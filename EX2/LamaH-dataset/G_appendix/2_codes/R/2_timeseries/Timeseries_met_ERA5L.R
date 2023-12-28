### OBJECT
# Aggregate data from ERA5-Land dataset (netcdf file)
# to individual polygons (e.g. upstream areas of individual gauges)
# with hourly time resolution 

### INFO
# choose between basin delineation A, B or C
# aggregation of ERA5L variables can be done also on other polygons, but unique identifier with field name "ID" must be given as first attribute in shapefile
# script "API_download_ERA5L.R" must have already been executed
# folders "daily", "hourly", "gaps" and "working" must be created in export repository "Output" before executing the script
# folder "working" can be deleted after finishing (time series per year)
# the downloaded ERA5L netcdf files have 106 columns and 46 rows, see variable "area" in "API_download_ERA5L.R", set in lines 157 (NCOLS) and 158 (NROWS)
# ID of ERA5L grids starts from 1 at upper left, ascending to top right; new block starting at upper left when bottom right position is reached (see Grid_ERA5L.shp)
# downloaded variables from ERA5L: 2m_temperature, 10m_u_component_of_wind, 10m_v_component_of_wind, potential_evaporation, snow_depth_water_equivalent, 
#   surface_net_solar_radiation, surface_net_thermal_radiation, surface_pressure, total_evaporation, total_precipitation,
#   volumetric_soil_water_layer_1, volumetric_soil_water_layer_2, volumetric_soil_water_layer_3, volumetric_soil_water_layer_4,
#   skin_temperature, leaf_area_index_high_vegetation, leaf_area_index_low_vegetation)
# variable "volumetric_soil_water_layer_123" is output of script "ERA5L_aggregate_layer_soilwatercontent.R"
# the imported shapefiles must have the same projection (default EPSG 3035)
# some of the variables like evaporation or precipition are daily-wise accumulated (see ERA5-Land description)
# gaps (NAs) are linear interpolated, maximum number of interpolated gaps is 3, remaining gaps are filled with -999
# the interpolated time steps are output as additional text file

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES 
library(data.table)
library(sf)
library(ncdf4)
library(zoo)


########
### LOOP

# choose variables
metvars <- c("2m_temperature", "10m_u_component_of_wind", "10m_v_component_of_wind", "potential_evaporation", "snow_depth_water_equivalent",
             "surface_net_solar_radiation", "surface_net_thermal_radiation", "surface_pressure", "total_evaporation", "total_precipitation",
             "volumetric_soil_water_layer_123", "volumetric_soil_water_layer_4", "skin_temperature", "leaf_area_index_high_vegetation", "leaf_area_index_low_vegetation",
             "2m_dewpoint_temperature", "forecast_albedo", "snow_albedo", "snow_cover", "snow_density", "snowmelt")


## Start variable loop
for (metvar in metvars){

# print actual variable
print(metvar)


#############
### VARIABLES

# time window, code has to be adapted if dates are changed
dt_start <- "1981 01 01 01 00"                                                                 # start date of time series, format: YYYY MM DD hh mm
dt_end <- "2019 12 31 23 00"                                                                   # end date of time series, format: YYYY MM DD hh mm

# input path and file name
Input_TS <- "D:/Data/ERA5_Land"                                                                # path to ERA5-Land netcdf files (output folder of API_download_ERA5L.R)
Input_grid_ERA5L <- "D:/LamaH/G_appendix/3_shapefiles/Grid_ERA5L.shp"  vv                       # path to grid of ERA5-Land
Input_shape_poly <- "D:/LamaH/G_appendix/3_shapefiles/Poly_B.shp"                              # path to polygons, on which the meteorol. time series should be aggregated; choose between basin delineation A, B or C

# output path
Output <- "D:/Data/TS_met/B"           				   								           # path to output folder; choose between basin delineation A, B or C


################
### IMPORT FILES

# import shapefiles
R_ts <- st_read(Input_grid_ERA5L)
S_poly <- st_read(Input_shape_poly)


######################
### PROCESS SHAPEFILES

# keep only column "ID" and geometry
S_poly <- subset(S_poly, select = 1)

# rename the first column, which contains the individual Poly_ID to "ID"
colnames(S_poly)[1] <- c("ID")

# get the intersecting grid cells of "R_ts" with "S_poly" (slow with many intersecting cells)
Intersec <- st_intersection(R_ts, S_poly)

# create list, which contains the unique and intersecting cell IDs of the data grid "R_ts"
# sort by ascending values
Icells <- sort(unique(st_drop_geometry(Intersec)[,1]))


####################################################################
### FUNCTION TO CREATE AREAL WEIGHTS FOR EACH INTERSECTING GRID CELL
# creates a table with intersecting area between each grid cell and each polygon

# create char sequence for describing the colnames (IDs) of the polygons
# sort by ascending values
Poly_ID <- as.character(sort(st_drop_geometry(S_poly)[,1])) 

# create empty matrix, filled with zeros 
# with m (number of intersecting grid cells) columns and n (number of polygons) rows
AW <- matrix(0, ncol = length(Icells), nrow = length(S_poly$ID))

# rename columns of empty data.table
colnames(AW) <- as.character(Icells)

# running variable for accessing row number of empty data.table 
j <- 1

# loop through polygons
for(i in as.integer(Poly_ID)){
  
  # subset data.table with geometry of polygon
  Intersec_poly <- Intersec[Intersec$ID.1 == i, ]
  
  # sort by ascending ID
  Intersec_poly <- Intersec_poly[order(Intersec_poly$ID),]
  
  # create vector with intersecting IDs of grid "R_ts" and actual polygon
  Cell <- as.character(st_drop_geometry(Intersec_poly)[,1])
  
  # create vector with areas [m2] of each intersecting grid cell of "R_ts" and actual polygon
  Cell_area <- as.vector(as.integer(st_area(Intersec_poly)))
  
  
  ## Inner loop through Poly_ID큦
  for(k in 1:length(Cell)){
    
    # write to empty matrix
    AW[j, Cell[k]] <- Cell_area[k]
  
  # end inner loop       
  }
  
  # increment j by 1
  j <- j+1
  
# print state to console
#print(paste("Poly_ID =", i, sep=" "))
  
# end loop    
}

# calculate rowsums of "AW" (needed for following loops)
AWRS <- rowSums(AW)

# delete unused variables
rm(Intersec, Intersec_poly, Cell, Cell_area, i, j, k)


#########################################################
### LOOP FOR AGGREGATING THE ERA5L VALUES ON THE POLYGONS

## Define basic netcdf information

# number of rows and columns of a netcdf file
NCOLS <- 106
NROWS <- 46

# set working directory
setwd(Input_TS)

# generate list of file names, which contains the variable name
filenames <- Sys.glob("*.nc")
filenames <- filenames[grepl(metvar, filenames)]

# divide ERA5L variables into different groups (accumulated or not, ...) 
if (metvar %in% c("2m_temperature", "10m_u_component_of_wind", "10m_v_component_of_wind", "snow_depth_water_equivalent", "surface_pressure", 
                  "volumetric_soil_water_layer_1", "volumetric_soil_water_layer_2", "volumetric_soil_water_layer_3", "volumetric_soil_water_layer_4", "volumetric_soil_water_layer_123",
                  "skin_temperature", "leaf_area_index_high_vegetation", "leaf_area_index_low_vegetation", "2m_dewpoint_temperature", "forecast_albedo", "snow_albedo", "snow_cover", "snow_density")){
  vgrp <- 1
} 
if (metvar %in% c("potential_evaporation", "total_evaporation", "total_precipitation", "snowmelt")){
  vgrp <- 2
}
if (metvar %in% c("surface_net_solar_radiation", "surface_net_thermal_radiation")){
  vgrp <- 3
}

# create empty vector, which stores afterwards the number of NA큦 of each netcdf file
nanet = c()

# create empty vector, which stores afterwards bool values for indicating compliance of timesteps (timeseq and netcdf file)
chk = c()

# create empty vector, which stores the number of NA's after the loop
naout1 = c()

# create empty list, which contains the gaprows of the years afterwards
gaprows <- list() 


## Dates

# transform char dates to POSIXct Dates
dt_st <- as.POSIXct(dt_start, format='%Y %m %d %H %M', tz = "GMT")
dt_ed <- as.POSIXct(dt_end, format='%Y %m %d %H %M', tz = "GMT")

# create date sequence by 1 year
years <- as.character(substr(seq(dt_st, dt_ed, by="year"), 1, 4))

# select only filenames within the desired years
filenames <- filenames[grepl(paste(years, collapse = '|'), filenames)]

# set origin time
otim = as.POSIXct("1900 01 01 00 00", format='%Y %m %d %H %M', tz = "GMT")


## Define outer loop through netcdf files in folder "Input_TS"
for (i in 1:length(filenames)){
  
  
  ## Dates of actual year
  
  # create input path and file name
  file <- paste(Input_TS, filenames[i], sep = "/")
  
  # get actual year from filename as character
  yr <- substr(file, nchar(file)-6, nchar(file)-3)
  
  # print actual year
  print(yr)
  
  # transform char dates to POSIXct Dates
  dt_sti <- as.POSIXct(paste(yr, "01 01 00 00"), format='%Y %m %d %H %M', tz = "GMT")
  if (yr == "1981"){
    dt_sti <- dt_sti+3600
  }
  dt_edi <- as.POSIXct(paste(yr, "12 31 23 00"), format='%Y %m %d %H %M', tz = "GMT")
  
  # create date sequence by 1 hour for actual year
  timeseq <- seq(dt_sti, dt_edi, by="hour")
  
  # calculate number of timesteps between start and and end date of actual year
  diffts = length(timeseq)
  
  
  ## Matrix

  # generate empty data.table, which will be filled in the following for-loop
  Out <- data.table(matrix(NA, nrow = diffts, ncol = length(Poly_ID)+1))

  # data.table, transform data type of all columns from character to numeric
  Out <- Out[, lapply(.SD, as.numeric)]

  # rename columns of empty data.table
  colnames(Out) <- c("Date", Poly_ID)

  # write "timeseq" into first column (Date) of data.table,
  # in case of some accumulated variables: subtract 1 hour (3600 sec), because we want Austrian convention (value at actual timestep represents sum from actual to the next timestep)
  if ((vgrp == 1) | (vgrp == 3)) {
    Out$Date <- timeseq
  }
  if (vgrp == 2){
    Out$Date <- timeseq-3600
  } 
  
  
  ## Read netcdf file
  
  # open netcdf
  nc_data <- nc_open(file)
  
  # read values
  data <- ncvar_get(nc_data, nc_data$var[[1]]$name)
  tim <- ncvar_get(nc_data, "time")
  
  # get "fillvalue" of variable
  fillvalue <- ncatt_get(nc_data, nc_data$var[[1]]$name, "_FillValue")
  
  # replace "fillvalue" with NA
  data[data == fillvalue$value] <- NA
  
  # check sum of NA큦
  nanet[i] <- sum(is.na(data))
  
  # save data as array
  bin <- c(data) # merge all timesteps of actual year
  
  # if metvar = "potential_evaporation" or "total_evaporation", change sign
  # before: (-) means evaporation
  # after: (-) means condensation
  if ((metvar == "potential_evaporation") | (metvar == "total_evaporation")){
	  bin <- bin*(-1)
  }
  
  # if metvar = "surface_net_thermal_radiation", change sign
  # before: (-) means emission from the earth
  # after: (-) means irradiation on the earth
  if ((metvar == "surface_net_thermal_radiation")){
    bin <- bin*(-1)
  }
  
  # close netcdf
  nc_close(nc_data)
  
  # get timesteps of actual file (third dimension)
  nts <- dim(data)[3]
  
  # delete unused variables
  rm(data)
  
  
  ## Define middle loop through hourly timesteps in a file
  for (j in 1:nts){
    
    # print actual timestep to console
    #print(paste(substr(file, 20, nchar(file)), ", timestep: ", j))
    
    # adapt intersecting cell ID큦 to actual timestep
    Cell_sel <- as.integer(Icells+NCOLS*NROWS*(j-1))
      
    # extract only values of intersecting grid cells
    bin_sel <- bin[Cell_sel]
    
    
    ## Processing depending on the variable
    
    # if metvar = "2m_temperature", transform from [K] to [캜]
    if (metvar == "2m_temperature" | metvar == "skin_temperature" | metvar == "2m_dewpoint_temperature"){
      bin_sel <- bin_sel-273.15
    }
    
    # if metvar = "snow_depth_water_equivalent", transform from [m] to [mm]
    if (metvar == "snow_depth_water_equivalent"){
      bin_sel <- bin_sel*1000
    }
    
    # if metvar = "snow_cover", transform from [%] to [-]
    if (metvar == "snow_cover"){
      bin_sel <- bin_sel/100
    }
    
    # if metvar = "potential_evaporation", "total_evaporation", "total_precipitation" or
    # if metvar = "surface_net_solar_radiation", "surface_net_thermal_radiation"
    # subtract value of previous timestep from that of actual timestep, except at timestep 01:00 of a day (this timestep is not accumulated with previous timestep within ERA5L)
    if ((vgrp == 2) | (vgrp == 3)){
    
      # calculate difference to previous timestep
      if (substr(as.character(otim + tim[j]*3600), 12, 13) != "01"){
        
        if (j != nts){ # all timesteps, except the last one
          
          # adapt intersecting cell ID큦 to previous timestep
          Cell_sel_p <- as.integer(Icells+NCOLS*NROWS*(j-2))
          
          # extract only values of intersecting grid cells
          bin_sel_p <- bin[Cell_sel_p]
          
        } else { # store additionally last timestep for calculating the difference in first time step of the next year
          
          # adapt intersecting cell ID큦 to previous timestep
          Cell_sel_p <- as.integer(Icells+NCOLS*NROWS*(j-2))
          Cell_sel_l <- Cell_sel
          
          # extract only values of intersecting grid cells
          bin_sel_p <- bin[Cell_sel_p]
          bin_sel_l <- bin_sel
        }
        
        # calculate difference between actual and previous timestep
        if ((j == 1) & (i > 1)){
          bin_sel <- bin_sel-bin_sel_l
        } else {
          bin_sel <- bin_sel-bin_sel_p
        }
      }
      
      # transform from [m] to [mm]
      if (vgrp == 2){
        bin_sel <- bin_sel*1000
      }
      
      # transform from [J/m2] to [W/m2]
      if (vgrp == 3){
        bin_sel <- bin_sel/3600
      }
    }
    
    
    ## Calculate weighted means
    
    # multiply each row of "AW" with "bin_sel" and calculate rowSums
    AWVRS <- as.numeric(AW %*% bin_sel) 
    
    # calculate weighted mean by sum(AW*bin_sel)/sum(AW)
    WM <- AWVRS/AWRS
    
    # write results to data.table
    Out[j, 2:ncol(Out)] <- as.list(WM)
	
	  # delete unused variables
	  rm(AWVRS, WM)
    
  # end middle loop
  }
  
  
  ## Table extension
  
  if ( ((vgrp == 1) | (vgrp == 3)) & (i == 1)){
    # add row at beginning for timestep 1981 01 01 00 00, if "vgrp" is 1 or 3
    # copy and insert row of timestep 1981 01 01 01 00
    startrow <- data.table("Date"=timeseq[1]-3600, Out[1,2:ncol(Out)])
    Out <- rbind(startrow, Out)
  } 
  if ((vgrp == 2) & (i == length(filenames))) {
    # add row at ending for timestep 2019 12 31 23 00, if "vgrp" is 2
    # copy and insert row of timestep 2019 12 31 22 00
    endrow <- data.table("Date"=timeseq[length(timeseq)], Out[nrow(Out),2:ncol(Out)])
    Out <- rbind(Out, endrow) 
  }
  
  
  ## Prepare before export
  
  # check if number of timesteps between start and end date is equal to accumulated number of time steps
  chk[i] <- identical(diffts, as.integer(nts))
  
  # check for number of NA큦 in the data.table
  naout1[i] <- sum(is.na(Out))
  
  # round values from tables, further effect: save dataspace
  if (metvar %in% c("surface_pressure", "snow_density")){
    Out[,(Poly_ID) := round(.SD,0), .SDcols=Poly_ID] # to 0 digits
  }
  if (metvar %in% c("2m_temperature", "10m_u_component_of_wind", "10m_v_component_of_wind", "skin_temperature", "leaf_area_index_high_vegetation", "leaf_area_index_low_vegetation", "2m_dewpoint_temperature")){
    Out[,(Poly_ID) := round(.SD,1), .SDcols=Poly_ID] # to 1 digits
  }
  if (metvar %in% c("snow_depth_water_equivalent", "volumetric_soil_water_layer_1", "volumetric_soil_water_layer_2", "volumetric_soil_water_layer_3", "volumetric_soil_water_layer_4", "volumetric_soil_water_layer_123")){
    Out[,(Poly_ID) := round(.SD,2), .SDcols=Poly_ID] # to 2 digits
  }
  if (metvar %in% c("forecast_albedo", "snow_albedo")){
    Out[,(Poly_ID) := round(.SD,2), .SDcols=Poly_ID] # to 2 digits
  } 
  if (metvar %in% c("snow_cover")){
    Out[,(Poly_ID) := round(.SD,3), .SDcols=Poly_ID] # to 3 digits
  } 
  if (vgrp == 2){
    Out[,(Poly_ID) := round(.SD,2), .SDcols=Poly_ID] # to 2 digits
  } 
  if (vgrp == 3){
    Out[,(Poly_ID) := round(.SD,0), .SDcols=Poly_ID] # to 0 digits
  }
  
  # transform Date from POSIX to character in a specific format
  Out$Date = as.character(Out$Date, format = "%Y %m %d %H %M")
  
  # create list of timesteps with NA큦 / no data
  if (i == 1){
    gaprows <- as.data.table(Out[!complete.cases(Out), 1])
  } else {
    gaprows <- rbind(gaprows, as.data.table(Out[!complete.cases(Out), 1]))
  }
  
  
  ## Export data of individual year
  
  # create path and filename for output text file
  Output_i <- paste(Output, "/working/", "ERA5L_", metvar, "_", yr, ".txt", sep = "")
  
  # export output of actual year as text file
  fwrite(Out, Output_i, sep = ",", row.names = FALSE, col.names = TRUE)
  
  # delete unused variables
  rm(Out, Output_i, yr, nc_data, fillvalue, bin, bin_sel, file, Cell_sel, dt_sti, dt_edi, timeseq, nts)
  if ((vgrp == 2) | (vgrp == 3)){
    rm(bin_sel_p, Cell_sel_l, Cell_sel_p)
  }
  
  # clear RAM
  gc()
  
# end outer loop
}

# delete unused variables after outer loop has finished
rm(NCOLS, NROWS, i, j, years)
if ((vgrp == 2) | (vgrp == 3)){
  rm(bin_sel_l)
}


###################################
### MERGE FILES OF INDIVIDUAL YEARS

## Import files

# set working directory
setwd(paste(Output, "/working", sep = ""))

# generate list of file names, which contains the variable name
wfilenames <- Sys.glob("*.txt")
wfilenames <- wfilenames[grepl(metvar, wfilenames)]

# create empty list, which stores the variable names afterwards
tables <- list()

# loop for importing and merging the tables of the individual years
for (i in 1:length(wfilenames)){
  
  # import table
  Input_i <- paste(getwd(), "/", wfilenames[i], sep = "")
  tables[[i]] <- fread(Input_i, header = TRUE)
  
  # rowbind tables
  if (i == 1){
    Out <- tables[[i]]
  } else {
    Out <- rbind(Out, tables[[i]])
  }
  
  # print actual state
  #print(wfilenames[i])
  
  # delete table to save data storage
  tables[[i]] <- NULL
  gc()
}

# delete unused variables 
rm(tables, i, Input_i)
gc()


############################ 
### PROCESSING BEFORE EXPORT

## Search for gaps in merged data.table

# check for number of NA큦 in the data.table after table merging
naout2 <- sum(is.na(Out))

# fill gaps

# remove NA큦 in timeseries, max number of consecutive NAs to fill is set to 3
if (naout2 != 0L){
  Out <- data.table(Date = Out$Date, na.approx(Out[, 2:ncol(Out)], na.rm = FALSE, maxgap = 3))
}

# check for number of NA큦 in the data.table after NA filling
naout3 <- sum(is.na(Out))

# fill remaining NAs with -999
if (naout3 != 0L){
  Out[is.na(Out)] <- -999
}

# round values from tables, further effect: save dataspace
if (metvar %in% c("surface_pressure", "snow_density")){
  Out[,(Poly_ID) := round(.SD,0), .SDcols=Poly_ID] # to 0 digits
}
if (metvar %in% c("2m_temperature", "10m_u_component_of_wind", "10m_v_component_of_wind", "skin_temperature", "leaf_area_index_high_vegetation", "leaf_area_index_low_vegetation", "2m_dewpoint_temperature")){
  Out[,(Poly_ID) := round(.SD,1), .SDcols=Poly_ID] # to 1 digits
}
if (metvar %in% c("snow_depth_water_equivalent", "volumetric_soil_water_layer_1", "volumetric_soil_water_layer_2", "volumetric_soil_water_layer_3", "volumetric_soil_water_layer_4", "volumetric_soil_water_layer_123")){
  Out[,(Poly_ID) := round(.SD,2), .SDcols=Poly_ID] # to 2 digits
}
if (metvar %in% c("forecast_albedo", "snow_albedo")){
  Out[,(Poly_ID) := round(.SD,2), .SDcols=Poly_ID] # to 2 digits
} 
if (metvar %in% c("snow_cover")){
  Out[,(Poly_ID) := round(.SD,3), .SDcols=Poly_ID] # to 3 digits
} 
if (vgrp == 2){
  Out[,(Poly_ID) := round(.SD,2), .SDcols=Poly_ID] # to 2 digits
} 
if (vgrp == 3){
  Out[,(Poly_ID) := round(.SD,0), .SDcols=Poly_ID] # to 0 digits
}

# transform Date from POSIX to character in a specific format
Out$Date = as.character(Out$Date, format = "%Y %m %d %H %M")


########## 
### EXPORT

# create path and filename for output text file
Output_t <- paste(Output, "/hourly/ERA5L_", metvar, ".txt", sep = "")
Output_g <- paste(Output, "/gaps/ERA5L_", metvar, ".txt", sep = "")

# save table as text file
fwrite(Out, Output_t, sep = ",", row.names = FALSE, col.names = TRUE)
if (naout2 != 0L){
  fwrite(gaprows, Output_g, sep = ",", row.names = FALSE, col.names = TRUE)
}

# clear RAM
gc()

# end variable loop
}