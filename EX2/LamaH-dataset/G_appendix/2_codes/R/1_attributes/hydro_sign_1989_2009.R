### OBJECT
# Calculate hydrological signatures for the period 1 October 1989 to 30 September 2009

### INFO
# scripts "Transform_timeseries_hourly_to_daily.R" and "Timeseries_runoff.R" must have already been executed

### AUTHOR
# by Nans Addor (CAMELS dataset, 2017), paper https://doi.org/10.5194/hess-21-5293-2017 / code repository https://github.com/naddor/camels
# with adaptions and extensions by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES
library(data.table)
library(lfstat)
library(xts)
library(zoo)


############
### SETTINGS

# set working direction
setwd("D:/LamaH/G_appendix/1_codes/R/1_attributes")

# load R-scripts in workspace
source('supplement/hydro_signatures.R')
  
# set preferences
hy_cal = 'oct_us_gb' # hydrological year starts in October and ends in September of the next year, see "time_tools.R" in supplement
tol = 0.05 # tolerated gaps in timerow [-], (here 5%)

# time window for calculation
per_start <- as.Date('1989-10-01')
per_end <- as.Date('2009-09-30')

# set working direction
setwd("D:/LamaH/D_gauges/2_timeseries/daily")

# get list of files in working directory
filenames <- list.files()


##############
### PROCESSING

# create data.frames
camels_hydro_obs <- data.frame(stringsAsFactors=FALSE)

# empty matrix for storing beg and end date for calculating the hydro_indices
period <- data.frame(stringsAsFactors=FALSE)

# load data for precipitation (output path of "Transform_timeseries_hourly_to_daily.R")
tprec <- fread("D:/Data/TS_met/A/daily/ERA5L_total_precipitation.csv",header=TRUE)

# load catchment areas
catchareas <- read.csv("D:/LamaH/A_basins_total_upstrm/1_attributes/Catchment_attributes.csv",header=TRUE,sep=";")[c("ID","area_calc")]

# get colnames
id_list <- colnames(tprec[,!1])


## Loop through catchments
for(i in id_list){
  
  # get index of matching files
  idx <- match(c(paste0("ID_",i,".csv")),filenames)
  
  # get filename
  filename <- filenames[idx]
  
  # print loop status
  print(filename)
  
  # load data
  tq <- fread(paste0(getwd(),"/",filename),header=TRUE) # runoff in [m3/s]
  tp <- data.table(date=tprec[,1], prec=tprec[,get(i)]) # precipitation in [mm]
  area <- catchareas[which(catchareas$ID == as.numeric(i)),2] # area in [km2]
  
  # paste date columns of tq
  tq$date <- paste(tq$YYYY,tq$MM,tq$DD, sep=" ")
  
  # rename column
  names(tp)[1] <- c("date")
  
  # transform char dates in column 1 to dates
  tq$date <- as.Date(strptime(tq$date, format='%Y %m %j'))
  tp$date <- as.Date(strptime(tp$date, format='%Y %m %j'))
  
  # set -999 in timeseries as NA
  tq$qobs[tq$qobs == -999] <- NA
  tp$prec[tp$prec == -999] <- NA
  
  
  ## Set sub-period
  
  # clip time window of precipitation data to those of runoff data
  tp <- tp[which(tp$date == tq$date[1]):which(tp$date == tq$date[nrow(tq)]),]
  
  # get vectors
  day <- tq$date
  q_obs <- tq$qobs
  prec <- tp$prec
  
  # clip to defined time window
  in_period <- day>=per_start&day<=per_end
  q_obs <- q_obs[in_period]
  prec <- prec[in_period]
  day <- day[in_period]
  
  # get specific daily discharge in [mm]
  q_obs <- q_obs*(3600*24)/(area*1000)
  
  
  ## Compute hydrological signatures
  
  # write ID to table
  camels_hydro_obs[i,'ID'] <- as.numeric(i)
  
  # check if timerow covers the whole defined time window, otherwise skip loop step
  if(min(day)>per_start|max(day)<per_end){
    next
  }
  
  # compute hydro indices
  dat <- compute_hydro_signatures_camels(q=q_obs,p=prec,d=day,tol=tol,hy_cal=hy_cal)
  
  # write hydro indices to table
  camels_hydro_obs[i,names(dat)] <- dat
  
}


##########
### EXPORT

# function to round dataframe, applied only to columns with numeric format
round_df <- function(x, digits) {
  # x: data frame 
  # digits: number of digits to round
  nums <- vapply(x, is.numeric, FUN.VALUE = logical(1))
  x[,nums] <- round(x[,nums], digits = digits)
  (x)
}

# apply function
camels_hydro_obs <- round_df(camels_hydro_obs, 3)

# set working direction
setwd("D:/Data/Indices")

# export
write.table(camels_hydro_obs, file='Hydro_sign_1989_2009.csv', row.names=FALSE, quote=FALSE, sep=';')