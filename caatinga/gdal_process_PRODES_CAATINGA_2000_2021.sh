#!/bin/bash
echo

# NOTE: Caatinga biome - Years 2000, 2004, 2006, 2008, 2010, 2011, 2013, 2014, 2016, 2017, 2018, 2019, 2020 and 2021.
# landsat grid shapefile with feature "pathrow" in format 00527, 5 digits, not in format 005/27
# Need to define the year of the mosaic
# Link: http://terrabrasilis.dpi.inpe.br/geoserver/prodes-caatinga-nb/wms?service=WMS&version=1.1.0&request=GetMap&layers=prodes-caatinga-nb%3Atemporal_mosaic_caatinga&bbox=-45.078141%2C-16.71263667%2C-35.066981362%2C-2.748264&width=550&height=768&srs=EPSG%3A4326&format=application/openlayers&TIME=2021
# chage parameter TIME=2021

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
    echo "Example: /path/gdal_process_PRODES_CAATINGA_2000_2021.sh 2000"
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

## CAATINGA
#shapefile="/[path]/shapefiles/limite_caatinga/caatinga_border_4326_newIBGE.shp" # <- CHANGE ME
shapefile="/home/adeline/Dropbox/github_projects/geoserver-mosaics/shapefiles/limite_caatinga/caatinga_border_4326_newIBGE.shp" # <- CHANGE ME
printf $shapefile

#shapefile_grid="/[path]/shapefiles/limite_caatinga/grid_landsat_tm_Caatinga_crop_4326_newIBGE_v2.shp" # <- CHANGE ME
shapefile_grid="/home/adeline/Dropbox/github_projects/geoserver-mosaics/shapefiles/limite_caatinga/grid_landsat_tm_Caatinga_crop_4326_newIBGE_v2.shp" # <- CHANGE ME
printf $shapefile_grid

#rscript_file="/[path]/caatinga/script_r_cut_images_by_grid_caatinga.R" # <- CHANGE ME
rscript_file="/home/adeline/Dropbox/github_projects/geoserver-mosaics/caatinga/script_r_cut_images_by_grid_caatinga.R" # <- CHANGE ME
printf $rscript_file

#pyscript_file="/[path]/geoserver-mosaics/sentinel_hist.py" # <- CHANGE ME
pyscript_file="/home/adeline/Dropbox/github_projects/geoserver-mosaics/sentinel_hist.py" # <- CHANGE ME
printf $pyscript_file


echo
echo "----- gdal from 16bits to 8bits Byte -----"
echo
dir=tempByte
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdal_translate -scale -ot Byte -a_nodata 0 -of GTiff "$file" "${dir}/${file}_byte"
  #0 65535 0 255
  echo
done

echo
for file1 in $dir/*.tif_byte; do
  printf '%s\n' "${file1%.*}_byte.tif"
  newname="${file1%.*}_byte.tif"
  mv -- "$file1" "$newname"
  echo
done
echo "Fim: `date +%d-%m-%y_%H:%M:%S`"

echo
echo "----- script Cartaxo contraste img Byte input -----"
echo
cd tempByte/
dir=tempPercentile
mkdir -p $dir
echo

for file in *.tif; do
  echo "$file"
  python "$pyscript_file" "$file"
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
  gdalwarp -t_srs EPSG:4326 -of GTiff "$file" "${dir}/${file}_4326"
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
mv ${mydir}/tempByte/tempPercentile/tempEPSG4326/tempCutted_buffer/tempNoAlphaBand/tempNoData/ ${mydir}
#mv ${mydir}/tempByte/ ~/.local/share/Trash/files/
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
