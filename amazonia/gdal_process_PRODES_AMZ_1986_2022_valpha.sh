#!/bin/bash
echo

# NOTE: script to generate mosaics to No Forest for Amazon biome for the years: 1980, 2000, 2002, 2004, 2006, 2008, 2010, 2013, 2014, 2016, 2018, 2019, 2020, 2021 e 2022.
# Need to define the year of the mosaic
# Link: http://terrabrasilis.dpi.inpe.br/geoserver/prodes-amazon-nb/wms?service=WMS&version=1.1.0&request=GetMap&layers=prodes-amazon-nb%3Atemporal_mosaic_amazon_1980&bbox=-73.983162%2C-16.6619941132773%2C-43.3993356873114%2C5.269517&width=768&height=550&srs=EPSG%3A4326&format=application/openlayers&TIME=2022
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
    echo "Example: [PATH_WITH_IMAGES]/gdal_process_PRODES_AMZ_1986_2022_valpha.sh 2020"
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
shapefile="/[path]/shapefiles/limite_amazonia/amz_border_4326_newIBGE.shp" # <- CHANGE ME
printf $shapefile

echo
shapefile_grid="/[path]/shapefiles/limite_amazonia/grid_landsat_tm_Amz_biome_4326_newIBGE_v2.shp" # <- CHANGE ME
printf $shapefile_grid

rscript_file="/[path]/script_r_cut_images_by_grid_amazonia.R" # <- CHANGE ME

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
#mv ${mydir}/tempCopy/ ~/.local/share/Trash/files/
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

