####
# Nanopore Sequencing Data Bioinformatics Pipeline
# author: Chunyu Zhao
# time: 2018-03-08
####

import os

configfile: 'config.yaml'
workdir: config['project_dir']

with open(config['barcodes_fp']) as f:
 BARCODES = f.read().splitlines()

## Gather_up_nanopore_fastqs
rule collect_raw_fastq:
 input:
#  fast5_fp1 = config['raw_fast5_fp1'] + '/fast5/basecalled_albacore_v2.1/workspace/pass/{barcode}',
#  fast5_fp2 = config['raw_fast5_fp2'] + '/fast5/basecalled_albacore_v2.1/workspace/pass/{barcode}'
  fast5_fp1 = config['raw_fast5_fp1'] + '/{barcode}/{barcode}_basecalled_albacore_v2.1/workspace/pass/{barcode}',
  fast5_fp2 = config['raw_fast5_fp2'] + '/basecalled_dir_albacore_v2.1/workspace/pass/{barcode}' 
 output:
  config['project_dir'] + '/01_basecalled_reads/{barcode}/reads.fastq'
 run:
  if os.path.samefile(input.fast5_fp1, input.fast5_fp2):
   shell("cat {input.fast5_fp1}/*.fastq > {output}")
  else:
   shell("cat {input.fast5_fp1}/*.fastq {input.fast5_fp2}/*.fastq > {output}")

rule asm_stats_raw:
 input:
  config['project_dir'] + '/01_basecalled_reads/{barcode}/reads.fastq'
 output:
  config['project_dir'] + '/reports/01_basecalled_reads/{barcode}/reads.asm.stats'
 shell:
  """
  assembly-stats {input} > {output}
  """

## Assess reads using reference genome
rule assess_reads:
 input:
  genome = config['project_dir'] + '/' + config['genome_fp'],
  reads = config['project_dir'] + '/01_basecalled_reads/{barcode}/reads.fastq',
  python_script_fp = config['basecalling_cmp_fp'] + '/read_length_identity.py'
 output:
  aln = config['project_dir'] + '/01_basecalled_reads/{barcode}/reads.paf',
  table = config['project_dir'] + '/reports/01_basecalled_reads/{barcode}/reads.aln.tsv'
 threads: 1
 shell:
  """
  minimap2 -k12 -t {threads} -c {input.genome} {input.reads} > {output.aln}
  python {input.python_script_fp} {input.reads} {output.aln} > {output.table}
  """

## Confidently-binned reads
rule trim_reads:
 input:
  config['project_dir'] + '/01_basecalled_reads/{barcode}/reads.fastq'
 output:
  config['project_dir'] + '/02_trimmed_reads/{barcode}/reads.fastq'
 threads: 4
 shell:
  """
  porechop -i {input} -o {output} --threads {threads}
  """

## Subsample reads
rule subsample_reads:
 input:
  config['project_dir'] + '/02_trimmed_reads/{barcode}/reads.fastq'
 output:
  config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz'
 shell:
  """
  filtlong --min_length 1000 --keep_percent 90 --target_bases 500000000 {input} | gzip > {output}
  """

rule subsample_reads_with_reference:
 input:
  reads = config['project_dir'] + '/02_trimmed_reads/{barcode}/reads.fastq',
  R1 = config['project_dir'] + '/' + config['short_reads_fp'] + '/{barcode}/R1.fastq',
  R2 = config['project_dir'] + '/' + config['short_reads_fp'] + '/{barcode}/R2.fastq'
 output:
  config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.with.ref.fastq.gz'
 shell:
  """
  filtlong -1 {input.R1} -2 {input.R2} --min_length 1000 --keep_percent 90 --target_bases 500000000 {input.reads} --trim --split 250 | gzip > {output}
  """

rule asm_stats_subsample:
 input:
  config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz'
 output:
  config['project_dir'] + '/reports/03_subsampled_reads/{barcode}/reads.asm.stats'
 shell:
  """
  assembly-stats {input} > {output}
  """

rule canu_asm:
 input:
  reads = config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz',
  canu_exec_dir = config['canu_fp']
 output:
  config['project_dir'] + '/04_canu_asm/{barcode}/' + config['canu_prefix'] + '.contigs.fasta'
 params:
  output_dir = config['project_dir'] + '/04_canu_asm/{barcode}'
 threads: 8
 shell:
  """
  LD_LIBRARY_PATH="$CONDA_PREFIX/lib64" {input.canu_exec_dir} \
   -p {config[canu_prefix]} -d {params.output_dir} genomeSize={config[canu_genome_size]} \
   -nanopore-raw {input.reads} correctedErrorRate=0.16 useGrid=false \
   maxMemory=12G maxThreads=8 gnuplotTested=true
  """

rule assess_canu:
 input:
  genome = config['project_dir'] + '/' + config['genome_fp'],
  contigs = config['project_dir'] + '/04_canu_asm/{barcode}/' + config['canu_prefix'] + '.contigs.fasta',
  python_chop_fp = config['basecalling_cmp_fp'] + '/chop_up_assembly.py',
  python_ident_fp = config['basecalling_cmp_fp'] + '/read_length_identity.py'
 output:
  asm_pieces = config['project_dir'] + '/04_canu_asm/{barcode}/asm_pieces.fasta',
  asm_aln = config['project_dir'] + '/04_canu_asm/{barcode}/asm.aln.paf',
  asm_table = config['project_dir'] + '/reports/04_canu_asm/{barcode}/asm.aln.tsv'
 threads: 2
 shell:
  """
  python {input.python_chop_fp} {input.contigs} 1000 > {output.asm_pieces}
  minimap2 -k12 -t {threads} -c {input.genome} {output.asm_pieces} > {output.asm_aln}
  python {input.python_ident_fp} {output.asm_pieces} {output.asm_aln} > {output.asm_table}
  """

rule _all_reports:
 input:
  [expand(config['project_dir'] + '/reports/01_basecalled_reads/{barcode}/reads.aln.tsv', barcode=BARCODES),
expand(config['project_dir'] + '/reports/01_basecalled_reads/{barcode}/reads.asm.stats', barcode=BARCODES),
expand(config['project_dir'] + '/reports/04_canu_asm/{barcode}/asm.aln.tsv', barcode=BARCODES)]


## Prepare sequencign summary for fast nanopolish index fast5 files
rule collect_sequencing_summary:
 input:
  expand(config['raw_fast5_fp1'] + '/{barcode}/{barcode}_basecalled_albacore_v2.1/sequencing_summary.txt', barcode=BARCODES),
  config['raw_fast5_fp2'] + '/basecalled_dir_albacore_v2.1/sequencing_summary.txt'
 output:
  config['project_dir'] + '/05_nanopolish/{barcode}/sequencing_summary_files.txt'
 run:
  with open(output[0],'w') as out:
   for item in input:
    out.write("%s\n" % os.path.abspath(item))

## Index the reads after preprocessing
rule nanopolish_index:
 input:
  fast5_fp1 = config['raw_fast5_fp1'] + '/{barcode}/{barcode}_basecalled_albacore_v2.1/workspace/pass/{barcode}',
  fast5_fp2 = config['raw_fast5_fp2'] + '/basecalled_dir_albacore_v2.1/workspace/pass/{barcode}',
  reads = config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz',
  nanopolish_fp = config['nanopolish_fp'] + '/nanopolish',
  summary = config['project_dir'] + '/05_nanopolish/{barcode}/sequencing_summary_files.txt'
 output:
  config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz.index.readdb'
 shell:
  """
  export LD_LIBRARY_PATH="$CONDA_PREFIX/lib64"
  
  if [[ {input.fast5_fp1} -ef {input.fast5_fp2} ]]; then
   {input.nanopolish_fp} index -d {input.fast5_fp1} -f {input.summary} {input.reads}
  else
   {input.nanopolish_fp} index -d {input.fast5_fp1} -d {input.fast5_fp2} -f {input.summary} {input.reads}
  fi
  """

## 20180315: technically speaking, bwa's long reads mapping functionality tranferred to minimap2
rule bwa_index:
 input:
  config['project_dir'] + '/04_canu_asm/{barcode}/' + config['canu_prefix'] + '.contigs.fasta'
 output:
  contigs = config['project_dir'] + '/05_nanopolish_bwa/{barcode}/' + config['canu_prefix'] + '.contigs.fasta',
  index = config['project_dir'] + '/05_nanopolish_bwa/{barcode}/' + config['canu_prefix'] + '.contigs.fasta.amb'
 shell:
  """
  cp {input} {output.contigs}
  bwa index {output.contigs}
  """

rule bwa_align:
 input:
  subsampled_reads = config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz',
  reads_index = config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz.index.readdb',
  contigs = config['project_dir'] + '/05_nanopolish_bwa/{barcode}/' + config['canu_prefix'] + '.contigs.fasta',
  contigs_index = config['project_dir'] + '/05_nanopolish_bwa/{barcode}/' + config['canu_prefix'] + '.contigs.fasta.amb'
 output:
  sorted_bam = config['project_dir'] + '/05_nanopolish_bwa/{barcode}/reads.sorted.bam',
  sorted_bai = config['project_dir'] + '/05_nanopolish_bwa/{barcode}/reads.sorted.bam.bai'
 params:
  temp = config['project_dir'] + '/05_nanopolish_bwa/{barcode}/reads.tmp'
 threads: 8
 shell:
  """
  bwa mem -x ont2d -t 8 {input.contigs} {input.subsampled_reads} | \
   samtools sort -o {output.sorted_bam} -T {params.temp} -
  samtools index {output.sorted_bam}
  """

rule minimap2_long:
 input:
  contigs = config['project_dir'] + '/04_canu_asm/{barcode}/' + config['canu_prefix'] + '.contigs.fasta',
  reads = config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz',
  reads_index = config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz.index.readdb',
 output:
  contigs = config['project_dir'] + '/05_nanopolish/{barcode}/' + config['canu_prefix'] + '.contigs.fasta',
  sorted_bam = config['project_dir'] + '/05_nanopolish/{barcode}/reads.sorted.bam',
  sorted_bai = config['project_dir'] + '/05_nanopolish/{barcode}/reads.sorted.bam.bai'
 params:
  temp = config['project_dir'] + '/05_nanopolish/{barcode}/reads.tmp'
 threads: 8
 shell:
  """
  cp {input} {output.contigs}
  minimap2 -x map10k -a -t {threads} {output.contigs} {input.reads} | \
   samtools sort -o {output.sorted_bam} -T {params.temp} -
  samtools index {output.sorted_bam}
  """

rule _all_long_aln:
 input:
  expand(config['project_dir'] + '/05_nanopolish/{barcode}/reads.sorted.bam.bai', barcode=BARCODES)

## THIS rule need to be updated based on the other Snakefile_0314
rule nanopolish_consensus:
 input:
  reads = config['project_dir'] + '/03_subsampled_reads/{barcode}/reads.fastq.gz',
  bam = config['project_dir'] + '/05_nanopolish/{barcode}/reads.sorted.bam',
  bai = config['project_dir'] + '/05_nanopolish/{barcode}/reads.sorted.bam.bai',
  contigs = config['project_dir'] + '/05_nanopolish/{barcode}/' + config['canu_prefix'] + '.contigs.fasta',
  makerange_fp = config['nanopolish_scripts_fp'] + '/nanopolish_makerange.py',
  merge_fp = config['nanopolish_scripts_fp'] + '/nanopolish_merge.py'
 output:
  config['project_dir'] + '/05_nanopolish/{barcode}/' + config['canu_prefix'] + '.polished.contigs.fasta'
 params:
  results_fp = config['project_dir'] + '/05_nanopolish/{barcode}/nanopolish.results',
  polished_fp = config['project_dir'] + '/05_nanopolish/{barcode}/polished.results'
 threads: 32
 shell:
  """
  export PATH=/home/zhaoc1/minions-snakemake/local/nanopolish:$PATH
  export LD_LIBRARY_PATH="$CONDA_PREFIX/lib64"
  python {input.makerange_fp} {input.contigs} | \
   parallel --results {params.results_fp} -P 8 \
   nanopolish variants --consensus {params.polished_fp}/polished.{{1}}.fa \
    -w {{1}} -r {input.reads} -b {input.bam} -g {input.contigs} \
    -t 4 --min-candidate-frequency 0.1 --methylation-aware=dcm,dam
  
  python {input.merge_fp} {params.polished_fp}/polished.*.fa > {output}
  """

rule _all_polish:
 input:
  expand(config['project_dir'] + '/05_nanopolish/{barcode}/' + config['canu_prefix'] + '.polished.contigs.fasta', barcode=["barcode03"])

rule ass_nanopolish:
 input:
  genome = config['project_dir'] + '/' + config['genome_fp'],
  contigs = config['project_dir'] + '/05_nanopolish/{barcode}/' + config['canu_prefix'] + '.contigs.fasta',
  python_chop_fp = config['basecalling_cmp_fp'] + '/chop_up_assembly.py',
  python_ident_fp = config['basecalling_cmp_fp'] + '/read_length_identity.py'
 output:
  asm_pieces = config['project_dir'] + '/05_nanopolish/{barcode}/asm_pieces.fasta',
  asm_aln = config['project_dir'] + '/05_nanopolish/{barcode}/asm.aln.paf',
  asm_table = config['project_dir'] + '/reports/05_nanopolish/{barcode}/asm.aln.tsv'
 threads: 2
 shell:
  """
  python {input.python_chop_fp} {input.contigs} 1000 > {output.asm_pieces}
  minimap2 -x map10k -t {threads} -c {input.genome} {output.asm_pieces} > {output.asm_aln}
  python {input.python_ident_fp} {output.asm_pieces} {output.asm_aln} > {output.asm_table}
  """

#onsuccess:
# print("Workflow finished, no error")
# shell("mail -s 'workflow finished' " + config['admins']+" <{log}")
#onerror:
# print("An error occurred")
# shell("mail -s 'an error occurred' " + config['admins']+" < {log}")
