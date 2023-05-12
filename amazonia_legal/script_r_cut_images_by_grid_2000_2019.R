#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

# Execute R script to cut images according to a grid landsat: 
# Rscript --vanilla script_r_cut_images_by_grid.R /home/user/.../grid_landsat_brazilian_legal_amazon_4326.shp /home/user/.../2006/

list.of.packages <- c("dplyr", "raster", "rgeos", "rgdal", "tools", "stringr", "rlang")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(dplyr)
library(raster)

# test if there is at least one argument: if not, stop
if (length(args)==2) {
  
  cat("---------------------\n")
  shape <- as.character(args[1])
  cat("shapefile path: '", shape, "' \n")
  rasterFolder <- as.character(args[2])
  cat("folder with files: '", rasterFolder, "' \n\n")
  
  newFolder <- "tempCutted_buffer"
  dir.create(path = paste(rasterFolder, newFolder, sep = ""))
  cat("new dir created in: '", paste(rasterFolder, newFolder, sep = ""), "' \n\n")
  
  myshp <- raster::shapefile(shape)
  
  myRasters <- list.files(rasterFolder, pattern = "*.tif", full.names = TRUE)
  pathrowShp <- myshp@data$pathrow
  
  for (i in 1:length(myRasters)){
    filename <- basename(tools::file_path_sans_ext(myRasters[i]))
    
    # verify if exist images of other satellites
    landsat_different_exist <- any(stringr::str_detect(filename, stringr::fixed(c("DMC", "CBERS", "LISS", "Sentinel2"), ignore_case=TRUE)))
    pathrowRasterValue <- pathrowShp[stringr::str_detect(filename, pathrowShp , negate = FALSE)]
    
    if(isFALSE(rlang::is_empty(pathrowRasterValue))){
      pathrowRaster <- pathrowRasterValue
    } else {
      # extract pattern path/row of the file name, case exist 
      pattern_landsat <- "[[:digit:]]{3}[[:punct:]]{1}[[:digit:]]{2}"
      exist_pathrow <- sub("_","",regmatches(filename, regexpr(pattern_landsat, filename))) 
      if (isFALSE(rlang::is_empty(exist_pathrow)) && nchar(exist_pathrow) == 5)
        pathrowRaster <- exist_pathrow
      else
        pathrowRaster <- filename
    }
    
    if(isFALSE(landsat_different_exist) && isTRUE(pathrowRaster %in% pathrowShp)){
      
      cat("Id: ", i, " -- PathRow: ", pathrowRaster, "\n", sep = "")
      myRaster <- raster::brick(myRasters[i])
      
      grid.sub <- myshp[as.character(pathrowShp) %in% pathrowRaster, ]
      
      # Create a buffer in a polygon
      grid.sub.buffer <- buffer(grid.sub, width = 0.0002, dissolve = TRUE)
      
      # cut by path/row scene
      raster.sub <- raster::mask(myRaster, grid.sub.buffer)
      
      # change last band value, rgb, from 0 to 1 and from 255 to 254
      raster.sub[[3]][raster.sub[[3]] == 0] <- 1
      raster.sub[[2]][raster.sub[[2]] == 0] <- 1
      raster.sub[[1]][raster.sub[[1]] == 0] <- 1
      raster.sub[[3]][raster.sub[[3]] == 255] <- 254
      raster.sub[[2]][raster.sub[[2]] == 255] <- 254
      raster.sub[[1]][raster.sub[[1]] == 255] <- 254
      
      # save raster only for the shape that match with grid
      raster::writeRaster(raster.sub, filename = paste(rasterFolder, newFolder, "/", filename, "_cutted.tif", sep = ""), format="GTiff", datatype = "INT1U", overwrite=TRUE)
    } else {
      cat("Id: ", i, " -- PathRow: ", pathrowRaster, ", image .tif provided by satellite different of the Landsat or off limits of the shapefile\n", sep = "")
      
      myRaster <- raster::brick(myRasters[i])
      myRaster[[3]][myRaster[[3]] == 255] <- 254
      ## save raster only for the shape that match with grid
      raster::writeRaster(myRaster, filename = paste(rasterFolder, newFolder, "/", filename, "_cutted.tif", sep = ""), format="GTiff", datatype = "INT1U", overwrite=TRUE)
    }
    
    removeTmpFiles(h=0)
  }
  
} else if (length(args)<=1 || length(args)>2) {
  stop("-----------------------------------\n
       At least two argument must be supplied (input grid file).shp and path to save \n
       -----------------------------------\n", call.=FALSE)
}
