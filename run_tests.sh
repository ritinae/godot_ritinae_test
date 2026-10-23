#!/usr/bin/env bash
# Runs every test_*.gd under the tests folder (subfolders included) headless and
# reports which passed. Tests are named by their path under that folder,
# without .gd. Run from anywhere; paths are relative to the project root.
#
#   run_tests.sh                   run all tests in test/
#   run_tests.sh economy           run tests whose name contains "economy"
#   run_tests.sh gameplay/camp     run the tests in a folder (and its subfolders)
#   run_tests.sh camp economy      run tests whose name contains any of the filters
#   run_tests.sh -v                also print every step, check and info line
#   run_tests.sh --tests dir       look for tests in dir instead of test/
#
# The framework's own tests are in tests/ (tests/run_self_tests.sh).
#
# Set GODOT to use a different Godot binary (default: godot).
set -u
cd "$(dirname "$0")/../.."

godot=${GODOT:-godot}
runner=res://addons/ritinae_test/runner.gd
tests=test
verbose=0
filters=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		-v) verbose=1 ;;
		--tests)
			shift
			tests="${1:?--tests needs a folder}"
			;;
		-*)
			echo "Unknown option $1"
			exit 2
			;;
		*) filters+=("$1") ;;
	esac
	shift
done
tests=${tests%/}
if [[ ! -d $tests ]]; then
	echo "No tests folder $tests"
	exit 1
fi

source addons/ritinae_test/import.sh
ensure_imported || exit 1

matches_filters() {
	[[ ${#filters[@]} -eq 0 ]] && return 0
	local filter
	for filter in "${filters[@]}"; do
		[[ "$1" == *"$filter"* ]] && return 0
	done
	return 1
}

failed=()
count=0
while IFS= read -r path; do
	name=${path#"$tests"/}
	name=${name%.gd}
	matches_filters "$name" || continue
	count=$((count + 1))
	output=$(timeout 300 "$godot" --headless --fixed-fps 60 --script "$runner" -- "res://$path" 2>&1 </dev/null)
	status=$?
	result=$(grep -E "^RESULT:" <<<"$output" | tail -1)
	if [[ $status -eq 0 ]] && ! grep -q "SCRIPT ERROR" <<<"$output"; then
		echo "PASS $name (${result#RESULT: })"
		[[ $verbose -eq 1 ]] && grep -E "^(STEP|PASS|FAIL|info)" <<<"$output" | sed 's/^/    /'
	else
		result=${result#RESULT: }
		echo "FAIL $name (${result:-exit code $status})"
		grep -E "^info|^STEP|^FAIL|SCRIPT ERROR|ERROR:|^\s+at:" <<<"$output" | sed 's/^/    /'
		failed+=("$name")
	fi
done < <(find "$tests" -name 'test_*.gd' | sort)

echo
if [[ $count -eq 0 ]]; then
	echo "No tests matched."
	exit 1
elif [[ ${#failed[@]} -eq 0 ]]; then
	echo "All $count tests passed."
else
	echo "${#failed[@]} of $count tests failed: ${failed[*]}"
	exit 1
fi
