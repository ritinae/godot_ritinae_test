extends "res://addons/ritinae_test/base_test.gd"
## spec()'s top level works like a describe body without a name: it may hold
## hooks, steps and several groups, and adds nothing to their paths.


func spec() -> void:
	before_all(func(): check("top-level before_all", true))
	before_each(func(): check("top-level before_each", true))
	after_all(func(): check("top-level after_all", true))
	it("top-level step", func(): check("top-level step", true))
	describe("first", func():
		it("one", func(): check("one", true)),
	)
	describe("second", func():
		it("two", func(): check("two", true)),
	)
