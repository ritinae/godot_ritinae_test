@tool
class_name RTTestQueue
extends RefCounted
## Test files run several at a time, each as an RTTestRun.
##
## Call start() with the tests' paths and await finished, keeping a reference
## meanwhile. At most jobs runs go at once, started in the order given. How
## tests are run: addons/ritinae_test/docs/tests.md.

## Emitted when a test's run is made and about to start.
signal test_started(path: String, run: RTTestRun)
## Emitted when a test's run has ended; the queue lets go of it after this.
signal test_finished(path: String, run: RTTestRun)
## Emitted once every test given to start() has finished or was stopped.
signal finished

## How many tests run at a time.
var jobs := 1
## Real seconds after which each test's process is killed.
var timeout_seconds := 300.0
var running := false

var _waiting := PackedStringArray()
var _runs: Array[RTTestRun] = []


## Runs the tests at paths, unless tests are running. The first ones start on
## the next frame.
func start(paths: PackedStringArray) -> void:
	if running:
		return
	running = true
	_waiting = paths.duplicate()
	_fill.call_deferred()


## Stops the running tests, which fail as stopped, and drops the waiting ones.
func stop() -> void:
	_waiting.clear()
	for run in _runs:
		run.stop()


## The runs going now, in the order they started.
func runs() -> Array[RTTestRun]:
	return _runs.duplicate()


func _fill() -> void:
	while _runs.size() < maxi(jobs, 1) and not _waiting.is_empty():
		var run := RTTestRun.new(_waiting[0])
		_waiting.remove_at(0)
		run.timeout_seconds = timeout_seconds
		run.finished.connect(_on_run_finished)
		_runs.append(run)
		test_started.emit(run.path, run)
		run.start()
	if _runs.is_empty() and running:
		running = false
		finished.emit()


func _on_run_finished() -> void:
	for run in _runs.duplicate():
		if not run.running:
			_runs.erase(run)
			test_finished.emit(run.path, run)
	_fill()
