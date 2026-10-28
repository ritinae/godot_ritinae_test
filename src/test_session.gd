@tool
class_name RTTestSession
extends RefCounted
## A run of a suite's tests, named as RTTestSuite names them.
##
## Call start() with the tests folder and the names and await finished,
## keeping a reference meanwhile. Each test runs in its own process, at most jobs
## at a time; results are kept by name. How tests are run:
## addons/ritinae_test/docs/tests.md.

## Emitted when a test starts running.
signal test_started(name: String, run: RTTestRun)
## Emitted when a test has finished, with its entry in [member results].
signal test_finished(name: String, result: Dictionary)
## Emitted once every test has finished or was stopped.
signal finished

## How many tests run at a time.
var jobs := 1
## The tests folder of the run, as a res:// path.
var dir := ""
## The tests of the run, in list order.
var names := PackedStringArray()
## Each finished test's lines, summary and pass, by name.
var results := { }

var _queue := RTTestQueue.new()
## The run of each running test, by name, in the order they started.
var _runs := { }
var _taken := 0


func _init() -> void:
	_queue.test_started.connect(_on_test_started)
	_queue.test_finished.connect(_on_test_finished)
	_queue.finished.connect(_on_queue_finished)


## Runs the tests with the given names under tests_dir, unless tests are
## running. The first ones start on the next frame.
func start(tests_dir: String, test_names: PackedStringArray) -> void:
	if is_running():
		return
	dir = tests_dir
	names = test_names.duplicate()
	results.clear()
	_runs.clear()
	_taken = 0
	var paths := PackedStringArray()
	for name in names:
		paths.append(RTTestSuite.path_of(dir, name))
	_queue.jobs = jobs
	_queue.start(paths)


## Stops the running tests, which fail as stopped, and drops the waiting ones.
func stop() -> void:
	_queue.stop()


## Whether tests are running, until finished is emitted.
func is_running() -> bool:
	return _queue.running


## The run of the test with the given name while it runs, else null.
func run_of(name: String) -> RTTestRun:
	return _runs.get(name)


## The names of the running tests, in the order they started.
func running_names() -> PackedStringArray:
	return PackedStringArray(_runs.keys())


## The names of the finished tests that failed, in list order.
func failed() -> PackedStringArray:
	var failed_names := PackedStringArray()
	for name in names:
		if name in results and not results[name].passed:
			failed_names.append(name)
	return failed_names


## The names of the tests that have finished, along with every test before them
## in list order, and that weren't taken before.
func take_finished_in_order() -> PackedStringArray:
	var taken := PackedStringArray()
	while _taken < names.size() and names[_taken] in results:
		taken.append(names[_taken])
		_taken += 1
	return taken


func _on_test_started(path: String, run: RTTestRun) -> void:
	var name := _name_of(path)
	_runs[name] = run
	test_started.emit(name, run)


func _on_test_finished(path: String, run: RTTestRun) -> void:
	var name := _name_of(path)
	_runs.erase(name)
	results[name] = { "lines": run.lines, "summary": run.summary(), "passed": run.passed() }
	test_finished.emit(name, results[name])


func _on_queue_finished() -> void:
	finished.emit()


func _name_of(path: String) -> String:
	return path.trim_prefix(dir + "/").trim_suffix(".gd")
