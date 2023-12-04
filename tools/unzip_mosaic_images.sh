#!/bin/bash
# unZIP raster
BASE_DIR="$1"
# verify parameter
if [ "$#" -eq 1 ]
then
  if [[ -v BASE_DIR ]];
  then
    echo "Parameter BASE_DIR=${BASE_DIR} defined"
  fi;
else
  echo "Where is the input files?"
  echo "This script expect one parameter as base dir where the input files, in ZIP format, is...aborting"
  echo 
  exit 1
fi;

cp -a remove_double_cenes.sh ${BASE_DIR}/

cd ${BASE_DIR}

OUTPUT_DIR=$(date '+%Y')
mkdir -p ${OUTPUT_DIR}
echo "Putting files inside output dir: ${OUTPUT_DIR}"

find "$BASE_DIR" -type f -name '*.zip' |
while IFS= read fullfile;
do

    unzip -j -d ${OUTPUT_DIR}/ ${fullfile}

done

mv remove_double_cenes.sh ${OUTPUT_DIR}/
cd ${OUTPUT_DIR}
./remove_double_cenes.sh