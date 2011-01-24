/* ******************************
 * Modeler LScript: Transfer By UV
 * Version: 1.0
 * Author: Johan Steen
 * Date: 28 Mar 2010
 * Modified: 28 Mar 2010
 * Description: Transfers VMaps from the background to the background by using the UV coordinates as reference.
 *
 * http://www.artstorm.net
 *
 * Revisions
 * Version 1.0 - 28 Mar 2010
 * + Initial Release.
 * ****************************** */

@version 2.4
@warnings
@script modeler
@name "JS_TransferByUV"

// Main Variables
tbuv_version = "1.0";
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


// Vertex Maps
var VMDim;
var VMNamePost = nil;
var arrWeights;
var arrMorphs;
var arrSelections;
var arrListVMaps;		// The array in the Listbox (copied from the others).
var arrSelectedVMaps;	// Array that contains the VMaps selected in the listbox.


main {
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
	
	abort = matchUV();
    monend();
	undogroupend();
	// If aborted during matching, return without displaying the result window
	if (abort)
		return;
	openResultWin();
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


/*
 * Function to loop through the BG points and build an array of all uv/vmap values
 *
 * @returns     Nothing 
 */
scanBGData
{
	aBGPntData = nil;
    editbegin();
    var ctr = 1;
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
		aBGPntData[ctr, 1] = <uv[1],uv[2],0>;
		ctrt = 0;
		for (i = 1; i <= arrSelectedVMaps.count(); i++) {
			var vm = VMap(VMType, arrSelectedVMaps[i]);
			if(vm.isMapped(p)) {
				aBGPntData[ctr, i + 1] = vm.getValue(p);
				// Special case for selection maps
				if (vm.type == VMSELECT) {
					aBGPntData[ctr, i + 1] = true;
				}
			} else {
				aBGPntData[ctr, i + 1] = nil;
			}
		}
		ctr++;
    }
    editend();
    return false;
}


/*
 * Function to match the UV data between the layers
 *
 * @returns     Nothing 
 */
matchUV {
	// If selected points differs from total points, get the selection
	if (globalPntCnt != iTotFGPnts) {
		getSelPnts();
	}
    editbegin();

	// loop through all points in foreground
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
			
			// If a match was found, copy the VMap values
			if (matchPnt != nil) {
				transferVMap(p, matchPnt);
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

/*
 * Functions to transfer the VMaps
 *
 * @returns     Nothing 
 */
transferVMap: p, matchPnt {
	for (i = 1; i <= arrSelectedVMaps.count(); i++) {
		if (aBGPntData[matchPnt, i + 1] != nil) {
			var vm = VMap(VMType, arrSelectedVMaps[i] + VMNamePost, VMDim);
			vm.setValue(p, aBGPntData[matchPnt, i + 1]);
		}
	}
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
	ctlVMList = ctllistbox("Vertex Maps", 204, 300, "VMListSize", "VMListItem");
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
		
	// Collect the input
	tolerance = getvalue(ctlTol);
	VMType = getvalue(ctlVMType);
	// Convert VMTYPE to LScript Constant
	switch (VMType) {
		case 1: VMType = VMWEIGHT; VMDim = 1; break;
		case 2: VMType = VMMORPH; VMDim = 3; break;
		case 3: VMType = VMSELECT; VMDim = 1; VMNamePost = "_copy"; break;
	}

	// Get the names of the selected VMaps
	var vmaps_idx = getvalue(ctlVMList);
	for (i = 1; i <= vmaps_idx.count(); i++)
		arrSelectedVMaps += arrListVMaps[vmaps_idx[i]];

    reqend();
	return true;
}

// Refresh the GUI when VMap type changes
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
	// Clear listbox Selection
	setvalue(ctlVMList, nil);
	requpdate();
}

// UDFs for the Listbox
VMListSize {
    return(arrListVMaps.count());
}
VMListItem: index {
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

    c10 = ctlcheckbox("Create selection set of unmatched points", false);
    ctlposition(c10,10,76);
	
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
    reqend();
}

// About Window
openAboutWin
{
	reqbegin("About Transfer By UV");
	reqsize(330,160);

	ctlText1 = ctltext("","Transfer By UV", "Version: " + tbuv_version, "Build Date: " + tbuv_date);
	ctlText4 = ctltext("","Programming by Johan Steen.");
	ctlText5 = ctltext("","Variation of an idea by Lee Perry-Smith.");
	ctlSep1 = ctlsep();
	ctlposition(ctlText1, 10, 10);
	ctlposition(ctlSep1, 0, 64);
	ctlposition(ctlText4, 10, 78);
	ctlposition(ctlText5, 10, 100);
	
	url_johan = "http://www.artstorm.net/";
	url_lee = "http://www.ir-ltd.net/";
	url_docs = "http://www.artstorm.net/plugins/transfer-by-uv/";
	ctlurl1 = ctlbutton("Artstorm", 100, "gotoURL", "url_johan");
	ctlurl2 = ctlbutton("Infinite Realities", 100, "gotoURL", "url_lee");
	ctlurl3 = ctlbutton("Help", 100, "gotoURL", "url_docs");
	ctlposition(ctlurl1, 220, 75);
	ctlposition(ctlurl2, 220, 97);
	ctlposition(ctlurl3, 220, 10);
	
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