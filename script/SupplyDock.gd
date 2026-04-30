extends Node3D

@export var total_supply: int = 20000
@export var gather_rate: float = 200.0

func take_supply(amount: int) -> int:
	if amount <= 0:
		return 0
	var taken: int = min(amount, total_supply)
	total_supply -= taken
	return taken

func is_depleted() -> bool:
	return total_supply <= 0
