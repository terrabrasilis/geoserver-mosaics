#!/bin/bash
mkdir output
shp="amz_border_4326_newIBGE.shp"
datadir="mosaic_lvl0_from_legal_amazon"
outputdir="output"
#ls ${datadir}/*.tif > files.txt

for i in $(seq 2000 2023); do 
echo "Processing $i"
echo "Building VRT"
ls ${datadir}/mosaic_${i}_*.tif > ${outputdir}/files_${i}.txt
gdalbuildvrt -srcnodata 0 -hidenodata -resolution highest -input_file_list ${outputdir}/files_${i}.txt ${outputdir}/output_${i}.vrt
echo "Building Mosaic"
gdal_translate -co COMPRESS=LZW -ot Byte -co "BIGTIFF=YES" -co "TILED=YES" -co "PROFILE=GEOTIFF" -co "BLOCKXSIZE=256" -co "BLOCKYSIZE=256" ${outputdir}/output_${i}.vrt ${outputdir}/mosaic_${i}_border.tif

#gdal_merge.py -n 0 -a_nodata 0 -co COMPRESS=LZW -of GTiff -o ${outputdir}/mosaic_${i}_border.tif mosaic_lvl0_from_legal_amazon/mosaic_${i}_*.tif

echo "Cutting by Limit"
gdalwarp -ot Byte -q -of GTiff -srcnodata "0 0 0" -dstalpha -cutline ${shp} -crop_to_cutline -co BIGTIFF=YES -co COMPRESS=LZW -wo OPTIMIZE_SIZE=TRUE ${outputdir}/mosaic_${i}_border.tif ${outputdir}/mosaic_${i}.tif

echo "Creating multiresolution"
gdaladdo --config COMPRESS_OVERVIEW LZW ${outputdir}/mosaic_${i}.tif  2 4 8 16 32

echo "Done $i"
done
