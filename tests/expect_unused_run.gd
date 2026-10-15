extends "res://addons/ritinae_test/base_test.gd"
## A test that overrides run() also fails for an assertion it never checks,
## when it finishes.


func run() -> void:
	expectations.track(RTAssertion.new(func(): return "never checked"))
	check("a check that passes", true)
