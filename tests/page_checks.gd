extends "res://addons/ritinae_test/base_test.gd"
## A page's should_ checks work with every expect call and all_of(), and are
## tracked like any other assertion.

var tally := TallyPage.new(self)


func spec() -> void:
	describe("a page", func():
		it("checks now", func():
			tally.add(3)
			expect("count to 3", tally.should_be(3))
			expect("count to 4", tally.should_be(4))
			expect("count to 3 and at least 2", all_of(tally.should_be(3), tally.should_be_at_least(2)))
			expect("count to 3 and at least 5", all_of(tally.should_be(3), tally.should_be_at_least(5))))
		it("checks over frames", func():
			_count_up(20)
			await expect_within(0.5, "reach 10", tally.should_be_at_least(10))
			await expect_throughout(0.1, "stay at most 30", tally.should_be_at_most(30)))
		it("tracks its checks", func():
			await wait_frames(20)  # counting up has finished: 3 + 20
			tally.should_be(0))
	)


## Adds one to the tally on each of the next `frames` frames.
func _count_up(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
		tally.add(1)


class TallyPage extends RTPage:
	var _value := 0

	func add(n: int) -> void:
		_value += n

	func should_be(n: int) -> RTAssertion:
		return _assert(func():
			return "" if _value == n else "the tally was %d" % _value)

	func should_be_at_least(n: int) -> RTAssertion:
		return _assert(func():
			return "" if _value >= n else "the tally was only %d" % _value)

	func should_be_at_most(n: int) -> RTAssertion:
		return _assert(func():
			return "" if _value <= n else "the tally was already %d" % _value)
