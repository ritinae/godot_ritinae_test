extends "res://addons/ritinae_test/base_test.gd"
## Hooks run in order around the steps: each hook checks in under its own name,
## so the output shows when it ran. Some hooks wait, and what follows waits for
## them.


func spec() -> void:
	describe("outer", func():
		before_all(func(): check("outer before_all", true))
		before_each(func():
			await wait_frames(2)
			check("outer before_each", true),
		)
		after_each(func(): check("outer after_each", true))
		after_all(func():
			await wait_frames(2)
			check("outer after_all", true),
		)
		it("one", func(): check("one", true))
		describe("inner", func():
			before_each(func(): check("inner before_each", true))
			after_each(func():
				await wait_frames(2)
				check("inner after_each", true),
			)
			it("two", func(): check("two", true)),
		)
		it("three", func(): check("three", true)),
	)
