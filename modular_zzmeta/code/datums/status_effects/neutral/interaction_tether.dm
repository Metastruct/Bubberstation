/// Watcher effect used by the interaction system to keep a status effect (e.g. Cover's
/// blindness/muffle) alive only while tether_source stays adjacent to the owner.
/datum/status_effect/interaction_tether
	id = "interaction_tether"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_MULTIPLE
	alert_type = null
	/// Whoever needs to stay adjacent for the linked effect to persist.
	var/mob/living/tether_source
	/// Typepath of the status effect this tether is keeping alive, stripped early once the tether breaks.
	var/linked_effect_type

/datum/status_effect/interaction_tether/on_creation(mob/living/new_owner, mob/living/source, linked_type)
	tether_source = source
	linked_effect_type = linked_type
	return ..()

/datum/status_effect/interaction_tether/tick(seconds_between_ticks)
	if(QDELETED(tether_source) || QDELETED(owner) || !owner.Adjacent(tether_source))
		qdel(src)

/datum/status_effect/interaction_tether/on_remove()
	if(linked_effect_type && owner)
		owner.remove_status_effect(linked_effect_type)
