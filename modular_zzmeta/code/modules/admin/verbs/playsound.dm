/**
 * BYOND's "as sound" file picker can return control to the verb before a double-clicked
 * file has actually finished uploading, silently handing back an empty/invalid resource
 * (selecting the file and pressing "Open" instead does not have this problem).
 * Returns FALSE and warns the requesting admin (only) if the upload looks incomplete.
 */
/proc/validate_admin_sound_upload(file, mob/user)
	if(file && fexists(file))
		return TRUE
	to_chat(user, span_warning("That sound didn't finish uploading, so nothing was played. This can happen if you double-clicked the file in the picker instead of selecting it and pressing \"Open\" - please try again."))
	return FALSE

/datum/admin_verb/play_sound/__avd_do_verb(client/user, sound as sound)
	if(!validate_admin_sound_upload(sound, user))
		return
	return ..()

/datum/admin_verb/play_local_sound/__avd_do_verb(client/user, sound as sound)
	if(!validate_admin_sound_upload(sound, user))
		return
	return ..()

/datum/admin_verb/play_direct_mob_sound/__avd_do_verb(client/user, sound as sound, mob/target in world)
	if(!validate_admin_sound_upload(sound, user))
		return
	return ..()

/datum/admin_verb/set_round_end_sound/__avd_do_verb(client/user, sound as sound)
	if(!validate_admin_sound_upload(sound, user))
		return
	return ..()
