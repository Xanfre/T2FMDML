/************************
 * FMDML Helper Scripts *
 ************************/

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
