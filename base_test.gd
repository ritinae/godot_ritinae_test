extends Node
## Base for headless tests: checks, pass/fail counts and waiting. A project's
## own base test extends this with what its tests need (the scene they run in,
## references into it, helpers), and its tests extend that.
##
## A test overrides run() (which may await) and checks with check(). The
## process exits with 0 when every check passed and at least one did.

const FPS := 60

## Game seconds after which the test is failed as hung (e.g. it awaits
## something that never happens).
var max_seconds := 180.0

## Number of checks that passed and failed so far; the runner reports them.
var passed := 0
var failed := 0


## The test body, overridden by each test. May await.
func run() -> void:
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
