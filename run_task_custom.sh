#!/bin/bash
#SBATCH -J graphrag
#SBATCH -o .log/%j_RAG.out  
#SBATCH -e .log/%j_RAG.out  
export PYTHONUNBUFFERED=1
SRUN_JOB_ID=$SLURM_JOB_ID
LOG_FILE=".log/RAG/job-$SRUN_JOB_ID"
# In this script, we will run the graphrag software for input part files, each part file names like xxxxxxxxxxxxxxxxx.jsonl and it always contains 1000 records.
# the .jsonl file is format as 
# {"track_id": "ecc050a5-7ced-475b-b299-08753db114cb", "path": "opendata:s3://sci-hub/enbook-scimag/37500000/lib..............", "markdown": "............"}
# {"track_id": "9d1d4a78-5662-46ae-9f97-e1f61f670a13", "path": "opendata:s3://sci-hub/enbook-scimag/17900000/lib..............", "markdown": "............"}
# {"track_id": "3c754e79-016c-4f1e-a16c-5f8f65c2bab6", "path": "opendata:s3://sci-hub/enbook-scimag/34100000/lib..............", "markdown": "............"}
# {"track_id": "c9a3b92a-4aaa-4852-8ca4-2cfdaec3677c", "path": "opendata:s3://sci-hub/enbook-scimag/03200000/lib..............", "markdown": "............"}
# {"track_id": "41f4184c-3c54-4202-b096-a19090dce48e", "path": "opendata:s3://sci-hub/enbook-scimag/78800000/lib..............", "markdown": "............"}
# {"track_id": "9ef4b1ae-4d1f-400d-8712-fbeefc67b34e", "path": "opendata:s3://sci-hub/enbook-scimag/02700000/lib..............", "markdown": "............"}
# {"track_id": "8ee8c84f-3bc3-4adf-b0ee-6f39a0464ebf", "path": "opendata:s3://sci-hub/enbook-scimag/18800000/lib..............", "markdown": "............"}
# we will firstly extract the data into a TEMP folder(use the system temp), and then run the graphrag software to generate the graph data, and finally we will upload the graph data to the S3 bucket.
alias awsdd='aws s3 --endpoint-url=http://p-ceph-norm-outside.pjlab.org.cn/ --profile afp'

TEMPROOT="/tmp/graphrag"
#TEMPROOT="temp"
HOSTNAME=$(hostname)
# the input part file
# lets use python random_sample_one_name.py random get filename
INPUT_PART_FILE="custom_collection/markdown/whole.jsonl" #`python random_sample_one_name.py|tail -n 1`  #$1
## exit when the INPUT_PART_FILE is None
if [ -z "$INPUT_PART_FILE" ]; then
    echo "[$HOSTNAME][`date`] --  No input part file found, exit"
    exit 1
fi

# remove the jsonl
INPUT_PART_NAME=$(basename $INPUT_PART_FILE .jsonl)


RESULT_FILE=/mnt/petrelfs/zhangtianning.di/projects/graphrag-local-ollama/custom_collection/graphrag/$INPUT_PART_NAME
if [ ! -d $RESULT_FILE ]; then
    mkdir -p $RESULT_FILE
fi
### lets make a small lock system to avoid the same task run at the same time
FINISHLOCK=$RESULT_FILE/finish.lock
if [ -f $FINISHLOCK ]; then
    echo "[$HOSTNAME][`date`] --  $INPUT_PART_NAME is already finished [Marked by $FINISHLOCK] skip it"
    exit 0
fi

TIMELOCK="$RESULT_FILE/last_run.lock"
echo "LOCK AT $TIMELOCK"
# If TIMELOCK does not exist, write current time into TIMELOCK
# Else, compare current time with TIMELOCK; if less than 1 hour, skip it
if [ ! -f "$TIMELOCK" ]; then
    date +%s > "$TIMELOCK"
else
    LASTTIME=$(cat "$TIMELOCK")
    CURTIME=$(date +%s)
    if [ $(($CURTIME - $LASTTIME)) -lt 3600 ]; then
        echo "[$HOSTNAME][`date`] --  $INPUT_PART_NAME is already running, skip it"
        exit 0
    else
        date +%s > "$TIMELOCK"
    fi
fi

# the TEMP file
TEMP_FOLDER=$RESULT_FILE #$TEMPROOT/$INPUT_PART_NAME
if [ ! -d $TEMP_FOLDER ]; then
    mkdir -p $TEMP_FOLDER
fi
OLLMA_PORT=$(python -c "import socket; s = socket.socket(); s.bind(('', 0)); print(s.getsockname()[1]); s.close()")
LLMPORT=$(python -c "import socket; s = socket.socket(); s.bind(('', 0)); print(s.getsockname()[1]); s.close()")
echo """
=========================
[$HOSTNAME][`date`] --  OLLMA_PORT: $OLLMA_PORT, LLMPORT: $LLMPORT
=========================
"""
# cp settings.yaml $TEMP_FOLDER/settings.yaml
# sed -i "s|http://localhost:30000|http://localhost:$LLMPORT|g" $TEMP_FOLDER/settings.yaml
# sed -i "s|http://localhost:11434|http://localhost:$OLLMA_PORT|g" $TEMP_FOLDER/settings.yaml
# cat $TEMP_FOLDER/settings.yaml
# exit 0
## USE
TEMP_INPUT_FOLD=$TEMP_FOLDER/input
if [ ! -d $TEMP_INPUT_FOLD ]; then
    mkdir -p $TEMP_INPUT_FOLD
fi
# USE convert_jsonl_to_csv.py to split data into .txt 
python convert_jsonl_to_csv.py $INPUT_PART_FILE $TEMP_INPUT_FOLD
# then we need setup graphrag server

declare -a pids

# ### setup the LLM backend enigine, it should be in background but should be killed when the main thread die
if [ ! -d $LOG_FILE ]; then
    mkdir -p $LOG_FILE
fi
for v in http_proxy https_proxy HTTP_PROXY HTTPS_PROXY; do export $v=http://zhangtianning.di:IDd1jJ7pW7MXd1od63GnWeASuzpqyx1lY8N3TESETAn62A8oOcQmLJHA7IyG@10.1.20.51:23128; done; 
export no_proxy=10.140.27.254,10.140.31.254,localhost,127.0.0.1
# =================================================================================
### setup the ollama server
### random get a ollama port


export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_ORIGINS=* 
export OLLAMA_KEEP_ALIVE='24h'
export OLLAMA_HOST=127.0.0.1:$OLLMA_PORT

nohup ~/projects/ollama/bin/ollama serve > $LOG_FILE/embedding.log 2>&1 &
pids[0]=$!
### use follow code test the ollama serve is setup correctly, you may create a is_ollama_build function
### curl http://$OLLAMA_HOST/api/embeddings -d '{"model": "jina/jina-embeddings-v2-base-en","prompt": "Llamas are members of the camelid family"}'
### setup a loop with timelimit that detect the status for ollama building via is_ollama_build function
sleep 5

STARTTIME=$(date +%s)
while true; do
    curl -s http://$OLLAMA_HOST/api/embeddings -d '{"model": "jina/jina-embeddings-v2-base-en","prompt": "Llamas are members of the camelid family"}' > /dev/null
    if [ $? -eq 0 ]; then
        break
    fi
    echo "[$HOSTNAME][`date`] -- Embedding is not ready, check log file [$LOG_FILE/embedding.log] , wait 5s"
    sleep 5
    NOWTIME=$(date +%s)
    if [ $(($NOWTIME - $STARTTIME)) -gt 600 ]; then
        echo "[$HOSTNAME][`date`] -- Embedding is TIME OUT, check log file [$LOG_FILE/embedding.log] , wait 5s"
        exit 1
    fi
done


echo "[$HOSTNAME][`date`] -- finish test llama"

# =================================================================================
echo "[$HOSTNAME][`date`] -- start building LLM"
export HF_DATASETS_OFFLINE=1
export HF_HUB_OFFLINE=1
export OUTLINES_CACHE_DIR=$TEMPROOT/outlines
nohup python -m sglang.launch_server --model Qwen/Qwen2.5-14B-Instruct --trust-remote-code --port $LLMPORT --disable-disk-cache > $LOG_FILE/LLM.log 2>&1 &
pids[1]=$!


sleep 5
#curl https://localhost:$LLMPORT/v1/chat/completions -H "Content-Type: application/json" \-d '{"model": "deepseek-chat","messages": [{"role": "system", "content": "You are a helpful assistant."},{"role": "user", "content": "Hello!"}],"stream": false}'
## lets add a time limit for the LLM building
STARTTIME=$(date +%s)
while true; do
    curl -s http://localhost:$LLMPORT/v1/chat/completions -H "Content-Type: application/json" -d '{"model": "deepseek-chat","messages": [{"role": "system", "content": "You are a helpful assistant."},{"role": "user", "content": "Hello!"}],"stream": false}' > /dev/null
    if [ $? -eq 0 ]; then
        break
    fi
    REMAINTIME=$(($NOWTIME - $STARTTIME))
    echo "[$HOSTNAME][`date`] -- LLM is not ready, check log file [$LOG_FILE/LLM.log] , wait 5s, pass time: $REMAINTIME, limit 600s"
    NOWTIME=$(date +%s)
    if [ $REMAINTIME -gt 600 ]; then
        echo "[$HOSTNAME][`date`] -- LLM is TIME OUT, check log file [$LOG_FILE/LLM.log] , EXIT"
        exit 1
    fi
    sleep 5
    
done

echo "[$HOSTNAME][`date`] -- finish test LLM"

# =================================================================================
## pass if and only if the curl return 200


python -u -m graphrag.index --init --root $TEMP_FOLDER
cp settings.yaml $TEMP_FOLDER/settings.yaml
sed -i "s|http://localhost:30000|http://localhost:$LLMPORT|g" $TEMP_FOLDER/settings.yaml
sed -i "s|http://localhost:11434|http://localhost:$OLLMA_PORT|g" $TEMP_FOLDER/settings.yaml


if [ ! -d $OUTPUT_FOLD ]; then
    mkdir -p $OUTPUT_FOLD
fi

echo "[$HOSTNAME][`date`] -- GraphRAG is start, check log file [$LOG_FILE/Control.log] "
python -u -m graphrag.index --root $TEMP_FOLDER > $LOG_FILE/Control.log

if [ $? -ne 0 ]; then
    echo "[$HOSTNAME][`date`] --  $INPUT_PART_NAME failed"
    exit 1
fi

echo "[$HOSTNAME][`date`] --  $INPUT_PART_NAME finished"


#mv $TEMP_FOLDER/output $RESULT_FILE/output
# touch $FINISHLOCK
# ### the fold under $RESULT_FILE/output is
# ## then after finish it will upload the graph data to the S3 bucket
# unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
# aws s3 --endpoint-url=http://p-ceph-norm-outside.pjlab.org.cn/ --profile afp sync --exclude *.log $RESULT_FILE/output/ s3://llm-pdf-text/pdf_gpu_output/scihub_shared/physics_part/graphrag/version1/$INPUT_PART_NAME
# if [ $? -ne 0 ]; then
#     echo "[$HOSTNAME][`date`] --  $INPUT_PART_NAME up load failed"
#     exit 1
# fi
# ## then create the finish lock
# ## then remove the temp folder
# rm -rf $TEMP_FOLDER
# ## then remove the $RESULT_FILE/output
# rm -rf $RESULT_FILE/output