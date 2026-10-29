// disables tab autocompletion taken from monke #12858
/datum/preference/toggle/commandbar_tab_autocomplete
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "commandbar_tab_autocomplete"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/toggle/commandbar_tab_autocomplete/apply_to_client(client/client, value)
	if(!istype(client, /client))
		return
	client.tgui_panel?.send_hotkey_mode()
