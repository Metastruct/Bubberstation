/// Any species can now pick a cosmetic eye shape via the "Eye Shape" preference
/// (Allow Mismatched Parts). Species whose native eyes carry real mechanics
/// (night vision, flash resistance/vulnerability, phasing, EMP damage, spells,
/// etc.) need overrides_sprite_datum_organ_type = TRUE so their real eyes always
/// win over a cosmetic pick, the same way Teshari ears protect their 4-ear setup.
/// Species whose eyes are purely cosmetic already (teshari, vox, vox_primalis,
/// akula, skrell) are intentionally left out here; there's nothing to protect.

/obj/item/organ/eyes/golem
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/ghost
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/night_vision/mushroom
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/zombie
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/dullahan
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/shadow
	overrides_sprite_datum_organ_type = TRUE

// Covers android and the modular_zubbers protean subtype too, via inheritance.
/obj/item/organ/eyes/robotic
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/fly
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/synth
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/serpentid
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/night_vision/ashwalker
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/shadekin
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/vulpkanin
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/lycan
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/tajaran
	overrides_sprite_datum_organ_type = TRUE

/obj/item/organ/eyes/low_light_adapted
	overrides_sprite_datum_organ_type = TRUE
