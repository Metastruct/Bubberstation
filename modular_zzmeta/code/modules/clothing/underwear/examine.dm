/// Adds examine text for worn underwear items, matching the same "hidden while covered" rule
/// used by the strip menu and inventory HUD (see covered_by_clothing() in strip_menu.dm and
/// update_locked_slots() in human_underwear_hud.dm): visible only with no uniform or suit on.
/mob/living/carbon/human/examine_more(mob/user)
	. = ..()
	if(HAS_TRAIT(src, TRAIT_UNKNOWN_APPEARANCE) && !isobserver(user))
		return
	if(w_uniform || wear_suit)
		return

	var/t_He = p_They()
	var/t_is = p_are()

	if(w_underwear && !HAS_TRAIT(w_underwear, TRAIT_EXAMINE_SKIP))
		. += "[t_He] [t_is] wearing [w_underwear.examine_title_worn(user)]."
	if(w_bra && !HAS_TRAIT(w_bra, TRAIT_EXAMINE_SKIP))
		. += "[t_He] [t_is] wearing [w_bra.examine_title_worn(user)]."
	if(w_undershirt && !HAS_TRAIT(w_undershirt, TRAIT_EXAMINE_SKIP))
		. += "[t_He] [t_is] wearing [w_undershirt.examine_title_worn(user)]."
	if(w_socks && !HAS_TRAIT(w_socks, TRAIT_EXAMINE_SKIP))
		. += "[t_He] [t_is] wearing [w_socks.examine_title_worn(user)]."
