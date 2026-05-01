extends Node3D

var speed: float = 30.0
var damage: int = 5
var damage_type: String = "small_arms"
var splash_radius: float = 0.0
var accuracy: float = 1.0
var target_position: Vector3 = Vector3.ZERO
var target_unit: Node3D
var source_team: int = 0
var source_unit: Node3D
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 0.0
var max_lifetime: float = 5.0

func setup(weapon: WeaponData, origin: Vector3, target: Vector3, target_node: Node3D, team_id: int, source: Node3D) -> void:
	global_position = origin
	target_position = target
	target_unit = target_node
	source_team = team_id
	source_unit = source
	if weapon != null:
		speed = weapon.projectile_speed
		damage = weapon.damage
		damage_type = weapon.damage_type
		splash_radius = weapon.splash_radius
		accuracy = weapon.accuracy
	direction = (target_position - origin)
	if direction.length_squared() > 0.001:
		direction = direction.normalized()

func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return
	var step := speed * delta
	var to_target := target_position - global_position
	if to_target.length() <= step:
		global_position = target_position
		impact()
		return
	global_position += direction * step

func impact() -> void:
	var hit := randf() <= accuracy
	if hit and is_instance_valid(target_unit):
		_apply_damage(target_unit, damage)
	if splash_radius > 0.0:
		_apply_splash_damage()
	queue_free()

func _apply_damage(unit: Node3D, amount: int) -> void:
	if unit == null:
		return
	if unit.has_method("apply_damage"):
		unit.apply_damage(amount, source_unit, damage_type)

func _apply_splash_damage() -> void:
	var units := get_tree().get_nodes_in_group("units")
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if unit == target_unit:
			continue
		if unit is Node3D:
			var dist := global_position.distance_to(unit.global_position)
			if dist <= splash_radius:
				_apply_damage(unit, damage)
