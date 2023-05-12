#!/bin/bash
echo

# NOTE: Legal Amazon - Years 2007 and 2012

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
    echo "Example: path/gdal_process_PRODES_AMZ_2007_2012.sh 2007"
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

rscript_file="/[path]/script_r_cut_images_by_grid_2000_2019.R"

echo
echo "----- Copy of the raster data -----"
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

echo
echo "----- Unset NoData -----"
echo
cd tempCopy/

for file in *.tif; do
  echo $file
  gdal_edit.py "$file" -unsetnodata
  echo
done

echo
echo "----- Define from Datum SAD69 to WGS84 (EPSG:4326) -----"
echo
cd tempCopy/
dir=tempEPSG4326
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdalwarp -of GTiff -s_srs "+proj=longlat +ellps=GRS67 +towgs84=-57,1,-41,0,0,0,0 +no_defs" -t_srs EPSG:4326 "$file" "${dir}/${file}_4326"
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
echo "----- Cut each raster by scene of the Landsat path/row grid -----"
echo
cd tempEPSG4326/
current="$(pwd)/"
echo "$current"

Rscript --vanilla ${rscript_file} ${shapefile_grid} "$current"
echo

echo
echo "----- Define NoData -----"
echo
cd tempCutted_buffer/
dir=tempNoData
mkdir -p $dir

for file in *.tif; do
  echo $file
  gdalwarp -of GTiff -srcnodata "255 255 255" -dstnodata "0 0 0" "$file" "${dir}/${file}_nodata"
  echo
done

echo
for file1 in $dir/*.tif_nodata; do
  printf '%s\n' "${file1%.*}_nodata.tif"
  newname="${file1%.*}_nodata.tif"
  mv -- "$file1" "$newname"
  echo
done


echo "----- Move to trash nodata folder -----"
mv ${mydir}/tempCopy/tempEPSG4326/tempCutted_buffer/tempNoData/ ${mydir}
mv ${mydir}/tempCopy/ ~/.local/share/Trash/files/
echo

echo
echo "----- Merge all scenes -----"
gdal_merge.py -n 0 -a_nodata 0 -of GTiff -o ${mydir}/mosaic_${year}_border.tif ${mydir}/tempNoData/*.tif
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
gdal_retile.py -v -r bilinear -levels 4 -ps 2048 2048 -ot Byte -co "TILED=YES" -co "COMPRESS=LZW" -targetDir ${year} ${mydir}/mosaic_${year}.tif
echo

echo "Script has been executed successfully"
echo

