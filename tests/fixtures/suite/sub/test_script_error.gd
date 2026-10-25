extends RTTest
## A fixture test whose checks pass but that stops at a script error, run by
## tests/suite_run.gd.


func run() -> void:
	check("passes before the error", true)
	var missing: Object = null
	missing.free()
