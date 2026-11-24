/datum/storyteller/deadpop
	name = "Pepis Panic (Deadpop Chaos)"
	desc = "A storyteller intended for extremely low player counts. \
	Instead of antags, more focus is given to destructive events."
	welcome_text = "There's a weird ass fucking CREATURE IN FRONT OF THE BRIDGE!"
	storyteller_type = STORYTELLER_TYPE_ALWAYS_AVAILABLE

	antag_divisor = 32 //Ha ha, it's just like chill...

	guarantees_roundstart_crewset = FALSE
	tag_multipliers = list(
		TAG_NPC_ANTAG = 3,
		TAG_CLOWN = 1.5,
		TAG_DESTRUCTIVE = 1.1,
		TAG_CREW_ANTAG = 0.05
	)

	track_data = /datum/storyteller_data/tracks/deadpop

	starting_point_multipliers = list(
		EVENT_TRACK_MUNDANE = 1.2,
		EVENT_TRACK_MODERATE = 1,
		EVENT_TRACK_MAJOR = 1,
		EVENT_TRACK_CREWSET = 0,
		EVENT_TRACK_GHOSTSET = 0
	)
	event_repetition_multiplier = 0.8

/datum/storyteller_data/tracks/deadpop
	threshold_mundane = 800
	threshold_moderate = 1000
	threshold_major = 1800
	threshold_crewset = 20000
	threshold_ghostset = 20000
