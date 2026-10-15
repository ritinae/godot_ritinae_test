#!/usr/bin/env bash
# Runs every test_*.gd under the tests folder (subfolders included) headless and
# reports which passed. Tests are named by their path under that folder,
# without .gd. Run from anywhere; paths are relative to the project root.
#
#   run_tests.sh                   run all tests in test/
#   run_tests.sh economy           run tests whose name contains "economy"
#   run_tests.sh gameplay/camp     run the tests in a folder (and its subfolders)
#   run_tests.sh -v                also print every step, check and info line
#   run_tests.sh --tests dir       look for tests in dir instead of test/
#
# Set GODOT to use a different Godot binary (default: godot).
set -u
cd "$(dirname "$0")/../.."

godot=${GODOT:-godot}
runner=res://addons/ritinae_test/runner.gd
tests=test
verbose=0
filter=""
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
		*) filter="$1" ;;
	esac
	shift
done
tests=${tests%/}
if [[ ! -d $tests ]]; then
	echo "No tests folder $tests"
	exit 1
fi

# Without an up-to-date import cache, class_names are missing (a fresh checkout
# or worktree has no cache; a new class_name, e.g. from a pull or rebase, isn't
# in it yet), and tests using them would hang until their timeout. Import the
# project first when the cache is missing or a script is newer than it.
cache=.godot/global_script_class_cache.cfg
reason=""
if [[ ! -f $cache ]]; then
	reason="No import cache found"
elif [[ -n $(find . -path ./.godot -prune -o -name '*.gd' -newer "$cache" -print -quit) ]]; then
	reason="Scripts changed since the last import"
else
	# A moved or renamed script keeps its old mtime (git mv, mv), so the check
	# above misses it; catch it by the cache listing a path that's now gone.
	while IFS= read -r script; do
		if [[ ! -f ${script#res://} ]]; then
			reason="Scripts moved since the last import"
			break
		fi
	done < <(sed -n 's/^"path": "\(res:\/\/[^"]*\)"$/\1/p' "$cache")
fi
if [[ -n $reason ]]; then
	echo "$reason, importing the project..."
	if ! "$godot" --headless --import >/dev/null 2>&1 || [[ ! -f $cache ]]; then
		echo "Import failed; run '$godot --headless --import' to see why."
		exit 1
	fi
	# Godot leaves the cache alone when no class changed; mark it current so
	# the next run doesn't import again.
	touch "$cache"
fi

failed=()
count=0
while IFS= read -r path; do
	name=${path#"$tests"/}
	name=${name%.gd}
	[[ -n "$filter" && "$name" != *"$filter"* ]] && continue
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
