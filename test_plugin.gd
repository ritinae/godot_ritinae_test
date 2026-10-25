@tool
extends EditorPlugin
## Adds the Tests main screen to the editor, which lists and runs the project's
## tests, and the project setting naming their folder. Tests also run without
## the editor, through run_tests.sh and runner.gd. How tests are run:
## addons/ritinae_test/docs/tests.md.

const TestsScreen := preload("res://addons/ritinae_test/src/tests_screen.gd")
const TestSuite := preload("res://addons/ritinae_test/src/test_suite.gd")

var _screen: TestsScreen


func _enter_tree() -> void:
	_add_tests_dir_setting()
	_screen = TestsScreen.new()
	EditorInterface.get_editor_main_screen().add_child(_screen)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_screen.refresh)
	ProjectSettings.settings_changed.connect(_screen.refresh)
	_make_visible(false)


func _exit_tree() -> void:
	if _screen:
		_screen.queue_free()
		_screen = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _screen:
		_screen.visible = visible


func _get_plugin_name() -> String:
	return "Tests"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Performance", "EditorIcons")


func _add_tests_dir_setting() -> void:
	var setting := TestSuite.TESTS_DIR_SETTING
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, TestSuite.DEFAULT_TESTS_DIR)
	ProjectSettings.set_initial_value(setting, TestSuite.DEFAULT_TESTS_DIR)
	ProjectSettings.add_property_info(
		{ "name": setting, "type": TYPE_STRING, "hint": PROPERTY_HINT_DIR }
	)
	ProjectSettings.set_as_basic(setting, true)
