### OBJECT
# Calculate distance from a specific gauge to the it´s next downstream gauge (if there is one) (basin delineation B and C)

### INFO
# choose between basin delineation B or C
# start and end of calculation are assumed to be the points where the river segment intersects the basin polygon
# errors will be indexed by "-999" in the column "dist_hdn" of the output file (occuring mostly when the river network is not fully connected after clipping, see line 93)
# it is recommended to check the output file for errors
# the code presuppose that all imported shapefiles are already in the same coordinate system

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


##########
### IMPORT

# libraries
import math
import processing

# load shapefiles/csv and add them to the map/registry
basins = QgsVectorLayer("D:/LamaH/B_basins_intermediate_all/3_shapefiles/Basins_B.shp", "Basins_B") # basin delineation B
#basins = QgsVectorLayer("D:/LamaH/C_basins_intermediate_lowimp/3_shapefiles/Basins_C.shp", "Basins_C") # basin delineation C
QgsProject.instance().addMapLayer(basins, True)
gauges = QgsVectorLayer("D:/LamaH/D_gauges/3_shapefiles/Gauges.shp", "Gauges")
QgsProject.instance().addMapLayer(gauges, True)
strmnet = QgsVectorLayer("D:/LamaH/E_stream_network/EU-Hydro_network.shp", "EU-Hydro_network")
QgsProject.instance().addMapLayer(strmnet, True)
segids = QgsVectorLayer("D:/LamaH/G_appendix/1_attributes/EU-Hydro_network_start_end_ID.csv", "EU-Hydro_network_start_end_ID")
QgsProject.instance().addMapLayer(segids, True)
hrchy = QgsVectorLayer("D:/LamaH/B_basins_intermediate_all/1_attributes/Gauge_hierarchy.csv", "Gauge_hierarchy") # basin delineation B
#hrchy = QgsVectorLayer(" D:/LamaH/C_basins_intermediate_lowimp/1_attributes/Gauge_hierarchy.csv", "Gauge_hierarchy") # basin delineation C
QgsProject.instance().addMapLayer(hrchy, True)


#################
### PREPROCESSING

# output path
output = "D:/LamaH/B_basins_intermediate_all/1_attributes/Stream_dist_.csv" # basin delineation B, all degrees of impact
#output = "D:/LamaH/C_basins_intermediate_lowimp/1_attributes/Stream_dist_.csv" # basin delineation C, only un- and low impacted basins/gauges

# create empty textfile for storing the results, append mode
txt = open(output, "a")

# write header in first line
txt.write("ID;NEXTDOWNID;dist_hdn;elev_diff;strm_slope\n")


###########################
### LOOP THROUGH ALL BASINS

# start loop
for feature in hrchy.getFeatures():

    # reset fail status
    fail = 0

    # get attributes from hierachy
    ID = feature['ID']
    NDID = feature['NEXTDOWNID']
    
    # print loop status
    print(ID)
    
    # check for downstream gauge
    if NDID == '0':
        #txt.write(str(ID) + ";" + str(NDID) + "\n")
        continue
        
    # create filter expression
    fexp = "ID = " + str(NDID)
    
    # filter and select by "NDID"
    basins.setSubsetString(fexp)
    basins.selectByExpression(fexp)

    # get "OBJECT_ID" of last river segments
    segids.selectByExpression(" \"ID\" = '{}' ".format(ID))
    LSID1 = segids.selectedFeatures()[0].attribute('end_ID')
    segids.selectByExpression(" \"ID\" = '{}' ".format(NDID))
    LSID2 = segids.selectedFeatures()[0].attribute('end_ID')
    
    # get elevations from gauges
    gauges.selectByExpression(" \"ID\" = '{}' ".format(ID))
    elev1 = gauges.selectedFeatures()[0].attribute('elev')
    gauges.selectByExpression(" \"ID\" = '{}' ".format(NDID))
    elev2 = gauges.selectedFeatures()[0].attribute('elev')
    
    # clip river network to filtered basin
    strmnetclip = processing.run("native:clip", {'INPUT':strmnet,'OVERLAY':QgsProcessingFeatureSourceDefinition(basins.id(), True),'OUTPUT':'memory:'})["OUTPUT"]

    # select first river segment of the next downstream basin
    strmnetclip.selectByExpression(" \"OBJECT_ID\" = '{}' ".format(LSID1))

    # check if there is one segment selected
    if len(strmnetclip.selectedFeatures()) != 1:
        fail = 1
        print("Error at ID: ", ID)

    # get "OBJECT_ID" of selected river segment
    OBJID = strmnetclip.selectedFeatures()[0]['OBJECT_ID']

    # get NEXTDOWN "OBJECT_ID" of selected river segment
    NDSID = strmnetclip.selectedFeatures()[0]['NEXTDOWNID']

    # create list for storing the segment lengths
    list_seglen = []
        
    # sub-loop for summing up the downstream segment lengths
    while len(strmnetclip.selectedFeatures()) != 0:
        
        # get segment length in [m]
        seglen = strmnetclip.selectedFeatures()[0].geometry().length()

        # write segment length to list
        list_seglen.append(seglen)
        
        # get "OBJECT_ID" of selected river segment
        lastobj = strmnetclip.selectedFeatures()[0]['OBJECT_ID']
        
        # get NEXTDOWN "OBJECT_ID" of selected river segment
        NDSID = strmnetclip.selectedFeatures()[0]['NEXTDOWNID']
        
        # set next downstream segment as actual segment
        strmnetclip.selectByExpression(" \"OBJECT_ID\" = '{}' ".format(NDSID))

    # check if loop has reached the last segment, which is declared in "segids"
    if lastobj == LSID2:
        chk = "TRUE"
    else:
        list_seglen = [-999000]
        chk = "FALSE"
        
    # sum up the segment lengths [km], if fail status is 0
    if fail == 0:
        disth = round((sum(list_seglen)/1000),1)
    else:
        disth = -999
        
    # calculate elevation difference
    elevd = elev1-elev2
    
    # calculate slope [m/km]
    slope = round(elevd/disth,1)
        
    # write results to textfile
    txt.write(str(ID) + ";" + str(NDID) + ";" + str(disth) + ";" + str(elevd) + ";" + str(slope) + "\n")

    # remove selection of layers
    strmnetclip.removeSelection()
    gauges.removeSelection()

# unfilter basins
basins.setSubsetString("")

# close textfile
txt.close()

# delete unused temporary layers from registry
legend_layers = [i.layer() for i in QgsProject.instance().layerTreeRoot().children()]
registry_layers = QgsProject.instance().mapLayers().values()
for i in registry_layers:
    if not i in legend_layers:
        QgsProject.instance().removeMapLayer(i.id())
        
# print status end
print("Finished")