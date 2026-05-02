extends CharacterBody3D
# Economy unit: kinematic-style movement via global_position; CharacterBody3D gives a solid physics collider for the truck hull.

@export var supply_dock_path: NodePath
@export var dropoff_path: NodePath
@export var capacity: int = 1000
@export var move_speed: float = 2.2
@export var gather_rate: float = 200.0
@export var dropoff_time: float = 1.5
@export var auto_harvest_enabled: bool = true
@export var team_id: int = 1
## Dock/dropoff roots sit inside StaticBody3D; aim short of center so we do not grind into solids every frame.
@export var resource_approach_standoff: float = 1.9
@export var resource_arrive_distance: float = 0.85
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
@onready var supply_counter: Label3D = $SupplyCounter

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
## Harvest-command dock; cleared when depleted or on stop. Otherwise truck uses nearest dock.
var preferred_supply_dock: Node3D = null
var _gather_pulse_amount: int = 0
var _gather_pulse_timer: float = 0.0
var _delivered_flash_amount: int = 0
var _delivered_flash_timer: float = 0.0
var _collision_log_time: float = 0.0
var _collision_log_collider_id: int = 0
## When nav path stays empty, periodically re-send target so the agent can build a corridor after mesh bake.
var _nav_empty_path_frames: int = 0
const NAV_EMPTY_PATH_REPATH_FRAMES: int = 24

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	up_direction = Vector3.UP
	add_to_group("units")
	setup_selection_visual()
	setup_navigation()
	_refresh_supply_dock()
	_refresh_dropoff()
	# print("[SupplyTruck] ready dock=%s dropoff=%s auto_harvest=%s" % [str(supply_dock != null), str(dropoff != null), str(auto_harvest_enabled)])
	_apply_economy_data()
	_reset_movement_progress()
	if supply_counter:
		supply_counter.visible = false
	if auto_harvest_enabled:
		_schedule_auto_supply_startup()


## call_deferred() into a method that uses await can drop the coroutine; a one-shot SceneTreeTimer
## then await from the signal handler reliably runs after the first frames (nav / physics).
func _schedule_auto_supply_startup() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(0.0)
	timer.timeout.connect(_on_auto_supply_startup_timer, CONNECT_ONE_SHOT)


func _on_auto_supply_startup_timer() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if not auto_harvest_enabled:
		return
	if manual_override:
		return
	if state != HarvestState.IDLE:
		return
	_refresh_supply_dock()
	_refresh_dropoff()
	if supply_dock == null or dropoff == null:
		# print("[SupplyTruck] delayed auto start skipped: dock=%s dropoff=%s" % [str(supply_dock != null), str(dropoff != null)])
		return
	# print("[SupplyTruck] delayed auto start -> MOVE_TO_DOCK")
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
	# print("[SupplyTruck] economy gather_rate=%.1f dropoff_time=%.2f" % [gather_rate, dropoff_time])

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
				preferred_supply_dock = target
				supply_dock = target
				auto_harvest_enabled = true
				manual_override = false
				# print("[SupplyTruck] harvest command -> preferred dock=%s" % target.name)
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
	preferred_supply_dock = null
	state = HarvestState.IDLE
	current_manual_command = {}
	velocity = Vector3.ZERO
	# print("[SupplyTruck] stop/hold -> idle")
	_reset_movement_progress()

func _physics_process(delta: float) -> void:
	if manual_override:
		_process_manual(delta)
	else:
		_process_auto(delta)
	_update_supply_counter(delta)

func _process_manual(delta: float) -> void:
	if not has_target:
		_start_next_manual_command()
	if has_target:
		if _move_towards(current_target, delta):
			has_target = false
		if not has_target and command_queue.is_empty():
			manual_override = false
			current_manual_command = {}
			_resume_auto_after_manual_move()

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
		# print("[SupplyTruck] gather aborted: no dock")
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
	if taken > 0:
		_gather_pulse_amount = taken
		_gather_pulse_timer = 0.45
		# print("[SupplyTruck] gather +%s load=%s/%s dock_remaining=%s" % [taken, current_load, capacity, _dock_supply_left()])
	# Full: always haul. Depleted dock: only go to dropoff if we actually collected something.
	if current_load >= capacity:
		# print("[SupplyTruck] gather done -> move to dropoff (full)")
		_set_state(HarvestState.MOVE_TO_DROPOFF)
	elif supply_dock.has_method("is_depleted") and supply_dock.is_depleted():
		if current_load > 0:
			# print("[SupplyTruck] gather done -> move to dropoff (dock depleted, load=%s)" % current_load)
			_set_state(HarvestState.MOVE_TO_DROPOFF)
		else:
			if preferred_supply_dock == supply_dock:
				preferred_supply_dock = null
				# print("[SupplyTruck] preferred dock empty, cleared")
			# print("[SupplyTruck] gather stopped: dock depleted and no cargo -> idle")
			_set_state(HarvestState.IDLE)

func _process_dropoff(delta: float) -> void:
	if dropoff == null:
		# print("[SupplyTruck] dropoff aborted: no dropoff node")
		_set_state(HarvestState.IDLE)
		return
	if dropoff_timer > 0.0:
		dropoff_timer = max(dropoff_timer - delta, 0.0)
		return
	if dropoff.has_method("deposit"):
		var dep_amt: int = current_load
		# print("[SupplyTruck] deposit load=%s" % dep_amt)
		dropoff.deposit(dep_amt)
		_delivered_flash_amount = dep_amt
		_delivered_flash_timer = 0.65
	current_load = 0
	if supply_dock != null and supply_dock.has_method("is_depleted") and supply_dock.is_depleted():
		if preferred_supply_dock == supply_dock:
			preferred_supply_dock = null
			# print("[SupplyTruck] preferred dock depleted, cleared")
		# print("[SupplyTruck] dock depleted -> idle")
		_set_state(HarvestState.IDLE)
	else:
		# print("[SupplyTruck] dropoff complete -> return to dock")
		_set_state(HarvestState.MOVE_TO_DOCK)

func _set_state(new_state: HarvestState) -> void:
	var prev: HarvestState = state
	var effective: HarvestState = new_state
	if new_state == HarvestState.MOVE_TO_DOCK:
		_refresh_supply_dock()
		if supply_dock == null:
			effective = HarvestState.IDLE
	elif new_state == HarvestState.MOVE_TO_DROPOFF:
		if current_load <= 0:
			# print("[SupplyTruck] dropoff leg skipped (no cargo) -> dock")
			effective = HarvestState.MOVE_TO_DOCK
			_refresh_supply_dock()
			if supply_dock == null:
				effective = HarvestState.IDLE
		else:
			_refresh_dropoff()
			if dropoff == null:
				effective = HarvestState.IDLE
	state = effective
	# print("[SupplyTruck] state %s -> %s" % [str(prev), str(state)])
	match state:
		HarvestState.MOVE_TO_DOCK:
			if supply_dock != null:
				_set_move_target(_approach_point_outside_node(supply_dock))
		HarvestState.MOVE_TO_DROPOFF:
			if dropoff != null:
				_set_move_target(_approach_point_outside_node(dropoff))
		HarvestState.DROPOFF:
			dropoff_timer = dropoff_time
			# print("[SupplyTruck] dropoff wait %.2fs" % dropoff_timer)
		HarvestState.IDLE:
			has_target = false
			velocity = Vector3.ZERO
		_:
			pass
	_reset_movement_progress()

func _set_move_target(target: Vector3) -> void:
	current_target = target
	has_target = true
	if use_nav_agent and nav_agent != null:
		_snap_character_to_nav_mesh_if_needed()
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

func _arrive_radius_for_current_move() -> float:
	if manual_override:
		return arrive_distance
	if state == HarvestState.MOVE_TO_DOCK or state == HarvestState.MOVE_TO_DROPOFF:
		return maxf(arrive_distance, resource_arrive_distance)
	return arrive_distance


func _approach_point_outside_node(node: Node3D) -> Vector3:
	var center := node.global_position
	center.y = global_position.y
	var from_truck := center - global_position
	from_truck.y = 0.0
	if from_truck.length_squared() < 0.0004:
		from_truck = Vector3(0, 0, 1)
	var inward := from_truck.normalized()
	return center - inward * resource_approach_standoff


func _snap_character_to_nav_mesh_if_needed() -> void:
	if nav_agent == null or not use_nav_agent:
		return
	var map_rid: RID = nav_agent.get_navigation_map()
	if not map_rid.is_valid():
		return
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, global_position)
	var delta_h := Vector3(closest.x - global_position.x, 0.0, closest.z - global_position.z)
	var d: float = delta_h.length()
	if d < 0.02 or d > 6.0:
		return
	global_position += delta_h


func _move_towards(target: Vector3, delta: float) -> bool:
	var current_position := global_position
	var target_pos := target
	target_pos.y = current_position.y
	var next_position := target_pos
	var use_arrive: float = _arrive_radius_for_current_move()
	var path_sz: int = 0
	var nav_fin: bool = true
	if use_nav_agent:
		var path: PackedVector3Array = nav_agent.get_current_navigation_path()
		path_sz = path.size()
		nav_fin = nav_agent.is_navigation_finished()
		if path_sz > 0 and not nav_fin:
			next_position = nav_agent.get_next_path_position()
			next_position.y = current_position.y
	var travel_vector := next_position - current_position
	var distance := travel_vector.length()
	var dist_goal: float = current_position.distance_to(target_pos)
	if use_nav_agent and nav_agent != null:
		if path_sz == 0 and dist_goal > 0.4:
			_nav_empty_path_frames += 1
			if _nav_empty_path_frames >= NAV_EMPTY_PATH_REPATH_FRAMES:
				_nav_empty_path_frames = 0
				nav_agent.target_position = current_target
		elif path_sz > 0:
			_nav_empty_path_frames = 0
	if distance <= use_arrive:
		_push_kinematic_translation(next_position - global_position, true)
		var final_distance: float = global_position.distance_to(target_pos)
		if final_distance <= use_arrive:
			_reset_movement_progress()
			return true
		# Near the nav segment (next_path within arrive radius) but still far from the real goal:
		# the old code returned false here every frame, so the truck never ran the main move step.
		travel_vector = target_pos - current_position
		travel_vector.y = 0.0
		distance = travel_vector.length()
		if distance < 1e-5:
			if use_nav_agent and not nav_agent.is_navigation_finished():
				_update_stuck_recovery(target_pos, delta)
				return false
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
	var motion_len: float = minf(step, distance)
	var motion: Vector3 = Vector3(movement_dir.x, 0.0, movement_dir.z) * motion_len
	_push_kinematic_translation(motion, false)
	if movement_dir.length_squared() > 0.001:
		look_at(global_position + Vector3(movement_dir.x, 0, movement_dir.z), Vector3.UP)
	_update_stuck_recovery(target_pos, delta)
	var final_distance2: float = global_position.distance_to(target_pos)
	if final_distance2 <= use_arrive:
		var path_empty: bool = true
		if use_nav_agent and nav_agent != null:
			path_empty = nav_agent.get_current_navigation_path().is_empty()
		if not use_nav_agent or nav_agent.is_navigation_finished() or path_empty:
			_reset_movement_progress()
			return true
	return false


# CharacterBody3D must use move_and_collide (or move_and_slide); raw global_position teleports through StaticBody3D.
func _push_kinematic_translation(offset: Vector3, quiet: bool) -> void:
	offset.y = 0.0
	if offset.length_squared() < 1e-10:
		return
	var motion: Vector3 = offset
	var hit: KinematicCollision3D = move_and_collide(motion, false, 0.08, true, 4)
	if hit != null:
		var rem: Vector3 = hit.get_remainder()
		rem.y = 0.0
		var n: Vector3 = hit.get_normal()
		n.y = 0.0
		if rem.length_squared() > 1e-8 and n.length_squared() > 1e-8:
			n = n.normalized()
			var slide_try: Vector3 = rem.slide(n)
			slide_try.y = 0.0
			if slide_try.length_squared() > 1e-10:
				move_and_collide(slide_try, false, 0.08, true, 4)
		if not quiet:
			_maybe_log_collision_hit(hit)


func _maybe_log_collision_hit(hit: KinematicCollision3D) -> void:
	var rem_len: float = hit.get_remainder().length()
	if rem_len < 0.08:
		return
	var other: Object = hit.get_collider()
	var oid: int = other.get_instance_id() if other != null else 0
	var now: float = float(Time.get_ticks_msec()) * 0.001
	if oid == _collision_log_collider_id and now - _collision_log_time < 0.9:
		return
	_collision_log_time = now
	_collision_log_collider_id = oid
	# print("[SupplyTruck] collision with %s remainder=%.3f" % [other if other != null else "?", rem_len])


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
	if global_position.distance_to(target_pos) <= max(_arrive_radius_for_current_move() * 2.0, 0.45):
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


func _dock_supply_left() -> String:
	if supply_dock == null:
		return "n/a"
	var v: Variant = supply_dock.get("total_supply")
	if typeof(v) == TYPE_INT:
		return str(int(v))
	if typeof(v) == TYPE_FLOAT:
		return str(int(v))
	return "?"


func _resume_auto_after_manual_move() -> void:
	if not auto_harvest_enabled:
		_set_state(HarvestState.IDLE)
		return
	if current_load > 0:
		_refresh_dropoff()
		if dropoff != null:
			# print("[SupplyTruck] manual complete -> haul to nearest dropoff load=%s" % current_load)
			_set_state(HarvestState.MOVE_TO_DROPOFF)
			return
		# print("[SupplyTruck] manual complete, cargo but no dropoff -> idle")
		_set_state(HarvestState.IDLE)
		return
	_refresh_supply_dock()
	if supply_dock != null:
		# print("[SupplyTruck] manual complete -> nearest dock to collect")
		_set_state(HarvestState.MOVE_TO_DOCK)
		return
	# print("[SupplyTruck] manual complete, no dock -> idle")
	_set_state(HarvestState.IDLE)


func _refresh_supply_dock() -> void:
	supply_dock = _resolve_supply_dock()
	# if supply_dock != null:
	# 	print("[SupplyTruck] supply_dock -> %s" % supply_dock.name)


func _refresh_dropoff() -> void:
	dropoff = _find_nearest_dropoff_with_fallback()
	# if dropoff != null:
	# 	print("[SupplyTruck] dropoff -> %s" % dropoff.name)


func _resolve_supply_dock() -> Node3D:
	if preferred_supply_dock != null and is_instance_valid(preferred_supply_dock):
		if preferred_supply_dock.has_method("take_supply"):
			if not (preferred_supply_dock.has_method("is_depleted") and preferred_supply_dock.is_depleted()):
				return preferred_supply_dock
		preferred_supply_dock = null
		# print("[SupplyTruck] preferred dock unusable, using nearest")
	var n: Node3D = _find_nearest_supply_dock()
	if n != null:
		return n
	return get_node_or_null(supply_dock_path) as Node3D


func _find_nearest_supply_dock() -> Node3D:
	var from_pos := global_position
	var best_any: Node3D = null
	var best_any_d: float = INF
	var best_stocked: Node3D = null
	var best_stocked_d: float = INF
	for node in get_tree().get_nodes_in_group("supply_docks"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if not (node as Node3D).has_method("take_supply"):
			continue
		if not _supply_node_team_matches(node as Node):
			continue
		var n3: Node3D = node as Node3D
		var d: float = _horizontal_distance(from_pos, n3.global_position)
		var depleted: bool = n3.has_method("is_depleted") and n3.is_depleted()
		if not depleted and d < best_stocked_d:
			best_stocked = n3
			best_stocked_d = d
		if d < best_any_d:
			best_any = n3
			best_any_d = d
	if best_stocked != null:
		return best_stocked
	return best_any


func _find_nearest_dropoff_with_fallback() -> Node3D:
	var n: Node3D = _find_nearest_dropoff()
	if n != null:
		return n
	return get_node_or_null(dropoff_path) as Node3D


func _find_nearest_dropoff() -> Node3D:
	var from_pos := global_position
	var best: Node3D = null
	var best_d: float = INF
	for node in get_tree().get_nodes_in_group("dropoff_points"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if not (node as Node3D).has_method("deposit"):
			continue
		if not _supply_node_team_matches(node as Node):
			continue
		var n3: Node3D = node as Node3D
		var d: float = _horizontal_distance(from_pos, n3.global_position)
		if d < best_d:
			best = n3
			best_d = d
	return best


func _supply_node_team_matches(node: Node) -> bool:
	var t: Variant = node.get("team_id")
	if typeof(t) != TYPE_INT:
		return true
	return int(t) == team_id


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	var pa := Vector3(a.x, 0.0, a.z)
	var pb := Vector3(b.x, 0.0, b.z)
	return pa.distance_to(pb)


func _update_supply_counter(delta: float) -> void:
	if supply_counter == null:
		return
	if _delivered_flash_timer > 0.0:
		_delivered_flash_timer = max(_delivered_flash_timer - delta, 0.0)
	if _gather_pulse_timer > 0.0:
		_gather_pulse_timer = max(_gather_pulse_timer - delta, 0.0)

	if _delivered_flash_timer > 0.0:
		supply_counter.visible = true
		supply_counter.text = "Delivered\n%s" % _delivered_flash_amount
		return

	var show_counter := false
	var lines: String = ""
	match state:
		HarvestState.GATHER:
			show_counter = true
			lines = "Supply %s / %s" % [current_load, capacity]
			if _gather_pulse_timer > 0.0 and _gather_pulse_amount > 0:
				lines += "\n+%s" % _gather_pulse_amount
		HarvestState.MOVE_TO_DROPOFF:
			if current_load > 0:
				show_counter = true
				lines = "Hauling %s / %s" % [current_load, capacity]
		HarvestState.DROPOFF:
			if current_load > 0 or dropoff_timer > 0.0:
				show_counter = true
				lines = "Unloading %s / %s" % [current_load, capacity]
		HarvestState.MANUAL:
			if current_load > 0:
				show_counter = true
				lines = "Supply %s / %s" % [current_load, capacity]
		_:
			pass

	if show_counter:
		supply_counter.visible = true
		supply_counter.text = lines
	else:
		supply_counter.visible = false
		supply_counter.text = ""


func get_vision_range() -> float:
	return 10.0
