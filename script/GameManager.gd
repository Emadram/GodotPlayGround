extends Node

signal game_state_changed(new_state: int)
signal resources_changed(current: int)
signal power_changed(available: int, used: int)
signal promotions_changed(points: int, level: int)

enum GameState {
	BOOT,
	RUNNING,
	VICTORY,
	DEFEAT,
	PAUSED
}

var state: GameState = GameState.BOOT
var current_faction_id: String = "usa"
var resources: int = 0
var power_available: int = 0
var power_used: int = 0
var promotion_points: int = 0
var promotion_level: int = 0
var promotion_thresholds: PackedInt32Array = PackedInt32Array([0, 3, 7, 12])

func _ready() -> void:
	if DataRegistry:
		DataRegistry.load_all()
	start_match(current_faction_id)

func start_match(faction_id: String) -> void:
	current_faction_id = faction_id
	var faction: FactionData = DataRegistry.get_faction(faction_id) if DataRegistry else null
	if faction != null:
		resources = faction.starting_cash
		power_available = faction.starting_power
	else:
		resources = 10000
		power_available = 0
	power_used = 0
	promotion_points = 0
	promotion_level = 0
	_set_state(GameState.RUNNING)
	resources_changed.emit(resources)
	power_changed.emit(power_available, power_used)
	promotions_changed.emit(promotion_points, promotion_level)

func spend_resources(amount: int) -> bool:
	if amount <= 0:
		return true
	if resources < amount:
		return false
	resources -= amount
	resources_changed.emit(resources)
	return true

func add_resources(amount: int) -> void:
	if amount <= 0:
		return
	resources += amount
	resources_changed.emit(resources)

func set_power_used(value: int) -> void:
	power_used = max(value, 0)
	power_changed.emit(power_available, power_used)

func set_power_available(value: int) -> void:
	power_available = max(value, 0)
	power_changed.emit(power_available, power_used)

func add_promotion_points(points: int) -> void:
	if points <= 0:
		return
	promotion_points += points
	var new_level := promotion_level
	while new_level + 1 < promotion_thresholds.size() and promotion_points >= promotion_thresholds[new_level + 1]:
		new_level += 1
	if new_level != promotion_level:
		promotion_level = new_level
		promotions_changed.emit(promotion_points, promotion_level)
	else:
		promotions_changed.emit(promotion_points, promotion_level)

func request_airstrike(position: Vector3, team_id: int = 1, radius: float = 2.5, damage: int = 80) -> void:
	if promotion_level < 1:
		return
	var units := get_tree().get_nodes_in_group("units")
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if not unit is Node3D:
			continue
		var other_team = unit.get("team_id")
		if typeof(other_team) == TYPE_INT and other_team == team_id:
			continue
		if position.distance_to(unit.global_position) <= radius:
			if unit.has_method("apply_damage"):
				unit.apply_damage(damage, null)

func end_match(victory: bool) -> void:
	_set_state(GameState.VICTORY if victory else GameState.DEFEAT)

func toggle_pause() -> void:
	if state == GameState.PAUSED:
		_set_state(GameState.RUNNING)
		get_tree().paused = false
	else:
		_set_state(GameState.PAUSED)
		get_tree().paused = true

func get_state_name() -> String:
	match state:
		GameState.BOOT:
			return "BOOT"
		GameState.RUNNING:
			return "RUNNING"
		GameState.VICTORY:
			return "VICTORY"
		GameState.DEFEAT:
			return "DEFEAT"
		GameState.PAUSED:
			return "PAUSED"
	return "UNKNOWN"

func _set_state(new_state: GameState) -> void:
	state = new_state
	game_state_changed.emit(state)
