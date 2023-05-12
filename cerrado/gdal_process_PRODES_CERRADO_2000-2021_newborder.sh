#!/bin/bash
echo

# NOTE: Cerrado biome - Years 2000, 2002, 2004, 2006, 2008, 2010, 2011, 2012, 2013, 2014, 2016, 2015, 2017, 2018, 2019, 2020 and 2021.
# Need to define the year of the mosaic
# Link: http://terrabrasilis.dpi.inpe.br/geoserver/prodes-cerrado-nb/wms?service=WMS&version=1.1.0&request=GetMap&layers=prodes-cerrado-nb%3Atemporal_mosaic_cerrado&bbox=-60.472596%2C-24.6817797920001%2C-41.277535892%2C-2.332088&width=659&height=768&srs=EPSG%3A4326&format=application/openlayers&TIME=2022
# chage parameter TIME=2022

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
    echo "Example: path/gdal_process_PRODES_CERRADO....sh 2000"
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
  gdalwarp -dstnodata 0 -t_srs EPSG:4326 "$file" "${dir}/${file}_4326"
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
mv ${mydir}/temp8bits/tempNoData0/tempEPSG4326/ ${mydir}
mv ${mydir}/temp8bits/tempNoData0/ ~/.local/share/Trash/files/
echo

echo
echo "----- merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempEPSG4326/*.tif
echo

echo
echo "----- change nodata value 0 0 0 -> 0 0 1 -----"
gdalwarp -srcnodata "0 0 0" -dstnodata "0 0 1" ${mydir}/mosaic_${year}_border.tif ${mydir}/mosaic_${year}_border2.tif
echo

echo
echo "----- gdal cutline -----"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${mydir}/mosaic_${year}_border2.tif ${mydir}/mosaic_${year}.tif
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


