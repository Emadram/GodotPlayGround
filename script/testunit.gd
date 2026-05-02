extends CharacterBody3D
# Base infantry (Ranger / Rocket Soldier): command queue, combat, veterancy, FoW vision, Soldier_02 animation, weapon mesh, health bar.

@export var unit_data: UnitData
@export var team_id: int = 1
@export var xp_value: int = 10
@export var projectile_scene: PackedScene = preload("res://scene/projectile.tscn")
@export_group("Unit Presentation")
@export var personal_space_radius: float = 0.95
@export var range_ring_segments: int = 96
@export var idle_animation_name: String = "Idle"
@export var friendly_idle_animation_name: String = "Idle_Talking"
@export var selected_animation_name: String = "Pistol_idle"
@export var move_animation_name: String = "walk_formal"
@export var guard_animation_name: String = "crouch_idle"
@export var attack_animation_name: String = "Pistol_shoot"
@export var death_animation_name: String = "Death01"
@export var friendly_idle_radius: float = 3.0
@export_group("Health Bar")
@export var health_bar_height: float = 2.08
@export_group("Rifle visual")
@export var pistol_mesh_path: String = "res://gltf/Pistol_5.obj"
@export var pistol_grip_target_length: float = 0.12
@export var pistol_hand_bone_hints: PackedStringArray = PackedStringArray(["hand_r", "mixamorig:RightHand", "mixamorig_RightHand", "RightHand", "Hand.R", "J_Bip_R_Hand", "DEF-hand.R", "hand.R"])

@export_group("Navigation Tuning")
@export var nav_avoidance_enabled: bool = true
@export var nav_radius: float = 0.65
@export var separation_radius: float = 2.2
@export var separation_weight: float = 1.65
@export var destination_slowdown_distance: float = 1.1
@export_group("Stuck Recovery")
@export var stuck_distance_threshold: float = 0.06
@export var stuck_timeout: float = 0.75
@export var stuck_repath_offset: float = 1.1
@export var max_stuck_recoveries: int = 6

@onready var nav_agent: NavigationAgent3D = $NavAgent
@onready var health_bar: Node3D = $HealthBar
@onready var health_fill: MeshInstance3D = $HealthBar/BarFill
@onready var hit_flash: MeshInstance3D = $HitFlash
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio
@onready var unit_graphics: Node3D = $unit_graphics

enum UnitState {
	IDLE,
	MOVE,
	ATTACK,
	GUARD,
	BUILD,
	HARVEST,
	GARRISON
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

var xp_thresholds: PackedInt32Array = PackedInt32Array([0, 50, 150, 300])
var fire_rate_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.15, 1.3, 1.5])
var damage_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.1, 1.2, 1.35])
var self_heal: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.5, 1.0])

var max_health: int = 100
var current_health: int = 100
var move_speed: float = 5.0
var armor_data: ArmorData
var weapon_data: WeaponData
var attack_range: float = 0.0
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0
var attack_target: Node3D
var xp: int = 0
var rank: int = 0
var fire_rate_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var self_heal_rate: float = 0.0
var state: UnitState = UnitState.IDLE
var command_queue: Array = []
var current_command: Dictionary = {}
var current_target: Vector3 = Vector3.ZERO
var has_target: bool = false
var arrive_distance: float = 0.2
var use_nav_agent: bool = false
var bar_fill_half_width: float = 0.475
var hit_flash_duration: float = 0.08
var hit_sound_duration: float = 0.06
var hit_sound_frequency: float = 880.0
var guard_target: Node3D
var guard_follow_distance: float = 2.0
var hold_position: bool = false
var attack_move_active: bool = false
var progress_anchor: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var stuck_recovery_count: int = 0
var total_stuck_recoveries: int = 0
var animation_player: AnimationPlayer
var idle_animation: String = ""
var friendly_idle_animation: String = ""
var selected_animation: String = ""
var move_animation: String = ""
var guard_animation: String = ""
var attack_animation: String = ""
var death_animation: String = ""
var current_animation: String = ""
var fire_range_ring: MeshInstance3D
var vision_range_ring: MeshInstance3D
var last_action_debug: String = ""
var is_selected: bool = false
var is_dead: bool = false
# Weapon root: Node3D prop holder, or BoneAttachment3D when rifle pistol is rigged to the skeleton.
var weapon_prop: Node3D

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	up_direction = Vector3.UP
	add_to_group("units")
	setup_selection_visual()
	apply_unit_data()
	deselect()
	setup_navigation()
	setup_animation()
	setup_weapon_prop()
	setup_range_rings()
	setup_hit_audio()
	# Health bar is a child of unit root (not the skinned mesh) so it does not bob with clips; Y-billboard materials face the camera.
	if health_bar != null:
		health_bar.position = Vector3(0, health_bar_height, 0)
	update_health_bar()
	_update_rank()
	_reset_movement_progress()
	_start_next_command()


func apply_unit_data() -> void:
	if unit_data == null:
		return
	max_health = unit_data.max_health
	current_health = max_health
	move_speed = unit_data.move_speed
	if DataRegistry and unit_data.armor_id != "":
		armor_data = DataRegistry.get_armor(unit_data.armor_id)
	if DataRegistry and unit_data.weapon_id != "":
		weapon_data = DataRegistry.get_weapon(unit_data.weapon_id)
	if weapon_data != null:
		attack_range = weapon_data.range
		attack_cooldown = weapon_data.cooldown
	_apply_visual_tint()
	update_health_bar()


func _apply_visual_tint() -> void:
	if unit_data == null or unit_graphics == null:
		return
	for child in unit_graphics.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		for surface_index in range(mesh_instance.get_surface_override_material_count()):
			var material := mesh_instance.get_active_material(surface_index)
			if material is StandardMaterial3D:
				var copy := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
				copy.albedo_color *= unit_data.visual_tint
				mesh_instance.set_surface_override_material(surface_index, copy)
	print("[UnitVisual] %s tint=%s" % [unit_data.id, str(unit_data.visual_tint)])


func setup_navigation() -> void:
	if nav_agent == null:
		use_nav_agent = false
		return
	use_nav_agent = true
	nav_agent.avoidance_enabled = nav_avoidance_enabled
	nav_agent.path_desired_distance = arrive_distance
	nav_agent.target_desired_distance = arrive_distance
	nav_agent.radius = max(nav_radius, personal_space_radius)
	nav_agent.max_speed = move_speed


func setup_hit_audio() -> void:
	if hit_audio == null:
		return
	if hit_audio.stream == null:
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = 44100
		generator.buffer_length = 0.1
		hit_audio.stream = generator
	hit_audio.volume_db = -12.0


func setup_animation() -> void:
	animation_player = _find_animation_player(self)
	if animation_player == null:
		print("[UnitAnimation] no AnimationPlayer found for %s; imported scene may have no clips or animations disabled" % name)
		return
	idle_animation = _find_animation_name(idle_animation_name)
	friendly_idle_animation = _find_animation_name(friendly_idle_animation_name)
	selected_animation = _find_animation_name(selected_animation_name)
	move_animation = _find_animation_name(move_animation_name)
	guard_animation = _find_animation_name(guard_animation_name)
	attack_animation = _find_animation_name(attack_animation_name)
	death_animation = _find_animation_name(death_animation_name)
	if idle_animation == "" and animation_player.get_animation_list().size() > 0:
		idle_animation = animation_player.get_animation_list()[0]
	print("[UnitAnimation] %s idle=%s friendly=%s selected=%s move=%s guard=%s attack=%s death=%s" % [name, idle_animation, friendly_idle_animation, selected_animation, move_animation, guard_animation, attack_animation, death_animation])
	_play_animation(idle_animation)


func setup_range_rings() -> void:
	vision_range_ring = _create_range_ring("VisionRange", unit_data.sight_range if unit_data != null else 0.0, Color(1.0, 0.85, 0.25, 0.45))
	fire_range_ring = _create_range_ring("FireRange", attack_range, Color(0.25, 0.65, 1.0, 0.6))
	_set_range_rings_visible(false)


# Weapon visuals: rocket keeps placeholder boxes; rifle loads Pistol_5.obj and attaches to hand_r when a Skeleton3D exists.
func setup_weapon_prop() -> void:
	if weapon_data == null or unit_graphics == null:
		return
	if weapon_prop != null and is_instance_valid(weapon_prop):
		weapon_prop.queue_free()
		weapon_prop = null
	if weapon_data.id == "rocket_launcher":
		weapon_prop = Node3D.new()
		weapon_prop.name = "WeaponProp"
		unit_graphics.add_child(weapon_prop)
		_add_box_weapon_part(Vector3(0.08, 0.08, 0.75), Vector3(0.34, 1.05, -0.14), Color(0.2, 0.2, 0.2, 1.0))
		_add_box_weapon_part(Vector3(0.18, 0.18, 0.18), Vector3(0.34, 1.05, 0.26), Color(0.35, 0.35, 0.35, 1.0))
	elif weapon_data.id == "rifle":
		_setup_rifle_pistol_visual()
	else:
		weapon_prop = Node3D.new()
		weapon_prop.name = "WeaponProp"
		unit_graphics.add_child(weapon_prop)
		_add_box_weapon_part(Vector3(0.05, 0.05, 0.55), Vector3(0.32, 0.98, -0.1), Color(0.08, 0.08, 0.08, 1.0))
		_add_box_weapon_part(Vector3(0.12, 0.06, 0.18), Vector3(0.32, 0.95, 0.1), Color(0.18, 0.18, 0.18, 1.0))
	print("[UnitVisual] %s weapon prop=%s" % [get_selection_key(), weapon_data.id])


# Prefer BoneAttachment3D on the rig; otherwise parent mesh under WeaponProp with a fixed socket offset.
func _setup_rifle_pistol_visual() -> void:
	var loaded: Resource = load(pistol_mesh_path) as Resource
	if loaded == null or not (loaded is ArrayMesh):
		push_warning("[UnitVisual] could not load rifle mesh: %s" % pistol_mesh_path)
		_fallback_box_rifle()
		return
	var mesh := loaded as ArrayMesh
	var mi := MeshInstance3D.new()
	mi.name = "PistolMesh"
	mi.mesh = mesh
	_apply_dark_metal_materials(mi)
	var skel := _find_skeleton(unit_graphics)
	var bone_name := ""
	if skel != null:
		bone_name = _resolve_hand_bone_name(skel)
	if skel != null and bone_name != "":
		var bat := BoneAttachment3D.new()
		bat.name = "WeaponGrip"
		bat.bone_name = bone_name
		skel.add_child(bat)
		mi.transform = _compose_pistol_mesh_local_transform(mesh, pistol_grip_target_length, _pistol_bone_local_transform())
		bat.add_child(mi)
		weapon_prop = bat
		return
	weapon_prop = Node3D.new()
	weapon_prop.name = "WeaponProp"
	unit_graphics.add_child(weapon_prop)
	var socket := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-90), PI, 0)), Vector3(0.32, 0.98, -0.1))
	mi.transform = _compose_pistol_mesh_local_transform(mesh, pistol_grip_target_length, socket)
	weapon_prop.add_child(mi)


func _fallback_box_rifle() -> void:
	weapon_prop = Node3D.new()
	weapon_prop.name = "WeaponProp"
	unit_graphics.add_child(weapon_prop)
	_add_box_weapon_part(Vector3(0.05, 0.05, 0.55), Vector3(0.32, 0.98, -0.1), Color(0.08, 0.08, 0.08, 1.0))
	_add_box_weapon_part(Vector3(0.12, 0.06, 0.18), Vector3(0.32, 0.95, 0.1), Color(0.18, 0.18, 0.18, 1.0))


func _pistol_bone_local_transform() -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(-95.0), deg_to_rad(185.0), deg_to_rad(-8.0)))
	return Transform3D(b, Vector3(0.0, 0.02, 0.01))


# Uniform scale to fit target_length on longest mesh axis, centered on AABB; multiplied with grip/socket (never assign .transform after .scale — that clears scale).
func _compose_pistol_mesh_local_transform(mesh: ArrayMesh, target_length: float, grip_basis: Transform3D) -> Transform3D:
	var abb: AABB = mesh.get_aabb()
	var longest: float = maxf(abb.size.x, maxf(abb.size.y, abb.size.z))
	var s: float = 1.0
	if longest > 0.0001:
		s = target_length / longest
	var center := Transform3D(Basis.from_scale(Vector3(s, s, s)), -abb.get_center() * s)
	return grip_basis * center


func _apply_dark_metal_materials(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.metallic = 0.65
	mat.roughness = 0.45
	mat.albedo_color = Color(0.12, 0.12, 0.14, 1.0)
	for si in range(mi.mesh.get_surface_count()):
		mi.set_surface_override_material(si, mat)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var sk: Skeleton3D = _find_skeleton(child)
		if sk != null:
			return sk
	return null


func _resolve_hand_bone_name(skel: Skeleton3D) -> String:
	for h in pistol_hand_bone_hints:
		if skel.find_bone(StringName(h)) >= 0:
			return h
	for bi in range(skel.get_bone_count()):
		var nm := String(skel.get_bone_name(bi))
		var lower := nm.to_lower()
		if "hand" in lower and ("right" in lower or lower.ends_with(".r") or "_r_" in lower or lower.contains("handr")):
			return nm
	return ""


func issue_move(target: Vector3, queued: bool) -> void:
	issue_command({
		"type": CommandType.MOVE,
		"position": target,
		"target": null
	}, queued)

func issue_command(command: Dictionary, queued: bool) -> void:
	var cmd_type := int(command.get("type", CommandType.MOVE))
	if cmd_type == CommandType.STOP:
		_print_action("stop")
		clear_commands()
		hold_position = false
		return
	if cmd_type == CommandType.HOLD:
		_print_action("hold position")
		clear_commands()
		hold_position = true
		return
	if cmd_type == CommandType.HARVEST:
		return
	hold_position = false
	if not queued:
		command_queue.clear()
	command_queue.append(command)
	_print_action("queued command type=%d queued=%s" % [cmd_type, str(queued)])
	if state == UnitState.IDLE or not has_target:
		_start_next_command()


func clear_commands() -> void:
	command_queue.clear()
	current_command = {}
	has_target = false
	state = UnitState.IDLE
	attack_target = null
	guard_target = null
	attack_move_active = false
	_reset_movement_progress()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	attack_timer = max(attack_timer - delta, 0.0)
	if self_heal_rate > 0.0 and current_health < max_health:
		current_health = min(current_health + self_heal_rate * delta, max_health)
		update_health_bar()
	if state == UnitState.MOVE and has_target:
		_process_move(delta)
	elif state == UnitState.GUARD:
		_process_guard(delta)
	else:
		_process_attack(delta)
	_update_animation()


func _process_move(delta: float) -> void:
	if attack_move_active:
		var target_unit := _find_target()
		if target_unit != null:
			attack_target = target_unit
			state = UnitState.ATTACK
			_print_action("attack-move acquired %s" % attack_target.name)
			return
	if _move_towards_position(current_target, delta):
		_start_next_command()

func _process_guard(delta: float) -> void:
	if guard_target == null or not is_instance_valid(guard_target):
		guard_target = null
		_start_next_command()
		return
	var target_unit := _find_target()
	if target_unit != null:
		attack_target = target_unit
		state = UnitState.ATTACK
		_print_action("guard acquired %s" % attack_target.name)
		return
	var guard_position := guard_target.global_position
	if global_position.distance_to(guard_position) > guard_follow_distance:
		_move_towards_position(guard_position, delta)
	else:
		state = UnitState.GUARD

func _move_towards_position(target: Vector3, delta: float) -> bool:
	var current_position := global_position
	var target_pos := target
	target_pos.y = current_position.y
	if use_nav_agent:
		nav_agent.target_position = target_pos
	var next_position := target_pos
	if use_nav_agent:
		var path: PackedVector3Array = nav_agent.get_current_navigation_path()
		if path.size() > 0 and not nav_agent.is_navigation_finished():
			next_position = nav_agent.get_next_path_position()
			next_position.y = current_position.y
	var travel_vector := next_position - current_position
	var distance := travel_vector.length()
	if distance <= arrive_distance:
		var motion_snap1: Vector3 = next_position - current_position
		motion_snap1.y = 0.0
		_push_kinematic_translation(motion_snap1)
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
		var motion_snap2: Vector3 = next_position - current_position
		motion_snap2.y = 0.0
		_push_kinematic_translation(motion_snap2)
		var final_distance2: float = global_position.distance_to(target_pos)
		if final_distance2 <= arrive_distance:
			_update_stuck_recovery(target_pos, delta)
			return true
		if use_nav_agent and not nav_agent.is_navigation_finished():
			_update_stuck_recovery(target_pos, delta)
			return false
		_update_stuck_recovery(target_pos, delta)
		return false
	var motion_step: Vector3 = movement_dir * step
	motion_step.y = 0.0
	_push_kinematic_translation(motion_step)
	if movement_dir.length_squared() > 0.001:
		var lb: Vector3 = Vector3(movement_dir.x, 0.0, movement_dir.z)
		if lb.length_squared() > 1e-6:
			look_at(global_position + lb, Vector3.UP)
	_update_stuck_recovery(target_pos, delta)
	return false


func _push_kinematic_translation(offset: Vector3) -> void:
	offset.y = 0.0
	if offset.length_squared() < 1e-10:
		return
	var hit: KinematicCollision3D = move_and_collide(offset, false, 0.08, true, 4)
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


func _process_attack(delta: float) -> void:
	if weapon_data == null:
		state = UnitState.IDLE
		return
	var cmd_type := int(current_command.get("type", CommandType.MOVE))
	if attack_target == null or not is_instance_valid(attack_target) or not _is_enemy(attack_target):
		if attack_move_active and has_target:
			state = UnitState.MOVE
			return
		if cmd_type == CommandType.ATTACK and current_command.size() > 0:
			_start_next_command()
			return
		attack_target = _find_target()
		if attack_target == null:
			state = UnitState.IDLE
			_print_action("idle no target")
			return
		_print_action("target acquired %s" % attack_target.name)
	var distance := global_position.distance_to(attack_target.global_position)
	if distance > attack_range:
		if cmd_type == CommandType.ATTACK:
			_move_towards_position(attack_target.global_position, delta)
			return
		if attack_move_active and has_target:
			state = UnitState.MOVE
			return
		attack_target = null
		state = UnitState.IDLE
		return
	state = UnitState.ATTACK
	if attack_timer <= 0.0:
		_print_action("fire at %s" % attack_target.name)
		_fire_weapon(attack_target)
		attack_timer = attack_cooldown / fire_rate_multiplier


func _start_next_command() -> void:
	if command_queue.is_empty():
		has_target = false
		state = UnitState.IDLE
		current_command = {}
		attack_move_active = false
		guard_target = null
		attack_target = null
		_reset_movement_progress()
		return
	current_command = command_queue.pop_front()
	attack_move_active = false
	guard_target = null
	attack_target = null
	var cmd_type := int(current_command.get("type", CommandType.MOVE))
	match cmd_type:
		CommandType.MOVE:
			_set_move_target(current_command.get("position", global_position))
			state = UnitState.MOVE
			_print_action("move to (%.1f, %.1f)" % [current_target.x, current_target.z])
		CommandType.ATTACK_MOVE:
			_set_move_target(current_command.get("position", global_position))
			attack_move_active = true
			state = UnitState.MOVE
			_print_action("attack-move to (%.1f, %.1f)" % [current_target.x, current_target.z])
		CommandType.ATTACK:
			var target: Node3D = current_command.get("target", null) as Node3D
			if target == null or not is_instance_valid(target):
				_start_next_command()
				return
			attack_target = target
			state = UnitState.ATTACK
			_print_action("attack target %s" % attack_target.name)
		CommandType.GUARD:
			var guard: Node3D = current_command.get("target", null) as Node3D
			if guard == null or not is_instance_valid(guard):
				_start_next_command()
				return
			guard_target = guard
			state = UnitState.GUARD
			_print_action("guard target %s" % guard_target.name)
		_:
			state = UnitState.IDLE
	_reset_movement_progress()

func _set_move_target(target: Vector3) -> void:
	current_target = target
	has_target = true
	if use_nav_agent:
		nav_agent.target_position = current_target
	_reset_movement_progress()


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
		var delta: Vector3 = origin - unit.global_position
		delta.y = 0.0
		var dist: float = delta.length()
		var effective_radius: float = max(separation_radius, personal_space_radius * 2.0)
		if dist <= 0.001 or dist > effective_radius:
			continue
		var push: Vector3 = delta.normalized() * ((effective_radius - dist) / effective_radius)
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
		"moving": state == UnitState.MOVE
	}


func _find_target() -> Node3D:
	if weapon_data == null:
		return null
	var sight := unit_data.sight_range if unit_data != null else attack_range
	var best_target: Node3D = null
	var best_score := -INF
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit == self:
			continue
		if not _is_enemy(unit):
			continue
		if unit is Node3D and not (unit as Node3D).visible:
			continue
		if unit is Node3D:
			var dist: float = global_position.distance_to(unit.global_position)
			if dist > sight:
				continue
			var score: float = _get_target_priority(unit, dist, sight)
			if score > best_score:
				best_score = score
				best_target = unit
	return best_target


func _get_target_priority(unit: Node, distance: float, sight: float) -> float:
	var score := 0.0
	if unit.has_method("can_attack") and unit.can_attack():
		score += 60.0
	if unit.has_method("can_construct") and unit.can_construct():
		score += 25.0
	if unit.has_method("get_health_ratio"):
		score += (1.0 - float(unit.get_health_ratio())) * 20.0
	score += (1.0 - clamp(distance / max(sight, 0.01), 0.0, 1.0)) * 15.0
	return score


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
	projectile.setup(weapon_data, origin, target_pos, target_unit, team_id, self)
	projectile.damage = int(round(float(projectile.damage) * damage_multiplier))



func apply_damage(amount: int, _source: Node, damage_type: String = "small_arms") -> void:
	var was_alive := current_health > 0
	var final_amount := _calculate_modified_damage(amount, damage_type)
	current_health = max(current_health - final_amount, 0)
	print("[Combat] %s took %d %s damage" % [name, final_amount, damage_type])
	update_health_bar()
	flash_hit()
	play_hit_sound()
	if current_health <= 0:
		if was_alive:
			_award_kill_xp(_source)
		die()


func _calculate_modified_damage(amount: int, damage_type: String) -> int:
	var modifier := 1.0
	if armor_data != null and armor_data.damage_modifiers.has(damage_type):
		modifier = float(armor_data.damage_modifiers.get(damage_type, 1.0))
	return max(int(round(float(amount) * modifier)), 0)


func get_health_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return clamp(float(current_health) / float(max_health), 0.0, 1.0)


func gain_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	_update_rank()


func _update_rank() -> void:
	var new_rank := rank
	for i in range(xp_thresholds.size()):
		if xp >= xp_thresholds[i]:
			new_rank = i
	if new_rank != rank:
		rank = new_rank
		fire_rate_multiplier = fire_rate_mult[rank]
		damage_multiplier = damage_mult[rank]
		self_heal_rate = self_heal[rank]


func _award_kill_xp(source: Node) -> void:
	if source == null:
		return
	if source.has_method("gain_xp"):
		source.gain_xp(xp_value)
	if GameManager and typeof(source.get("team_id")) == TYPE_INT and source.get("team_id") == 1:
		GameManager.add_promotion_points(1)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	_set_range_rings_visible(false)
	$selected.visible = false
	_play_animation(death_animation if death_animation != "" else idle_animation)
	print("[UnitAction] %s: death" % get_selection_key())
	var delay := 1.5
	if animation_player != null and death_animation != "":
		delay = animation_player.get_animation(death_animation).length
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)


# Hold (H): use guard-style idle, no friendly chatter. GUARD state is handled in the match arm above.
func _suppress_friendly_idle_talk() -> bool:
	return hold_position


# MOVE/GUARD/ATTACK are explicit; default branch prioritizes hold over selected over social idle over plain idle.
func _update_animation() -> void:
	if animation_player == null:
		return
	if is_dead:
		return
	match state:
		UnitState.MOVE:
			_play_animation(move_animation if move_animation != "" else idle_animation)
		UnitState.GUARD:
			_play_animation(guard_animation if guard_animation != "" else idle_animation)
		UnitState.ATTACK:
			_play_animation(attack_animation if attack_animation != "" else idle_animation)
		_:
			if _suppress_friendly_idle_talk():
				_play_animation(guard_animation if guard_animation != "" else idle_animation)
			elif is_selected and selected_animation != "":
				_play_animation(selected_animation)
			elif _has_nearby_friendly_infantry() and friendly_idle_animation != "":
				_play_animation(friendly_idle_animation)
			else:
				_play_animation(idle_animation)


func _play_animation(animation_name: String) -> void:
	if animation_player == null or animation_name == "":
		return
	if current_animation == animation_name and animation_player.is_playing():
		return
	current_animation = animation_name
	animation_player.play(animation_name)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_animation_name(hint: String) -> String:
	if animation_player == null:
		return ""
	var lower_hint := hint.to_lower()
	for animation_name in animation_player.get_animation_list():
		var candidate := String(animation_name)
		if candidate == hint:
			return candidate
		if candidate.to_lower().find(lower_hint) != -1:
			return animation_name
	return ""


# Social idle only if a nearby friendly is not in GUARD/hold (so guards do not pull others into talking anims).
func _has_nearby_friendly_infantry() -> bool:
	for unit in get_tree().get_nodes_in_group("units"):
		if unit == self or not is_instance_valid(unit):
			continue
		if not unit is Node3D:
			continue
		if _is_enemy(unit):
			continue
		if _is_unit_in_guard_or_hold(unit):
			continue
		if global_position.distance_to(unit.global_position) <= friendly_idle_radius:
			return true
	return false


func _is_unit_in_guard_or_hold(unit: Node) -> bool:
	var st: Variant = unit.get("state")
	if typeof(st) == TYPE_INT and int(st) == UnitState.GUARD:
		return true
	var hp: Variant = unit.get("hold_position")
	if typeof(hp) == TYPE_BOOL and bool(hp):
		return true
	return false


func _create_range_ring(ring_name: String, radius: float, color: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = ring_name
	ring.mesh = _build_ring_mesh(max(radius, 0.1))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	ring.material_override = material
	ring.position.y = 0.035
	add_child(ring)
	return ring


func _build_ring_mesh(radius: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments: int = max(range_ring_segments, 16)
	for i in range(segments + 1):
		var angle := (float(i) / float(segments)) * TAU
		mesh.surface_add_vertex(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	mesh.surface_end()
	return mesh


func _set_range_rings_visible(is_visible: bool) -> void:
	if fire_range_ring != null:
		fire_range_ring.visible = is_visible
	if vision_range_ring != null:
		vision_range_ring.visible = is_visible


func get_vision_range() -> float:
	if unit_data != null:
		return unit_data.sight_range
	return attack_range


func _add_box_weapon_part(size: Vector3, local_position: Vector3, color: Color) -> void:
	if weapon_prop == null:
		return
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	weapon_prop.add_child(mesh_instance)


func _print_action(message: String) -> void:
	if message == last_action_debug:
		return
	last_action_debug = message
	var label := get_selection_key()
	print("[UnitAction] %s: %s" % [label, message])


func update_health_bar() -> void:
	if health_fill == null:
		return
	var ratio := 0.0
	if max_health > 0:
		ratio = float(current_health) / float(max_health)
	ratio = clamp(ratio, 0.0, 1.0)
	# Shrink fill from the left anchor using bar_fill_half_width (must match QuadMesh width / 2).
	health_fill.scale.x = ratio
	health_fill.position.x = -bar_fill_half_width * (1.0 - ratio)
	if health_bar != null:
		health_bar.visible = true


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
	is_selected = true
	$selected.visible = true
	_set_range_rings_visible(true)

func deselect() -> void:
	is_selected = false
	$selected.visible = false
	_set_range_rings_visible(false)

func get_selection_key() -> String:
	if unit_data != null and unit_data.id != "":
		return unit_data.id
	return "unit"


func can_attack() -> bool:
	return weapon_data != null
