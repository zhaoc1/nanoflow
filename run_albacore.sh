set -e
set -x
raw_fast5_fp=/mnt/isilon/microbiome/incoming/nanopore/run14_cdiff_t15_t18_t19_t21_t22/20180220_2138/fast5
basecalled_fast5_fp=/scr1/users/zhaoc1/projects/basecalled_run14_20180329
read_fast5_basecaller.py --flowcell FLO-MIN106 --kit SQK-RBK001 --barcoding --output_format fast5,fastq \
	--worker_threads 8 --recursive --input $raw_fast5_fp --save_path $basecalled_fast5_fp
