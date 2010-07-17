# RasterToPolyline_sample.py
# Description: 
#   Converts a raster to polyline features.
# Requirements: None
# Author: ESRI
# Date: Oct 20, 2005
# Import system modules
import arcgisscripting
import os

def CalculateLength(PolylineFeatures):
    print "Adding field"
    gp.AddField(PolylineFeatures, "Length", "double")

    print "Getting descriptions"
    desc = gp.Describe(OutPolylineFeatures)
    shapeField = desc.ShapeFieldName

    print "Getting cursor"
    rows = gp.UpdateCursor(OutPolylineFeatures)
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


# Create the Geoprocessor object
gp = arcgisscripting.create()

# Set local variables
InRaster = "C:\Documents and Settings\Robin Wilson\My Documents\_Academic\GISTest\TestOutput2.tif"
OutPolylineFeatures = "C:/DunesExportTest.shp"

#os.remove(OutPolylineFeatures)

print "Converting Raster -> Polyline"

# Process: RasterToPolyline_conversion
gp.RasterToPolyline_conversion(InRaster, OutPolylineFeatures, "ZERO", 0, "SIMPLIFY", "Value")


print "Trying to subset..."
CalculateLength(OutPolylineFeatures)

