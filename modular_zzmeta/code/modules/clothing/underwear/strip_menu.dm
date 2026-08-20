/// Same "hidden while covered" rule as the HUD slots (human_underwear_hud.dm).
/datum/strippable_item/mob_item_slot/proc/covered_by_clothing(atom/source)
	if(!ishuman(source))
		return FALSE
	var/mob/living/carbon/human/human_source = source
	return (human_source.w_uniform || human_source.wear_suit)

/datum/strippable_item/mob_item_slot/underwear
	key = STRIPPABLE_ITEM_UNDERWEAR
	item_slot = ITEM_SLOT_UNDERWEAR

/datum/strippable_item/mob_item_slot/underwear/should_show(atom/source, mob/user)
	return ..() && !covered_by_clothing(source)

/datum/strippable_item/mob_item_slot/bra
	key = STRIPPABLE_ITEM_BRA
	item_slot = ITEM_SLOT_BRA

/datum/strippable_item/mob_item_slot/bra/should_show(atom/source, mob/user)
	return ..() && !covered_by_clothing(source)

/datum/strippable_item/mob_item_slot/undershirt
	key = STRIPPABLE_ITEM_UNDERSHIRT
	item_slot = ITEM_SLOT_UNDERSHIRT

/datum/strippable_item/mob_item_slot/undershirt/should_show(atom/source, mob/user)
	return ..() && !covered_by_clothing(source)

/datum/strippable_item/mob_item_slot/socks
	key = STRIPPABLE_ITEM_SOCKS
	item_slot = ITEM_SLOT_SOCKS

/datum/strippable_item/mob_item_slot/socks/should_show(atom/source, mob/user)
	return ..() && !covered_by_clothing(source)
