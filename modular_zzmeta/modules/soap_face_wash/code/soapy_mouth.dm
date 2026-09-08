#define SOAPY_MOUTH_DEFAULT_DURATION 45 SECONDS

/datum/status_effect/soapy_mouth
	id = "soapy_mouth"
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null
	remove_on_fullheal = TRUE
	var/static/regex/swear_regex = regex(@"\b(fuck(?:ing|er|ed|s)?|shit(?:ty|ted|s)?|bitch(?:es|y)?|assh[o0]le\w*|bastard\w*|damn(?:it)?|goddamn\w*|cunt\w*|dick(?:head)?s?|piss(?:ed|es)?|crap\w*)\b", "gi")

/datum/status_effect/soapy_mouth/on_creation(mob/living/new_owner, duration = SOAPY_MOUTH_DEFAULT_DURATION)
	src.duration = duration
	return ..()

/datum/status_effect/soapy_mouth/on_apply()
	RegisterSignal(owner, COMSIG_MOB_SAY, PROC_REF(censor_swears))
	to_chat(owner, span_notice("Your mouth tastes like soap. You can't bring yourself to swear right now."))
	return TRUE

/datum/status_effect/soapy_mouth/on_remove()
	UnregisterSignal(owner, COMSIG_MOB_SAY)
	if(owner.stat != DEAD)
		to_chat(owner, span_notice("The soapy taste finally fades from your mouth."))

/datum/status_effect/soapy_mouth/proc/censor_swears(datum/source, list/speech_args)
	SIGNAL_HANDLER
	var/message = speech_args[SPEECH_MESSAGE]
	if(!swear_regex.Find(message))
		return
	speech_args[SPEECH_MESSAGE] = swear_regex.Replace(message, GLOBAL_PROC_REF(grawlix))

#undef SOAPY_MOUTH_DEFAULT_DURATION
