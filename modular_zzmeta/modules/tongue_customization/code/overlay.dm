/datum/bodypart_overlay/simple/emote/tongue
	icon = 'modular_zzmeta/modules/tongue_customization/icons/tongue.dmi'
	icon_state = "default"
	draw_color = COLOR_TONGUE_PINK
	// BODY_ADJ_LAYER is under uniforms; FRONT sits with snouts/ears, above clothes.
	layers = list(EXTERNAL_FRONT = BODY_FRONT_LAYER)
	/// Accessory currently applied, if any.
	var/datum/sprite_accessory/custom_tongue/tongue_accessory

/datum/bodypart_overlay/simple/emote/tongue/added_to_limb(obj/item/bodypart/limb)
	. = ..()
	apply_tongue_appearance(limb)

/datum/bodypart_overlay/simple/emote/tongue/icon_render_key(obj/item/bodypart/limb)
	apply_tongue_appearance(limb)
	. = ..()
	. += "[icon]"
	if(islist(draw_color))
		. += jointext(draw_color, "")
	else
		. += "[draw_color]"

/datum/bodypart_overlay/simple/emote/tongue/color_image(image/overlay, obj/item/bodypart/limb, layer_index)
	if(islist(draw_color))
		overlay.color = length(draw_color) ? draw_color[1] : COLOR_TONGUE_PINK
		return
	overlay.color = draw_color

/datum/bodypart_overlay/simple/emote/tongue/get_all_overlays(obj/item/bodypart/limb)
	apply_tongue_appearance(limb)
	if(isnull(tongue_accessory) || tongue_accessory.color_src != USE_MATRIXED_COLORS || !length(tongue_accessory.color_layer_names))
		return ..()

	var/list/overlays = list()
	var/list/colors = islist(draw_color) ? draw_color : list(draw_color || COLOR_TONGUE_PINK)
	var/saved_state = icon_state
	var/saved_color = draw_color
	for(var/index_key in tongue_accessory.color_layer_names)
		var/suffix = tongue_accessory.color_layer_names[index_key]
		icon_state = "[saved_state]_[suffix]"
		var/color_index = text2num(index_key)
		draw_color = colors[clamp(color_index, 1, length(colors))]
		for(var/overlay_postfix, overlay_layer in layers)
			overlays += get_overlay(limb, overlay_postfix, -overlay_layer)
	icon_state = saved_state
	draw_color = saved_color
	return overlays

/datum/bodypart_overlay/simple/emote/tongue/proc/apply_tongue_appearance(obj/item/bodypart/limb)
	var/mob/living/carbon/human/owner = limb?.owner
	tongue_accessory = null
	if(!istype(owner))
		return

	var/style_name = owner.dna?.features?[FEATURE_CUSTOM_TONGUE]
	var/datum/sprite_accessory/custom_tongue/accessory = SSaccessories.sprite_accessories[FEATURE_CUSTOM_TONGUE]?[style_name]
	if(istype(accessory))
		tongue_accessory = accessory
		icon = accessory.icon
		icon_state = accessory.icon_state

	var/list/colors = owner.dna?.features?[FEATURE_CUSTOM_TONGUE_COLOR]
	if(islist(colors) && length(colors))
		draw_color = colors.Copy()
	else if(istext(colors) && length(colors))
		draw_color = colors
	else
		draw_color = COLOR_TONGUE_PINK
