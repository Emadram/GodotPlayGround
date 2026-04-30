extends Node3D

@export var supply_dock_path: NodePath
@export var dropoff_path: NodePath
@export var capacity: int = 1000
@export var move_speed: float = 5.0
@export var gather_rate: float = 200.0
@export var dropoff_time: float = 1.5
@export var auto_harvest_enabled: bool = true

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

func _ready() -> void:
	add_to_group("units")
	setup_selection_visual()
	setup_navigation()
	supply_dock = get_node_or_null(supply_dock_path)
	dropoff = get_node_or_null(dropoff_path)
	if auto_harvest_enabled and supply_dock != null and dropoff != null:
		_set_state(HarvestState.MOVE_TO_DOCK)

func setup_navigation() -> void:
	if nav_agent == null:
		use_nav_agent = false
		return
	use_nav_agent = true
	nav_agent.avoidance_enabled = false
	nav_agent.path_desired_distance = arrive_distance
	nav_agent.target_desired_distance = arrive_distance

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

func issue_move(target: Vector3, queued: bool) -> void:
	manual_override = true
	state = HarvestState.MANUAL
	if not queued:
		command_queue.clear()
	command_queue.append(target)
	if not has_target:
		_start_next_manual_command()

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

func _set_move_target(target: Vector3) -> void:
	current_target = target
	has_target = true
	if use_nav_agent:
		nav_agent.target_position = target

func _start_next_manual_command() -> void:
	if command_queue.is_empty():
		has_target = false
		return
	_set_move_target(command_queue.pop_front())

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
	var direction := next_position - current_position
	var distance := direction.length()
	if distance <= arrive_distance:
		global_position = next_position
		return true
	var step := move_speed * delta
	if step >= distance:
		global_position = next_position
		return true
	global_position = current_position + direction.normalized() * step
	if direction.length_squared() > 0.001:
		look_at(current_position + Vector3(direction.x, 0, direction.z), Vector3.UP)
	return false
