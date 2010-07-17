; THIS FILE IS NO LONGER USED, BUT MAY BE USEFUL IN FUTURE
; 
; Idea: Keep track of which cell you've come to a cell from, and then don't let you go back there unles there are no other possibilities
; Kinda done the idea above
; Somehow last_cell = current_cell == 33....how on earth?!

PRO TRACE_ROUTES
  ; Get the image from ENVI
  image = GET_IMAGE_ARRAY()
  
  ; Create an image where each cell is the number of neighbours of that cell
  num_neighbours = CREATE_NUM_NEIGHBOURS_IMAGE(image)

  
  ; Get the dimensions of the input image
  dims = SIZE(image, /DIMENSIONS)
  
  ; Create visited array
  visited = bytarr(dims[0], dims[1])
  
  ; Create final output array
  final_output = bytarr(dims[0], dims[1])
  
  ; Look for a starting pixel that hasn't been visited
  starting_indices = WHERE(num_neighbours EQ 1 AND visited EQ 0)
  
;  print, starting_indices
  
  output = FOLLOW_ROUTES(starting_indices[0], visited, num_neighbours, image)

END

FUNCTION FOLLOW_ROUTES, start, global_visited, num_neighbours, image
  ; Run FOLLOW_ROUTE until there are no more routes left to find
    ; How do we know that?
  
  finished = 0
  
  WHILE finished EQ 0 DO BEGIN
;    print, "--- VISITED BEFORE ---"
;    print, global_visited
    output = FOLLOW_ROUTE(start, global_visited, num_neighbours, image)
;    print, "--- VISITED AFTER ---"
;    print, global_visited
    print, "----------------- Structure ----------"
    print, output.output
    print, "Length:", output.length
    print, "Finish location:", output.finish
    print, "Num unvisited:", output.unvisited
    finished = output.properly_finished
    
    IF N_ELEMENTS(routes) EQ 0 THEN BEGIN
      routes = output
    ENDIF ELSE BEGIN
      routes = struct_append(routes, output)
    ENDELSE
  ENDWHILE
  
  ; Remove the last element from routes, as it had a num unvisited of 0
  routes = routes[0:N_ELEMENTS(routes)-2]
  
  
  
  print, "Done!"
    
  ; Examine all of the returned structures to select the best route
  ; Return it!
  
  return, 0
END

FUNCTION FOLLOW_ROUTE, start, global_visited, num_neighbours, image
   ; Get the dimensions of the input image
  dims = SIZE(image, /DIMENSIONS)
  
  ; Create the arrays specific to this particular route - ie. the output (the route selected) and the local_visited arrays
  output = bytarr(dims[0], dims[1])
  local_visited = bytarr(dims[0], dims[1])
  
  current_cell = start
  
  ; Initialise finish and last_cell
  finish = -1
  last_cell = -1
  num_unvisited = 0
  properly_finished = 0
  
  WHILE finish NE current_cell DO BEGIN
  
    IF global_visited[current_cell] EQ 0 THEN num_unvisited++
    
    IF current_cell EQ last_cell THEN BEGIN
      print, "Break!"
    ENDIF
  
    ; Mark the current cell as visited in the global map - using bitwise operations
    MARK_VISITED, global_visited, current_cell, last_cell
    
    ; Mark the current cell as visited in the local map - using bitwise operatons
    MARK_VISITED, local_visited, current_cell, last_cell
    
    ; Put the current cell in the output map
    output[current_cell] = 1
    
    print, current_cell
    
    ; Start working out where to move to
    
    ; Global candidates are all cells which are 1 and haven't already been visited in this route
    global_candidates = WHERE(local_visited EQ 0 AND image EQ 1)
    
    ; These are all the neighbouring indices (8 of them - not including middle cell)
    neighbour_indices = GET_NEIGHBOURS(current_cell, dims)
    
    ; Some of the neighbours may be outside the grid - so exclude those, and also exclude the last cell we visited (so we don't go backwards)
    neighbour_indices = neighbour_indices[WHERE(neighbour_indices GT 0 AND neighbour_indices NE last_cell)]
    
    ; The local candidates are those cells that are both global and in the neighbourhood
    local_candidates = SetIntersection(global_candidates, neighbour_indices, SUCCESS=success)
    
    ; If there are no local candidates then we've finished tracing this route - and CONTINUE will make the WHILE re-evaluate and stop the loop
    IF success EQ 0 THEN BEGIN
      finishing_cells = WHERE(num_neighbours EQ 1)
      index = WHERE(finishing_cells EQ current_cell, count)
      IF count NE 0 THEN BEGIN
        finish = current_cell ; WHAT DO WE DO WHEN WE'VE FINISHED?
        properly_finished = 1
        print, "I've Finished!"
        CONTINUE
      ENDIF
      print, "Though I'd finished, but haven't..."
    ENDIF
    
    ; Skip all the processing below if there is only one local candidate - just move to it
    IF N_ELEMENTS(local_candidates) EQ 1 THEN BEGIN
      ; Mark current cell as last cell before we change it
      last_cell = current_cell
      current_cell = local_candidates[0]
      
      CONTINUE
    ENDIF
    
    
    ; Choose a cell based on which direction we've come at it from
    ; ------------------------------------------------------------
    
    FOR i = 0, N_ELEMENTS(local_candidates) - 1 DO BEGIN
      possible_cell = local_candidates[i]
      IF N_ELEMENTS(direction_masks) EQ 0 THEN BEGIN
        direction_masks = GET_DIRECTION(possible_cell, current_cell, dims)
      ENDIF ELSE BEGIN
        direction_masks = [direction_masks, GET_DIRECTION(possible_cell, current_cell, dims)]
      ENDELSE
    ENDFOR
    
    ; Select cells not visited from this direction ever before (ie. using global_visited image)
    
    candidate_cells = bytarr(N_ELEMENTS(local_candidates))
    
    ; Awfully inefficient way of doing this - optimise later!
    FOR i = 0, N_ELEMENTS(local_candidates) - 1 DO BEGIN
      print, "Global Visited [i]", global_visited[local_candidates[i]]
      print, "Direction Masks [i]", direction_masks[i]
      print, "Stopped here!"
      IF (global_visited[local_candidates[i]] AND direction_masks[i]) EQ 0 THEN BEGIN
        candidate_cells[i] = 1
      ENDIF
    ENDFOR

    ; Mark current cell as last cell before we change it
    last_cell = current_cell
    
    indices = WHERE(candidate_cells EQ 1, count)
    IF count EQ 0 THEN BEGIN
      finish = current_cell ; WHAT DO WE DO WHEN WE'VE FINISHED?
      print, "I've Finished! - Second bit"
      CONTINUE
    ENDIF
    
    actual_candidates = local_candidates[indices]
    
    current_cell = RANDOM_ELEMENT_OF(actual_candidates)
    
    
  ENDWHILE
  
  ;print, "------------ Output ----------"
  ;print, output
  
  indices = WHERE(output EQ 1)
  length = N_ELEMENTS(indices)
  
  
  
  IF num_unvisited EQ 0 AND properly_finished EQ 1 THEN BEGIN
    return_finished = 1
  ENDIF ELSE BEGIN
    return_finished = 0
  ENDELSE
  
  return_struct = { output: output, finish: finish, length: length, unvisited: num_unvisited, properly_finished: return_finished}
         
  return, return_struct
END

FUNCTION RANDOM_ELEMENT_OF, array
  random_number = RANDOMU(seed)
  
  index = fix(random_number * N_ELEMENTS(array))  
  
  return, array[index]
END

FUNCTION GET_NEIGHBOURS, current_cell, dims
  neighbour_indices = [current_cell + 1, current_cell - 1, current_cell - dims[0], (current_cell - dims[0]) - 1,  (current_cell - dims[0]) + 1,  current_cell + dims[0], (current_cell + dims[0]) + 1, (current_cell + dims[0] - 1)]
  
  return, neighbour_indices
END

FUNCTION DO_CONVOL, x, y, array
  kernel = intarr(3, 3)
  kernel[x,y] = 1
  
  return, CONVOL(float(array), kernel, /CENTER, /EDGE_ZERO)
END

PRO MARK_VISITED, visited_array, current_cell, last_cell
  dims = SIZE(visited_array, /DIMENSIONS)
  
  IF last_cell EQ -1 THEN BEGIN
    visited_array[current_cell] = 255
    return
  ENDIF
  
  bit_value = GET_DIRECTION(current_cell, last_cell, dims)
  
  visited_array[current_cell] = visited_array[current_cell] OR bit_value
END

FUNCTION GET_DIRECTION, current_cell, last_cell, dims
  possible_last_cells = GET_NEIGHBOURS(current_cell, dims)

  bitwise_values = [2^0, 2^1, 2^2, 2^3, 2^4, 2^5, 2^6, 2^7]
  
  index = WHERE(possible_last_cells EQ last_cell, count)
  if count EQ 0 THEN BEGIN
    print, "ARGH - it's all gone wrong!"
    print, "blah"
  ENDIF
  
  
  bit_value = bitwise_values[index]
  
  return, bit_value
END

FUNCTION GET_IMAGE_ARRAY
  ; Use the ENVI dialog box to select a file
  ENVI_SELECT, fid=file,dims=dims,pos=pos, /BAND_ONLY
  
  WholeBand = ENVI_GET_DATA(fid=file, dims=dims, pos=pos)
  
  return, WholeBand
END

FUNCTION CREATE_NUM_NEIGHBOURS_IMAGE, image
  
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
  
  ; Note - E is not added below as it is the centre pixel anyway!
  num_neighbours = fix(A + B + C + D  + F + G + H + I)
  
  indices = WHERE(image EQ 0)
  num_neighbours[indices] = 0
  
  return, num_neighbours
END

