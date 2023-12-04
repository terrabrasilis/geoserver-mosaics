#!/bin/bash
# NOTE: change nodata value to 0, projection to EPSG: 4326, and merge scenes as a mosaic.

year=$1
biome=$2
data_dir="/pve12/share/images" # <- CHANGE ME
# verify parameter
if [ "$#" -eq 2 ]
then
  if [[ -v year && -v biome ]];
  then
    echo "Parameter year=${year} defined"
    echo "Parameter biome=${biome} defined"
  fi;
else
  CURRENT_YYYY=$(date '+%Y')
  echo "Insert a parameter with year YYYY and the biome name like: amazonia or mata_atlantica"
  echo "Example: ./gdal_process_prodes_images.sh ${CURRENT_YYYY} cerrado"
  echo
  exit 1
fi;

TODAY_DATE=$(date '+%Y%m%d')
echo
echo "----- Start processing ${TODAY_DATE} -----"

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
echo "Searching tif files in: ${data_dir}"
if [[ ${FOUNDED_FILES} -gt 0 ]];
then
  echo "Input tif files found, proceeding..."
else
  echo "Input tif files not found, aborting..."
  echo "Edit this script and set the correct location of input tif files."
  exit 1
fi;

exec > ${data_dir}/output_mosaic_${year}_${TODAY_DATE}.log 2>&1

echo "Inicio: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "Shapefile"
## AMZ LEGAL
shapefile="${SCRIPT_LOCATION}/../shapefiles/limite_${biome}/${biome}_border_new_ibge_4326.shp" # <- CHANGE ME
printf $shapefile
echo
shapefile_grid="${SCRIPT_LOCATION}/../shapefiles/limite_${biome}/grid_landsat_${biome}_new_ibge_4326.shp" # <- CHANGE ME
printf $shapefile_grid

rscript_file="${SCRIPT_LOCATION}/script_r_cut_images_by_grid.R" # <- CHANGE ME

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
  # read the source projection from input file
  SOURCE_SRC=""
  SRC_TEST="$(gdalinfo Mosaico_Sentinel2_222076_20230611_20230721_8bits_8114_contraste.tif 2>/dev/null | grep -oP 'GEOGCRS\["unknown",')"
  if [[ " GEOGCRS[\"unknown\", " = " ${SRC_TEST} " ]]; then
    # if is unknown so force the EPSG: 4674 (used on Cerrado imagens and need to be reviw for other biomes)
    # -s_srs "EPSG:4674"
    SOURCE_SRC="-s_srs EPSG:4674"
  fi;

  gdalwarp -of GTiff $SOURCE_SRC -t_srs "EPSG:4326" "$file" "${dir}/${filename}_4326.${extension}"
  echo
done

echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- Cut band to bounding line -----"
echo

cd ${dir}

raster_dir="$(pwd)/"
echo "$raster_dir"

function Rscript_with_status {
  # shapefile_grid expect the path and full name of shapefile with grid for biome
  # raster_dir expect the path when tif files are. These tifs should be reprojected to EPSG:4326
  if Rscript --vanilla ${rscript_file} ${shapefile_grid} "${raster_dir}"
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

echo "----- move result dir to base dir and remove temporary dirs and files -----"
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
