// Generalizes /datum/component/splat (pie, ink sac, canned squid ink, ink-spit projectiles) to
// snapshot the source's reagents onto the floor smudge and face residue, so lick/smell reads
// something real instead of "tastes like nothing". Full proc overrides of the originals in
// code/datums/components/splat.dm and code/datums/components/face_decal.dm.

/datum/component/face_decal/splat
	/// Non-destructive snapshot of the reagents that caused this splat (e.g. pie filling), read by lick/smell. Owned by this component.
	var/datum/reagents/tasted_reagents

/datum/component/face_decal/splat/Initialize(icon_state, layers, color, memory_type = /datum/memory/witnessed_creampie, mood_event_type = /datum/mood_event/creampie, datum/reagents/tasted_reagents)
	if(!is_type_in_typecache(parent, GLOB.splattable))
		return COMPONENT_INCOMPATIBLE

	. = ..()

	SEND_SIGNAL(parent, COMSIG_MOB_HIT_BY_SPLAT, src)
	add_memory_in_range(parent, 7, memory_type, protagonist = parent)
	src.mood_event_type = mood_event_type
	src.tasted_reagents = tasted_reagents

/datum/component/face_decal/splat/Destroy(force)
	QDEL_NULL(tasted_reagents)
	return ..()

/datum/component/splat/splat(atom/movable/source, atom/hit_atom)
	var/datum/reagents/copied_reagents
	if(source?.reagents?.total_volume)
		copied_reagents = new /datum/reagents(source.reagents.total_volume)
		source.reagents.trans_to(copied_reagents, source.reagents.total_volume, copy_only = TRUE)

	var/turf/hit_turf = get_turf(hit_atom)
	var/obj/effect/decal/cleanable/smudge = new smudge_type(hit_turf)
	if(copied_reagents && !QDELETED(smudge))
		smudge.create_reagents(copied_reagents.total_volume)
		copied_reagents.trans_to(smudge, copied_reagents.total_volume, copy_only = TRUE)

	var/can_splat_on = TRUE
	if(isliving(hit_atom))
		var/mob/living/living_target_getting_hit = hit_atom
		if(iscarbon(living_target_getting_hit))
			can_splat_on = !!(living_target_getting_hit.get_bodypart(BODY_ZONE_HEAD))
		hit_callback?.Invoke(living_target_getting_hit, can_splat_on)
	if(can_splat_on && is_type_in_typecache(hit_atom, GLOB.splattable))
		hit_atom.AddComponent(/datum/component/face_decal/splat, icon_state, layer, splat_color || source.color, memory_type, moodlet_type, copied_reagents)
	else
		QDEL_NULL(copied_reagents)
	SEND_SIGNAL(source, COMSIG_MOVABLE_SPLAT, hit_atom)
	if(!isprojectile(source))
		qdel(source)
