import json
import pandas as pd
import re,os
from tqdm.auto import tqdm
import sys
from get_data_utils import *
jsonl_file = sys.argv[1]#'ragtest_md/0000000-0000209.00000_00000.jsonl'
output_dir = sys.argv[2]#'ragtest_md/input'
if os.path.exists(jsonl_file):
    with open(jsonl_file, 'r') as f:
        lines = f.readlines()
else:
    client    = build_client()
    filename  = os.path.basename(jsonl_file)
    s3path    = f"opendata:s3://llm-pdf-text/pdf_gpu_output/scihub_shared/physics_part/markdown/{filename}"
    if check_path_exists(s3path,client):
        lines = read_json_from_path(s3path,client)
    else:
        raise FileNotFoundError(f"File {jsonl_file} not found in local or s3")
output_csv = []

for line_idx, line in enumerate(tqdm(lines)):
    data = json.loads(line) if isinstance(line, str) else line
    markdown = data['markdown']
    ### remove image ref in markdown: format is ![](xxxxxxxxxxxxx)
    # example: ![](s3://llm-pdf-text/pdf_gpu_output/scihub_shared/physics_part/images_per_pdf/0000000-0000209.00000_00000/ecc050a5-7ced-475b-b299-08753db114cb/4d3dc27972564c4130bce569f3d368548af7d35837ea350c9a75514b356fa43e.jpg)
    markdown = re.sub(r'!\[\]\(s3://llm-pdf-text/pdf_gpu_output/scihub_shared/physics_part/images_per_pdf/.*?\.jpg\)', '', markdown)
    ### remove table ref in markdown: format is ![TABLE xxxx](xxxxxxxxxxxxx)
    # example: ![TABLE 1 Mechanical properties of Al 6061-SiC composites ](s3://llm-pdf-text/pdf_gpu_output/scihub_shared/physics_part/images_per_pdf/0000000-0000209.00000_00000/2eee5347-9f87-40a9-9da6-2294c19c5fe6/5977db2955047c21078d2de62f73927fc312fea456df029de5e5c96f0ed1e10b.jpg)  Tpr, processing temperature; NA, not available.  
    markdown = re.sub(r'!\[TABLE \d+.*?\]\(s3://llm-pdf-text/pdf_gpu_output/scihub_shared/physics_part/images_per_pdf/.*?\.jpg\)', '', markdown)
    track_id = data['track_id']
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    with open(os.path.join(output_dir,track_id+'.txt'),'w') as f:
        f.write(markdown)
    #output_csv.append([data['track_id'],  markdown])
    #if line_idx>2:break
# df = pd.DataFrame(output_csv, columns=['track_id', 'markdown'])
# df.to_csv('ragtest_md/input/0000000-0000209.00000_00000.csv', index=False)