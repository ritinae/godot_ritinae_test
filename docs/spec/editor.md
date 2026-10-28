# The Tests screen

The editor plugin adds a **Tests** main screen, next to 2D, 3D and Script,
that lists the project's tests and runs them. Each test runs in its own
headless Godot process, several at a time, and is judged as `run_tests.sh`
judges it. The plugin also adds the project settings that name the tests
folder and how many tests run at a time.

## The tests folder

- The project setting `ritinae_test/run/tests_dir` (Project Settings →
  Ritinae Test → Run → Tests Dir) names the folder, `res://test` by
  default. The plugin adds it, with a folder picker, while it is enabled.
- A folder without `res://` is under the project root, a trailing `/` is
  dropped, and an empty one is the default.
- `run_tests.sh` reads the same setting (see the running spec).

## Jobs

- The project setting `ritinae_test/run/jobs` (Project Settings → Ritinae
  Test → Run → Jobs) is how many tests run at a time, 0 by default, which
  runs one per CPU. The plugin adds it while it is enabled.
- `run_tests.sh` reads the same setting; its `-j` overrides it.

## Listing tests

- The screen lists every `test_*.gd` under the tests folder, subfolders
  included, sorted by path and named by its path under the folder without
  `.gd`, as `run_tests.sh` does.
- The list is a tree: each subfolder is an item with a folder icon, holding
  its subfolders and tests, and each test shows its file name without `.gd`.
- The list has a name column and a status column. The status column starts
  out fitting an icon and `FAIL (99 passed, 99 failed)`, and widens, with
  the list, to fit any longer status shown, such as a timeout; it doesn't
  narrow again. A status also shows whole in its tooltip. The list starts as wide as its widest name,
  indent and icon included, but at most 480 pixels for the names (times the
  editor scale), and keeps fitting the names when refreshed until its width
  is dragged.
- The filter keeps the tests whose name contains any of its
  space-separated words.
- The list is refreshed when the screen is shown, when the filter changes,
  when the project's files change and when a project setting changes, but
  not while tests are running. Results of earlier runs stay on their tests.
- A test that hasn't run shows `Not yet run`, dimmed, as do the tests
  skipped by Stop. The list has a background darker than the editor's.
- The status shows `<N> tests in <folder>`, `No tests matched.` or
  `No tests folder <folder>`. Run is disabled when nothing is listed.

## Running tests

- **Run** (or Enter in the filter) runs the listed tests, starting them in
  order, up to the jobs setting at a time; a
  double-click on a test runs only that one, and on a folder the listed
  tests under it. The filter can't be changed
  while tests run.
- When the editor setting `run/auto_save/save_before_running` is on, all
  scenes and scripts are saved first.
- A test runs as `godot --headless --fixed-fps 60 --path <project> --script
  res://addons/ritinae_test/runner.gd -- <test>`, with the editor's own
  Godot binary.
- While a test runs, it shows `running…`, and the status shows
  `Running <R>, <D> of <N> done`: how many tests are running and how many
  have finished.
- A test passes when its process exits with 0 and prints no `SCRIPT ERROR`.
  It then shows `PASS (<counts>)`, else `FAIL (<counts>)`, where the counts
  are its `RESULT` line (`3 passed, 1 failed`), or `exit code <N>`,
  `stopped` or `timed out after 300 real seconds` when it has none.
- A test still running after 300 real seconds is killed and fails as
  timed out.
- **Stop** kills the running tests, which fail as stopped, and skips the
  ones waiting.
- After the run the status is `All <N> tests passed.` or
  `<K> of <N> tests failed.`.

## Output

- Selecting a test shows its output: the lines it printed, stdout and
  stderr alike, as they arrive while it runs. Godot's version line and
  empty lines are left out.
- `PASS` lines are green, `FAIL`, `SCRIPT ERROR` and `ERROR:` lines red,
  and `STEP` lines in the accent colour.
- During a run the selection follows the earliest running test, and ends
  on the first failed test in list order, until a test is selected by hand. Folders of a selected
  test are expanded. Selecting a folder shows no output.

## Controls

| Control | Action |
|---|---|
| Run, or Enter in the filter | Run the listed tests |
| Double-click a test | Run that test |
| Double-click a folder | Run the listed tests under it |
| Stop | Stop the running tests and the ones waiting |
| Filter | List the tests whose name contains any of its words |
| Select a test | Show its output |
| `ritinae_test/run/jobs` | How many tests run at a time, 0 for one per CPU |

## Code

- `test_plugin.gd`: the main screen and the project settings
- `src/tests_screen.gd`: the screen
- `src/test_suite.gd` (`RTTestSuite`): the tests folder and jobs settings,
  finding and filtering tests
- `src/test_queue.gd` (`RTTestQueue`): running tests several at a time
- `src/test_run.gd` (`RTTestRun`): running one test in its own process,
  timing out, stopping, judging it

## Tests

- `tests/suite_find.gd`: finding and filtering tests, the settings
- `tests/queue_run.gd`: running several tests at a time, in order, and
  stopping them
- `tests/suite_run.gd`: running, judging, stopping and timing out, against
  the tests in `tests/fixtures/suite/`
- The screen itself has no self-test; it needs the editor.
