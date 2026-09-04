/// Whether this clothing design leaves the groin visible (skirts, dresses) rather
/// than concealing it.
/proc/is_groin_exposing_uniform(obj/item/clothing/under/uniform)
	return istype(uniform, /obj/item/clothing/under/dress) || istype(uniform, /obj/item/clothing/under/color/jumpskirt)

/// Whether the chest underwear categories (bra, undershirt) should stay hidden.
/proc/is_chest_covered(atom/source)
	if(!ishuman(source))
		return FALSE
	var/mob/living/carbon/human/human_source = source
	return !!(human_source.w_uniform || human_source.wear_suit)

/// Whether the underwear (groin) category should stay hidden.
/proc/is_groin_covered(atom/source)
	if(!ishuman(source))
		return FALSE
	var/mob/living/carbon/human/human_source = source
	if(human_source.wear_suit)
		return TRUE
	return human_source.w_uniform && !is_groin_exposing_uniform(human_source.w_uniform)

/// Whether the socks category should stay hidden.
/proc/is_feet_covered(atom/source)
	if(!ishuman(source))
		return FALSE
	var/mob/living/carbon/human/human_source = source
	return !!human_source.shoes
