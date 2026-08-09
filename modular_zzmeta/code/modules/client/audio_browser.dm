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

/datum/audio_browser/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return
	switch(action)
		if("preview")
			var/path = params["path"]
			if(!(path in SSsounds.all_sounds))
				return
			SEND_SOUND(ui.user, sound(path))
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
