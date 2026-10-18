# describe() with a body lambda

`describe()` takes a name and a body lambda instead of variadic children. Calls
to `it()`, `describe()` and the hooks inside the body add themselves to the
describe being built. The tree that `_run_spec()` runs stays the same; only how
it's built changes.

## How a test reads

```gdscript
func spec() -> void:
	describe("the economy loop", func():
		before_all(func():
			hall = me.town_hall()
			bush = map.nearest_resource("food", hall))

		it("forages berries and trains a worker", func():
			me.select([hall])
			me.run_command("train_worker")
			expect("charge 50 food for a worker", economy.should_have(me, "food", 150)))

		describe("with a lumbermill", func():
			before_each(func(): ...)
			it("chops wood", func(): ...)))
```

The steps and hooks are statements on their own lines. They aren't arguments
separated by commas, so the trailing-comma and `),` layout of the variadic form
goes away, and the formatter treats the describe body like any other block.

## API

- `describe(name: String, body: Callable) -> void`: starts a group, calls
  `body` right away (synchronously), then adds the group to the group around it.
- `it(name, body) -> void` and `before_all` / `before_each` / `after_each` /
  `after_all(body) -> void`: add a step or hook to the innermost group being
  collected. None of them, `describe()` included, return anything.
- `spec() -> void`: collection runs in it. Its top level works like the body of
  a describe without a name: it may hold several `describe()`s and `it()`s.
  The name of the root group isn't part of any path, so `STEP` lines stay
  `STEP outer > step`.

Hooks may come anywhere in a body, as they can now. Their order in the body
doesn't matter, but steps and groups run in the order they were added.

## Collecting

`base_test.gd` keeps a stack of the groups being built (`_collecting`, an array
of the same `{ name, children }` dictionaries as now):

1. `run()` pushes a root group, calls `spec()`, then pops the root. After that
   the stack is empty.
2. `describe()` pushes a new group, calls `body`, pops the group and appends
   it to the new top of the stack.
3. `it()` and the hooks append `{ name, body }` / `{ hook, body }` to the top
   of the stack.
4. `run()` counts steps as now (no steps: fail) and awaits
   `_run_spec(root)`. `_run_spec()` leaves an empty root name out of the path,
   including in the root's own `(before all)` / `(after all)` lines.

### Misuse

- `it()`, a hook or `describe()` called while nothing is being collected (inside
  a step or hook body, or in a describe body that awaited and resumed after
  collection ended) fails the test with
  `check("it(\"<name>\") is called in spec() or a describe body", false)`
  (named after the call: `it`, `before_each`, ...) and adds nothing.
- A describe body that `await`s gives control back at its first await. The rest
  of the body runs only after collection has ended, so its calls fail as above.
  Doc: describe bodies must not await.
- Code in a describe body other than the calls above runs during collection,
  before any hook or step runs. Doc: set up state in `before_all` /
  `before_each`, not in the describe body. A local in a describe body is
  copied into each lambda that uses it, so it's only good for values that
  never change. Shared state still goes in script-level variables.

## Migration

One change, with no compatibility layer. A `describe()` that took both forms
would have to guess from the type of its second argument, and the variadic
form would stay around.

- Every `func spec() -> Dictionary: return describe(...)` becomes
  `func spec() -> void: describe(..., func(): ...)`, with the children as
  statements and their trailing commas removed. 69 files: `test/`,
  `addons/ritinae_iso_sprite_generator/tests/`,
  `addons/ritinae_editor_tools/tests/` and this addon's self-tests. Use a
  one-off conversion script (kept out of the repo) or convert by hand per
  folder, then run the formatter over the converted files.
- Tests that override `run()` don't change.
- Project base tests that override `spec()` or call `describe()` are updated
  the same way. `test/base_test.gd` doesn't, but check it.

## Output contract

It doesn't change: the same `STEP` / `PASS` / `FAIL` / `RESULT` lines in the
same order. Every existing `.expected` file must still match after its `.gd`
is converted. The only new lines are the misuse `FAIL`s.

## Self-tests

- Convert `hooks_order`, `hooks_without_steps`, `spec_steps`,
  `spec_groups_only` and the `expect_*` / `page_checks` tests. Their
  `.expected` stay the same.
- `spec_empty` (no `spec()`) is unchanged and still fails.
- New `spec_top_level`: `spec()` with two top-level describes and a top-level
  `it()`, plus a top-level `before_all`. Expects paths without a root name.
- New `spec_outside_collection`: a step that calls `it()`. Expects the misuse
  `FAIL`, and the step it tried to add never runs.
- New `spec_await_in_describe`: a describe body that awaits before an `it()`.
  Expects the misuse `FAIL` once the body resumes.

## Docs

- `docs/tests.md`: the example under "Writing a test", the Hooks section
  ("Hooks go into a `describe` body ..."), and new rules: describe bodies don't
  await or do setup, and top-level `spec()` may hold several groups. Drop the
  advice about trailing commas and block-ending steps if the new form makes it
  moot. "A step can't end inside a block" still applies inside step bodies.
- Addon `AGENTS.md`: `base_test.gd` "collects the `describe`/`it`/hook tree
  from `spec()`".
- Doc comments on `describe()`, `it()`, the hooks and `spec()` in
  `base_test.gd`.

