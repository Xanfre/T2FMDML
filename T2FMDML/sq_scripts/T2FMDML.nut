/*
 * FMDML Helper Scripts
 */

class T2FMDMLReposBase extends SqRootScript
{

	// Get the specified location
	function GetLoc(def)
	{
		local loc = def;
		if ("RepositionLoc" in userparams())
		{
			try
			{
				local locxyz = split(
					userparams().RepositionLoc.tostring(), ","
				);
				if (locxyz.len() == 3)
					loc = vector(locxyz[0].tofloat(), locxyz[1].tofloat(),
						locxyz[2].tofloat());
			}
			catch (err) { }
		}
		return loc;
	}

	// Get the specified rotation
	function GetDir(def)
	{
		local dir = def;
		if ("RepositionDir" in userparams())
		{
			try
			{
				local dirhpb = split(
					userparams().RepositionDir.tostring(), ","
				);
				if (dirhpb.len() == 3)
					dir = vector(dirhpb[2].tofloat(), dirhpb[1].tofloat(),
						dirhpb[0].tofloat());
			}
			catch (err) { }
		}
		return dir;
	}

}

class T2FMDMLSimReposOfst extends T2FMDMLReposBase
{

	// Teleport this object to its current position and rotation plus the
	// retrieved offsets on Sim start.
	function OnSim()
	{
		if (message().starting)
			Object.Teleport(self, Object.Position(self) + GetLoc(vector(0)),
				Object.Facing(self) + GetDir(vector(0)));
	}

}

class T2FMDMLSimReposAbs extends T2FMDMLReposBase
{

	// Teleport this object to the retrieved location and rotation on Sim start.
	function OnSim()
	{
		if (message().starting)
			Object.Teleport(self, GetLoc(Object.Position(self)),
				GetDir(Object.Facing(self)));
	}

}

const SVP_MAX_SUBPROP = 4;

class SetVectorProp extends SqRootScript
{

	// Get the specified property.
	function GetPropParam()
	{
		try
		{
			return userparams()[GetClassName() + "Property"].tostring();
		}
		catch (err)
		{
			Debug.MPrint(
				"[" + GetClassName() + "] No property specified for object "
				+ self + "."
			);
			return null;
		}
	}

	// Get the specified subproperties.
	function GetSubPropParam()
	{
		local subprops = [];
		subprops.resize(SVP_MAX_SUBPROP);
		for (local i = 0; i < SVP_MAX_SUBPROP; i++)
		{
			try
			{
				subprops[i] = userparams()[GetClassName() + "SubProperty"
					+ (0 == i ? "" : i + 1)].tostring();
			}
			catch (err) { }
		}
		return subprops;
	}

	// Get the specified property values.
	function GetValueParam()
	{
		local values = [];
		values.resize(SVP_MAX_SUBPROP);
		for (local i = 0; i < SVP_MAX_SUBPROP; i++)
		{
			try
			{
				values[i] = userparams()[GetClassName() + "Value"
					+ (0 == i ? "" : i + 1)].tostring();
			}
			catch (err) { }
		}
		return values;
	}

	// Set the requested property fields with the provided values.
	function SetProp()
	{
		// Fetch parameters for the property to be modified, the subproperties
		// (if applicable), and the vector values to be set.
		local prop = GetPropParam();
		if (null == prop)
			return;
		local subprops = GetSubPropParam();
		local vals = GetValueParam();
		for (local i = 0; i < SVP_MAX_SUBPROP; i++)
		{
			// Skip this field if no value was specified.
			if (null == vals[i])
				continue;
			// Separate the comma-separated values passed as the value
			// parameter.
			local val = split(vals[i], ",");
			// Ensure a 3-tuple was passed as the value.
			// If one was, construct a vector using it and populate the
			// specified property field.
			if (3 == val.len()) {
				local vec = vector(val[0].tofloat(), val[1].tofloat(),
					val[2].tofloat());
				Property.Set(self, prop,
					null == subprops[i] ? "" : subprops[i], vec);
			}
		}
		// Handle special cases for modifying physics attributes of doors.
		// Ex. COG Offset
		// In particular, re-initialize the relevant door property.
		if (prop == "PhysAttr")
		{
			if (Property.Possessed(self, "RotDoor"))
				Property.CopyFrom(self, "RotDoor", self);
			else if (Property.Possessed(self, "TransDoor"))
				Property.CopyFrom(self, "TransDoor", self);
		}
	}

	// Set the property on simulation start.
	function OnSim()
	{
		if (message().starting) SetProp();
	}

}

class SetVectorProp2 extends SetVectorProp { }

class SetVectorProp3 extends SetVectorProp { }

class SetVectorProp4 extends SetVectorProp { }
