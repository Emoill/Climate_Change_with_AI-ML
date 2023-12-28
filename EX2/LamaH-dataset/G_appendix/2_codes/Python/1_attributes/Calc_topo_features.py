### OBJECT
# Fill empty Polygon-shapefiles with attribute fields and
# calculate some topographic and geologic attributes

### INFO
# script "Subbasin_merge.py" must have already been executed (for creating individual and intermediate catchments/polygons)
# choose between basin delineation A, B or C
# the geological glim classes 'ev' (Evaporites), 'nd' (No Data) and 'vi' (Intermediate volcanic rocks) are not present in the area of interest, and therefore aren´t reflected in the script
# calculation may takes a while, depending on the number of basins
# the code presuppose that all imported shapefiles are already in the same coordinate system

### AUTHOR
# by Christoph Klingler, Institute for Hydrology and Water Management, University of Natural Resources and Life Sciences, Vienna, 11 June 2021, v1.0
# code accompanying the paper "LamaH-CE | Large-Sample Data for Hydrology and Environmental Sciences for Central Europe" published in the journal Earth Syst. Sci. Data (ESSD), 2021


##########
### IMPORT

# libraries
import math
import processing

# load shapefiles and add them to the map/registry
#basins = QgsVectorLayer("D:/LamaH/G_appendix/3_shapefiles/Poly_A.shp", "Poly_A") # Polygons of basin delineation A, output of the script "Subbasin_merge.py"
basins = QgsVectorLayer("D:/LamaH/G_appendix/3_shapefiles/Poly_B.shp", "Poly_B") # Polygons of basin delineation B, output of the script "Subbasin_merge.py"
#basins = QgsVectorLayer("D:/LamaH/G_appendix/3_shapefiles/Poly_C.shp", "Poly_C") # Polygons of basin delineation C, output of the script "Subbasin_merge.py"
QgsProject.instance().addMapLayer(basins, True)
gauges = QgsVectorLayer("D:/LamaH/D_gauges/3_shapefiles/Gauges.shp", "Gauges")
QgsProject.instance().addMapLayer(gauges, True)
strmnet = QgsVectorLayer("D:/LamaH/E_stream_network/EU-Hydro_network.shp", "EU-Hydro_network")
QgsProject.instance().addMapLayer(strmnet, True)
glim = QgsVectorLayer("D:/LamaH/G_appendix/3_shapefiles/GLiM.shp", "GLiM")
QgsProject.instance().addMapLayer(glim, True)


#################
### PREPROCESSING

# set crs to crs of layer "basin"
crs = basins.crs().toWkt()

# create list from attribute "ID" of layer basins
ID_list = [i.attribute("ID") for i in basins.getFeatures()]

# order list by ascending value
ID_list.sort() 

# create empty lists
filter_list = []

# create lists with geological attribute classes
code_xx = ['ig', 'mt', 'pa', 'pb', 'pi', 'py', 'sc', 'sm', 'ss', 'su', 'va', 'vb', 'wb'] # geological glim classes 'ev' (Evaporites), 'nd' (No Data) and 'vi' (Intermediate volcanic rocks) are not present in the area of interest

# loop for joining "ID=" to ID_list to filter layers
for i in ID_list:
    string = "ID" + "=" + str(i)
    filter_list.append(string)


########################################################
### LOOP THROUGH ALL BASINS TO CALCULATE SOME ATTRIBUTES

# start loop
for idx, j in enumerate(filter_list):

    # print loop status
    print(j)
    
    # filter vector layer and select them
    basins.setSubsetString(j) # filter 
    basins.selectByExpression(j) # selection
    gauges.setSubsetString(j) # filter
    gauges.selectByExpression(j) # selection
    
    
    ## Calculate some topographic attributes

    # create list with coordinates of x/y from all vertices of layer basin
    vertl = basins.selectedFeatures()[0].geometry().asMultiPolygon()
    vertl = [i for i in vertl[0][0]]

    # get coordinates of gauge
    gc = gauges.selectedFeatures()[0].geometry().asPoint()

    # calculate distance from every single vertex to the gauge in [m]
    dist = [((i.x()-gc.x())**2 + (i.y()-gc.y())**2)**0.5 for i in vertl]

    # get index of vertex, which is most distant to the gauge 
    vertidx = dist.index(max(dist))

    # get maximum vertex distance to the gauge
    L = dist[vertidx]

    # calculate angle from most distant vertex [deg]
    # flow direction from north to south: 180 deg
    # flow direction from east to west: 270 deg
    angle = math.degrees(math.atan(abs(gc.x()-vertl[vertidx].x()) / abs(gc.y()-vertl[vertidx].y()) ))
    if gc.x()-vertl[vertidx].x() > 0 and gc.y()-vertl[vertidx].y() > 0:
        angle = angle
    elif gc.x()-vertl[vertidx].x() > 0 and gc.y()-vertl[vertidx].y() < 0:
        angle = 180 - angle 
    elif gc.x()-vertl[vertidx].x() < 0 and gc.y()-vertl[vertidx].y() < 0:
        angle = 180 + angle 
    elif gc.x()-vertl[vertidx].x() < 0 and gc.y()-vertl[vertidx].y() > 0:
        angle = 360 - angle
        
    # get area of basin in [m2]
    area = basins.selectedFeatures()[0].geometry().area()
            
    # calculate elongation ratio after Schumm
    Re = 1/L * (4*area/math.pi)**0.5


    ## Calculate stream density of basin
    
    # clip river network to filtered basin
    strmclip = processing.run("native:clip", {'INPUT':strmnet,'OVERLAY':QgsProcessingFeatureSourceDefinition(basins.id(), True),'OUTPUT':'memory:'})["OUTPUT"]

    # create list with stream-lengths [m] of layer strmclip
    streamlengths = [i.geometry().length() for i in strmclip.getFeatures()]

    # sum up the stream segment lengths [m]
    streamlen = sum(streamlengths)

    # calculate stream density [m/m2]
    D = streamlen/area
    
    
    ## Calculate geologic attributes
    
    # create empty lists
    filter_list_glim = []
    glim_area = []
    
    # intersect glim to filtered basin
    glimisec = processing.run("native:intersection", {'INPUT':glim,'OVERLAY':basins,'INPUT_FIELDS':['xx'],'OVERLAY_FIELDS':['ID'],'OUTPUT':'memory:'})["OUTPUT"]
    
    # loop for joining area to list
    for i in code_xx:
        glimisec.selectByExpression('"xx"=\'%s\'' % i)
        if len(glimisec.selectedFeatures()) == 0:
            glim_area_i = 0
        else:
            glim_area_sec = []
            for feat in glimisec.selectedFeatures():
                glim_area_sec.append(feat.geometry().area())
            glim_area_i = sum(glim_area_sec)
        glim_area.append(glim_area_i)

    # get value and index of list, where area is maximum
    glim_area_max = max(glim_area)
    glim_area_max_idx = glim_area.index(glim_area_max)

    # get geologic class, with highest area share
    glim_area_max_xx = code_xx[glim_area_max_idx]

    # get fractions for all geological classes
    fra_gc_ig = glim_area[0]/area
    fra_gc_mt = glim_area[1]/area
    fra_gc_pa = glim_area[2]/area
    fra_gc_pb = glim_area[3]/area
    fra_gc_pi = glim_area[4]/area
    fra_gc_py = glim_area[5]/area
    fra_gc_sc = glim_area[6]/area
    fra_gc_sm = glim_area[7]/area
    fra_gc_ss = glim_area[8]/area
    fra_gc_su = glim_area[9]/area
    fra_gc_va = glim_area[10]/area
    fra_gc_vb = glim_area[11]/area
    fra_gc_wb = glim_area[12]/area
    

##########################
### CHANGE ATTRIBUTE TABLE
    
    # start editing of layer
    basins.startEditing()
    
    
    ## Add fields to attribute table
    
    # append fields in first loop step
    if idx == 0:
        
        # topographic attributes (10)
        basins.addAttribute(QgsField("area_calc", QVariant.Double, len=10, prec=3)) # km2
        basins.addAttribute(QgsField("elev_mean", QVariant.Int, len=4, prec=0))
        basins.addAttribute(QgsField("elev_med", QVariant.Int, len=4, prec=0))
        basins.addAttribute(QgsField("elev_std", QVariant.Int, len=4, prec=0))
        basins.addAttribute(QgsField("elev_ran", QVariant.Int, len=4, prec=0))
        basins.addAttribute(QgsField("slope_mean", QVariant.Int, len=4, prec=0)) # m/km
        basins.addAttribute(QgsField("mvert_dist", QVariant.Double, len=6, prec=1)) # km
        basins.addAttribute(QgsField("mvert_ang", QVariant.Int, len=3, prec=0)) # deg
        basins.addAttribute(QgsField("elon_ratio", QVariant.Double, len=5, prec=3)) # -
        basins.addAttribute(QgsField("strm_dens", QVariant.Double, len=4, prec=2))# km/km2
        
        # climate attributes (11)
        basins.addAttribute(QgsField("p_mean", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("et0_mean", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("aridity", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("p_season", QVariant.Double, len=5, prec=2))
        basins.addAttribute(QgsField("frac_snow", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("hi_prec_fr", QVariant.Double, len=5, prec=2))
        basins.addAttribute(QgsField("hi_prec_du", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("hi_prec_ti", QVariant.String, len=3))
        basins.addAttribute(QgsField("lo_prec_fr", QVariant.Double, len=6, prec=2))
        basins.addAttribute(QgsField("lo_prec_du", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("lo_prec_ti", QVariant.String, len=3))
        
        # land class attributes (7)
        basins.addAttribute(QgsField("lc_dom", QVariant.Int, len=3, prec=0))
        basins.addAttribute(QgsField("agr_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("bare_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("forest_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("glac_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("lake_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("urban_fra", QVariant.Double, len=5, prec=3))
        
        # vegetation attributes (6)
        basins.addAttribute(QgsField("lai_max", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("lai_diff", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("ndvi_max", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("ndvi_min", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("gvf_max", QVariant.Double, len=4, prec=2))
        basins.addAttribute(QgsField("gvf_diff", QVariant.Double, len=4, prec=2))
        
        # soil attributes (10)
        basins.addAttribute(QgsField("bedrk_dep", QVariant.Double, len=5, prec=2)) # m
        basins.addAttribute(QgsField("root_dep", QVariant.Double, len=4, prec=2)) # m
        basins.addAttribute(QgsField("soil_poros", QVariant.Double, len=4, prec=2)) # -
        basins.addAttribute(QgsField("soil_condu", QVariant.Double, len=5, prec=3)) # /(100*24)
        basins.addAttribute(QgsField("soil_tawc", QVariant.Double, len=4, prec=2)) # m
        basins.addAttribute(QgsField("sand_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("silt_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("clay_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("grav_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("oc_fra", QVariant.Double, len=5, prec=3))
        
        # geological attributes (16)
        basins.addAttribute(QgsField("gc_dom", QVariant.String, len=2))
        basins.addAttribute(QgsField("gc_ig_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_mt_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_pa_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_pb_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_pi_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_py_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_sc_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_sm_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_ss_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_su_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_va_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_vb_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("gc_wb_fra", QVariant.Double, len=5, prec=3))
        basins.addAttribute(QgsField("geol_perme", QVariant.Double, len=5, prec=1))
        basins.addAttribute(QgsField("geol_poros", QVariant.Double, len=5, prec=3))
        
    
    ## Add results to attribute table

    # transfer calculated attribute values to fields
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("area_calc"), area/1000000) 
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("mvert_dist"), L/1000) 
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("mvert_ang"), angle) 
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("elon_ratio"), Re) 
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("strm_dens"), D*1000)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_dom"), glim_area_max_xx)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_ig_fra"), fra_gc_ig)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_mt_fra"), fra_gc_mt)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_pa_fra"), fra_gc_pa)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_pb_fra"), fra_gc_pb)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_pi_fra"), fra_gc_pi)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_py_fra"), fra_gc_py)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_sc_fra"), fra_gc_sc)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_sm_fra"), fra_gc_sm)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_ss_fra"), fra_gc_ss)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_su_fra"), fra_gc_su)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_va_fra"), fra_gc_va)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_vb_fra"), fra_gc_vb)
    basins.changeAttributeValue(basins.selectedFeatures()[0].id(), basins.fields().indexFromName("gc_wb_fra"), fra_gc_wb)
    
    # end editing, save changes of layer
    basins.commitChanges()
        
    # unfilter layers
    basins.setSubsetString("")
    gauges.setSubsetString("")
    
    # remove selection of layers
    basins.removeSelection()
    gauges.removeSelection()

# delete unused temporary layers from registry
legend_layers = [i.layer() for i in QgsProject.instance().layerTreeRoot().children()]
registry_layers = QgsProject.instance().mapLayers().values()
for i in registry_layers:
    if not i in legend_layers:
        QgsProject.instance().removeMapLayer(i.id())

# print status end
print("Finished")