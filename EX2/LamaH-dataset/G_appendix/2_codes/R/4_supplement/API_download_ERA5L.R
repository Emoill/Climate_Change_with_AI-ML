### OBJECT
# Download hourly ERA5-Land data from ECMWF server

### INFO
# ECMWF account is required

### AUTHOR
# by Christoph Klingler & Thomas Pulka, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES

# install packages, if required
if(!require(ecmwfr)) install.packages("ecmwfr", repos = "http://cran.us.r-project.org")
if(!require(keyring)) install.packages("keyring", repos = "http://cran.us.r-project.org")
if(!require(maps)) install.packages("maps", repos = "http://cran.us.r-project.org")
if(!require(raster)) install.packages("raster", repos = "http://cran.us.r-project.org")


##############
### PRESETTING

# login data to ECMWF, enter your personal username and key
usr = "xxxxx"
ky = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# save ECMWF user data
wf_set_key(user = usr, key = ky, service = "cds")

# set desired variables
variables = c("snowmelt")
#variables = c("2m_dewpoint_temperature", "2m_temperature", "potential_evaporation", "total_precipitation", "total_evaporation", "surface_pressure", "leaf_area_index_low_vegetation", "leaf_area_index_high_vegetation" 
              #"10m_u_component_of_wind", "10m_v_component_of_wind", "surface_net_solar_radiation", "surface_net_thermal_radiation", "snow_depth_water_equivalent",
              #"volumetric_soil_water_layer_1", "volumetric_soil_water_layer_2", "volumetric_soil_water_layer_3", "volumetric_soil_water_layer_4",
              #"forecast_albedo", "snow_albedo", "snow_cover", "snow_density", "snowmelt")

# start and end date
startyear <- 1981
endyear <- 2019
years <- startyear:endyear

# output path
pth <- "D:/Data/ERA5_Land"


##################
### START DOWNLOAD

cat("Start ERA5-Land download ...", "\n")

for (variable in variables){

  for (year in years){
    
  # specify the data set request
  request <- list(
    variable = variable,
    year = year,
    month = c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"),
    day = c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31"),
    time = c("00:00", "01:00", "02:00", "03:00", "04:00", "05:00", "06:00", "07:00", "08:00", "09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00", "17:00", "18:00", "19:00", "20:00", "21:00", "22:00", "23:00"),
    area = c(50.5, 8, 46, 18.5), # WGS84 coordinates, North/West/South/East
    format = "netcdf",
    dataset_short_name = "reanalysis-era5-land",
    target = paste0("ERA5-Land_", variable, "_", year, ".nc")
  )
  
  ncfile <- wf_request(user = usr,
            request = request,   
            transfer = TRUE,  
            path = pth,
            verbose = FALSE)
  
  cat("Download year ", year, " for variable ", variable, " is complete", "\r") 
  }
}
cat("files successfully downloaded", "\r")