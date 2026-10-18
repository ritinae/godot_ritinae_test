# Steps

A test is a tree of named steps (`it`) in groups (`describe`), with hooks
that run around them. The test adds them in `spec()`, and they run in order,
each awaited, so a step may wait for the game.

## Building the tree

```gdscript
func spec() -> void:
	describe("the economy loop", func():
		before_all(func(): hall = me.town_hall())

		it("trains a worker", func():
			me.select([hall])
			me.run_command("train_worker")
			expect("charge 50 food for a worker", economy.should_have(me, "food", 150)),
		),
	)
```

- `describe(name, body)` calls `body` right away. The `it()`, `describe()`
  and hook calls made inside it go into that group.
- `it(name, body)` adds a step. Its body runs later, when the tree runs.
- The top level of `spec()` works like a describe body without a name: it
  may hold several groups, steps and hooks.
- A helper method may add a group too, with a `describe()` inside, when it's
  called from a describe body.
- Steps and groups run in the order they were added. Hooks may come anywhere
  in a body; their place doesn't change when they run.
- A describe body runs while `spec()` builds the tree, before any hook or
  step. It must not await: what it calls after its first await comes after
  the tree is built.
- `it()`, `describe()` or a hook called while no tree is being built (inside
  a step or hook, or after an await in a describe body) adds nothing and
  fails with `FAIL it("<name>") is called in spec() or a describe body`
  (named after the call: `describe("<name>")`, `before_each()`, ...). The
  step or describe body it was called from goes on.
- A step can't end inside a block, such as a `for` loop's body. Move the
  loop into a method and call that last.

## Running the steps

- Before a step runs, its path prints: `STEP outer > inner > step`. The
  top level adds no name to the path (`STEP top-level step`).
- Each step is awaited before the next starts, and a step may await (for
  example `await wait_seconds(30)`).
- Steps share the test's state. What one step sets for a later one must be
  a script-level variable: a lambda gets its own copy of a local.
- After each step, assertions made in it that never reached an expect call
  fail (see the checks spec).
- A test whose tree has no steps fails with
  `FAIL the test has at least one step (it)`, and none of its hooks run.
  Hooks and groups don't count as steps.

## Hooks

- `before_all(body)` runs once, before the group's first step;
  `after_all(body)` once, after its last. Each set prints its own line first:
  `STEP outer (before all)` / `STEP outer (after all)`; at the top level,
  just `STEP (before all)` / `STEP (after all)`. Assertions they leave
  unchecked fail after them.
- `before_each(body)` and `after_each(body)` wrap every step of the group,
  nested groups included. Outer `before_each` hooks run first and outer
  `after_each` hooks last. They count as part of the step: their checks
  print under its `STEP` line.
- Hooks are awaited like steps, so they may wait too.

For an outer group with all four hooks and an inner group with
`before_each` and `after_each`, a step in the inner group runs:
outer before_each, inner before_each, the step, inner after_each, outer
after_each.

## Tests without steps

A test may override `run()` instead of `spec()` and check with `check()`. It
prints no `STEP` lines. Assertions it leaves unchecked fail when it ends.
Prefer `spec()`.

## Waiting

- `wait_frames(n)` waits n process frames; `wait_seconds(s)` waits
  `round(s × 60)` frames. Await them.

## Code

- `base_test.gd`: `spec()`, `describe()`, `it()`, the hooks, `run()`,
  waiting

## Tests

- `tests/spec_steps.gd`
- `tests/spec_groups_only.gd`, `tests/spec_empty.gd`
- `tests/spec_top_level.gd`
- `tests/spec_outside_collection.gd`, `tests/spec_await_in_describe.gd`
- `tests/hooks_order.gd`, `tests/hooks_without_steps.gd`
