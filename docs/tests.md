# Writing tests

Tests are headless Godot runs. Each test is a `test_*.gd` file in a project's
tests folder (`test/` by default, subfolders included). It extends the
project's own base test, which extends this framework's `RTTest`
(`src/base_test.gd`, so `extends RTTest`) and adds what the project's tests
need: the scene they run in (`create_scene()`), references into it, helpers
and pages.

## Running tests

In the editor, enable the plugin (Project Settings → Plugins) and open the
**Tests** main screen, next to 2D, 3D and Script. It lists the tests and runs
the listed ones with **Run**, or one with a double-click. The filter keeps the
tests whose name contains any of its words. Each test shows PASS or FAIL with
its counts, and selecting one shows its output. **Stop** stops the running
test and the ones waiting. When the editor saves before running the project
(Editor Settings → Run → Auto Save), the screen saves scenes and scripts
first, since tests run from the files on disk.

The tests folder is `test/` unless the project setting **Ritinae Test → Run →
Tests Dir** (`ritinae_test/run/tests_dir`) names another. Both the Tests
screen and `run_tests.sh` use it, and `--tests` overrides it.

From a shell:

```sh
addons/ritinae_test/run_tests.sh                 # all tests in test/
addons/ritinae_test/run_tests.sh economy         # tests whose name contains "economy"
addons/ritinae_test/run_tests.sh gameplay/camp   # tests in a folder (and its subfolders)
addons/ritinae_test/run_tests.sh camp economy    # tests whose name contains "camp" or "economy"
addons/ritinae_test/run_tests.sh -v              # also print every step, check and info line
addons/ritinae_test/run_tests.sh --tests dir     # look for tests in dir instead of the tests folder
```

Set `GODOT` to use a different Godot binary. To run one test file without
the script:

```sh
godot --headless --fixed-fps 60 --script res://addons/ritinae_test/runner.gd -- res://test/gameplay/test_economy.gd
```

## Writing a test

A test adds its steps in `spec()` with `describe()` and `it()`. A describe
takes a body lambda, and the `it()`, `describe()` and hook calls in that body
go into its group:

```gdscript
extends "res://test/base_test.gd"
## What this test covers.

var hall: BuildingPage


func spec() -> void:
	describe("the economy loop", func():
		before_all(func(): hall = me.town_hall())

		it("trains a worker", func():
			me.select([hall])
			me.run_command("train_worker")
			expect("charge 50 food for a worker", economy.should_have(me, "food", 150))
			await wait_seconds(30)
			expect("train the worker", me.should_have_unit_count(4)),
		),
	)
```

- Steps run in order, and each is awaited, so a step may `await`. Each step
  prints its path (`STEP the economy loop > trains a worker`) before its
  checks.
- The top level of `spec()` works like a describe body without a name. It
  may hold several groups, steps and hooks, and adds nothing to the paths.
- A describe body runs right away, while `spec()` collects the tree, before
  any hook or step. It only adds steps, groups and hooks: set things up in
  `before_all` / `before_each`, and don't `await` in it. Calls to `it()`,
  `describe()` or a hook made after an await, or inside a step or hook, fail
  the test.
- A helper may add a group too: `func _suite_at(name: String) -> void:` with
  a `describe()` inside, called from a describe body.
- Steps share the test's state. Anything one step sets for a later one must
  be a script-level variable, because a lambda gets its own copy of a local.
- A step can't end inside a block, such as a `for` loop's body. Move the loop
  into a method and call that last.
- A test without any step fails.
- Don't give a test member the name of a member of its base test (such as a
  page). The two clash.

### Hooks

Hooks go into a describe body (or the top level of `spec()`) next to its
steps, in any order:

- `before_all` runs once before the group's first step, `after_all` once after
  its last. Each prints its own `STEP <path> (before all)` / `(after all)`
  line; at the top level just `STEP (before all)` / `STEP (after all)`.
- `before_each` and `after_each` wrap every step of the group, nested groups
  included. Outer `before_each` hooks run first and outer `after_each` hooks
  last. They count as part of the step and print under its `STEP` line.

### Checks

A test acts and checks through pages. The test says what it intends; the
page's check says what it saw:

```gdscript
expect("not be able to build on top of the other tower", map.should_be_blocked(spot, TOWER))
```

This prints `PASS Expected to not be able to build on top of the other tower`,
or `FAIL Expected to ..., but spot (12, 4) was free`.

- `expect(intent, a)`: the assertion holds now.
- `await expect_within(seconds, intent, a)`: it comes to hold on some frame
  within the given game seconds.
- `await expect_throughout(seconds, intent, a)`: it holds on every frame for
  the given game seconds.
- `all_of(a, b, ...)`: several assertions as one; reports the first part that
  fails.
- `each_of(items, func(x): return x.should_...())`: one check per item, as one.
- `wait_frames(n)` / `wait_seconds(s)`: let the game run. Await them.

An assertion that never reaches an expect call fails the step (or hook) it
was made in.

Plain `check(description, condition)` on nodes is only for checks of how the
game is put together rather than of game state: scene wiring, components,
data. A test may also override `run()` instead of `spec()` and use `check()`;
prefer `spec()`.

## Writing pages

A page (`extends RTPage`) wraps something a test acts on or checks, and hides
how it's built, so the test reads like what it means. When a test needs
something new, extend a page rather than reaching into nodes from the test.

- Checks start with `should_` and return a `RTAssertion` made with
  `_assert()`. Actions (`place()`, `set_wood()`) and queries (`wood_of()`) are
  plain methods.
- A check does its actions and takes its baselines when it's called. Only the
  looking goes in the probe, which may run on many frames (`expect_within`).
- The probe returns `""` while the check holds, else what was seen, with
  actual values (`"the player had 470 wood"`). A check of several things says
  which part failed.
- A probe doesn't call `should_` checks. Those make tracked assertions that
  would never reach an expect call. Share a plain helper between checks
  instead.

```gdscript
func should_be_blocked(cell: Vector2i, kind: Building.Kind) -> RTAssertion:
	return _assert(func():
		return "" if not _fits(cell, kind) else "spot %s was free" % cell)
```

## How a test runs

`run_tests.sh` imports the project if needed, then runs each test file through
`runner.gd` at a fixed 60 fps. The runner adds the scene from
`create_scene()` (if any) and the test to the tree, calls `run()` and exits
with 0 when every check passed and at least one did. A test fails as hung
after `max_seconds` (180) game seconds. A script error stops a test early.
`run_tests.sh` counts any `SCRIPT ERROR` in the output as a failure. Tests
are loaded after the autoloads exist, so they can name the project's classes
directly.

## Framework self-tests

The framework's own tests are in `addons/ritinae_test/tests/`. Each
`<name>.gd` there has a `<name>.expected` next to it. That file holds the exit
code (`exit N`) and, in order, the `STEP`, `PASS`, `FAIL`, `RESULT` and
`SCRIPT ERROR` lines the test should print. Many of them are meant to fail.
When you change the framework, add or update a self-test and run
`tests/run_self_tests.sh`.
