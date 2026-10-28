extends SceneTree
## Runs a project's tests, several at a time, and sums up which passed.
##
## Each test runs in its own process through runner.gd; results print in test
## order. run_tests.sh starts it once the project is imported:
##   godot --headless --no-header --script res://addons/ritinae_test/cli_runner.gd -- [filter...] [-v] [--tests dir] [-j n]
## How tests are run: addons/ritinae_test/docs/tests.md.

const TestQueue := preload("res://addons/ritinae_test/src/test_queue.gd")
const TestRun := preload("res://addons/ritinae_test/src/test_run.gd")
const TestSuite := preload("res://addons/ritinae_test/src/test_suite.gd")

## The lines of a failed test's output that are shown under it.
const FAILURE_LINES := "^info|^STEP|^FAIL|SCRIPT ERROR|ERROR:|^\\s+at:"
const VERBOSE_LINES := "^(STEP|PASS|FAIL|info)"

var _dir := ""
var _names := PackedStringArray()
var _verbose := false
## The finished runs' results by test index, until they are reported.
var _results := { }
var _reported := 0
var _failed := PackedStringArray()
var _failure_lines := RegEx.create_from_string(FAILURE_LINES)
var _verbose_lines := RegEx.create_from_string(VERBOSE_LINES)


func _initialize() -> void:
	# The tests run in other processes; this one only waits for them.
	Engine.max_fps = 30
	var exit_code := _start(OS.get_cmdline_user_args())
	if exit_code >= 0:
		quit(exit_code)


## Starts the run and returns -1, or returns the exit code when there is
## nothing to run.
func _start(args: PackedStringArray) -> int:
	_dir = TestSuite.tests_dir()
	var jobs := TestSuite.jobs()
	var filters := PackedStringArray()
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "-v":
			_verbose = true
		elif arg == "--tests" or arg == "-j" or arg == "--jobs":
			i += 1
			var value := args[i] if i < args.size() else ""
			if arg == "--tests":
				if value.is_empty():
					print("--tests needs a folder")
					return 2
				_dir = "res://" + value.trim_prefix("res://").trim_suffix("/")
			else:
				if not value.is_valid_int() or value.to_int() < 1:
					print("-j needs a positive number")
					return 2
				jobs = value.to_int()
		elif arg.begins_with("-"):
			print("Unknown option %s" % arg)
			return 2
		else:
			filters.append(arg)
		i += 1
	if not DirAccess.dir_exists_absolute(_dir):
		print("No tests folder %s" % _dir.trim_prefix("res://"))
		return 1
	_names = TestSuite.find(_dir, filters)
	if _names.is_empty():
		print("\nNo tests matched.")
		return 1

	var queue := TestQueue.new()
	queue.jobs = jobs
	queue.test_finished.connect(_on_test_finished)
	queue.finished.connect(_finish)
	root.add_child(queue)
	var paths := PackedStringArray()
	for name in _names:
		paths.append(TestSuite.path_of(_dir, name))
	queue.start(paths)
	return -1


func _on_test_finished(path: String, run: TestRun) -> void:
	_results[_names.find(path.trim_prefix(_dir + "/").trim_suffix(".gd"))] = {
		"lines": run.lines,
		"summary": run.summary(),
		"passed": run.passed(),
	}
	while _reported in _results:
		_report(_names[_reported], _results[_reported])
		_results.erase(_reported)
		_reported += 1


func _report(name: String, result: Dictionary) -> void:
	var shown := _verbose_lines
	if result.passed:
		print("PASS %s (%s)" % [name, result.summary])
		if not _verbose:
			return
	else:
		print("FAIL %s (%s)" % [name, result.summary])
		_failed.append(name)
		shown = _failure_lines
	for line: String in result.lines:
		if shown.search(line):
			print("    " + line)


func _finish() -> void:
	print("")
	if _failed.is_empty():
		print("All %d tests passed." % _names.size())
		quit(0)
	else:
		print("%d of %d tests failed: %s" % [_failed.size(), _names.size(), " ".join(_failed)])
		quit(1)
