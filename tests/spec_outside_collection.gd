extends "res://addons/ritinae_test/base_test.gd"
## Steps, hooks and groups can only be added while spec() runs. Adding one from
## inside a step fails the test, and what it adds never runs.


func spec() -> void:
	describe("outer", func():
		it("adds more steps", func():
			it("late", func(): check("the late step runs", true))
			before_each(func(): check("the late hook runs", true))
			describe("late group", func(): check("the late group's body runs", true))
			check("the step goes on after the calls", true),
		)
		it("next", func(): check("the next step runs", true)),
	)
