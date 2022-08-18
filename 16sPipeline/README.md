# 16s processing and analysis pipeline
1. The 16sPipeline is QIIME2 based 16S rRNA data processing and analysis pipelines.
2. The 16S data processing pipelines are designed to process reads with V3V4 primer(Zymo Research cat# D6405-2-400), and are branched into two pipelines - gut micicrobe pipeline and enviromental microbe pipeline. Both of which are implemented with nextflow and fastqscreen for quick data processing and QC, and they use DADA2 for denoising for increased sensitivity. 
3. The gut micicrobe pipeline uses greengene database, and the enviromental microbe pipeline uses SILVA database. The enviromental microbe pipeline has an additional filter step, using fastqscreen filter mode to filter out Mitochondria and Plastid reads before import to QIIME2 to increase specificity.

- [pip4zacPrimer/](pip4zacPrimer/): Directory containing nextflow and bash scripts of a special version of gut micicrobe pipeline with in house V3V4 primer of June Round lab and using deblur for denoising.
    

* run on chpc:
* For example, in screen:
>
$module load nextflow
>
$nextflow run q2prescreenFilt.dsl2.nf --reads "/uufs/chpc.utah.edu/common/home/hcibcore/u0762203/microbiomeTestPipe/16s/testReads/*_R{1,2}*.fastq.gz" --fqsConfig "/uufs/chpc.utah.edu/common/home/hcibcore/u0762203/microbiomeTestPipe/16s/fastq_screen.conf"
>
$sb q2pipe16s.process.visualInspectBfDada2.sh
>
$sb q2pipe16s.process.sh 
