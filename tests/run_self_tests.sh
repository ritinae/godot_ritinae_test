#!/usr/bin/env bash
# Tests the test framework itself. Each <name>.gd in this folder is a test run
# through runner.gd; <name>.expected next to it holds the exit code it should
# end with ("exit N") and, in order, the STEP, PASS, FAIL, RESULT and SCRIPT
# ERROR lines it should print. Many of these tests are meant to fail; what's
# checked is that they fail, or pass, exactly as expected.
#
#   addons/ritinae_test/tests/run_self_tests.sh          run all
#   addons/ritinae_test/tests/run_self_tests.sh hooks    run those whose name contains "hooks"
#
# Set GODOT to use a different Godot binary (default: godot).
set -u
cd "$(dirname "$0")/../../.."

godot=${GODOT:-godot}
dir=addons/ritinae_test/tests
filter=${1:-}

source addons/ritinae_test/import.sh
ensure_imported || exit 1

failed=()
count=0
for path in "$dir"/*.gd; do
	name=$(basename "$path" .gd)
	[[ -n "$filter" && "$name" != *"$filter"* ]] && continue
	count=$((count + 1))
	output=$("$godot" --headless --fixed-fps 60 --script res://addons/ritinae_test/runner.gd \
		-- "res://$path" 2>&1 </dev/null)
	status=$?
	actual=$(printf 'exit %d\n' "$status"; grep -E "^(STEP|PASS|FAIL|RESULT:|SCRIPT ERROR)" <<<"$output")
	if diff_out=$(diff "$dir/$name.expected" <(echo "$actual")); then
		echo "PASS $name"
	else
		echo "FAIL $name (< expected, > actual)"
		sed 's/^/    /' <<<"$diff_out"
		failed+=("$name")
	fi
done

echo
if [[ $count -eq 0 ]]; then
	echo "No self-tests matched."
	exit 1
elif [[ ${#failed[@]} -eq 0 ]]; then
	echo "All $count self-tests passed."
else
	echo "${#failed[@]} of $count self-tests failed: ${failed[*]}"
	exit 1
fi
