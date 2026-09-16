// META EDIT - REMOVAL - START - UNDERWEAR_ITEMS
// get_underwear_overlays() removed. Underwear, bra, undershirt, and socks are now real equipped
// items rendered via modular_zzmeta/code/modules/mob/living/carbon/human/human_underwear_icons.dm.
// META EDIT - REMOVAL - END - UNDERWEAR_ITEMS

// Refresh bodypart overlays (genitals etc.) when suit/uniform changes so visibility updates immediately.
/mob/living/carbon/human/update_worn_oversuit()
	..()
	if(!(living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS))
		update_body_parts()

/mob/living/carbon/human/update_worn_undersuit()
	..()
	if(!(living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS))
		update_body_parts()
