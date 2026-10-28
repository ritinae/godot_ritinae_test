extends RTTest
## cli_runner.gd, which run_tests.sh starts, runs the tests in a folder
## several at a time and reports each in test order: PASS or FAIL with its
## counts, a failed test's steps, failures and errors under it, and a summary.
## It exits with 0 only when every test passed, and with 2 on a bad option.

const SUITE := "addons/ritinae_test/tests/fixtures/suite"
const FAST := ["passes", "fails", "script_error"]


func spec() -> void:
	describe("a run", func():
		it("reports each test in order, then a summary", func():
			var run := _run(["--tests", SUITE] + FAST)
			check("it exits with 1", run.exit_code == 1)
			check(
				"each test is reported in order, with its counts",
				_reports(run.lines)
				== [
					"FAIL sub/test_script_error (1 passed, 0 failed)",
					"FAIL test_fails (0 passed, 1 failed)",
					"PASS test_passes (1 passed, 0 failed)",
				],
			)
			check("a failed check is shown under its test", "    FAIL fails" in run.lines)
			var lines: Array = run.lines
			check(
				"a script error is shown under its test",
				lines.any(func(line: String) -> bool: return line.begins_with("    SCRIPT ERROR:")),
			)
			check("a passing test shows no steps", not "    PASS passes" in run.lines)
			check(
				"the summary names the failed tests",
				run.lines[-1] == "2 of 3 tests failed: sub/test_script_error test_fails",
			),
		)
		it("prints the same whatever the jobs", func():
			var one := _run(["--tests", SUITE, "-j", "1"] + FAST)
			var many := _run(["--tests", SUITE, "-j", "4"] + FAST)
			check("the output is the same", one.lines == many.lines),
		)
		it("passes when every test passes, showing steps with -v", func():
			var run := _run(["--tests", SUITE, "-v", "passes"])
			check("it exits with 0", run.exit_code == 0)
			check("the passing test's checks are shown", "    PASS passes" in run.lines)
			check("the summary says all passed", run.lines[-1] == "All 1 tests passed."),
		),
	)
	describe("a run with nothing to run", func():
		it("fails when no test matches", func():
			var run := _run(["--tests", SUITE, "nothing_like_this"])
			check("it exits with 1", run.exit_code == 1)
			check("it says so", run.lines[-1] == "No tests matched."),
		)
		it("fails without the tests folder", func():
			var run := _run(["--tests", "no/such/folder"])
			check("it exits with 1", run.exit_code == 1)
			check("it names the folder", run.lines == ["No tests folder no/such/folder"]),
		)
		it("exits with 2 on a bad option", func():
			var unknown := _run(["--bogus"])
			check("an unknown option exits with 2", unknown.exit_code == 2)
			check("it names the option", unknown.lines == ["Unknown option --bogus"])
			var jobs := _run(["-j", "0"])
			check("a -j below 1 exits with 2", jobs.exit_code == 2)
			check("it says why", jobs.lines == ["-j needs a positive number"]),
		),
	)


## Runs cli_runner.gd with args, returning its exit code and its non-empty
## output lines, stdout and stderr together.
func _run(args: Array) -> Dictionary:
	var output := []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray(
			[
				"--headless",
				"--no-header",
				"--path",
				ProjectSettings.globalize_path("res://"),
				"--script",
				"res://addons/ritinae_test/cli_runner.gd",
				"--",
			]
			+ args
		),
		output,
		true,
	)
	var lines := []
	for line in "".join(output).split("\n"):
		if not line.strip_edges().is_empty():
			lines.append(line)
	return { "exit_code": exit_code, "lines": lines }


func _reports(lines: Array) -> Array:
	return lines.filter(func(line: String) -> bool:
		return line.begins_with("PASS ") or line.begins_with("FAIL "),
	)
