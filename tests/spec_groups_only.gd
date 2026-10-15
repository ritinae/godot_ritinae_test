extends "res://addons/ritinae_test/base_test.gd"
## Groups without a single step between them are no test, and fail.


func spec() -> Dictionary:
	return describe("outer",
		describe("inner"),
		describe("another"),
	)
