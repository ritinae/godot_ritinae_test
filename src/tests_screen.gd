@tool
extends VBoxContainer
## The editor's Tests main screen: lists the project's tests and runs them one
## at a time, each in its own headless process, showing each test's result and
## the output of the selected one. Tests are listed in a tree of their folders. How tests are run:
## addons/ritinae_test/docs/tests.md.

const TestRun := preload("res://addons/ritinae_test/src/test_run.gd")
const TestSuite := preload("res://addons/ritinae_test/src/test_suite.gd")

## The widest status the status column fits without clipping.
const WIDEST_STATUS := "FAIL (999 passed, 999 failed)"
## The widest the name column starts, before the editor scale.
const MAX_NAME_WIDTH := 480
## The narrowest the name column can be dragged, before the editor scale.
const MIN_NAME_WIDTH := 120

var _run_button := Button.new()
var _stop_button := Button.new()
var _filter := LineEdit.new()
var _status := Label.new()
var _split := HSplitContainer.new()
var _tree := Tree.new()
var _output := RichTextLabel.new()

var _dir := ""
## The TreeItem of each listed test, by name.
var _items := { }
## The TreeItem of each folder of the listed tests, by path under the tests
## folder.
var _folders := { }
## The lines, summary and pass of each test that has run, by name.
var _results := { }
var _queue := PackedStringArray()
var _run: TestRun
var _run_count := 0
var _failed := PackedStringArray()
## Whether the output follows the running test; it stops when a test is picked.
var _following := false
var _selecting := false
## Whether the list's width was dragged; until then it fits the names.
var _width_dragged := false


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
	_split.size_flags_vertical = SIZE_EXPAND_FILL
	_split.dragged.connect(func(_offset: int): _width_dragged = true)
	add_child(_split)
	_tree.columns = 2
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.set_column_expand(1, false)
	var background := StyleBoxFlat.new()
	background.bg_color = get_theme_color("dark_color_1", "Editor")
	background.set_content_margin_all(4 * scale)
	_tree.add_theme_stylebox_override("panel", background)
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(func(): _start(_names_under(_tree.get_selected())))
	_split.add_child(_tree)
	_tree.set_column_custom_minimum_width(1, _status_width())
	_tree.custom_minimum_size.x = _tree_width(MIN_NAME_WIDTH * scale)
	_output.size_flags_horizontal = SIZE_EXPAND_FILL
	_output.selection_enabled = true
	_output.context_menu_enabled = true
	_output.scroll_following = true
	_output.add_theme_font_override("normal_font", get_theme_font("output_source", "EditorFonts"))
	_output.add_theme_font_size_override(
		"normal_font_size",
		get_theme_font_size("output_source_size", "EditorFonts"),
	)
	_split.add_child(_output)

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
	_folders.clear()
	var root := _tree.create_item()
	if not DirAccess.dir_exists_absolute(_dir):
		_status.text = "No tests folder %s" % _dir
		_run_button.disabled = true
		return
	var names := TestSuite.find(_dir, _filters())
	for name in names:
		var item := _folder(name.get_base_dir(), root).create_child()
		item.set_text(0, name.get_file())
		item.set_metadata(0, name)
		_items[name] = item
		if name in _results:
			_show_result(name)
		else:
			_show_not_run(name)
	_fit_width()
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


## The item of the folder at path under the tests folder, made with its parent
## folders when missing. The empty path is the root.
func _folder(path: String, root: TreeItem) -> TreeItem:
	if path.is_empty():
		return root
	if path in _folders:
		return _folders[path]
	var item := _folder(path.get_base_dir(), root).create_child()
	item.set_text(0, path.get_file())
	item.set_icon(0, get_theme_icon("Folder", "EditorIcons"))
	item.set_metadata(0, "")
	_folders[path] = item
	return item


## The names of the test at item, or of the tests under the folder at item.
func _names_under(item: TreeItem) -> Array:
	var name: String = item.get_metadata(0)
	if not name.is_empty():
		return [name]
	var names := []
	for child in item.get_children():
		names.append_array(_names_under(child))
	return names


## Widens the list to fit its widest name, up to MAX_NAME_WIDTH, unless its
## width was dragged.
func _fit_width() -> void:
	if _width_dragged:
		return
	var scale := EditorInterface.get_editor_scale()
	var name_width := 0.0
	for item: TreeItem in _items.values() + _folders.values():
		name_width = maxf(name_width, _cell_width(item, 0))
	name_width = clampf(name_width, MIN_NAME_WIDTH * scale, MAX_NAME_WIDTH * scale)
	_split.split_offset = roundi(_tree_width(name_width) - _tree.custom_minimum_size.x)


## The width of the status column: an icon and WIDEST_STATUS.
func _status_width() -> int:
	var icon := get_theme_icon("StatusError", "EditorIcons")
	return ceili(_content_width(WIDEST_STATUS, icon))


## The width the cell's text and icon take, with its indent.
func _cell_width(item: TreeItem, column: int) -> float:
	var depth := 0
	var parent := item.get_parent()
	while parent:
		depth += 1
		parent = parent.get_parent()
	var indent := depth * _tree.get_theme_constant("item_margin")
	return indent + _content_width(item.get_text(column), item.get_icon(column))


func _content_width(text: String, icon: Texture2D) -> float:
	var font := _tree.get_theme_font("font")
	var font_size := _tree.get_theme_font_size("font_size")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if icon:
		width += icon.get_width() + _tree.get_theme_constant("h_separation")
	width += _tree.get_theme_constant("inner_item_margin_left")
	width += _tree.get_theme_constant("inner_item_margin_right")
	return width + _tree.get_theme_constant("h_separation")


## The width of the list with a name column name_width wide, the status column,
## the margins and room for the scroll bar.
func _tree_width(name_width: float) -> float:
	var scale := EditorInterface.get_editor_scale()
	var margins := _tree.get_theme_stylebox("panel").get_minimum_size().x
	return name_width + _status_width() + margins + 16 * scale


func _show_result(name: String) -> void:
	var result: Dictionary = _results[name]
	var item: TreeItem = _items[name]
	var verdict := "PASS" if result.passed else "FAIL"
	item.set_text(1, "%s (%s)" % [verdict, result.summary])
	item.set_tooltip_text(1, item.get_text(1))
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
	item.set_tooltip_text(1, "")
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
	_items[name].uncollapse_tree()
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
