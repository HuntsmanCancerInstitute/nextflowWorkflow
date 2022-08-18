#!/bin/bash

#SBATCH --account=hci-kp
#SBATCH --partition=hci-kp
#SBATCH -J q2prPipe
#SBATCH --nodes=1
#SBATCH -e ./stderr.txt


# NOTES: Preprocesses (repair,import, check parameter for deblur2) of 16S sequences using qiime2 from multiple sequencing lanes and merging based on sample if needed.
# Because this uses Zac's V3V4 primers, trimming with  primers and adapters are done after importing to qiimme2 
# Manifest files are made on the fly.

#### User-defined variables #################################
workDir=${PWD}
READSDIR=$workDir/19768R
# Directory on scratch file system for intermediate files (will be created if not existing)
SCRATCH=$workDir/tmp
# The results directory for key outputs. Generally, your project directory or within it. (will be created if not existing)
ResultDir=$workDir/q2.deblur.result
# The qiime2 container image (update version tag as needed. Year.Month after "core:")
ContainerImage=/uufs/chpc.utah.edu/common/home/hcibcore/u0762203/microbiomeTestPipe/containers/qimme2.core_2021.11.sif
MAPBYGNOMEXID=$workDir/sampleSheet.txt
##############################################################
Nproc=`nproc`
echo $Nproc
Nproc=$((Nproc-2))
echo $Nproc

#### Param (depends on the primer used)###################################################
FPrimerSeqToTrim=TGCCTACGGGNBGCASCAG
RPrimerSeqToTrim=GCGACTACNVGGGTATCTAATCC
# Default minimum size after merge is set to Rprimer+Fprimer+10. Permissive, but remove most primer dimers
MinMergeLength=189


# Classifier will likely need to be retrained with differnt qiime versions as scikit classifier different versions are not compatible.
CLASSIFIER=/uufs/chpc.utah.edu/common/home/hcibcore/u0762203/microbiomeTestPipe/feature-classifiers/classifier.2011.11.qza


##############################################################
#### Setup ###################################################
module load singularity
mkdir -p ${SCRATCH}
mkdir -p ${SCRATCH}/tmp_XDG
mkdir -p ${SCRATCH}/tmp_sing
mkdir -p ${ResultDir}/q2_viz; mkdir -p ${ResultDir}/metadata
#############################################################
#### SINGULARITYENV (space & runtime issues) ################
XDG_RUNTIME_DIR=${SCRATCH}/tmp_XDG
SINGTEMPDIR=${SCRATCH}/tmp_sing
export SINGULARITYENV_XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}
export SINGULARITYENV_TMPDIR=${SINGTEMPDIR}
#############################################################
echo "VERSION: SINGULARITY: `singularity --version`"

# Part 1: Make manifest file on the fly, place in metadata file in project directory.
# Should allow for slightly changing naming schemes by core, but always assumes "_R1" somewhere in filename indicates read1 though.
echo "sample-id,absolute-filepath,direction" > ${ResultDir}/metadata/manifest_16SRawFiles.txt
cd $READSDIR
for f in *R1*fastq.gz
do
	SAMPLEID=`basename ${f%%_*}`
	echo "${SAMPLEID},${PWD}/${f},forward" >> ${ResultDir}/metadata/manifest_16SRawFiles.txt
	echo "${SAMPLEID},${PWD}/${f/_R1/_R2},reverse" >> ${ResultDir}/metadata/manifest_16SRawFiles.txt
done
MANIFEST=${ResultDir}/metadata/manifest_16SRawFiles.txt

# Part 2: Import sequences (this is slow)
cd ../

echo "TIME: START import = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' \
--input-path ${MANIFEST} \
--output-path ${SCRATCH}/inseqs-demux.qza \
--input-format PairedEndFastqManifestPhred33

singularity exec ${ContainerImage} qiime demux summarize \
  --i-data ${SCRATCH}/inseqs-demux.qza \
  --o-visualization ${SCRATCH}/inseqs-demux-summary.qzv  
echo "TIME: END import = `date +"%Y-%m-%d %T"`"

echo "TIME: START trim, merge = `date +"%Y-%m-%d %T"`"
singularity exec ${ContainerImage} qiime cutadapt trim-paired \
--i-demultiplexed-sequences ${SCRATCH}/inseqs-demux.qza \
--o-trimmed-sequences ${SCRATCH}/PE-demux_trim.qza \
--p-front-f ${FPrimerSeqToTrim} \
--p-front-r ${RPrimerSeqToTrim} \
--p-cores $Nproc

singularity exec ${ContainerImage} qiime vsearch join-pairs \
--i-demultiplexed-seqs ${SCRATCH}/PE-demux_trim.qza \
--o-joined-sequences ${SCRATCH}/PE-demux_trim_join.qza \
--p-minmergelen ${MinMergeLength} \
--verbose

singularity exec ${ContainerImage} qiime demux summarize \
  --i-data ${SCRATCH}/PE-demux_trim_join.qza \
  --o-visualization ${SCRATCH}/PE-demux_trim_join.qzv


echo "TIME: END trim, merge = `date +"%Y-%m-%d %T"`"


# Copy visualization results to ResultDir for inspection
cp ${SCRATCH}/*.qzv ${ResultDir}/q2_viz/


# At this stage plots(PE-demux_trim_join.qzv) should be inspected to infer the JoinedTrimLength for deblur (also double check --p-min-quality for quality-filter q-score-joined step). It should hold whenever using the same primer set though with good quality seq runs.
#deblur QC parameters:Position at which forward/reverse read sequences should be truncated due to decrease in quality, need to be adjusted according to inspection of inseqs-demux-summary.qza (shoot for middle box 20 - 30 maybe)

