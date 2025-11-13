#!/bin/bash

# GDAL settings
#export CHECK_DISK_FREE_SPACE=NO
export GDAL_CACHEMAX=10%
export GDAL_NUM_THREADS=ALL_CPUS
#
# pixel size 30 meters in decimal degres of geographic projection
PIXEL_SIZE="0.0002689 0.0002689"

# get local dir
DATA_DIR=`pwd`
INPUT_FILE=${1}

if [[ ! -f ${DATA_DIR}/${INPUT_FILE} ]]; then

  echo "missing input file"
  echo
  echo "Use the ./resample-mosaic-from-10m-to-30m.sh inputfile.tif"
else

    # split filename and extension
    filename=$(basename -- "${INPUT_FILE}")
    extension="${filename##*.}"
    filename="${filename%.*}"
    OUTPUT_FILE="${filename}-30m.${extension}"

    if [[ -f ${DATA_DIR}/${OUTPUT_FILE} ]]; then
    echo "remove the old file to recreate"
    rm ${DATA_DIR}/${OUTPUT_FILE}
    fi;

    echo "${DATA_DIR}/${OUTPUT_FILE}"

    gdalwarp -ot Byte -of GTiff -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE \
    -tr ${PIXEL_SIZE} ${DATA_DIR}/${INPUT_FILE} ${DATA_DIR}/${OUTPUT_FILE}

fi;
