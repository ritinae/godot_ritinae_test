class_name RTAssertion
extends RefCounted
## A check that can be looked at again on any frame. Made by a page's
## _assert() (or RTExpect.all_of()) and checked with the test's expect calls.

var probe: Callable  # returns "" while the check holds, else what was seen


func _init(p: Callable) -> void:
	probe = p


## "" if the check holds right now, else what was seen, e.g. "spot (12, 4) was free".
func seen() -> String:
	return probe.call()
