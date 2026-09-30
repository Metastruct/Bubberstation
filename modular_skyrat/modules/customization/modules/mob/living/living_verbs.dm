GLOBAL_VAR_INIT(temporary_flavor_text_indicator, generate_temporary_flavor_text_indicator())

/proc/generate_temporary_flavor_text_indicator()
	var/mutable_appearance/temporary_flavor_text_indicator = mutable_appearance('modular_skyrat/modules/indicators/icons/temporary_flavor_text_indicator.dmi', "flavor", FLY_LAYER)
	temporary_flavor_text_indicator.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA | KEEP_APART
	return temporary_flavor_text_indicator

GAME_VERB_DESC(/mob/living, set_temporary_flavor, "Set Temporary Flavor Text", "Allows you to set a temporary flavor text.", "IC")
	if(IS_UNCONSCIOUS_OR_CRIT(src))
		to_chat(src, span_warning("You can't set your temporary flavor text now..."))
		return

	var/msg = tgui_input_text(src, "Set the temporary flavor text in your 'examine' verb. This is for describing what people can tell by looking at your character.", "Temporary Flavor Text", temporary_flavor_text, max_length = MAX_FLAVOR_LEN, multiline = TRUE)
	if(msg == null)
		return

	// Turn empty input into no flavor text
	var/result = msg || null
	temporary_flavor_text = result
	// META EDIT - ADDITION - START - TEMP_FLAVOR_CLEAR_ON_MOVE
	UnregisterSignal(src, COMSIG_MOVABLE_MOVED)
	if(result && tgui_alert(src, "Automatically clear this flavor text after you move one tile?", "Temporary Flavor Text", list("Yes", "No")) == "Yes")
		RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(clear_temporary_flavor_on_move))
	// META EDIT - ADDITION - END - TEMP_FLAVOR_CLEAR_ON_MOVE
	update_appearance(UPDATE_ICON|UPDATE_OVERLAYS)

/// META EDIT - ADDITION - TEMP_FLAVOR_CLEAR_ON_MOVE
/mob/living/proc/clear_temporary_flavor_on_move(atom/movable/mover, atom/old_loc, direction, forced, list/old_locs, momentum_change)
	SIGNAL_HANDLER
	UnregisterSignal(src, COMSIG_MOVABLE_MOVED)
	temporary_flavor_text = null
	update_appearance(UPDATE_ICON|UPDATE_OVERLAYS)
	to_chat(src, span_notice("Your temporary flavor text fades away as you move."))

/mob/living/update_overlays()
	. = ..()
	if (temporary_flavor_text)
		. += GLOB.temporary_flavor_text_indicator
