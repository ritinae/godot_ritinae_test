extends RTTest
## RTTestQueue runs test files as RTTestRuns, at most jobs at a time, starting
## them in the order given and reporting each as it starts and finishes. Stop
## stops the running tests and drops the waiting ones.

const DIR := "res://addons/ritinae_test/tests/fixtures/suite"

var _started := PackedStringArray()
var _finished := PackedStringArray()
var _summaries := { }
var _most_at_once := 0


func _init() -> void:
	# The test waits for other processes in real time, while game time runs as
	# fast as the frames do.
	max_seconds = 100000.0


func spec() -> void:
	describe("a queue", func():
		it("runs every test, at most jobs at a time", func():
			var paths := _paths(["test_passes", "test_fails", "sub/test_script_error"])
			var queue := _queue(2)
			queue.start(paths)
			check("the queue is running", queue.running)
			await queue.finished
			check("the queue is no longer running", not queue.running)
			check("every test started", _sorted(_started) == _sorted(paths))
			check("every test finished", _sorted(_finished) == _sorted(paths))
			check("two tests ran at once", _most_at_once == 2)
			check(
				"each run was reported finished",
				_summaries[paths[0]] == "1 passed, 0 failed"
				and _summaries[paths[1]] == "0 passed, 1 failed",
			),
		)
		it("runs one test at a time, in order, with one job", func():
			var paths := _paths(["test_passes", "test_fails", "sub/test_script_error"])
			var queue := _queue(1)
			queue.start(paths)
			await queue.finished
			check("the tests started in order", _started == paths)
			check("the tests finished in order", _finished == paths)
			check("one test ran at a time", _most_at_once == 1),
		)
		it("finishes at once with nothing to run", func():
			var queue := _queue(2)
			queue.start(PackedStringArray())
			await queue.finished
			check("nothing started", _started.is_empty())
			check("the queue is no longer running", not queue.running),
		),
	)
	describe("a stopped queue", func():
		it("stops the running tests and drops the waiting ones", func():
			var paths := _paths(["test_slow", "test_slow", "test_passes"])
			var queue := _queue(2)
			queue.start(paths)
			await wait_frames(5)
			check("two tests are running", queue.runs().size() == 2)
			queue.stop()
			await queue.finished
			check("only the running tests started", _started == paths.slice(0, 2))
			check(
				"the running tests finished as stopped",
				_finished.size() == 2 and _summaries[paths[0]] == "stopped",
			)
			check("no test is running", queue.runs().is_empty()),
		),
	)


func _queue(jobs: int) -> RTTestQueue:
	_started.clear()
	_finished.clear()
	_summaries.clear()
	_most_at_once = 0
	var queue := RTTestQueue.new()
	queue.jobs = jobs
	queue.test_started.connect(func(path: String, _run: RTTestRun):
		_started.append(path)
		_most_at_once = maxi(_most_at_once, _started.size() - _finished.size()),
	)
	queue.test_finished.connect(func(path: String, run: RTTestRun):
		_finished.append(path)
		_summaries[path] = run.summary(),
	)
	return queue


func _paths(names: Array) -> PackedStringArray:
	var paths := PackedStringArray()
	for name: String in names:
		paths.append(RTTestSuite.path_of(DIR, name))
	return paths


func _sorted(paths: PackedStringArray) -> PackedStringArray:
	var copy := paths.duplicate()
	copy.sort()
	return copy
