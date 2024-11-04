#!/bin/bash
#SBATCH -J graphrag
#SBATCH -o .log/%j_RAG.out  
#SBATCH -e .log/%j_RAG.out  

LOG_FILE=".log"
OLLMA_PORT=$(python -c "import socket; s = socket.socket(); s.bind(('', 0)); print(s.getsockname()[1]); s.close()")
LLMPORT=$(python -c "import socket; s = socket.socket(); s.bind(('', 0)); print(s.getsockname()[1]); s.close()")
HOSTNAME=$(hostname)

echo """
=========================
[$HOSTNAME][`date`] --  OLLMA_PORT: $OLLMA_PORT, LLMPORT: $LLMPORT
=========================
"""

export no_proxy=10.140.27.254,10.140.31.254,localhost,127.0.0.1
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_ORIGINS=* 
export OLLAMA_KEEP_ALIVE='24h'
export OLLAMA_HOST=0.0.0.0:$OLLMA_PORT

declare -a pids

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
nohup python -m sglang.launch_server --model Qwen/Qwen2.5-14B-Instruct --trust-remote-code --port $LLMPORT --disable-disk-cache --host 0.0.0.0 > $LOG_FILE/LLM.log 2>&1 &
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

# hold the script until all the background processes are finished
for pid in ${pids[*]}; do
    wait $pid
done