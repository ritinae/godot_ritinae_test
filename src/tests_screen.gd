@tool
extends VBoxContainer
## The editor's Tests main screen: lists the project's tests and runs them one
## at a time, each in its own headless process, showing each test's result and
## the output of the selected one. How tests are run:
## addons/ritinae_test/docs/tests.md.

const TestRun := preload("res://addons/ritinae_test/src/test_run.gd")
const TestSuite := preload("res://addons/ritinae_test/src/test_suite.gd")

var _run_button := Button.new()
var _stop_button := Button.new()
var _filter := LineEdit.new()
var _status := Label.new()
var _tree := Tree.new()
var _output := RichTextLabel.new()

var _dir := ""
## The TreeItem of each listed test, by name.
var _items := { }
## The lines, summary and pass of each test that has run, by name.
var _results := { }
var _queue := PackedStringArray()
var _run: TestRun
var _run_count := 0
var _failed := PackedStringArray()
## Whether the output follows the running test; it stops when a test is picked.
var _following := false
var _selecting := false


func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL

	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	_run_button.text = "Run"
	_run_button.tooltip_text = "Run the listed tests"
	_run_button.icon = get_theme_icon("Play", "EditorIcons")
	_run_button.pressed.connect(_run_listed)
	toolbar.add_child(_run_button)
	_stop_button.text = "Stop"
	_stop_button.icon = get_theme_icon("Stop", "EditorIcons")
	_stop_button.disabled = true
	_stop_button.pressed.connect(stop)
	toolbar.add_child(_stop_button)
	_filter.placeholder_text = "Filter: names containing any of these words"
	_filter.clear_button_enabled = true
	_filter.size_flags_horizontal = SIZE_EXPAND_FILL
	_filter.text_changed.connect(func(_text: String): refresh())
	_filter.text_submitted.connect(func(_text: String): _run_listed())
	toolbar.add_child(_filter)
	toolbar.add_child(_status)

	var scale := EditorInterface.get_editor_scale()
	var split := HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(split)
	_tree.columns = 2
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.custom_minimum_size.x = 360 * scale
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, roundi(200 * scale))
	var background := StyleBoxFlat.new()
	background.bg_color = get_theme_color("dark_color_1", "Editor")
	background.set_content_margin_all(4 * scale)
	_tree.add_theme_stylebox_override("panel", background)
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(func(): _start([_tree.get_selected().get_metadata(0)]))
	split.add_child(_tree)
	_output.size_flags_horizontal = SIZE_EXPAND_FILL
	_output.selection_enabled = true
	_output.context_menu_enabled = true
	_output.scroll_following = true
	_output.add_theme_font_override("normal_font", get_theme_font("output_source", "EditorFonts"))
	_output.add_theme_font_size_override(
		"normal_font_size",
		get_theme_font_size("output_source_size", "EditorFonts"),
	)
	split.add_child(_output)

	visibility_changed.connect(func():
		if visible:
			refresh(),
	)
	refresh()


## Lists the tests in the tests folder that match the filter, unless tests are
## running.
func refresh() -> void:
	if _run or not is_node_ready():
		return
	var selected := _selected_name()
	_dir = TestSuite.tests_dir()
	_tree.clear()
	_items.clear()
	var root := _tree.create_item()
	if not DirAccess.dir_exists_absolute(_dir):
		_status.text = "No tests folder %s" % _dir
		_run_button.disabled = true
		return
	var names := TestSuite.find(_dir, _filters())
	for name in names:
		var item := root.create_child()
		item.set_text(0, name)
		item.set_metadata(0, name)
		_items[name] = item
		if name in _results:
			_show_result(name)
		else:
			_show_not_run(name)
	_run_button.disabled = names.is_empty()
	if names.is_empty():
		_status.text = "No tests matched."
	else:
		_status.text = "%d tests in %s" % [names.size(), _dir]
	if selected in _items:
		_select(selected)
	else:
		_output.clear()


## Stops the running test, which fails as stopped, and the tests waiting to run.
func stop() -> void:
	_queue.clear()
	if _run:
		_run.stop()


func _run_listed() -> void:
	_start(_items.keys())


func _start(names: Array) -> void:
	if _run or names.is_empty():
		return
	_save_before_running()
	_queue = PackedStringArray(names)
	_run_count = names.size()
	_failed.clear()
	_following = true
	for name in names:
		_results.erase(name)
		_show_not_run(name)
	_run_button.disabled = true
	_stop_button.disabled = false
	_filter.editable = false
	_run_next()


## Saves scenes and scripts first when the editor saves them before running the
## project, as tests run from the files on disk.
func _save_before_running() -> void:
	if EditorInterface.get_editor_settings().get_setting("run/auto_save/save_before_running"):
		EditorInterface.save_all_scenes()
		EditorInterface.get_script_editor().save_all_scripts()


func _run_next() -> void:
	if _queue.is_empty():
		_finish()
		return
	var name := _queue[0]
	_queue.remove_at(0)
	_status.text = "Running %d of %d: %s" % [_run_count - _queue.size(), _run_count, name]
	_items[name].set_text(1, "running…")
	_items[name].set_custom_color(1, get_theme_color("font_color", "Editor"))
	_run = TestRun.new(TestSuite.path_of(_dir, name))
	_run.line_received.connect(_on_line_received.bind(name))
	_run.finished.connect(_on_run_finished.bind(name))
	add_child(_run)
	if _following:
		_select(name)
	_run.start()


func _on_line_received(line: String, name: String) -> void:
	if _selected_name() == name:
		_append(line)


func _on_run_finished(name: String) -> void:
	_results[name] = { "lines": _run.lines, "summary": _run.summary(), "passed": _run.passed() }
	if not _run.passed():
		_failed.append(name)
	_run.queue_free()
	_run = null
	_show_result(name)
	_run_next()


func _finish() -> void:
	_run_button.disabled = false
	_stop_button.disabled = true
	_filter.editable = true
	if _failed.is_empty():
		_status.text = "All %d tests passed." % _run_count
	else:
		_status.text = "%d of %d tests failed." % [_failed.size(), _run_count]
		if _following and _failed[0] in _items:
			_select(_failed[0])


func _show_result(name: String) -> void:
	var result: Dictionary = _results[name]
	var item: TreeItem = _items[name]
	var verdict := "PASS" if result.passed else "FAIL"
	item.set_text(1, "%s (%s)" % [verdict, result.summary])
	item.set_icon(
		1,
		get_theme_icon("StatusSuccess" if result.passed else "StatusError", "EditorIcons"),
	)
	item.set_custom_color(
		1,
		get_theme_color("success_color" if result.passed else "error_color", "Editor"),
	)


func _show_not_run(name: String) -> void:
	var item: TreeItem = _items[name]
	item.set_text(1, "Not yet run")
	item.set_icon(1, null)
	item.set_custom_color(1, get_theme_color("font_disabled_color", "Editor"))


func _on_item_selected() -> void:
	if not _selecting:
		_following = false
	_output.clear()
	var name := _selected_name()
	var lines := PackedStringArray()
	if _run and _run.path == TestSuite.path_of(_dir, name):
		lines = _run.lines
	elif name in _results:
		lines = _results[name].lines
	for line in lines:
		_append(line)


func _select(name: String) -> void:
	_selecting = true
	_items[name].select(0)
	_tree.scroll_to_item(_items[name])
	_selecting = false


func _selected_name() -> String:
	var item := _tree.get_selected()
	return item.get_metadata(0) if item else ""


func _append(line: String) -> void:
	if line.is_empty() or line.begins_with("Godot Engine v"):
		return
	var color := Color()
	if line.begins_with("PASS "):
		color = get_theme_color("success_color", "Editor")
	elif line.begins_with("FAIL ") or line.contains("SCRIPT ERROR") or line.contains("ERROR:"):
		color = get_theme_color("error_color", "Editor")
	elif line.begins_with("STEP "):
		color = get_theme_color("accent_color", "Editor")
	if color != Color():
		_output.push_color(color)
		_output.add_text(line)
		_output.pop()
	else:
		_output.add_text(line)
	_output.newline()


func _filters() -> PackedStringArray:
	return _filter.text.split(" ", false)
