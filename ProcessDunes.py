# Code written by Robin Wilson (robin@rtwilson.com)
# to process dune crests created through processing DECAL
# output files using IDL
import arcgisscripting
import os

def CalculateLength(PolylineFeatures):
    print "Adding field"
    gp.AddField(PolylineFeatures, "Length", "double")

    print "Getting descriptions"
    desc = gp.Describe(PolylineFeatures)
    shapeField = desc.ShapeFieldName

    print "Getting cursor"
    rows = gp.UpdateCursor(PolylineFeatures)
    row = rows.Next()
    gp.AddMessage("  Calculating values" + "\n")

    while row:
        # Create the geometry object
        feat = row.GetValue(shapeField)
        # Calculate the appropriate statistic
        row.SetValue("Length",feat.length)
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

# ----------------------------------------------------------------
# Main Script Starts Here...
# ----------------------------------------------------------------

# Set input details
InRaster = "C:\Documents and Settings\Robin Wilson\My Documents\_Academic\GISTest\TestOutput2.tif"
PolylineFilename = "DunesExportTest.shp"
SubsetFilename = "Subset.shp"

# Create the Geoprocessor object
gp = arcgisscripting.create()

gp.OverWriteOutput = 1

gp.workspace = "C:\TestArcWorkspace"

print "Finished initialising"


print "Converting Raster -> Polyline"

# Process: RasterToPolyline_conversion
gp.RasterToPolyline_conversion(InRaster, PolylineFilename, "ZERO", 0, "SIMPLIFY", "Value")

print "Calculating length"
CalculateLength(PolylineFilename)

# Make a feature layer from the polylines
gp.MakeFeatureLayer(PolylineFilename,"Polyline_lyr")

print "Subsetting by length"
gp.SelectLayerByAttribute("Polyline_lyr", "NEW_SELECTION", " \"Length\" > 15 ")
gp.CopyFeatures("Polyline_lyr", SubsetFilename)

print "Mean Length: ", Mean(SubsetFilename, "Length")
print "Total Length: ", Sum(SubsetFilename, "Length")
print "Number of dunes: ", Count(SubsetFilename, "Length")


# Do Nearest Neighbour calculation
nn_output = gp.AverageNearestNeighbor_stats(SubsetFilename, "Euclidean Distance", "false", "#")
print nn_output



