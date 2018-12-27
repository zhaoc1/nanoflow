#!/bin/bash
set -e
set -x

# Chunyu Zhao 2018-06-24
# The following are the Minion flow cell used by PCMP

## raw FAST5 signal data directory
raw_fast5_fp=/mnt/isilon/microbiome/incoming/nanopore/run14_cdiff_t15_t18_t19_t21_t22/20180220_2138/fast5

## basecalled FAST5 signal data directory; will be used by Nanopolish
basecalled_fast5_fp=/scr1/users/zhaoc1/projects/basecalled_run14_20180329

## do the work
read_fast5_basecaller.py --flowcell FLO-MIN106 --kit SQK-RBK001 --barcoding --output_format fast5,fastq \
	--worker_threads 8 --recursive --input $raw_fast5_fp --save_path $basecalled_fast5_fp
