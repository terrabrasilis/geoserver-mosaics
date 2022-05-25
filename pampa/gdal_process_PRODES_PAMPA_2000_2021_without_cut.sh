#!/bin/bash
echo

# NOTE: Pampa biome - Years 2000, 2004, 2006, 2008, 2010, 2011, 2013, 2014, 2016, 2017, 2018, 2019, 2020 and 2021.
# landsat grid shapefile with feature "pathrow" in format 00527, 5 digits, not in format 005/27 
# Without to cut by Landsat grid

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
    echo "Example: /path/gdal_process_PRODES_PAMPA_2000_2021_without_cut.sh 2018"
    echo
    exit 1
    fi

echo
echo "----- Start processing -----"

mydir=$(pwd)
printf $mydir

echo
echo "Shapefile"

## PAMPA
shapefile="/[path]/shapefiles/limite_pampa/biome_border_4326.shp"
printf $shapefile

shapefile_grid="/[path]/shapefiles/limite_pampa/grid_landsat_tm_Pampa_crop_4326_2.shp"
printf $shapefile_grid

echo
echo "----- gdal from 16bits to 8bits -----"
echo
dir=temp8bits
mkdir -p $dir

for file in *.tif; do   
  echo $file
  gdal_translate -scale -ot Byte -a_nodata 0 -of GTiff "$file" "${dir}/${file}_8bits" 
  #0 65535 0 255
  echo
done

echo
for file1 in $dir/*.tif_8bits; do
  printf '%s\n' "${file1%.*}_8bits.tif"
  newname="${file1%.*}_8bits.tif"
  mv -- "$file1" "$newname"
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


echo "----- Change UInt16 to Byte -----"
echo
cd tempNoAlphaBand/
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


echo "----- move to trash nodata folder -----"
mv ${mydir}/temp8bits/tempNoData0/tempEPSG4326/tempNoAlphaBand/tempByte/ ${mydir}
mv ${mydir}/temp8bits/ ~/.local/share/Trash/files/
echo

# # if does not exist some images of the biome
# echo
# echo "----- merge all scenes -----"
# gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempByte/*.tif
# echo

# echo
# echo "----- gdal cutline -----"
# gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${mydir}/mosaic_${year}_border.tif ${mydir}/mosaic_${year}.tif
# echo

# if exist all images of the biome
echo
echo "----- merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempByte/*.tif
echo

echo
echo "----- change nodata value -----"
gdalwarp -srcnodata "0 0 0" -dstnodata "0 0 1" ${mydir}/mosaic_${year}_border.tif ${mydir}/mosaic_${year}_border2.tif
echo

echo
echo "----- gdal cutline -----"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${mydir}/mosaic_${year}_border2.tif ${mydir}/mosaic_${year}.tif
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
