/* ******************************
 * Modeler LScript: Transform By UV
 * Version: 1.0
 * Author: Johan Steen
 * Date: 28 Mar 2010
 * Modified: 28 Mar 2010
 * Description: Conforms the foreground mesh to the background by using the UV coordinates as reference.
 *
 * http://www.artstorm.net
 * ****************************** */

@version 2.4
@warnings
@script modeler
@name "JS_TransferByUV"

// Main Variables
tbuv_version = "0.5";
tbuv_date = "28 March 2010";

// GUI Settings
var tolerance = 0.02;
var VMType = 1;			// 1 = Weights, 2 = Morphs, 3 = Selections

// GUI Gadgets
var ctlVMList;

// Misc
var fg;
var bg;

// Point Variables
var uvMap;				// Holds the selected UV map
var iTotBGPnts;			// Integer with total number of points in BG layer
var iTotFGPnts;			// Integer with total number of selected points in FG layer
var globalPntCnt;		// Integer with total number of poins in FG layer
var aBGPntData;			// Array that keeps track of all point coords and UV coords
var selPnts;			// Array that keeps track of current user point selection

// Stats Variables
var statsNoUV = 0;
var statsUnMatched = nil;
var statsOverlapped = nil;


var arrSurfaces;
var arrMatchedPoints;
var arrPolys;

// Vertex Maps
var arrWeights;
var arrMorphs;
var arrSelections;
var arrListVMaps;		// The array in the Listbox (copied from the others).
var arrSelectedVMaps;	// Array that contains the VMaps selected in the listbox.


main
{
    //
    // Make all preparations so the plugin finds enough data to be used.
    // --------------------------------------------------------------------------------
	// Get selected UV Map
    uvMap = VMap(VMTEXTURE, 0) || error("Please select a UV map.");		// By using 0, the modeler selected UV map is acquired.
	
	// Get total number of points, not caring about selections
	selmode(GLOBAL);
	globalPntCnt = pointcount();

	// Get user selected point count
    selmode(USER);
    var iTotFGPnts = pointcount();

	// Get the layers
	fg = lyrfg();
    bg = lyrbg();
	
	// Error handling: If no BG selected or more than 1 BG layer selected, exit plugin
    if(bg == nil) error("Please select a BG layer.");
    if(bg.size() > 1) error("Please select only one BG layer.");
	// Error handling:  if FG is empty, exit plugin
    if(iTotFGPnts <= 0) error("Please use a FG layer with geometry.");
	
	// If selected points differs from total points, store the selection
	if (globalPntCnt != iTotFGPnts) {
		storeSelPnts();
	}

	// Switch to BG, and Get number of points in BG layer
    lyrsetfg(bg);
	iTotBGPnts = pointcount();
	
	// Error handling: If BG is empty, exit plugin
    if(iTotBGPnts == 0){
        lyrsetfg(fg);
        lyrsetbg(bg);
        error("Please use a BG layer with geometry.");
    }

	// Retrieve all available Vertex Maps, and set Default
	getVertexMaps();
	arrListVMaps = arrWeights;

    //
    // Open the main window and collect / process user input.
    // --------------------------------------------------------------------------------
	// Restore layer selections
    lyrsetfg(fg);
    lyrsetbg(bg);
	
	var mainWin = openMainWin();
	if (mainWin == false)
		return;

	/* Window Closed, start the process */
    undogroupbegin();
	// Switch to BG again
    lyrsetfg(bg);

	// Initialize the progress bar (iTotBGPnts for looping the BG array + iTotFGPnts when looping though the FG points )
    moninit((iTotBGPnts + 1) + iTotFGPnts);
	// Get all info from bg layer
    var abort = scanBGData();

	// Update number of BG Points (if some lacked UV coords)
	// using iTotBGPnts on each loop later, is faster than using .size() on each iteration
	iTotBGPnts = aBGPntData.size();
	// Restore layer selections
    lyrsetfg(fg);
    lyrsetbg(bg);
	// If aborted during getBGInfo, exit
    if(abort) return true;
	
	
	findMatches();


    monend();



//	abort = findMatches();
//	if (abort)
//		return;
	undogroupend();

			openResultWin();

}


/*
 * Function to loop through the BG points and build an array of all uv/vmap values
 *
 * @returns     Nothing 
 */
scanBGData
{
	aBGPntData = nil;
	// Setup Vertex Map type
	if (VMType == 1)
		var vType = VMWEIGHT;
	if (VMType == 2)
		var vType = VMMORPH;
	if (VMType == 3)
		var vType = VMSELECT;
    editbegin();
    var i = 1;
    foreach(p, points)
    {
		// Increase the progress bar
        if(monstep()){
            editend(ABORT);
            return true;
        }
		// Get the UV values
        var uv = uvMap.getValue(p);
		// Check so the point contains UV data
		if(uv == nil){ 
			// skip rest of the loop and continue with the next point
			continue;
		}
		// If UV data was present
		aBGPntData[i,1] = <uv[1],uv[2],0>;
		for (j = 1; j <= arrSelectedVMaps.count(); j++) {
			var vm = VMap(vType, arrSelectedVMaps[j]);
			if(vm.isMapped(p)) {
				aBGPntData[i, j + 1] = vm.getValue(p);
				if (vm.type == VMSELECT) {
					aBGPntData[i, j + 1] = true;
				}
			} else {
				aBGPntData[i, j + 1] = nil;
			}
		}
		i++;
    }
    editend();
    return false;
}

/*
 * Function to retrieve all Vertex Maps used.
 *
 * @returns     Nothing 
 */
getVertexMaps {
	editbegin();
    var vmap = VMap();
    while(vmap) {
		switch (vmap.type) {
			case VMWEIGHT:
				arrWeights += vmap.name;
				break;
			case VMMORPH:
				arrMorphs += vmap.name;
				break;
			case VMSELECT:
				arrSelections += vmap.name;
				break;
		}
		vmap = vmap.next();
    }
	editend();
}



// Finds the matching UV coordinates and performed the desired operation
findMatches {
    //
    // Start moving the points in the foreground
    // --------------------------------------------------------------------------------
	// If selected points differs from total points, get the selection
	if (globalPntCnt != iTotFGPnts) {
		getSelPnts();
	}
    editbegin();
	

	// loop through all points in foreground
    var p;
j = 1;			
    foreach(p,points){
		// Get the UV for current point
        var uv = uvMap.getValue(p);
		if(uv == nil) {
			// If the point lacks UV coords
			statsNoUV++;
		} else {
			// Convert the UV coords to a vector
			var uvVec = <uv[1],uv[2],0>;
			var bestMatch = nil;					// Keep track of current best match
			var matchPnt = nil;				
			// Loop through all BG UV coords
			for (i=1; i <= iTotBGPnts; i++) {
				// Skip if BG pnt already has been used
				if (aBGPntData[i] != nil) {
					// Get the distance between the FG and BG UV coord vectors
					var getDist = vmag(uvVec - aBGPntData[i,1]);
					// If perfect match is found
					if (getDist == 0) {
						// match immediately and break the for loop
						matchPnt = i;
						break;
					}
					// Check if distance is smaller than current best match, and that distance is within the tolerance
					if (getDist < bestMatch && getDist < tolerance) {
						bestMatch = getDist;
						matchPnt = i;
					}
				}
			}
			
			// If a match was found, move the point into position
			if (matchPnt != nil) {
	if (VMType == 1)
		copyWeight(p, matchPnt);
	if (VMType == 2)
		copyMorph(p, matchPnt);
	if (VMType == 3)
		copySelect(p, matchPnt);
//				if (operationMode == 1) 
//					positionPnt(p, matchPnt);
//				if (operationMode == 2) 
//					positionUV(p, matchPnt);
//				if (operationMode == 3) 
//					positionMorph(p, matchPnt);
//		arrMatchedPoints[j,1] = p;
//		arrMatchedPoints[j,2] = aBGPntData[matchPnt,5];
//		j++;
		
			} else {
				// if no match was found, add the unmatched point to the stats array
				statsUnMatched += p;
			}
		}
		// Increase the progressbar
		if(monstep()){
			monend();
			editend(ABORT);
			return true;
		}
    }
    editend();
	return false;
}

// Moves points, for normal mode
copyWeight: p, matchPnt {
		for (j = 1; j <= arrSelectedVMaps.count(); j++) {
			if (aBGPntData[matchPnt, j + 1] != nil) {
				var vm = VMap(VMWEIGHT, arrSelectedVMaps[j], 1);
				vm.setValue(p, aBGPntData[matchPnt, j + 1]);
			}
//			var vm = VMap(VMWEIGHT, arrSelectedVMaps[j]);
//			if(vm.isMapped(p)) {
//				aBGPntData[i, j + 1] = vm.getValue(p);
//			} else {
//				aBGPntData[i, j + 1] = nil;
//			}
		}

//	if (aBGPntData[matchPnt,5] == true) {
//				statsOverlapped += p;
//	}
//	p.x = aBGPntData[matchPnt,1];
//	p.y = aBGPntData[matchPnt,2];
//	p.z = aBGPntData[matchPnt,3];
//	aBGPntData[matchPnt,5] = true;
}


copyMorph: p, matchPnt {
		for (j = 1; j <= arrSelectedVMaps.count(); j++) {
			if (aBGPntData[matchPnt, j + 1] != nil) {
				var vm = VMap(VMMORPH, arrSelectedVMaps[j], 3);
				vm.setValue(p, aBGPntData[matchPnt, j + 1]);
			}
		}
}


copySelect: p, matchPnt {
		for (j = 1; j <= arrSelectedVMaps.count(); j++) {
			if (aBGPntData[matchPnt, j + 1] != nil) {
				var vm = VMap(VMSELECT, arrSelectedVMaps[j] + "_copy", 1);
				vm.setValue(p, aBGPntData[matchPnt, j + 1]);
			}
		}
}


// Moves UV coordinates for Cleanup mode
positionUV: p, matchPnt {
	if (aBGPntData[matchPnt,5] == true) {
				statsOverlapped += p;
	}
	var thisUV = aBGPntData[matchPnt,4];
	uv[1] = thisUV.x; uv[2] = thisUV.y;
	uvMap.setValue(p,uv);
	aBGPntData[matchPnt,5] = true;
}

// Moves positions into relative morphs
positionMorph: p, matchPnt {
	// Dirty, dirty solution, fix this.
	if (morphCtr > 2) {
		var oldMap = VMap(VMMORPH, morphPrefix + (morphCtr - 2).asStr());
		if(oldMap.isMapped(p)) {
			valold = oldMap.getValue(p);
			morphMap = VMap(VMMORPH,morphPrefix + (morphCtr - 1).asStr(), 3);
			val[1] = aBGPntData[matchPnt,1] + valold[1] - p.x;
			val[2] = aBGPntData[matchPnt,2] + valold[2] - p.y;
			val[3] = aBGPntData[matchPnt,3] + valold[3] - p.z;
		} else {
			if (morphCtr == 3) {
				val[1] = aBGPntData[matchPnt,1] - p.x;
				val[2] = aBGPntData[matchPnt,2] - p.y;
				val[3] = aBGPntData[matchPnt,3] - p.z;
			}
		}
	} else {
		val[1] = aBGPntData[matchPnt,1] - p.x;
		val[2] = aBGPntData[matchPnt,2] - p.y;
		val[3] = aBGPntData[matchPnt,3] - p.z;
	}
	morphMap.setValue(p,val);
}


getSurfaces {
	editbegin();
	i = 1;
	foreach (p, polygons) {
		poly = polyinfo(p);
//		info (poly[1]);
// arrSurfaces += poly[1];
 arrSurfaces += "surf" + i.asStr();
 i++;
//		polysurface(p, "surf" + i.asStr());
arrPolys[i, 1] = poly[1];
arrPolys[i, 2] = poly[2];
arrPolys[i, 3] = poly[3];
arrPolys[i, 4] = poly[4];
arrPolys[i, 5] = poly[5];
	}
	editend();

	// Get surfaces
	// surface = nextsurface();
	// arrSurfaces += surface;
	// info(surface);
	// while(true)
	// {
		// if((surface = nextsurface(surface)) == nil)
		// break;
	// arrSurfaces += surface;
//     info(surface);

	/*	surfObj = Surface();
	while(surfObj)
	{
		arrSurfaces += surfObj.name;
		surfObj = surfObj.next();
	} */
}






mainSelectedMorph
{
	// Get selected morph
//	vmap = VMap(VMMORPH,0) || error("Select a Weight map so I have something to do!");
	vmap = VMap(VMMORPH,0);
	if (!vmap) {
		info ("no morph selected");
	} else {
		info (vmap.name);
	}
}

mainGetAvailableMorphs
{
	// List available morphs
    vmap = VMap(VMWEIGHT) || error("No morph maps in mesh!");
    while(vmap && vmap.type == VMWEIGHT)
    {
         arrWeightMaps += vmap.name;
         vmap = vmap.next();
    }
//	info (vmapnames);
}

mainAddMorphAndReturnToBase
{
//	info("mupp");
	editbegin();
	morphMap = VMap(VMMORPH,"test", 3);
    foreach(p, points) {
		val[1] = 0;
		val[2] = 0;
		val[3] = 0;
		morphMap.setValue(p,val);
	}
	editend();
	
	new();
	close();
}



/*
 * Functions to handle point selections
 *
 * @returns     Nothing 
 */

// Stores all selected Point ID's in an array
storeSelPnts
{
    editbegin();
    foreach(p, points) {
        selPnts += p;
    }
    editend();
}

// Selects all points stored in the selection array
getSelPnts
{
	selmode(USER);
    selpolygon(CLEAR);                  // Switch to polygon mode, to speed up drawing of point selections
	selpoint(SET, POINTID, selPnts);
    selpoint(SET,NPEQ,1000);        	// Switch back to point selection mode (Dummy selection value to keep current selection)
}

/*
 * Functions to handle the windows
 *
 * @returns     Nothing 
 */

 // Main Window, Returns false for cancel
openMainWin
{
    reqbegin("Transfer By UV v" + tbuv_version);
    reqsize(248,444);               // Width, Height

    ctlTol = ctlnumber("Tolerance", tolerance);
    ctlVMType = ctlpopup("VMap Type", 1, @ "Weights","Morphs","Selections" @);
	ctlVMList = ctllistbox("Vertex Maps", 204, 300, "ListSize", "ListItem"); //(label,width, height,count_udf,name_udf[, event_udf , [select_udf] ] )
    ctlAbout = ctlbutton("About the Plugin", 73, "openAboutWin");
	
	ctlSep1 = ctlsep();
	ctlSep2 = ctlsep();

	var yComp = 0;
    ctlposition(ctlVMType,		25,	10);
    ctlposition(ctlTol,			32,	32, 204);
	ctlposition(ctlSep1, 		0,	60);
	ctlposition(ctlVMList,		10,	68);
	ctlposition(ctlSep2, 		0,	376);
	ctlposition(ctlAbout, 		86, 384, 150);

	
	// Refresh controller on VMap Type Change
	ctlrefresh(ctlVMType, "refreshMainWin");
	
    if (!reqpost())
		return false;
		
	VMType = getvalue(ctlVMType);
    tolerance = getvalue(ctlTol);

	// Get the names of the selected VMaps
	var vmaps_idx = getvalue(ctlVMList);
	for (i = 1; i <= vmaps_idx.count(); i++)
		arrSelectedVMaps += arrListVMaps[vmaps_idx[i]];

    reqend();
	return true;
}

refreshMainWin: value
{
	switch (value) {
		case 1:
			arrListVMaps = arrWeights;
			break;
		case 2:
			arrListVMaps = arrMorphs;
			break;
		case 3:
			arrListVMaps = arrSelections;
			break;
	}
	// Clear Selection
	setvalue(ctlVMList, nil);
	requpdate();
}


ListSize
{
    return(arrListVMaps.count());
}

// UDF to get a listbox item (name_udf)
ListItem: index
{
    return(arrListVMaps[index]);
}
// Result Window
openResultWin
{
    reqbegin("Transfer By UV");
    reqsize(240,170);               // X,Y
	// Add result info here
    c2 = ctltext("","Points without UVs: " + statsNoUV);
    ctlposition(c2,10,10,200,13);
    c3 = ctltext("","Unmatched Points: " + statsUnMatched.size());
    ctlposition(c3,10,30,200,13);
//    c5 = ctltext("","Overlapping Points: " + statsOverlapped.size());
//    ctlposition(c5,10,50,200,13);

    c10 = ctlcheckbox("Create selection set of unmatched points", false);
    ctlposition(c10,10,76);
    c11 = ctlcheckbox("Create selection set of overlapping points", false);
    ctlposition(c11,10,100);
	
    return if !reqpost();

	// Create selection set of unmatched points
	if (getvalue(c10) == true && statsUnMatched.size() != 0) {
		selmode(USER);
		editbegin();
		selMap = VMap(VMSELECT,"UnMatched",1);
		foreach(p,statsUnMatched)
		{
			selMap.setValue(p,1);
		}
		editend();
	}

	// Create selection set of overlapping points
	if (getvalue(c11) == true && statsOverlapped.size() != 0) {
		selmode(USER);
		editbegin();
		selMap = VMap(VMSELECT,"Overlap",1);
		foreach(p,statsOverlapped)
		{
			selMap.setValue(p,1);
		}
		editend();
	}
    reqend();
}

// About Window
openAboutWin
{
	reqbegin("About Transfer By UV");
	reqsize(330,160);

	ctlText1 = ctltext("","Transfer By UV", "Version: " + tbuv_version, "Build Date: " + tbuv_date);
//	ctlText4 = ctltext("","Programming by Johan Steen.");
//	ctlText5 = ctltext("","Ideas, Logo & Testing by Lee Perry-Smith.");
//	ctlSep1 = ctlsep();
//	ctlposition(ctlText1, 10, 10);
//	ctlposition(ctlSep1, 0, 64);
//	ctlposition(ctlText4, 10, 78);
//	ctlposition(ctlText5, 10, 100);
	
	url_johan = "http://www.artstorm.net/";
	url_lee = "http://www.ir-ltd.net/";
	url_docs = "http://www.artstorm.net/plugins/conform-by-uv/";
//	ctlurl1 = ctlbutton("Artstorm", 100, "gotoURL", "url_johan");
//	ctlurl2 = ctlbutton("Infinite Realities", 100, "gotoURL", "url_lee");
//	ctlurl3 = ctlbutton("Help", 100, "gotoURL", "url_docs");
//	ctlposition(ctlurl1, 220, 75);
//	ctlposition(ctlurl2, 220, 97);
//	ctlposition(ctlurl3, 220, 10);
	
	return if !reqpost();
	reqend();
}

@asyncspawn
gotoURL: url
{
var spawnStr = "cmd.exe /C start " + url;
url_id = spawn(spawnStr);
if(url_id == nil)
	info("Failed to open website " + url);
}