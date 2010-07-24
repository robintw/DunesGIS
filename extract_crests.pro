FUNCTION DO_CONVOL, x, y, array
  kernel = intarr(3, 3)
  kernel[x,y] = 1
  
  return, CONVOL(float(array), kernel, /CENTER, /EDGE_TRUNCATE)
END

FUNCTION REMOVE_LOW_VALUES, fid, dims, pos, threshold
  WholeBand = ENVI_GET_DATA(fid=fid, dims=dims, pos=pos)
  
  indices = WHERE(WholeBand LT threshold)
  
  WholeBand[indices] = 0
  
  return, WholeBand
END

PRO EXTRACT_CRESTS_FROM_FOLDER, folder
  filenames = FILE_SEARCH(folder, "*sand05.txt")
  
  print, filenames
  
  FOR i = 0, N_ELEMENTS(filenames)-1 DO BEGIN
    EXTRACT_CRESTS_AUTOMATED, filenames[i]
  ENDFOR
END


PRO EXTRACT_CRESTS_AUTOMATED, input_file
  input_file_base = STRMID(input_file, 0, STRLEN(input_file) - 4)

  output_file = input_file_base + ".bsq"
  
  READ_DECAL_FILE, input_file, output_file, r_fid
  print, "Read DECAL file from " + input_file
  
  output_file = input_file_base + "_extract.tif"
  
  ENVI_FILE_QUERY, r_fid, dims=dims
  pos = [0]
  
  EXTRACT_CRESTS, r_fid, dims, pos, output_file
  print, "Extracted crests to ", output_file
END

PRO EXTRACT_CRESTS_GUI

  ; Use the ENVI dialog box to select a file
  ENVI_SELECT, fid=fid,dims=dims,pos=pos, /BAND_ONLY

  EXTRACT_CRESTS, fid, dims, pos
END

FUNCTION EXTRACT_FROM_ASPECT, aspect_fid
  ; Get the dims of the file
  ENVI_FILE_QUERY, aspect_fid, dims=dims
  
  ; Get the data into an array called image
  image = ENVI_GET_DATA(fid=aspect_fid, dims=dims, pos=0)

  ns = dims[2]
  nl = dims[4]

  output = intarr(ns, nl)

; Get the individual cell from top left, top middle etc as below
  ; A  B  C
  ; D  E  F
  ; G  H  I

  A = DO_CONVOL(0, 0, image)
  B = DO_CONVOL(1, 0, image)
  C = DO_CONVOL(2, 0, image)
  D = DO_CONVOL(0, 1, image)
  E = DO_CONVOL(1, 1, image)
  F = DO_CONVOL(2, 1, image)
  G = DO_CONVOL(0, 2, image)
  H = DO_CONVOL(1, 2, image)
  I = DO_CONVOL(2, 2, image)
  
  last_set = 0
  second_set = 0
  
  FOR r = 0, nl - 1 DO BEGIN
  FOR c = 0, ns - 1 DO BEGIN
    ; A  B  C
    ; D  E  F
    ; G  H  I
    
    IF last_set EQ 1 THEN BEGIN
      last_set = 0
      second_set = 1
      CONTINUE
    ENDIF
    
    IF second_set EQ 1 THEN BEGIN
      second_set = 0
      CONTINUE
    ENDIF
    
  
    ; Do cardinal directions first
    IF D[c, r] GT 180 AND F[c, r] LT 180 THEN output[c, r] = 1
    IF F[c, r] GT 180 AND D[c, r] LT 180 THEN output[c, r] = 1
    
    IF B[c, r] GT 180 AND H[c, r] LT 180 THEN output[c, r] = 1
    IF H[c, r] GT 180 AND B[c, r] LT 180 THEN output[c, r] = 1
    
    IF output[c, r] EQ 1 THEN BEGIN
      last_set = 1
    ENDIF ELSE BEGIN
      last_set = 0
    ENDELSE
    
  ENDFOR
  ENDFOR
  
  return, output
END

PRO EXTRACT_CRESTS, fid, dims, pos, output_file
  ; Remove the low values from the input image to reduce noise
  thresholded = REMOVE_LOW_VALUES(fid, dims, pos, 10)
  ENVI_ENTER_DATA, thresholded, r_fid=thresholded_fid

  ; Create aspect image
  envi_doit, 'topo_doit', fid=thresholded_fid, pos=pos, dims=dims, $
    bptr=[1], /IN_MEMORY, pixel_size=[1,1], r_fid=aspect_fid
    
  ; Run two low pass filters over the aspect image to remove noise
  envi_doit, 'conv_doit', fid=aspect_fid, dims=dims, pos=pos, kx=3, ky=3, method=3, $
    /IN_MEMORY, r_fid=LP1_fid
  envi_doit, 'conv_doit', fid=LP1_fid, dims=dims, pos=pos, kx=3, ky=3, method=3, $
    /IN_MEMORY, r_fid=LP2_fid
    
  
  ; Extract rough crests from aspect image
  output = EXTRACT_FROM_ASPECT(LP2_fid)
  
  ; Fill in the gaps if needed
  filled_output = FILL_IN_GAPS(output)
  
  ENVI_ENTER_DATA, filled_output, r_fid=output_fid
 
  ; Output to TIFF
  ENVI_FILE_QUERY, output_fid, dims=dims
  ENVI_OUTPUT_TO_EXTERNAL_FORMAT, fid=output_fid, pos=[0], dims=dims, /TIFF, out_name=output_file
  
  ; Remove all the temporary in-memory files that we created
  ENVI_FILE_MNG, id=thresholded_fid, /REMOVE, /DELETE
  ENVI_FILE_MNG, id=aspect_fid, /REMOVE, /DELETE
  ENVI_FILE_MNG, id=LP1_fid, /REMOVE, /DELETE
  ENVI_FILE_MNG, id=LP2_fid, /REMOVE, /DELETE
  ENVI_FILE_MNG, id=output_fid, /REMOVE, /DELETE 
  ENVI_FILE_MNG, id=fid, /REMOVE
  
  
END

FUNCTION FILL_IN_GAPS, output
  ;ENVI_SELECT, fid=file,dims=dims,pos=pos, /BAND_ONLY
  ;output = ENVI_GET_DATA(fid=file, dims=dims, pos=pos)
  
  
    
  A = PTR_NEW(DO_CONVOL(0, 0, output))
  B = PTR_NEW(DO_CONVOL(1, 0, output))
  C = PTR_NEW(DO_CONVOL(2, 0, output))
  D = PTR_NEW(DO_CONVOL(0, 1, output))
  E = PTR_NEW(DO_CONVOL(1, 1, output))
  F = PTR_NEW(DO_CONVOL(2, 1, output))
  G = PTR_NEW(DO_CONVOL(0, 2, output))
  H = PTR_NEW(DO_CONVOL(1, 2, output))
  I = PTR_NEW(DO_CONVOL(2, 2, output))
  
  ; A  B  C
  ; D  E  F
  ; G  H  I
  
  pairs = [ [A, H], [A, I], [A, F], [D, F], [G, B], [G, C], [D, F], [G, F], [D, C], [D, I]]

  sum = *A + *B + *C + *D + *E + *F + *G + *H + *I

  FOR loop_var = 0, (N_ELEMENTS(pairs)/2)-1 DO BEGIN
    *A = DO_CONVOL(0, 0, output)
    *B = DO_CONVOL(1, 0, output)
    *C = DO_CONVOL(2, 0, output)
    *D = DO_CONVOL(0, 1, output)
    *E = DO_CONVOL(1, 1, output)
    *F = DO_CONVOL(2, 1, output)
    *G = DO_CONVOL(0, 2, output)
    *H = DO_CONVOL(1, 2, output)
    *I = DO_CONVOL(2, 2, output)
    
    sum = *A + *B + *C + *D + *E + *F + *G + *H + *I
    
    indices = WHERE(output EQ 0 AND *pairs[0, loop_var] EQ 1 AND *pairs[1, loop_var] EQ 1 AND sum EQ 2, count)
    if count GT 0 THEN BEGIN
      output[indices] = 1
    ENDIF
  ENDFOR
  
  return, output
END

FUNCTION FILL_IN_GAP, start, finish, sum, output
  indices = WHERE(output EQ 0 AND start EQ 1 AND finish EQ 1 AND sum EQ 2, count)
  if count GT 0 THEN BEGIN
    output[indices] = 1
  ENDIF
  
  return, output
END