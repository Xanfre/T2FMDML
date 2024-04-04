/************************
 * FMDML Helper Scripts *
 ************************/

/*
 * T2FMDMLBase:
 * Common routines for derived scripts.
 * This script responds to no messages.
 */
class T2FMDMLBase extends SqRootScript
{

	// Get the script target.
	function GetTarget()
	{
		local targetstr = "";
		local target = [[], []]
		try
		{
			targetstr = userparams()[GetClassName() + "Target"].tostring();
		}
		catch(err) { target[0].append(self); }
		if (0 != targetstr.len())
		{
			local objstrs = split(targetstr, ",");
			foreach (objstr in objstrs)
			{
				local obj;
				local exclude = objstr.len() > 0 && objstr[0] == '!';
				if (exclude)
					objstr = objstr.slice(1);
				try
				{
					obj = objstr.tointeger();
				}
				catch (err) { obj = ObjID(objstr); }
				if (obj > 0 && Object.Exists(obj))
					target[exclude ? 1 : 0].append(obj);
				else if (obj < 0 && Object.Exists(obj))
				{
					local objmax = 8184, objmaxref = int_ref();
					if (Engine.ConfigGetInt("obj_max", objmaxref))
						objmax = objmaxref.tointeger();
					// NOTE: This is inefficient, but Squirrel scripts do not
					// have access to ITraitMan to query objects.
					for (local i = 1; i < objmax; i++)
					{
						if (!Object.Exists(i) || !Object.InheritsFrom(i, obj))
							continue;
						target[exclude ? 1 : 0].append(i);
					}
				}
			}
		}
		return target;
	}

}

/*
 * T2FMDMLRePhys:
 * Re-physicalize ControlDevice-linked physical objects upon receiving "TurnOn"
 * messages.
 * Linked objects are assumed to be physical objects.
 */
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

/*
 * T2FMDMLReposBase:
 * Get the user-specified location and direction parameters for use in derived
 * scripts.
 * This script responds to no messages.
 *
 * Parameters:
 * "RepositionLoc" - The new location of the object.
 * "RepositionDir" - The new direction of the object.
 */
class T2FMDMLReposBase extends SqRootScript
{

	// Get the specified location
	function GetLoc(def)
	{
		try
		{
			local loc = def;
			local locxyz = split(userparams().RepositionLoc.tostring(), ",");
			if (locxyz.len() == 3)
				loc = vector(locxyz[0].tofloat(), locxyz[1].tofloat(),
					locxyz[2].tofloat());
			return loc;
		}
		catch (err) { return def; }
	}

	// Get the specified rotation
	function GetDir(def)
	{
		try
		{
			local dir = def;
			local dirhpb = split(userparams().RepositionDir.tostring(), ",");
			if (dirhpb.len() == 3)
				dir = vector(dirhpb[2].tofloat(), dirhpb[1].tofloat(),
					dirhpb[0].tofloat());
			return dir;
		}
		catch (err) { return def; }
	}

}

/*
 * T2FMDMLSimReposOfst:
 * Change the position of this object on simulation start to that which was
 * provided, treating parameters as offsets applied to the object's current
 * state.
 */
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

/*
 * T2FMDMLSimReposAbs:
 * Change the position of this object on simulation start to that which was
 * provided, treating parameters as absolute.
 */
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

/*
 * NoBlkVisDoor:
 * Prevent this door from blocking vision, which is useful if you have the
 * 'black box' effect from its cells being set to block vision.
 *
 * Parameters:
 * "NoBlkVisDoorBlockAIVis" - Set the door to block AI vision instead of
 *     blocking vision on the door property itself. This parameter takes no
 *     argument.
 */
class NoBlkVisDoor extends SqRootScript
{

	// Set the blocking state of the door.
	function SetBlocking(on)
	{
		Door.SetBlocking(self, on);
		if (HasProperty("RotDoor"))
			SetProperty("RotDoor", "Blocks Vision?", on);
		else if (HasProperty("TransDoor"))
			SetProperty("TransDoor", "Blocks Vision?", on);
		if (!on)
			Door.SetBlocking(self, true)
	}

	// Unblock the door on script start.
	function OnBeginScript()
	{
		local blocking = false;
		if (HasProperty("RotDoor"))
			blocking = GetProperty("RotDoor", "Blocks Vision?");
		else if (HasProperty("TransDoor"))
			blocking = GetProperty("TransDoor", "Blocks Vision?");
		if (blocking)
		{
			SetBlocking(false);
			if (!HasProperty("AI_BlkVis")
				&& GetClassName() + "BlockAIVis" in userparams())
				SetProperty("AI_BlkVis", true);
		}
		if (!IsDataSet("Blocking"))
			SetData("Blocking", blocking);
	}

	// Block the door on script end.
	function OnEndScript()
	{
		if (IsDataSet("Blocking") && GetData("Blocking"))
			SetBlocking(true);
	}

}
/*
 * PhysTypeReAdd:
 * Re-add the "PhysType" property to the specified objects on simulation start.
 *
 * Parameters:
 * "PhysTypeReAddTarget" - The target of the script (either a concrete object or
 *     an archetype; multiple targets can be specified by providing a
 *     comma-separated list; prepend '!' to a target to explicitly exclude it).
 *     applicable).
 * "PhysTypeReAddType" - The physics type to which the targets will be reset.
 *     If none is provided, or an invalid option is provided, the default is
 *     "OBB".
 */
class PhysTypeReAdd extends T2FMDMLBase
{

	// Get the specified physics type.
	function GetTypeParam()
	{
		local type;
		try
		{
			switch (userparams()[GetClassName() + "Type"].tostring())
			{
				case "1":
				case "Sphere":
					type = 1;
					break;
				case "2":
				case "Sphere Hat":
					type = 2;
					break;
				default:
					type = 0;
					break;
			}
		}
		catch (err) { type = 0; }
		return type;
	}

	function OnSim()
	{
		if (message().starting)
		{
			// Fetch targets of re-initialization.
			local target = GetTarget();
			if (0 == target[0].len())
				return;
			// Get the destination physics type.
			local type = GetTypeParam();
			// Re-initialize the physics type property.
			foreach (obj in target[0])
			{
				local skip = false;
				foreach (exclusion in target[1])
				{
					if (obj == exclusion
						|| Object.InheritsFrom(obj, exclusion))
					{
						skip = true;
						break;
					}
				}
				if (!skip)
				{
					Property.Remove(obj, "PhysType");
					Property.Set(obj, "PhysType", "Type", type);
				}
			}
		}
	}

}

const SVP_MAX_SUBPROP = 4;

/*
 * SetVectorProp:
 * Set a specified vector property on the specified objects to that which was
 * provided on simulation start.
 * Provides multiple copies for use on the same object.
 *
 * Parameters:
 * "SetVectorProp[2,3,4]Target" - The target of the script (either a concrete
 *     object or an archetype; multiple targets can be specified by providing a
 *     comma-separated list; prepend '!' to a target to explicitly exclude it).
 * "SetVectorProp[2,3,4]Property" - The vector property to assign.
 * "SetVectorProp[2,3,4]SubProperty" - The sub property to assign (if
 *     applicable).
 * "SetVectorProp[2,3,4]Value" - The vector to assign to the property.
 */
class SetVectorProp extends T2FMDMLBase
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
		// Fetch targets of the set operation.
		local target = GetTarget();
		if (0 == target[0].len())
			return;
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
			if (3 == val.len())
			{
				local vec = vector(val[0].tofloat(), val[1].tofloat(),
					val[2].tofloat());
				foreach (obj in target[0])
				{
					local skip = false;
					foreach (exclusion in target[1])
					{
						if (obj == exclusion
							|| Object.InheritsFrom(obj, exclusion))
						{
							skip = true;
							break;
						}
					}
					if (!skip)
						Property.Set(obj, prop,
							null == subprops[i] ? "" : subprops[i], vec);
				}
			}
		}
		// Handle special cases for modifying physics attributes of doors.
		// Ex. COG Offset
		// In particular, re-initialize the relevant door property.
		if (prop == "PhysAttr")
		{
			foreach (obj in target[0])
			{
				if (Property.Possessed(obj, "RotDoor"))
					Property.CopyFrom(obj, "RotDoor", obj);
				else if (Property.Possessed(obj, "TransDoor"))
					Property.CopyFrom(obj, "TransDoor", obj);
			}
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

/*
 * T2FMDMLUnmount:
 * Unmounts the player from a rope or other climbable object upon receiving
 * "TurnOn".
 */
class T2FMDMLUnmount extends SqRootScript
{

	// Unmount the player.
	function OnTurnOn()
	{
		// Get the player object.
		local player = ObjID("Player");
		// Prepare the object being climbed.
		local climbobj = object(); 
		Physics.GetClimbingObject(player, climbobj);
		climbobj = climbobj.tointeger();
		// Unmount if the player is currently climbing.
		if (climbobj)
		{
			// If this is a non-rope OBB object like a ladder, trick Dark into
			// believing that it is a rope for a few moments and reset the
			// relevant properties after a short delay.
			if (!Physics.IsRope(climbobj) && Physics.IsOBB(climbobj))
			{
				Property.Add(climbobj, "PhysRope");
				Property.Set(climbobj, "PhysType", "Type", /*Sphere*/ 1);
				SetOneShotTimer("ResetPhys", 0.001, climbobj);
			}
			// Reset the velocity to what it was before. This will destroy all
			// object contacts on the player, causing him to unmount from ropes
			// (but not ladders!).
			// See SetVelocity() in PHSCRPT.CPP.
			local vel = vector();
			Physics.GetVelocity(player, vel);
			Physics.SetVelocity(player, vel);
		}
	}

	function OnTimer()
	{
		if (message().name == "ResetPhys" && message().data)
		{
			// Remove rope-related properties and reset physics.
			local climbobj = message().data;
			Property.Remove(climbobj, "PhysRope");
			Property.Remove(climbobj, "Creature");
			Property.Add(climbobj, "PhysType");
		}
	}

}

/*
 * T2FMDMLZomExpRelay:
 * Relay a "T2FMDMLZomExp" message to a specified controller object if this
 * zombie was destroyed with a particular weapon.
 *
 * Parameters
 * "T2FMDMLZomExpRelayWeapon" - The accepted weapon's archetype or object ID.
 * "T2FMDMLZomExpRelayController" - The controller object's name or object ID.
 */
class T2FMDMLZomExpRelay extends SqRootScript
{

	// Relay a message if this zombie is about to explode.
	function OnSlain()
	{
		// If the weapon archetype exists and this zombie is actually dead,
		// send a message to the controller.
		// If this is not a zombie, assume that it is dead.
		local zomarch = ObjID("ZombieTypes");
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
		if (Object.Exists(weap)
			&& (!Object.Exists(zomarch) || !Object.InheritsFrom(self, zomarch)
				|| (HasProperty("MAX_HP") && 0 >= GetProperty("MAX_HP")))
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

/*
 * T2FMDMLZomExpCtl:
 * Upon receiving the "T2FMDMLZomExp" message, temporarily flatten the player's
 * bash parameters coefficient to prevent damage from flying zombie parts.
 * The original coefficient is restored after a short delay.
 *
 * Parameters:
 * "T2FMDMLZomExpCtlDelay" - The amount of time before the bash parameters
 *     coefficient is reset to its initial value.
 */
class T2FMDMLZomExpCtl extends SqRootScript
{

	// Temporarily flatten the bash parameters coefficient.
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
