### OBJECT
# Get gauge hierarchy and IDs of next upstream and downstream gauges

### INFO
# choose between basin delineation B or C
# the code presuppose that all imported shapefiles are already in the same coordinate system

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


##########
### IMPORT

# libraries
import collections 

# load shapefiles and add them to the map/registry
subbasins = QgsVectorLayer("D:/LamaH/G_appendix/3_shapefiles/Subbasins.shp", "Subbasins")
QgsProject.instance().addMapLayer(subbasins, True)
gauges = QgsVectorLayer("D:/LamaH/D_gauges/3_shapefiles/Gauges.shp", "Gauges")
QgsProject.instance().addMapLayer(gauges, True)


#################
### PREPROCESSING

# output path
output = "D:/LamaH/B_basins_intermediate_all/1_attributes/Gauge_hierarchy_.csv" # basin delineation B, all degrees of impact
#output = "D:/LamaH/C_basins_intermediate_lowimp/1_attributes/Gauge_hierarchy_.csv" # basin delineation C, only un- and low impacted basins/gauges

# filter out unuseful gauges
filtexpr = "degimpact " + "NOT IN ('x')" # for basin delineation B
#filtexpr = "degimpact " + "NOT IN ('m','s','x')" # for basin delineation C
gauges.setSubsetString(filtexpr)

# set crs to crs of layer "subbasin"
crs = subbasins.crs().toWkt()

# create gauge ID list
ID_list = [i.attribute("ID") for i in gauges.getFeatures()]

# order list by ascending value
ID_list.sort()

# create dictionaries for storing the results, fill with number -999
UPID = dict.fromkeys(set(ID_list), -999)
DNID = dict.fromkeys(set(ID_list), -999)
ORD = dict.fromkeys(set(ID_list), -999)

# create list from attributes of layer subbasins
HYDROID_list = [i.attribute("HYDROID") for i in subbasins.getFeatures()]
NDID_list = [i.attribute("NEXTDOWNID") for i in subbasins.getFeatures()]

# check for duplicates and print them if there are any
if len(HYDROID_list) != len(set(HYDROID_list)):
    print("Duplicates in list")
    dupls = [item for item, count in collections.Counter(HYDROID_list).items() if count > 1]


################################################
### A) CREATE TABLE WITH NEXT UPSTREAM GAUGE IDs

## Loop through all gauges
for x in ID_list:
    
    # print actual step
    print("step: ", x)

    # create empty list for storing the gauge IDs
    GID = []

    # select individual gauge
    gauges.selectByExpression("ID='{}'".format(x))
        
    # select subbasin, which correspond to the selected gauge
    processing.run("native:selectbylocation", {'INPUT':subbasins,'PREDICATE':[0],'INTERSECT':QgsProcessingFeatureSourceDefinition(gauges.id(), True),'METHOD':0})

    # get HYDROID of intersecting subbasin
    HYDROID = [subbasins.selectedFeatures()[0].attribute("HYDROID")]

    # check if list contains HYDROID and wenn true: return index of ids
    upstrm_list = [i for i, value in enumerate(NDID_list) if value in HYDROID]

    # number of upstream subbasins
    upnum = len(upstrm_list)

    ## Write sign "-" to dictionary, if there are no upstream subbasins (indicates headwater basin)
    if upnum == 0:
        UPID[x] = ["-"]

    ## Loop to get further upstream subbasins
    while upnum > 0:
        
        # check if list contains HYDROID and if true: return index of feature
        upstrm_list = [i for i, value in enumerate(NDID_list) if value in HYDROID]

        # create empty list
        newhydro_list = []
        
        # loop for creating a list with the new HYDROIDs
        for i in upstrm_list:
            newhydro_list.append(subbasins.getFeature(i)['HYDROID'])
            
        # overwrite HYDROID
        HYDROID = newhydro_list
        
        # refresh selection
        subbasins.removeSelection()
        gauges.removeSelection()
        subbasins.select(upstrm_list)
        
        # select gauges, which are in the selected subbasins
        processing.run("native:selectbylocation", {'INPUT':gauges,'PREDICATE':[0],'INTERSECT':QgsProcessingFeatureSourceDefinition(subbasins.id(), True),'METHOD':0})
        
        # check if the selected subbasin intersects with a gauge
        gmatch = len(gauges.selectedFeatures()) 
        
        if gmatch > 0:
                        
            # get gauge ID 
            GID_list = [gauges.selectedFeatures()[i].attribute("ID") for i in range(gmatch)]
            
            # append elements of GID_list to GID
            [GID.append(i) for i in GID_list]
            
            # select subbasins, which contains the selected gauges
            processing.run("native:selectbylocation", {'INPUT':subbasins,'PREDICATE':[0],'INTERSECT':QgsProcessingFeatureSourceDefinition(gauges.id(), True),'METHOD':0})
            
            # get HYDROID of intersecting subbasins
            RHYDROID = [subbasins.selectedFeatures()[i].attribute("HYDROID") for i in range(len(GID_list))]
            
            # remove HYDROID (RHYDROID) of intersecting subbasins from list HYDROID (stop searching upstream gauges in that stream)
            [HYDROID.remove(i) for i in RHYDROID]
            
        # number of next upstream subbasins
        upnum = len(HYDROID)
        
        # write next upstream gauge IDs to dictionary if there are no more upstream subbasins in the streams
        if upnum == 0:
            
            # sort GID
            GID.sort()
            
            # fill GID with sign "-", if there was no upstream gauge
            if GID == []:
                GID = ["-"]
            
            # write to dictionary
            UPID[x] = GID
        
    # remove selection
    subbasins.removeSelection()
    gauges.removeSelection()

# check values, which weren´t overwritten (failures)
na1 = sum(value == -999 for value in UPID.values())


#################################################
### B) CREATE TABLE WITH NEXT DOWNSTREAM GAUGE ID

# loop through sorted features of layer "gauges"
for outlet in sorted(gauges.getFeatures(), key=lambda x: x['ID']):
    
    # set variable to false (which indicates a gauge match)
    gmatch = False
    
    # select gauge
    gauges.selectByIds([outlet.id()])
    
    # get ID of selected gauge
    x = gauges.selectedFeatures()[0].attribute("ID")
    
    # print actual step
    print("step: ", x)
    
    # select intersecting subbasin
    processing.run("native:selectbylocation", {'INPUT':subbasins,'PREDICATE':[0],'INTERSECT':QgsProcessingFeatureSourceDefinition(gauges.id(), True),'METHOD':0})
         
    # repeat as long as variable "gmatch" is true
    while gmatch == False:
        
        # deselect layer gauges
        gauges.selectByIds([])
        
        # get NEXTDOWNID of intersecting subbasin
        NDID = subbasins.selectedFeatures()[0].attribute("NEXTDOWNID")
    
        # select subbasin, where HYDROID is equal to NEXTDOWNID of intersecting subbasin
        subbasins.selectByExpression("HYDROID='{}'".format(NDID))
        
        # select intersecting gauge
        processing.run("native:selectbylocation", {'INPUT':gauges,'PREDICATE':[0],'INTERSECT':QgsProcessingFeatureSourceDefinition(subbasins.id(), True),'METHOD':0})
        
        # check if the actual subbasin intersects with a gauge
        gnum = len(gauges.selectedFeatures())
                      
        # if "gnum" is larger than zero
        if gnum > 0:
            # set "gmatch" to true
            gmatch = True
            # get ID number of next downstream gauge
            GID = gauges.selectedFeatures()[0].attribute("ID")
            # write result to dictionary
            DNID[x] = [GID]
        
        # if there are no more subbasins downstream left
        if NDID == 0:
            # set "gmatch" to true
            gmatch = True
            # write result to dictionary
            DNID[x] = ["-"]

# check values, which weren´t overwritten (failures)
na2 = sum(value == -999 for value in DNID.values())

# remove selection
subbasins.removeSelection()
gauges.removeSelection()


###############################
### C) ADD GAUGE ORDER TO TABLE

# create list with gauge IDs, where "UPID" is "-" (headwater basin)
fkeys = [id for id, val in UPID.items() if val == ['-']]

# write number 1 in dictionary "ORD" at headwater subbasins
for i in fkeys:
    ORD[i] = 1

# check values, which weren´t overwritten
na3 = sum(value == -999 for value in ORD.values())

# copy "ID_list"
resid = ID_list.copy()

# do as long as all IDs have an order 
while na3 > 0:
    
    # remove keys, which were already filled up with an order
    [resid.remove(i) for i in fkeys]
    
    # start loop to fill the dictionary "ORD", every new loop step handles higher order
    for z, y in enumerate(resid):
        
        # get list with IDs of upstream gauges from dictionary "UPID"
        upid_list = UPID[y]
        
        # get order of that gauges
        upord_list = []
        for i in upid_list:
            upord_list.append(ORD[i])
        
        # skip loop step, if at least one upstream gauge has no order yet
        if min(upord_list) == -999:
            continue
        
        else:
            # otherwise calculate order
            iord = max(upord_list)+1
            # and write it to the dictionary
            ORD[y] = iord
    
    # create list with gauge IDs, where "UPID" is equal to the actual order
    fkeys = [id for id, val in UPID.items() if val == (z+1)]
    
    # check values, which weren´t overwritten
    na3 = sum(value == -999 for value in ORD.values())


####################
### D) WRITE RESULTS

# create empty textfile, append mode
txt = open(output, "a")

# write header in first line
txt.write("ID;HIERARCHY;NEXTUPID;NEXTDOWNID\n")

# loop for writing the lines
for x in ID_list:
    
    strup = str(UPID[x]).replace("[", "").replace("]", "").replace("'", "").replace("-", "0").replace(" ", "")
    strdn = str(DNID[x]).replace("[", "").replace("]", "").replace("'", "").replace("-", "0")
    
    txt.write(str(x) + ";" + str(ORD[x]) + ";" + strup + ";" + strdn + "\n")

# end writing in textfile
txt.close()

# delete unused temporary layers from registry
legend_layers = [i.layer() for i in QgsProject.instance().layerTreeRoot().children()]
registry_layers = QgsProject.instance().mapLayers().values()
for i in registry_layers:
    if not i in legend_layers:
        QgsProject.instance().removeMapLayer(i.id())

# print status end
print("Finished")