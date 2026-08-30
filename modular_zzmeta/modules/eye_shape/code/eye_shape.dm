/// Eye Shape

/datum/preference/choiced/mutant_choice/eye_shape
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_key = "feature_eye_shape"
	main_feature_name = "Eye Shape"
	relevant_mutant_bodypart = "eye_shape"
	default_accessory_type = /datum/sprite_accessory/eyes/none

/datum/preference/choiced/mutant_choice/eye_shape/is_part_enabled(datum/preferences/preferences)
	return TRUE

/datum/sprite_accessory/eyes
	key = "eye_shape"
	color_src = null

/datum/sprite_accessory/eyes/none
	name = SPRITE_ACCESSORY_NONE
	organ_type = /obj/item/organ/eyes

/datum/sprite_accessory/eyes/snail
	name = "Snail"
	organ_type = /obj/item/organ/eyes/snail

/datum/sprite_accessory/eyes/jelly
	name = "Jelly"
	organ_type = /obj/item/organ/eyes/jelly

/datum/sprite_accessory/eyes/lizard
	name = "Reptile"
	organ_type = /obj/item/organ/eyes/lizard

/datum/sprite_accessory/eyes/felinid
	name = "Feline"
	organ_type = /obj/item/organ/eyes/felinid

/datum/sprite_accessory/eyes/moth
	name = "Moth"
	organ_type = /obj/item/organ/eyes/moth/cosmetic
