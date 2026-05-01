extends Node3D

@export var total_supply: int = 20000
@export var gather_rate: float = 200.0

func _ready() -> void:
	add_to_group("resource_nodes")
	_apply_economy_data()

func _apply_economy_data() -> void:
	var economy := _get_current_economy_data()
	if economy == null:
		return
	total_supply = economy.supply_dock_amount
	gather_rate = economy.supply_gather_rate

func _get_current_economy_data() -> EconomyData:
	if DataRegistry == null or GameManager == null:
		return null
	var faction: FactionData = DataRegistry.get_faction(GameManager.current_faction_id)
	if faction == null or faction.economy_id == "":
		return null
	return DataRegistry.get_economy(faction.economy_id)

func take_supply(amount: int) -> int:
	if amount <= 0:
		return 0
	var taken: int = min(amount, total_supply)
	total_supply -= taken
	return taken

func is_depleted() -> bool:
	return total_supply <= 0
