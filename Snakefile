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

include: "preprocess.rules"
#include: "draft1.rules"
#include: "draft2.rules"

#onsuccess:
# print("Workflow finished, no error")
# shell("mail -s 'workflow finished' " + config['admins']+" <{log}")
#onerror:
# print("An error occurred")
# shell("mail -s 'an error occurred' " + config['admins']+" < {log}")
