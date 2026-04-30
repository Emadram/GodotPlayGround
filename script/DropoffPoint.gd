extends Node3D

@export var team_id: int = 1

func deposit(amount: int) -> void:
	if amount <= 0:
		return
	if GameManager:
		GameManager.add_resources(amount)
