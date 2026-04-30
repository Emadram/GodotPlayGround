extends Node3D

@export var unit_data: UnitData

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

func _ready() -> void:
	add_to_group("units")
	setup_selection_visual()
	apply_unit_data()
	deselect()
	_start_next_command()


func apply_unit_data() -> void:
	if unit_data == null:
		return
	max_health = unit_data.max_health
	current_health = max_health
	move_speed = unit_data.move_speed


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
	var position := global_position
	var target := current_target
	target.y = position.y
	var direction := target - position
	var distance := direction.length()
	if distance <= arrive_distance:
		global_position = target
		_start_next_command()
		return
	var step := move_speed * delta
	if step >= distance:
		global_position = target
		_start_next_command()
		return
	global_position = position + direction.normalized() * step
	if direction.length_squared() > 0.001:
		look_at(position + Vector3(direction.x, 0, direction.z), Vector3.UP)


func _start_next_command() -> void:
	if command_queue.is_empty():
		has_target = false
		state = UnitState.IDLE
		return
	current_target = command_queue.pop_front()
	has_target = true
	state = UnitState.MOVE


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
