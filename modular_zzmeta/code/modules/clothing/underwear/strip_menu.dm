/// Per-category "hidden while covered" rules, shared with the HUD slots (human_underwear_hud.dm)
/// and examine text (examine.dm) — see visibility.dm.
/datum/strippable_item/mob_item_slot/underwear
	key = STRIPPABLE_ITEM_UNDERWEAR
	item_slot = ITEM_SLOT_UNDERWEAR

/datum/strippable_item/mob_item_slot/underwear/should_show(atom/source, mob/user)
	return ..() && !is_groin_covered(source)

/datum/strippable_item/mob_item_slot/bra
	key = STRIPPABLE_ITEM_BRA
	item_slot = ITEM_SLOT_BRA

/datum/strippable_item/mob_item_slot/bra/should_show(atom/source, mob/user)
	return ..() && !is_chest_covered(source)

/datum/strippable_item/mob_item_slot/undershirt
	key = STRIPPABLE_ITEM_UNDERSHIRT
	item_slot = ITEM_SLOT_UNDERSHIRT

/datum/strippable_item/mob_item_slot/undershirt/should_show(atom/source, mob/user)
	return ..() && !is_chest_covered(source)

/datum/strippable_item/mob_item_slot/socks
	key = STRIPPABLE_ITEM_SOCKS
	item_slot = ITEM_SLOT_SOCKS

/datum/strippable_item/mob_item_slot/socks/should_show(atom/source, mob/user)
	return ..() && !is_feet_covered(source)
