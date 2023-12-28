### OBJECT
# Select downstream intermediate basins

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

# get feature id of selected feature
featid = subbasin.selectedFeatures()[0].id()

# get NEXTDOWNID of selected feature
NEXTDOWN = subbasin.selectedFeatures()[0]['NEXTDOWNID']

# create empty list for storing the NEXTDOWNIDs
sel_list = []

# add feature id to "sel_list"
sel_list.append(featid)


##############################################
## LOOP FOR SELECTING ALL DOWNSTREAM SUBBASINS
while NEXTDOWN != 0:
    
    # select next downstream basin
    subbasin.selectByExpression("ID='{}'".format(NEXTDOWN))
    
    # get feature id of selection
    featid = subbasin.selectedFeatures()[0].id()
    
    # add feature id of selection to "sel_list"
    sel_list.append(featid)
    
    # get NEXTDOWNID of selected feature
    NEXTDOWN = subbasin.selectedFeatures()[0]['NEXTDOWNID']
    
# refresh selection on map
subbasin.select(sel_list)

# create selection 
selection = subbasin.selectedFeatures()

# print number of subbasins
print("Selected subbasins: ", len(selection))
print("")