@tool
class_name RTEditorRunner
extends RTTestSession
## Runs the Tests screen's tests as the editor should.
##
## A test session that saves scenes and scripts first when the editor saves
## before running the project, runs as many tests at a time as the jobs setting
## says, and words the progress for the screen's status. How tests are run:
## addons/ritinae_test/docs/tests.md.


## Saves when the editor would, then runs the tests with the given names under
## tests_dir.
func start(tests_dir: String, test_names: PackedStringArray) -> void:
	if is_running():
		return
	_save_before_running()
	jobs = RTTestSuite.jobs()
	super(tests_dir, test_names)


## The status while tests run: how many are running and how many are done.
func progress_text() -> String:
	return "Running %d, %d of %d done" % [running_names().size(), results.size(), names.size()]


## The status once the run has finished.
func summary_text() -> String:
	var failed_count := failed().size()
	if failed_count == 0:
		return "All %d tests passed." % names.size()
	return "%d of %d tests failed." % [failed_count, names.size()]


## Saves scenes and scripts when the editor saves them before running the
## project, as tests run from the files on disk.
func _save_before_running() -> void:
	if not Engine.is_editor_hint():
		return
	if EditorInterface.get_editor_settings().get_setting("run/auto_save/save_before_running"):
		EditorInterface.save_all_scenes()
		EditorInterface.get_script_editor().save_all_scripts()
