
TOTALNUM=10
CPU_NUM=$1 # Automatically get the number of CPUs
if [ -z "$CPU_NUM" ]; then
    CPU_NUM=$TOTALNUM
fi
# check hostname: if it start with SH than use 

if [[ $(hostname) == SH* ]]; then
    PARA="--quotatype=spot -p AI4Chem -N1 -c8 --gres=gpu:1"

    export LD_LIBRARY_PATH=/mnt/cache/share/gcc/gcc-7.5.0/lib64:${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
    export PATH=/mnt/cache/share/gcc/gcc-7.5.0/bin:$PATH

else

    PARA="-p vip_gpu_ailab_low -N1 -c8 --gres=gpu:1"
fi

START=0
for ((CPU=0; CPU<CPU_NUM; CPU++));
do

    sbatch $PARA run_task.sh
   
    if [ $(($CPU % 10)) -eq 9 ]; then
        sleep 20
    fi
done 
