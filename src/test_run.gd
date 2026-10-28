@tool
class_name RTTestRun
extends RefCounted
## One test file run in its own headless Godot process through runner.gd. Its
## output is collected as it arrives, on each frame of the main loop, and
## judged: it passes when the process exits with 0 and prints no SCRIPT ERROR.
## Call start() and await finished, keeping a reference meanwhile. How tests
## are run: addons/ritinae_test/docs/tests.md.

## Emitted for each line the test prints, from stdout and stderr alike.
signal line_received(line: String)
## Emitted once the process has ended, was stopped or timed out.
signal finished

const RUNNER := "res://addons/ritinae_test/runner.gd"

## The test file, as a res:// path.
var path: String
## Real seconds after which the process is killed and the test fails.
var timeout_seconds := 300.0
## Every line the test has printed, in the order they arrived.
var lines := PackedStringArray()
## The process's exit code: -1 until it has ended, and when it was killed.
var exit_code := -1
var running := false
var stopped := false
var timed_out := false

var _pid := -1
var _readers: Array[Thread] = []
var _received := PackedStringArray()
var _received_mutex := Mutex.new()
var _started_msec := 0


func _init(test_path := "") -> void:
	path = test_path


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and running:
		stop()
		_join_readers()


## Starts the test's process. The game runs at a fixed 60 fps.
func start() -> void:
	var godot := OS.get_executable_path()
	var args := PackedStringArray(
		[
			"--headless",
			"--fixed-fps",
			"60",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			RUNNER,
			"--",
			path,
		]
	)
	var process := OS.execute_with_pipe(godot, args)
	running = true
	if process.is_empty():
		_receive("Couldn't start %s" % godot)
		_finish.call_deferred()
		return
	_pid = process.pid
	_started_msec = Time.get_ticks_msec()
	for pipe: FileAccess in [process.stdio, process.stderr]:
		var reader := Thread.new()
		reader.start(_read.bind(pipe))
		_readers.append(reader)
	(Engine.get_main_loop() as SceneTree).process_frame.connect(_poll)


## Kills the test's process. The test fails as stopped.
func stop() -> void:
	if running and _pid > 0 and not stopped and not timed_out:
		stopped = true
		OS.kill(_pid)


## Whether the test passed: its process exited with 0 and printed no
## SCRIPT ERROR.
func passed() -> bool:
	if exit_code != 0:
		return false
	for line in lines:
		if line.contains("SCRIPT ERROR"):
			return false
	return true


## What the run came to: the counts from the test's RESULT line
## ("3 passed, 1 failed"), or why there are none.
func summary() -> String:
	if stopped:
		return "stopped"
	if timed_out:
		return "timed out after %d real seconds" % timeout_seconds
	for i in range(lines.size() - 1, -1, -1):
		if lines[i].begins_with("RESULT: "):
			return lines[i].trim_prefix("RESULT: ")
	if running:
		return "running"
	return "exit code %d" % exit_code


func _poll() -> void:
	if not running or _pid < 0:
		return
	_take_received()
	if (
		not timed_out and not stopped
		and Time.get_ticks_msec() - _started_msec > timeout_seconds * 1000
	):
		timed_out = true
		OS.kill(_pid)
	if _readers.any(func(reader: Thread) -> bool: return reader.is_alive()):
		return
	# OS.kill() has already reaped a killed process, so only one that ended by
	# itself is asked about.
	if not stopped and not timed_out:
		if OS.is_process_running(_pid):
			return
		exit_code = OS.get_process_exit_code(_pid)
	_finish()


func _finish() -> void:
	var frames := (Engine.get_main_loop() as SceneTree).process_frame
	if frames.is_connected(_poll):
		frames.disconnect(_poll)
	_join_readers()
	_take_received()
	running = false
	finished.emit()


func _join_readers() -> void:
	for reader in _readers:
		reader.wait_to_finish()
	_readers.clear()


## Runs on a reader thread until the pipe ends.
func _read(pipe: FileAccess) -> void:
	while true:
		var line := pipe.get_line()
		var ended := pipe.get_error() != OK
		if not ended or not line.is_empty():
			_received_mutex.lock()
			_received.append(line)
			_received_mutex.unlock()
		if ended:
			return


func _take_received() -> void:
	_received_mutex.lock()
	var received := _received
	_received = PackedStringArray()
	_received_mutex.unlock()
	for line in received:
		_receive(line)


func _receive(line: String) -> void:
	lines.append(line)
	line_received.emit(line)
