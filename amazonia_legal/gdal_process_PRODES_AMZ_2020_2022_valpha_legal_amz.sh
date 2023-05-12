#!/bin/bash
echo

# NOTE: change nodata value to 0, projection to EPSG: 4326, and merge scenes as a mosaic. Year of 2021.
# Need to define the year of the mosaic
# Link: http://terrabrasilis.dpi.inpe.br/geoserver/prodes-legal-amz/wms?service=WMS&version=1.1.0&request=GetMap&layers=prodes-legal-amz%3Atemporal_mosaic_legal_amazon&bbox=-73.990972%2C-18.04176667%2C-43.9518271429269%2C5.272225&width=768&height=596&srs=EPSG%3A4326&format=application/openlayers&TIME=2022
# chage parameter TIME=2022

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
    echo "Example: path/gdal_process_PRODES_AMZ_2020_2022_valpha_legal_amz.sh 2022"
    echo
    exit 1
    fi

echo
echo "----- Start processing -----"

mydir=$(pwd)

exec > ${mydir}/output_mosaic_${year}.log 2>&1

echo "Inicio: `date +%d-%m-%y_%H:%M:%S`"

echo "Input year: $1"
printf $mydir


echo
echo "Shapefile"
## AMZ LEGAL
shapefile="/[path]/shapefiles/brazilian_legal_amazon/brazilian_legal_amazon_4326.shp" # <- CHANGE ME
printf $shapefile

shapefile_grid="/[path]/shapefiles/brazilian_legal_amazon/grid_landsat_brazilian_legal_amazon_4326.shp" # <- CHANGE ME
printf $shapefile_grid

rscript_file="/[path]/script_r_cut_images_by_grid_amz_legal.R" # <- CHANGE ME

shopt -s nocasematch

echo
echo "----- gdal copy -----"
echo
dir=tempCopy
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdalmanage copy "$file" "${dir}/${file}_copy"
  echo
done

echo
for file1 in $dir/*.tif_copy; do
  printf '%s\n' "${file1%.*}_copy.tif"
  newname="${file1%.*}_copy.tif"
  mv -- "$file1" "$newname"
  echo
done
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- gdal unset NoData -----"
echo
cd tempCopy/

for file in *.tif; do
  echo $file
  gdal_edit.py "$file" -unsetnodata
  echo
done
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- gdal EPSG:4326 -----"
echo
cd tempCopy/
dir=tempEPSG4326
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdalwarp -of GTiff -t_srs "+proj=longlat +ellps=WGS84" "$file" "${dir}/${file}_4326"
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

# --------------
# cd tempCopy/
#--------------

echo
echo "----- Cut band to bounding line -----"
echo
cd tempEPSG4326/
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
cd tempCutted_buffer/
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
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

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
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo "----- move to trash nodata folder -----"
mv ${mydir}/tempCopy/tempEPSG4326/tempCutted_buffer/tempNoAlphaBand/tempNoData/ ${mydir}
mv ${mydir}/tempCopy/ ~/.local/share/Trash/files/
echo

echo "----- merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempNoData/*.tif
echo
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- gdal cutline -----"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${mydir}/mosaic_${year}_border.tif ${mydir}/mosaic_${year}.tif
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
