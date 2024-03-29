#!/bin/bash
echo

# NOTE: change from 16bits to 8btis, change nodata value to 0, projection to EPSG: 4326, and merge scenes as a mosaic. Years 2015 and 2017

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
    echo "Example: path/gdal_process_PRODES_CERRADO_2015_2017_newborder_valpha.sh 2015"
    echo
    exit 1
    fi

echo
echo "----- Start processing -----"

mydir=$(pwd)
printf $mydir

echo
echo "Shapefile"
## CERRADO
shapefile="/[path]/shapefiles/limite_cerrado/cerrado_border_new_ibge_4326.shp"


printf $shapefile
#set -e

echo
echo "----- gdal from 16bits to 8bits -----"
echo
dir=temp8bits
mkdir -p $dir

for file in *.tif; do  #for file in *16bits*.tif; do 
  echo $file
  gdal_translate -scale -ot Byte -a_nodata 0 -of GTiff "$file" "${dir}/${file}_8bits" 
  #0 65535 0 255
  echo
done

echo
for file1 in $dir/*.tif_8bits; do
   printf '%s\n' "${file1}"
   newname="${file1%.*}.tif"
   printf '%s\n' "$newname"
   mv "$file1" "$newname"
   echo
done

# new name
echo
for file2 in $dir/*16bits*.tif; do
    printf '%s\n' "${file2}"
    newname2="${file2//16bits/8bits}"
    printf '%s\n' "$newname2"
    mv "$file2" "$newname2"
    echo
done


echo
echo "----- gdal NoData -----"
echo
cd temp8bits/
dir=tempNoData0
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdal_translate -a_nodata 0 -of GTiff "$file" "${dir}/${file}_nodata"
  echo
done

echo
for file1 in $dir/*.tif_nodata; do
  printf '%s\n' "${file1%.*}_nodata.tif"
  newname="${file1%.*}_nodata.tif"
  mv -- "$file1" "$newname"
  echo
done

echo
echo "----- gdal EPSG:4326 -----"
echo
cd tempNoData0/
dir=tempEPSG4326
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdalwarp -dstnodata 0 -t_srs EPSG:4326 -of GTiff "$file" "${dir}/${file}_4326"
  echo
done

echo
for file1 in $dir/*.tif_4326; do
  printf '%s\n' "${file1%.*}_4326.tif"
  newname="${file1%.*}_4326.tif"
  mv -- "$file1" "$newname"
  echo
done

echo
echo "----- gdal Remove Band Alpha -----"
echo
cd tempEPSG4326/
dir=tempNoAlphaBand
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdal_translate -b 1 -b 2 -b 3 -of GTiff "$file" "${dir}/${file}_noalpha"
  echo
done

echo
for file1 in $dir/*.tif_noalpha; do
  printf '%s\n' "${file1%.*}_noalpha.tif"
  newname="${file1%.*}_noalpha.tif"
  mv -- "$file1" "$newname"
  echo
done

echo
echo "----- gdal NoData -----"
echo
cd tempNoAlphaBand/
dir=tempNoData
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdalwarp -of GTiff -t_srs EPSG:4326 -srcnodata "255 255 255" -dstnodata "0 0 0" "$file" "${dir}/${file}_nodata"
  echo
done

echo
for file1 in $dir/*.tif_nodata; do
  printf '%s\n' "${file1%.*}_nodata.tif"
  newname="${file1%.*}_nodata.tif"
  mv -- "$file1" "$newname"
  echo
done

echo "----- move to trash nodata folder -----"
mv ${mydir}/temp8bits/tempNoData0/tempEPSG4326/tempNoAlphaBand/tempNoData/ ${mydir}
mv ${mydir}/temp8bits/ ~/.local/share/Trash/files/
echo

echo
echo "----- merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempNoData/*.tif
echo

echo
echo "----- gdal cutline -----"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${mydir}/mosaic_${year}_border.tif ${mydir}/mosaic_${year}.tif
echo

cd ${mydir}/
dir=$year
mkdir -p $dir
echo "----- Directory created: ${dir} -----"
echo 

echo
echo "----- retile mosaic -----"
gdal_retile.py -v -r bilinear -levels 4 -ps 2048 2048 -ot Byte -co "TILED=YES" -co "COMPRESS=LZW" -targetDir ${year} ${mydir}/mosaic_${year}.tif
echo

echo "Script has been executed successfully"
echo


