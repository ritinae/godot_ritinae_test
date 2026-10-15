class_name RTPage
extends RefCounted
## Base for page objects: a page wraps something a test acts on or checks, and
## hides how it's built, so a test reads like what it means.
##
## Conventions:
## - Checks start with should_ and return a RTAssertion made with _assert(),
##   apart from actions (place(), set_wood()) and queries (wood_of()).
## - A check does its actions and takes its baselines when it's called; only
##   looking goes in the probe, which may run on many frames (expect_within).
## - A failure says what was there, with actual values ("the player had 470
##   wood"); a check of several things says which part failed.
##
##   func should_be_blocked(cell: Vector2i, kind: Building.Kind) -> RTAssertion:
##   	return _assert(func():
##   		return "" if not _fits(cell, kind) else "spot %s was free" % cell)

var t: Node  # the running test


func _init(test: Node) -> void:
	t = test


## Makes a check. `probe` returns "" while the check holds, else what was seen.
## Do any actions and take any baselines before this; the probe should only look.
func _assert(probe: Callable) -> RTAssertion:
	return t.expectations.track(RTAssertion.new(probe))
