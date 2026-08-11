/**
 * Skips the client to server to client round trip when opening the TGUI say popup
 * (T, ;/Y, O, M, P by default) so it isn't gated on the player's ping.
 *
 * Today, pressing one of those keys sends the keypress to /client/verb/keyDown()
 * (a real verb call, code/modules/keybindings/bindings_client.dm), which dispatches
 * server-side to the matching down() proc under /datum/keybinding/client/communication
 * (code/datums/keybinding/communication.dm), which winset()s the open command back
 * down to the client. That's a full round trip just to reveal a popup that's already
 * sitting hidden on the client, and on a high-ping connection it's the whole delay.
 *
 * tgui_say_create_open_command(channel) is pure/deterministic for a given channel
 * (code/modules/tgui_input/say_modal/modal.dm), so which command a key should send is
 * already known at bind time. This mirrors the ADMIN_CHANNEL case already handled
 * below by binding the open command straight into the macro, bypassing keyDown()
 * entirely for these keys, the same trick already used for asay, just extended to the
 * regular say/radio/ooc/me/pray hotkeys.
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
 */
/client/update_special_keybinds(datum/preferences/direct_prefs)
	. = ..()
	var/datum/preferences/D = prefs || direct_prefs
	if(!D?.key_bindings)
		return
	if(!D.read_preference(/datum/preference/toggle/tgui_input))
		return // Native input() box, no popup to pre-empt, leave keyDown() routing alone.
	var/static/list/instant_open_channels = list(SAY_CHANNEL, RADIO_CHANNEL, OOC_CHANNEL, ME_CHANNEL, PRAY_CHANNEL)
	for(var/channel in instant_open_channels)
		var/list/bound_keys = D.key_bindings[channel]
		if(!bound_keys)
			continue
		for(var/key in bound_keys)
			if(length(D.key_bindings_by_key[key]) > 1)
				continue // Shared with another keybind, keep the normal routing so that one still fires.
			var/open_command = tgui_say_create_open_command(channel)
			winset(src, "default-[REF(key)]", "parent=default;name=[key];command=[open_command]")
