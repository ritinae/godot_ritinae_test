# AGENTS.md: ritinae_test

A headless test framework for Godot 4 (GDScript): describe/it steps, hooks,
page objects and checks that can be looked at on every frame. A project uses
it through its own base test and tests. How to write tests and pages is in
[docs/tests.md](docs/tests.md). The specs (current behaviour) are in
[docs/spec/](docs/spec/README.md).

## Commands

Run from anywhere; the scripts work from the project root.

```sh
addons/ritinae_test/tests/run_self_tests.sh         # run the framework's self-tests
addons/ritinae_test/tests/run_self_tests.sh hooks   # self-tests whose name contains "hooks"
addons/ritinae_test/run_tests.sh [filter...] [-v] [--tests dir] [-j n]   # run a project's tests (default dir: test/, jobs: the setting, else one per CPU)
```

Set `GODOT` to use a different Godot binary.

## Files

The framework's scripts are in `src/`; the runner and the editor plugin are in
the addon root.

- `runner.gd`: a `SceneTree` script that runs one test file. It adds the
  scene from the test's `create_scene()` and the test, awaits `run()`, fails
  the test as hung after `max_seconds`, and exits with 0 when every check
  passed and at least one did.
- `src/base_test.gd` (`RTTest`): the base every test extends through a
  project's base test. It collects the `describe`/`it`/hook tree from
  `spec()` and runs it, and holds `check()`, the `expect` calls, waiting and
  the pass/fail counts.
- `src/page.gd` (`RTPage`), `src/assertion.gd` (`RTAssertion`) and
  `src/expect.gd` (`RTExpect`): pages make assertions with `_assert()`.
  `RTExpect` checks them and tracks the ones that never reach an expect call.
- `run_tests.sh`: imports the project when needed and starts
  `cli_runner.gd`, a `SceneTree` script running every `test_*.gd` in a
  tests folder through an `RTTestSession`, several at a time, and
  summarising in test order. `import.sh` (sourced by both scripts) imports
  the project first when the import cache is missing or stale.
- `plugin.cfg` and `test_plugin.gd`: the editor plugin. It adds the Tests
  main screen (`src/tests_screen.gd`, `RTTestsScreen`) and the
  `ritinae_test/run/tests_dir` and `ritinae_test/run/jobs` project settings.
- `editor_runner.gd` (`RTEditorRunner`): the Tests screen's `RTTestSession`,
  saving before a run when the editor would, taking the jobs setting and
  wording the screen's status. The screen itself only shows the run.
- `src/test_session.gd` (`RTTestSession`): a run of a suite's tests by
  name, keeping their results, the failed ones and the order they finish in,
  for `cli_runner.gd` and `editor_runner.gd`.
- `src/test_suite.gd` (`RTTestSuite`): the tests folder and jobs settings,
  and finding and filtering tests as `run_tests.sh` does.
- `src/test_queue.gd` (`RTTestQueue`): runs test files several at a time as
  `RTTestRun`s, for `RTTestSession`.
- `src/test_run.gd` (`RTTestRun`): runs one test in its own headless process
  and judges it.
- `tests/`: the self-tests. `tests/fixtures/` holds tests the self-tests
  run as data; they aren't self-tests themselves.

## Output contract

The runner's output is parsed by `RTTestRun` (for `run_tests.sh` and the
Tests screen) and compared line by line by the self-tests. Changing it is a breaking change:

- `STEP <path>` (and `(before all)` / `(after all)`), `PASS <description>`,
  `FAIL <description>` and a final `RESULT: N passed, M failed`.
- Exit code 0 only when nothing failed and something passed; 1 otherwise.
- `run_tests.sh` counts any `SCRIPT ERROR` in the output as a failure, and
  `-v` also prints lines starting with `info`.

## Self-tests

Each `tests/<name>.gd` is a test run through `runner.gd`, and
`tests/<name>.expected` holds what it should produce: `exit N`, then, in
order, its `STEP`, `PASS`, `FAIL`, `RESULT:` and `SCRIPT ERROR` lines. Many
self-tests are meant to fail; what's checked is that they fail or pass exactly
as expected. Every change to the framework adds or updates a self-test, and
the self-tests pass before the change is done.

## Rules

- The framework must not depend on any one project: no references to a
  project's classes, scenes or `test/` layout in code. Examples in comments
  and `docs/` may use a game's names.
- Keep the specs in `docs/spec/` (and its README.md index) up to date with
  every change to the framework's behaviour. Designs go in `plans/`.
- Keep [docs/tests.md](docs/tests.md) up to date with every change to how
  tests or pages are written or run. Doc comments in the code describe the
  class and point there, rather than repeating it.
- Refer to the framework's classes by `class_name`, the editor plugin's
  scripts included: the editor loads class names before plugins, even on a
  first launch. Entry points loaded by path (`runner.gd`, `cli_runner.gd`,
  `test_plugin.gd`) have none; nothing is `preload`ed.
- Null checks are written `if x:` / `if not x:`.
- Doc comments (`##`) on classes and public members describe behaviour, not
  history. Prefer descriptive code and names over comments.
