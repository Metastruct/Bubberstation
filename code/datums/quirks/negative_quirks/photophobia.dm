#define MOOD_CATEGORY_PHOTOPHOBIA "photophobia"

/datum/quirk/photophobia
	name = "Photophobia"
	desc = "Bright lights seem to bother you more than others. Maybe it's a medical condition."
	icon = FA_ICON_ARROWS_TO_EYE
	value = -4
	gain_text = span_danger("The safety of light feels off...")
	lose_text = span_notice("Enlightening.")
	medical_record_text = "Patient has acute phobia of light, and insists it is physically harmful."
	medical_symptom_text = "Exhibits heightened sensitivity to bright lights, leading to discomfort and avoidance behaviors."
	hardcore_value = 4
	quirk_flags = QUIRK_HUMAN_ONLY|QUIRK_TRAUMALIKE
	mail_goodies = list(
		/obj/item/flashlight/flashdark,
		/obj/item/food/grown/mushroom/glowshroom/shadowshroom,
		/obj/item/skillchip/light_remover,
	)

/datum/quirk/photophobia/add(client/client_source)
	RegisterSignal(quirk_holder, COMSIG_CARBON_GAIN_ORGAN, PROC_REF(check_eyes))
	RegisterSignal(quirk_holder, COMSIG_CARBON_LOSE_ORGAN, PROC_REF(restore_eyes))
	RegisterSignal(quirk_holder, COMSIG_MOVABLE_MOVED, PROC_REF(on_holder_moved))
	// META EDIT - ADDITION - START - PHOTOPHOBIA_DISGUISE
	RegisterSignal(quirk_holder, SIGNAL_ADDTRAIT(TRAIT_UNKNOWN_APPEARANCE), PROC_REF(on_appearance_hidden))
	RegisterSignal(quirk_holder, COMSIG_CARBON_ITEM_COVERAGE_CHANGED, PROC_REF(on_appearance_hidden))
	RegisterSignals(quirk_holder, list(COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM), PROC_REF(on_gear_changed))
	// META EDIT - ADDITION - END - PHOTOPHOBIA_DISGUISE
	update_eyes(quirk_holder.get_organ_slot(ORGAN_SLOT_EYES))

/datum/quirk/photophobia/remove()
	// META EDIT - CHANGE - START - PHOTOPHOBIA_DISGUISE
	UnregisterSignal(quirk_holder, list(
		COMSIG_CARBON_GAIN_ORGAN,
		COMSIG_CARBON_LOSE_ORGAN,
		COMSIG_MOVABLE_MOVED,
		SIGNAL_ADDTRAIT(TRAIT_UNKNOWN_APPEARANCE),
		COMSIG_CARBON_ITEM_COVERAGE_CHANGED,
		COMSIG_MOB_EQUIPPED_ITEM,
		COMSIG_MOB_UNEQUIPPED_ITEM,))
	// META EDIT - CHANGE - END - PHOTOPHOBIA_DISGUISE
	quirk_holder.clear_mood_event(MOOD_CATEGORY_PHOTOPHOBIA)
	var/obj/item/organ/eyes/normal_eyes = quirk_holder.get_organ_slot(ORGAN_SLOT_EYES)
	if(istype(normal_eyes))
		normal_eyes.flash_protect = initial(normal_eyes.flash_protect)

/datum/quirk/photophobia/proc/check_eyes(datum/source, obj/item/organ/eyes/sensitive_eyes)
	SIGNAL_HANDLER
	if(!istype(sensitive_eyes))
		return
	update_eyes(sensitive_eyes)

/datum/quirk/photophobia/proc/update_eyes(obj/item/organ/eyes/target_eyes)
	if(!istype(target_eyes))
		return
	target_eyes.flash_protect = max(target_eyes.flash_protect - 1, FLASH_PROTECTION_HYPER_SENSITIVE)

/datum/quirk/photophobia/proc/restore_eyes(datum/source, obj/item/organ/eyes/normal_eyes)
	SIGNAL_HANDLER
	if(!istype(normal_eyes))
		return
	normal_eyes.flash_protect = initial(normal_eyes.flash_protect)

/datum/quirk/photophobia/proc/on_holder_moved(mob/living/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER

	if(IS_UNCONSCIOUS(quirk_holder) || HAS_TRAIT(quirk_holder, TRAIT_FEARLESS))
		return

	var/mob/living/carbon/human/human_holder = quirk_holder

	// META EDIT - ADDITION - START - PHOTOPHOBIA_DISGUISE
	if(human_holder.is_face_obscured())
		return
	// META EDIT - ADDITION - END - PHOTOPHOBIA_DISGUISE

	if(human_holder.sight & SEE_TURFS)
		return

	var/turf/holder_turf = get_turf(quirk_holder)
	var/eye_protection = quirk_holder.get_eye_protection()
	if(holder_turf.check_lumcount_below(LIGHTING_TILE_IS_DARK) || eye_protection >= FLASH_PROTECTION_NONE)
		quirk_holder.clear_mood_event(MOOD_CATEGORY_PHOTOPHOBIA)
		return
	quirk_holder.add_mood_event(MOOD_CATEGORY_PHOTOPHOBIA, /datum/mood_event/photophobia)

// META EDIT - ADDITION - START - PHOTOPHOBIA_DISGUISE
/// Called when the holder's appearance is hidden (unknown appearance or an obscured face).
/datum/quirk/photophobia/proc/on_appearance_hidden(datum/source, added_slots, removed_slots)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/human_holder = quirk_holder
	if(!istype(human_holder) || !human_holder.is_face_obscured())
		return
	quirk_holder.clear_mood_event(MOOD_CATEGORY_PHOTOPHOBIA)

/// Called when gear is equipped/unequipped; re-runs the movement check so eye protection is re-evaluated immediately.
/datum/quirk/photophobia/proc/on_gear_changed(datum/source)
	SIGNAL_HANDLER
	on_holder_moved(quirk_holder, null, 0, 0)
// META EDIT - ADDITION - END - PHOTOPHOBIA_DISGUISE

	#undef MOOD_CATEGORY_PHOTOPHOBIA
