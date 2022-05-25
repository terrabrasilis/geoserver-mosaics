# geoserver-mosaics

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://github.com/terrabrasilis/geoserver-mosaics/blob/master/LICENSE)
![Release](https://img.shields.io/github/v/release/terrabrasilis/geoserver-mosaics)
![Linux Compatible](https://img.shields.io/badge/platform-linux-bringhtgreen)
<!---![Linux Compatible](https://img.shields.io/badge/linux-compatible%20🐧-brightgreen.svg)-->

These scripts will automatically build mosaics to create tiled raster image (pyramid) with GeoServer. All scripts have been developed on Linux operating system, Ubuntu 16.04. 

# Directory Guide and Input Data

The directories are grouped by brazilian biomes and Legal Amazon: "amazonia", includes the Legal Amazon, "cerrado" with the Cerrado biome, and others biomes that comprises four biomes: Caatinga, Mata Atlântica, Pantanal and Pampa.

All the images must be in Geotiff (.tif) raster file format. For images coming from Legal Amazon, all of them must have correct Landsat path and row in filename where appropriate and possible, i.e, "Landsat8_OLI_21964_17082019.tif". 

For each script is necessary edit the contents of variable "shapefile" and put the path to shapefile with the biome limits. The shapefile must be in the geographic coordinate system EPSG:4326.  

When the script have "rscript_file" variable, is used a R script to cut each image by your landsat grid scene to avoid border sobreposition. In this case is necessary the landsat grid shapefile contains a feature called "pathrow" in format of 5 digits 00527, and not in 005/27.

# Usage

## Dependencies
- [Python](https://www.python.org/) (>= 2.7);
- [GDAL](https://gdal.org) (>= 2.4.2);
- [GeoServer](http://geoserver.org/) (>= 2.13.0) with Image Pyramid extension;
- [R](https://www.r-project.org/) (>= 3.6.2);
- Geographic Information System (GIS) to add layer and visualize the mosaic via Web Map Service (WMS), e.g., [QGIS](https://qgis.org/en/site/#);

You can use docker to run some these applications in containers. You may need to install missing dependencies before you can install applications.


## Command line

The scripts can be run on your system as follows:

```bash
user@machine:~/[directory_with_raster_year]$ /[path_to_repository]/cerrado/gdal_process_PRODES_CERRADO_2000-2018.sh [year]
```
Example:

```bash
user@machine:~/Downloads/images_cer/im_2010$ /home/user/Downloads/geoserver_mosaics/cerrado/gdal_process_PRODES_CERRADO_2000-2018.sh 2010

```
## Output

The scripts create intermediate folders and GeoTIFF files. By default, the folder named with "year" is used as input of Image Pyramid GeoServer, move this folder to directory of GeoServer data. After script execution, the intermediate files and folders can be removed to trash. 

# Online Resource

- [Image Pyramid](https://docs.geoserver.org/stable/en/user/tutorials/imagepyramid/imagepyramid.html)
- Download [shapefile](http://terrabrasilis.dpi.inpe.br/downloads/) with biomes and Legal Amazon border.

