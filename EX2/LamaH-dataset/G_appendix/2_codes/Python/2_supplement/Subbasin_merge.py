### OBJECT
# Create empty polygons, which reflects the full upstream area of a gauge (basin delineataion A) or intermediate catchments (basin delineation B and C)

### INFO
# choose between basin delineation B or C
# polygons for basin delineation A will be output if basin delineation B is chosen
# created working folders "working_B" or "working_C" in 'D:/LamaH/G_appendix/3_shapefiles' can be deleted after closing GIS
# the code presuppose that all imported shapefiles are already in the same coordinate system

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


##########
### IMPORT

# libraries
import os
import math
import processing

# load shapefiles and add them to the map/registry
subbasins = QgsVectorLayer("D:/LamaH/G_appendix/3_shapefiles/Subbasins.shp", "Subbasins")
QgsProject.instance().addMapLayer(subbasins, True)
gauges = QgsVectorLayer("D:/LamaH/D_gauges/3_shapefiles/Gauges.shp", "Gauges")
QgsProject.instance().addMapLayer(gauges, True)


###############
### PRESETTINGS

## Choose basin delineation B or C 

# basin delineation B
filtexpr = "degimpact " + "NOT IN ('x')" # set filtexpr = '', if no filtering is required
workfold = "working_B"
os.makedirs('D:/LamaH/G_appendix/3_shapefiles/working_B', exist_ok = True)
# or
# basin delineation C
#filtexpr = "degimpact " + "NOT IN ('m','s','x')" 
#workfold = "working_C"
#os.makedirs('D:/LamaH/G_appendix/3_shapefiles/working_C', exist_ok = True)

# set output path and file name
output = "D:/LamaH/G_appendix/3_shapefiles/"

# set crs to crs of layer "subbasins"
crs = subbasins.crs().toWkt()


######################################################
### SELECT UPSTREAMS, DISSOLVE AND MERGE ALL SUBBASINS


## Preprocessing

# filter out unuseful gauges
gauges.setSubsetString(filtexpr)

# create list from attribute "ID" of layer gauges
ID_list = [i.attribute('ID') for i in gauges.getFeatures()]

# order list by ascending value
ID_list.sort() 

# create empty lists
filter_list = []
poly_list = []

# loop for joining the term "ID=" to every element in "ID_list"
for i in ID_list:
    string = "ID" + "=" + str(i)
    filter_list.append(string)
    
# loop for creating a list with the values from 0 to len(ID_list)-1
for j in range(len(ID_list)):
    poly_list.append(j)


## Loop through "ID_list"

# start loop
for z, x in enumerate(filter_list):
    
    # filter individual gauge
    gauges.setSubsetString(x)
    
    # set output path and file name for shapefile
    output_x = output + workfold + "/Poly_A_" + str(x[3:]) + ".shp"
    
    ## 1) select uptream subbasins
    
    # select subbasin, which intersects the gauge
    processing.run("native:selectbylocation", {'INPUT':subbasins,'PREDICATE':[1],'INTERSECT':gauges,'METHOD':0})

    # set "HYDROID" of selected feature as list
    HYDROID = [subbasins.selectedFeatures()[0]['HYDROID']]

    # create list for attribute "NEXTDOWNID"
    NDID_list = [i.attribute("NEXTDOWNID") for i in subbasins.getFeatures()]

    # check if "NDID_list" contains "HYDROID" and if true: return ids
    upstrm_list = [j for j, value in enumerate(NDID_list) if value in HYDROID] 

    # number of upstream subbasins
    upnum = len(upstrm_list)

    # create empty list
    sel_list = []

    # loop for selecting all upstream subbasins
    while upnum > 0:
    
        # check if "NDID_list" contains "HYDROID" and if true: return ids
        upstrm_list = [j for j, value in enumerate(NDID_list) if value in HYDROID]

        # number of upstream subbasins
        upnum = len(upstrm_list)

        # add selected features to list
        sel_list.extend(upstrm_list)
        
        # get last upnum elements from "sel_list"
        newid_list = sel_list[-upnum:] 
        
        # create empty list
        newhydro_list = []
        
        # loop for creating a list with the new HYDROIDs
        for k in newid_list:
            newhydro_list.append(subbasins.getFeature(k)['HYDROID'])
            
        # overwrite "HYDROID"
        HYDROID = newhydro_list

    # refresh selection on map
    subbasins.select(sel_list)

    # create selection 
    selection = subbasins.selectedFeatures()

    # print number of subbasins
    print("Gauge with ", x, " has ", len(selection), " upstream subbasins.")
    print("")
    
    ## 2) dissolve uptream subbasins
    
    # dissolve the selected subbasins
    poly_diss = processing.run("native:dissolve", {'INPUT':QgsProcessingFeatureSourceDefinition(subbasins.id(), True), 'FIELD':[], 'OUTPUT':output_x})["OUTPUT"]
    
    # add result to registry as vector layer
    poly_diss = QgsVectorLayer(output_x, "", "ogr")
    
    # start editing of layer
    poly_diss.startEditing()
    
    # delete the attribute fields from dissolved polygon
    poly_diss.deleteAttributes([1,2,3])
    
    # get ID of selected gauge as integer
    outlet_id = int(x[3:])
    
    # change attribute name
    poly_diss.renameAttribute(0, 'ID')
    
    # assign the ID of the gauge (feature 0 (row) / index 0 (column)) to the ID of the dissolved poly
    poly_diss.changeAttributeValue(0, 0, outlet_id)
    
    # end editing, save changes of layer
    poly_diss.commitChanges()
    
    ## 3) finishing loop step
    
    # clear selection 
    subbasins.removeSelection()
    
    # unfilter layer gauges
    gauges.setSubsetString('')
    
    # write vector ID to "poly_list"
    poly_list[z] = QgsVectorLayer(output_x, "", "ogr")

# end loop
print("Loop for selecting all upstreams has finished.")
    
    
## Merge dissolved polygons

# set parameters for merging
merge_params = {'LAYERS': poly_list,
                'CRS': QgsCoordinateReferenceSystem(crs).authid(),
                'OUTPUT': output + workfold + "/Poly_A.shp"}
    
# merge dissolved layer to vector layer "Poly_A"
Poly_A = processing.run("native:mergevectorlayers", merge_params)["OUTPUT"]

# add result to registry as vector layer
Poly_A = QgsVectorLayer(output + workfold + "/Poly_A.shp", "", "ogr")


## Process attributes

# start editing of layer
Poly_A.startEditing()

# delete the fields "layer" (idx 1) and "path" (idx 2) from merged polygon
Poly_A.deleteAttributes([1, 2])

# end editing, save changes of layer
Poly_A.commitChanges()

# write Poly_A.shp also to output directory, if basin delineation B is chosen
# load merged layer and show it on the map
if workfold == "working_B":
    QgsVectorFileWriter.writeAsVectorFormat(Poly_A,output+"Poly_A.shp",'utf-8',QgsCoordinateReferenceSystem(QgsCoordinateReferenceSystem(crs).authid()),'ESRI Shapefile')
    iface.addVectorLayer(output + "Poly_A.shp", "", "ogr")

print("Creating of Poly_A has finished.")


###################################################
### CREATE INTERMEDIATE POLYGONS (Poly_B or Poly_C)

# filter out unuseful gauges
gauges.setSubsetString(filtexpr)

# union "Poly_A", add to registry and set CRS
poly_union = processing.run("native:union", {'INPUT':output + workfold + "/Poly_A.shp",'OVERLAY':None,'OUTPUT':'memory:'})["OUTPUT"]
QgsProject.instance().addMapLayer(poly_union, False)
poly_union = processing.run("native:reprojectlayer", {'INPUT':poly_union,'TARGET_CRS':QgsCoordinateReferenceSystem(crs).authid(),'OUTPUT':'memory:'})["OUTPUT"]

# delete duplicate geometries of union and add to registry
if workfold == "working_B":
    Poly_BC = processing.run("qgis:deleteduplicategeometries", {'INPUT':poly_union,'OUTPUT':output + "Poly_B.shp"})["OUTPUT"]
    Poly_BC = iface.addVectorLayer(output + "Poly_B.shp", "", "ogr")
elif workfold == "working_C":
    Poly_BC = processing.run("qgis:deleteduplicategeometries", {'INPUT':poly_union,'OUTPUT':output + "Poly_C.shp"})["OUTPUT"]
    Poly_BC = iface.addVectorLayer(output + "Poly_C.shp", "", "ogr")

# delete unused layers
del poly_union

# start editing of layer
Poly_BC.startEditing()

# loop through features of layer
for feat in Poly_BC.getFeatures():
    
    # select feature of intermediate polygon
    Poly_BC.selectByIds([feat.id()])
    
    # select intersecting gauge
    processing.run("native:selectbylocation", {'INPUT':gauges,'PREDICATE':[0],'INTERSECT':QgsProcessingFeatureSourceDefinition(Poly_BC.id(), True),'METHOD':0})

    # get ID of selection from layer gauges
    outlet_id = gauges.selectedFeatures()[0].attribute("ID")
    
    # change attribute ID of "Poly_BC"
    Poly_BC.changeAttributeValue(Poly_BC.selectedFeatures()[0].id(), Poly_BC.fields().indexFromName("ID"), outlet_id)
    
# end editing, save changes of layer
Poly_BC.commitChanges()

# deselect features
Poly_BC.selectByIds([])
gauges.selectByIds([])

# unfilter layer gauges
gauges.setSubsetString('')

# remove layers
QgsProject.instance().removeMapLayer(subbasins)
QgsProject.instance().removeMapLayer(gauges)

# delete unused temporary layers from registry
legend_layers = [i.layer() for i in QgsProject.instance().layerTreeRoot().children()]
registry_layers = QgsProject.instance().mapLayers().values()
for i in registry_layers:
    if not i in legend_layers:
        QgsProject.instance().removeMapLayer(i.id())

# print status end
print("Finished")