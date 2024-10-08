#!/bin/bash
#SBATCH --partition AI4Chem
#SBATCH --output /mnt/petrelfs/hugengyuan/llm_server.log
#SBATCH --gres gpu:1
#SBATCH --cpus-per-task 16
#SBATCH --quotatype auto
hostname
proxy_off
nohup /mnt/petrelfs/hugengyuan/softwares/frp/frpc -c /mnt/petrelfs/hugengyuan/softwares/frp/webui_frp.json &
proxy_on
apptainer instance start -B ~/openwebui/runtime_data/:/app/backend/data ~/openwebui.sif webui
OLLAMA_HOST=0.0.0.0 OLLAMA_MAX_LOADED_MODELS=3 OLLAMA_ORIGINS=* OLLAMA_KEEP_ALIVE='24h' ~/ollama-linux-amd64 serve