# Tail wag frame splitter

Companion tool for `modular_zzmeta/code/datums/bodypart_overlays/tail_wag_speed.dm`.

That feature drives tail wag animation speed from code (mood + a player-set
percentage) instead of the animation's own baked per-frame delay. To do that
it needs each baked wag animation split into individual single-frame states
(`<state>_f1`, `<state>_f2`, ...), which it steps through on a timer. Any
tail whose wag animation isn't split just falls back to playing its original
baked animation at its original fixed speed.

## Adding a new tail sprite

If you're adding a new tail with its own wag animation, split it after
you've added the DMI states as normal:

```
tools/bootstrap/python modular_zzmeta/tools/tail_wag_split/split_wag_frames.py path/to/your_tails.dmi
```

Preview what it would do first with `--dry-run` if you want to check before
writing:

```
tools/bootstrap/python modular_zzmeta/tools/tail_wag_split/split_wag_frames.py --dry-run path/to/your_tails.dmi
```

It's safe to run on a whole file even if some of its states are already
split, since those are detected and left alone.

For a full worked example, including a real .dmi file set up exactly the
way it should look before running this tool, see
`modular_zzmeta/code/modules/customization/sprite_accessories/EXAMPLE_new_tail.dm.example`
and the `tails.dmi.example` next to it.

## Re-editing an existing tail's wag animation

A wag animation can split into over a dozen states per direction per color
layer, which makes editing it in an icon editor awkward with all those
split states in the way. Strip them first with `--unsplit`:

```
tools/bootstrap/python modular_zzmeta/tools/tail_wag_split/split_wag_frames.py --unsplit path/to/tails.dmi
```

This removes every `_f1`, `_f2`, ... state belonging to a matching wag
animation and leaves the original baked animated state untouched. Edit that
animation like normal, then split it again the usual way. `--dry-run` works
here too.

## How it decides what to split

Any animated (more than one baked frame) icon_state whose name contains the
text `wagging` is treated as a wag animation. That's the convention every
tail sprite in the repo uses today (see `get_feature_key_for_overlay()` in
`modular_skyrat/modules/customization/modules/surgery/organs/tails.dm`,
which prepends the literal text `wagging` to the tail's feature_key while
wagging, and that's what ends up in the rendered icon_state name). If a new
tail's naming doesn't fit that pattern for some reason, pass
`--pattern` to match on something else instead.

Ping-pong (`rewind`) source animations are split into the full
forward-then-reverse sequence (2N-2 states for an N-frame source) rather
than just the forward frames, matching how BYOND itself plays a rewind
animation back. A plain forward-only split makes a ping-pong tail wag in
one direction only.
