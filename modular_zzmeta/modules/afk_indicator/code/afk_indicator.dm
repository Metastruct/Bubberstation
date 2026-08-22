GLOBAL_VAR_INIT(afk_indicator_overlay, generate_afk_indicator_overlay())

/proc/generate_afk_indicator_overlay()
	var/mutable_appearance/overlay = mutable_appearance('modular_skyrat/modules/indicators/icons/ssd_indicator.dmi', "default0", FLY_LAYER)
	overlay.color = "#FFDD33"
	return overlay

/mob/living
	var/afk_indicator = FALSE

/mob/living/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_LIVING_LIFE, PROC_REF(evaluate_afk_indicator))
	RegisterSignal(src, COMSIG_MOB_LOGIN, PROC_REF(on_login_clear_afk))
	RegisterSignal(src, COMSIG_MOB_LOGOUT, PROC_REF(on_logout_clear_afk))

/mob/living/proc/set_afk_indicator(state)
	if(state == afk_indicator)
		return
	afk_indicator = state
	if(afk_indicator)
		add_overlay(GLOB.afk_indicator_overlay)
	else
		cut_overlay(GLOB.afk_indicator_overlay)

/mob/living/proc/on_login_clear_afk()
	SIGNAL_HANDLER
	set_afk_indicator(FALSE)

/mob/living/proc/on_logout_clear_afk()
	SIGNAL_HANDLER
	set_afk_indicator(FALSE)

/mob/living/proc/evaluate_afk_indicator()
	SIGNAL_HANDLER
	if(client == NULL) // don't bother with disconnected people shoudld already be handled
		return
	if(client.is_afk())
		set_afk_indicator(TRUE)
	else
		set_afk_indicator(FALSE)
