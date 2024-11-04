
#!/bin/bash

# Function to get the count of pending tasks
user=`whoami`
if [[ $(hostname) == SH* ]]; then
    partition='AI4Chem'
    TASKLIMIT=30
    PENDINGLIMIT=2
else
    partition='vip_gpu_ailab_low'
    TASKLIMIT=30
    PENDINGLIMIT=2
fi

jobname='graphrag'
get_pending_count() {
    squeue -u $user -p $partition -n $jobname | grep PD | wc -l
}
get_pending_jobids() {
    squeue -u $user -p $partition -n $jobname | grep PD | awk '{print $1}'
}

# Function to get the count of running tasks
get_running_count() {
    squeue -u $user -p $partition -n $jobname | grep R | wc -l
}



# Function to submit a task
submit_task() {
    current_time=$(date +"%Y.%m.%d %H:%M")
    
    bash batch_run.sh 1
    
}

# Function to cancel extra pending tasks
cancel_extra_pending_tasks() {
    pending_jobids=($(get_pending_jobids))
    for (( i=$PENDINGLIMIT; i<${#pending_jobids[@]}; i++ )); do
        echo "Cancelling extra pending task: ${pending_jobids[$i]}"
        scancel "${pending_jobids[$i]}"
    done
}

# Main loop to check and submit tasks every 2 seconds
while true; do
    pending_count=$(get_pending_count)
    running_count=$(get_running_count)
    
    # Cancel extra pending tasks if pending count > 5
    if [ "$pending_count" -gt $PENDINGLIMIT ]; then
        cancel_extra_pending_tasks
        sleep 30
    fi

    pending_count=$(get_pending_count)
    running_count=$(get_running_count)



    # Submit a task only when running tasks < 60 and pending tasks < 3
    if [ "$running_count" -lt $TASKLIMIT ] && [ "$pending_count" -lt 3 ]; then
        echo "Pending tasks: $pending_count Running tasks: $running_count/$TASKLIMIT Submitting a new task..."
        submit_task
    else
        echo "Pending tasks: $pending_count Running tasks: $running_count/$TASKLIMIT"
    fi


    sleep 30
done