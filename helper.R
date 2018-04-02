library(readr)
library(reshape2)
library(ggplot2)
library(gridExtra)
library(grid)
library(dplyr)
library(tidyr)
library(ggbeeswarm)
library(scales)
library(stringr)
library(RColorBrewer)
library(viridis)

load_tsv_data <- function(filename, column_names) {
  if(file.exists(filename)) {
    data <- read_tsv(filename, skip = 1, col_names = column_names)
  }
  else {
    data <- data.frame(matrix(ncol = 4, nrow = 0))
    colnames(data) <- column_names
  }
  return(data)
}


read_assembly_assess_plot <- function(report_fp, runnum, barcode){
  column_names=c("Name","Length","Identity","Relative.length")
  
  read_tsv <- file.path(runnum, report_fp, "01_basecalled_reads", barcode, "reads.aln.tsv")
  read_data <- load_tsv_data(read_tsv, column_names)
  
  canu_tsv <- file.path(runnum, report_fp, "04_canu", barcode, "asm.aln.tsv")
  canu_data <- load_tsv_data(canu_tsv, column_names)
  
  nanopolish_tsv <- file.path(runnum, report_fp, "05_nanopolish", barcode, "asm.aln.tsv")
  nanopolish_data <- load_tsv_data(nanopolish_tsv, column_names)
  
  pilon_tsv <- file.path(runnum, report_fp, "07_pilon", barcode, "asm.aln.tsv")
  pilon_data <- load_tsv_data(pilon_tsv, column_names)
  
  unicycler_tsv <- file.path(runnum, report_fp, "08_unicycler", barcode, "asm.aln.tsv")
  unicycler_data <- load_tsv_data(unicycler_tsv, column_names)
  
  ##### plot time #####
  ranges <- seq(50000,150000,5000)
  maxLen <- max(read_data$Length)
  maxLabel <- ranges[which.min(abs(ranges-maxLen))]
  
  my_theme <- theme_bw() + theme(panel.grid.major.x = element_blank())
  fill_scale <- scale_fill_brewer(palette = "Set1")
  
  
  p1 <- read_data %>% 
    ggplot(aes(x=Length)) +
    geom_histogram(binwidth = 1000, color="black", fill="grey") +
    theme_classic() +
    theme_bw() + 
    xlab("Read length") +
    ylab("") +
    scale_y_log10(breaks=c(1, 10, 100, 1000, 10000, 10000)) +
    scale_x_continuous(breaks= c(0, 10000, 20000, 30000, 40000, 50000, 60000), labels = scales::comma) +
    coord_cartesian(xlim=c(0, 60000)) +
    theme(plot.title = element_text(hjust = 0.5))
  
  p2 <- read_data %>%
    ggplot(aes(x=Length)) +
    geom_histogram(binwidth = 1000, color="black", fill="grey") +
    theme_classic() +
    theme_bw() + 
    xlab("Read length") +
    ylab("") +
    coord_cartesian(xlim=c(60000, maxLabel)) +
    scale_y_log10(breaks=c(1, 10, 100, 1000, 10000, 10000)) +
    scale_x_continuous(breaks= seq(60000,maxLabel,10000), labels = scales::comma) +
    theme(plot.title = element_text(hjust = 0.5))
  
  g1 <- read_data %>% 
    ggplot(aes(x = 1, y = Identity, weight = Length)) +
    geom_hline(yintercept = 100) + 
    geom_violin(draw_quantiles = c(0.5), bw=0.6) +
    fill_scale + my_theme + guides(fill=FALSE) +
    scale_y_continuous(expand = c(0, 0), breaks = seq(0, 100, 10), minor_breaks = seq(0, 100, 5), labels = scales::unit_format("%")) +
    scale_x_discrete() +
    coord_cartesian(ylim=c(65, 100)) +
    labs(title = "", x = "", y = "Reads identity")
  
  g2 <- read_data %>%
    ggplot(aes(x = 1, y = Identity, weight = Length)) +
    geom_violin(draw_quantiles = c(0.5), width=1.1, bw=0.6) +
    fill_scale + my_theme + guides(fill=FALSE) +
    scale_y_continuous(expand = c(0, 0), breaks = seq(0, 100, 5), minor_breaks = seq(0, 100, 1), labels = scales::unit_format("%")) +
    scale_x_discrete() +
    coord_cartesian(ylim=c(0, 5)) +
    labs(x = "", y = "")
  
  g3 <- read_data %>% 
    mutate(Relative.length = ifelse(is.na(Relative.length), 0, as.numeric(Relative.length))) %>%
    ggplot(aes(x = 1, y = Relative.length, weight = Length)) +
    geom_hline(yintercept = 100) + 
    geom_violin(draw_quantiles = c(0.5), bw=0.06) +
    fill_scale + my_theme + guides(fill=FALSE) +
    scale_y_continuous(expand = c(0, 0), breaks = seq(0, 200, 4), minor_breaks = seq(0, 200, 1), labels = scales::unit_format("%")) +
    scale_x_discrete() +
    coord_cartesian(ylim=c(88, 112)) +
    labs(title = "", x = "", y = "Relative read length")
  
  ## I saw this on the DC nanopore day again
  g4 <- read_data %>%
    ggplot(aes(x = Length, y = Identity)) +
    geom_point() + 
    geom_hline(yintercept = 85, linetype = "longdash", color="red") + 
    fill_scale + my_theme + guides(fill=FALSE) +
    labs(title = "", x = "", y = "Identity")
  
  f1 <- canu_data %>%
    ggplot(aes(x = 1, y = Identity, weight = Length))+ 
    geom_violin(draw_quantiles = c(0.5), bw=0.5) +
    fill_scale + my_theme + guides(fill=FALSE) + 
    scale_y_continuous(expand = c(0, 0), breaks = seq(0, 100, 0.5), minor_breaks = seq(0, 100, 0.1), labels = scales::unit_format("%")) +
    scale_x_discrete() +
    coord_cartesian(ylim=c(95, 100)) +
    labs(title = "", x = "", y = "Canu")
  
  f2 <- nanopolish_data %>%
    ggplot(aes(x = 1, y = Identity, weight = Length))+ 
    geom_violin(draw_quantiles = c(0.5), bw=0.5) +
    fill_scale + my_theme + guides(fill=FALSE) + 
    scale_y_continuous(expand = c(0, 0), breaks = seq(0, 100, 0.5), minor_breaks = seq(0, 100, 0.1), labels = scales::unit_format("%")) +
    scale_x_discrete() +
    coord_cartesian(ylim=c(95, 100)) +
    labs(title = "", x = "", y = "Nanopolish")
  
  f3 <- pilon_data %>%
    ggplot(aes(x = 1, y = Identity, weight = Length))+ 
    geom_violin(draw_quantiles = c(0.5), bw=0.5) +
    fill_scale + my_theme + guides(fill=FALSE) + 
    scale_y_continuous(expand = c(0, 0), breaks = seq(0, 100, 0.5), minor_breaks = seq(0, 100, 0.1), labels = scales::unit_format("%")) +
    scale_x_discrete() +
    coord_cartesian(ylim=c(95, 100)) +
    labs(title = "", x = "", y = "Pilon")
  
  f4 <- unicycler_data %>%
    ggplot(aes(x = 1, y = Identity, weight = Length))+ 
    geom_violin(draw_quantiles = c(0.5), bw=0.5) +
    fill_scale + my_theme + guides(fill=FALSE) + 
    scale_y_continuous(expand = c(0, 0), breaks = seq(0, 100, 0.5), minor_breaks = seq(0, 100, 0.1), labels = scales::unit_format("%")) +
    scale_x_discrete() +
    coord_cartesian(ylim=c(95, 100)) +
    labs(title = "", x = "", y = "Unicycler")
  
  
  gA <- ggplot_gtable(ggplot_build(g1))
  gB <- ggplot_gtable(ggplot_build(g2))
  maxWidth = grid::unit.pmax(gA$widths[2:3], gB$widths[2:3])
  gA$widths[2:3] <- as.list(maxWidth)
  gB$widths[2:3] <- as.list(maxWidth)
  
  set.seed(123)
  grid.newpage()
  grid.arrange(p1, p2, gA, gB, g3, g4, f1, f2, f3, f4, ncol=4,
               heights=c(3,2,1,3),
               layout_matrix = rbind(c(1,1,2,2), c(3,5, 6,6),c(4,5,6,6),c(7,8,9,10)),
               top=paste("Read Length Distributuion for", paste(runnum, barcode, sep=":")),
               left="Read Level",
               bottom="Assembly Level")
}

read_mummer_coords_file <- function(filename){
  
  con  <- file(filename, open = "r")
  
  coords_list <- list()
  row = 1
  
  while (length(oneLine <- readLines(con, n = 1, warn = FALSE)) > 0) {
    if (grepl("\\|", oneLine)) {
      oneLine <- gsub("\\|", "", oneLine)
      line = str_extract_all(oneLine, "\\S+") %>% unlist()
      if (length(line) == 13) {
        coords_list[[row]] <- line
        row <- row + 1
      }
    }
  }
  
  close(con)
  
  aln.df <- do.call(rbind, coords_list) %>% as.data.frame()
  colnames(aln.df) <- c("S1", "E1","S2", "E2","LEN1","LEN2","IDY","LEN_R","LEN_Q","COV_R","COV_Q","R","Q")
  
  aln.df %<>%
    mutate(S1 = as.numeric(as.character(S1))) %>%
    mutate(S2 = as.numeric(as.character(S2))) %>%
    mutate(E1 = as.numeric(as.character(E1))) %>%
    mutate(E2 = as.numeric(as.character(E2))) %>%
    mutate(LEN1 = as.numeric(as.character(LEN1))) %>% # len of aln region in ref seq
    mutate(LEN2 = as.numeric(as.character(LEN2))) %>% # len of aln region in query
    mutate(IDY = as.numeric(as.character(IDY))) %>%
    mutate(LEN_R = as.numeric(as.character(LEN_R))) %>%
    mutate(LEN_Q = as.numeric(as.character(LEN_Q))) %>%
    mutate(COV_R = as.numeric(as.character(COV_R))) %>%
    mutate(COV_Q = as.numeric(as.character(COV_Q))) %>%
    mutate(R = as.character(R)) %>%
    mutate(Q = as.character(Q)) %>%
    mutate(Q = str_extract(Q, "[[:digit:]]+")) %>% 
    mutate(Q = gsub("000000", "", Q))
    
}

collect_aln_points <- function(temp){
  #######################
  # these should be a repeat
  # start from the most simple one
  # now let's add color
  #######################
  
  #temp <- aln.df.12[1:10,]
  plot.df <- list()
  count = 1
  for (ti in 1:dim(temp)[1]){
    plot.df[[count]] <- data.frame(X = temp[ti, "S1"], Y = temp[ti, "S2"], IDY = temp[ti, "IDY"], Group = ti, Ref = temp[ti, "R"], Query = temp[ti, "Q"])
    plot.df[[count + 1]] <- data.frame(X = temp[ti, "E1"], Y = temp[ti, "E2"], IDY = temp[ti,"IDY"], Group = ti, Ref = temp[ti, "R"], Query = temp[ti, "Q"])
    
    count = count + 2
  }
  
  do.call(rbind, plot.df)
  
}

show_coords_plot <- function(aln.df){
  ## Kyle:
  fa1 <- aln.df %>% ggplot() + geom_histogram(aes(LEN1))
  fa2 <- aln.df %>% filter(LEN1 < 10000) %>% ggplot() + geom_histogram(aes(x = LEN1))
  fa3 <- aln.df %>% filter(LEN1 < 10000) %>% ggplot() + geom_point(aes(x = LEN1, y = IDY))
  ## basec on fa3: we filtered out IDY < 80
  plot.df <- collect_aln_points(aln.df)
  
  fig <- plot.df %>%
    filter(IDY >= 80) %>% 
    mutate(Ref = gsub("_pilon", "", Ref)) %>%
    ggplot(aes(x = X, y = Y, group=Group, color=IDY)) +
    geom_line(size=1) + 
    theme_bw() +
    labs(x = "Ref pos", y="Qry pos") +
    scale_color_viridis(option = "viridis", direction=-1) +
    theme(panel.grid.major.x = element_blank(), panel.grid.major.y = element_blank()) +
    facet_grid(Query ~ Ref, scales="free") 
  fig
}

find_missing_region <- function(ref.df){
  refLen <- max(ref.df$LEN_R)
  refpos <- rep(0, refLen)
  
  for (ri in 1:dim(ref.df)[1]){
    start = min(c(ref.df[ri, "S1"], ref.df[ri, "E1"]))
    end = max(c(ref.df[ri, "S1"], ref.df[ri, "E1"]))
    refpos[start:end] <-  refpos[start:end] + 1
  }
  
  pos_compressed <- which(refpos > 1)
  pos_missed <- which(refpos == 0)
  
  pos_missed
}

show_missing_refpos <- function(aln.df.12){
  ## This is good: look for regions of x that is not covered by y alignment
  # first extract alns to refID 
  # we also want to know if there are small assemblies mapped to the big assembly, so dont do any Query filter
  
  pos_missed <- find_missing_region(aln.df.12 %>% filter(R == "tig00000001_pilon") )
  
  my_theme <- theme_bw() + theme(panel.grid.major.x = element_blank())
  
  f4 <- collect_aln_points(aln.df.12) %>%
    filter(Ref == "tig00000001_pilon") %>%
    ggplot(aes(x = X, y = Y, group=Group, color=Query)) +
    geom_line(size=1) + 
    theme_bw() +
    geom_vline(xintercept = pos_missed, lty = "dashed", color="red") +
    my_theme  +
    scale_color_viridis(option = "viridis", direction=1, discrete = TRUE) +
    labs(x = "Pilon", y="Unicycler") +
    facet_grid(Query ~ Ref, scales="free")
  
  f4
}
  
show_dot_plot <- function(report_fp, runnum, barcode){
  fp_pilon <- file.path(runnum, report_fp,"09_eval/nucmer", barcode, "ref_draft1.coords")
  fp_unicycler <- file.path(runnum, report_fp, "09_eval/nucmer", barcode, "ref_draft2.coords")
  fp_draft12 <- file.path(runnum, report_fp,"09_eval/nucmer", barcode, "draft1_draft2.coords")
  
  aln.df.1 <- read_mummer_coords_file(fp_pilon)
  refLen = max(aln.df.1$LEN_R)
  f1 <- show_coords_plot(aln.df.1) + theme(legend.position="none") + labs(y = "Pilon") +
    geom_abline(intercept = 0, slope = 1, lty = "dotted", color="pink") +
    geom_abline(intercept = refLen, slope = -1, lty = "dotted", color="pink") 
  ## too messy for ref genome
  #pos_missed <- find_missing_region(aln.df.1)
  #f1 + geom_vline(xintercept = pos_missed, lty = "dashed", color="red") 
  
  aln.df.2 <- read_mummer_coords_file(fp_unicycler)
  refLen = max(aln.df.2$LEN_R)
  f2 <- show_coords_plot(aln.df.2) + theme(legend.position="none") + labs(y = "Unicycler") +
    geom_abline(intercept = 0, slope = 1, lty = "dotted", color="pink") +
    geom_abline(intercept = refLen, slope = -1, lty = "dotted", color="pink") 
  
  aln.df.12 <- read_mummer_coords_file(fp_draft12)
  refLen = max(aln.df.12$LEN_R)
  f12 <- show_coords_plot(aln.df.12)
  
  f4 <- show_missing_refpos(aln.df.12) + theme(legend.position="none") +
    geom_abline(intercept = 0, slope = 1, lty = "dotted", color="pink") +
    geom_abline(intercept = refLen, slope = -1, lty = "dotted", color="pink") 
  

  grid.newpage()
  grid.arrange(f1, f2, f12, f4, ncol=3,
               layout_matrix = rbind(c(1,2,4), c(3,3,3), c(3,3,3)),
               top=paste("Assembly Comparisons for ", paste(runnum, barcode, sep=":")))
}

read_assembly_stats <- function(report_fp, runnum, barcode){
  file_raw <- file.path(runnum,report_fp,"01_basecalled_reads", barcode, "reads.asm.stats")
  content <- read_lines(file_raw)
  
  line.stats <- content[startsWith(content, "sum")]
  total <- as.numeric(str_match(line.stats, "sum = ([^,]*)")[2])
  n <- as.numeric(str_match(line.stats, "n = ([^,]*)")[2])
  ave <- as.numeric(str_match(line.stats, "ave = ([^,]*)")[2])
  largest <- as.numeric(str_match(line.stats, "largest = ([^,]*)")[2])
  N50 <- str_match(content[startsWith(content, "N50")], "N50 = ([^,]*)")[2]
  
  data.frame(run = runnum, barcode  = barcode, total = total, n = n, ave = ave, largest=largest, N50 = N50)
}

show_gage <- function(report_fp, runnum, barcode){
  file_gage <- file.path(runnum, report_fp,"09_eval/quast_results",barcode,"gage_report.txt")
  content <- read_lines(file_gage)
  t2 <- textGrob(paste(content[3:length(content)], collapse = '\n'))
  
  grid.arrange(t2, ncol=1,top=paste("Assembly GAGE report for", paste(runnum, barcode, sep=":")))
}
