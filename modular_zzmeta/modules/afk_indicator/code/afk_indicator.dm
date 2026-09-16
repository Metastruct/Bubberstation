/mob/living
	var/afk_indicator = FALSE

/mob/living/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_LIVING_LIFE, PROC_REF(evaluate_afk_indicator))
	RegisterSignal(src, COMSIG_MOB_LOGIN, PROC_REF(on_login_clear_afk))
	RegisterSignal(src, COMSIG_MOB_LOGOUT, PROC_REF(on_logout_clear_afk))

/// Builds the AFK indicator overlay tinted with this mob's own chat name color (see modular_zzmeta/modules/chat_colors), instead of a fixed color.
/mob/living/proc/generate_afk_indicator_overlay()
	var/mutable_appearance/overlay = mutable_appearance('modular_skyrat/modules/indicators/icons/ssd_indicator.dmi', "default0", FLY_LAYER)
	var/list/rgb = rgb2num(get_chat_name_color())
	var/red = rgb[1] / 255
	var/green = rgb[2] / 255
	var/blue = rgb[3] / 255
	overlay.color = list(0,0,0,0,	red,green,blue,0, 0,0,0,0, 0,0,0,1, 0,0,0,0)
	return overlay

/mob/living/update_overlays()
	. = ..()
	if(afk_indicator)
		. += generate_afk_indicator_overlay()

/mob/living/proc/set_afk_indicator(state)
	if(state == afk_indicator)
		return
	afk_indicator = state
	update_appearance(UPDATE_OVERLAYS)

/mob/living/proc/on_login_clear_afk()
	SIGNAL_HANDLER
	set_afk_indicator(FALSE)

/mob/living/proc/on_logout_clear_afk()
	SIGNAL_HANDLER
	set_afk_indicator(FALSE)

/mob/living/proc/evaluate_afk_indicator()
	SIGNAL_HANDLER
	if(client == null) // don't bother with disconnected people shoudld already be handled
		return
	if(client.is_afk())
		set_afk_indicator(TRUE)
	else
		set_afk_indicator(FALSE)
