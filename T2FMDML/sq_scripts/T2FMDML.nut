/*
 * FMDML Helper Scripts
 */

class T2FMDMLReposBase extends SqRootScript {

	// Get the specified location
	function GetLoc(def) {
		local loc = def;
		if ("RepositionLoc" in userparams()) {
			try {
				local locxyz = split(userparams().RepositionLoc.tostring(), ",");
				if (locxyz.len() == 3) {
					loc = vector(locxyz[0].tofloat(), locxyz[1].tofloat(), locxyz[2].tofloat());
				}
			} catch (err) { }
		}
		return loc;
	}

	// Get the specified rotation
	function GetDir(def) {
		local dir = def;
		if ("RepositionDir" in userparams()) {
			try {
				local dirhpb = split(userparams().RepositionDir.tostring(), ",");
				if (dirhpb.len() == 3) {
					dir = vector(dirhpb[2].tofloat(), dirhpb[1].tofloat(), dirhpb[0].tofloat());
				}
			} catch (err) { }
		}
		return dir;
	}

}

class T2FMDMLSimReposOfst extends T2FMDMLReposBase {

	// Teleport this object to its current position and rotation plus the retrieved offsets on Sim start
	function OnSim() {
		if (message().starting) {
			Object.Teleport(self, Object.Position(self) + GetLoc(vector(0.0,0.0,0.0)), Object.Facing(self) + GetDir(vector(0.0,0.0,0.0)));
		}
	}

}

class T2FMDMLSimReposAbs extends T2FMDMLReposBase {

	// Teleport this object to the retrieved location and rotation on Sim start
	function OnSim() {
		if (message().starting) {
			Object.Teleport(self, GetLoc(Object.Position(self)), GetDir(Object.Facing(self)));
		}
	}

}
