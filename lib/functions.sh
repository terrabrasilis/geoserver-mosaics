#!/bin/bash

# get filename without extension given file
getFilename(){
    file="${1}"
    filename=$(basename -- "${file}")
    filename="${filename%.*}"
    echo "${filename}"
}

# get extension given file
getExtension(){
    file="${1}"
    filename=$(basename -- "${file}")
    extension="${filename##*.}"
    echo "${extension}"
}

# test and count tif files into some directory
hasTiffFiles(){
    BASE_DIR="${1}"
    TRY_FOUND=(${BASE_DIR}/*.tif)
    FOUNDED_FILES=0
    if [ -f ${TRY_FOUND[0]} ]; then
        FOUNDED_FILES=`ls ${BASE_DIR}/*.tif |wc -l`
    fi;
    echo "${FOUNDED_FILES}"
}

# test if file exists in path, if not, exit
fileExistsOrExit(){
    FULL_PATH_AND_FILE="${1}"
    if [[ ! -f "${FULL_PATH_AND_FILE}" ]];
    then
        echo "${FULL_PATH_AND_FILE}"
        echo "File not found."
        exit 1
    fi;
}