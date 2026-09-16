//Plushie of Daoma, by Dottrina
/obj/item/toy/plush/daoma
	name = "pink alien plush"
	desc = "An otherworldly yet familiar plushie. There is a tag on it with indecipherable writing."
	icon = 'modular_zubbers/icons/obj/toys/plushes.dmi'
	icon_state = "daoma_plush"
	gender = FEMALE
	attack_verb_continuous = list("bullies", "slams", "attacks", "slaps")
	attack_verb_simple = list("bully", "slam", "attack", "slap")

//Plushie of Sansiri, by Danielone
/obj/item/toy/plush/sansiri
	name = "purple bird plush"
	desc = "A delicate plushie whose softness is second to none. It looks ready to go to hell and back with you."
	icon = 'modular_zubbers/icons/obj/toys/plushes.dmi'
	icon_state = "sansiri_plush"
	gender = FEMALE
	attack_verb_continuous = list("crushes", "cleaves", "smashes", "chops", "pulps", "attacks") // crusher attack verbs
	attack_verb_simple = list("crush", "cleave", "smash", "chop", "pulp", "attack")
	squeak_override = list('sound/items/weapons/thudswoosh.ogg'=1) // hug sound

//Plushie of Tenn
/obj/item/toy/plush/tenn
	name = "gray elephant plush"
	desc = "Pour milk on it and slam it against the wall! Not actually an elephant."
	icon = 'modular_zubbers/icons/obj/toys/plushes.dmi'
	icon_state = "tenn"
	gender = MALE
