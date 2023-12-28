### OBJECT
# process the runoff data - provided by the governments - to an unique form
# with hourly and daily time resolution
# transform timezone CET to UTC (=GMT)

### INFO
# folders "daily", "hourly" and "gaps" must be created in export repository before executing the script
# time period 1 October 1981 to 31 December 2017
# gaps (NAs) are linear interpolated, maximum number of interpolated gaps is 6, remaining gaps are filled with -999
# the interpolated time steps are output as additional text file
# country (variable cty) must be selected
# supplementary script "Qual_flags_runoff.R" adds quality flags to generated runoff time series (should be executed afterwards)

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES

# call additional packages
library(data.table)
library(zoo)


###############
### PRESETTINGS

# import gauge attributes
attrs <- read.table("D:/LamaH/D_gauges/1_attributes/Gauge_attributes.csv", header = TRUE, sep = ";")

# transform factor columns to character
fcols <- sapply(attrs, is.factor)
attrs[fcols] <- lapply(attrs[fcols], as.character)

# rename first column
names(attrs)[1] <- "ID"

# start and end date of timeseries
start_dt <- as.POSIXct("01.01.1981 00:00:00", format="%d.%m.%Y %H:%M:%S", tz = "GMT")
end_dt <- as.POSIXct("31.12.2017 23:00:00", format="%d.%m.%Y %H:%M:%S", tz = "GMT")

# set country
# Austria --> 1 / Bavaria --> 2 / Baden-Wuerttemberg --> 3 / Switzerland --> 4 /
# Czech Rep, Brno, daily --> 51 / Czech Rep, Brno, hourly --> 52 / Czech Rep, Ostrava, daily --> 61 / Czech Rep, Ostrava, hourly --> 62
cty <- 2

# set output path
outpth <- "D:/LamaH/D_gauges/2_timeseries"

# settings per country
if (cty == 1){ 
  setwd("D:/Data/Runoff/Austria") 
  mode <- "hourly"  
} else if (cty == 2){
  setwd("D:/Data/Runoff/Bavaria") # input path
  skp <- 10 # number of lines to skip while importing
  mode <- "hourly" # time resolution
} else if (cty == 3){
  setwd("D:/Data/Runoff/Baden_Wuerttemberg")
  skp <- 4
  mode <- "hourly"
} else if (cty == 4){
  setwd("D:/Data/Runoff/Switzerland")
  skp <- 8
  mode <- "hourly"
} else if (cty == 51){
  setwd("D:/Data/Runoff/Czech/Brno_dy")
  mode <- "daily"
} else if (cty == 52){
  setwd("D:/Data/Runoff/Czech/Brno_hr")
  mode <- "hourly"
} else if (cty == 61){
  setwd("D:/Data/Runoff/Czech/Ostrava_dy")
  mode <- "daily"
} else if (cty == 62){
  setwd("D:/Data/Runoff/Czech/Ostrava_hr")
  mode <- "hourly"
} 


############## 
### PROCESSING

# get list of files in working directory
filenames <- list.files()


## Start loop to process every single file in working directory (wd)
for (i in sequence(length(filenames))){
  
  # print actual step
  print(paste("actual step:", i, sep = " "))
  
  # concatenate wd and filename
  path <- paste0(getwd(), "/", filenames[i])
  
  
  ## Preparation depending on data provider
  
  # Austria
  if (cty == 1){ 
    
    # import runoff data of specific gauge as data.table
    ts <- fread(path, header = FALSE, nrows = Inf, fill = TRUE)
    
    # search for rownumber of word "Werte:" to cut the header
    rownrhd <- which(ts$V1 == "Werte:")
    
    # cut table
    ts <- ts[(rownrhd+1):nrow(ts), 1:3]
    
    # get govnr (HZBNR)
    govnr <- as.integer(substr(filenames[i], nchar(filenames[i])-9, nchar(filenames[i])-4))
    
    # merge two time columns of timeseries
    ts$Date <- paste(ts$V1, ts$V2, sep = " ")
    
    # keep only column 4 and 3
    ts <- ts[,c(4,3)]
    
    # rename column
    names(ts)[2] <- "Qobs"
    
    # transform char dates in column 1 to POSIXct dates
    dates <- strptime(ts[,ts$Date], format = "%d.%m.%Y %H:%M:%S", tz = "GMT")
    ts <- data.table(Date = as.POSIXct(dates), ts[,2])
    
    # transform values from char to numeric
    ts$Qobs <- as.numeric(ts$Qobs)
    
    # add column "ckhs", all time steps are checked by the hydrographic service
    ts$ckhs <- 1
  
  # Bavaria  
  } else if (cty == 2){
    
    # import runoff data of specific gauge as data.table
    ts <- fread(path, header = FALSE, nrows = Inf, skip = skp)
    
    # get govnr
    govnr <- as.integer(substr(filenames[i], 1, 8))
    
    # rename columns
    names(ts)[1] <- "Date"
    names(ts)[2] <- "Qobs"
    names(ts)[3] <- "ckhs"
    
    # transform the char dates in column 1 to POSIXct dates
    dates <- strptime(ts[,ts$Date], format = "%Y-%m-%d %H:%M", tz = "GMT")
    ts <- data.table(Date = as.POSIXct(dates), ts[,2:3])
    
    # subtract 900 seconds (15 minutes), because timestamp are provided after intervall and we want before
    ts$Date <- ts$Date-900
    
    # transform Date from POSIX to character in a specific format, cut off the minutes
    ts$Date <- as.character(ts$Date, format = "%Y-%m-%d %H") 
    
    # replace comma by point in data column
    ts[,2] <- ts[, lapply(ts[,2], function(x) gsub(",", ".", x))]
    
    # transform values from char to numeric
    ts$Qobs <- as.numeric(ts$Qobs)
    
    # replace strings in column "ckhs"
    ts$ckhs[ts$ckhs == "Geprueft"] <- 1
    ts$ckhs[ts$ckhs == "Rohdaten"] <- 0
    
    # transform "ckhs" from character to numeric
    ts[,3] <- sapply(ts[,3], as.numeric)
    
    # create time series with hourly resolution
	  # mean the values of a hour, dont consider NA´s
    ts <- ts[,2:3][, lapply(.SD, mean, na.rm=TRUE), by=ts$Date]
    
    # floor meaned flags for "ckhs"
    ts[,3] <- floor(ts[,3])
    
    # rename columns
    names(ts)[1] <- "Date"
    
    # transform char dates in column 1 to POSIXct dates
    dates <- strptime(ts[,ts$Date], format = "%Y-%m-%d %H", tz = "GMT")
    ts <- data.table(Date = as.POSIXct(dates), ts[,2:3])

  # Baden-Wuerttemberg  
  } else if (cty == 3){
    
    # import runoff data of specific gauge as data.table
    ts <- fread(path, header = FALSE, nrows = Inf, skip = skp)
    
    # get govnr
    govnr <- as.integer(read.table(path, skip=1, nrows=1)[,1])
    
    # rename columns
    names(ts)[1] <- "Date"
    names(ts)[2] <- "Qobs"
    names(ts)[3] <- "ckhs"
    
    # replace comma by point in data column
    ts[,2] <- ts[, lapply(ts[,2], function(x) gsub(",", ".", x))]
    
    # transform values from char to numeric
    ts$Qobs <- as.numeric(ts$Qobs)
    
    # replace strings in column "ckhs"
    ts$ckhs[ts$ckhs == "ja"] <- 1
    ts$ckhs[ts$ckhs == "nein"] <- 0
    
    # transform "ckhs" from character to numeric
    ts[,3] <- sapply(ts[,3], as.numeric)
    
    # transform char dates in column 1 to POSIXct dates
    dates <- strptime(ts[,ts$Date], format = "%d.%m.%Y %H:%M", tz = "GMT")
    ts <- data.table(Date = as.POSIXct(dates), ts[,2:3])

  # Switzerland 
  } else if (cty == 4){
    
    # import runoff data of specific gauge as data.table
    ts <- fread(path, header = TRUE, nrows = Inf, skip = skp)
    
    # cut table
    ts <- ts[1:nrow(ts), c(7,9,10)]
    
    # get govnr
    govnr <- as.integer(read.table(path, nrows=1)[,2])
       
    # rename columns
    names(ts)[1] <- "Date"
    names(ts)[2] <- "Qobs"
    names(ts)[3] <- "ckhs"
    
    # transform values from char to numeric
    ts$Qobs <- as.numeric(ts$Qobs)
    
    # replace strings in column "ckhs"
    ts$ckhs[ts$ckhs == "Freigegeben, validierte Daten"] <- 1
    ts$ckhs[ts$ckhs == "Freigegeben, provisorische Daten"] <- 0
    
    # transform "ckhs" from character to numeric
    ts[,3] <- sapply(ts[,3], as.numeric)
    
    # transform char dates in column 1 to POSIXct dates
    dates <- strptime(ts[,ts$Date], format = "%Y-%m-%d %H:%M:%S", tz = "GMT")
    ts <- data.table(Date = as.POSIXct(dates), ts[,2:3])
  
  # Czech Rep, Brno, daily  
  } else if (cty == 51){
    
    # import runoff data of specific gauge as data.table
    ts <- fread(path, header = FALSE, nrows = Inf, fill = TRUE)
    
    # get govnr (database nr)
    govnr <- as.integer(substr(filenames[i], nchar(filenames[i])-10, nchar(filenames[i])-6))
        
    # keep only column 2 and 4
    ts <- ts[,c(2,4)]
    
    # rename column
    names(ts)[1] <- "Date"
    names(ts)[2] <- "Qobs"
    
    # transform char dates in column 1 to Dates
    dates <- as.Date(ts[,ts$Date], format = "%d.%m.%Y %H:%M")
    ts <- data.table(Date = dates, ts[,2])
    
    # transform values from char to numeric
    ts$Qobs <- as.numeric(ts$Qobs)
    
    # add column "ckhs", all time steps are checked by the hydrographic service
    ts$ckhs <- 1
  
  # Czech Rep, Brno, hourly    
  } else if (cty == 52){
    
    # import runoff data of specific gauge as data.table
    ts <- fread(path, header = FALSE, nrows = Inf)
    
    # get govnr (database nr)
    govnr <- as.integer(substr(filenames[i], nchar(filenames[i])-10, nchar(filenames[i])-6))
    
    # keep only column 2 and 4
    ts <- ts[,c(2,4)]
    
    # rename column
    names(ts)[1] <- "Date"
    names(ts)[2] <- "Qobs"
    
    # transform char dates in column 1 to Dates
    dates <- strptime(ts[,ts$Date], format = "%d.%m.%Y %H:%M", tz = "GMT")
    ts <- data.table(Date = as.POSIXct(dates), ts[,2])
    
    # transform values from char to numeric
    ts$Qobs <- as.numeric(ts$Qobs)
    
    # add column "ckhs", all time steps are checked by the hydrographic service
    ts$ckhs <- 1
   
  # Czech Rep, Ostrava, daily     
  } else if (cty == 61){
    
    # import runoff data of specific gauge as data.table
    ts <- fread(path, header = TRUE, nrows = Inf)
    
    # get govnr (database nr)
    govnr <- as.integer(substr(filenames[i], nchar(filenames[i])-10, nchar(filenames[i])-6))
    
    # keep only column 2 and 3
    ts <- ts[,c(2,3)]
    
    # rename column
    names(ts)[1] <- "Date"
    names(ts)[2] <- "Qobs"
    
    # transform char dates in column 1 to Dates
    dates <- as.Date(ts[,ts$Date], format = "%d.%m.%Y")
    ts <- data.table(Date = dates, ts[,2])
    
    # transform values from char to numeric
    ts$Qobs <- as.numeric(ts$Qobs)
    
    # add column "ckhs", all time steps are checked by the hydrographic service
    ts$ckhs <- 1
  
  # Czech Rep, Ostrava, hourly    
  } else if (cty == 62){
    
    # import runoff data of specific gauge as data.table
    ts <- fread(path, header = TRUE, nrows = Inf)
    
    # get govnr (database nr)
    govnr <- as.integer(substr(filenames[i], nchar(filenames[i])-10, nchar(filenames[i])-6))
    
    # merge two time columns of timeseries
    ts$Date <- paste(ts$datum, ts$hodina, sep = " ")
    
    # keep only column 5 and 4
    ts <- ts[,c(5,4)]
    
    # rename column
    names(ts)[2] <- "Qobs"
    
    # transform the char dates in column 1 to POSIXct dates
    dates <- strptime(ts[,ts$Date], format = "%d.%m.%Y %H:%M", tz = "GMT")
    ts <- data.table(Date = as.POSIXct(dates), ts[,2])
    
    # transform values from char to numeric
    ts$Qobs <- as.numeric(ts$Qobs)
    
    # add column "ckhs", all time steps are checked by the hydrographic service
    ts$ckhs <- 1
    
  }
  
  # replace Qobs = "-999" and other possible negative values by NA
  ts$Qobs[ts$Qobs < 0] <- NA 
  
  
  ########################
  # mode hourly (standard)
  if (mode == "hourly"){
  
  # get rownumber of start date
  rownrst <- which(ts$Date == start_dt)
  
  # cut table at this timestamp, if table expands time window
  if (length(rownrst) > 0) {
    ts <- ts[rownrst:nrow(ts),]
  }
  
  # get rownumber of end date and add 1 for changing the time zone afterwards
  rownred <- which(ts$Date == end_dt)+1
  
  # cut table at this timestamp, if table expands time window
  if (length(rownred) > 0) {
    ts <- ts[1:rownred,]
  }
  
  # subtract 1 hour to get timezone UTC (GMT)
  ts$Date <- ts$Date-3600
  
  # get date of first data row
  firstday <- ts$Date[1]
  
  # count hours within that day
  hoursfirstday <- length(which(format(ts$Date,"%Y-%m-%d")  == format(firstday,"%Y-%m-%d")))
  
  # cut, if number of hours of that first day is not 24 -> keep only full days
  if (hoursfirstday != 24){
    ts <- ts[(hoursfirstday+1):nrow(ts),]
  }
  
  # create timesequence from start date to end date by hour
  dateseq <- seq(from = ts$Date[1], to = end_dt, by = "hour")
  
  # create table with dateseq
  th <- data.table(Date = dateseq)
  
  # merge tables
  th <- merge(th, ts, by="Date", all.x=TRUE)
  
  # create list of timesteps with NAs / no data
  gaprows <- as.vector(th[!complete.cases(th), 1])
  
  # fill NAs in other columns by interpolation, maxgap = 6
  if (nrow(gaprows) != 0){
    th <- data.table(Date=th$Date, na.approx(th[,2], na.rm = FALSE, maxgap = 6), ckhs=th$ckhs )
  }
  
  # create time series with daily resolution
  td <- th # copy table
  td$Date <- as.Date(td$Date, format = "%Y %m %d %H %M") # set first column as Date
  td <- td[,2:3][, lapply(.SD, mean), by=td$Date] # mean the values of a day
  names(td)[1] <- "Date" # rename first column
  
  # floor meaned flags for "ckhs"
  td[,3] <- floor(td[,3])
  
  # round values to 3 decimals
  th[,2 := round(.SD, 3), .SDcols=2]
  td[,2 := round(.SD, 3), .SDcols=2]
  
  # get corresponding ID number
  if (cty == 1){ 
    idnr <- attrs[which(attrs$govnr == govnr & attrs$country == "AUT"),1]
  } else if (cty == 2){
    idnr <- attrs[which(attrs$govnr == govnr & attrs$fedstate == "BAV"),1]
  } else if (cty == 3){
    idnr <- attrs[which(attrs$govnr == govnr & attrs$fedstate == "BWT"),1]
  } else if (cty == 4){
    idnr <- attrs[which(attrs$govnr == govnr & (attrs$country == "CHE" | attrs$country == "LIE")),1]
  } else if (cty == 51 | cty == 52 | cty == 61 | cty == 62){
    idnr <- attrs[which(attrs$govnr == govnr & attrs$country == "CZE"),1]
  }
  
  # fill NAs with -999
  th[,2][is.na(th[,2])] <- -999
  th[,3][is.na(th[,3])] <- 0
  th[,3][th[,2] == -999] <- 0
  td[,2][is.na(td[,2])] <- -999
  td[,3][is.na(td[,3])] <- 0
  td[,3][td[,2] == -999] <- 0
    
  # transform Date from POSIX to character in a specific format
  th$Date <- as.character(th$Date, format = "%Y %m %d %H %M")
  td$Date <- as.character(td$Date, format = "%Y %m %d")
  gaprows$Date <- as.character(gaprows$Date, format = "%Y %m %d %H %M")
  
  # split dates and transform to integer, hourly data
  th <- setDT(th)[, paste0("Date", 1:5) := tstrsplit(Date, " ")]
  th <- th[, 2:ncol(th)]
  setcolorder(th, c("Date1", "Date2", "Date3", "Date4", "Date5"))
  names(th) [1:5] = c("YYYY", "MM", "DD", "hh", "mm")
  th[, 1:5] <- lapply(th[, 1:5], as.integer)
  
  # split dates and transform to integer, daily data
  td <- setDT(td)[, paste0("Date", 1:3) := tstrsplit(Date, " ")]
  td <- td[, 2:ncol(td)]
  setcolorder(td, c("Date1", "Date2", "Date3"))
  names(td) [1:3] = c("YYYY", "MM", "DD")
  td[, 1:3] <- lapply(td[, 1:3], as.integer)
  
  # rename columns
  names(th)[6] <- "qobs"
  names(th)[7] <- "ckhs"
  names(td)[4] <- "qobs"
  names(td)[5] <- "ckhs"
  names(gaprows)[1] <- "YYYY MM DD hh mm"
  
  # create name for export file
  outnmth <- paste0(outpth, "/hourly/ID_" ,idnr, ".csv") # for timeseries with hourly resolution
  outnmtd <- paste0(outpth, "/daily/ID_" ,idnr, ".csv") # for timeseries with daily resolution
  outnmgp <- paste0(outpth, "/gaps/ID_" ,idnr, ".csv") # for gaps
  
  # save tables as text file
  fwrite(th, outnmth, sep = ";", row.names = FALSE, col.names = TRUE) # hourly
  fwrite(td, outnmtd, sep = ";", row.names = FALSE, col.names = TRUE) # daily
  if (nrow(gaprows) > 0){
    fwrite(gaprows, outnmgp, sep = ";", row.names = FALSE, col.names = TRUE)
  }
  
  # remove variables
  rm(ts, th, td, dates, gaprows, govnr, idnr, rownred, rownrst, firstday)
  
  # end mode hourly
  }
  
  
  ################################
  # mode daily (only in Czech Rep)
  if (mode == "daily"){
  
  # get rownumber of start date
  rownrst <- which(ts$Date == as.Date(start_dt))
  
  # cut table at this timestamp, if table expands time window
  if (length(rownrst) > 0) {
    ts <- ts[rownrst:nrow(ts),]
  }
  
  # get rownumber of end date
  rownred <- which(ts$Date == as.Date(end_dt))
  
  # cut table at this timestamp, if table expands time window
  if (length(rownred) > 0) {
    ts <- ts[1:rownred,]
  }
    
  # create timesequence from start date to end date by day
  dateseq <- seq(from = ts$Date[1], to = as.Date(end_dt), by = "day")
  
  # create table with dateseq
  th <- data.table(Date = dateseq)
  
  # merge tables
  td <- merge(th, ts, by="Date", all.x=TRUE)
  
  # round values to 3 decimals
  td[,2 := round(.SD, 3), .SDcols=2]
    
  # get corresponding ID number
  idnr <- attrs[which(attrs$govnr == govnr & attrs$country == "CZE"),1]
  
  # fill NAs with -999
  td[,2][is.na(td[,2])] <- -999
  td[,3][is.na(td[,3])] <- 0
  td[,3][td[,2] == -999] <- 0
  
  # transform Date from POSIX to character in a specific format
  td$Date <- as.character(td$Date, format = "%Y %m %d")
  
  # split dates and transform to integer, daily data
  td <- setDT(td)[, paste0("Date", 1:3) := tstrsplit(Date, " ")]
  td <- td[, 2:ncol(td)]
  setcolorder(td, c("Date1", "Date2", "Date3"))
  names(td) [1:3] = c("YYYY", "MM", "DD")
  td[, 1:3] <- lapply(td[, 1:3], as.integer)
  
  # rename columns
  names(td)[4] <- "qobs"
  names(td)[5] <- "ckhs"
  
  # create path and name for exporting file
  outnmtd <- paste0(outpth, "/daily/ID_" ,idnr, ".csv") # for timeseries with daily resolution
  
  # save table as text file
  fwrite(td, outnmtd, sep = ";", row.names = FALSE, col.names = TRUE) # daily
  
  # remove variables
  rm(ts, td, dates, govnr, idnr, rownred, rownrst)
  
  # end mode daily
  }
  
# end loop  
}