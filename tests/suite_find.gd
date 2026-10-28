extends RTTest
## RTTestSuite finds the test_*.gd files under a folder, subfolders included,
## sorted by path and named by their path under it, keeps the ones matching any
## filter, and reads the tests folder and the jobs from the project settings.

const DIR := "res://addons/ritinae_test/tests/fixtures/suite"


func spec() -> void:
	describe("finding tests", func():
		it("finds every test_*.gd under the folder, sorted by path", func():
			check(
				"the tests are found by name",
				RTTestSuite.find(DIR)
				== PackedStringArray(
					["sub/test_script_error", "test_fails", "test_passes", "test_slow"]
				),
			),
		)
		it("keeps the tests whose name contains any of the filters", func():
			check(
				"a filter keeps the matching tests",
				RTTestSuite.find(DIR, ["fail"]) == PackedStringArray(["test_fails"]),
			)
			check(
				"a folder filter keeps the tests in it",
				RTTestSuite.find(DIR, ["sub/"]) == PackedStringArray(["sub/test_script_error"]),
			)
			check(
				"several filters keep the tests matching any of them, once",
				RTTestSuite.find(DIR, ["pass", "test_p", "slow"])
				== PackedStringArray(["test_passes", "test_slow"]),
			)
			check("a filter matching nothing keeps nothing", RTTestSuite.find(DIR, ["nothing"]).is_empty()),
		)
		it("finds nothing in a missing folder", func():
			check("a missing folder has no tests", RTTestSuite.find(DIR + "/missing").is_empty()),
		)
		it("gives a test's path by its name", func():
			check(
				"the path is the folder, the name and .gd",
				RTTestSuite.path_of(DIR, "sub/test_script_error")
				== DIR + "/sub/test_script_error.gd",
			),
		),
	)
	describe("the tests folder setting", func():
		var saved: Variant = ProjectSettings.get_setting(RTTestSuite.TESTS_DIR_SETTING)
		after_all(func(): ProjectSettings.set_setting(RTTestSuite.TESTS_DIR_SETTING, saved))

		it("is res://test when not set", func():
			ProjectSettings.set_setting(RTTestSuite.TESTS_DIR_SETTING, null)
			check("the default folder is res://test", RTTestSuite.tests_dir() == "res://test"),
		)
		it("is a res:// path without a trailing slash", func():
			ProjectSettings.set_setting(RTTestSuite.TESTS_DIR_SETTING, "res://checks/")
			check("a trailing slash is dropped", RTTestSuite.tests_dir() == "res://checks")
			ProjectSettings.set_setting(RTTestSuite.TESTS_DIR_SETTING, "checks/gameplay")
			check(
				"a folder without res:// is under the project",
				RTTestSuite.tests_dir() == "res://checks/gameplay",
			)
			ProjectSettings.set_setting(RTTestSuite.TESTS_DIR_SETTING, "")
			check("an empty folder is the default", RTTestSuite.tests_dir() == "res://test"),
		),
	)
	describe("the jobs setting", func():
		var saved: Variant = ProjectSettings.get_setting(RTTestSuite.JOBS_SETTING)
		after_all(func(): ProjectSettings.set_setting(RTTestSuite.JOBS_SETTING, saved))

		it("is one per CPU when not set or 0", func():
			ProjectSettings.set_setting(RTTestSuite.JOBS_SETTING, null)
			check("unset is the CPU count", RTTestSuite.jobs() == OS.get_processor_count())
			ProjectSettings.set_setting(RTTestSuite.JOBS_SETTING, 0)
			check("0 is the CPU count", RTTestSuite.jobs() == OS.get_processor_count()),
		)
		it("is the setting when positive", func():
			ProjectSettings.set_setting(RTTestSuite.JOBS_SETTING, 3)
			check("the setting is used", RTTestSuite.jobs() == 3),
		),
	)
