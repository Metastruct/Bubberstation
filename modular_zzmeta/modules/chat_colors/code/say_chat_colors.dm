/**
 * Gets this atom's personal chat color, used to color its name in the chat log (see /atom/movable/proc/compose_message).
 * Caches the same way /datum/chatmessage/proc/generate_image does, so player-picked chat colors (see modular_skyrat/modules/chat_colors)
 * and the deterministic per-name fallback stay in sync between the overhead runechat bubble and the chat log.
 */
/atom/proc/get_chat_name_color(darkened = FALSE)
	if(!chat_color || chat_color_name != name)
		chat_color = get_chat_color_string(name)
		chat_color_darkened = get_chat_color_string(name, darkened = TRUE)
		chat_color_name = name
	return darkened ? chat_color_darkened : chat_color

/// Maps the radio span classes in GLOB.freqtospan to a representative hex color, used as the blend base in get_radio_base_color().
/// Keep in sync with tgui-panel's chat-dark.scss / chat-light.scss radio colors.
GLOBAL_LIST_INIT(radio_span_colors, list(
	"radio" = RADIO_COLOR_COMMON,
	"sciradio" = RADIO_COLOR_SCIENCE,
	"medradio" = RADIO_COLOR_MEDICAL,
	"engradio" = RADIO_COLOR_ENGINEERING,
	"suppradio" = RADIO_COLOR_SUPPLY,
	"servradio" = RADIO_COLOR_SERVICE,
	"secradio" = RADIO_COLOR_SECURITY,
	"comradio" = RADIO_COLOR_COMMAND,
	"aiprivradio" = RADIO_COLOR_AI_PRIVATE,
	"enteradio" = RADIO_COLOR_ENTERTAIMENT,
	"syndradio" = RADIO_COLOR_SYNDICATE,
	"centcomradio" = "#686868",
	"redteamradio" = RADIO_COLOR_CTF_RED,
	"blueteamradio" = RADIO_COLOR_CTF_BLUE,
	"greenteamradio" = RADIO_COLOR_GREEN,
	"yellowteamradio" = RADIO_COLOR_YELLOW,
	"captaincast" = "#00ff99",
))

/**
 * Gets a radio channel's established color, e.g. the green of Common or the red of Security.
 * This is only the channel's own base color. The client blends it with the speaker's personal chat color itself,
 * with the ratio set by the "Radio color mix" slider in chat settings, see .chat-color-name-radio in main.scss.
 *
 * * freq - The radio frequency being spoken on.
 * * freq_color - An explicit color override for this transmission, if any (see get_radio_color()).
 */
/proc/get_radio_base_color(freq, freq_color)
	if(!freq)
		return null
	if(freq_color)
		return freq_color
	var/span = GLOB.freqtospan["[freq]"]
	var/base_color = span ? GLOB.radio_span_colors[span] : null
	return base_color || RADIO_COLOR_COMMON
