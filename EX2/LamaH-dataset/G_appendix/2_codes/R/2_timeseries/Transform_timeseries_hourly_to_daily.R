### OBJECT
# Get meteorological time series with daily resolution

### INFO
# script "Timeseries_met_ERA5L.R" must have already been executed
# different aggregation modes depending on variable

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES
library(data.table)


#############
### VARIABLES

# path to input timeseries (output path of "Timeseries_met_ERA5L.R")
inpath <- "D:/Data/TS_met/A/hourly/"

# output path
outpath <- "D:/Data/TS_met/A/daily/" 

# name of the variables
files <- c("2m_dewpoint_temperature","2m_temperature", "10m_u_component_of_wind", "10m_v_component_of_wind", "forecast_albedo", "leaf_area_index_high_vegetation", "leaf_area_index_low_vegetation",
           "potential_evaporation", "skin_temperature", "snow_albedo", "snow_cover", "snow_density", "snow_depth_water_equivalent", "snowmelt",
           "surface_net_solar_radiation", "surface_net_thermal_radiation", "surface_pressure",
           "total_evaporation", "total_precipitation", "volumetric_soil_water_layer_4", "volumetric_soil_water_layer_123")


########
### LOOP

# create empty table for storing the NAs
NA_sum <- c()

## Start loop
for (i in 1:length(files)){
  
  # print loop step
  print(paste0("variable: ", files[i]))
  
  ## Mode 
  # 1 for summing (ETA, ETP, Prec, Snow_melt)
  # 2 for splitting into daily min/max/mean (Temp)
  # 3 for splitting into daily max/mean (Radiation)
  # 4 for meaning (Albedo, LAI, Wind, Psurf, Snow_cover, Snow_density, SWE, Radiation, Vol_SW, Runoff)
  if (files[i] %in% c("potential_evaporation", "total_evaporation", "total_precipitation", "snowmelt")){
    mode <- 1
  }
  if (files[i] %in% c("2m_temperature", "2m_dewpoint_temperature", "skin_temperature")){
    mode <- 2
  }
  if (files[i] %in% c("surface_net_solar_radiation", "surface_net_thermal_radiation")){
    mode <- 3
  }
  if (files[i] %in% c("10m_u_component_of_wind", "10m_v_component_of_wind", "leaf_area_index_high_vegetation", "leaf_area_index_low_vegetation",
                      "forecast_albedo", "snow_albedo", "snow_cover", "snow_density",
                      "snow_depth_water_equivalent", "surface_pressure", "volumetric_soil_water_layer_4", "volumetric_soil_water_layer_123")){
    mode <- 4
  }
  
  
  ##########
  ### IMPORT 
  
  # create input pathname
  import <- paste(inpath, "ERA5L_", files[i], ".csv", sep = "")
  
  # import timeseries with hourly resolution as data.table
  ts <- fread(import, header = TRUE, nrows = Inf)
  
  
  ###########
  ### PROCESS
  
  # transform char dates in column 1 to dates
  dates <- as.Date(strptime(ts[,ts$Date], format='%Y %m %j %H %M', tz = "GMT"))
  
  # update data.table with dates
  ts$Date <- dates
  
  # check for number of NA´s
  NA_sum[i] <- sum(is.na(ts))
  
  # aggregate hourly to daily values, depending on the chosen mode
  # rename first column to "Date"
  if (mode == 1){
    ts <- ts[,2:ncol(ts)][, lapply(.SD, sum), by=ts$Date]
    colnames(ts)[1] <- "Date"
  } 
  if (mode == 2){
    tsmin <- ts[,2:ncol(ts)][, lapply(.SD, min), by=ts$Date]
    colnames(tsmin)[1] <- "Date"
    tsmax <- ts[,2:ncol(ts)][, lapply(.SD, max), by=ts$Date]
    colnames(tsmax)[1] <- "Date"
    tsmn <- ts[,2:ncol(ts)][, lapply(.SD, mean), by=ts$Date]
    colnames(tsmn)[1] <- "Date"
  } 
  if (mode == 3){
    tsmax <- ts[,2:ncol(ts)][, lapply(.SD, max), by=ts$Date]
    colnames(tsmax)[1] <- "Date"
    tsmn <- ts[,2:ncol(ts)][, lapply(.SD, mean), by=ts$Date]
    colnames(tsmn)[1] <- "Date"
  } 
  if (mode == 4){
    ts <- ts[,2:ncol(ts)][, lapply(.SD, mean), by=ts$Date]
    colnames(ts)[1] <- "Date"
  }
  
  
  #########################
  ### PREPARE BEFORE EXPORT
  
  # transform Date to character in a specific format
  if (mode == 2){
    tsmin$Date <- as.character(tsmin$Date, format = "%Y %m %d")
    tsmn$Date <- as.character(tsmn$Date, format = "%Y %m %d")
    tsmax$Date <- as.character(tsmax$Date, format = "%Y %m %d")
  } else if (mode == 3){
    tsmn$Date <- as.character(tsmn$Date, format = "%Y %m %d")
    tsmax$Date <- as.character(tsmax$Date, format = "%Y %m %d")
  } else {
    ts$Date <- as.character(ts$Date, format = "%Y %m %d")
  }
  
  # create colnames
  cols <- colnames(ts[,!1])
  
  # round values from tables
  if (files[i] %in% c("surface_pressure", "snow_density")){
    ts[,(cols) := round(.SD,0), .SDcols=cols] # to 0 digits
  }
  if (files[i] %in% c("surface_net_solar_radiation", "surface_net_thermal_radiation")){
    tsmax[,(cols) := round(.SD,0), .SDcols=cols] # to 0 digits
    tsmn[,(cols) := round(.SD,0), .SDcols=cols] # to 0 digits
  }
  if (files[i] %in% c("10m_u_component_of_wind", "10m_v_component_of_wind", "leaf_area_index_high_vegetation", "leaf_area_index_low_vegetation")){
    ts[,(cols) := round(.SD,1), .SDcols=cols] # to 1 digits
  }
  if (files[i] %in% c("2m_temperature", "2m_dewpoint_temperature", "skin_temperature")){
    tsmin[,(cols) := round(.SD,1), .SDcols=cols] # to 1 digits
    tsmax[,(cols) := round(.SD,1), .SDcols=cols] # to 1 digits
    tsmn[,(cols) := round(.SD,1), .SDcols=cols] # to 1 digits
  }
  if (files[i] %in% c("forecast_albedo","potential_evaporation","total_evaporation", "total_precipitation", "snow_albedo", "snow_cover", "snowmelt", "snow_depth_water_equivalent", 
                      "volumetric_soil_water_layer_4", "volumetric_soil_water_layer_123")){
    ts[,(cols) := round(.SD,2), .SDcols=cols] # to 2 digits
  }
  
  # rename column Date
  if (mode == 1 | mode == 4){
    colnames(ts)[1] <- "YYYY MM DD"
  } 
  if (mode == 2){
    colnames(tsmin)[1] <- "YYYY MM DD"
    colnames(tsmax)[1] <- "YYYY MM DD"
    colnames(tsmn)[1] <- "YYYY MM DD"
  } 
  if (mode == 3){
    colnames(tsmax)[1] <- "YYYY MM DD"
    colnames(tsmn)[1] <- "YYYY MM DD"
  }
  
  
  ########## 
  ### EXPORT
  
  # create output pathname
  if (mode == 2){
    exportmin <- paste(outpath, "ERA5L_", files[i], "_min.csv", sep = "")
    exportmax <- paste(outpath, "ERA5L_", files[i], "_max.csv", sep = "")
    exportmn <- paste(outpath, "ERA5L_", files[i], "_mean.csv", sep = "")
  } else if (mode == 3){
    exportmax <- paste(outpath, "ERA5L_", files[i], "_max.csv", sep = "")
    exportmn <- paste(outpath, "ERA5L_", files[i], "_mean.csv", sep = "")
  } else {
    export <- paste(outpath, "ERA5L_", files[i], ".csv", sep = "")
  }
  
  # save table as text file
  if (mode == 2){
    fwrite(tsmin, exportmin, sep = ",", row.names = FALSE, col.names = TRUE)
    fwrite(tsmax, exportmax, sep = ",", row.names = FALSE, col.names = TRUE)
    fwrite(tsmn, exportmn, sep = ",", row.names = FALSE, col.names = TRUE)
  } else if (mode == 3){
    fwrite(tsmax, exportmax, sep = ",", row.names = FALSE, col.names = TRUE)
    fwrite(tsmn, exportmn, sep = ",", row.names = FALSE, col.names = TRUE)
  } else {
    fwrite(ts, export, sep = ",", row.names = FALSE, col.names = TRUE)
  } 

# end loop
}