### OBJECT
# Select upstream intermediate basins

### INFO
# choose between shapefiles "Basins_B.shp", "Basins_C.shp", "Subbasins.shp" or "Hyd_model.shp"
# attribute which indicates the next downstream (sub-)basin must be named 'NEXTDOWNID'
# select manually one (sub-)basin and run then the script

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


##########
### IMPORT

# add them to the map/registry
subbasin = QgsProject.instance().mapLayersByName('Basins_B')[0] # load shapefile manually from "D:/LamaH/B_basins_intermediate_all/3_shapefiles/Basins_B.shp"
#subbasin = QgsProject.instance().mapLayersByName('Basins_C')[0] # load shapefile manually from "D:/LamaH/C_basins_intermediate_lowimp/3_shapefiles/Basins_C.shp"
#subbasin = QgsProject.instance().mapLayersByName('Hyd_model')[0] # load shapefile manually from "D:/LamaH/F_hydrol_model/3_shapefiles/Hyd_model.shp"
idname = 'ID' # attribute name of unique identifier of shapefile
# or
#subbasin = QgsProject.instance().mapLayersByName('Subbasins')[0] # load shapefile manually from "D:/LamaH/G_appendix/3_shapefiles/Subbasins.shp"
#idname = 'HYDROID' # attribute name of unique identifier of shapefile


#################
### PREPROCESSING

# set crs to crs of layer "subbasin"
crs = subbasin.crs().toWkt()

# set HYDROID of selected feature as list
HYDROID = [subbasin.selectedFeatures()[0][idname]]

# create list for attribute "NEXTDOWNID"
NDID_list = [i.attribute('NEXTDOWNID') for i in subbasin.getFeatures()]

# check if "NDID_list" contains "HYDROID" and if true: return ids
upstrm_list = [j for j, value in enumerate(NDID_list) if value in HYDROID] 

# number of upstream basins
upnum = len(upstrm_list)

# create empty list
sel_list = []


#############################################
## LOOP FOR SELECTING ALL UPSTREAM SUBBASINS
while upnum > 0:
    
    # check if "NDID_list" contains "HYDROID" and if true: return feature ids
    upstrm_list = [j for j, value in enumerate(NDID_list) if value in HYDROID]

    # number of upstream basins
    upnum = len(upstrm_list)

    # add ids of selected feature to list
    sel_list.extend(upstrm_list)
    
    # remove last upnum elements from "sel_list"
    newid_list = sel_list[-upnum:] 
    
    # create empty list
    newhydro_list = []
    
    # loop for creating a list with the new HYDROIDs
    for k in newid_list:
        newhydro_list.append(subbasin.getFeature(k)[idname])
        
    # overwrite "HYDROID"
    HYDROID = newhydro_list

# refresh selection on map
subbasin.select(sel_list)

# create selection 
selection = subbasin.selectedFeatures()

# print number of subbasins
print("Selected subbasins: ", len(selection))
print("")

# get summed area of selected basins [km2]
area = round(sum([subbasin.selectedFeatures()[i].geometry().area() for i in range(len(subbasin.selectedFeatures()))])/1000000, 1)

# print aggregated area
print("Area of selected subbasins: ", area, "[km2]")