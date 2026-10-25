extends SceneTree
## Runs one headless test file: adds the scene the test runs in and the test to
## the tree, calls the test's run() and exits with 0 when every check passed.
##
##   godot --headless --fixed-fps 60 --script res://addons/ritinae_test/runner.gd -- res://test/gameplay/test_economy.gd
##
## The test is an RTTest (src/base_test.gd), with run(), create_scene(),
## max_seconds and passed/failed counts. The runner only puts the scene from
## create_scene() (if any) around it.
##
## A script error inside run() stops it early but doesn't fail the exit code;
## run_tests.sh treats any SCRIPT ERROR in the output as a failure.

var _test: Node
var _elapsed := 0.0
var _finished := false


func _process(delta: float) -> bool:
	if not _test or _finished:
		return false
	_elapsed += delta
	if _elapsed > _test.max_seconds:
		_test.check("test finished within %d game seconds" % _test.max_seconds, false)
		_finish()
	return false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_abort("no test given; pass its path after --, e.g. -- res://test/test_example.gd")
		return
	var script: Script = load(args[0])
	if not script or not script.can_instantiate():
		_abort("can't load test %s" % args[0])
		return
	_test = script.new() as Node
	if not _test or not _test.has_method("run"):
		_abort("%s is not a test; it should extend RTTest" % args[0])
		return
	var scene: Node = _test.create_scene()
	if scene:
		root.add_child(scene)
	root.add_child(_test)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await _test.run()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	# Also for tests that override run(), whose steps don't check this.
	_test.expectations.check_unused()
	print("RESULT: %d passed, %d failed" % [_test.passed, _test.failed])
	quit(1 if _test.failed > 0 or _test.passed == 0 else 0)


func _abort(message: String) -> void:
	push_error("runner: " + message)
	quit(1)
