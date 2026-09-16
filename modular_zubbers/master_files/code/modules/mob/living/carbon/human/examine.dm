// Species examine
/mob/living/carbon/human/examine_title(mob/user, thats = FALSE)
	. = ..()
	var/skipface = covered_slots & HIDEFACE
	var/species_visible
	var/species_name_string
	// META EDIT - CHANGE - START - EXAMINE_TITLE_UNKNOWN_APPEARANCE
	// get_visible_name() doesn't return "Unknown" for disguises that force a custom name (e.g. the potted plant tactical component), so also check the traits directly
	if(skipface || HAS_TRAIT(src, TRAIT_UNKNOWN_APPEARANCE) || HAS_TRAIT(src, TRAIT_INVISIBLE_MAN) || get_visible_name() == "Unknown")
		// META EDIT - CHANGE - END
		species_visible = FALSE
	else
		species_visible = TRUE

	if(!species_visible)
		species_name_string = ""
	else if (!dna.species.lore_protected && dna.features["custom_species"] && dna.features["custom_species"] != "")
		species_name_string = ", [prefix_a_or_an(dna.features["custom_species"])] <EM>[dna.features["custom_species"]] [isobserver(user) ? "([dna.species.name])" : ""]</EM>"
	else
		species_name_string = ", [prefix_a_or_an(dna.species.name)] <EM>[dna.species.name]</EM>"

	. += species_name_string
