#!/bin/bash
echo

# NOTE: gdal change from bands 564 Cerrado to compositon bands 654 Amazonia.

echo "Input year: $1"
year=$1

# verify parameter
if [ "$#" -eq 1 ]
    then
            if [ -d $year ]
            then
            echo Parameter ${year} defined
            fi
    else
    echo "Insert a parameter with year"
    echo "Example: path/gdal_process_PRODES_change_bands_CER_564_to_AMZ_654.sh 2020"
    echo
    exit 1
    fi

echo
echo "----- Start processing -----"

mydir=$(pwd)
printf $mydir

shopt -s nocasematch

echo
echo "----- gdal change from bands 564 Cerrado to compositon bands 654 Amazonia -----"
echo
dir=from564to654
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdal_translate -of GTiff -b 2 -b 1 -b 3 -ot Byte "$file" "${dir}/${file}_from564to654" 
  echo
done

echo
for file1 in $dir/*.tif_from564to654; do
  printf '%s\n' "${file1%.*}_from564to654.tif"
  newname="${file1%.*}_from564to654.tif"
  mv -- "$file1" "$newname"
  echo
done

echo

echo "Script has been executed successfully"
echo

