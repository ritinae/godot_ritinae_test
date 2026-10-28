extends RTTest
## RTTestSession runs a suite's tests by name, several at a time, keeping each
## finished test's result by name. It lists the failed tests and hands out the
## finished ones in list order, and names the running tests and their runs.

const DIR := "res://addons/ritinae_test/tests/fixtures/suite"
const NAMES := ["sub/test_script_error", "test_fails", "test_passes"]


func _init() -> void:
	# The test waits for other processes in real time, while game time runs as
	# fast as the frames do.
	max_seconds = 100000.0


func spec() -> void:
	describe("a finished session", func():
		it("keeps each test's result by name", func():
			var session := _session()
			var reported := []
			session \
					.test_finished \
					.connect(func(name: String, _result: Dictionary): reported.append(name))
			session.start(DIR, PackedStringArray(NAMES))
			await session.finished
			check("the session is no longer running", not session.is_running())
			check("every test was reported by name", _sorted(reported) == NAMES)
			check("a passing test passed", session.results["test_passes"].passed)
			check(
				"a failing test has its summary",
				session.results["test_fails"].summary == "0 passed, 1 failed",
			)
			check(
				"the failed tests are listed in list order",
				session.failed() == PackedStringArray(["sub/test_script_error", "test_fails"]),
			),
		)
		it("hands out the finished tests in list order", func():
			var session := _session()
			var taken := []
			session \
					.test_finished \
					.connect(func(_name: String, _result: Dictionary):
						taken.append_array(session.take_finished_in_order()),
					)
			session.start(DIR, PackedStringArray(NAMES))
			await session.finished
			check("every test was handed out once, in list order", taken == NAMES),
		)
		it("forgets the last run's results when started again", func():
			var session := _session()
			session.start(DIR, PackedStringArray(["test_fails"]))
			await session.finished
			session.start(DIR, PackedStringArray(["test_passes"]))
			await session.finished
			check("only the new run's result is kept", session.results.keys() == ["test_passes"]),
		),
	)
	describe("a running session", func():
		it("names its running tests and stops them", func():
			var session := _session()
			var started := []
			session.test_started.connect(func(name: String, _run: RTTestRun): started.append(name))
			session.start(DIR, PackedStringArray(["test_slow", "test_passes"]))
			check("the session is running", session.is_running())
			await wait_frames(5)
			check("both tests started, by name", started == ["test_slow", "test_passes"])
			check("the slow test is running", "test_slow" in session.running_names())
			check("its run is at hand", session.run_of("test_slow") != null)
			session.stop()
			await session.finished
			check("the slow test was stopped", session.results["test_slow"].summary == "stopped")
			check("no test is running", session.running_names().is_empty())
			check("no run is at hand", session.run_of("test_slow") == null),
		),
	)


func _session() -> RTTestSession:
	var session := RTTestSession.new()
	session.jobs = 2
	return session


func _sorted(names: Array) -> Array:
	var copy := names.duplicate()
	copy.sort()
	return copy
