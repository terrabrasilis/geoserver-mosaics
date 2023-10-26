# geoserver-mosaics

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://github.com/terrabrasilis/geoserver-mosaics/blob/master/LICENSE)
![Release](https://img.shields.io/github/v/release/terrabrasilis/geoserver-mosaics)
![Linux Compatible](https://img.shields.io/badge/platform-linux-bringhtgreen)
<!---![Linux Compatible](https://img.shields.io/badge/linux-compatible%20🐧-brightgreen.svg)-->

These scripts will automatically build mosaics to create tiled raster (image pyramid) with GeoServer. All scripts have been developed on Linux operating system, Ubuntu 16.04.

# Directory Guide and Input Data

The directories are grouped by brazilian biomes and Legal Amazon: "amazonia", includes the Legal Amazon, "cerrado" with the Cerrado biome, and others biomes that comprises four biomes: Caatinga, Mata Atlântica, Pantanal and Pampa.

All the images must be in Geotiff (.tif) raster file format. And, all of them must have the correct Landsat path and row in filename where appropriate and possible, i.e, "Landsat8_OLI_232062_20200729_8bits_654_contraste.tif".

For each script is necessary to edit the contents of the variable "shapefile" and put the path to shapefile with the biome limits. The shapefile must be in the geographic coordinate system EPSG:4326.

When the script has the "rscript_file" variable, is used an R script to cut each image by your Landsat grid scene to avoid border overlap. In this case is necessary the Landsat grid shapefile contains a feature called "pathrow" in the format of 5 digits 00527, and not in 005/27.

# Usage

## Dependencies
- [Python](https://www.python.org/) (>= 2.7);
- [GDAL](https://gdal.org) (>= 3.0);
- [GeoServer](http://geoserver.org/) (>= 2.13.0) with Image Pyramid extension;
- [R](https://www.r-project.org/) (>= 3.6.2);
- Geographic Information System (GIS) to add layer and visualize the mosaic via Web Map Service (WMS), e.g., [QGIS](https://qgis.org/en/site/#);
- [Docker](https://www.docker.com/) and [Compose](https://docs.docker.com/compose/install/);
- [PostgreSQL](https://www.postgresql.org/) and spatial database extension [Postgis](https://postgis.net/).

You can use docker to run some of these applications in containers. You may need to install missing dependencies before you can install applications. The Docker Compose file is a YAML file defining services, networks and volumes. In docker folder there are examples of .yml files, before run then, create a Docker-Compose folder in localhost and change path in files.

### Notes

- If the shell script uses 'sentinel_hist.py', create an environment Python and execute scripts in this env.
- If Pampa does not have an image with pathrow 22482, duplicate the GeoTIFF with pathrow 22481 and rename it 22482. It is necessary because of the stage of cutting images by grid Landsat.
- Case Pantanal does not exist an image with pathrow 22571, duplicate GeoTIFF 22572 and rename it to 22571.

## Command line

The scripts can be run on your system as follows:

```bash
user@machine:~/[directory_with_raster_year]$ /[path_to_repository]/cerrado/gdal_process_PRODES_CERRADO_2022_valpha_.sh [year]
```
Example:

```bash
user@machine:~/Downloads/images_cer/im_2022$ /home/user/Downloads/geoserver_mosaics/cerrado/gdal_process_PRODES_CERRADO_2022_valpha.sh 2022

```
## Output

The scripts create intermediate folders and GeoTIFF files. By default, the folder named with "year" is used as input of Image Pyramid GeoServer, move this folder to the directory of GeoServer data. After script execution, the intermediate files and folders can be removed to the trash.

# Online Resource

A more complete [README](https://github.com/ammaciel/mosaics-prodes-geoserver) file including the step-by-step Geoserver configuration tutorial.

- [Image Pyramid](https://docs.geoserver.org/stable/en/user/tutorials/imagepyramid/imagepyramid.html)
- [Building and using an image pyramid](https://docs.geoserver.org/latest/en/user/tutorials/imagepyramid/imagepyramid.html)
- [Advanced Mosaics and Pyramids Configuration](https://docs.geoserver.geo-solutions.it/edu/en/raster_data/mosaic_pyramid.html)
- Download [shapefile](http://terrabrasilis.dpi.inpe.br/downloads/) with biomes and Legal Amazon border.
- [GeoServer - Layers](https://docs.geoserver.org/2.23.x/en/user/data/webadmin/layers.html)

