#!/bin/bash
# Used to rename files using some pattern for input. The output name should be defined into code.
#
# get files from one path. Use ./rename_files.sh <path to dir>
BASE_DIR="$1"
find "$BASE_DIR" -type f -name '*_copy.tif' |
while IFS= read fullfile;
do
    # split filename and extension
    filename=$(basename -- "$fullfile")
    extension="${filename##*.}"
    filename="${filename%.*}"

    # change to new name
    p1=$(echo ${filename} | cut -d'_' -f1)
    p2=$(echo ${filename} | cut -d'_' -f2)
    p3=$(echo ${filename} | cut -d'_' -f3)
    p4=$(echo ${filename} | cut -d'_' -f4)
    p5=$(echo ${filename} | cut -d'_' -f5)
    p6=$(echo ${filename} | cut -d'_' -f6)

    new_filename="${p1}_${p2}_${p3}_${p4}_${p5}_${p6}"

    mv "$BASE_DIR/$filename.$extension" "$BASE_DIR/$new_filename.tif"

done
