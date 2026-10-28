extends RTTest
## editor_runner.gd, the Tests screen's test session, runs as many tests at a
## time as the jobs setting says and words the screen's status: the progress
## while tests run and a summary once they have.

const DIR := "res://addons/ritinae_test/tests/fixtures/suite"


func _init() -> void:
	# The test waits for other processes in real time, while game time runs as
	# fast as the frames do.
	max_seconds = 100000.0


func spec() -> void:
	describe("the editor runner", func():
		var saved: Variant = ProjectSettings.get_setting(RTTestSuite.JOBS_SETTING)
		after_all(func(): ProjectSettings.set_setting(RTTestSuite.JOBS_SETTING, saved))

		it("runs as many tests at a time as the jobs setting says", func():
			ProjectSettings.set_setting(RTTestSuite.JOBS_SETTING, 1)
			var runner := _runner()
			runner.start(DIR, PackedStringArray(["test_slow", "test_passes"]))
			await wait_frames(5)
			check("one test runs at a time", runner.jobs == 1)
			check(
				"the progress counts the running and done tests",
				runner.progress_text() == "Running 1, 0 of 2 done",
			)
			runner.stop()
			await runner.finished,
		)
		it("sums up a run with failures", func():
			ProjectSettings.set_setting(RTTestSuite.JOBS_SETTING, 0)
			var runner := _runner()
			runner.start(DIR, PackedStringArray(["test_fails", "test_passes"]))
			await runner.finished
			check("one per CPU runs at a time at 0", runner.jobs == OS.get_processor_count())
			check(
				"the progress counts every test done",
				runner.progress_text() == "Running 0, 2 of 2 done",
			)
			check(
				"the summary counts the failures",
				runner.summary_text() == "1 of 2 tests failed.",
			),
		)
		it("sums up a passing run", func():
			var runner := _runner()
			runner.start(DIR, PackedStringArray(["test_passes"]))
			await runner.finished
			check("the summary says all passed", runner.summary_text() == "All 1 tests passed."),
		),
	)


func _runner() -> RTEditorRunner:
	var runner := RTEditorRunner.new()
	return runner
