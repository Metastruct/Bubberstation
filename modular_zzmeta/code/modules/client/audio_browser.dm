/// Lets players browse, search, preview, and copy the resource path of every sound file shipped with the game.
/// Restricted to admins (R_SOUND) by default - set AUDIO_BROWSER_ADMIN_ONLY to 0 in config.txt to let all players use it.
GLOBAL_DATUM_INIT(audio_browser, /datum/audio_browser, new)

/datum/config_entry/flag/audio_browser_admin_only
	default = TRUE

/datum/audio_browser

/datum/audio_browser/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AudioBrowser")
		ui.open()

/datum/audio_browser/ui_state(mob/user)
	if(CONFIG_GET(flag/audio_browser_admin_only))
		return ADMIN_STATE(R_SOUND)
	return GLOB.always_state

/datum/audio_browser/ui_assets(mob/user)
	return list(
		get_asset_datum(/datum/asset/json/audio_browser),
	)

/datum/audio_browser/ui_data(mob/user)
	return list(
		"is_admin" = check_rights_for(user.client, R_SOUND),
	)

/datum/audio_browser/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(action == "stop")
		if(!check_rights_for(user.client, R_SOUND))
			to_chat(user, span_warning("This feature is restricted to admins."), confidential = TRUE)
			return
		for(var/mob/player as anything in GLOB.player_list)
			SEND_SOUND(player, sound(null, channel = CHANNEL_ADMIN))
		log_admin("[key_name(user)] stopped all sounds played via the audio browser.")
		message_admins("[key_name_admin(user)] stopped all sounds played via the audio browser.")
		return TRUE

	var/path = params["path"]
	if(!(path in SSsounds.all_sounds))
		return
	switch(action)
		if("preview")
			SEND_SOUND(user, sound(path, channel = CHANNEL_ADMIN))
			return TRUE
		if("play_global")
			if(!check_rights_for(user.client, R_SOUND))
				to_chat(user, span_warning("This feature is restricted to admins."), confidential = TRUE)
				return
			var/volume = tgui_input_number(user, "What volume would you like the sound to play at?", max_value = 100)
			if(!volume)
				return
			for(var/mob/listener in GLOB.player_list)
				var/pref_volume = listener.client.prefs.read_preference(/datum/preference/numeric/volume/sound_midi)
				if(pref_volume > 0)
					listener.playsound_local(listener, path, (volume * (pref_volume / 100)), FALSE, channel = CHANNEL_ADMIN, pressure_affected = FALSE)
			log_admin("[key_name(user)] played mounted sound \"[path]\" to everyone via the audio browser.")
			message_admins("[key_name_admin(user)] played mounted sound \"[path]\" to everyone via the audio browser.")
			return TRUE
		if("play_target")
			if(!check_rights_for(user.client, R_SOUND))
				to_chat(user, span_warning("This feature is restricted to admins."), confidential = TRUE)
				return
			var/mob/target = input(user, "Choose a mob to play the sound to. Only they will hear it.", "Audio Browser") as null|anything in sort_names(GLOB.player_list)
			if(QDELETED(target))
				return
			var/volume = tgui_input_number(user, "What volume would you like the sound to play at?", max_value = 100)
			if(!volume)
				return
			SEND_SOUND(target, sound(path, volume = volume, channel = CHANNEL_ADMIN))
			log_admin("[key_name(user)] played mounted sound \"[path]\" to [key_name_admin(target)] via the audio browser.")
			message_admins("[key_name_admin(user)] played mounted sound \"[path]\" to [ADMIN_LOOKUPFLW(target)] via the audio browser.")
			return TRUE

/// Ships the full list of playable sound resource paths to the client as a static JSON asset.
/datum/asset/json/audio_browser
	name = "audio_browser_sounds"

/datum/asset/json/audio_browser/generate()
	return SSsounds.all_sounds

/client/verb/open_audio_browser()
	set category = "OOC"
	set name = "Open Audio Browser"
	set desc = "Browse, search, and preview every sound in the game, and copy their resource paths."

	if(CONFIG_GET(flag/audio_browser_admin_only) && !check_rights_for(src, R_SOUND))
		to_chat(usr, span_warning("This feature is restricted to admins."))
		return

	GLOB.audio_browser.ui_interact(usr)
