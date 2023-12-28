### OBJECT
# Plot spatial distribution of catchment attributes and model results as well as cumulative distribution function of model results

### INFO
# the imported shapefiles must have the same projection (default EPSG 3035)
# plots:
# topo_indices (9)
# clim_indices (9)
# hydro_indices (12)
# veg_indices (6)
# landclass (6)
# geol_indices (9)
# geol_indices (6)
# model results (3)

### AUTHOR
# by Nans Addor (CAMELS dataset, 2017), paper https://doi.org/10.5194/hess-21-5293-2017 / code repository https://github.com/naddor/camels
# with adaptions and extensions by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES
require(RColorBrewer)
require(maps)
require(TeachingDemos)
library(sf)
library(Hmisc)


##########
### IMPORT

cattrs <- read.csv("D:/LamaH/A_basins_total_upstrm/1_attributes/Catchment_attributes.csv", header=TRUE, sep=";") # catchment attributes, basin delineation A
gattrs <- read.csv("D:/LamaH/D_gauges/1_attributes/Gauge_attributes.csv", header=TRUE, sep=";") # gauge attributes
hydro_ind <- read.csv("D:/LamaH/D_gauges/1_attributes/Hydro_indices_1989_2009.csv", header=TRUE, sep=";") # hydrological indices
hier <- read.csv("D:/LamaH/B_basins_intermediate_all/1_attributes/Gauge_hierarchy.csv", header=TRUE, sep=";") # gauge hierarchies
stat_cal <- read.csv("D:/LamaH/F_hydrol_model/2_output/statistics/statistics_cal.csv", header=TRUE, sep=";")[,c("ID","NSE","pBIAS","fewobs")] # statistics of model output, calibration phase
stat_val <- read.csv("D:/LamaH/F_hydrol_model/2_output/statistics/statistics_val.csv", header=TRUE, sep=";")[,c("ID","NSE","pBIAS")] # statistics of model output, validation phase
ctry <- st_read("D:/Data/Shapefiles/ctry.shp") # borders of countries, shapefile is not included in LamaH but can be obtained from eurostat (EPSG 3035): https://ec.europa.eu/eurostat/web/gisco/geodata/reference-data/administrative-units-statistical-units/countries
regions <- st_read("D:/LamaH/G_appendix/3_shapefiles/River_regions.shp") # borders of river regions
mask <- st_read("D:/LamaH/G_appendix/3_shapefiles/Mask_ctry.shp") # mask to hide the country borders outside the area of interest


###############
### PREPARATION

# set working directory
setwd("D:/LamaH/G_appendix/4_plots")

# transform datatype factor to character
fcolsc <- sapply(cattrs, is.factor)
fcolsg <- sapply(gattrs, is.factor)
cattrs[fcolsc] <- lapply(cattrs[fcolsc], as.character)
gattrs[fcolsg] <- lapply(gattrs[fcolsg], as.character)
rm(fcolsc, fcolsg)

# join catchment and gauge attribut tables
attrs <- merge(gattrs, cattrs, by="ID", all.x=TRUE)

# join attributes with hydro_indices
attrs <- merge(attrs, hydro_ind, by="ID", all.x=TRUE)

# join attributes with gauge hierarchy
attrs <- merge(attrs, hier, by="ID", all.x=TRUE)

# set statistics to NaN, where "fewobs" is TRUE
stat_cal[stat_cal[,4] == 1,2:3] <- NaN
stat_val[stat_cal[,4] == 1,2:3] <- NaN

# rename columns of model statistics
names(stat_cal) <- c("ID","NSEcal","PBIAScal","fewobs")
names(stat_val) <- c("ID","NSEval","PBIASval")

# join attributes with model statistics
attrs <- merge(attrs, stat_cal, by="ID", all.x=TRUE)
attrs <- merge(attrs, stat_val, by="ID", all.x=TRUE)

# get column names
cols <- names(attrs)


##################
### PRINT SETTINGS

# general
gen_row <- match(c("obsbeg_hr","gaps_post","HIERARCHY",
                   "degimpact"), cols)
gen_txt <- c("a) Start of continuous data recording [year]", "b) Fraction of gaps in hourly runoff timeseries [%o]", "c) Gauge hierarchy [-]",
             "Degree of gauge impact")
gen_col_sh <- c("YlGn", "Reds", "BuPu",
                "RdYlBu")
gen_col_rev <- c(TRUE,FALSE,FALSE,
                 FALSE)
gen_col_br <- list(c(1980,1985,1990,1995,2000), c(0.1,1,5,10,50), c(2,4,6,10,12),
                   c(NA,NA,NA,NA))

# topo
topo_row <- match(c("area_calc","elev_mean","elev_ran",
                    "slope_mean","elon_ratio","strm_dens"), cols)
topo_txt <- c("a) Catchment area [km2]", "b) Mean catchment elevation [m a.s.l.]", "c) Range of catchment elevation [m a.s.l.]",
              "d) Mean catchment slope [m/km]", "e) Elongation ratio [-]", "f) Stream density [km/km2]")
topo_col_sh <- c("YlOrRd", "Blues", "BuGn",
                 "YlGnBu", "PuRd", "BuPu")
topo_col_rev <- c(FALSE,FALSE,FALSE,
                  FALSE,FALSE,FALSE)
topo_col_br <- list(c(50,200,500,2000,10000), c(300,500,800,1200,1600,2000), c(300,500,800,1200,1600,2000),
                    c(50,100,200,300,400), c(0.5,0.6,0.8,0.9,1.0), c(0.4,0.5,0.6,0.7,0.8,0.9))

# climate indices
clim_row <- match(c("p_mean","et0_mean","arid_2",
                    "p_season","hi_prec_fr","hi_prec_du",
                    "frac_snow","lo_prec_fr","lo_prec_du"), cols)
clim_txt <- c("a) Mean daily precipitation P [mm/day]", "b) Mean daily reference evapotranspiration ET0 [mm/day]", "c) Aridity (ET0/P) [-]",
              "d) Seasonality of precipitation [-]", "e) Frequency of high precip. days [days/yr]", "f) Mean duration of high precip. events [days]",
              "g) Fraction of precipitation falling as snow [-]", "h) Frequency of dry days [days/yr]", "i) Mean duration of dry periods [days]")
clim_col_sh <- c("Blues", "Reds", "Oranges",
                 "RdPu", "YlGnBu", "Blues",
                 "Blues", "YlOrRd", "Oranges")
clim_col_rev <- c(FALSE,FALSE,FALSE,
                  FALSE,FALSE,FALSE,
                  FALSE,FALSE,FALSE)
clim_col_br <- list(c(2.2,2.8,3.4,4.0,4.6), c(1.8,2.0,2.2,2.4,2.6), c(0.5,0.75,1.0,1.25,1.5),
                    c(0.1,0.2,0.3,0.4,0.5), c(10,12,14,16,18), c(1.12,1.14,1.16,1.18,1.2),
                    c(0.1,0.2,0.3,0.4,0.5), c(160,180,200,215,230), c(2.8,3.0,3.2,3.4,3.6))

# hydro indices
hydro_row <- match(c("q_mean","runoff_ratio","hfd_mean",
                     "slope_fdc","baseflow_index_ladson","stream_elas",
                     "high_q_freq","high_q_dur","Q95",
                     "low_q_freq","low_q_dur","Q5"), cols)
hydro_txt <- c("a) Mean daily discharge Q [mm/d]", "b) Runoff ratio (Q/P) [-]", "c) Mean half-flow date [days since 01. Oct.]",
               "d) Slope of the flow duration curve [-]", "e) Baseflow index [-]", "f) Discharge precipitation elasticity [-]",
               "g) High-flow frequency [days/yr]", "h) Mean high-flow duration [days]", "i) Q95 [mm/d]",
               "j) Low-flow frequency [days/yr]", "k) Mean low-flow duration [days]", "l) Q5 [mm/d]")
hydro_col_sh <- c("Blues", "YlGn", "BuGn",
                 "Oranges", "BuPu", "Reds",
                 "YlGnBu", "Blues", "Blues",
                 "YlOrRd", "Oranges", "Oranges")
hydro_col_rev <- c(FALSE,FALSE,FALSE,
                   FALSE,FALSE,FALSE,
                   FALSE,FALSE,FALSE,
                   FALSE,FALSE,TRUE)
hydro_col_br <- list(c(0.5,1.0,1.5,2.0,2.5,3.0), c(0.2,0.4,0.6,0.8,1.0), c(151,182,212,243,273),
                    c(1.0,1.5,2.0,2.5,3.0), c(0.5,0.6,0.7,0.8), c(0.5,1.0,1.5,2.0),
                    c(1,2,3,5,10), c(1.2,1.4,1.6,1.8,2.0), c(2,4,6,8,10),
                    c(0.5,2,10,20,50), c(2,4,6,10,20), c(0.1,0.2,0.4,0.6,0.8))

# landclass
lc_row <- match(c("agr_fra","bare_fra","forest_fra",
                  "glac_fra","lake_fra","urban_fra"), cols)
lc_txt <- c("a) Fraction of agriculture [-]", "b) Fraction of bare area [-]", "c) Fraction of forest [-]",
            "d) Fraction of glaciers [-]", "e) Fraction of water bodies [-]", "f) Fraction of urban areas [-]")
lc_col_sh <- c("YlGn", "OrRd", "Greens",
               "YlGnBu", "Blues", "YlOrBr")
lc_col_rev <- c(FALSE,FALSE,FALSE,
                FALSE,FALSE,FALSE)
lc_col_br <- list(c(0.1,0.2,0.4,0.6,0.8), c(0.01,0.05,0.1,0.2,0.4), c(0.1,0.2,0.4,0.6,0.8),
                  c(0.01,0.02,0.03,0.05,0.1), c(0.01,0.02,0.03,0.04,0.05), c(0.01,0.05,0.1,0.15,0.2))

# vegetation
veg_row <- match(c("lai_max","ndvi_max","gvf_max",
                   "lai_diff","ndvi_min","gvf_diff"), cols)
veg_txt <- c("a) LAI max [-]", "b) NDVI max [-]", "c) GVF max [-]",
             "d) LAI diff [-]", "e) NDVI min [-]", "f) GVF diff [-]")
veg_col_sh <- c("Blues", "Greens", "Oranges",
                "YlGnBu", "YlGn", "YlOrBr")
veg_col_rev <- c(FALSE,FALSE,TRUE,
                 FALSE,FALSE,TRUE)
veg_col_br <- list(c(1.5,2.25,3.0,3.75,4.5), c(0.4,0.5,0.6,0.7,0.8), c(0.5,0.6,0.7,0.8,0.9),
                   c(1.5,2.25,3.0,3.75,4.5), c(0.0,0.1,0.2,0.3), c(0.5,0.6,0.7,0.8,0.9))

# soil
soil_row <- match(c("bedrk_dep","root_dep","oc_fra",
                    "sand_fra","silt_fra","clay_fra",
                    "soil_poros","soil_condu","soil_tawc"), cols)
soil_txt <- c("a) Depth to bedrock [m]", "b) Depth available for roots [m]", "c) Organic fraction [-]",
              "d) Sand fraction [-]", "e) Silt fraction [-]", "f) Clay fraction [-]",
              "g) Soil porosity [-]", "h) Saturated hydraulic conductivity [cm/h]", "i) Total available water content [m]")
soil_col_sh <- c("Greens", "Oranges", "YlGn",
                 "YlGnBu", "YlGn", "YlOrBr",
                 "BuPu", "Blues", "YlGnBu")
soil_col_rev <- c(FALSE,FALSE,FALSE,
                  FALSE,FALSE,FALSE,
                  FALSE,FALSE,FALSE)
soil_col_br <- list(c(0.75,1,2,5,10), c(0.4,0.6,0.8,1.0,1.2), c(0.01,0.02,0.03,0.04,0.05),
                    c(0.35,0.40,0.45,0.50,0.55), c(0.25,0.30,0.35,0.40,0.45), c(0.10,0.15,0.20,0.25,0.30),
                    c(0.42,0.44,0.46,0.48,0.50), c(0.04,0.08,0.12,0.2,0.4,0.6), c(0.06,0.08,0.1,0.12,0.14,0.16,0.18))

# geologic
geol_row <- match(c("gc_dom","gc_mt_fra","gc_sc_fra",
                    "gc_sm_fra","geol_poros","geol_perme"), cols)
geol_txt <- c("a) Dominant geologic class", "b) Fraction of metamorphics (mt) [-]", "c) Fraction of carbonate sedimentary rocks (sc) [-]",
              "d) Fraction of mixed sedimentary rocks (sm) [-]", "e) Subsurface porosity [-]", "f) Subsurface permeability [m2, log scale]")
geol_col_sh <- c("-", "Oranges", "Blues",
                 "Greens", "YlGnBu", "YlGn")
geol_col_rev <- c(FALSE,FALSE,FALSE,
                  FALSE,FALSE,FALSE)
geol_col_br <- list(c(NA), c(0.10,0.30,0.50,0.70,0.90), c(0.10,0.30,0.50,0.70,0.90),
                    c(0.10,0.30,0.50,0.70,0.90), c(0.05,0.1,0.15,0.2), c(-14,-13,-12))

# hydrol model
hmod_row <- match(c("NSEval","PBIASval"), cols)
hmod_txt <- c("a) NSE [-], validation phase", "c) pBIAS [%], validation phase")
hmod_col_sh <- c("BrBG", "RdBu")
hmod_col_rev <- c(FALSE,FALSE)
hmod_col_br <- list(c(0,0.2,0.4,0.6,0.8), c(-20,-10,-5,0,5,10,20))

# point size (cex) depending on catchment area
catcharea <- data.frame(ID=attrs[,1], Area=attrs$area_calc)
pcex <- log10(catcharea$Area)*0.25+0.25
pcex[is.na(pcex)] <- 0.5 # replace NAs by 0.5


#################
### PLOT FUNCTION

## Plot legend
plot.legend.na<-function (col, breaks, vert=TRUE, density = NULL, angle = 45, slwd = par("lwd"), cex.leg = 1.4) {
  nbrk <- length(breaks)
  ncol <- length(col)
  if (ncol != (nbrk + 1)) {
    stop("Length of col must be length of breaks plus 1")
  }
  if (is.null(density)) {
    dens <- NULL
  }else{
    dens <- rep(density, length = ncol)
  }
  lwds <- rep(slwd, length = ncol)
  angs <- rep(angle, length = ncol)
  
  if(vert){
    image(x = c(1), y = seq(1, (ncol + 1)) - 0.5, z = matrix(seq(1, (ncol + 1)) - 0.5, nrow = 1), col = col, breaks = seq(1,(ncol + 1)), ylim = c(1, (ncol + 1)), axes = FALSE, xlab = "", ylab = "")
    for (k in 1:ncol) {
      polygon(x = c(0, 2, 2, 0, 0), y = c(k, k, k + 1, k + 1, k), col = "white", border = NA, xpd = FALSE)
      polygon(x = c(0, 2, 2, 0, 0), y = c(k, k, k + 1, k + 1, k), col = col[k], density = dens[k], lwd = lwds[k],
              angle = angs[k], border = NA, xpd = FALSE)
    }
    axis(4, lwd = 0, at = seq(2, ncol), labels = breaks, las = 1, tick = FALSE, cex.axis = cex.leg)
    
  }else{
    image(y = c(1), x = seq(1, (ncol + 1)) - 0.5, z = matrix(seq(1, (ncol + 1)) - 0.5, ncol = 1), col = col, breaks = seq(1,(ncol + 1)), xlim = c(1, (ncol + 1)), axes = FALSE, xlab = "", ylab = "")
    for (k in 1:ncol) {
      polygon(y = c(0, 2, 2, 0, 0), x = c(k, k, k + 1, k + 1, k), col = "white", border = NA, xpd = FALSE)
      polygon(y = c(0, 2, 2, 0, 0), x = c(k, k, k + 1, k + 1, k), col = col[k], density = dens[k], lwd = lwds[k],
              angle = angs[k], border = NA, xpd = FALSE)
    }
    axis(1, lwd = 0, at = seq(2, ncol), labels = breaks, line=-0.5, tick = FALSE, cex.axis = cex.leg)
  }
  
  box()
}


## Plot background map, points amd histogramm
plot_points<-function(x,y,z,n_classes,col_scheme,col_rev,color_bar,subplot_hist=TRUE,
                      col_trans=0,b_round=2,text_legend,cex=pcex,pch=16,qual,
                      force_zero_center=FALSE,force_n_classes=FALSE,set_breaks,breaks,layout_on=FALSE){

  # input variables:
  # x,y: coordinates
  # z: variable to plot
  # n_classes: number of color classes (even number suggested)
  # col: http://colorbrewer2.org/ color scheme
  # col_rev: reverse the color scheme?
  # col_trans: use transparent colors (0 is opaque 255 is transparent)
  # b_round: number of decimals to keep for the break values
  # text_legend: text to add above the color bar

  # remove NAs from vector
  naidxn <- which(is.na(z)) # numerics
  naidxc <- which(z %in% c("")) # characters
  if (sum(is.na(z)) > 0){
    x <- x[-naidxn]
    y <- y[-naidxn]
    z <- z[-naidxn]
    cex <- cex[-naidxn]
  }
  if (length(naidxc) > 0){
    x <- x[-naidxc]
    y <- y[-naidxc]
    z <- z[-naidxc]
    cex <- cex[-naidxc]
  }

  if(length(x)!=length(y)|length(x)!=length(z)){stop('x, y and z must have the same length')}

  if(force_zero_center&n_classes%%2!=0){stop('n_classes must be an even number if force_zero_center is TRUE')}
  
  # vertical ratio Map / legend
  h_map <- 4
  h_leg <- 0.34

  # setup layout - this might have to be changed for, when layout_on=FALSE
  if(color_bar){
    if(!layout_on){
      layout(matrix(1:2,2,1),heights=c(h_map,h_leg),widths=1)
    }
  }else{
    par(mfrow=c(1,1))
  }

  # initialise par
  par(mar=c(0,0,0,0),cex=1.6)

  # plot background
  plot.new()
  plot.window(c(4205000,4920000), c(2550000,3040000))
  box(col="white")
  plot(regions$geometry, lwd=2, col="grey50", border="white", add=TRUE)
  plot(ctry$geometry, lwd=3, add=TRUE)
  plot(mask$geometry, col="white", border="white", add=TRUE)

  coor_text<-c(4170000,2547500)
  coor_hist<-c(4886000,2579000)


  ## Define colors and breaks
  if(!qual){
    if(set_breaks){
      b<-breaks
      # show breaks
      message(paste0('set_breaks=TRUE, using these values'))
    }else{
      b<-unique(round(quantile(z,seq(1/n_classes,1-1/n_classes,length.out=n_classes-1),na.rm = TRUE),b_round))
      if(b[1]==0&length(b)>1){b<-b[-1]}
      if(force_n_classes&length(b)<n_classes){
        z_temp<-z[z>b[1]] # only works if first class is the most populated one (e.g. no snow). TODO: use which.max(table(findInterval))
        b_temp<-unique(round(quantile(z_temp,seq(1/n_classes,1-1/n_classes,length.out=n_classes-2),na.rm = TRUE),b_round))
        b<-c(b[1],b_temp)
      }
      if(force_zero_center){
        b[n_classes/2]<-0
      }
      # show breaks
      message(paste0('set_breaks=FALSE, using these values for breaks'))
    }
    print(b)
    # define colors
    if(length(b)<2){ # the mimimum number of color delivered by colorbrewer is 3
      col<-brewer.pal(4,col_scheme)[1:(length(b)+1)]
    }else{
      col<-brewer.pal(length(b)+1,col_scheme)
    }

  }else{ # qualitative classes
    # create an array containing the name of all classes to be plotted
    qc<-table(z)
    qc_nonzero<-qc[as.numeric(qc)!=0]
    qc_label<-names(qc_nonzero)
    print(qc_label)
    # create a table associating expected classes to hard-coded colors
    if(col_scheme=='degim'){
      if(any(!qc_label%in%c('u','l','m','s','x'))){
        stop('When color scheme is degim, the variable to plot can only use these 5 levels: u, l, m, s, x')
      }
      col_table<-data.frame(categ=c('u','l','m','s','x'),
                            R_color=c('steelblue3','palegreen3','goldenrod','brown3','black'))
    }else if(col_scheme=='glim'){
      file_glim_colors<-"GLiM_classes_colors.txt"
      if(!file.exists(file_glim_colors)){
        stop(paste('File with glim colors is missing:',file_glim_colors))
      }
      # load colors
      table_glim_classes<-read.table(file_glim_colors,sep=';',header=TRUE)
      table_glim_classes$short_name<-as.factor(table_glim_classes$short_name)
      if(any(colnames(table_glim_classes)!=c('short_name','long_name','R_color'))){
        stop(paste('Unexpect column names in:',file_glim_colors))
      }
      col_table<-data.frame(categ=table_glim_classes$short_name,
                            R_color=table_glim_classes$R_color)
      if(!any(qc_label%in%col_table$categ)){
        stop(paste('One or more qualitative class does not appear in:',file_glim_colors))
      }
    }else{
      if(length(qc_nonzero)>11){ # the maximum number of color delivered by colorbrewer is around 10
        print('combining two colors classes because number of breaks > 11')
        # combining two color classes
        n_colors_paired<-ceiling(length(qc_nonzero)/2)
        col<-c(brewer.pal(n_colors_paired,'Paired'),brewer.pal(length(qc_nonzero)-n_colors_paired,'Set3'))
      }else{
        col<-brewer.pal(length(qc_nonzero),col_scheme)
      }
      col_table<-data.frame(categ=qc_label,R_color=col)
    }
    # get rownumber of col_table, where qc_lable intersects categ
    qcidx <- which(col_table$categ %in% qc_label)
    # determine color of each basin
    z_temp<-data.frame(sort_column=1:length(z),z=z) # add a sorting column
    merged_table<-merge(z_temp,col_table,by.x='z',by.y='categ',all.x=TRUE) # all.x allows to keep NA values
    merged_table<-merged_table[order(merged_table$sort_column),] # sort
    if(dim(merged_table)[1]!=length(z)){
      stop('Error when determining colors.')
    }
    col_each_basin<-as.character(merged_table$R_color)
  }

  if(col_rev){col<-rev(col)} # reverse color scheme if necessary
  if(col_trans>0){col<-paste(col,col_trans,sep='')} # use semi-transparent colors if necessary

  ## Plots points on the map
  if(qual){
    if(pch>=21){
      points(x, y, bg=col_each_basin, cex=cex, pch=pch)
    }else{
      points(x, y, col=col_each_basin, cex=cex, pch=pch)
    }
  }else{
    if(pch>=21){
      points(x, y, bg=col[findInterval(z,b)+1], cex=cex, pch=pch)
    }else{
      points(x, y, col=col[findInterval(z,b)+1], cex=cex, pch=pch)
    }
  }

  ## Add text (usually for variable name)
  text(coor_text[1],coor_text[2],text_legend,pos=4,cex=1.1,font=2)
  
  ## Add histogram if required
  if(subplot_hist){
    message('Trying to plot histogram')
    if(qual){
      par(las=3,cex=1.3)
      table_qual<-table(z)
      if(col_scheme=='degim'){
        table_qual<-table_qual[c('u','l','m','s','x')]
        names(table_qual)<-c('u','l','m','s','x')
      }
      subplot(barplot(table_qual,main='',ylab='',xlab='',col=as.character(col_table$R_color)[qcidx],names.arg=FALSE),coor_hist[1],coor_hist[2],size=c(1.2,1.2))
    }else{
      par(las=0,cex=1.3)
      subplot(hist(z,main='',ylab='',xlab='',breaks=10),coor_hist[1],coor_hist[2],size=c(1.2,1.2))
    }
  }

  ## Plot legend
  if(!qual){
    if(color_bar){
      par(mar=c(1.5,1.8,0,8.5),cex=1.3,fig=c(0,1,0,h_leg/(h_map+h_leg)),new=TRUE)
      plot.legend.na(col, b, vert=FALSE)
    }
  }else{
    par(mar=c(0,0.8,0,0),cex=1.8,fig=c(0,1,0,h_leg/(h_map+h_leg)),new=TRUE)
    plot.new()
    if(pch>=21){
      legend('top',pt.bg=as.character(col_table$R_color)[qcidx],legend=paste(as.character(col_table$categ),"   ",sep="")[qcidx],pch=pch,horiz=TRUE,bty='n')
    }else{
      legend('top',col=as.character(col_table$R_color)[qcidx],legend=paste(as.character(col_table$categ)[qcidx],"   ",sep=""),pch=16,horiz=TRUE,bty='n')
    }
  }
}


########
### PLOT

#############################################
# plot spatial distribution of general attributes

pdf('spdist_gen.pdf',10,7.2,useDingbats=FALSE)

i <- 1
for(my_var in names(attrs[gen_row])){

  qual=is.character(attrs[,my_var])

  plot_points(x=attrs$lon,y=attrs$lat,z=attrs[,my_var],text_legend=gen_txt[i],qual=qual,color_bar=TRUE,
              col_scheme=ifelse(qual,'degim',gen_col_sh[i]),col_rev=gen_col_rev[i],n_classes=length(gen_col_br[[i]])+1,set_breaks=TRUE,breaks=gen_col_br[[i]])

  i <- i+1
}

dev.off()

#############################################
# plot spatial distribution of topographic attributes

pdf('spdist_topo.pdf',10,7.2,useDingbats=FALSE)

i <- 1
for(my_var in names(attrs[topo_row])){
  
  qual=is.character(attrs[,my_var])
  
  plot_points(x=attrs$lon,y=attrs$lat,z=attrs[,my_var],text_legend=topo_txt[i],qual=qual,color_bar=TRUE,
              col_scheme=ifelse(qual,'glim',topo_col_sh[i]),col_rev=topo_col_rev[i],n_classes=length(topo_col_br[[i]])+1,set_breaks=TRUE,breaks=topo_col_br[[i]])
  
  i <- i+1
}

dev.off()

#############################################
# plot spatial distribution of climatic attributes

pdf('spdist_clim.pdf',10,7.2,useDingbats=FALSE)

i <- 1
for(my_var in names(attrs[clim_row])){
  
  qual=is.character(attrs[,my_var])
  
  plot_points(x=attrs$lon,y=attrs$lat,z=attrs[,my_var],text_legend=clim_txt[i],qual=qual,color_bar=TRUE,
              col_scheme=ifelse(qual,'glim',clim_col_sh[i]),col_rev=clim_col_rev[i],n_classes=length(clim_col_br[[i]])+1,set_breaks=TRUE,breaks=clim_col_br[[i]])
  
  i <- i+1
}

dev.off()


#############################################
# plot spatial distribution of hydrological attributes

pdf('spdist_hydro.pdf',10,7.2,useDingbats=FALSE)

i <- 1
for(my_var in names(attrs[hydro_row])){
  
  qual=is.character(attrs[,my_var])
  
  plot_points(x=attrs$lon,y=attrs$lat,z=attrs[,my_var],text_legend=hydro_txt[i],qual=qual,color_bar=TRUE,
              col_scheme=ifelse(qual,'glim',hydro_col_sh[i]),col_rev=hydro_col_rev[i],n_classes=length(hydro_col_br[[i]])+1,set_breaks=TRUE,breaks=hydro_col_br[[i]])
  
  i <- i+1
}

dev.off()

#############################################
# plot spatial distribution of landclass attributes

pdf('spdist_lc.pdf',10,7.2,useDingbats=FALSE)

i <- 1
for(my_var in names(attrs[lc_row])){
  
  qual=is.character(attrs[,my_var])
  
  plot_points(x=attrs$lon,y=attrs$lat,z=attrs[,my_var],text_legend=lc_txt[i],qual=qual,color_bar=TRUE,
              col_scheme=ifelse(qual,'glim',lc_col_sh[i]),col_rev=lc_col_rev[i],n_classes=length(lc_col_br[[i]])+1,set_breaks=TRUE,breaks=lc_col_br[[i]])
  
  i <- i+1
}

dev.off()

#############################################
# plot spatial distribution of vegetation attributes

pdf('spdist_veg.pdf',10,7.2,useDingbats=FALSE)

i <- 1
for(my_var in names(attrs[veg_row])){
  
  qual=is.character(attrs[,my_var])
  
  plot_points(x=attrs$lon,y=attrs$lat,z=attrs[,my_var],text_legend=veg_txt[i],qual=qual,color_bar=TRUE,
              col_scheme=ifelse(qual,'glim',veg_col_sh[i]),col_rev=veg_col_rev[i],n_classes=length(veg_col_br[[i]])+1,set_breaks=TRUE,breaks=veg_col_br[[i]])
  
  i <- i+1
}

dev.off()

#############################################
# plot spatial distribution of soil attributes

pdf('spdist_soil.pdf',10,7.2,useDingbats=FALSE)

i <- 1
for(my_var in names(attrs[soil_row])){
  
  qual=is.character(attrs[,my_var])
  
  plot_points(x=attrs$lon,y=attrs$lat,z=attrs[,my_var],text_legend=soil_txt[i],qual=qual,color_bar=TRUE,
              col_scheme=ifelse(qual,'glim',soil_col_sh[i]),col_rev=soil_col_rev[i],n_classes=length(soil_col_br[[i]])+1,set_breaks=TRUE,breaks=soil_col_br[[i]])
  
  i <- i+1
}

dev.off()

#############################################
# plot spatial distribution of geological attributes

pdf('spdist_geol.pdf',10,7.2,useDingbats=FALSE)

i <- 1
for(my_var in names(attrs[geol_row])){
  
  qual=is.character(attrs[,my_var])
  
  plot_points(x=attrs$lon,y=attrs$lat,z=attrs[,my_var],text_legend=geol_txt[i],qual=qual,color_bar=TRUE,
              col_scheme=ifelse(qual,'glim',geol_col_sh[i]),col_rev=geol_col_rev[i],n_classes=length(geol_col_br[[i]])+1,set_breaks=TRUE,breaks=geol_col_br[[i]])
  
  i <- i+1
}

dev.off()

#############################################
# plot spatial distribution of model statistics

pdf('spdist_hmodel.pdf',10,7.2,useDingbats=FALSE)

i <- 1
for(my_var in names(attrs[hmod_row])){
  
  qual=is.character(attrs[,my_var])
  
  plot_points(x=attrs$lon,y=attrs$lat,z=attrs[,my_var],text_legend=hmod_txt[i],qual=qual,color_bar=TRUE,
              col_scheme=ifelse(qual,'glim',hmod_col_sh[i]),col_rev=hmod_col_rev[i],n_classes=length(hmod_col_br[[i]])+1,set_breaks=TRUE,breaks=hmod_col_br[[i]])
  
  i <- i+1
}

dev.off()

#############################################
# plot cumulative distribution function (cdf) of model statistics

pdf('cdf_hmodel.pdf',10,7.2,useDingbats=FALSE)

# space outline of the box, c(bottom, left, top, right)
par(mar=c(4.2, 7, 3, 3)) #2.6, 3.5, 2.8, 0.5

# plot ecdf
plot(ecdf(attrs$NSEcal), verticals=T, do.points=T, pch=1, cex=0.2,
     lty=1, lwd=2, col="red", xlim=range(-0.4,1), ylim=range(0,1),
     main="", xlab="", ylab="", axes=F, xaxs="i", yaxs="i")
lines(ecdf(attrs$NSEval), verticals=T, do.points=T, pch=1, cex=0.2, lty=1, lwd=2, col="blue")

# set titles
title(main="b) Cumulative distribution function - NSE", cex.main=1.8, font.main=2, col.main="black", adj=0.0, line=1.5)

# set axis
axis(side=1, at=seq(-0.4, 1, by=0.2), cex.axis=1.8, font.axis=1, col.axis="black", mgp=c(3,1.2,0), tcl=-0.6)
axis(side=2, at=seq(0, 1, by=0.2), cex.axis=1.8, font.axis=1, col.axis="black", mgp=c(3,1.2,0), tcl=-0.6, las=1)
minor.tick(nx=4, ny=2, tick.ratio=0.5, x.args = list(), y.args = list())
box(bty="L")
abline(h=seq(0.1,1,by=0.1), v=seq(-0.3,1,by=0.1), col="gray", lty=2)
         
# set axis labels
mtext("NSE [-]", side=1, line=3, cex=1.8, font=2, col="black")
mtext("cumulative distribution [-]", side=2, line=4, cex=1.8, font=2, col="black")

# insert a legend
legend(-0.4, 1, c("calibration","validation"),
       lty=c(1,1), lwd=c(2,2),
       col=c("red", "blue"),
       cex=1.8, text.font=1, x.intersp=1.0, y.intersp=1.0,
       bty="n", box.lty=1, box.lwd=1, box.col="white", bg="white")

dev.off()