extends "res://addons/ritinae_test/base_test.gd"
## A run() test whose checks all pass, also across a wait.


func run() -> void:
	check("a check before waiting passes", true)
	await wait_frames(2)
	check("a check after waiting passes", true)
