#!/bin/bash
echo

# NOTE: change from Float32 to Byte, change nodata value to 0, projection to EPSG: 4326, and merge scenes as a mosaic. Years 2020

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
    echo "Example: path/gdal_process_PRODES_CERRADO_2020_sentinel_valpha.sh 2020"
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
shapefile="/[path]/shapefiles/Mosaicos_terraclass/limite_cerrado_4326.shp"

printf $shapefile
#set -e


echo
echo "----- gdal choose bands RGB 432 Cerrado Sentinel and from Float32 to Byte -----"
echo
dir=tempBands432
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdal_translate -of GTiff -b 4 -b 3 -b 2 -ot Byte -scale -a_nodata 0 "$file" "${dir}/${file}_432_byte" 
  echo
done

echo
for file1 in $dir/*.tif_432_byte; do
  printf '%s\n' "${file1%.*}_432_byte.tif"
  newname="${file1%.*}_432_byte.tif"
  mv -- "$file1" "$newname"
  echo
done
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"


echo
echo "----- script Cartaxo contraste img Byte input -----"
echo
cd tempBands432/
dir=tempPercentile
mkdir -p $dir
echo

for file in *.tif; do
  echo "$file"
  python /[path]/Mosaicos_terraclass/sentinel_hist.py "$file" 
  newname="${file%.*}_ctx.tif"
  mv -- "$newname" "$dir"
  echo
done
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- gdal EPSG:4326 -----"
echo
cd tempPercentile/
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
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"


echo "----- move to trash nodata folder -----"
mv ${mydir}/tempBands432/tempPercentile/tempEPSG4326/ ${mydir}
mv ${mydir}/tempBands432/ ~/.local/share/Trash/files/
echo

echo
echo "----- merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempEPSG4326/*.tif
echo
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- Change nodata value 0 0 0 -> 0 0 1 -----"
gdalwarp -srcnodata "0 0 0" -dstnodata "0 0 1" -multi -wo NUM_THREADS=10 -co BIGTIFF=YES ${mydir}/mosaic_${year}_border.tif ${mydir}/mosaic_${year}_border2.tif
echo
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- gdal cutline -----"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -multi -wo NUM_THREADS=10 -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${mydir}/mosaic_${year}_border2.tif ${mydir}/mosaic_${year}.tif
echo
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"


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
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

