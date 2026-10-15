class_name RTExpect
extends RefCounted
## Checks assertions for a test: "Expected to <intent>[, but <what was seen>]".
## Tests reach this through their base test's expect() and all_of(); pages
## register every assertion they make with track(), and the runner fails any
## that never got checked (check_unused()).

var t: Node  # the running test
var _unused: Array[RTAssertion] = []  # made, not yet checked


func _init(test: Node) -> void:
	t = test


## Holds now.
func now(intent: String, a: RTAssertion) -> void:
	_unused.erase(a)
	var seen := a.seen()
	t.check("Expected to %s" % intent if seen == ""
		else "Expected to %s, but %s" % [intent, seen], seen == "")


## Several assertions as one; reports the first part that fails.
func all_of(parts: Array) -> RTAssertion:
	for a in parts:
		_unused.erase(a)
	return track(RTAssertion.new(func():
		for a in parts:
			var seen: String = a.seen()
			if seen != "":
				return seen
		return ""))


## Registers an assertion, so it fails if it's never checked.
func track(a: RTAssertion) -> RTAssertion:
	_unused.append(a)
	return a


## Fails for every assertion made since the last call that was never checked.
func check_unused() -> void:
	for a in _unused:
		var seen := a.seen()
		t.check("every check is passed to an expect call (one wasn't%s)"
			% ("" if seen == "" else ": " + seen), false)
	_unused.clear()
