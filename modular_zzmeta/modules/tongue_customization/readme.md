# Tongue customization

Character-pref driven appearance for the tongue overlay used by `*tongue` and the `*lick` emote.

Hovering a style in the dropdown previews it live on the character preview dummy
(see `code/preview.dm`); picking one saves it.

## Adding a style

1. Draw directional states in `icons/tongue.dmi` (white/greyscale so the pref colors tint them).
2. Add a `/datum/sprite_accessory/custom_tongue/<id>` in `code/sprite_accessories.dm`.

### One color

- `color_src = USE_ONE_COLOR` (the default)
- One state named `icon_state` with 4 dirs.

### Tri-color / matrixed

- `color_src = USE_MATRIXED_COLORS`
- States named `icon_state_primary`, `icon_state_secondary`, and optionally `icon_state_tertiary`.

### Species gating

Set `allowed_species` to a list of species IDs (`SPECIES_LIZARD`, …).
Null or empty = available to everyone.
With **Allow Mismatched Parts** off, other species cannot pick it from the dropdown.
