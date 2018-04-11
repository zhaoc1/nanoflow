####
# Nanopore Sequencing Data Bioinformatics Pipeline
# author: Chunyu Zhao
# time: 2018-03-08
####

import os
from sbx_igv import * 

configfile: 'config.yaml'
workdir: config['project_dir']

with open(config['barcodes_fp']) as f:
 BARCODES = f.read().splitlines()

include: "preprocess.rules"
include: "draft1.rules"
include: "draft2.rules"
include: "draft3.rules"
include: "assess_asm.rules"
include: "mapping.rules"

rule all:
 input:
  expand(config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz', barcode=BARCODES),
  expand(config['project_dir'] + '/reports/{step}/{barcode}/reads.asm.stats', 
	step=['01_basecalled_reads','03_subsampled_reads'], barcode=BARCODES),
  expand(config['project_dir'] + '/reports/01_basecalled_reads/{barcode}/reads.aln.tsv', barcode=BARCODES),
  expand(config['project_dir'] + '/reports/{step}/{barcode}/asm.aln.tsv',
    step=['04_canu','05_nanopolish'], barcode=BARCODES),
  expand(config['project_dir'] + '/reports/{step}/{barcode}/asm.aln.tsv',
    step=['09_unicycler_long'], barcode=BARCODES)


#onsuccess:
# print("Workflow finished, no error")
# shell("mail -s 'workflow finished' " + config['admins']+" <{log}")
#onerror:
# print("An error occurred")
# shell("mail -s 'an error occurred' " + config['admins']+" < {log}")

