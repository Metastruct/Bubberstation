/// Garbles spoken words into "mmmf"-style gibberish instead of blocking speech outright.
/// Word-mangling logic mirrors /datum/element/muffles_speech (used by muzzle masks) so a
/// muzzled mob and a "muffled" one read the same in chat. Also forces whisper range and
/// silences audible emotes like laugh, since a covered mouth can't project either.
/datum/status_effect/muffled
	id = "muffled"
	alert_type = null
	remove_on_fullheal = TRUE

/datum/status_effect/muffled/on_creation(mob/living/new_owner, duration = 10 SECONDS)
	src.duration = duration
	return ..()

/datum/status_effect/muffled/on_apply()
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(clear_muffle))
	RegisterSignal(owner, COMSIG_MOB_SAY, PROC_REF(muffle_talk))
	ADD_TRAIT(owner, TRAIT_SOFTSPOKEN, TRAIT_STATUS_EFFECT(id))
	ADD_TRAIT(owner, TRAIT_MUFFLED_EMOTE_SOUND, TRAIT_STATUS_EFFECT(id))
	return TRUE

/datum/status_effect/muffled/on_remove()
	UnregisterSignal(owner, list(COMSIG_LIVING_DEATH, COMSIG_MOB_SAY))
	REMOVE_TRAIT(owner, TRAIT_SOFTSPOKEN, TRAIT_STATUS_EFFECT(id))
	REMOVE_TRAIT(owner, TRAIT_MUFFLED_EMOTE_SOUND, TRAIT_STATUS_EFFECT(id))

/// Signal proc that clears any muffle we have (self-deletes).
/datum/status_effect/muffled/proc/clear_muffle(mob/living/source)
	SIGNAL_HANDLER

	qdel(src)

/datum/status_effect/muffled/proc/muffle_talk(datum/source, list/speech_args)
	SIGNAL_HANDLER

	if(HAS_TRAIT(source, TRAIT_SIGN_LANG))
		return
	var/spoken_message = speech_args[SPEECH_MESSAGE]
	if(spoken_message)
		var/list/words = splittext(spoken_message, " ")
		var/yell_suffix = copytext(spoken_message, findtext(spoken_message, "!"))
		spoken_message = ""

		for(var/ind = 1 to length(words))
			var/new_word = ""
			for(var/i = 1 to length(words[ind]) + rand(-1, 1))
				new_word += "m"
			new_word += "f"
			words[ind] = yell_suffix ? uppertext(new_word) : new_word
		spoken_message = "[jointext(words, " ")][yell_suffix]"
	speech_args[SPEECH_MESSAGE] = spoken_message
