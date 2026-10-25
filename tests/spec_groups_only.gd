extends RTTest
## Groups without a single step between them are no test, and fail.


func spec() -> void:
	describe("outer", func():
		describe("inner", func(): pass)
		describe("another", func(): pass),
	)
