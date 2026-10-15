extends "res://addons/ritinae_test/base_test.gd"
## describe/it steps run in order, nested groups included, each printing its
## path first. A step may await, and the next one waits for it. Script-level
## variables carry state from one step to the next.

var order: Array[String] = []


func spec() -> Dictionary:
	return describe("outer",
		it("first", func():
			order.append("first")
			await wait_frames(3)
			order.append("first, after waiting")
			check("the first step runs", true)),
		describe("inner",
			it("second", func():
				order.append("second")
				check("the second step runs after the first one has finished waiting",
					order == ["first", "first, after waiting", "second"]))),
		it("third", func():
			check("the third step runs last", order.size() == 3)),
	)
