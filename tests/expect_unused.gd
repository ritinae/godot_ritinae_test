extends "res://addons/ritinae_test/base_test.gd"
## An assertion that never reaches an expect call fails the step or hook it was
## made in, saying what it saw. The parts of an all_of() count as checked; the
## all_of() itself doesn't until it's expected.

var after_each_makes_one := false # makes after_each leave one unused too


func spec() -> void:
	describe("unused", func():
		before_all(func(): fails("made in before_all"))
		after_each(func():
			if after_each_makes_one:
				holds(),
		)
		it("forgets a failing check", func():
			fails("the player had 470 wood")
			check("the step goes on", true),
		)
		it("forgets a passing check", func():
			holds()
			after_each_makes_one = true,
		)
		it("forgets an all_of", func():
			after_each_makes_one = false
			all_of(holds(), fails("a part of all_of")),
		)
		it("forgets nothing", func():
			expect("have a part checked through all_of", all_of(holds(), holds())),
		),
	)


func holds() -> RTAssertion:
	return expectations.track(RTAssertion.new(func(): return ""))


func fails(seen: String) -> RTAssertion:
	return expectations.track(RTAssertion.new(func(): return seen))
