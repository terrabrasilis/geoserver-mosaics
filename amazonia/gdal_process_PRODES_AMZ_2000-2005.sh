#!/bin/bash
echo

# NOTE: Legal Amazon - Years from 2000 to 2005

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
    echo "Example: [path]/gdal_process_PRODES_AMZ_2000-2005.sh 2005"
    echo
    exit 1
    fi

echo
echo "----- Start processing -----"

mydir=$(pwd)
printf $mydir

echo
echo "Shapefile"
## AMZ LEGAL
shapefile="/[path]/shapefiles/brazilian_legal_amazon/brazilian_legal_amazon_4326.shp"
printf $shapefile

shapefile_grid="/[path]/shapefiles/brazilian_legal_amazon/grid_landsat_brazilian_legal_amazon_4326.shp"
printf $shapefile_grid

rscript_file="/[path]/script_r_cut_images_by_grid_2000-2019.R"

echo
echo "----- Define EPSG:4326 -----"
echo
dir=tempEPSG4326
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdalwarp -of GTiff -s_srs "+proj=longlat +datum=WGS84 +no_defs" -t_srs EPSG:4326 "$file" "${dir}/${file}_4326" 
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
echo "----- Expand One band to Three using RGB -----"
echo
cd tempEPSG4326/
dir=tempRGB
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdal_translate -of GTiff -ot Byte -outsize 100% 100% -expand rgb -co COMPRESS=DEFLATE "$file" "${dir}/${file}_rgb" 
  echo
done

echo
for file1 in $dir/*.tif_rgb; do
  printf '%s\n' "${file1%.*}_rgb.tif"
  newname="${file1%.*}_rgb.tif"
  mv -- "$file1" "$newname"
  echo
done

echo
echo "----- Cut each raster by scene of the Landsat path/row grid -----"
echo
cd tempRGB/
current="$(pwd)/"
echo "$current"

Rscript --vanilla ${rscript_file} ${shapefile_grid} "$current"
echo

echo
echo "----- Define NoData -----"
echo
cd tempCutted_buffer/
dir=tempNoData0
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdalwarp -of GTiff -srcnodata "0 0 0" -dstnodata "0 0 0" "$file" "${dir}/${file}_nodata"
  echo
done

echo
for file1 in $dir/*.tif_nodata; do
  printf '%s\n' "${file1%.*}_nodata.tif"
  newname="${file1%.*}_nodata.tif"
  mv -- "$file1" "$newname"
  echo
done


echo "----- Move to trash the intermediate folders -----"
mv ${mydir}/tempEPSG4326/tempRGB/tempCutted_buffer/tempNoData0 ${mydir}
mv ${mydir}/tempEPSG4326/ ~/.local/share/Trash/files/

echo
echo "----- Merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempNoData0/*.tif
echo


echo
echo "----- Cut mosaic by biome limits -----"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shapefile} -crop_to_cutline -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${mydir}/mosaic_${year}_border.tif ${mydir}/mosaic_${year}.tif
echo

cd ${mydir}/
dir=$year
mkdir -p $dir
echo "----- Directory created: ${dir} -----"
echo 

echo
echo "----- Retile mosaic -----"
gdal_retile.py -v -r bilinear -levels 4 -ps 2048 2048 -ot Byte -co "TILED=YES" -co "COMPRESS=LZW" -co "ALPHA=YES" -targetDir ${year} ${mydir}/mosaic_${year}.tif  
echo


echo "Script has been executed successfully"
echo
