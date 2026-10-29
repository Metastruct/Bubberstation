/atom/movable/screen/map_view/char_preview
	/// Style name the dropdown is currently hovering, or null when not previewing.
	var/preview_tongue_style

/datum/preferences/render_new_preview_appearance(mob/living/carbon/human/dummy/mannequin)
	. = ..()
	var/style = character_preview_view?.preview_tongue_style
	if(isnull(style) || !istype(mannequin))
		return
	mannequin.dna.features[FEATURE_CUSTOM_TONGUE] = style
	var/obj/item/bodypart/head = mannequin.get_bodypart(BODY_ZONE_HEAD)
	if(head)
		var/datum/bodypart_overlay/simple/emote/tongue/existing = locate() in head.bodypart_overlays
		qdel(existing)
	mannequin.give_emote_overlay(/datum/bodypart_overlay/simple/emote/tongue)
	return mannequin.appearance

/datum/preference_middleware/tongue_preview
	action_delegations = list(
		"preview_custom_tongue" = PROC_REF(preview_custom_tongue),
	)

/datum/preference_middleware/tongue_preview/proc/preview_custom_tongue(list/params, mob/user)
	var/atom/movable/screen/map_view/char_preview/preview = preferences.character_preview_view
	if(isnull(preview))
		return FALSE
	var/style = params["style"]
	if(!isnull(style) && !(style in SSaccessories.sprite_accessories[FEATURE_CUSTOM_TONGUE]))
		return FALSE
	if(preview.preview_tongue_style == style)
		return FALSE
	preview.preview_tongue_style = style
	preview.update_body()
	return FALSE
