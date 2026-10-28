class_name RTTestSuite
extends RefCounted
## A project's tests: the test_*.gd files under its tests folder, found and
## filtered by name, for run_tests.sh and the Tests screen. How tests are run:
## addons/ritinae_test/docs/tests.md.

## The project setting naming the tests folder. run_tests.sh reads it too.
const TESTS_DIR_SETTING := "ritinae_test/run/tests_dir"
const DEFAULT_TESTS_DIR := "res://test"
## The project setting limiting how many tests run at a time; 0 runs one per
## CPU. run_tests.sh reads it too.
const JOBS_SETTING := "ritinae_test/run/jobs"


## The tests folder named by the project setting, as a res:// path without a
## trailing slash. A folder given without res:// is under the project root.
static func tests_dir() -> String:
	var dir := str(ProjectSettings.get_setting(TESTS_DIR_SETTING, DEFAULT_TESTS_DIR)).strip_edges()
	dir = dir.trim_prefix("res://").trim_suffix("/")
	if dir.is_empty():
		return DEFAULT_TESTS_DIR
	return "res://" + dir


## How many tests run at a time: the project setting, or the CPU count when it
## is 0 or less.
static func jobs() -> int:
	var jobs := int(ProjectSettings.get_setting(JOBS_SETTING, 0))
	return jobs if jobs > 0 else OS.get_processor_count()


## The names of the tests under dir, subfolders included, sorted by path. A
## test's name is its path under dir without .gd. With filters, only the tests
## whose name contains any of them are kept.
static func find(dir: String, filters := PackedStringArray()) -> PackedStringArray:
	var paths := PackedStringArray()
	if DirAccess.dir_exists_absolute(dir):
		_collect(dir, paths)
	paths.sort()
	var names := PackedStringArray()
	for path in paths:
		var name := path.trim_prefix(dir + "/").trim_suffix(".gd")
		if _matches(name, filters):
			names.append(name)
	return names


## The file of the test with the given name under dir.
static func path_of(dir: String, name: String) -> String:
	return "%s/%s.gd" % [dir, name]


static func _collect(dir: String, paths: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.begins_with("test_") and file.ends_with(".gd"):
			paths.append(dir.path_join(file))
	for subdir in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(subdir), paths)


static func _matches(name: String, filters: PackedStringArray) -> bool:
	if filters.is_empty():
		return true
	for filter in filters:
		if name.contains(filter):
			return true
	return false
