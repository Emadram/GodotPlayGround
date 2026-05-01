extends Node3D

@export var team_id: int = 1
@export var move_speed: float = 4.5
@export var construction_site_scene: PackedScene = preload("res://scene/construction_site.tscn")
@export var build_range: float = 1.4
@export var build_rate: float = 1.0

@onready var nav_agent: NavigationAgent3D = $NavAgent
@onready var selection_sprite: Sprite3D = $selected

enum CommandType {
	MOVE,
	ATTACK,
	ATTACK_MOVE,
	GUARD,
	HOLD,
	STOP,
	HARVEST,
	BUILD
}

var current_target: Vector3 = Vector3.ZERO
var has_target: bool = false
var command_queue: Array = []
var current_command: Dictionary = {}
var active_construction_site: Node3D
var arrive_distance: float = 0.4
var use_nav_agent: bool = false
var last_build_state: String = "idle"

func _ready() -> void:
	add_to_group("units")
	add_to_group("builders")
	setup_selection_visual()
	setup_navigation()


func setup_selection_visual() -> void:
	if selection_sprite != null:
		selection_sprite.visible = false


func setup_navigation() -> void:
	if nav_agent == null:
		use_nav_agent = false
		return
	use_nav_agent = true
	nav_agent.avoidance_enabled = true
	nav_agent.path_desired_distance = arrive_distance
	nav_agent.target_desired_distance = arrive_distance
	nav_agent.radius = 0.8
	nav_agent.max_speed = move_speed


func selected() -> void:
	if selection_sprite != null:
		selection_sprite.visible = true


func deselect() -> void:
	if selection_sprite != null:
		selection_sprite.visible = false


func get_selection_key() -> String:
	return "dozer"


func can_construct() -> bool:
	return true


func issue_command(command: Dictionary, queued: bool) -> void:
	var cmd_type := int(command.get("type", CommandType.MOVE))
	match cmd_type:
		CommandType.STOP, CommandType.HOLD:
			_stop_actions()
		CommandType.BUILD:
			if not queued:
				_stop_actions()
			command_queue.append(command)
			var building_id := str(command.get("building_id", ""))
			var position: Vector3 = command.get("position", global_position) as Vector3
			_set_build_state("queued build %s at (%.1f, %.1f), queued=%s" % [building_id, position.x, position.z, str(queued)])
			if not has_target and active_construction_site == null:
				_start_next_command()
		CommandType.MOVE:
			if not queued:
				_stop_actions()
			command_queue.append({
				"type": CommandType.MOVE,
				"position": command.get("position", global_position)
			})
			if not has_target:
				_start_next_command()
		CommandType.ATTACK, CommandType.ATTACK_MOVE, CommandType.GUARD:
			_set_build_state("ignored combat command")
		_:
			pass


func issue_move(target: Vector3, queued: bool) -> void:
	issue_command({
		"type": CommandType.MOVE,
		"position": target
	}, queued)


func _physics_process(delta: float) -> void:
	if active_construction_site != null:
		if not is_instance_valid(active_construction_site):
			active_construction_site = null
		else:
			_process_construction(delta)
			return
	if not has_target:
		_start_next_command()
	if has_target:
		if int(current_command.get("type", CommandType.MOVE)) == CommandType.BUILD:
			var build_distance: float = global_position.distance_to(current_target)
			if build_distance <= build_range:
				has_target = false
				_set_build_state("reached build range")
				_begin_construction(current_command)
				return
		if _move_towards(current_target, delta):
			has_target = false
			if int(current_command.get("type", CommandType.MOVE)) == CommandType.BUILD:
				_begin_construction(current_command)


func _stop_actions() -> void:
	command_queue.clear()
	current_command = {}
	has_target = false
	active_construction_site = null


func _start_next_command() -> void:
	if command_queue.is_empty():
		current_command = {}
		has_target = false
		return
	current_command = command_queue.pop_front()
	current_target = current_command.get("position", global_position) as Vector3
	current_target.y = global_position.y
	has_target = true
	if int(current_command.get("type", CommandType.MOVE)) == CommandType.BUILD:
		_set_build_state("moving to build site")
	if use_nav_agent:
		nav_agent.target_position = current_target


func _move_towards(target: Vector3, delta: float) -> bool:
	var current_position := global_position
	var target_pos := target
	target_pos.y = current_position.y
	var distance_to_target: float = current_position.distance_to(target_pos)
	if distance_to_target <= arrive_distance:
		return true
	var next_position := target_pos
	if use_nav_agent:
		nav_agent.target_position = target_pos
		if not nav_agent.is_navigation_finished():
			next_position = nav_agent.get_next_path_position()
			next_position.y = current_position.y
	var direction: Vector3 = next_position - current_position
	if direction.length_squared() <= 0.001:
		direction = target_pos - current_position
		direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return distance_to_target <= arrive_distance
	var step: float = min(move_speed * delta, distance_to_target)
	if step >= direction.length() and next_position.distance_to(target_pos) <= arrive_distance:
		global_position = next_position
	else:
		global_position = current_position + direction.normalized() * step
	look_at(current_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)
	return global_position.distance_to(target_pos) <= arrive_distance


func _begin_construction(command: Dictionary) -> void:
	var resume_target: Node3D = command.get("target", null) as Node3D
	if resume_target != null and is_instance_valid(resume_target) and resume_target.has_method("advance_construction"):
		active_construction_site = resume_target
		_set_build_state("resumed construction: %s" % str(resume_target.get("building_id")))
		return
	var building_id := str(command.get("building_id", ""))
	if building_id == "":
		_set_build_state("construction failed: empty id")
		return
	var building_data: BuildingData = DataRegistry.get_building(building_id) if DataRegistry else null
	if building_data == null:
		_set_build_state("construction failed: missing BuildingData for %s" % building_id)
		return
	if GameManager != null and not GameManager.spend_resources(building_data.cost):
		_set_build_state("construction failed: not enough resources for %s cost=%d" % [building_id, building_data.cost])
		return
	if construction_site_scene == null:
		_set_build_state("construction failed: no site scene")
		return
	var site := construction_site_scene.instantiate() as Node3D
	if site == null:
		_set_build_state("construction failed: scene instantiate failed")
		return
	var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	root.add_child(site)
	var target_pos: Vector3 = command.get("position", global_position) as Vector3
	target_pos.y = 0.0
	site.global_position = target_pos
	if site.has_method("configure"):
		site.configure(building_id, team_id, building_data, false)
	active_construction_site = site
	_set_build_state("construction started: %s" % building_id)


func _process_construction(delta: float) -> void:
	if active_construction_site == null or not is_instance_valid(active_construction_site):
		active_construction_site = null
		return
	var site_pos := active_construction_site.global_position
	if global_position.distance_to(site_pos) > build_range:
		_move_towards(site_pos, delta)
		return
	if active_construction_site.has_method("advance_construction"):
		var done: bool = active_construction_site.advance_construction(delta * build_rate)
		if done:
			active_construction_site = null
			current_command = {}
			_set_build_state("construction completed")


func get_navigation_stats() -> Dictionary:
	return {
		"stuck_recoveries": 0,
		"moving": has_target
	}


func get_vision_range() -> float:
	return 12.0


func get_builder_debug_state() -> Dictionary:
	return {
		"state": last_build_state,
		"has_target": has_target,
		"queue_size": command_queue.size(),
		"active_site": active_construction_site != null and is_instance_valid(active_construction_site)
	}


func _set_build_state(message: String) -> void:
	last_build_state = message
	print("[Dozer] ", message)
