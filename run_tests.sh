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
#   run_tests.sh -j 4              run at most 4 tests at a time
#
# The tests folder is test/ unless the project setting ritinae_test/run/tests_dir
# (Project Settings > Ritinae Test > Run > Tests Dir) or --tests names another.
# Tests run one per CPU at a time unless the project setting ritinae_test/run/jobs
# (above 0) or -j says otherwise. cli_runner.gd does the running.
#
# The framework's own tests are in tests/ (tests/run_self_tests.sh).
#
# Set GODOT to use a different Godot binary (default: godot).
set -u
cd "$(dirname "$0")/../.."

godot=${GODOT:-godot}

source addons/ritinae_test/import.sh
ensure_imported || exit 1

exec "$godot" --headless --no-header --script res://addons/ritinae_test/cli_runner.gd -- "$@"
