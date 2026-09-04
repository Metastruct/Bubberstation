/// Adds examine text for worn underwear items, matching the same per-category "hidden while
/// covered" rules used by the strip menu and inventory HUD, see visibility.dm.
/mob/living/carbon/human/get_clothing_examine_info(mob/living/user)
	. = ..()
	var/t_He = p_They()
	var/t_is = p_are()

	if(w_underwear && !is_groin_covered(src) && !HAS_TRAIT(w_underwear, TRAIT_EXAMINE_SKIP))
		. += "[t_He] [t_is] wearing [w_underwear.examine_title_worn(user)]."
	if(w_bra && !is_chest_covered(src) && !HAS_TRAIT(w_bra, TRAIT_EXAMINE_SKIP))
		. += "[t_He] [t_is] wearing [w_bra.examine_title_worn(user)]."
	if(w_undershirt && !is_chest_covered(src) && !HAS_TRAIT(w_undershirt, TRAIT_EXAMINE_SKIP))
		. += "[t_He] [t_is] wearing [w_undershirt.examine_title_worn(user)]."
	if(w_socks && !is_feet_covered(src) && !HAS_TRAIT(w_socks, TRAIT_EXAMINE_SKIP))
		. += "[t_He] [t_is] wearing [w_socks.examine_title_worn(user)]."
