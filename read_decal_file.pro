PRO READ_DECAL_FILE, input_file, output_file, r_fid
  ;file = "C:\Documents and Settings\Robin Wilson\My Documents\_Academic\GISTest\IDL\_Dunes\sand05.txt"
  
  ; Open file
  OPENR, lun, input_file, /GET_LUN
  
  ; Initialise string variable
  str = ""
  
  ; For every line in the file
  WHILE NOT EOF(lun) DO BEGIN
    ; Read the line into a string
    READF, lun, str
    
    ; Split the string by space characters, and convert to integers
    int_array = fix(STRSPLIT(str, " ", /EXTRACT))
    
    ; Append to the output array - dealing with the first time
    IF N_ELEMENTS(output) EQ 0 THEN BEGIN
      output = int_array
    ENDIF ELSE BEGIN
      output = [ [output], [[int_array]] ]
    ENDELSE
  ENDWHILE
  
  FREE_LUN, lun
  
  OPENW, unit, output_file, /get_lun
  WRITEU, unit, output
  FREE_LUN, unit
  
  dims = SIZE(output, /DIMENSIONS)
  
  ENVI_SETUP_HEAD, fname=output_file, ns=dims[0], nl=dims[1], nb=1, interleave=0, data_type=2, offset=0, r_fid=r_fid, /write, /open
END