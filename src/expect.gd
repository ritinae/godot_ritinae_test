class_name RTExpect
extends RefCounted
## Checks assertions for a test: "Expected to <intent>[, but <what was seen>]".
## Tests reach this through their base test's expect() and all_of(); pages
## register every assertion they make with track(), and the runner fails any
## that never got checked (check_unused()).

var t: RTTest # the running test
var _unused: Array[RTAssertion] = [] # made, not yet checked


func _init(test: RTTest) -> void:
	t = test


## Holds now.
func now(intent: String, a: RTAssertion) -> void:
	_unused.erase(a)
	var seen := a.seen()
	t.check(
		("Expected to %s" % intent
			if seen == ""
			else "Expected to %s, but %s" % [intent, seen]),
		seen == "",
	)


## Comes to hold on some frame within the given game seconds.
func within(seconds: float, intent: String, a: RTAssertion) -> void:
	_unused.erase(a)
	var seen := a.seen()
	for i in roundi(seconds * t.FPS):
		if seen == "":
			break
		await t.get_tree().process_frame
		seen = a.seen()
	t.check(
		(
			"Expected within %s s to %s" % [seconds, intent]
			if seen == ""
			else "Expected within %s s to %s, but %s" % [seconds, intent, seen]
		),
		seen == "",
	)


## Holds on every frame for the given game seconds; fails as soon as it doesn't.
func throughout(seconds: float, intent: String, a: RTAssertion) -> void:
	_unused.erase(a)
	var frames := roundi(seconds * t.FPS)
	var seen := a.seen()
	var i := 0
	while seen == "" and i < frames:
		await t.get_tree().process_frame
		i += 1
		seen = a.seen()
	t.check(
		(
			"Expected to %s for %s s" % [intent, seconds]
			if seen == ""
			else "Expected to %s for %s s, but after %.2f s %s"
			% [intent, seconds, float(i) / t.FPS, seen]
		),
		seen == "",
	)


## Several assertions as one; reports the first part that fails.
func all_of(parts: Array) -> RTAssertion:
	for a in parts:
		_unused.erase(a)
	return track(
		RTAssertion.new(func():
			for a in parts:
				var seen: String = a.seen()
				if seen != "":
					return seen
			return "",
		)
	)


## Registers an assertion, so it fails if it's never checked.
func track(a: RTAssertion) -> RTAssertion:
	_unused.append(a)
	return a


## Fails for every assertion made since the last call that was never checked.
func check_unused() -> void:
	for a in _unused:
		var seen := a.seen()
		t.check(
			"every check is passed to an expect call (one wasn't%s)"
			% ("" if seen == "" else ": " + seen),
			false,
		)
	_unused.clear()
