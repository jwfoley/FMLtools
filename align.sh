#! /bin/bash

read1_regex='_R1\.fastq\.gz$' # verify this file is read1
read1_to_name_regex="s/$read1_regex//" # convert read1 base filename to library name
read1_to_read2_regex='s/_R1\.fastq\.gz$/_R2.fastq.gz/' # convert read1 filename to read2 filename
n_thread=$(nproc)
samtools_path=samtools
common_samtools_options="-@ $n_thread"
view_options="-uF 0x4" # options for converting BWA's output to BAM for sorting; filters should go here (currently removes unaligned reads)
sort_options='-l 9 -m 1G -O CRAM --reference $genome_fasta' # allocates 1 GB RAM per thread (adjust for your hardware)
bwa_path='bwa-mem2 mem'
bwa_options="-p -t $n_thread"
trim_path='python3 -Om cutadapt'
trim_options="-j $n_thread --interleaved -a CTGTCTCTTATACACATCTCCGAGCCCACGAGAC -A CTGTCTCTTATACACATCTGACGCTGCCGACGA" # Nextera adapters

if [ ! -n "$2" ]
then
	echo "usage: $(basename $0) genome_prefix file1_R1.fastq.gz file2_R1.fastq.gz file3_R1.fastq.gz ..." >&2
	exit 1
fi

wd=$(pwd)
genome_prefix=$1
genome_fasta="$genome_prefix.fa"
if [ ! -f "$genome_fasta" ]; then
	echo "error: $genome_fasta not found; expect FASTA and BWA index files with same prefix" >&2
	exit 1
fi
shift 1

set -euo pipefail

for fastq_shortname in "$@"
do
	if [ $(grep $read1_regex <<< $fastq_shortname) ] # get only read1 filenames, then infer read2 filenames from them
	then
		fastq1=$(readlink -f $fastq_shortname)
		fastq2=$(sed $read1_to_read2_regex <<< $fastq1)
		library_name=$(basename $fastq_shortname | sed $read1_to_name_regex)
		
		echo "aligning $library_name..." >&2
		$trim_path $trim_options $fastq1 $fastq2 2>$library_name.trim.log |
			$bwa_path $bwa_options $genome_prefix /dev/stdin 2>$library_name.align.log |
			$samtools_path view $common_samtools_options $view_options |
			$samtools_path sort $common_samtools_options "$sort_options" - |
			tee $library_name.cram |
			$samtools_path index $common_samtools_options /dev/stdin $library_name.crai
		touch $library_name.crai # make sure the index is newer than the CRAM so it doesn't cause warnings later
		
		echo -e "aligned $library_name\n" >&2
	fi
done

