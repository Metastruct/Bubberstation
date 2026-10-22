// Metastruct: leg style registry keys.
//
// Global because the registry, its preference and the teshari leg fit all share them, and
// `define_sanity` only exempts global defines living under a `__DEFINES` directory.

/// DNA feature holding the chosen [GLOB.leg_styles] key. Separate from FEATURE_LEGS
/// (which stays a plain Normal/Digitigrade toggle) so existing legs logic is untouched.
#define FEATURE_LEG_STYLE "leg_style"

/// Use the species' own leg types (for synths: the chassis synth art).
#define LEG_STYLE_NATIVE "Native"
/// The slim organic lizard legs.
#define LEG_STYLE_ORGANIC "Organic Lizard"
#define LEG_STYLE_LIZARD "Lizard"
#define LEG_STYLE_TESHARI "Teshari"
#define LEG_STYLE_VOX "Vox"
#define LEG_STYLE_SHADEKIN "Shadekin"
#define LEG_STYLE_AQUATIC "Aquatic"
#define LEG_STYLE_LYCAN "Lycan"
#define LEG_STYLE_XENOHYBRID "Xenohybrid"
