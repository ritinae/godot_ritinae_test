@tool
extends EditorPlugin
## Adds the Tests main screen to the editor, which lists and runs the project's
## tests, and the project settings naming their folder and how many run at a
## time. Tests also run without
## the editor, through run_tests.sh and runner.gd. How tests are run:
## addons/ritinae_test/docs/tests.md.

var _screen: RTTestsScreen


func _enter_tree() -> void:
	_add_setting(
		{ "name": RTTestSuite.TESTS_DIR_SETTING, "type": TYPE_STRING, "hint": PROPERTY_HINT_DIR },
		RTTestSuite.DEFAULT_TESTS_DIR,
	)
	_add_setting(
		{
			"name": RTTestSuite.JOBS_SETTING,
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,64,1,or_greater",
		},
		0,
	)
	_screen = RTTestsScreen.new()
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


func _add_setting(info: Dictionary, default: Variant) -> void:
	var setting: String = info.name
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default)
	ProjectSettings.set_initial_value(setting, default)
	ProjectSettings.add_property_info(info)
	ProjectSettings.set_as_basic(setting, true)
