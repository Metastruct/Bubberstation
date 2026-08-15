/datum/quirk/wet_dog
	name = "Wet Dog"
	desc = "Something in your instincts knows exactly how to shake water and other liquids off your fur. Click the alert that appears when you're covered in liquid to shake it off, dumping it on the floor (and anyone standing too close)."
	icon = FA_ICON_DOG
	value = 6
	hardcore_value = 0
	mob_trait = TRAIT_WET_DOG_SHAKE
	gain_text = span_notice("You feel a primal urge to shake yourself dry whenever you're wet.")
	lose_text = span_danger("The urge to shake yourself dry fades.")
	medical_record_text = "Patient exhibits an unusually strong shake-dry reflex."

/datum/quirk/wet_dog/is_species_appropriate(datum/species/mob_species)
	// mob_species is often a raw type path here (not an instance, see preferences.dm's validate_quirks()),
	// so examine_limb_id must be read with initial() rather than direct access, and falls back to id the
	// same way /datum/species/New() does at runtime for species that never set examine_limb_id explicitly.
	var/limb_id = initial(mob_species.examine_limb_id) || initial(mob_species.id)
	if(limb_id != SPECIES_MAMMAL)
		return FALSE
	return ..()
