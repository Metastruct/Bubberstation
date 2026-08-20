/// Grants the mammal "shake off liquid coating" ability, see modular_zzmeta/code/modules/mob/living/carbon/human/mammal_shake.dm and the wet_dog quirk that grants it.
#define TRAIT_WET_DOG_SHAKE "wet_dog_shake"

/// examine_limb_id values that count as furry enough for the wet dog shake-off (see is_mammal_species() in mammal_shake.dm and the wet_dog quirk's is_species_appropriate()). Lycan is its own limb_id distinct from SPECIES_MAMMAL, so it needs to be listed explicitly.
#define WET_DOG_SHAKE_LIMB_IDS list(SPECIES_MAMMAL, SPECIES_LYCAN, SPECIES_CURSEKIN)
