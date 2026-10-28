extends RTTest
## RTTestRun runs a test file in its own headless Godot process, collects its
## output as it arrives and judges it as run_tests.sh does: the test passes
## when the process exits with 0 and prints no SCRIPT ERROR. A run can be
## stopped, and fails when it takes longer than its timeout.

const DIR := "res://addons/ritinae_test/tests/fixtures/suite"


func _init() -> void:
	# The test waits for other processes in real time, while game time runs as
	# fast as the frames do.
	max_seconds = 100000.0


func spec() -> void:
	describe("a finished run", func():
		it("passes when the test passes", func():
			var run := await _run("test_passes")
			check("the run passed", run.passed())
			check("the summary is the test's counts", run.summary() == "1 passed, 0 failed")
			check("the test's checks are among its lines", "PASS passes" in run.lines)
			check("the exit code is 0", run.exit_code == 0),
		)
		it("fails when the test fails", func():
			var run := await _run("test_fails")
			check("the run failed", not run.passed())
			check("the summary is the test's counts", run.summary() == "0 passed, 1 failed")
			check("the failing check is among its lines", "FAIL fails" in run.lines),
		)
		it("fails on a script error, though the test's checks passed", func():
			var run := await _run("sub/test_script_error")
			check("the exit code is 0", run.exit_code == 0)
			check("the run failed", not run.passed())
			check(
				"the script error is among its lines",
				Array(run.lines).any(func(line: String) -> bool:
					return line.contains("SCRIPT ERROR"),
				),
			),
		)
		it("fails with the exit code when the test doesn't load", func():
			var run := await _run("test_missing")
			check("the run failed", not run.passed())
			check("the summary is the exit code", run.summary() == "exit code 1"),
		)
		it("emits each line it collects", func():
			var run := RTTestRun.new(RTTestSuite.path_of(DIR, "test_passes"))
			var received := []
			run.line_received.connect(func(line: String): received.append(line))
			run.start()
			await run.finished
			check("every line was emitted, in order", received == Array(run.lines)),
		),
	)
	describe("a run that doesn't finish", func():
		it("fails as stopped when stopped", func():
			var run := RTTestRun.new(RTTestSuite.path_of(DIR, "test_slow"))
			run.start()
			await wait_frames(5)
			check("the run is running", run.running)
			run.stop()
			await run.finished
			check("the run is no longer running", not run.running)
			check("the run failed", not run.passed())
			check("the summary says it was stopped", run.summary() == "stopped"),
		)
		it("fails as timed out after its timeout", func():
			var run := await _run("test_slow", 1.0)
			check("the run failed", not run.passed())
			check(
				"the summary says it timed out",
				run.summary() == "timed out after 1 real seconds",
			),
		),
	)


func _run(name: String, timeout_seconds := 300.0) -> RTTestRun:
	var run := RTTestRun.new(RTTestSuite.path_of(DIR, name))
	run.timeout_seconds = timeout_seconds
	run.start()
	await run.finished
	return run
