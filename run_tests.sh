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
#   run_tests.sh -j 4              run at most 4 tests at a time (default: one per CPU)
#
# The tests folder is test/ unless the project setting ritinae_test/run/tests_dir
# (Project Settings > Ritinae Test > Run > Tests Dir) or --tests names another.
#
# The framework's own tests are in tests/ (tests/run_self_tests.sh).
#
# Set GODOT to use a different Godot binary (default: godot).
set -u
cd "$(dirname "$0")/../.."

godot=${GODOT:-godot}
runner=res://addons/ritinae_test/runner.gd

# Prints a project setting's value as project.godot holds it (a string keeps its
# quotes), or nothing when the setting isn't there, as at its default.
project_setting() {
	local section=${1%%/*} key=${1#*/}
	awk -v section="[$section]" -v key="$key=" '
		/^\[/ { in_section = ($0 == section) }
		in_section && index($0, key) == 1 { print substr($0, length(key) + 1); exit }
	' project.godot
}

tests=$(project_setting ritinae_test/run/tests_dir)
tests=${tests#\"}
tests=${tests%\"}
tests=${tests#res://}
tests=${tests:-test}
verbose=0
jobs=$(nproc 2>/dev/null || echo 1)
filters=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		-v) verbose=1 ;;
		-j | --jobs)
			shift
			jobs="${1:?-j needs a number}"
			if [[ ! $jobs =~ ^[1-9][0-9]*$ ]]; then
				echo "-j needs a positive number"
				exit 2
			fi
			;;
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

names=()
while IFS= read -r path; do
	name=${path#"$tests"/}
	name=${name%.gd}
	matches_filters "$name" && names+=("$name")
done < <(find "$tests" -name 'test_*.gd' | sort)
count=${#names[@]}

# Each test runs in the background into $work/<index>.out, then writes
# <index>.status; results print in test order as soon as the earlier ones are in.
work=$(mktemp -d)

# timeout runs in its own process group, out of reach of Ctrl-C; it passes a
# TERM on to Godot.
stop_tests() {
	local job
	for job in $(jobs -p); do
		pkill -TERM -P "$job" 2>/dev/null
		kill "$job" 2>/dev/null
	done
	rm -rf "$work"
}
trap stop_tests EXIT
trap 'exit 130' INT TERM

run_test() {
	local index=$1 path=$2
	timeout 300 "$godot" --headless --fixed-fps 60 --script "$runner" -- "res://$path" \
		>"$work/$index.out" 2>&1 </dev/null
	echo $? >"$work/$index.status.tmp"
	mv "$work/$index.status.tmp" "$work/$index.status"
}

failed=()
report() {
	local index=$1 name=${names[$1]} output status result
	output=$(<"$work/$index.out")
	status=$(<"$work/$index.status")
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
}

reported=0
report_finished() {
	while [[ $reported -lt $count && -f $work/$reported.status ]]; do
		report "$reported"
		reported=$((reported + 1))
	done
}

for index in "${!names[@]}"; do
	while [[ $(jobs -rp | wc -l) -ge $jobs ]]; do
		wait -n
		report_finished
	done
	run_test "$index" "$tests/${names[$index]}.gd" &
done
wait
report_finished

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
