extends Node
## Base for headless tests: describe/it steps, checks, pass/fail counts and
## waiting. A project's own base test extends this with what its tests need (the
## scene they run in, references into it, helpers), and its tests extend that.
##
## A test returns a tree of steps from spec(), built with describe() and it():
##
##   func spec() -> Dictionary:
##   	return describe("placing buildings",
##   		it("places a foundation", func():
##   			check("...", true)),
##   		describe("refusals",
##   			it("refuses a blocked spot", func():
##   				check("...", true))),
##   	)
##
## The steps run in order, each awaited, so a step may await. Each prints its
## path ("STEP placing buildings > refusals > refuses a blocked spot") before
## its checks. Steps share the test's state; anything one step sets for a later
## one must be a script-level variable, since a lambda gets its own copy of a
## local variable. A test without a single step fails.
##
## A test can instead override run() (which may await) and check with check().
## Either way, the process exits with 0 when every check passed and at least
## one did.

const FPS := 60

## Game seconds after which the test is failed as hung (e.g. it awaits
## something that never happens).
var max_seconds := 180.0

## Number of checks that passed and failed so far; the runner reports them.
var passed := 0
var failed := 0


## The test body: runs the steps from spec(). A test may override it instead
## of spec(). May await.
func run() -> void:
	var tree := spec()
	if _count_steps(tree) == 0:
		check("the test has at least one step (it)", false)
		return
	await _run_spec(tree)


## The test's steps, built with describe() and it(). None by default.
func spec() -> Dictionary:
	return {}


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


## A group of steps (it) and groups (describe), run in order.
func describe(name: String, ...children: Array) -> Dictionary:
	return {"name": name, "children": children}


## One step. Its body isn't run here; run() runs the whole tree once it's built.
func it(name: String, body: Callable) -> Dictionary:
	return {"name": name, "body": body}


## Runs a step, or a describe's steps and groups in order.
func _run_spec(node: Dictionary, path: Array = []) -> void:
	path = path + [node.name]
	if node.has("body"):
		print("STEP ", " > ".join(path))
		await node.body.call()
		return
	for child in node.children:
		await _run_spec(child, path)


## The number of steps (it) in a tree; 0 for an empty spec().
func _count_steps(node: Dictionary) -> int:
	if node.has("body"):
		return 1
	var steps := 0
	for child in node.get("children", []):
		steps += _count_steps(child)
	return steps
