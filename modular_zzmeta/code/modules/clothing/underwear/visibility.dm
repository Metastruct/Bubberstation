/// Whether this clothing design leaves the groin visible (skirts, dresses) rather
/// than concealing it.
/proc/is_groin_exposing_uniform(obj/item/clothing/under/uniform)
	if(istype(uniform, /obj/item/clothing/under/dress))
		return TRUE
	return !!findtext("[uniform.type]", "skirt")

/// Whether the chest underwear categories (bra, undershirt) should stay hidden.
/proc/is_chest_covered(atom/source)
	if(!ishuman(source))
		return FALSE
	var/mob/living/carbon/human/human_source = source
	return !human_source.is_topless()

/// Whether the underwear (groin) category should stay hidden.
/proc/is_groin_covered(atom/source)
	if(!ishuman(source))
		return FALSE
	var/mob/living/carbon/human/human_source = source
	return !human_source.is_bottomless()

/// Whether the socks category should stay hidden.
/proc/is_feet_covered(atom/source)
	if(!ishuman(source))
		return FALSE
	var/mob/living/carbon/human/human_source = source
	return !human_source.is_barefoot()
