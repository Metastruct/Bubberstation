// Imprint the player's saved tail (stored under FEATURE_TAIL_GENERIC) instead of always picking a random one.
/datum/bodypart_overlay/mutant/tail/fish/on_mob_insert(obj/item/organ/parent, mob/living/carbon/receiver)
	if(imprint_on_next_insertion && !receiver.dna.features[feature_key])
		var/list/saved_tail = receiver.dna.mutant_bodyparts[FEATURE_TAIL_GENERIC] || receiver.dna.species?.mutant_bodyparts[FEATURE_TAIL_GENERIC]
		receiver.dna.features[feature_key] = saved_tail?[MUTANT_INDEX_NAME] || pick(SSaccessories.feature_list[feature_key])
		receiver.dna.update_uf_block(/datum/dna_block/feature/accessory/tail_fish)

	return ..()
