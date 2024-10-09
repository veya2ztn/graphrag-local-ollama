## this file will 
### 1. collect whole the should filename list
### 2. detect finished filename list
### 3. filter unfinished filename list
### 4. random pick one file from remain 

import os
import numpy as np
whole_file_set_path = "markdown.total.filelist"
with open(whole_file_set_path,'r') as f:
    lines = f.readlines()
    lines = [l.strip().replace('.jsonl','') for l in lines]
    whole_file_set = set(lines)

finished_file_fold = "/mnt/petrelfs/zhangtianning.di/projects/graphrag-local-ollama/physics_whole_graph"
finished_file_set = []
for fold_name in os.listdir(finished_file_fold):
    fold_path = os.path.join(finished_file_fold,fold_name)
    finishlock= os.path.join(fold_path,'finish.lock')
    if os.path.exists(finishlock):continue
    finished_file_set.append(fold_name)
finished_file_set = set(finished_file_set)

with open("graphrag.finish.lslist",'r') as f:
    lines = [t.strip() for t in f.readlines()]
    finished_file_set2 = [t.strip('/').split()[1] for t in lines]
    finished_file_set2 = set(finished_file_set2)

finished_file_set = finished_file_set | finished_file_set2

remain_file_set = whole_file_set - finished_file_set
if len(remain_file_set) ==0:
    print("")
else:

    one_file = np.random.choice(list(remain_file_set))
    print(f"{one_file}.jsonl")