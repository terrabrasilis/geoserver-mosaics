#!/bin/bash
echo

# NOTE: change from Float32 to Int16, change nodata value to 0, projection to EPSG: 4326, and merge scenes as a mosaic. Years 2021

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
    echo "Example: path/gdal_process_PRODES_CERRADO_2021_sentinel_valpha.sh 2021"
    echo
    exit 1
    fi


mydir=$(pwd)

exec > ${mydir}/output_mosaic_${year}.log 2>&1

echo "Inicio: `date +%d-%m-%y_%H:%M:%S`"

echo "Input year: $1"
printf $mydir

echo
echo "----- Start processing -----"

echo
echo "Shapefile"
## CERRADO
shapefile="/[path]/shapefiles/mosaicos_terraclass/shp/limite_cerrado_antigo_novo_4326.shp"


printf $shapefile
#set -e


echo
echo "----- gdal choose bands RGB 843 Cerrado Sentinel -----"
echo
dir=to843
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdal_translate -of GTiff -b 4 -b 3 -b 2 -ot Int16 "$file" "${dir}/${file}_843_int16" 
  echo
done

echo
for file1 in $dir/*.tif_843_int16; do
  printf '%s\n' "${file1%.*}_843_int16.tif"
  newname="${file1%.*}_843_int16.tif"
  mv -- "$file1" "$newname"
  echo
done


echo
echo "----- gdal EPSG:4326 -----"
echo
cd to843/
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

echo "----- move to trash nodata folder -----"
mv ${mydir}/to843/tempEPSG4326/ ${mydir}
mv ${mydir}/to843/ ~/.local/share/Trash/files/
echo

echo
echo "----- merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempEPSG4326/*.tif
echo

echo
echo "----- gdal cutline -----"
gdalwarp -ot Int16 -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${mydir}/mosaic_${year}_border.tif ${mydir}/mosaic_${year}.tif
echo


cd ${mydir}/
dir=$year
mkdir -p $dir
echo "----- Directory created: ${dir} -----"
echo 

echo
echo "----- retile mosaic -----"
gdal_retile.py -v -r bilinear -levels 4 -ps 2048 2048 -ot Int16 -co "TILED=YES" -co "COMPRESS=LZW" -targetDir ${year} ${mydir}/mosaic_${year}.tif
echo

echo "Script has been executed successfully"
echo


