# Code written by Robin Wilson (robin@rtwilson.com)
# to process dune crests created through processing DECAL
# output files using IDL
import arcgisscripting
import sys
import re
import os
from os.path import join, getsize

def CalculateFields(PolylineFeatures):
    gp.AddField(PolylineFeatures, "Length", "double")
    gp.AddField(PolylineFeatures, "CentroidX", "double")
    gp.AddField(PolylineFeatures, "CentroidY", "double")

    desc = gp.Describe(PolylineFeatures)
    shapeField = desc.ShapeFieldName

    rows = gp.UpdateCursor(PolylineFeatures)
    row = rows.Next()

    while row:
        # Create the geometry object
        feat = row.GetValue(shapeField)
        
        # Set the length field
        row.SetValue("Length",feat.length)

        # Get the centroid co-ords and split them
        centroid_str = feat.Centroid
        centroid_arr = centroid_str.rsplit(" ")

        # Assign the centroid co-ords to the right fields
        row.SetValue("CentroidX", centroid_arr[0])
        row.SetValue("CentroidY", centroid_arr[1])
        
        rows.UpdateRow(row)
        row = rows.Next()
    del rows
    return

def Mean(inputData, FieldName):
    # Execute the Summary Statistics tool using the MEAN option
    gp.Statistics_analysis(inputData, "mean_tmp", FieldName + " MEAN")
    # Get a list of fields from the new in-memory table.
    flds = gp.ListFields("mean_tmp")
    # Retrieve the field with the mean value.
    fld = flds.Next()
    while fld:
        if fld.Name.__contains__("MEAN_"):
            break
        fld = flds.Next()
    # Open a Search Cursor using field name.
    rows = gp.SearchCursor("mean_tmp", "", "", fld.Name)
    #Get the first row and mean value.
    row = rows.Next()
    return row.GetValue(fld.Name)

def Sum(inputData, FieldName):
    # Execute the Summary Statistics tool using the MEAN option
    gp.Statistics_analysis(inputData, "mean_tmp", FieldName + " SUM")
    # Get a list of fields from the new in-memory table.
    flds = gp.ListFields("mean_tmp")
    # Retrieve the field with the mean value.
    fld = flds.Next()
    while fld:
        if fld.Name.__contains__("SUM_"):
            break
        fld = flds.Next()
    # Open a Search Cursor using field name.
    rows = gp.SearchCursor("mean_tmp", "", "", fld.Name)
    #Get the first row and mean value.
    row = rows.Next()
    return row.GetValue(fld.Name)

def Count(inputData, FieldName):
    # Execute the Summary Statistics tool using the MEAN option
    gp.Statistics_analysis(inputData, "mean_tmp", FieldName + " COUNT")
    # Get a list of fields from the new in-memory table.
    flds = gp.ListFields("mean_tmp")
    # Retrieve the field with the mean value.
    fld = flds.Next()
    while fld:
        if fld.Name.__contains__("COUNT_"):
            break
        fld = flds.Next()
    # Open a Search Cursor using field name.
    rows = gp.SearchCursor("mean_tmp", "", "", fld.Name)
    #Get the first row and mean value.
    row = rows.Next()
    return row.GetValue(fld.Name)

def PolylineToPoint(InputPolylines, OutputPoints, Folder):
    OutputPoints = os.path.split(OutputPoints)[1]

    gp.CreateFeatureClass_management(Folder, OutputPoints, "POINT")

    rows = gp.SearchCursor(InputPolylines)
    row = rows.Next()

    while row:
        cur = gp.InsertCursor(OutputPoints)
        new_row = cur.NewRow()
        
        point = gp.CreateObject("Point")
        point.x = row.GetValue("CentroidX")
        point.y = row.GetValue("CentroidY")
        
        new_row.shape = point
        cur.InsertRow(new_row)
        del new_row
        row = rows.Next()
    del rows
    del row
    return

def process_file(full_path):
    full_path_no_ext = os.path.splitext(full_path)[0]
    
    # Set input details
    InRaster = full_path
    PolylineFilename = full_path_no_ext + "_lines.shp"
    SubsetFilename = full_path_no_ext + "_lines_sub.shp"
    PointsFilename = full_path_no_ext + "_pts_c.shp"
    
    # Set to overwrite output
    gp.OverWriteOutput = 1

    gp.workspace = os.path.split(full_path)[0]

    print "Converting Raster -> Polyline"

    # Process: RasterToPolyline_conversion
    gp.RasterToPolyline_conversion(InRaster, PolylineFilename, "ZERO", 0, "SIMPLIFY", "Value")

    print "Calculating fields"
    CalculateFields(PolylineFilename)

    # Make a feature layer from the polylines
    gp.MakeFeatureLayer(PolylineFilename,"Polyline_lyr")

    print "Subsetting by length"
    gp.SelectLayerByAttribute("Polyline_lyr", "NEW_SELECTION", " \"Length\" > 15 ")
    gp.CopyFeatures("Polyline_lyr", SubsetFilename)

    print "Converting to points"
    PolylineToPoint(SubsetFilename, PointsFilename, gp.workspace)

    print "Calculating Nearest Neighbour"
    
    # Do Nearest Neighbour calculation
    nn_output = gp.AverageNearestNeighbor_stats(PointsFilename, "Euclidean Distance", "false", "#")

    # Get stats on the dune lengths and numbers
    n_dunes = Count(SubsetFilename, "Length")
    mean_len = Mean(SubsetFilename, "Length")
    total_len = Sum(SubsetFilename, "Length")

    # Get out the individual parts of the Nearest Neighbour output
    nn_array = nn_output.rsplit(";")
    r_score = nn_array[0]
    z_score = nn_array[1]
    p_value = nn_array[2]

    # Create the CSV line ready to be appended
    csv_array = []
    tidied_file_name = re.sub("_extract", "", os.path.split(full_path_no_ext)[1])
    
    csv_array.append(tidied_file_name)
    csv_array.append(str(n_dunes))
    csv_array.append(str(mean_len))
    csv_array.append(str(total_len))
    csv_array.append(str(r_score))
    csv_array.append(str(z_score))
    csv_array.append(str(p_value))

    csv_string = ",".join(csv_array)
    return csv_string

# ----------------------------------------------------------------
# Main Script Starts Here...
# ----------------------------------------------------------------

#folder = 'D:\GIS\RealOutputs'

# Get the folder from the first command-line argument
folder = sys.argv[1]
#folder = "D:\GIS\ConstantIterations"

print "Started Dune Processing"

# Create the Geoprocessor object
gp = arcgisscripting.create()

print "Initialised ArcGIS object"

FILE = open(folder + "\\" + "results.csv", "a")
FILE.write("name,n,mean_len,total_len,r_score,z_score,p_value\n")

# Recursively walk though the directory tree
for root, dirs, files in os.walk(folder):
    # For each file found
    for name in files:
        # Get the full file path
        full_path = os.path.join(root, name)
        # If it's a .tif file then print the full file path
        if os.path.splitext(full_path)[1] == ".tif":
            print "----------------"
            print "Processing " + full_path
            csv_line = process_file(full_path)
            print csv_line
            FILE.write(csv_line + "\n")

FILE.close()
            
            
