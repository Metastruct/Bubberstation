/**
 * Skips the client to server to client round trip when opening the TGUI say popup
 * (T, ;, O, M, P, L, Y by default) so it isn't gated on the player's ping.
 *
 * Today, pressing one of those keys sends the keypress to /client/verb/keyDown()
 * (a real verb call, code/modules/keybindings/bindings_client.dm), which dispatches
 * server-side to the matching down() proc under /datum/keybinding/client/communication
 * (code/datums/keybinding/communication.dm and
 * modular_skyrat/modules/customization/datums/keybinding/communication.dm for
 * LOOC/Whisper), which winset()s the open command back down to the client, adding a
 * full round trip (and thus ping) to opening the popup.
 *
 * tgui_say_create_open_command(channel) is pure/deterministic for a given channel
 * (code/modules/tgui_input/say_modal/modal.dm), so which command a key should send is
 * already known at bind time. This mirrors the ADMIN_CHANNEL case already handled
 * below by binding the open command straight into the macro, bypassing keyDown()
 * entirely for these keys, the same trick already used for asay, just extended to the
 * regular say/radio/ooc/me/pray/looc/whisper hotkeys.
 *
 * The original per-channel down() procs are untouched and still work exactly as
 * before; they just stop being reached for a key once this claims it. They remain
 * the live path when tgui_input is disabled (native input() box, not worth this
 * optimization) and a safety net for any key this proc skips.
 *
 * If a key is bound to one of these channels AND something else (e.g. a player
 * rebound an ability to the same key as Say), the fast path is skipped for that key
 * so it keeps going through keyDown(), otherwise the other keybinding bound to that
 * key would stop firing.
 *
 * These macros bind the bare physical key (e.g. "L"), and BYOND has no notion of a
 * combined "Ctrl+L" key event, only separate "Ctrl" and "L" events with modifier state
 * tracked by hand in keyDown() (code/modules/keybindings/bindings_client.dm). A static
 * winset command can't consult that state at fire-time, so holding Ctrl/Alt/Shift would
 * pop the modal right along with the plain key unless something disables these macros
 * while a modifier is held. That's what instant_open_macros_active and
 * set_instant_open_macros() below are for: keyDown()/keyUp() call it on every
 * Ctrl/Alt/Shift transition to release the macros (falling through to the normal,
 * modifier-aware keyDown() routing) or re-arm them once no modifier is held.
 */
/client/var/instant_open_macros_active = FALSE

/client/update_special_keybinds(datum/preferences/direct_prefs)
	. = ..()
	set_instant_open_macros(!(keys_held["Ctrl"] || keys_held["Alt"] || keys_held["Shift"]), prefs || direct_prefs)

/client/proc/set_instant_open_macros(enable, datum/preferences/D)
	if(enable == instant_open_macros_active)
		return
	D ||= prefs
	if(!D?.key_bindings)
		return
	if(!D.read_preference(/datum/preference/toggle/tgui_input))
		return // Native input() box, no popup to pre-empt, leave keyDown() routing alone.
	instant_open_macros_active = enable
	var/static/list/instant_open_channels = list(SAY_CHANNEL, RADIO_CHANNEL, OOC_CHANNEL, ME_CHANNEL, PRAY_CHANNEL, LOOC_CHANNEL, WHIS_CHANNEL)
	for(var/channel in instant_open_channels)
		var/list/bound_keys = D.key_bindings[channel]
		if(!bound_keys)
			continue
		for(var/key in bound_keys)
			if(length(D.key_bindings_by_key[key]) > 1)
				continue // Shared with another keybind, keep the normal routing so that one still fires.
			if(enable)
				var/open_command = tgui_say_create_open_command(channel)
				winset(src, "default-[REF(key)]", "parent=default;name=[key];command=[open_command]")
			else
				winset(src, "default-[REF(key)]", "parent=null") // Falls through to the "Any" catch-all macro, i.e. normal keyDown() routing.
