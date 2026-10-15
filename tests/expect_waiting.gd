extends "res://addons/ritinae_test/base_test.gd"
## expect_within() passes on the first frame a check holds and fails if it
## never does in time; expect_throughout() fails on the first frame a check
## stops holding. A check that acts does so once, however long it's polled.

var actions := 0


func spec() -> Dictionary:
	return describe("waiting",
		it("waits for a check to come true", func():
			await expect_within(1.0, "be ready", ready_after(10))
			await expect_within(0.25, "be ready", ready_after(30))),
		it("watches a check stay true", func():
			await expect_throughout(0.25, "stay ready", ready_until(30))
			await expect_throughout(1.0, "stay ready", ready_until(15))),
		it("acts once while polled", func():
			await expect_within(0.5, "be ready", acting_ready_after(5))
			check("the check acted once", actions == 1)),
	)


## Holds from `frames` frames after it's made.
func ready_after(frames: int) -> RTAssertion:
	var start := Engine.get_process_frames()
	return expectations.track(RTAssertion.new(func():
		var waited := Engine.get_process_frames() - start
		return "" if waited >= frames else "it was %d frames in" % waited))


## Holds until `frames` frames after it's made.
func ready_until(frames: int) -> RTAssertion:
	var start := Engine.get_process_frames()
	return expectations.track(RTAssertion.new(func():
		var waited := Engine.get_process_frames() - start
		return "" if waited < frames else "it stopped %d frames in" % waited))


## Acts when it's made, then holds from `frames` frames on.
func acting_ready_after(frames: int) -> RTAssertion:
	actions += 1
	return ready_after(frames)
