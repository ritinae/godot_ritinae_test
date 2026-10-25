class_name RTPage
extends RefCounted
## Base for page objects: a page wraps something a test acts on or checks, and
## hides how it's built, so a test reads like what it means. Checks start with
## should_ and return a RTAssertion made with _assert(). How to write pages:
## addons/ritinae_test/docs/tests.md.

var t: Node # the running test


func _init(test: Node) -> void:
	t = test


## Makes a check. `probe` returns "" while the check holds, else what was seen.
## Do any actions and take any baselines before this; the probe should only look.
func _assert(probe: Callable) -> RTAssertion:
	return t.expectations.track(RTAssertion.new(probe))
