extends "res://addons/ritinae_test/base_test.gd"
## expect() reports the test's intent, and what was seen when the check didn't
## hold. all_of() is one check of several and reports the first part that
## fails.


func spec() -> void:
	describe("expect", func():
		it("passes and fails", func():
			expect("build the tower", holds())
			expect("not be able to build on top of the other tower",
				fails("spot (12, 4) was free")))
		it("combines checks", func():
			expect("have all parts hold", all_of(holds(), holds(), holds()))
			expect("have all parts hold",
				all_of(holds(), fails("the second part failed"), fails("the third part failed"))))
		it("checks each item", func():
			expect("have every item hold", each_of(["a", "b"], func(item): return holds()))
			expect("have every item hold",
				each_of(["a", "b", "c"], func(item): return holds() if item == "a" else fails("%s failed" % item))))
	)


## A tracked assertion that holds, as a page's check makes it.
func holds() -> RTAssertion:
	return expectations.track(RTAssertion.new(func(): return ""))


## A tracked assertion that doesn't hold, having seen `seen`.
func fails(seen: String) -> RTAssertion:
	return expectations.track(RTAssertion.new(func(): return seen))
