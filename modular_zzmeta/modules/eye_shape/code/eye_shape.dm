/// Eye Shape

/datum/preference/toggle/mutant_toggle/eye_shape
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_key = "eye_shape_toggle"
	relevant_mutant_bodypart = "eye_shape"

/datum/preference/choiced/mutant_choice/eye_shape
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_key = "feature_eye_shape"
	main_feature_name = "Eye Shape"
	relevant_mutant_bodypart = "eye_shape"
	type_to_check = /datum/preference/toggle/mutant_toggle/eye_shape
	default_accessory_type = /datum/sprite_accessory/eyes/none

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

/datum/sprite_accessory/eyes/teshari
	name = "Teshari"
	organ_type = /obj/item/organ/eyes/teshari

/datum/sprite_accessory/eyes/vox
	name = "Vox"
	organ_type = /obj/item/organ/eyes/vox

/datum/sprite_accessory/eyes/vox_primalis
	name = "Vox Primalis"
	organ_type = /obj/item/organ/eyes/vox_primalis

/datum/sprite_accessory/eyes/akula
	name = "Akula"
	organ_type = /obj/item/organ/eyes/akula

/datum/sprite_accessory/eyes/shadekin
	name = "Shadekin"
	organ_type = /obj/item/organ/eyes/shadekin/cosmetic

/datum/sprite_accessory/eyes/skrell
	name = "Skrell"
	organ_type = /obj/item/organ/eyes/skrell

/datum/sprite_accessory/eyes/insect
	name = "Insect"
	organ_type = /obj/item/organ/eyes/insect
