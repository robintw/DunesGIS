# Code written by Robin Wilson (robin@rtwilson.com)
# to process dune crests created through processing DECAL
# output files using IDL
import arcgisscripting
import sys
import re
import os
import math
import time
import numpy
import inspect
import pdb

MINIMUM_POLYLINE_LENGTH = 15

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

def CalculateStatistics(inputData, FieldName):
    # Execute the Summary Statistics tool using the MEAN, SUM and COUNT options
    gp.Statistics_analysis(inputData, "mean_tmp", FieldName + " MEAN;" + FieldName + " SUM;" + FieldName + " COUNT;" + FieldName + " MIN;" + FieldName + " MAX;" + FieldName + " STD;")
    # Get a list of fields from the new in-memory table.
    flds = gp.ListFields("mean_tmp")
    # Retrieve the field with the mean value.
    fld = flds.Next()
    while fld:
        if fld.Name.__contains__("MEAN_"):
            # Open a Search Cursor using field name.
            rows = gp.SearchCursor("mean_tmp", "", "", fld.Name)
            #Get the first row and mean value.
            row = rows.Next()
            mean = row.GetValue(fld.Name)
        elif fld.Name.__contains__("SUM_"):
            # Open a Search Cursor using field name.
            rows = gp.SearchCursor("mean_tmp", "", "", fld.Name)
            #Get the first row and mean value.
            row = rows.Next()
            total = row.GetValue(fld.Name)
        elif fld.Name.__contains__("COUNT_"):
            # Open a Search Cursor using field name.
            rows = gp.SearchCursor("mean_tmp", "", "", fld.Name)
            #Get the first row and mean value.
            row = rows.Next()
            count = row.GetValue(fld.Name)
        elif fld.Name.__contains__("MAX_"):
            # Open a Search Cursor using field name.
            rows = gp.SearchCursor("mean_tmp", "", "", fld.Name)
            #Get the first row and mean value.
            row = rows.Next()
            maximum = row.GetValue(fld.Name)
        elif fld.Name.__contains__("MIN_"):
            # Open a Search Cursor using field name.
            rows = gp.SearchCursor("mean_tmp", "", "", fld.Name)
            #Get the first row and mean value.
            row = rows.Next()
            minimum = row.GetValue(fld.Name)
        elif fld.Name.__contains__("STD_"):
            # Open a Search Cursor using field name.
            rows = gp.SearchCursor("mean_tmp", "", "", fld.Name)
            #Get the first row and mean value.
            row = rows.Next()
            std = row.GetValue(fld.Name)
        fld = flds.Next()
    return [count, mean, total, maximum, minimum, std]

def PolylineToPoint_Centre(InputPolylines, OutputPoints, Folder):
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

def rotate(x, y, deg):
    rad = math.radians(deg)
    s, c = [f(rad) for f in (math.sin, math.cos)]
    x, y = (c*x - s*y, s*x + c*y)

    return [x, y]

def get_best_poly_fit(x, y, max_deg):
    res_arr = []
    p_arr = []
    
    for i in range(2, max_deg):
        pol = numpy.polyfit(x, y, i, full=True)
        p, res, rank, sing, rcond = pol
        res_arr.append(res)
        p_arr.append(p)

    #print res_arr

    prev_r = 1000
    deg = 2
    selected_deg = -1
    
    for item in res_arr:
        print item
        if item.size == 0:
            continue
        if item < prev_r:
            prev_r = item
            selected_deg = deg
        deg = deg + 1

    #print prev_r
    print "Selected degree = ", selected_deg

    print p_arr[selected_deg - 2]
    return p_arr[selected_deg - 2]

def calc_max_curvature_point(x_arr, y_arr):
    rot_x = []
    rot_y = []

    # Rotate all of the x and y co-ordinates around the origin by 90deg
    for current_x, current_y in zip(x_arr, y_arr):
        out_x, out_y = rotate(current_x, current_y, 90)
        rot_x.append(out_x)
        rot_y.append(out_y)

    pol = get_best_poly_fit(rot_x, rot_y, 7)

    # Differentiate the polynomial
    deriv_one = numpy.polyder(pol)
    deriv_two = numpy.polyder(deriv_one)

    # Roots of the 1st derivative - that is, X-values for where 1st deriv = 0
    roots = numpy.roots(deriv_one)

    if roots.size == 1:
        result = rotate(roots, numpy.polyval(pol, roots), -90)
    else:
        prev_val = 0
        selected_root = -1

        for root in roots:
            val = numpy.polyval(deriv_two, root)
            if val > prev_val:
                selected_root = root

        result = rotate(selected_root, numpy.polyval(pol, selected_root), -90)

    return [float(result[0]), float(result[1])]

def snap_point_to_line(points, lines):
    gp.toolbox = "analysis"

    
    gp.near(points, lines, "", "LOCATION")
    # Open a Search Cursor using field name.
    
    rows = gp.UpdateCursor(points, "", "", "NEAR_X, NEAR_Y")

    row = rows.Next()

    while row:
        new_x = row.GetValue("NEAR_X")
        new_y = row.GetValue("NEAR_Y")
        
        point = gp.CreateObject("Point")
        point.x = new_x
        point.y = new_y
        
        row.shape = point

        rows.UpdateRow(row)
        row = rows.Next()

def PolylineToPoint_MaxCurv(InputPolylines, OutputPoints, Folder):
    # Get the output points filename
    OutputPoints = os.path.split(OutputPoints)[1]

    # Create the feature class to hold the points
    gp.CreateFeatureClass_management(Folder, OutputPoints, "POINT")

    # Look through the input polylines
    rows = gp.SearchCursor(InputPolylines)
    row = rows.Next()

    while row:
        # Get the individual points of the polyline
        shape = row.shape

        x_arr = []
        y_arr = []

        for i in range(0, shape.PartCount):
            part = shape.getpart(i)
            part.reset()
            pnt = part.next()
            while pnt:
                x_arr.append(pnt.x)
                y_arr.append(pnt.y)
                print pnt.x, pnt.y
                pnt = part.next()

        out_x, out_y = calc_max_curvature_point(x_arr, y_arr)
        
        # Create point object
        point = gp.CreateObject("Point")
        
        point.x = out_x
        point.y = out_y
        
        # Store an output point from the point object created above
        cur = gp.InsertCursor(OutputPoints)
        new_row = cur.NewRow()

        new_row.shape = point
        cur.InsertRow(new_row)
        
        del new_row
        row = rows.Next()
    del rows
    del row
    del cur

    snap_point_to_line(OutputPoints, InputPolylines)
    return

def CalculateCloseness(SubsetFilename):
    # Calculate the distance from each shape (point, line, polygon) to all of the others
    gp.GenerateNearTable(SubsetFilename, SubsetFilename, "NearTable", "", "LOCATION", "ANGLE", "ALL")

    # Create a view of the table so that we can run queries on it below
    gp.MakeTableView("NearTable", "tbl", "NEAR_DIST > 0")

    # Search for all of the distances which are > 175 and < 185 degrees - that is, basically horizontally
    rows = gp.SearchCursor("tbl", "NEAR_ANGLE >= 175 AND NEAR_ANGLE <= 185", "", "")
    
    # Get the first row
    row = rows.Next()

    # Create a NumPy array to hold the results
    shortest = numpy.zeros(500)

    # For each row
    while row:
        # Get the previous shortest distance from the array
        prev_value = shortest[row.IN_FID]
        
        # If the previous value is 0 then this is the first distance
        # we've found so set it to that
        if (prev_value == 0):
            shortest[row.IN_FID] = row.NEAR_DIST
            continue
        # Otherwise if this is a shorter one then use it
        elif (row.NEAR_DIST < prev_value):
            shortest[row.IN_FID] = row.NEAR_DIST

        # Move to the next row
        row = rows.Next()

    # Select all non-zero elements so the zero's don't skew the mean
    non_z_indices = numpy.where(shortest)

    # Calculate mean and stdev
    mean_closeness = numpy.mean(shortest[non_z_indices])
    std_closeness = numpy.std(shortest[non_z_indices])
    
    # Return results
    return [mean_closeness, std_closeness]

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
    gp.SelectLayerByAttribute("Polyline_lyr", "NEW_SELECTION", " \"Length\" > " + str(MINIMUM_POLYLINE_LENGTH))
    gp.CopyFeatures("Polyline_lyr", SubsetFilename)

    print "Converting to points"
    PolylineToPoint_Centre(SubsetFilename, PointsFilename, gp.workspace)
    #PolylineToPoint_MaxCurv(SubsetFilename, PointsFilename, gp.workspace)

    print "Calculating Nearest Neighbour"
    
    # Do Nearest Neighbour calculation
    nn_output = gp.AverageNearestNeighbor_stats(PointsFilename, "Euclidean Distance", "false", "#")

    # Get stats on the dune lengths and numbers
    stats = CalculateStatistics(SubsetFilename, "Length")

    closeness = CalculateCloseness(SubsetFilename)

    mean_closeness = closeness[0]
    std_closeness = closeness[1]

    n_dunes = stats[0]
    mean_len = stats[1]
    total_len = stats[2]
    max_len = stats[3]
    min_len = stats[4]
    stdev_len = stats[5]

    defect_dens = n_dunes / total_len

    # Get out the individual parts of the Nearest Neighbour output
    nn_array = nn_output.rsplit(";")
    r_score = nn_array[0]
    z_score = nn_array[1]
    p_value = nn_array[2]

    # Create the CSV line ready to be appended
    csv_array = []
    tidied_file_name = re.sub("_extract", "", os.path.split(full_path_no_ext)[1])

    output_stats = [tidied_file_name, n_dunes, mean_len, total_len, max_len, min_len, stdev_len, mean_closeness, std_closeness, defect_dens, r_score, z_score, p_value]

    for item in output_stats:
        csv_array.append(str(item))

    csv_string = ",".join(csv_array)
    return csv_string

# ----------------------------------------------------------------
# Main Script Starts Here...
# ----------------------------------------------------------------

# Get the folder from the first command-line argument
folder = sys.argv[1]
#folder = "D:\\simulations\\batch_sims_unzipped\\RTW\\rtw363"

print "Started Dune Processing"

start = time.clock()

# Create the Geoprocessor object
gp = arcgisscripting.create()

print "Initialised ArcGIS object"

output_file = os.path.join(folder, "results.csv")

FILE = open(output_file, "a")
FILE.write("name,n,mean_len,total_len,max_len,min_len,stdev_len,mean_closeness,std_closeness,defect_dens,r_score,z_score,p_value\n")

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

end = time.clock()

print "-------------"
print "Analsis took " + str(end-start) + " seconds"

