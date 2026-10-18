extends Node
## Base for headless tests: describe/it steps, checks, pass/fail counts and
## waiting. A project's own base test extends this with what its tests need (the
## scene they run in, references into it, helpers), and its tests extend that.
##
## A test adds its steps in spec() (with describe(), it() and the hooks), or
## overrides run() and checks with check(). How to write tests:
## addons/ritinae_test/docs/tests.md.

const FPS := 60

## Game seconds after which the test is failed as hung (e.g. it awaits
## something that never happens).
var max_seconds := 180.0

## Number of checks that passed and failed so far; the runner reports them.
var passed := 0
var failed := 0

## Checks assertions; pages and the runner reach it here, tests through
## expect() and all_of().
var expectations := RTExpect.new(self)

## The groups being built, innermost last; empty once spec() has returned.
var _collecting: Array[Dictionary] = []


## The test body: runs the steps from spec(). A test may override it instead
## of spec(). May await.
func run() -> void:
	var tree := { "name": "", "children": [] }
	_collecting.push_back(tree)
	spec()
	_collecting.pop_back()
	if _count_steps(tree) == 0:
		check("the test has at least one step (it)", false)
		return
	await _run_spec(tree)


## The test's steps, added with describe(), it() and the hooks. Its top level
## works like a describe body without a name. None by default.
func spec() -> void:
	pass


## The scene the test runs in, added to the tree before the test. None by
## default; a project's base test overrides this.
func create_scene() -> Node:
	return null


func check(description: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS " + description)
	else:
		failed += 1
		print("FAIL " + description)


func wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_seconds(seconds: float) -> void:
	await wait_frames(roundi(seconds * FPS))


## Checks that an assertion holds now: "Expected to <intent>[, but <what was seen>]".
func expect(intent: String, a: RTAssertion) -> void:
	expectations.now(intent, a)


## Checks that an assertion comes to hold on some frame within the given game
## seconds. Await it.
func expect_within(seconds: float, intent: String, a: RTAssertion) -> void:
	await expectations.within(seconds, intent, a)


## Checks that an assertion holds on every frame for the given game seconds.
## Await it.
func expect_throughout(seconds: float, intent: String, a: RTAssertion) -> void:
	await expectations.throughout(seconds, intent, a)


## Several assertions as one; reports the first part that fails.
func all_of(...parts: Array) -> RTAssertion:
	return expectations.all_of(parts)


## One check per item, made by `check` (item -> RTAssertion), as one; reports
## the first item that fails. each_of(builders, func(b): return b.should_be_idle())
func each_of(items: Array, check: Callable) -> RTAssertion:
	return expectations.all_of(items.map(check))


## A group of steps (it), groups (describe) and hooks: calls body right away,
## and what it calls inside body goes into the group. body must not await.
func describe(name: String, body: Callable) -> void:
	if not _can_add("describe", name):
		return
	var group := { "name": name, "children": [] }
	_collecting.push_back(group)
	body.call()
	_collecting.pop_back()
	_add(group)


## One step. Its body isn't run here; run() runs the whole tree once it's built.
func it(name: String, body: Callable) -> void:
	if _can_add("it", name):
		_add({ "name": name, "body": body })


## Runs once, before the first step of the describe it's in.
func before_all(body: Callable) -> void:
	_add_hook("before_all", body)


## Runs before every step of the describe it's in, nested describes included.
func before_each(body: Callable) -> void:
	_add_hook("before_each", body)


## Runs after every step of the describe it's in, nested describes included.
func after_each(body: Callable) -> void:
	_add_hook("after_each", body)


## Runs once, after the last step of the describe it's in.
func after_all(body: Callable) -> void:
	_add_hook("after_all", body)


func _add_hook(hook: String, body: Callable) -> void:
	if _can_add(hook, ""):
		_add({ "hook": hook, "body": body })


## Whether a describe, step or hook can be added now: only while spec() is
## collected. Fails the test otherwise (e.g. it() inside a step).
func _can_add(call: String, name: String) -> bool:
	if _collecting:
		return true
	var what := "%s(\"%s\")" % [call, name] if name else call + "()"
	check(what + " is called in spec() or a describe body", false)
	return false


func _add(child: Dictionary) -> void:
	_collecting.back().children.append(child)


## Runs a step, or a describe with its hooks. `befores` and `afters` are the
## each-hooks of the describes around it: outer before_each hooks run first,
## outer after_each hooks run last.
func _run_spec(node: Dictionary, path: Array = [], befores: Array = [], afters: Array = []) -> void:
	if node.name:
		path = path + [node.name]
	if node.has("body"):
		_print_step(path)
		for hook in befores:
			await hook.call()
		await node.body.call()
		for hook in afters:
			await hook.call()
		expectations.check_unused()
		return

	var hooks := { "before_all": [], "before_each": [], "after_each": [], "after_all": [] }
	var children := []
	for child in node.children:
		if child.has("hook"):
			hooks[child.hook].append(child.body)
		else:
			children.append(child)

	if hooks.before_all:
		_print_step(path, "(before all)")
	for hook in hooks.before_all:
		await hook.call()
	expectations.check_unused()
	for child in children:
		await _run_spec(child, path, befores + hooks.before_each, hooks.after_each + afters)
	if hooks.after_all:
		_print_step(path, "(after all)")
	for hook in hooks.after_all:
		await hook.call()
	expectations.check_unused()


## Prints the STEP line of a step, or of a describe's "(before all)" /
## "(after all)" hooks. The root's hooks print only the hook part.
func _print_step(path: Array, hooks := "") -> void:
	print("STEP ", (" > ".join(path) + " " + hooks).strip_edges())


## The number of steps (it) in a tree, hooks not counted; 0 for an empty spec().
func _count_steps(node: Dictionary) -> int:
	if node.has("body"):
		return 1
	var steps := 0
	for child in node.get("children", []):
		if not child.has("hook"):
			steps += _count_steps(child)
	return steps
