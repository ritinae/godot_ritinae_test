extends "res://addons/ritinae_test/base_test.gd"
## A run() test with one failing check fails, and its other checks still count.


func run() -> void:
	check("a passing check", true)
	check("a failing check", false)
	check("a check after the failure", true)
