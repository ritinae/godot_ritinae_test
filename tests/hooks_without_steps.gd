extends RTTest
## Hooks don't count as steps: a test with hooks but no steps fails, without
## running the hooks.


func spec() -> void:
	describe("outer", func():
		before_all(func(): check("before_all never runs", true))
		before_each(func(): check("before_each never runs", true))
		describe("inner", func():
			after_all(func(): check("after_all never runs", true)),
		),
	)
