#!/bin/bash
# NOTE: change nodata value to 0, projection to EPSG: 4326, and merge scenes as a mosaic. Year of 2021.
# Need to define the year of the mosaic
# Link: http://terrabrasilis.dpi.inpe.br/geoserver/prodes-legal-amz/wms?service=WMS&version=1.1.0&request=GetMap&layers=prodes-legal-amz%3Atemporal_mosaic_legal_amazon&bbox=-73.990972%2C-18.04176667%2C-43.9518271429269%2C5.272225&width=768&height=596&srs=EPSG%3A4326&format=application/openlayers&TIME=2022
# chage parameter TIME=2022

year=$1
data_dir="/pve12/share" # <- CHANGE ME
# verify parameter
if [ "$#" -eq 1 ]
then
  if [ -v year ]
  then
    echo Parameter ${year} defined
  fi;
else
  echo "Insert a parameter with year"
  echo "Example: ./gdal_process_PRODES_AMZ_2020_2022_valpha_legal_amz.sh 2022"
  echo
  exit 1
fi;

TODAY_DATE=$(date '+%Y%m%d')
echo
echo "----- Start processing -----"

# get location where the script is called.
mydir=$(pwd)

# get location where the script is
SCRIPT_LOCATION=$( dirname -- "$( readlink -f -- "$0"; )"; )
echo "where script file is: ${SCRIPT_LOCATION}"

if [[ ! -f "${SCRIPT_LOCATION}/../lib/functions.sh" ]];
then
  echo "Functions not found, aborting..."
  exit 1
fi;

cd ${SCRIPT_LOCATION}/../lib/
. ./functions.sh
cd -

# test if data dir has some tif file
FOUNDED_FILES=$(hasTiffFiles "${data_dir}")
if [[ ${FOUNDED_FILES} -gt 0 ]];
then
  echo "Input tif files found, proceeding..."
else
  echo "Input tif files not found, aborting..."
  exit 1
fi;

exec > ${data_dir}/output_mosaic_${year}_${TODAY_DATE}.log 2>&1

echo "Inicio: `date +%d-%m-%y_%H:%M:%S`"

echo "Input year: $1"

echo
echo "Shapefile"
## AMZ LEGAL
shapefile="${SCRIPT_LOCATION}/../shapefiles/brazilian_legal_amazon/brazilian_legal_amazon_4326.shp" # <- CHANGE ME
printf $shapefile
echo
shapefile_grid="${SCRIPT_LOCATION}/../shapefiles/brazilian_legal_amazon/grid_landsat_brazilian_legal_amazon_4326.shp" # <- CHANGE ME
printf $shapefile_grid

rscript_file="${SCRIPT_LOCATION}/script_r_cut_images_by_grid_amz_legal.R" # <- CHANGE ME

shopt -s nocasematch

echo
echo "----- gdal copy -----"
echo

cd ${data_dir}
dir=tempCopy
mkdir -p $dir

for file in *.tif; do
  filename=$(getFilename "${file}")
  extension=$(getExtension "${file}")
  echo $file
  gdalmanage copy "$file" "${dir}/${filename}_copy.${extension}"
done

echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- gdal unset NoData -----"
echo
cd ${dir}

for file in *.tif; do
  echo $file
  gdal_edit.py "$file" -unsetnodata
  echo
done
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- gdal EPSG:4326 -----"
echo

dir=tempEPSG4326
mkdir -p $dir

for file in *.tif; do
  filename=$(getFilename "${file}")
  extension=$(getExtension "${file}")
  echo $file
  gdalwarp -of GTiff -t_srs "+proj=longlat +ellps=WGS84" "$file" "${dir}/${filename}_4326.${extension}"
  echo
done

echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- Cut band to bounding line -----"
echo

cd ${dir}

current="$(pwd)/"
echo "$current"

function Rscript_with_status {
  if Rscript --vanilla ${rscript_file} ${shapefile_grid} "$current"
  then
    echo -e "0"
    echo
    echo "Fim: `date +%d-%m-%y_%H:%M:%S`"
    return 0
  else
    echo -e "1"
    echo
    echo "Fim: `date +%d-%m-%y_%H:%M:%S`"
    exit 1
  fi
}
Rscript_with_status

echo
echo "----- gdal Remove Band Alpha -----"
echo
# go to the directory crated by the Rscript
cd tempCutted_buffer/
dir=tempNoAlphaBand
mkdir -p $dir

for file in *.tif; do
  filename=$(getFilename "${file}")
  extension=$(getExtension "${file}")
  echo $file
  gdal_translate -b 1 -b 2 -b 3 -of GTiff "$file" "${dir}/${filename}_noalpha.${extension}"
  echo
done

echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- gdal NoData -----"
echo
cd tempNoAlphaBand/
dir=tempNoData
mkdir -p $dir

for file in *.tif; do
  filename=$(getFilename "${file}")
  extension=$(getExtension "${file}")
  echo $file
  gdalwarp -of GTiff -t_srs EPSG:4326 -srcnodata "255 255 255" -dstnodata "0 0 0" "$file" "${dir}/${filename}_nodata.${extension}"
  echo
done

echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo "----- move to trash nodata folder -----"
mv ${data_dir}/tempCopy/tempEPSG4326/tempCutted_buffer/tempNoAlphaBand/tempNoData/ ${data_dir}
rm -rf ${data_dir}/tempCopy/
echo

echo "----- merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${data_dir}/mosaic_${year}_border.tif ${data_dir}/tempNoData/*.tif
echo
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- gdal cutline -----"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${data_dir}/mosaic_${year}_border.tif ${data_dir}/mosaic_${year}.tif
echo
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

cd ${data_dir}/
dir=$year
mkdir -p $dir
echo "----- Directory created: ${dir} -----"
echo

echo
echo "----- retile mosaic -----"
gdal_retile.py -v -r bilinear -levels 4 -ps 2048 2048 -ot Byte -co "TILED=YES" -co "COMPRESS=LZW" -targetDir ${year} ${data_dir}/mosaic_${year}.tif
echo

echo "Script has been executed successfully"
echo
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"
