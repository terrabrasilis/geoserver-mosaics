#!/bin/bash
#
# https://gdal.org/drivers/raster/gtiff.html
# GDAL_NUM_THREADS enables multi-threaded compression by specifying the number of worker threads.
# Worth it for slow compression algorithms such as DEFLATE or LZMA. Will be ignored for JPEG.
# Default is compression in the main thread. Note: this configuration option also apply to other
# parts to GDAL (warping, gridding, ...). Starting with GDAL 3.6, this option also enables multi-threaded
# decoding when RasterIO() requests intersect several tiles/strips.
# GDAL settings
#export CHECK_DISK_FREE_SPACE=NO
export GDAL_CACHEMAX=10%
export GDAL_NUM_THREADS=ALL_CPUS
#
# pixel size 30 meters in decimal degres of geographic projection
PIXEL_SIZE="0.0002689 0.0002689"

# NOTE: change nodata value to 0, projection to EPSG: 4326, change pixel size to 30 meters and merge scenes as a mosaic.

year=$1
biome=$2
data_dir=$3

TODAY_DATE=$(date '+%Y%m%d')
echo
echo "----- Testing input parameters  ${TODAY_DATE} -----"

# verify parameter
if [ "$#" -eq 3 ]
then
  if [[ -v year && -v biome && -v data_dir ]];
  then
    echo "Parameter year=${year}"
    echo "Parameter biome=${biome}"
    echo "Parameter data_dir=${data_dir}"
    echo "Mandatory parameters are defined. Let's test it."
  fi;
else
  CURRENT_YYYY=$(date '+%Y')
  echo "Insert a parameters:"
  echo " - with year YYYY;"
  echo " - the biome name like: amazonia or mata_atlantica;"
  echo " - the location directory where the input files are;"
  echo 
  echo "Example: ./gdal_process_prodes_images.sh ${CURRENT_YYYY} cerrado /pve12/share/cerrado/2023"
  echo
  exit 1
fi;

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
  echo "More details on log file: ${data_dir}/output_mosaic_${year}_${TODAY_DATE}.log"
else
  echo "Input tif files not found, aborting..."
  echo "Edit this script and set the correct location of input tif files."
  exit 1
fi;

exec > ${data_dir}/output_mosaic_${year}_${TODAY_DATE}.log 2>&1

echo "Test location of biome border shapefile"
echo
## Biome border in shapefile format. Used to clip the final mosaic
shapefile="${SCRIPT_LOCATION}/../shapefiles/limite_${biome}/${biome}_border_new_ibge_4326.shp" # <- CHANGE ME
fileExistsOrExit "${shapefile}"

shopt -s nocasematch

echo "Starting process: `date +%d-%m-%y_%H:%M:%S`"
echo
echo "----- gdal copy -----"
echo

cd ${data_dir}
tmp_dir=tempCopy
mkdir -p $tmp_dir
echo "Copying files to: ${tmp_dir}"

cp -a ${data_dir}/*.tif ${tmp_dir}/

echo "End of copying files: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- gdal reproject to EPSG:4326 AND Remove Alpha Band AND set NoData -----"
echo

cd ${tmp_dir}

for file in *.tif; do
  filename=$(getFilename "${file}")
  extension=$(getExtension "${file}")

  # read the source projection from input file
  SOURCE_SRC=""
  SRC_TEST="$(gdalinfo "${file}" 2>/dev/null | grep -oP 'GEOGCRS\["unknown",')"
  if [[ " GEOGCRS[\"unknown\", " = " ${SRC_TEST} " ]]; then
    # if is unknown so force the EPSG: 4674 (used on Cerrado imagens and need to be review for other biomes)
    echo "WARNING: found unknown projection for: ${file}"
    echo "WARNING: force geographical/SIRGAS 2000 (EPSG:4674) as INPUT projection."
    SOURCE_SRC="-s_srs EPSG:4674"
  fi;

  gdalwarp -of GTiff $SOURCE_SRC -t_srs "EPSG:4326" "${file}" "${filename}_4326.${extension}"
  gdal_translate -b 1 -b 2 -b 3 -of GTiff "${filename}_4326.${extension}" "${filename}_noalpha.${extension}"
  # get no data value
  NODATA_VALUE=$(gdalinfo "${filename}_noalpha.${extension}" | grep "NoData Value" | awk -F'=' '{print $2}' | head -n 1)
  # change pixel value from 0 to 1
  gdal_calc.py --co="COMPRESS=LZW" -A "${filename}_noalpha.${extension}" --A_band=1 \
  -B "${filename}_noalpha.${extension}" --B_band=1 \
  -C "${filename}_noalpha.${extension}" --C_band=1 \
  --calc="((A==0)*1 + (B==0)*1 + (C==0)*1)" \
  --outfile="${filename}_nodata_step_1.${extension}"
  # unset no data
  gdal_edit.py -unsetnodata "${filename}_nodata_step_1.${extension}"
  # change pixel value of no data to 0
  gdal_calc.py --co="COMPRESS=LZW" -A "${filename}_nodata_step_1.${extension}" --A_band=1 \
  -B "${filename}_nodata_step_1.${extension}" --B_band=1 \
  -C "${filename}_nodata_step_1.${extension}" --C_band=1 \
  --calc="((A==${NODATA_VALUE})*0 + (B==${NODATA_VALUE})*0 + (C==${NODATA_VALUE})*0)" \
  --outfile="${filename}_nodata.${extension}"
  # set no data to 0
  gdal_edit.py -a_nodata 0 "${filename}_nodata.${extension}"
done

echo "End of reproject to EPSG:4326: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${data_dir}/mosaic_${year}.tif ./*_nodata.tif
echo
echo "End of merge all scenes: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- remove temporary files -----"
cd -
rm -rf ${tmp_dir}

echo
echo "----- gdal cutline -----"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${data_dir}/mosaic_${year}.tif ${data_dir}/mosaic_${year}_${biome}.tif
echo
echo "End of cutline using shapefile of biome border: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- resample mosaic to 30m -----"
gdalwarp -ot Byte -of GTiff -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE -tr ${PIXEL_SIZE} ${data_dir}/mosaic_${year}_${biome}.tif ${data_dir}/mosaic_${year}_${biome}_30m.tif
echo
echo "End of resample mosaic: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- build overview mosaic -----"
gdaladdo --config COMPRESS_OVERVIEW LZW ${data_dir}/mosaic_${year}_${biome}.tif 2 4 8 16 32 64 128 256 512 1024 2048 4096
echo
echo "Script has been executed successfully"
echo
echo "THE END: `date +%d-%m-%y_%H:%M:%S`"
