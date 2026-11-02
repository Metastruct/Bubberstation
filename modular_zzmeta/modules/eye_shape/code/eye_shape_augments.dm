/// Eye shapes offered in the Markings/Organs tab's "Eyes" dropdown.
///
/// These used to be a separate, purely-cosmetic "Eye Shape" preference that
/// fought the organ augmentation system over the eye organ slot. They are now
/// just regular eye-organ choices in the same dropdown, so there is a single
/// source of truth: pick an eye, get that eye.
///
/// Species whose real eyes carry mechanics (shadekin night vision, moth flash
/// sensitivity, ...) are therefore no longer protected from being replaced -
/// picking an eye is an explicit choice, and the chosen organ is what you get.

/datum/augment_item/organ/eyes/shape
	allowed_biotypes = MOB_ORGANIC|MOB_ROBOTIC

/datum/augment_item/organ/eyes/shape/snail
	name = "Snail Eyes"
	path = /obj/item/organ/eyes/snail

/datum/augment_item/organ/eyes/shape/jelly
	name = "Jelly Eyes"
	path = /obj/item/organ/eyes/jelly

/datum/augment_item/organ/eyes/shape/reptile
	name = "Reptile Eyes"
	path = /obj/item/organ/eyes/lizard

/datum/augment_item/organ/eyes/shape/feline
	name = "Feline Eyes"
	path = /obj/item/organ/eyes/felinid

/datum/augment_item/organ/eyes/shape/teshari
	name = "Teshari Eyes"
	path = /obj/item/organ/eyes/teshari

/datum/augment_item/organ/eyes/shape/vox
	name = "Vox Eyes"
	path = /obj/item/organ/eyes/vox

/datum/augment_item/organ/eyes/shape/vox_primalis
	name = "Vox Primalis Eyes"
	path = /obj/item/organ/eyes/vox_primalis

/datum/augment_item/organ/eyes/shape/akula
	name = "Akula Eyes"
	path = /obj/item/organ/eyes/akula

/datum/augment_item/organ/eyes/shape/skrell
	name = "Skrell Eyes"
	path = /obj/item/organ/eyes/skrell

// Night vision, so it isn't free like the purely-visual shapes above.
/datum/augment_item/organ/eyes/shape/shadekin
	name = "Shadekin Eyes"
	path = /obj/item/organ/eyes/shadekin
	cost = 1

/datum/augment_item/organ/eyes/shape/insect
	name = "Insect Eyes"
	path = /obj/item/organ/eyes/insect
