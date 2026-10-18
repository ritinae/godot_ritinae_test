# Running tests

Tests run headless, one Godot process per test file, at a fixed 60 fps.
`run_tests.sh` finds a project's tests, runs each through `runner.gd` and
sums up which passed. The runner's output lines are a contract that the
scripts parse.

## Finding tests

- `run_tests.sh` runs every `test_*.gd` under the tests folder, subfolders
  included, sorted by path. The folder is `test/` unless `--tests <dir>` is
  given; a trailing `/` is ignored.
- A test's name is its path under that folder without `.gd`
  (`gameplay/test_economy`).
- A filter argument keeps the tests whose name contains it, so `economy`
  matches a file and `gameplay/camp` a folder and its subfolders.
- The script works from any directory; paths are relative to the project
  root.
- A missing tests folder prints `No tests folder <dir>` and exits with 1. An
  unknown option prints `Unknown option <option>` and exits with 2. A
  `--tests` without a folder is an error.

## Importing

Before running anything, `run_tests.sh` and `run_self_tests.sh` import the
project (`godot --headless --import`) when:

- there is no import cache (`No import cache found`),
- a `.gd` file is newer than the cache (`Scripts changed since the last
  import`), or
- the cache lists a script path that no longer exists, as after a move or
  rename that kept the file's time (`Scripts moved since the last import`).

The reason is printed, followed by `importing the project...`. After the
import the cache is touched, so the next run doesn't import again. A failed
import prints `Import failed; run '<godot> --headless --import' to see why.`
and the script exits with 1 before running any test.

## Running one test

`runner.gd` runs one test file, given after `--`:

```sh
godot --headless --fixed-fps 60 --script res://addons/ritinae_test/runner.gd -- res://test/gameplay/test_economy.gd
```

- It makes the test, adds the scene from the test's `create_scene()` (if
  any) to the tree, then the test, and calls the test's `run()` one frame
  later.
- Tests are loaded after the autoloads exist, so they can name the project's
  classes directly.
- When `run()` returns, any assertion that never reached an expect call
  fails (see the checks spec), then the runner prints
  `RESULT: <passed> passed, <failed> failed` and quits.
- Exit code 0 only when no check failed and at least one passed; 1
  otherwise. A test that makes no checks fails.
- Without a path, with a path that doesn't load, or with a script that has
  no `run()`, the runner reports the problem as an error and exits with 1.

## Hung tests

- A test still running after `max_seconds` game seconds (180 by default; a
  test may set it in `_init()`) fails with
  `FAIL test finished within <max_seconds> game seconds`, then prints its
  `RESULT` line and quits.
- `run_tests.sh` also stops a test process after 300 real seconds.

## Script errors

A script error stops the test's `run()` early but doesn't fail the
runner's exit code. `run_tests.sh` and the self-tests count any
`SCRIPT ERROR` line in the output as a failure.

## Output

The runner prints, in order:

- `STEP <path>` before each step, and `STEP <path> (before all)` /
  `(after all)` before a group's once-hooks (see the steps spec);
- `PASS <description>` or `FAIL <description>` for each check;
- lines starting with `info` that the project's tests print;
- `RESULT: N passed, M failed` last.

`run_tests.sh` prints one line per test, then a summary:

- `PASS <name> (N passed, M failed)`. With `-v` it also prints the test's
  `STEP`, `PASS`, `FAIL` and `info` lines, indented by 4 spaces.
- `FAIL <name> (N passed, M failed)` (or `(exit code N)` when there was no
  `RESULT` line), followed by its `info`, `STEP`, `FAIL`, `SCRIPT ERROR`,
  `ERROR:` and stack (`at:`) lines, indented by 4 spaces.
- After a blank line: `All N tests passed.`, or
  `K of N tests failed: <names>` and exit code 1, or `No tests matched.` and
  exit code 1.

## Self-tests

- `tests/run_self_tests.sh [filter]` runs every `tests/<name>.gd` of the
  framework whose name contains the filter.
- Each self-test passes when its exit code (`exit N`) and its `STEP`,
  `PASS`, `FAIL`, `RESULT:` and `SCRIPT ERROR` lines match
  `tests/<name>.expected` exactly. Many self-tests are meant to fail; what's
  checked is that they fail, or pass, exactly as expected.
- A mismatch prints `FAIL <name> (< expected, > actual)` with the diff.
  The summary is `All N self-tests passed.`, `K of N self-tests failed:
  <names>` or `No self-tests matched.`.

## Controls

| Command | Action |
|---|---|
| `run_tests.sh` | Run every test in `test/` |
| `run_tests.sh <filter>` | Run the tests whose name contains the filter |
| `run_tests.sh -v` | Also print every step, check and info line |
| `run_tests.sh --tests <dir>` | Look for tests in `<dir>` |
| `tests/run_self_tests.sh [filter]` | Run the framework's self-tests |
| `GODOT=<binary>` | Use a different Godot binary in either script |

## Code

- `run_tests.sh`: finding, filtering and running tests, the summary
- `import.sh`: importing when the cache is missing or stale
- `runner.gd`: running one test, hung tests, `RESULT` and the exit code
- `tests/run_self_tests.sh`: the self-tests against their `.expected`

## Tests

- `tests/run_passing.gd`, `tests/run_failing.gd`
- `tests/run_no_checks.gd`
- `tests/run_hang.gd`
