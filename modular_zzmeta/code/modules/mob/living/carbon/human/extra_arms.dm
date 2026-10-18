/mob/living/carbon/human
	/// Optional abstract chest arms granted by the "Extra Arms" preference (non-moth species only).
	var/list/extra_arms

/**
 * Enables or disables the optional extra chest arms.
 *
 * Mothpeople are handled entirely by their chest bodypart, so for them this just
 * clears any stale state so we never fight over the same hands/overlay.
 */
/mob/living/carbon/human/proc/set_extra_arms(enabled)
	if(istype(dna?.species, /datum/species/moth))
		extra_arms = null
		return
	if(enabled)
		give_extra_arms()
	else
		remove_extra_arms()

/// Attaches the optional extra arms to our current chest, if we don't already have them.
/mob/living/carbon/human/proc/give_extra_arms()
	if(isnull(dna))
		return
	// Clear refs left dangling by a species change (replace_body() qdels them).
	if(length(extra_arms) >= 2 && !QDELETED(extra_arms[1]) && !QDELETED(extra_arms[2]))
		return
	extra_arms = null

	var/obj/item/bodypart/chest/chest = get_bodypart(BODY_ZONE_CHEST)
	if(isnull(chest))
		return

	change_number_of_hands(4)

	var/obj/item/bodypart/arm/left/moth/inner/left_arm = new(chest)
	var/obj/item/bodypart/arm/right/moth/inner/right_arm = new(chest)
	left_arm.try_attach_limb(src, special = TRUE)
	right_arm.try_attach_limb(src, special = TRUE)
	extra_arms = list(left_arm, right_arm)

	chest.add_bodypart_overlay(new /datum/bodypart_overlay/simple/moth_arms())
	update_body()

/// Removes the optional extra arms and their chest overlay.
/mob/living/carbon/human/proc/remove_extra_arms()
	if(istype(dna?.species, /datum/species/moth))
		extra_arms = null
		return
	if(!length(extra_arms))
		return

	for(var/obj/item/bodypart/arm/extra_arm in extra_arms)
		if(QDELETED(extra_arm))
			continue
		extra_arm.drop_limb(special = TRUE, dismembered = FALSE, move_to_floor = FALSE)
	extra_arms = null

	change_number_of_hands(2)

	var/obj/item/bodypart/chest/chest = get_bodypart(BODY_ZONE_CHEST)
	chest?.remove_bodypart_overlay(/datum/bodypart_overlay/simple/moth_arms)
	update_body()

/// Re-evaluate the optional extra arms after a species change, since replace_body()
/// deletes our (zone-less) arms along with everything else.
/mob/living/carbon/human/set_species(datum/species/mrace, icon_update = TRUE, pref_load = FALSE, replace_missing = TRUE, list/override_features, list/override_mutantparts, list/override_markings)
	. = ..()

	var/datum/preferences/prefs = client?.prefs
	if(isnull(prefs))
		extra_arms = null
		return

	var/enabled = prefs.read_preference(/datum/preference/toggle/extra_arms) \
		&& prefs.read_preference(/datum/preference/toggle/allow_mismatched_parts)
	set_extra_arms(enabled)
