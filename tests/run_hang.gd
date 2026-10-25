extends RTTest
## A test still running after max_seconds fails as hung.


func _init() -> void:
	max_seconds = 1.0


func run() -> void:
	check("a check before hanging", true)
	await wait_seconds(10)
	check("a check the test never gets to", true)
