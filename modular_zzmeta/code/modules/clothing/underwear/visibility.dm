/// Whether this clothing design leaves the groin visible (skirts, dresses) rather
/// than concealing it.
/proc/is_groin_exposing_uniform(obj/item/clothing/under/uniform)
	if(istype(uniform, /obj/item/clothing/under/dress))
		return TRUE
	return !!findtext("[uniform.type]", "skirt")

/// Whether a body zone is covered or not
/mob/living/carbon/human/proc/is_body_zone_covered(zone, include_underwear = TRUE)
	var/list/covering_slots = list(w_uniform, wear_suit, shoes)
	if(include_underwear)
		covering_slots += w_underwear
		covering_slots += w_bra
		covering_slots += w_undershirt
		covering_slots += w_socks
	for(var/obj/item/garment as anything in covering_slots)
		if(isnull(garment))
			continue
		if(zone == GROIN && garment == w_uniform && is_groin_exposing_uniform(garment))
			continue
		if(garment.body_parts_covered & zone)
			return TRUE
	if(istype(wear_suit, /obj/item/clothing/suit/toggle/labcoat/hospitalgown))
		return TRUE
	return FALSE

/// Whether the chest underwear categories (bra, undershirt) should stay hidden by OUTER clothing.
/proc/is_chest_covered(atom/source)
	if(!ishuman(source))
		return FALSE
	var/mob/living/carbon/human/human_source = source
	return human_source.is_body_zone_covered(CHEST, include_underwear = FALSE)

/// Whether the underwear (groin) category should stay hidden by OUTER clothing.
/proc/is_groin_covered(atom/source)
	if(!ishuman(source))
		return FALSE
	var/mob/living/carbon/human/human_source = source
	return human_source.is_body_zone_covered(GROIN, include_underwear = FALSE)

/// Whether the socks category should stay hidden by OUTER clothing.
/proc/is_feet_covered(atom/source)
	if(!ishuman(source))
		return FALSE
	var/mob/living/carbon/human/human_source = source
	return human_source.is_body_zone_covered(FEET, include_underwear = FALSE)
