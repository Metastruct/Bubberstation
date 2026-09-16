/// A toggleable RP status effect: shuts the eyes visually (via the same eyelid-tinting branch
/// used for unconsciousness/death, see get_eyelid_overlays()) and actually blinds the owner
/// (via the standard become_blind/cure_blind grouped-blindness mechanism) until removed.
/datum/status_effect/eyes_closed
	id = "eyes_closed"
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null

/datum/status_effect/eyes_closed/on_apply()
	. = ..()
	ADD_TRAIT(owner, TRAIT_EYES_CLOSED, TRAIT_STATUS_EFFECT(id))
	owner.become_blind(TRAIT_STATUS_EFFECT(id))
	owner.update_eyes()

/datum/status_effect/eyes_closed/on_remove()
	REMOVE_TRAIT(owner, TRAIT_EYES_CLOSED, TRAIT_STATUS_EFFECT(id))
	owner.cure_blind(TRAIT_STATUS_EFFECT(id))
	owner.update_eyes()

GAME_VERB_DESC(/mob/living/carbon/human, toggle_eyes_closed, "Close Eyes", "Close your eyes. Use again to open them.", "IC")
	if(incapacitated)
		to_chat(src, span_warning("You can't do that right now!"))
		return

	if(has_status_effect(/datum/status_effect/eyes_closed))
		remove_status_effect(/datum/status_effect/eyes_closed)
		visible_message(span_notice("[src] opens their eyes."), span_notice("You open your eyes."))
	else
		apply_status_effect(/datum/status_effect/eyes_closed)
		visible_message(span_notice("[src] closes their eyes."), span_notice("You close your eyes."))
