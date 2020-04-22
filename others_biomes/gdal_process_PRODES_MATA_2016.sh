#!/bin/bash
echo

# NOTE: Mata Atlântica - 2016.

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
    echo "Example: path/gdal_process_PRODES_MATA_2016.sh 2018"
    echo
    exit 1
    fi

echo
echo "----- Start processing -----"

mydir=$(pwd)
printf $mydir

echo
echo "Shapefile"
## MATA ATLANTICA
shapefile="/[path]/shapefiles/limite_mata_atlantica/mata_atlantica_border_4326.shp"

printf $shapefile

echo
echo "----- Define EPSG:4326 -----"
echo
dir=tempEPSG4326
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdalwarp -t_srs EPSG:4326 "$file" "${dir}/${file}_4326"
  echo
done

echo
for file1 in $dir/*.tif_4326; do
  printf '%s\n' "${file1%.*}_4326.tif"
  newname="${file1%.*}_4326.tif"
  mv -- "$file1" "$newname"
  echo
done


echo "----- Change UInt16 to Byte -----"
echo
cd tempEPSG4326/
dir=tempByte
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdal_translate -of GTiff -ot Byte -scale "$file" "${dir}/${file}_Byte" 
  echo
done

echo
for file1 in $dir/*.tif_Byte; do
  printf '%s\n' "${file1%.*}_Byte.tif"
  newname="${file1%.*}_Byte.tif"
  mv -- "$file1" "$newname"
  echo
done


echo
echo "----- Define NoData -----"
echo
cd tempByte/
dir=tempNoData
mkdir -p $dir

echo
echo "----- Search by different nodata value - gdalinfo -----"
echo
for file in *.tif; do
  echo $file
  value=$(gdalinfo "$file" | grep -o 'NoData Value\=[-0-9]*' | uniq || echo "NoData Value=None" )
  echo $value

  if echo "$value" | grep -q "NoData\sValue\=0" ; then
      echo "NoData equals 0"
      gdal_translate -a_nodata 0 -of GTiff "$file" "${dir}/${file}_nodata"
  else
      echo "NoData DIFFERENT of 0"
      gdalwarp -srcnodata "255 255 255" -dstnodata "0 0 0" "$file" "${dir}/${file}_nodata"
  fi
  echo
done 

echo
for file1 in $dir/*.tif_nodata; do
  printf '%s\n' "${file1%.*}_nodata.tif"
  newname="${file1%.*}_nodata.tif"
  mv -- "$file1" "$newname"
  echo
done


echo "----- Move to trash nodata folder -----"
mv ${mydir}/tempEPSG4326/tempByte/tempNoData ${mydir}
mv ${mydir}/tempEPSG4326/ ~/.local/share/Trash/files/

echo
echo "----- Merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempNoData/*.tif
echo

echo
echo "----- Change nodata value 0 0 0 -> 0 0 1 -----"
gdalwarp -srcnodata "0 0 0" -dstnodata "0 0 1" ${mydir}/mosaic_${year}_border.tif ${mydir}/mosaic_${year}_border2.tif
echo

echo
echo "----- Cut mosaic by biome limits -----"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${mydir}/mosaic_${year}_border2.tif ${mydir}/mosaic_${year}.tif
echo

cd ${mydir}/
dir=$year
mkdir -p $dir
echo "----- Directory created: ${dir} -----"
echo 

echo
echo "----- Retile mosaic -----"
gdal_retile.py -v -r bilinear -levels 4 -ps 2048 2048 -ot Byte -co "TILED=YES" -co "COMPRESS=LZW" -targetDir ${year} ${mydir}/mosaic_${year}.tif
echo

echo "Script has been executed successfully"
echo
