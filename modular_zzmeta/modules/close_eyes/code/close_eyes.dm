/// A toggleable, purely cosmetic RP status effect: shuts the eyes visually (via the same
/// eyelid-tinting branch used for unconsciousness/death, see get_eyelid_overlays()) until removed.
/datum/status_effect/eyes_closed
	id = "eyes_closed"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null

/datum/status_effect/eyes_closed/on_apply()
	. = ..()
	ADD_TRAIT(owner, TRAIT_EYES_CLOSED, TRAIT_STATUS_EFFECT(id))
	owner.update_eyes()

/datum/status_effect/eyes_closed/on_remove()
	REMOVE_TRAIT(owner, TRAIT_EYES_CLOSED, TRAIT_STATUS_EFFECT(id))
	owner.update_eyes()

/mob/living/carbon/human/verb/toggle_eyes_closed()
	set name = "Close Eyes"
	set category = "IC"
	set desc = "Close your eyes. Use again to open them."

	if(incapacitated)
		to_chat(src, span_warning("You can't do that right now!"))
		return

	if(has_status_effect(/datum/status_effect/eyes_closed))
		remove_status_effect(/datum/status_effect/eyes_closed)
		visible_message(span_notice("[src] opens their eyes."), span_notice("You open your eyes."))
	else
		apply_status_effect(/datum/status_effect/eyes_closed)
		visible_message(span_notice("[src] closes their eyes."), span_notice("You close your eyes."))
