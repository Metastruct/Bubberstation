/datum/emote/living/carbon/lick
	key = "lick"
	key_third_person = "licks"
	cooldown = 3 SECONDS

/datum/emote/living/carbon/lick/run_emote(mob/user, params, type_override, intentional)
	. = ..()
	if(!isliving(user))
		return
	var/mob/living/living_user = user
	if(living_user.remove_status_effect(/datum/status_effect/sensory/lick))
		return
	living_user.apply_status_effect(/datum/status_effect/sensory/lick)

/datum/emote/living/carbon/smell
	key = "smell"
	key_third_person = "smells"
	cooldown = 3 SECONDS

/datum/emote/living/carbon/smell/run_emote(mob/user, params, type_override, intentional)
	. = ..()
	if(!isliving(user))
		return
	var/mob/living/living_user = user
	if(living_user.remove_status_effect(/datum/status_effect/sensory/smell))
		return
	living_user.apply_status_effect(/datum/status_effect/sensory/smell)
