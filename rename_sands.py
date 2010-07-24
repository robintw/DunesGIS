import re
import os

folder = "D:\GIS\ConstantIterations"

# Recursively walk though the directory tree
for root, dirs, files in os.walk(folder):
    # For each file found
    for name in files:
        # Get the full file path
        full_path = os.path.join(root, name)
        # If it's a .tif file then print the full file path
        if re.search("sand\d\d.txt", name):
            print "----------------"
            print "Processing " + full_path
            new_name = os.path.split(root)[1] + "_" + name
            print "New name = " + new_name
            os.rename(full_path, os.path.join(root, new_name))
