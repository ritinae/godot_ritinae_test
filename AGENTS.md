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
addons/ritinae_test/run_tests.sh [filter...] [-v] [--tests dir]   # run a project's tests (default dir: test/)
```

Set `GODOT` to use a different Godot binary.

## Files

- `runner.gd`: a `SceneTree` script that runs one test file. It adds the
  scene from the test's `create_scene()` and the test, awaits `run()`, fails
  the test as hung after `max_seconds`, and exits with 0 when every check
  passed and at least one did.
- `base_test.gd`: the base every test extends through a project's base test.
  It collects the `describe`/`it`/hook tree from `spec()` and runs it, and
  holds `check()`, the `expect` calls,
  waiting and the pass/fail counts.
- `page.gd` (`RTPage`), `assertion.gd` (`RTAssertion`) and `expect.gd`
  (`RTExpect`): pages make assertions with `_assert()`. `RTExpect` checks them
  and tracks the ones that never reach an expect call.
- `run_tests.sh`: runs every `test_*.gd` in a tests folder and summarises.
  `import.sh` (sourced by both scripts) imports the project first when the
  import cache is missing or stale.
- `plugin.cfg` and `test_plugin.gd`: an empty editor plugin that lists the
  framework in Project Settings → Plugins.
- `tests/`: the self-tests.

## Output contract

The runner's output is parsed by `run_tests.sh` and compared line by line by
the self-tests. Changing it is a breaking change:

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
- Null checks are written `if x:` / `if not x:`.
- Doc comments (`##`) on classes and public members describe behaviour, not
  history. Prefer descriptive code and names over comments.
