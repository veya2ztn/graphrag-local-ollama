#!/bin/bash
#SBATCH -J graphrag
#SBATCH -o .log/%j_RAG.out  
#SBATCH -e .log/%j_RAG.out  
export LD_LIBRARY_PATH=/mnt/cache/share/gcc/gcc-7.5.0/lib64:${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}};
export PATH=/mnt/cache/share/gcc/gcc-7.5.0/bin:$PATH;
export HF_DATASETS_OFFLINE=1 
export HF_HUB_OFFLINE=1 
HF_DATASETS_OFFLINE=1 HF_HUB_OFFLINE=1  python -m sglang.launch_server --trust-remote-code --host 0.0.0.0 --model nvidia/Llama-3.1-Nemotron-70B-Instruct-HF --tp 4 --dp 2
#HF_DATASETS_OFFLINE=1 HF_HUB_OFFLINE=1  python -m sglang.launch_server --trust-remote-code --host 0.0.0.0 --model Qwen/Qwen2.5-14B-Instruct --dp 4 
#HF_DATASETS_OFFLINE=1 HF_HUB_OFFLINE=1 srun1 -p AI4Chem -N1 -c16 --gres=gpu:1 python -m sglang.launch_server --trust-remote-code --host 0.0.0.0 --model deepseek-ai/DeepSeek-V2-Lite-Chat