/// Rebuild the instant say/radio/ooc/me/pray macros (see modular_zzmeta/code/modules/client/client_procs.dm)
/// as soon as this is toggled, instead of waiting for the next rebind or relog.
/datum/preference/toggle/tgui_input/apply_to_client(client/client, value)
	client.update_special_keybinds()
