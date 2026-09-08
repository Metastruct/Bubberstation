#!/bin/bash
# Run the locally-runnable subset of .github/workflows/run_linters.yml.
#
# Usage: modular_zzmeta/tools/check.sh [--update-baseline]
#   --update-baseline  Adopt the current dreamchecker diagnostics as the new
#                       accepted baseline instead of diffing against it. Use
#                       after confirming a diagnostic count change is real
#                       and intentional (fixed something, or knowingly
#                       accepting a new one), not as a way to silence a
#                       regression you haven't looked at.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

dc_args=()
if [[ "${1:-}" == "--update-baseline" ]]; then
	dc_args+=(--update-baseline)
fi

fail=0

run_step() {
	local name="$1"; shift
	echo "== $name =="
	if "$@"; then
		echo "[OK] $name"
	else
		echo "[FAIL] $name"
		fail=1
	fi
	echo
}

run_step "check_genesis" bash tools/ci/check_genesis.sh
run_step "check_grep" bash tools/ci/check_grep.sh
run_step "ticked_file_enforcement (tgstation.dme)" bash -c \
	'tools/bootstrap/python tools/ticked_file_enforcement/ticked_file_enforcement.py < tools/ticked_file_enforcement/schemas/tgstation_dme.json'
run_step "ticked_file_enforcement (unit_tests)" bash -c \
	'tools/bootstrap/python tools/ticked_file_enforcement/ticked_file_enforcement.py < tools/ticked_file_enforcement/schemas/unit_tests.json'
run_step "define_sanity" tools/bootstrap/python -m tools.define_sanity.check
run_step "trait_validity" tools/bootstrap/python -m tools.trait_validity.check
run_step "check_filedirs" bash tools/ci/check_filedirs.sh tgstation.dme
run_step "dmi.test" tools/bootstrap/python -m dmi.test

if command -v dreamchecker >/dev/null 2>&1; then
	echo "== dreamchecker =="
	dreamchecker 2>&1 | tools/bootstrap/python modular_zzmeta/tools/dreamchecker_diff.py "${dc_args[@]}"
	dc_status=${PIPESTATUS[1]}
	if [[ $dc_status -eq 0 ]]; then
		echo "[OK] dreamchecker"
	else
		echo "[FAIL] dreamchecker"
		fail=1
	fi
	echo
else
	echo "[SKIP] dreamchecker not on PATH (bash tools/ci/install_spaceman_dmm.sh dreamchecker, then symlink onto PATH)"
fi

exit $fail
