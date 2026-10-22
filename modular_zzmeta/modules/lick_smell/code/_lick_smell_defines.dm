/// from /datum/status_effect/sensory/lick/do_taste(): (source=mob/living/licker, atom/licked)
#define COMSIG_LIVING_LICK_ATOM "living_lick_atom"
/// from /datum/status_effect/sensory/lick/do_taste(): (source=mob/living/licked, mob/living/licker)
#define COMSIG_LIVING_LICKED "living_licked"
/// from /datum/status_effect/sensory/smell/do_taste(): (source=mob/living/sniffer, atom/smelled)
#define COMSIG_LIVING_SMELL_ATOM "living_smell_atom"
/// from /datum/status_effect/sensory/smell/do_taste(): (source=mob/living/smelled, mob/living/sniffer)
#define COMSIG_LIVING_SMELLED "living_smelled"

/// How far, in tiles, a keen nose can pick up a scent trail.
#define KEEN_NOSE_TRACK_RANGE 7
/// Minimum bloodiness for a decal to register as a trackable scent.
#define KEEN_NOSE_MIN_BLOODINESS 10
