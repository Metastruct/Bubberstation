// Save paintings every restart rather than just round-ends
/datum/controller/subsystem/persistent_paintings/Shutdown()
	. = ..()
	save_paintings()
