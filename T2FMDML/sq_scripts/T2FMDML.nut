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

class T2FMDMLRePhys extends SqRootScript
{

	function RePhys()
	{
		// Remove and add the "PhysType" property to each ControlDevice-linked
		// object.
		// NOTE: This is assumed to be used only on physical objects.
		if (!Link.AnyExist(linkkind("ControlDevice"), self))
			return;
		foreach (l in Link.GetAll(linkkind("ControlDevice"), self))
		{
			Property.Remove(LinkDest(l), "PhysType");
			Property.Add(LinkDest(l), "PhysType");
		}
	}

	function OnRePhys() { RePhys(); }

	function OnTurnOn() { RePhys(); }

}

class T2FMDMLZomExpRelay extends SqRootScript
{

	function OnSlain()
	{
		// If the weapon archetype exists and this zombie is actually dead,
		// send a message to the controller.
		local weapname = "";
		local weap = 0
		try
		{
			weapname = userparams()[GetClassName() + "Weapon"].tostring();
			weap = weapname.tointeger();
		}
		catch (err) { }
		if (!weap && weapname.len() > 0)
			weap = ObjID(weapname);
		if (Object.Exists(weap) && HasProperty("MAX_HP")
			&& 0 >= GetProperty("MAX_HP")
			&& (Object.InheritsFrom(message().culprit, weap)
				|| message().culprit == weap))
		{
			// Check if the controller exists.
			local ctlname = "";
			local ctl = 0;
			try
			{
				ctlname = userparams()[GetClassName() + "Controller"].tostring();
				ctl = ctlname.tointeger();
			}
			catch (err) { }
			if (!ctl && ctlname.len() > 0)
				ctl = ObjID(ctlname);
			if (!Object.Exists(ctl))
				return;
			// Send both a generic and specific message to the controller.
			SendMessage(ctl, "T2FMDMLZomExp");
			SendMessage(ctl, "T2FMDMLZomExp" + self);
		}
	}

}

class T2FMDMLZomExpCtl extends SqRootScript
{

	function OnT2FMDMLZomExp()
	{
		// Check if the player object exists as a precaution and broadcast the
		// message to other players if this is a multiplayer game.
		local plrobj = ObjID("Player");
		if (!Object.Exists(plrobj))
			return;
		if (Networking.IsMultiplayer() && Networking.IsPlayer(plrobj)
			&& TRUE != message().data)
			Networking.Broadcast(self, "T2FMDMLZomExp", TRUE, TRUE);
		// Get the initial value of the bash params coefficient.
		local coeff = Property.Get(plrobj, "BashParams", "Coefficient");
		// Flatten the coefficient of the player's bash parameters.
		// This will nullify bash damage.
		Property.Set(plrobj, "BashParams", "Coefficient", 0.0);
		// Store the initial coefficient if no timer has been set,
		local timer = IsDataSet("TimerHandle") ? GetData("TimerHandle") : 0;
		if (0 == timer)
			SetData("Coeff", coeff);
		else
		// Otherwise, kill the existing timer.
			KillTimer(timer);
		// Get the reset delay.
		// The default is 250 ms.
		local delay = 0.25;
		try
		{
			delay = userparams()[GetClassName() + "Delay"].tofloat();
		}
		catch (err) { }
		// Set a timer for resetting the bash parameters.
		SetData("TimerHandle", SetOneShotTimer("T2FMDMLZomExpReset", delay));
	}

	function OnTimer()
	{
		if (message().name == "T2FMDMLZomExpReset")
		{
			// Nullify the timer handle.
			SetData("TimerHandle", 0);
			// Check if the player object exists as a precaution.
			local plrobj = ObjID("Player");
			if (!Object.Exists(plrobj))
				return;
			// Get the initial coefficient value if it was properly fetched.
			// The default is 0.00133.
			local coeff = IsDataSet("Coeff") ? GetData("Coeff") : 0.00133;
			// Reset the coefficient of the bash parameters.
			Property.Set(plrobj, "BashParams", "Coefficient", coeff);
		}
	}

}
