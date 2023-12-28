### OBJECT
# Adds quality flags for "consecutive equal values" and "outliers" to runoff timeseries

### INFO
# script "Timeseries_runoff.R" must have already been executed
# equations according to Gudmundsson et al. 2018, chapter 2.3, https://essd.copernicus.org/articles/10/787/2018/
# choose between daily and hourly
# flag 1) gaps (-999), no column added to time series
# flag 2) consecutive equal values
# flag 3) outliers (this flag can also indicate runoff values as outliers, which are in fact extraordinary high/low flows, see equations for setting the boundaries in the script)

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES
library(data.table)


###############
### PRESETTINGS

# set time resolution ("d" or "h")
mode <- "h"

# Flag 2
# see Gudmundsson et al. 2018, chapter 2.3, point 2, https://essd.copernicus.org/articles/10/787/2018/
# minimum days/hours with constant runoff; 
ncons <- 10

# Flag 3
# see Gudmundsson et al. 2018, chapter 2.3, point 3, https://essd.copernicus.org/articles/10/787/2018/
# length of moving window for calculating the mean/stdev is set to 5 days (line 159ff)
# n-times stdev for calculating lower/upper boundary
ndev <- 6

# paths (choose between daily="d" and hourly="h")
if (mode == "d"){
  path <- "D:/LamaH/D_gauges/2_timeseries/daily/" # for daily time series
} else {
  path <- "D:/LamaH/D_gauges/2_timeseries/hourly/" # for hourly time series
}
outpath <- "D:/Data/Attributes/" # for summary files

# get list of files in working directory
filenames <- list.files(path)


##############
### PROCESSING

# create empty vectors, which indicates if a flag was set / number "-999" is present in time series
flag1 <- c()
flag2 <- c()
flag3 <- c()
nine_f1 <- c()
nine_f2 <- c()
nine_f3 <- c()


## Loop through gauges
for (i in filenames){
  
  # print actual loop step
  print(i)
  
  # get ID number
  id <- as.integer(unlist(strsplit(unlist(strsplit(i, "_"))[2], ".c"))[1])   
  
  # import timeseries, transform character dates to Dates
  if (mode == "d"){
    ts <- fread(paste0(path, i), header=TRUE)
    ts$date <- paste(ts$YYYY, ts$MM, ts$DD, sep = " ")
    ts$date <- as.Date(strptime(ts$date, format='%Y %m %d'))
  } else {
    ts <- fread(paste0(path, i), header=TRUE)
    ts$date <- paste(ts$YYYY, ts$MM, ts$DD, ts$hh, ts$mm, sep = " ")
    dates <- strptime(ts[,ts$date], format = "%Y %m %d %H %M", tz = "GMT")
    ts$date <- as.POSIXct(dates)
  }
  
  # get sum of NAs and -999 in timeseries
  nas <- sum(is.na(ts$qobs))
  nines <- sum(ts$qobs==-999)
  
  
  ##########
  ### Flag 1
  
  # write summary for flag 1
  if(nines == 0){
    flag1[id] <- 0
  } else {
    flag1[id] <- 1
  }
  
  
  ##########
  ### Flag 2
  
  # create column with -999
  ts$qceq <- -999
  
  # get number of consecutive equals in vector
  conseq <- rle(ts$qobs)$length
  
  # replicate each element by its value (to get the length of the timeseries again)
  conrep <- rep(conseq, conseq)
  
  # create vector, where at least 10 consecutive equals are declared by 1, else 0
  ts$qceq <- ifelse(conrep < ncons, 0, 1)
  
  # write summary for flag 2
  if(sum(ts$qceq) == 0){
    flag2[id] <- 0
  } else {
    flag2[id] <- 1
  }
  
  
  ##########
  ### Flag 3
  
  ## Calculate mean and stdev for every calender day, including rim days
  
  # create column with -999
  ts$qcol <- -999
  
  # calculate log(qobs+0.01)
  ts$logq <- log10(ts$qobs+0.01)
  
  # add day of year to every row
  ts$doy <- as.integer(strftime(ts$date, format='%j', tz = "GMT"))
  
  # add hour of year to every row
  if (mode == "h"){
    choy <- function(doy,H){
      24*(doy-1)+H+1
    }
    ts$hoy <- choy(ts$doy,ts$hh)
  }
  
  # create empty vectors for storing the statistics
  mn <- c()
  std <- c()
  
  # get latest day of year (doy) in ts
  doym <- max(ts$doy)
  
  
  ## Get statistics
    
  # loop through day of years to get statistics
  for (x in 1:doym){
    
    # moving window of 5 days
    j <- seq(x-2,x+2)
    
    # exclude lower/upper rim days at begin/end of timeseries
    if (x == 1){
      j <- j[! j %in% c(-1,0)]
    } else if (x == 2) {
      j <- j[! j %in% c(0)]
    } else if (x == (doym-1)){
      j <- j[! j %in% c(doym+1)]
    } else if (x == doym){
      j <- j[! j %in% c(doym+1, doym+2)]
    }
    
    if (mode == "d"){
      
      # put needed values in vector and calculate statistics mean and stdev, ignore NAs
      k <- ts$logq[ts$doy %in% j]
      mn[x] <- mean(k, na.rm=TRUE)
      std[x] <- sd(k, na.rm=TRUE)
      
    } else {
    
      z <- choy(x,0:23)
      fmn <- function(y){
        mean(ts$logq[ts$doy %in% j & ts$hh %in% y], na.rm=TRUE)
      }
      fsd <- function(y){
        sd(ts$logq[ts$doy %in% j & ts$hh %in% y], na.rm=TRUE)
      }
      mn[z] <- mapply(fmn, 0:23)
      std[z] <- mapply(fsd, 0:23)
    
    }
  }

  # check if "logq" is within boundary, else set flag (for each timestep)
  if (mode == "d"){
    ts$qcol <- ifelse(ts$logq < (mn[ts$doy]-ndev*std[ts$doy]) | ts$logq > (mn[ts$doy]+ndev*std[ts$doy]), 1,0)
  } else {
    ts$qcol <- ifelse(ts$logq < (mn[ts$hoy]-ndev*std[ts$hoy]) | ts$logq > (mn[ts$hoy]+ndev*std[ts$hoy]), 1,0)
  }
  
  # delete unused columns 
  if (mode == "d"){
    ts <- ts[, !c("date","doy","logq")]
  } else {
    ts <- ts[, !c("date","doy","hoy","logq")]
  }
  
  # write summary for flag 3
  if(sum(ts$qcol, na.rm=TRUE) == 0){
    flag3[id] <- 0
  } else {
    flag3[id] <- 1
  }
  
  
  ## Check for -999 in quality flag columns
  nine_f1[id] <- sum(ts$ckhs==-999, na.rm=TRUE)
  nine_f2[id] <- sum(ts$qceq==-999, na.rm=TRUE)
  nine_f3[id] <- sum(ts$qcol==-999, na.rm=TRUE)
  
  
  ######################
  ### EXPORT TIME SERIES
  
  # create output name
  outn <- paste0(path, i)
  
  # export revised table
  fwrite(ts, outn, sep = ";", row.names = FALSE, col.names = TRUE)
  
  # delete unused variables
  rm(nines, nas, conseq, conrep, ts)
  
}

########################
### EXPORT SUMMARY FILES 

write.csv2(flag1, paste0(outpath, "flag1.csv"), row.names=TRUE)
write.csv2(flag2, paste0(outpath, "flag2.csv"), row.names=TRUE)
write.csv2(flag3, paste0(outpath, "flag3.csv"), row.names=TRUE)