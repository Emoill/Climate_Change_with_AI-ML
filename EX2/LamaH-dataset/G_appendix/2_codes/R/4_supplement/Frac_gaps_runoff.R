### OBJECT
# Get fraction of gaps of hourly time series in promille before and after processing (gap filling by linear interpolation in "Timeseries_runoff.R")

### INFO
# script "Timeseries_runoff.R" must have already been executed

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES
library(data.table)


###############
### PRESETTINGS

# set paths
inpath1 <- "D:/LamaH/D_gauges/2_timeseries/hourly/"
inpath2 <- "D:/LamaH/D_gauges/2_timeseries/gaps/"
outpath <- "D:/Data/Attributes/"

# get list of files in working directory
files_ts <- list.files(inpath1)
files_gp <- list.files(inpath2)


##############
### PROCESSING

# create empty vectors, which contains the fraction of gaps in promille afterwards
gaps_pre <- rep(-999,882)
gaps_post <- rep(-999,882)

# name vectors
names(gaps_pre) <- c(1:882)
names(gaps_post) <- c(1:882)


## Loop through gauges
for (i in files_ts){
  
  # print actual loop step
  print(i)
  
  # get ID number
  id <- as.integer(unlist(strsplit(unlist(strsplit(i, "_"))[2], ".c"))[1]) 
  
  # import timeseries, transform character dates to Dates
  ts <- fread(paste0(inpath1, i), header=TRUE)
  ts$date <- paste(ts$YYYY, ts$MM, ts$DD, ts$hh, ts$mm, sep = " ")
  dates <- strptime(ts[,ts$date], format = "%Y %m %d %H %M", tz = "GMT")
  ts$date <- as.POSIXct(dates)
  
  # import file with gaps (if there is one)
  if (i %in% files_gp){
    raw <- fread(paste0(inpath2, i), header=FALSE)
    raw <- nrow(raw)
  } else {
    raw <- 0L
  }
    
  # get the number of -999 in ts
  nines <- sum(ts$qobs==-999)
  
  # calcualte fraction of pre- and post gaps in promille and write them in vectors
  gaps_pre[id] <- round((raw/nrow(ts))*1000, digits=3)
  gaps_post[id] <- round((nines/nrow(ts))*1000, digits=3)
  
  # remove unused variables
  rm(ts,dates,raw,nines)
  
}

# check vectors for unfilled places
nine_pre <- sum(gaps_pre==-999)
nine_post <- sum(gaps_post==-999)

# merge vectors to data table
res <- data.table("ID"=c(1:882),"pre"=gaps_pre,"post"=gaps_post)

# create name for export
outn <- paste0(outpath,"runoff_frac_gaps.csv")

# export result
fwrite(res,outn,sep=";",col.names = TRUE)