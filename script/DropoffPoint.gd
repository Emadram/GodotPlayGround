extends Node3D

@export var team_id: int = 1

func _ready() -> void:
	add_to_group("dropoff_points")
	print("[Dropoff] ready at %s" % str(global_position))


func deposit(amount: int) -> void:
	if amount <= 0:
		print("[Dropoff] deposit ignored amount=%s" % amount)
		return
	if GameManager:
		GameManager.add_resources(amount)
		print("[Dropoff] deposit +%s resources (GameManager)" % amount)
	else:
		print("[Dropoff] deposit FAILED no GameManager amount=%s" % amount)
