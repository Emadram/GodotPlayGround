extends CharacterBody3D
# Economy unit: kinematic-style movement via global_position; CharacterBody3D gives a solid physics collider for the truck hull.

@export var supply_dock_path: NodePath
@export var dropoff_path: NodePath
@export var capacity: int = 1000
@export var move_speed: float = 5.0
@export var gather_rate: float = 200.0
@export var dropoff_time: float = 1.5
@export var auto_harvest_enabled: bool = true
@export var team_id: int = 1
@export_group("Navigation Tuning")
@export var nav_avoidance_enabled: bool = true
@export var nav_radius: float = 0.8
@export var separation_radius: float = 1.9
@export var separation_weight: float = 0.9
@export var destination_slowdown_distance: float = 1.0
@export_group("Stuck Recovery")
@export var stuck_distance_threshold: float = 0.06
@export var stuck_timeout: float = 0.9
@export var stuck_repath_offset: float = 1.0
@export var max_stuck_recoveries: int = 6

@onready var nav_agent: NavigationAgent3D = $NavAgent
@onready var selection_sprite: Sprite3D = $selected

enum HarvestState {
	IDLE,
	MOVE_TO_DOCK,
	GATHER,
	MOVE_TO_DROPOFF,
	DROPOFF,
	MANUAL
}

enum CommandType {
	MOVE,
	ATTACK,
	ATTACK_MOVE,
	GUARD,
	HOLD,
	STOP,
	HARVEST
}

var state: HarvestState = HarvestState.IDLE
var current_load: int = 0
var gather_accum: float = 0.0
var supply_dock: Node3D
var dropoff: Node3D
var arrive_distance: float = 0.4
var use_nav_agent: bool = false
var current_target: Vector3 = Vector3.ZERO
var has_target: bool = false
var command_queue: Array = []
var manual_override: bool = false
var dropoff_timer: float = 0.0
var current_manual_command: Dictionary = {}
var progress_anchor: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var stuck_recovery_count: int = 0
var total_stuck_recoveries: int = 0

func _ready() -> void:
	add_to_group("units")
	setup_selection_visual()
	setup_navigation()
	supply_dock = get_node_or_null(supply_dock_path)
	dropoff = get_node_or_null(dropoff_path)
	_apply_economy_data()
	_reset_movement_progress()
	if auto_harvest_enabled and supply_dock != null and dropoff != null:
		_set_state(HarvestState.MOVE_TO_DOCK)

func setup_navigation() -> void:
	if nav_agent == null:
		use_nav_agent = false
		return
	use_nav_agent = true
	nav_agent.avoidance_enabled = nav_avoidance_enabled
	nav_agent.path_desired_distance = arrive_distance
	nav_agent.target_desired_distance = arrive_distance
	nav_agent.radius = nav_radius
	nav_agent.max_speed = move_speed

func _apply_economy_data() -> void:
	var economy := _get_current_economy_data()
	if economy == null:
		return
	gather_rate = economy.supply_gather_rate
	dropoff_time = economy.drop_off_time

func _get_current_economy_data() -> EconomyData:
	if DataRegistry == null or GameManager == null:
		return null
	var faction: FactionData = DataRegistry.get_faction(GameManager.current_faction_id)
	if faction == null or faction.economy_id == "":
		return null
	return DataRegistry.get_economy(faction.economy_id)

func setup_selection_visual() -> void:
	if selection_sprite == null:
		return
	selection_sprite.visible = false

func selected() -> void:
	if selection_sprite:
		selection_sprite.visible = true

func deselect() -> void:
	if selection_sprite:
		selection_sprite.visible = false

func get_selection_key() -> String:
	return "supply_truck"

func issue_command(command: Dictionary, queued: bool) -> void:
	var cmd_type := int(command.get("type", CommandType.MOVE))
	match cmd_type:
		CommandType.STOP, CommandType.HOLD:
			_stop_actions()
		CommandType.HARVEST:
			var target: Node3D = command.get("target", null) as Node3D
			if target != null and is_instance_valid(target):
				supply_dock = target
				auto_harvest_enabled = true
				manual_override = false
				_set_state(HarvestState.MOVE_TO_DOCK)
		CommandType.MOVE, CommandType.ATTACK, CommandType.ATTACK_MOVE, CommandType.GUARD:
			var target_pos: Vector3 = command.get("position", global_position) as Vector3
			_issue_manual_move(target_pos, queued)
		_:
			pass

func issue_move(target: Vector3, queued: bool) -> void:
	_issue_manual_move(target, queued)

func _issue_manual_move(target: Vector3, queued: bool) -> void:
	manual_override = true
	state = HarvestState.MANUAL
	if not queued:
		command_queue.clear()
		current_manual_command = {}
		has_target = false
	command_queue.append({
		"type": "move",
		"position": target
	})
	if not has_target:
		_start_next_manual_command()


func _stop_actions() -> void:
	command_queue.clear()
	has_target = false
	manual_override = false
	state = HarvestState.IDLE
	current_manual_command = {}
	_reset_movement_progress()

func _physics_process(delta: float) -> void:
	if manual_override:
		_process_manual(delta)
		return
	_process_auto(delta)

func _process_manual(delta: float) -> void:
	if not has_target:
		_start_next_manual_command()
	if has_target:
		if _move_towards(current_target, delta):
			has_target = false
		if not has_target and command_queue.is_empty():
			manual_override = false
			current_manual_command = {}
			if auto_harvest_enabled and supply_dock != null and dropoff != null:
				_set_state(HarvestState.MOVE_TO_DOCK)

func _process_auto(delta: float) -> void:
	match state:
		HarvestState.MOVE_TO_DOCK:
			if _move_towards(current_target, delta):
				_set_state(HarvestState.GATHER)
		HarvestState.GATHER:
			_process_gather(delta)
		HarvestState.MOVE_TO_DROPOFF:
			if _move_towards(current_target, delta):
				_set_state(HarvestState.DROPOFF)
		HarvestState.DROPOFF:
			_process_dropoff(delta)
		_:
			pass

func _process_gather(delta: float) -> void:
	if supply_dock == null:
		_set_state(HarvestState.IDLE)
		return
	gather_accum += gather_rate * delta
	var to_take: int = int(gather_accum)
	if to_take <= 0:
		return
	gather_accum -= float(to_take)
	var taken: int = 0
	if supply_dock.has_method("take_supply"):
		taken = supply_dock.take_supply(to_take)
	current_load += taken
	if current_load >= capacity or (supply_dock.has_method("is_depleted") and supply_dock.is_depleted()):
		_set_state(HarvestState.MOVE_TO_DROPOFF)

func _process_dropoff(delta: float) -> void:
	if dropoff == null:
		_set_state(HarvestState.IDLE)
		return
	if dropoff_timer > 0.0:
		dropoff_timer = max(dropoff_timer - delta, 0.0)
		return
	if dropoff.has_method("deposit"):
		dropoff.deposit(current_load)
	current_load = 0
	if supply_dock != null and supply_dock.has_method("is_depleted") and supply_dock.is_depleted():
		_set_state(HarvestState.IDLE)
	else:
		_set_state(HarvestState.MOVE_TO_DOCK)

func _set_state(new_state: HarvestState) -> void:
	state = new_state
	if state == HarvestState.MOVE_TO_DOCK and supply_dock != null:
		_set_move_target(supply_dock.global_position)
	elif state == HarvestState.MOVE_TO_DROPOFF and dropoff != null:
		_set_move_target(dropoff.global_position)
	elif state == HarvestState.DROPOFF:
		dropoff_timer = dropoff_time
	elif state == HarvestState.IDLE:
		has_target = false
	_reset_movement_progress()

func _set_move_target(target: Vector3) -> void:
	current_target = target
	has_target = true
	if use_nav_agent:
		nav_agent.target_position = target
	_reset_movement_progress()

func _start_next_manual_command() -> void:
	if command_queue.is_empty():
		has_target = false
		current_manual_command = {}
		return
	current_manual_command = command_queue.pop_front()
	var target: Vector3 = current_manual_command.get("position", global_position) as Vector3
	_set_move_target(target)

func _move_towards(target: Vector3, delta: float) -> bool:
	var current_position := global_position
	var target_pos := target
	target_pos.y = current_position.y
	var next_position := target_pos
	if use_nav_agent:
		var path: PackedVector3Array = nav_agent.get_current_navigation_path()
		if path.size() > 0 and not nav_agent.is_navigation_finished():
			next_position = nav_agent.get_next_path_position()
			next_position.y = current_position.y
	var travel_vector := next_position - current_position
	var distance := travel_vector.length()
	if distance <= arrive_distance:
		global_position = next_position
		var final_distance: float = global_position.distance_to(target_pos)
		if final_distance <= arrive_distance:
			_reset_movement_progress()
			return true
		if use_nav_agent and not nav_agent.is_navigation_finished():
			_update_stuck_recovery(target_pos, delta)
			return false
		_update_stuck_recovery(target_pos, delta)
		return false
	var movement_dir := travel_vector.normalized()
	var separation := _compute_separation_vector(current_position)
	if separation.length_squared() > 0.0001:
		movement_dir = (movement_dir + separation * separation_weight).normalized()
	var target_distance := current_position.distance_to(target_pos)
	var speed_scale := 1.0
	if target_distance < destination_slowdown_distance:
		speed_scale = clamp(target_distance / max(destination_slowdown_distance, 0.01), 0.35, 1.0)
	var step := move_speed * speed_scale * delta
	if step >= distance:
		global_position = next_position
		var final_distance: float = global_position.distance_to(target_pos)
		if final_distance <= arrive_distance:
			_update_stuck_recovery(target_pos, delta)
			return true
		if use_nav_agent and not nav_agent.is_navigation_finished():
			_update_stuck_recovery(target_pos, delta)
			return false
		_update_stuck_recovery(target_pos, delta)
		return false
	global_position = current_position + movement_dir * step
	if movement_dir.length_squared() > 0.001:
		look_at(current_position + Vector3(movement_dir.x, 0, movement_dir.z), Vector3.UP)
	_update_stuck_recovery(target_pos, delta)
	return false


func _compute_separation_vector(origin: Vector3) -> Vector3:
	if separation_radius <= 0.01:
		return Vector3.ZERO
	var offset_sum := Vector3.ZERO
	var hits := 0
	for unit in get_tree().get_nodes_in_group("units"):
		if unit == self or not is_instance_valid(unit):
			continue
		if not unit is Node3D:
			continue
		var other_team = unit.get("team_id")
		if typeof(other_team) == TYPE_INT and other_team != team_id:
			continue
		var delta: Vector3 = origin - unit.global_position
		delta.y = 0.0
		var dist: float = delta.length()
		if dist <= 0.001 or dist > separation_radius:
			continue
		var push: Vector3 = delta.normalized() * ((separation_radius - dist) / separation_radius)
		offset_sum += push
		hits += 1
	if hits == 0:
		return Vector3.ZERO
	return offset_sum / float(hits)


func _reset_movement_progress() -> void:
	progress_anchor = global_position
	stuck_timer = 0.0
	stuck_recovery_count = 0


func _update_stuck_recovery(target_pos: Vector3, delta: float) -> void:
	if not has_target:
		return
	if global_position.distance_to(progress_anchor) > stuck_distance_threshold:
		progress_anchor = global_position
		stuck_timer = 0.0
		return
	if global_position.distance_to(target_pos) <= max(arrive_distance * 2.0, 0.45):
		stuck_timer = 0.0
		return
	stuck_timer += delta
	if stuck_timer < stuck_timeout:
		return
	stuck_timer = 0.0
	stuck_recovery_count += 1
	total_stuck_recoveries += 1
	var heading := target_pos - global_position
	heading.y = 0.0
	if heading.length_squared() < 0.001:
		heading = Vector3.FORWARD
	var side := heading.normalized().cross(Vector3.UP).normalized()
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	var lane_sign := 1.0 if stuck_recovery_count % 2 == 1 else -1.0
	var recovery_target := target_pos + side * stuck_repath_offset * lane_sign
	recovery_target.y = global_position.y
	if use_nav_agent:
		nav_agent.target_position = recovery_target
	if stuck_recovery_count >= max_stuck_recoveries:
		_reset_movement_progress()


func get_navigation_stats() -> Dictionary:
	return {
		"stuck_recoveries": total_stuck_recoveries,
		"moving": has_target
	}


func get_vision_range() -> float:
	return 10.0
