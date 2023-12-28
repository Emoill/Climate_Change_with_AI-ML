### OBJECT
# Plot water balance evalutions and comparisons to other meteorological datasets

### INFO
# some gauges don`t cover the period 1 Oct 1989 to 30 Sept 2009, and so they are not plotted (see created variable "show")

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


#############
### LIBRARIES
require(RColorBrewer)
library(data.table)
library(Hmisc)


##########
### IMPORT

# load as data table
data <- fread("D:/LamaH/A_basins_total_upstrm/1_attributes/Water_balance.csv", header=TRUE, sep=";")
cattrs <- fread("D:/LamaH/A_basins_total_upstrm/1_attributes/Catchment_attributes.csv", header=TRUE, sep=";")
gattrs <- fread("D:/LamaH/D_gauges/1_attributes/Gauge_attributes.csv", header=TRUE, sep=";")


###############
### EXTEND DATA

# add columns regarding water balance
data <- within(data, c(PmQ<-P-Q1, PETdP<-PET/P, ETAdP<-ETA/P, PdETA<-P/ETA, QdP<-Q1/P, PERA5mQ<-PERA5-Q1, PCRPSmQ<-PCRPS-Q1, PMSWmQ<-PMSW-Q1))

## Add column with flag for showing

# add "typimpact" from gauge attributes
data <- merge(data, gattrs[,c("ID","typimpact")], by="ID", all.x=TRUE)

# replace "," with "|" in column "degimpact"
data$typimpact <- gsub('\\,', '|', data$typimpact)

# set flag, if "degimpact" is in c(E,I,L,M)
# in plot a) and c), values are only plotted for basins not affected by artificial water input (typimpact=I), withdrawal (E), karstic springs (M) or high infiltration (L)
data <- within(data, show<-!unname(mapply(grepl,data$typimpact,"E,I,L,M")))


#################
### PLOT SETTINGS

# output path
setwd("D:/LamaH/G_appendix/4_plots")

# get area and elevation
area <- cattrs$area_calc
elev <- cattrs$elev_mean

# point size (cex) depending on catchment area
#pcex <- log10(area)*0.25+0.25
pcex <- log(area,20) # alternative formula, log to base 20
pcexv <- pcex*data$show # for plot a) and c)

# point color (col) depending on mean catchment elevation, classified by intervall
col_scheme <- "Spectral"
rev <- FALSE
brk <- 6
col <- brewer.pal(brk+1,col_scheme)
if(rev){col<-rev(col)} # reverse color scheme if necessary
pcol <- cut(elev,c(-Inf,300,500,800,1200,1600,2000,Inf))
levels(pcol) <- c(col[1],col[2],col[3],col[4],col[5],col[6],col[7])
pcol <- as.character(pcol)


##########
### PLOT A
png('wb_a.png',width=750,height=550,units="px",bg="white")
# space outline of the box, c(bottom, left, top, right)
par(mar=c(3.2, 4.4, 0.5, 0.5),cex=1.2)
plot(data$PmQ, data$ETA, xlim=c(-1.5,3),ylim=c(0.4,2.2), pch=21, col="black", bg=pcol, cex=pcexv, main ="", xlab="", ylab="", axes=F)
abline(coef = c(0,1))
abline(v=0, col="red")
# set axis
axis(side=1, at=seq(-1, 3, by=1), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.5,0), tcl=-0.3)
axis(side=2, at=seq(0, 2.5, by=0.5), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.6,0), tcl=-0.3, las=1)
minor.tick(nx=2, ny=2, tick.ratio=0.4, x.args = list(), y.args = list())
box(bty="o")
mtext(expression(bold(paste("P - Q [mm d"^'-1', "]"))), side=1, line=2.2, cex=2, col="black")
mtext(expression(bold(paste("ETA [mm d"^'-1', "]"))), side=2, line=2.4, cex=2, font=2, col="black")
# add legend
text(-1.5, 2.15, "a)", font=2, cex=2.2)
# export
dev.off()

##########
### PLOT B
#get Budyko x values
budx <- seq(0,5,by=0.01)
# get Budyko y values
budy <- (budx*tanh(1/budx)*(1-exp(-budx)))**0.5

png('wb_b.png',width=750,height=550,units="px",bg="white")
# space outline of the box, c(bottom, left, top, right)
par(mar=c(3.2, 4.2, 0.5, 0.5),cex=1.2)
plot(data$PETdP, data$ETAdP, xlim=c(0,4),ylim=c(0,1.2), pch=21, col="black", bg=pcol, cex=pcex, main ="", xlab="", ylab="", axes=F)
lines(c(0,1), c(0,1), col="orange", lwd=2)
lines(c(1,5),c(1,1), col="blue", lwd=2)
lines(c(1,1),c(0,1), col="black")
lines(budx,budy, lwd=2)
# set axis
axis(side=1, at=seq(0, 4, by=1), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.5,0), tcl=-0.3)
axis(side=2, at=seq(0, 1.2, by=0.2), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.6,0), tcl=-0.3, las=1)
minor.tick(nx=2, ny=2, tick.ratio=0.4, x.args = list(), y.args = list())
box(bty="o")
mtext("PET/P [-]", side=1, line=2.2, cex=2, font=2, col="black")
mtext("ETA/P [-]", side=2, line=2.4, cex=2, font=2, col="black")
# add legend
text(0, 1.165, "b)", font=2, cex=2.2)
text(0.5, 0, "energy-limited", font=2, cex=1.3)
text(1.9, 0.005, "water-limited catchments", font=2, cex=1.3)
# export
dev.off()

##########
### PLOT C
png('wb_c.png',width=750,height=550,units="px",bg="white")
# space outline of the box, c(bottom, left, top, right)
par(mar=c(3.2, 4.2, 0.5, 0.5),cex=1.2)
plot(data$PdETA, data$QdP, xlim=c(1,7),ylim=c(0,1.6), pch=21, col="black", bg=pcol, cex=pcexv, main ="", xlab="", ylab="", axes=F)
abline(h=1, col="red")
# set axis
axis(side=1, at=seq(1, 7, by=1), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.5,0), tcl=-0.3)
axis(side=2, at=seq(0, 2, by=0.5), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.6,0), tcl=-0.3, las=1)
minor.tick(nx=2, ny=2, tick.ratio=0.4, x.args = list(), y.args = list())
box(bty="o")
mtext("P/ETA [-]", side=1, line=2.2, cex=2, font=2.0, col="black")
mtext("Runoff coefficient (Q/P) [-]", side=2, line=2.4, cex=2, font=2, col="black")
# add legend
text(1.0, 1.55, "c)", font=2, cex=2.2)
# export
dev.off()

##########
### PLOT D
png('wb_d.png',width=750,height=550,units="px",bg="white")
# space outline of the box, c(bottom, left, top, right)
par(mar=c(3.2, 4.2, 0.5, 0.5),cex=1.2)
plot(data$P, data$PERA5, xlim=c(1,6),ylim=c(1,6), pch=21, col="black", bg=pcol, cex=pcex, main ="", xlab="", ylab="", axes=F)
abline(coef = c(0,1))
# set axis
axis(side=1, at=seq(1, 6, by=1), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.5,0), tcl=-0.3)
axis(side=2, at=seq(1, 6, by=1), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.6,0), tcl=-0.3, las=1)
minor.tick(nx=2, ny=2, tick.ratio=0.4, x.args = list(), y.args = list())
box(bty="o")
mtext(expression(bold(paste("P (ERA5-Land) [mm d"^'-1', "]"))), side=1, line=2.2, cex=2, col="black")
mtext(expression(bold(paste("P (ERA5) [mm d"^'-1', "]"))), side=2, line=2.2, cex=2, font=2, col="black")
# add legend
text(1, 5.85, "d)", font=2, cex=2.2)
# export
dev.off()

##########
### PLOT E
png('wb_e.png',width=750,height=550,units="px",bg="white")
# space outline of the box, c(bottom, left, top, right)
par(mar=c(3.2, 4.2, 0.5, 0.5),cex=1.2)
plot(data$P, data$PCRPS, xlim=c(1,6),ylim=c(1,6), pch=21, col="black", bg=pcol, cex=pcex, main ="", xlab="", ylab="", axes=F)
abline(coef = c(0,1))
# set axis
axis(side=1, at=seq(1, 6, by=1), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.5,0), tcl=-0.3)
axis(side=2, at=seq(1, 6, by=1), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.6,0), tcl=-0.3, las=1)
minor.tick(nx=2, ny=2, tick.ratio=0.4, x.args = list(), y.args = list())
box(bty="o")
mtext(expression(bold(paste("P (ERA5-Land) [mm d"^'-1', "]"))), side=1, line=2.2, cex=2, col="black")
mtext(expression(bold(paste("P (CHIRPS Daily v2) [mm d"^'-1', "]"))), side=2, line=2.2, cex=2, font=2, col="black")
# add legend
text(1, 5.85, "e)", font=2, cex=2.2)
# export
dev.off()

##########
### PLOT F
png('wb_f.png',width=750,height=550,units="px",bg="white")
# space outline of the box, c(bottom, left, top, right)
par(mar=c(3.2, 4.2, 0.5, 0.5),cex=1.2)
plot(data$P, data$PMSW, xlim=c(1,6),ylim=c(1,6), pch=21, col="black", bg=pcol, cex=pcex, main ="", xlab="", ylab="", axes=F)
abline(coef = c(0,1))
# set axis
axis(side=1, at=seq(1, 6, by=1), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.5,0), tcl=-0.3)
axis(side=2, at=seq(1, 6, by=1), cex.axis=1.4, font.axis=1, col.axis="black", mgp=c(3,0.6,0), tcl=-0.3, las=1)
minor.tick(nx=2, ny=2, tick.ratio=0.4, x.args = list(), y.args = list())
box(bty="o")
mtext(expression(bold(paste("P (ERA5-Land) [mm d"^'-1', "]"))), side=1, line=2.2, cex=2, col="black")
mtext(expression(bold(paste("P (MSWEP v2.2) [mm d"^'-1', "]"))), side=2, line=2.2, cex=2, font=2, col="black")
# add legend
text(1, 5.85, "f)", font=2, cex=2.2)
# export
dev.off()

#######################
### PEARSON-CORRELATION
#Ra1 <- cor(data$PmQ,data$ETA, use = "complete.obs")
#Ra2 <- cor(data$PERA5mQ,data$ETA, use = "complete.obs")
#Ra3 <- cor(data$PCRPSmQ,data$ETA, use = "complete.obs")
#Ra4 <- cor(data$PMSWmQ,data$ETA, use = "complete.obs")

#Rd <- cor(data$P, data$PERA5, use = "complete.obs")
#Re <- cor(data$P, data$PCRPS, use = "complete.obs")
#Rf <- cor(data$P, data$PMSW, use = "complete.obs")