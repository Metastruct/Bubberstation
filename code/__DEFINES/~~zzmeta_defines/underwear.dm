// Underwear/bra/undershirt/socks item slots. Needed early by core code/modules/mob/living/carbon/human/inventory.dm
// and code/datums/outfit.dm, so these can't live in a normally-late-compiling modular_zzmeta file.
#define ITEM_SLOT_UNDERWEAR (1<<19)
#define ITEM_SLOT_BRA (1<<20)
#define ITEM_SLOT_UNDERSHIRT (1<<21)
#define ITEM_SLOT_SOCKS (1<<22)

// Strip menu keys for the same four slots. Needed early by core code/modules/mob/living/carbon/human/human_stripping.dm.
#define STRIPPABLE_ITEM_UNDERWEAR "underwear"
#define STRIPPABLE_ITEM_BRA "bra"
#define STRIPPABLE_ITEM_UNDERSHIRT "undershirt"
#define STRIPPABLE_ITEM_SOCKS "socks"
