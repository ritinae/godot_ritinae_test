extends RTTest
## A describe body that awaits gives control back at the await, and the rest of
## it runs after spec() has returned: what it adds then fails the test and
## never runs.


func spec() -> void:
	describe("outer", func():
		it("first", func():
			await wait_frames(5)
			check("the first step runs", true),
		)
		await wait_frames(1)
		it("late", func(): check("the late step runs", true)),
	)
