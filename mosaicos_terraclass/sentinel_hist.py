#(base) adeline@adeline-G5-5590:~$ python3 -m pip install --upgrade --no-cache-dir setuptools==58.0.2
#(base) adeline@adeline-G5-5590:~$ python3 -m pip install --no-cache-dir pygdal==3.0.4.*
# (base) adeline@adeline-G5-5590:~/mosaicos_terraclass$ python sentinel_hist.py /home/adeline/Downloads/cerrado_agua/mosaico_22869.tif 

# Script developmented by Cartaxo 2020-08-23

import os,sys
from osgeo import gdal
from osgeo import osr
from osgeo import ogr
from osgeo.gdalconst import *
import numpy

driver = gdal.GetDriverByName('GTiff')

ifile = sys.argv[1]
idataset = gdal.Open(ifile,GA_ReadOnly)
if idataset is None:
	print ('\nCould not open ',ifile)
	exit(1)

ofile = ifile.replace('.tif','_ctx.tif')


odataset = driver.Create( ofile, idataset.RasterXSize, idataset.RasterYSize, 3, gdal.GDT_Byte,  options = [ 'BIGTIFF=YES'])
# Set the geo-transform to the dataset
odataset.SetGeoTransform(idataset.GetGeoTransform())
odataset.SetProjection(idataset.GetProjection())

for iband in [1,2,3]:
	raster = idataset.GetRasterBand(iband).ReadAsArray(0, 0, idataset.RasterXSize, idataset.RasterYSize).astype(numpy.float32)
	p2, p98 = numpy.percentile(raster[raster>0], (2, 98))
	print ('band {} p2 {} - p98 {}'.format(iband,p2,p98))

	raster = (raster - p2)/(p98-p2).astype(numpy.float32)
	raster[raster<0.] = 0.
	raster[raster>1.] = 1.
	raster = (255.*raster).astype(numpy.uint8)
	
	odataset.GetRasterBand(iband).WriteArray(raster)

idataset = None
odataset = None

