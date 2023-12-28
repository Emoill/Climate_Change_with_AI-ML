### OBJECT
# Calculate distance from source (most distant river segment) to the basin outlet (basin delineation A)

### INFO
# the outlet is assumed to be the point where the river segment intersects the basin polygon
# errors will be indexed by "-999" in the column "dist_hup" of the output file (occuring mostly when the river network is not fully connected after clipping, see line 80)
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
basins = QgsVectorLayer("D:/LamaH/A_basins_total_upstrm/3_shapefiles/Basins_A.shp", "Basins_A")
QgsProject.instance().addMapLayer(basins, True)
strmnet = QgsVectorLayer("D:/LamaH/E_stream_network/EU-Hydro_network.shp", "EU-Hydro_network")
QgsProject.instance().addMapLayer(strmnet, True)
segids = QgsVectorLayer("D:/LamaH/G_appendix/1_attributes/EU-Hydro_network_start_end_ID.csv", "EU-Hydro_network_start_end_ID")
QgsProject.instance().addMapLayer(segids, True)


#################
### PREPROCESSING

# output path
output = "D:/LamaH/A_basins_total_upstrm/1_attributes/Stream_dist_.csv"

# create empty textfile, append mode
txt = open(output, "a")

# write header in first line
txt.write("ID;dist_hup\n")
#txt.write("ID;dist_hup;lastobj\n")

# set crs to crs of layer "basin"
crs = basins.crs().toWkt()

# create list from attribute "ID" of layer basins
ID_list = [i.attribute("ID") for i in basins.getFeatures()]

# order list by ascending value
ID_list.sort() 

# create empty lists
filter_list = []

# append "ID=" to ID_list
for i in ID_list:
    string = 'ID' + "=" + str(i)
    filter_list.append(string)


###########################
### LOOP THROUGH ALL BASINS

# start loop
for idx, j in enumerate(filter_list):

    # print loop status
    print(j)
    
    # filter and select by ID
    basins.setSubsetString(j)
    basins.selectByExpression(j)
    segids.selectByExpression(j)
    
    # get "start_ID" from "segids"
    start_id = segids.selectedFeatures()[0]['start_ID']
    
    # clip river network to filtered basin
    strmnetclip = processing.run("native:clip", {'INPUT':strmnet,'OVERLAY':QgsProcessingFeatureSourceDefinition(basins.id(), True),'OUTPUT':'memory:'})["OUTPUT"]
    
    # select most distant river segment (source)
    strmnetclip.selectByExpression(" \"OBJECT_ID\" = '{}' ".format(start_id))
    
    # create list for storing the segment lengths
    list_seglen = []
    
    # sub-loop for summing up the downstream segment lengths
    while len(strmnetclip.selectedFeatures()) != 0:
    
        # get segment length in [m]
        seglen = strmnetclip.selectedFeatures()[0].geometry().length()

        # write segment length to list
        list_seglen.append(seglen)
        
        # get OBJECT_ID of selected river segment
        lastobj = strmnetclip.selectedFeatures()[0]['OBJECT_ID']
    
        # get nextdownstream OBJECT_ID of selected river segment
        NDID = strmnetclip.selectedFeatures()[0]['NEXTDOWNID']
    
        # select next downstream segment
        strmnetclip.selectByExpression(" \"OBJECT_ID\" = '{}' ".format(NDID))
        
    # get "end_ID" from "segids"
    end_id = segids.selectedFeatures()[0]['end_ID']
    
    # check if loop has reached the last segment, which is declared in "segids"
    if lastobj == end_id:
        chk = "TRUE"
    else:
        list_seglen = [-999000]
        chk = "FALSE"
    
    # write results to textfile
    txt.write(str(ID_list[idx]) + ";" + str(round((sum(list_seglen)/1000),1)) + "\n")
    #txt.write(str(ID_list[idx]) + ";" + str(round((sum(list_seglen)/1000),1)) + ";" + lastobj + "\n")

    # remove selection of layers
    basins.removeSelection()
    strmnetclip.removeSelection()
    segids.removeSelection()
    
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