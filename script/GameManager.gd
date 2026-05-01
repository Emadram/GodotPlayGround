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
var secondary_income_per_second: float = 0.0
var secondary_income_accum: float = 0.0
var visibility_state: Dictionary = {}

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
	secondary_income_per_second = 1.0
	secondary_income_accum = 0.0
	_set_state(GameState.RUNNING)
	resources_changed.emit(resources)
	power_changed.emit(power_available, power_used)
	promotions_changed.emit(promotion_points, promotion_level)

func _process(delta: float) -> void:
	_update_fog_of_war()
	if state != GameState.RUNNING:
		return
	if secondary_income_per_second <= 0.0:
		return
	secondary_income_accum += secondary_income_per_second * delta
	var income: int = int(secondary_income_accum)
	if income <= 0:
		return
	secondary_income_accum -= float(income)
	add_resources(income)

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


# Gameplay FoW: hide enemies unless any friendly unit or completed building (team 1) can see the position.
func _update_fog_of_war() -> void:
	var units := get_tree().get_nodes_in_group("units")
	var friendly_sources: Array[Node3D] = []
	var enemy_units: Array[Node3D] = []
	for unit in units:
		if not is_instance_valid(unit) or not unit is Node3D:
			continue
		var other_team = unit.get("team_id")
		if typeof(other_team) != TYPE_INT:
			continue
		if other_team == 1:
			friendly_sources.append(unit as Node3D)
		else:
			enemy_units.append(unit as Node3D)
	for node in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(node) or not node is Node3D:
			continue
		var bteam: Variant = node.get("team_id")
		if typeof(bteam) != TYPE_INT or int(bteam) != 1:
			continue
		if typeof(node.get("is_ghost")) == TYPE_BOOL and bool(node.get("is_ghost")):
			continue
		friendly_sources.append(node as Node3D)
	for enemy in enemy_units:
		var revealed := _is_position_visible(enemy.global_position, friendly_sources)
		enemy.visible = revealed
		var id := enemy.get_instance_id()
		if not visibility_state.has(id) or bool(visibility_state[id]) != revealed:
			visibility_state[id] = revealed
			print("[Fog] %s visible=%s" % [enemy.name, str(revealed)])


# Each source contributes a circle in XZ; range from get_vision_range() when implemented (units + buildings).
func _is_position_visible(position: Vector3, sources: Array[Node3D]) -> bool:
	for source in sources:
		if not is_instance_valid(source):
			continue
		var range := 12.0
		if source.has_method("get_vision_range"):
			range = float(source.get_vision_range())
		if source.global_position.distance_to(position) <= range:
			return true
	return false

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
