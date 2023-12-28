### OBJECT
# Merge meteorological ERA5-Land timeseries to get one file per basin
# for daily and hourly time resolution

### INFO
# choose between basin delineation A, B or C
# scripts "Timeseries_met_ERA5L.R" and "Transform_timeseries_hourly_to_daily.R" must have already been executed
# variables "Day of year" and "Hour of Day" will be added

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES
library(data.table)


#############
### VARIABLES

# paths to input timeseries (output path of "Timeseries_met_ERA5L.R" and "Transform_timeseries_hourly_to_daily.R")
inpath <- "D:/Data/TS_met/"

# basin delineation (A, B or C), extension to inpath
mode <- "B"

# time resolution ("hourly" or "daily")
tres <- "daily"

## Output path
#outpath <- "D:/LamaH/A_basins_total_upstrm/2_timeseries/" # basin delineation A
outpath <- "D:/LamaH/B_basins_intermediate_all/2_timeseries/" # basin delineation B
#outpath <- "D:/LamaH/C_basins_intermediate_lowimp/2_timeseries/" # basin delineation C

# names of input variables
if (tres == "hourly"){
  metvars <- c("2m_temperature", "2m_dewpoint_temperature", "10m_u_component_of_wind", "10m_v_component_of_wind", "forecast_albedo", "leaf_area_index_high_vegetation", "leaf_area_index_low_vegetation", 
               "snow_depth_water_equivalent", "surface_net_solar_radiation", "surface_net_thermal_radiation", "surface_pressure", 
               "total_evaporation", "total_precipitation", "volumetric_soil_water_layer_123", "volumetric_soil_water_layer_4") 
}
if (tres == "daily"){
  metvars <- c("2m_temperature_max", "2m_temperature_mean", "2m_temperature_min", "2m_dewpoint_temperature_max", "2m_dewpoint_temperature_mean", "2m_dewpoint_temperature_min",
               "10m_u_component_of_wind", "10m_v_component_of_wind", "forecast_albedo", "leaf_area_index_high_vegetation", "leaf_area_index_low_vegetation",
               "snow_depth_water_equivalent", "surface_net_solar_radiation_max", "surface_net_solar_radiation_mean", "surface_net_thermal_radiation_max", "surface_net_thermal_radiation_mean",
               "surface_pressure", "total_evaporation", "total_precipitation", "volumetric_soil_water_layer_123", "volumetric_soil_water_layer_4") 
}


##############
### PROCESSING

# set import path of first file in metvars
filepath1 <- paste0(inpath, mode, "/", tres, "/ERA5L_", metvars[1], ".csv")

# import only first row to get the header
cols <- as.character(fread(filepath1, header=FALSE, nrows=1))
cols <- cols[2:length(cols)]

# ALTERNATIVE: only specific colnames 
#cols <- c("735")

## Create table with colums for "Date", "Day of year" and on demand "Hour of day"

# import only first column 
tbld <- fread(filepath1, header=TRUE, select=c(1), nrows=Inf)

# rename column
colnames(tbld) <- c("Date")

# transform char dates in column 1 to dates
if (tres == "daily"){
  dates <- as.Date(strptime(tbld[,tbld$Date], format='%Y %m %d', tz = "GMT"))
}
if (tres == "hourly"){
  dates <- as.POSIXct(tbld[,tbld$Date], format='%Y %m %d %H %M', tz = "GMT")
}

# update table with dates
tbld$Date <- dates

# get day of year
doy <- as.numeric(strftime(dates, format="%j"))

# add number 1 in the front of doy, if tres is "hourly", and cut last value off
if (tres == "hourly"){
  doy <- c(1,doy[1:(length(doy)-1)])
}

# add "doy" to table
tbld <- cbind(tbld, "doy"=doy)

# get hour of day on demand
if (tres == "hourly"){
  hod <- as.numeric(hour(dates))
  # add "hod" to table
  tbld <- cbind(tbld, "hod"=hod)
}

# create empty vector for storing the NA´s
NA_sum <- c()
Nine_sum <- c()
j <- 1

## Start loop through basins
for (id in cols){
  
  # print actual state 
  print(id)
  
  # create empty data tabe
  ts <- data.table()
  
  # loop through metvars
  for (i in metvars){
    
    # set import
    filepath <- paste0(inpath, mode, "/", tres, "/ERA5L_", i, ".csv")
    
    # import timeseries for the different variables
    tm <- fread(filepath, header=TRUE, select=c(id), nrows=Inf)
    
    # bind with main table
    ts <- cbind(ts,tm)
  
  # end inner loop  
  }
  
  # bind with data table
  tbl <- cbind(tbld, ts)
  
  # transform Date to integer in a specific format and change colnames
  if (tres == "hourly"){
    tbl$Date <- as.character(tbl$Date, format = "%Y %m %d %H %M")
    tbl <- setDT(tbl)[, paste0("Date", 1:5) := tstrsplit(Date, " ")]
    tbl = tbl[, 2:ncol(tbl)]
    colnms <- c("DOY", "HOD", "2m_temp", "2m_dp_temp", "10m_wind_u", "10m_wind_v", "fcst_alb", "lai_high_veg", "lai_low_veg",
                "swe", "surf_net_solar_rad", "surf_net_therm_rad", "surf_press", "total_et", "prec", "volsw_123", "volsw_4","YYYY", "MM", "DD", "hh", "mm")
    colnames(tbl) <- colnms # rename columns
    setcolorder(tbl, c("YYYY", "MM", "DD", "hh", "mm")) # reorder columns after splitting up
    tbl[, 1:5] <- lapply(tbl[, 1:5], as.integer)
  }
  if (tres == "daily"){
    tbl$Date <- as.character(tbl$Date, format = "%Y %m %d")
    tbl <- setDT(tbl)[, paste0("Date", 1:3) := tstrsplit(Date, " ")]
    tbl = tbl[, 2:ncol(tbl)] # cut of the first column "Date"
    colnms <- c("DOY", "2m_temp_max", "2m_temp_mean", "2m_temp_min", "2m_dp_temp_max", "2m_dp_temp_mean", "2m_dp_temp_min",
                "10m_wind_u", "10m_wind_v", "fcst_alb", "lai_high_veg", "lai_low_veg",
                "swe", "surf_net_solar_rad_max", "surf_net_solar_rad_mean", "surf_net_therm_rad_max", "surf_net_therm_rad_mean",
                "surf_press", "total_et", "prec", "volsw_123", "volsw_4", "YYYY", "MM", "DD")
    colnames(tbl) <- colnms # rename columns
    setcolorder(tbl, c("YYYY", "MM", "DD")) # reorder columns after splitting up
    tbl[, 1:3] <- lapply(tbl[, 1:3], as.integer)
  }
  
  # check for number of NA´s
  NA_sum[j] <- sum(is.na(tbl))
  Nine_sum[j] <- sum(which(tbl == -999))
  j <- j+1
  
  # create path and filename for output text file
  outpath_i <- paste(outpath, tres, "/ID_", id, ".csv", sep = "")
  
  # export output file of actual year as text file
  fwrite(tbl, outpath_i, sep = ";", row.names = FALSE, col.names = TRUE)

  # reset RAM
  gc()  
  
# end outer loop
}