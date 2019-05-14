GeneFlow App Template
=====================

Version: 0.3

This GeneFlow template app wraps the BWA 0.7.17 mem tool.

Inputs
------

1. input: Sequence FASTQ File - A sequence file in the FASTQ file format.

2. pair: Paired-End Sequence FASTQ File - A paired-end sequence file in the FASTQ file format. The default value for this input is "null", and can be left blank for single-end sequence alignment.

3. reference: BWA Reference Index - A directory that contains a BWA reference index. This index includes multiple files. 

Parameters
----------

1. threads: CPU Threads - The number of CPU threads to use for sequence alignment. Default: 2.
 
2. output: Output SAM File - The name of the output SAM file to which alignment results should be written. Default: output.sam.

