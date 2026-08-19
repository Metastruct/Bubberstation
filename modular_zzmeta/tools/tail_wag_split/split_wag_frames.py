"""
Splits a baked wag animation icon_state into the per-frame static states
("<state>_f1", "<state>_f2", ...) that tail_wag_speed.dm's
discover_wag_frame_count() looks for at runtime to drive its code-controlled,
mood-scaled wag speed instead of the animation's own baked delay.

Usage:
    tools/bootstrap/python modular_zzmeta/tools/tail_wag_split/split_wag_frames.py <dmi_file> [<dmi_file> ...]
    tools/bootstrap/python modular_zzmeta/tools/tail_wag_split/split_wag_frames.py --dry-run <dmi_file>

By default, splits every animated (framecount > 1) icon_state whose name
contains "wagging", the convention every tail sprite in the repo uses today
(see get_feature_key_for_overlay() in
modular_skyrat/modules/customization/modules/surgery/organs/tails.dm, which
prepends the literal text "wagging" to the tail's feature_key while wagging).
Pass --pattern to match a different naming convention.

A rewind (ping-pong) source animation is split into its full forward+reverse
sequence (2N-2 states for an N-frame source), matching how BYOND itself plays
it back. A plain forward-only split makes a ping-pong tail wag in one
direction only.

Already-split states are left alone (matched by "<state>_f1" already
existing), so this is safe to re-run on a file after adding new tail sprites
to it without re-splitting states that are already done.

Pass --unsplit to go the other way: removes existing split states for a
matching wag animation, leaving just the original baked animated state
behind. Useful when re-drawing an existing wag animation, since editing a
DMI with hundreds of stale single-frame split states in it is painful:
unsplit first, edit the baked animation like normal, then split again.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "tools"))

from dmi import Dmi  # noqa: E402


def frame_sequence(framecount, rewind):
    """Animation-frame indexes (0-indexed, into the source state's own frame
    list) to emit as split states, in order."""
    if not rewind or framecount < 2:
        return list(range(framecount))
    return list(range(framecount)) + list(range(framecount - 2, 0, -1))


def split_state(dmi, state):
    """Adds one single-frame state per entry of frame_sequence() to dmi, named
    "<state.name>_f<n>" (1-indexed), preserving the source state's dirs.
    Returns how many split states were added."""
    sequence = frame_sequence(state.framecount, state.rewind)
    for split_index, source_frame in enumerate(sequence, start=1):
        split_state_obj = dmi.state(f"{state.name}_f{split_index}", dirs=state.dirs)
        for dir_offset in range(state.dirs):
            split_state_obj.frame(state.frames[source_frame * state.dirs + dir_offset])
    return len(sequence)


def find_wag_states(dmi, pattern):
    return [state for state in dmi.states if pattern in state.name and state.framecount > 1]


def already_split(dmi, state):
    return any(other.name == f"{state.name}_f1" for other in dmi.states)


SPLIT_STATE_RE = re.compile(r"^(?P<base>.+)_f(?P<n>\d+)$")


def find_split_children(dmi, pattern):
    """Returns {base_state_name: [split_state_name, ...]} for every state in
    dmi matching pattern that has "_fN" split children, sorted by N. Only
    counts a state as a split child if its base name is itself a real state
    in the file, so an unrelated state that happens to end in "_f3" for some
    other reason is never touched."""
    base_names = {state.name for state in dmi.states}
    groups = {}
    for state in dmi.states:
        match = SPLIT_STATE_RE.match(state.name)
        if not match or match.group("base") not in base_names or pattern not in match.group("base"):
            continue
        groups.setdefault(match.group("base"), []).append((int(match.group("n")), state.name))
    return {base: [name for _, name in sorted(children)] for base, children in groups.items()}


def unsplit_file(path, pattern, dry_run):
    dmi = Dmi.from_file(path)
    groups = find_split_children(dmi, pattern)
    if not groups:
        print(f"{path}: nothing to do (no split states found)")
        return

    remove_names = set()
    for base, children in groups.items():
        verb = "would remove" if dry_run else "removing"
        print(f"{path}: {verb} {len(children)} split state(s) for {base!r}")
        remove_names.update(children)

    if not dry_run:
        dmi.states = [state for state in dmi.states if state.name not in remove_names]
        dmi.to_file(path)
        print(f"{path}: removed {len(remove_names)} split state(s) across {len(groups)} base state(s)")


def process_file(path, pattern, dry_run):
    dmi = Dmi.from_file(path)
    candidates = find_wag_states(dmi, pattern)
    to_split = [state for state in candidates if not already_split(dmi, state)]
    if not to_split:
        print(f"{path}: nothing to do ({len(candidates)} matching state(s), all already split)")
        return

    total_added = 0
    for state in to_split:
        kind = "rewind" if state.rewind else "linear"
        sequence = frame_sequence(state.framecount, state.rewind)
        if dry_run:
            print(f"{path}: would split {state.name!r} ({kind}, {state.framecount} baked frames -> {len(sequence)} split states)")
            continue
        added = split_state(dmi, state)
        total_added += added
        print(f"{path}: split {state.name!r} ({kind}, {state.framecount} baked frames -> {added} split states)")

    if not dry_run:
        dmi.to_file(path)
        print(f"{path}: wrote {len(to_split)} split state(s), {total_added} frame(s) total")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dmi_files", nargs="+", help="DMI file(s) to split wag animations in, modified in place")
    parser.add_argument("--pattern", default="wagging", help='Substring an icon_state name must contain to be treated as a wag animation (default: "wagging")')
    parser.add_argument("--dry-run", action="store_true", help="Report what would change without writing any files")
    parser.add_argument("--unsplit", action="store_true", help="Remove existing split states instead of creating them")
    args = parser.parse_args()

    for path in args.dmi_files:
        if args.unsplit:
            unsplit_file(path, args.pattern, args.dry_run)
        else:
            process_file(path, args.pattern, args.dry_run)


if __name__ == "__main__":
    main()
