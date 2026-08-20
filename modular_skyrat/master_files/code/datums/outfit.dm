/datum/outfit
	/// Bitflag-based variable to store which parts of the uniform have been modified by the loadout, to avoid them being overriden again.
	var/modified_outfit_slots = NONE
	// META EDIT - CHANGE - START - UNDERWEAR_ITEMS
	// ORIGINAL: /// Underwear and bras are separated now
	// ORIGINAL: var/datum/sprite_accessory/clothing/bra/bra = null
	/// Underwear and bras are separated now. Real item now, not a cosmetic sprite_accessory.
	var/obj/item/clothing/underwear/bra/bra = null
	// META EDIT - CHANGE - END
