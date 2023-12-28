### OBJECT
# Calculate climate indices for the period 1 October 1989 to 30 September 2009

### INFO
# choose between basin delineation A, B or C
# script "Transform_timeseries_hourly_to_daily.R" must have already been executed
# all 3 time series (temp, prec, et) must have the same length (ensured by using "Timeseries_met_ERA5L.R" and "Transform_timeseries_hourly_to_daily.R" with default settings)

### AUTHOR
# by Nans Addor (CAMELS dataset, 2017), paper https://doi.org/10.5194/hess-21-5293-2017 / code repository https://github.com/naddor/camels
# with adaptions and extensions by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES
library(data.table)


############
### SETTINGS

# set working direction
setwd("D:/LamaH/G_appendix/2_codes/R/1_attributes")

# load R-scripts in workspace
source('supplement/clim_indices.R')

# set preferences
hy_cal = 'oct_us_gb' # hydrological year starts in October and ends in September of the next year, see "time_tools.R" in supplement
tol = 0.05 # tolerated gaps in timerow [-], (here 5%)

# define period over which indices and signatures will be computed
per_start <- as.Date('1989-10-01')
per_end <- as.Date('2009-09-30')
per_all <- seq(per_start,per_end,by='day')

# create data frames
camels_clim <- data.frame(stringsAsFactors=FALSE)
camels_hydro_obs <- data.frame(stringsAsFactors=FALSE)


#######################################
### LOAD CATCHMENT LIST AND TIME SERIES

# paths to input timeseries (output path of "Transform_timeseries_hourly_to_daily.R")
#setwd("D:/Data/TS_met/A/daily") # basin delineation A
setwd("D:/Data/TS_met/B/daily") # basin delineation B
#setwd("D:/Data/TS_met/C/daily") # basin delineation C

# import timeseries
DT_temp <- fread("ERA5L_2m_temperature_mean.csv", header = TRUE, sep = ";", dec = ".")
DT_prec <- fread("ERA5L_total_precipitation.csv", header = TRUE, sep = ";", dec = ".")
DT_et <- fread("ERA5L_total_evaporation.csv", header = TRUE, sep = ";", dec = ".")


##############
### PROCESSING

# create char sequence for colnames, skip header "Date"
ID_list <- as.integer(names(DT_temp)[2:ncol(DT_temp)])

## Loop through catchments
for(i in 1:length(ID_list)){
  
  catch_id <- unname(ID_list[i])
  
  print(paste0(i,' / ',catch_id))
  
  # select date series  
  day <- as.Date(DT_temp[[1]], "%Y %m %d")
  # select time series from loaded data table (i+1 --> excluding the first column "Date") 
  temp <- DT_temp[[i+1]]
  prec <- DT_prec[[i+1]]
  et <- DT_et[[i+1]]
  
  # select sub-period over which indices will be computed
  if(min(day)>per_start|max(day)<per_end){
    stop('The period over which the indices should be computed is not fully covered by the data')
  }
  
  # clip to defined time window
  in_period <- day>=per_start&day<=per_end
  temp <- temp[in_period]
  prec <- prec[in_period]
  et <- et[in_period]
  day <- day[in_period]
  
  # compute climate indices
  camels_clim[i,'ID'] <- as.character(catch_id)
  dat <- compute_clim_indices_camels(temp=temp,prec=prec,pet=et,day=day,tol=tol)
  camels_clim[i,names(dat)] <- dat
  
  if (i==1 && is.na(camels_clim$high_prec_timing)){
    camels_clim$high_prec_timing <- camels_clim$low_prec_timing
  }
  
  levels(camels_clim$high_prec_timing) <- c('djf','mam','jja','son')
  levels(camels_clim$low_prec_timing) <- c('djf','mam','jja','son')
  
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
camels_clim <- round_df(camels_clim, 2)

# set working direction
setwd("D:/Data/Indices")

# export
write.table(camels_clim, file='Clim_ind_1989_2009.csv', row.names=FALSE, col.names=TRUE, quote=FALSE, sep=';')