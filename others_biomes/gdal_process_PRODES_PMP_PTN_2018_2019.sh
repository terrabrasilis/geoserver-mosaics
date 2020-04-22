#!/bin/bash
echo

# NOTE: Pantanal and Pampa - Years 2018 and 2019

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
    echo "Example: path/gdal_process_PRODES_PMP_PTN_2018_2019.sh 2018"
    echo
    exit 1
    fi

echo
echo "----- Start processing -----"

mydir=$(pwd)
printf $mydir

echo
echo "Shapefile"
## PANTANAL
shapefile="/[path]/shapefiles/limite_pantanal/biome_border_4326.shp"
## PAMPA
#shapefile="[path]/shapefiles/limite_pampa/biome_border_4326.shp"

printf $shapefile

echo
echo "----- Define NoData -----"
echo
dir=tempNoData
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
echo "----- Define EPSG:4326 -----"
echo
cd tempNoData/
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


echo "----- Scale from Float32 to UInt16 -----"
echo
cd tempEPSG4326/
dir=tempUInt16
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdal_translate -of GTiff -ot UInt16 "$file" "${dir}/${file}_UInt16"
  echo
done

echo
for file1 in $dir/*.tif_UInt16; do
  printf '%s\n' "${file1%.*}_UInt16.tif"
  newname="${file1%.*}_UInt16.tif"
  mv -- "$file1" "$newname"
  echo
done


echo "----- Scale from UInt16 to Byte -----"
echo
cd tempUInt16/
dir=tempByte
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdal_translate -of GTiff -ot Byte -scale -a_nodata 0 "$file" "${dir}/${file}_Byte"
  echo
done

echo
for file1 in $dir/*.tif_Byte; do
  printf '%s\n' "${file1%.*}_Byte.tif"
  newname="${file1%.*}_Byte.tif"
  mv -- "$file1" "$newname"
  echo
done

echo "----- Move to trash nodata folder -----"
mv ${mydir}/tempNoData/tempEPSG4326/tempUInt16/tempByte ${mydir}
mv ${mydir}/tempNoData/ ~/.local/share/Trash/files/

echo
echo "----- Merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempByte/*.tif
echo

echo
echo "----- Change nodata value 0 0 0 -> 0 0 1 -----"
gdalwarp -srcnodata "0 0 0" -dstnodata "0 0 1" ${mydir}/mosaic_${year}_border.tif ${mydir}/mosaic_${year}_border2.tif
echo

echo
echo "----- Cut mosaic by biome limits -----"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${mydir}/mosaic_${year}_border2.tif ${mydir}/mosaic_${year}.tif
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
