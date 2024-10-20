/************************
 * FMDML Helper Scripts *
 ************************/

/*
 * T1GFMDMLBase:
 * Common routines for derived scripts.
 * This script responds to no messages.
 */
class T1GFMDMLBase extends SqRootScript
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
 * T1DoorFix:
 * Implements the door obstruction and synchronization behavior from the Thief 2
 * door script.
 */
class T1DoorFix extends SqRootScript
{

	function OnCloseAfterHalt()
	{
		// Close the door after having previously been halted.
		Door.CloseDoor(self);
		Sound.HaltSchema(self);
	}

	function OnDoorOpening()
	{
		// Close the door instead if it was halted while opening.
		if (message().PrevActionType == eDoorAction.kHalt
			&& IsDataSet("BeforeHalt"))
		{
			if (GetData("BeforeHalt") == eDoorAction.kOpening)
				PostMessage(self, "CloseAfterHalt");
			ClearData("BeforeHalt");
		}
	}

	function OnDoorHalt()
	{
		// Set 'BeforeHalt' to the previous action on halt.
		SetData("BeforeHalt", message().PrevActionType);
	}

	function OnSynchUp() {
		local pair = message().from;
		if (Property.Possessed(pair, "Locked")
			&& Property.Possessed(self, "Locked"))
		{
			// Synchronize the locked state between double doors.
			local pairLock = Property.Get(pair, "Locked");
			local lock = Property.Get(self, "Locked");
			if (lock != pairLock)
				Property.CopyFrom(self, "Locked", pair);
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
class SetVectorProp extends T1GFMDMLBase
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
