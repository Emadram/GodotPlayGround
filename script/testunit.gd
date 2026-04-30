extends Node3D

@export var unit_data: UnitData
@export var team_id: int = 1
@export var projectile_scene: PackedScene = preload("res://scene/projectile.tscn")

@onready var nav_agent: NavigationAgent3D = $NavAgent
@onready var health_bar: Node3D = $HealthBar
@onready var health_fill: MeshInstance3D = $HealthBar/BarFill
@onready var hit_flash: MeshInstance3D = $HitFlash
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio

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
var weapon_data: WeaponData
var attack_range: float = 0.0
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0
var attack_target: Node3D
var state: UnitState = UnitState.IDLE
var command_queue: Array = []
var current_target: Vector3 = Vector3.ZERO
var has_target: bool = false
var arrive_distance: float = 0.2
var use_nav_agent: bool = false
var bar_fill_half_width: float = 0.4
var hit_flash_duration: float = 0.08
var hit_sound_duration: float = 0.06
var hit_sound_frequency: float = 880.0

func _ready() -> void:
	add_to_group("units")
	setup_selection_visual()
	apply_unit_data()
	deselect()
	setup_navigation()
	setup_hit_audio()
	update_health_bar()
	_start_next_command()


func apply_unit_data() -> void:
	if unit_data == null:
		return
	max_health = unit_data.max_health
	current_health = max_health
	move_speed = unit_data.move_speed
	if DataRegistry and unit_data.weapon_id != "":
		weapon_data = DataRegistry.get_weapon(unit_data.weapon_id)
	if weapon_data != null:
		attack_range = weapon_data.range
		attack_cooldown = weapon_data.cooldown
	update_health_bar()


func setup_navigation() -> void:
	if nav_agent == null:
		use_nav_agent = false
		return
	use_nav_agent = true
	nav_agent.avoidance_enabled = false
	nav_agent.path_desired_distance = arrive_distance
	nav_agent.target_desired_distance = arrive_distance


func setup_hit_audio() -> void:
	if hit_audio == null:
		return
	if hit_audio.stream == null:
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = 44100
		generator.buffer_length = 0.1
		hit_audio.stream = generator
	hit_audio.volume_db = -12.0


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
	attack_timer = max(attack_timer - delta, 0.0)
	if state == UnitState.MOVE and has_target:
		_process_move(delta)
	else:
		_process_attack(delta)


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


func _process_attack(_delta: float) -> void:
	if weapon_data == null:
		state = UnitState.IDLE
		return
	if attack_target == null or not is_instance_valid(attack_target) or not _is_enemy(attack_target):
		attack_target = _find_target()
		if attack_target == null:
			state = UnitState.IDLE
			return
	var distance := global_position.distance_to(attack_target.global_position)
	if distance > attack_range:
		attack_target = _find_target()
		if attack_target == null:
			state = UnitState.IDLE
			return
	state = UnitState.ATTACK
	if attack_timer <= 0.0:
		_fire_weapon(attack_target)
		attack_timer = attack_cooldown


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
	attack_target = null


func _find_target() -> Node3D:
	if weapon_data == null:
		return null
	var sight := unit_data.sight_range if unit_data != null else attack_range
	var best_target: Node3D = null
	var best_distance := sight
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit == self:
			continue
		if not _is_enemy(unit):
			continue
		if unit is Node3D:
			var dist := global_position.distance_to(unit.global_position)
			if dist <= best_distance:
				best_distance = dist
				best_target = unit
	return best_target


func _is_enemy(unit: Node) -> bool:
	var other_team = unit.get("team_id")
	if typeof(other_team) != TYPE_INT:
		return false
	return other_team != team_id


func _fire_weapon(target_unit: Node3D) -> void:
	if projectile_scene == null:
		return
	var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var projectile := projectile_scene.instantiate()
	root.add_child(projectile)
	var origin := global_position + Vector3(0, 0.8, 0)
	var target_pos := target_unit.global_position + Vector3(0, 0.8, 0)
	projectile.setup(weapon_data, origin, target_pos, target_unit, team_id)


func apply_damage(amount: int, _source: Node) -> void:
	current_health = max(current_health - amount, 0)
	update_health_bar()
	flash_hit()
	play_hit_sound()
	if current_health <= 0:
		die()


func die() -> void:
	queue_free()


func update_health_bar() -> void:
	if health_fill == null:
		return
	var ratio := 0.0
	if max_health > 0:
		ratio = float(current_health) / float(max_health)
	ratio = clamp(ratio, 0.0, 1.0)
	health_fill.scale.x = ratio
	health_fill.position.x = -bar_fill_half_width * (1.0 - ratio)
	if health_bar != null:
		health_bar.visible = current_health < max_health


func flash_hit() -> void:
	if hit_flash == null:
		return
	hit_flash.visible = true
	var timer := get_tree().create_timer(hit_flash_duration)
	timer.timeout.connect(func():
		if is_instance_valid(hit_flash):
			hit_flash.visible = false
	)


func play_hit_sound() -> void:
	if hit_audio == null:
		return
	if not hit_audio.playing:
		hit_audio.play()
	var playback := hit_audio.get_stream_playback()
	if playback == null:
		return
	var mix_rate := 44100.0
	var frames_available: int = playback.get_frames_available()
	var sample_count: int = min(frames_available, int(mix_rate * hit_sound_duration))
	for i in range(sample_count):
		var t := float(i) / mix_rate
		var sample := sin(TAU * hit_sound_frequency * t) * 0.2
		playback.push_frame(Vector2(sample, sample))


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
