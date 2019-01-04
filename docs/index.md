## Nanopore Sequencing Analysis Tutorial

In this tutorial, we used bacterial sequencing data from long and short reads to produce a polished complete genome. 

### Dataset

First, create your `project_dir`:
  ```bash
  mkdir ~/nanoflow_tutorial
  ```
Second, we downloaded the long and short reads for sample INFO59 from [Ryan Wick's paper](https://www.ncbi.nlm.nih.gov/pubmed/29177090), which sequenced 12 Klebsiella pneumoniae on a single flow cell. We used [louiejtaylor](https://github.com/louiejtaylor)'s [grabseqs](https://github.com/louiejtaylor/grabseqs) to grab the sequencing data from SRA under theBioSample number SAMEA3357043.
  ```bash
  conda install -c louiejtaylor -c bioconda grabseqs
  
  grabseqs sra -t 8 SAMEA3357043 -o ~/nanoflow_tutorial/01_basecalled_reads
  ```

There are three files in the `01_basecalled_reads` files:
- SRR5665596.fastq.gz: the Nanopore reads
- ERR1023792_1.fastq.gz: the Illumina forward reads
- ERR1023792_2.fastq.gz: the Illumina reverse reads

Third, let's get the sequencing data in the desired format.

  ```bash
  cd ~/nanoflow_tutorial
  
  mkdir short_reads
  mkdir short_reads/barcode02
  mv ~/nanoflow_tutorial/01_basecalled_reads/ERR1023792_1.fastq.gz short_reads/barcode02/R1.fastq.gz
  mv ~/nanoflow_tutorial/01_basecalled_reads/ERR1023792_2.fastq.gz short_reads/barcode02/R2.fastq.gz
  
  mkdir 01_basecalled_reads/barcode02
  mv ~/nanoflow_tutorial/01_basecalled_reads/SRR5665596.fastq 01_basecalled_reads/barcode02/reads.fastq
  ```
  

Fourth, for the purpose of estimating the sequencing accuracy, download the genome and gene annotation files for [klebsiella pneumoniae](https://www.ncbi.nlm.nih.gov/genome/?term=Klebsiella%20pneumoniae) and place them into your `project_dir`.
  ```bash
  cd ~/nanoflow_tutorial
  wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/417/085/GCF_000417085.2_ASM41708v2/GCF_000417085.2_ASM41708v2_genomic.fna.gz
  wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/417/085/GCF_000417085.2_ASM41708v2/GCF_000417085.2_ASM41708v2_genomic.gff.gz
  gunzip *.gz
  
  mv GCF_000417085.2_ASM41708v2_genomic.fna GCF_000417085.fna
  mv GCF_000417085.2_ASM41708v2_genomic.gff GCF_000417085.gff
  ```
  

### Basecalling

Albacore is the data processig pipeline that provides the [Oxford Nanopore basecalling algorithms](https://nanoporetech.com/analyse), and several post-processing steps. In addition to Basecalling, Albacore also provided Barcoding/Demultiplexing. 
  ```bash
  read_fast5_basecaller.py --flowcell FLO-MIN106 --kit SQK-RBK001 --barcoding \
                           --output_format fast5,fastq --worker_threads 8 \
                           --recursive --input $raw_fast5_fp --save_path $basecalled_fast5_fp
  ```

After the basecalling, rule `collect_raw_fastq` gathers basecalled fastq files for each barcode, and rule `asm_stats_raw` reports the standard assembly quatlify metric for the raw long reads, include total number of reads, N50, largest read length, and etc.

- `01_basecalled_reads`/{barcode}/reads.fastq

### Quality Control

On top of the de-mutilplexed reads from Albacore, rule `trim_reads` used [porechop](https://github.com/rrwick/Porechop), to remove adapter sequences and generate the confidently-binned long reads. 
- `02_trimmed_reads`/{barcode}/reads.fastq


[Filtlong](https://github.com/rrwick/Filtlong) was then used in rule `subsample_reads` to remove reads short than 1 kbp and subsample the reads to 500 Mbps or keep the best 90% of the reads.

-  `03_subsampled_reads`/{barcode}/reads.fastq.gz

  ```bash
  snakemake --configfile ~/nanoflow_tutorial/config.yml _all_qc -p --cores 8
  ```

### Assembly - long reads only/first

**asm_long.rules** includes the steps for nanopore long reads only assembly and draft genome assessment.

**[Canu](http://canu.readthedocs.io/en/latest/quick-start.html)** was used to assemble the quality controlled long reads in rule `canu_asm`.

**Check assembly output**: there are two output files what will be used in many downstreams steps:

- `04_canu`/{barcode}/canu.contigs.fasta <- the assembled contigs.
- `04_canu`/{barcode}/canu.correctedReads.fasta.gz: the corrected Nanopore reads that were used in the assembly.
  - Canu corrects the long reads by using the overlap between reads. That being said, if you are intersted in any long reads level mapping or antibiotics resistance gene finding, use this **correctedReads** instead of the rawLongReads from the preivous QC step.
  
  
**[Nanopolish](http://nanopolish.readthedocs.io/en/latest/installation.html#installing-a-particular-release)** was used to polish the assembled consensus sequences using the raw FAST5 signal data. This includes four steps: 

- `05_nanopolish`/{barcode}/nanopolish.contigs.fasta

  1. rule `collect_sequencing_summary`: prepare sequencing summary for fast *nanopolish index* fast5 files.
  2. rule `nanopolish_index`: *nanopolish index* the QualityControledLongReads.
  3. rule  `minimap2_align_nanopolish`: map the QualityControledLongReads to the assembled contigs from Canu using [minimap2](https://github.com/lh3/minimap2).
  4. rule `nanopolish_consensus`: polish the draft genome.
 
 
**[Circlator](https://github.com/sanger-pathogens/circlator/wiki/Brief-instructions)** was used to trim overhangs and circularize the assembled contigs (for both chromosomes and plasmids) in rule `run_circlator`.
-  `06_circlator`/{barcode}/06.fixstart.fasta


**[Pilon](https://github.com/broadinstitute/pilon/wiki)** was used to polish the draft genomes using Illumina short reads. Pilon aligns short reads to draft assemblies to identify inconsistencies between the short reads and the input genome.

- `07_pilon`/{barcode}/pilon.fasta

```bash
snakemake --configfile ~/nanoflow_tutorial/config.yml _all_draft1_nofast5 -p --cores 8
```


## Assembly - short reads first

The hybrid assemblies were generated using [Unicycler](https://github.com/rrwick/Unicycler) pipeline, with the *--existing_long_read_assembly* option. Unicycler first assembles the short reads using SPAdes, then scaffolds the assembly graph using either provided or generated long reads assemblies, and finish up with multiple rounds of polishing the draft genomes, to reduce the small base-level errors. For each intermediate steps, we can visualize the assembly graph (.gfa) using [Bandage](https://github.com/rrwick/Bandage).


We illustrated the problem of interrupted genes in this [slide](https://github.com/zhaoc1/nanoflow/blob/master/demo_interruptted_genes.pdf) for long reads first assemblies, and therefore recommended the short reads first assemblies for the Hybrid assebmlies.

- `/09_unicycler_long`/{barcode}/assembly.fasta

```bash
snakemake --configfile config.yaml --cores 8 _all_draft3
```

   
## Assessment

We evaluated the accuracy of the raw long reads and the assembled draft genomes, using the reads alignment to the reference genome specified in the *config.yml*, in rule `assess_reads`, `assess_canu`, `assess_nanopolish` and `assess_pilon`.

Read accuracy is interesting to better understand the nanopore sequencing error, and assembly accuracy is more interesting to show whether the read errors can **average out** with high sequencing depth.

The generated tsv files were parsed in the **bioinfo_report.Rmd**, with an example [bioinfo_report.pdf](https://github.com/zhaoc1/nanoflow/blob/master/bioinfo_report.pdf). 

- `/reports/01_basecalled_reads`/{barcode}/reads.aln.tsv
- `/reports/04_canu`/{barcode}/asm.aln.tsv
- `/reports/05_nanopolish`/{barcode}/asm.aln.tsv
- `/reports/07_pilon`/{barcode}/asm.aln.tsv
- `/reports/08_unicycler`/{barcode}/asm.aln.tsv
- `/reports/09_unicycler_long`/{barcode}/asm.aln.tsv


### Genome Annotation
We used [Prokka](https://github.com/tseemann/prokka) to annotate the genome.
- rgi
Further research:
- core and pangenome analysis: https://github.com/zhaoc1/coreSNPs


