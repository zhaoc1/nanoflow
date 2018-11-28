####
# Nanopore Sequencing Data Bioinformatics Pipeline
# author: Chunyu Zhao
# time: 2018-03-08
####

import os
#from sbx_igv import * 

workdir: config['project_dir']

with open(config['barcodes_fp']) as f:
 BARCODES = f.read().splitlines()

#include: "rules/basecalling.rules"
include: "rules/qc.rules"
#include: "rules/asm_long.rules"
include: "rules/asm_long_nofast5.rules" #<---- only for tutorial purpose

#include: "rules/draft2.rules"
#include: "rules/draft3.rules"
include: "rules/assess_asm.rules"
#include: "rules/mapping.rules"


rule all_day1:
 input:
  expand(config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz', barcode=BARCODES),
  expand(config['project_dir'] + '/reports/{step}/{barcode}/reads.asm.stats',
        step=['01_basecalled_reads','03_subsampled_reads'], barcode=BARCODES),
  expand(config['project_dir'] + '/reports/01_basecalled_reads/{barcode}/reads.aln.tsv', barcode=BARCODES),
  expand(config['project_dir'] + '/reports/{step}/{barcode}/asm.aln.tsv',
    step=['04_canu'], barcode=BARCODES),
  expand(config['project_dir'] + '/06_circlator/.{barcode}_done_circlator', barcode=BARCODES)


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

