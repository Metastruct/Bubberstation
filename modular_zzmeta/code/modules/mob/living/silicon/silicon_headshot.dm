/mob/living/silicon
	var/headshot_snapshot
	var/headshot_snapshot_nsfw

/// Snapshots the silicon headshot prefs onto the mob at spawn/transform time, so later reads
/// (chat, examine panel) reflect the character actually played instead of whatever slot the
/// client currently has open in the character setup screen.
/mob/living/silicon/proc/apply_pref_headshot(client/requesting_client)
	if(!requesting_client?.prefs)
		return
	headshot_snapshot = requesting_client.prefs.read_preference(/datum/preference/text/headshot/silicon)
	headshot_snapshot_nsfw = requesting_client.prefs.read_preference(/datum/preference/text/headshot/silicon/nsfw)

/mob/living/silicon/get_chat_examine_headshot(mob/user)
	if(!user?.client)
		return null
	if(!user.client.prefs?.read_preference(/datum/preference/toggle/chat_examine_headshot))
		return null
	if(!length(headshot_snapshot))
		return null
	return "<div class='chat_headshot_top chat_headshot_frame'>[chat_headshot(html_encode(headshot_snapshot))]</div>"
