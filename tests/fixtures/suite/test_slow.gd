extends RTTest
## A fixture test that runs far longer than tests/suite_run.gd waits for it.


func _init() -> void:
	max_seconds = 100000.0


func run() -> void:
	check("starts", true)
	await wait_seconds(100000.0)
