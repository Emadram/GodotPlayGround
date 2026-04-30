extends Node3D

@export var unit_data: UnitData

@onready var nav_agent: NavigationAgent3D = $NavAgent

enum UnitState {
	IDLE,
	MOVE,
	ATTACK,
	BUILD,
	HARVEST,
	GARRISON
}

var max_health: int = 100
var current_health: int = 100
var move_speed: float = 5.0
var state: UnitState = UnitState.IDLE
var command_queue: Array = []
var current_target: Vector3 = Vector3.ZERO
var has_target: bool = false
var arrive_distance: float = 0.2
var use_nav_agent: bool = false

func _ready() -> void:
	add_to_group("units")
	setup_selection_visual()
	apply_unit_data()
	deselect()
	setup_navigation()
	_start_next_command()


func apply_unit_data() -> void:
	if unit_data == null:
		return
	max_health = unit_data.max_health
	current_health = max_health
	move_speed = unit_data.move_speed


func setup_navigation() -> void:
	if nav_agent == null:
		use_nav_agent = false
		return
	use_nav_agent = true
	nav_agent.avoidance_enabled = false
	nav_agent.path_desired_distance = arrive_distance
	nav_agent.target_desired_distance = arrive_distance


func issue_move(target: Vector3, queued: bool) -> void:
	if not queued:
		command_queue.clear()
	command_queue.append(target)
	if state != UnitState.MOVE or not has_target:
		_start_next_command()


func clear_commands() -> void:
	command_queue.clear()
	has_target = false
	state = UnitState.IDLE


func _physics_process(delta: float) -> void:
	if state == UnitState.MOVE and has_target:
		_process_move(delta)


func _process_move(delta: float) -> void:
	var current_position := global_position
	var target := current_target
	target.y = current_position.y
	var next_position := target
	if use_nav_agent:
		var path: PackedVector3Array = nav_agent.get_current_navigation_path()
		if path.size() > 0 and not nav_agent.is_navigation_finished():
			next_position = nav_agent.get_next_path_position()
			next_position.y = current_position.y
	var direction := next_position - current_position
	var distance := direction.length()
	if distance <= arrive_distance:
		global_position = next_position
		_start_next_command()
		return
	var step := move_speed * delta
	if step >= distance:
		global_position = next_position
		_start_next_command()
		return
	global_position = current_position + direction.normalized() * step
	if direction.length_squared() > 0.001:
		look_at(current_position + Vector3(direction.x, 0, direction.z), Vector3.UP)


func _start_next_command() -> void:
	if command_queue.is_empty():
		has_target = false
		state = UnitState.IDLE
		return
	current_target = command_queue.pop_front()
	has_target = true
	state = UnitState.MOVE
	if use_nav_agent:
		nav_agent.target_position = current_target


func setup_selection_visual() -> void:
	var selection_sprite:Sprite3D = $selected
	if selection_sprite == null:
		return
	selection_sprite.render_priority = 10
	var mat:StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_texture = selection_sprite.texture
	selection_sprite.material_override = mat


func selected() -> void:
	$selected.visible = true

func deselect() -> void:
	$selected.visible = false
