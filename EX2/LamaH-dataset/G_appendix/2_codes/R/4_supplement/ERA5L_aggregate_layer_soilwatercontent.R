### OBJECT
# Aggregate ERA5-Land volumetric soil water content from 
# 3 different vertical zones (0 to 7cm, 7 to 28cm and 28 to 100cm)
# to 1 vertical zone (0 to 100cm)
# with hourly time resolution 
# export as netcdf file

### INFO
# script "API_download_ERA5L.R" must have already been executed

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES 
library(data.table)
library(ncdf4)
library(raster)


#############
### VARIABLES

# path to ERA5L netcdf files
input <- "D:/Data/ERA5_Land" 

# variables to aggregate
var <- c("volumetric_soil_water_layer_1", "volumetric_soil_water_layer_2", "volumetric_soil_water_layer_3")


#################
### PREPROCESSING

## Define basic netcdf information

# set working directory
setwd(input)

# generate list of file names, which contains the variable name
filenames <- Sys.glob("*.nc")
filenames <- filenames[grepl(paste(var, collapse = '|'), filenames)]

# sort files by year
vals <- as.numeric(substr(filenames, 41, 44))
filenames <- filenames[order(vals)]

# set origin time
otim = as.POSIXct("1900 01 01 00 00", format='%Y %m %d %H %M', tz = "GMT")

# create empty vector which stores afterwards the number of NA´s of each netcdf file
nanet = c()


#############################################################
### LOOP FOR AGGREGATING VALUES OF 3 DIFFERENT VERTICAL ZONES

## Define outer loop through netcdf files in input folder
for (i in seq(1, length(filenames), by=3)){

  # create input path and file name
  file1 <- paste(input, filenames[i], sep = "/")
  file2 <- paste(input, filenames[i+1], sep = "/")
  file3 <- paste(input, filenames[i+2], sep = "/")
  
  # get actual year from filename as character
  yr <- substr(file1, nchar(file1)-6, nchar(file1)-3)
  
  # print actual year to console
  print(yr)
  
  
  ## Read in netcdf-file
  
  # open netcdf
  nc_data1 <- nc_open(file1)
  nc_data2 <- nc_open(file2)
  nc_data3 <- nc_open(file3)
  
  # read values
  data1 <- ncvar_get(nc_data1, nc_data1$var[[1]]$name)
  data2 <- ncvar_get(nc_data2, nc_data2$var[[1]]$name)
  data3 <- ncvar_get(nc_data3, nc_data3$var[[1]]$name)
  
  # read attributes and store as ncdim_def
  lon <- ncdim_def("longitude", "degrees_east", ncvar_get(nc_data1, "longitude"))
  lat <- ncdim_def("latitude", "degrees_north", ncvar_get(nc_data1, "latitude"))
  tim <- ncdim_def("time", "hours since 1900-01-01 00:00:00.0", ncvar_get(nc_data1, "time"))
  
  # get fillvalue of variable
  fillvalue <- ncatt_get(nc_data1, nc_data1$var[[1]]$name, "_FillValue")
  
  # replace fillvalue with NA
  data1[data1 == fillvalue$value] <- NA
  data2[data2 == fillvalue$value] <- NA
  data3[data3 == fillvalue$value] <- NA
  
  # check sum of NA´s
  nanet[i] <- sum(is.na(data1))
  nanet[i+1] <- sum(is.na(data2))
  nanet[i+2] <- sum(is.na(data3))
  
  # close netcdf
  nc_close(nc_data1)
  nc_close(nc_data2)
  nc_close(nc_data3)
  
  # get dimensions of actual netcdf
  ncols <- dim(data1)[1] # lon
  nrows <- dim(data1)[2] # lat
  nts <- dim(data1)[3] # time
  
  
  ## Aggregate values
  
  # create empty array
  data <- array(numeric(0), dim=c(ncols,nrows,nts))
  
  # by loop 
  # with specific weighting of each vertical layer, depending on layer depth 
  for (j in 1:nts){
    for (k in 1:nrows){
      for (l in 1:ncols){
        data[l,k,j] <- data1[l,k,j]*(7/100) + data2[l,k,j]*(21/100) + data3[l,k,j]*(72/100)
      }
    }
  }
  
  
  ## Create new netcdf file
  
  # paste filename
  filename <- paste0("ERA5-Land_volumetric_soil_water_layer_123_", yr, ".nc") 
  
  # define attributes of new netcdf
  var_temp <- ncvar_def(name="swvl123", units="m**3 m**-3", dim=list(lon, lat, tim), missval=fillvalue$value, longname="Volumetric soil water layer 1-3", prec="float")
  
  # create new netcdf
  nc_data <- nc_create(filename, list(var_temp))
  
  # write array to netcdf file
  ncvar_put(nc_data, var_temp, data, start=c(1,1,1), count=c(ncols,nrows,nts))
  
  # close new netcdf
  nc_close(nc_data)
  
  
  # delete unused variables from workspace
  rm(nc_data, nc_data1, nc_data2, nc_data3, data, data1, data2, data3)

# end loop   
}