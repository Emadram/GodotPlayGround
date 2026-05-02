extends Node3D

@export var building_id: String = ""
@export var team_id: int = 1
@export var build_time_override: float = 0.0
@export var unit_spawn_scene: PackedScene = preload("res://scene/testunit.tscn")
@export var rally_offset: Vector3 = Vector3(3.0, 0.0, 0.0)
@export var max_production_queue: int = 10
@export var visual_fit_margin: float = 0.9

@onready var occupancy_shape: CollisionShape3D = $OccupancyBody/CollisionShape3D
@onready var click_shape: CollisionShape3D = $ClickArea/CollisionShape3D
@onready var cancel_shape: CollisionShape3D = $CancelArea/CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var visual_root: Node3D = $VisualRoot
@onready var selection_sprite: Sprite3D = $selected
@onready var progress_label: Label3D = $ProgressLabel
@onready var cancel_label: Label3D = $CancelLabel

var building_data: BuildingData
var construction_progress: float = 0.0
var is_ghost: bool = false
var is_completed: bool = false
var ghost_valid: bool = true
var power_consumed_applied: bool = false
var power_provided_applied: bool = false
var production_queue: Array[String] = []
var production_timer: float = 0.0
var active_unit_id: String = ""
var building_visual: Node3D

func _process(delta: float) -> void:
	_update_construction_labels()
	if is_ghost or not is_completed:
		return
	_process_production(delta)

func _ready() -> void:
	add_to_group("buildings")
	if selection_sprite != null:
		selection_sprite.visible = false
	if building_id != "":
		var data: BuildingData = DataRegistry.get_building(building_id) if DataRegistry else null
		if data != null:
			configure(building_id, team_id, data, false)
	_update_visual()


func configure(new_building_id: String, new_team_id: int, data: BuildingData, ghost_mode: bool) -> void:
	building_id = new_building_id
	team_id = new_team_id
	building_data = data
	is_ghost = ghost_mode
	is_completed = false
	construction_progress = 0.0
	power_consumed_applied = false
	power_provided_applied = false
	_apply_footprint()
	_apply_building_visual()
	if occupancy_shape != null:
		occupancy_shape.disabled = is_ghost
	if click_shape != null:
		click_shape.disabled = is_ghost
	if cancel_shape != null:
		cancel_shape.disabled = is_ghost or is_completed
	if not is_ghost:
		_apply_start_power_impact()
	_update_visual()


func set_ghost_valid(is_valid: bool) -> void:
	ghost_valid = is_valid
	_update_visual()


func get_footprint() -> Vector2:
	if building_data != null:
		return building_data.footprint
	return Vector2.ONE


# Ghost previews never grant vision; matches GameManager and terrain FoW shader inputs.
func get_vision_range() -> float:
	if is_ghost:
		return 0.0
	if building_data != null:
		return building_data.sight_range
	return 12.0


func get_build_progress_ratio() -> float:
	var total_time := _get_total_build_time()
	if total_time <= 0.001:
		return 1.0
	return clamp(construction_progress / total_time, 0.0, 1.0)


func advance_construction(amount: float) -> bool:
	if is_ghost:
		return false
	if is_completed:
		return true
	if amount <= 0.0:
		return false
	construction_progress += amount
	if get_build_progress_ratio() >= 1.0:
		is_completed = true
		_apply_complete_power_impact()
		if AbilityProgression != null and building_id != "":
			AbilityProgression.notify_structure_completed(building_id)
	_update_visual()
	return is_completed


func is_under_construction() -> bool:
	return not is_ghost and not is_completed


func cancel_construction() -> bool:
	if not is_under_construction():
		return false
	var refund := 0
	if building_data != null:
		refund = int(round(float(building_data.cost) * 0.75))
	if GameManager != null and refund > 0:
		GameManager.add_resources(refund)
	print("[Construction] cancelled %s refund=%d" % [get_selection_key(), refund])
	queue_free()
	return true


func queue_unit(unit_id: String) -> bool:
	if not is_completed:
		print("[Production] queue failed: %s is not completed" % get_selection_key())
		return false
	if building_data == null:
		print("[Production] queue failed: missing BuildingData")
		return false
	if not building_data.produces_units.has(unit_id):
		print("[Production] queue failed: %s cannot produce %s" % [get_selection_key(), unit_id])
		return false
	if get_production_queue_items().size() >= max_production_queue:
		print("[Production] queue failed: %s queue is full (%d)" % [get_selection_key(), max_production_queue])
		return false
	var unit_data: UnitData = DataRegistry.get_unit(unit_id) if DataRegistry else null
	if unit_data == null:
		print("[Production] queue failed: missing UnitData for %s" % unit_id)
		return false
	if GameManager != null and GameManager.is_power_low():
		print("[Production] queue failed: low power (need more power plants)")
		return false
	var cp_need: int = maxi(0, unit_data.command_point_cost)
	if AbilityProgression != null and cp_need > 0 and AbilityProgression.command_points < cp_need:
		print("[Production] queue failed: need %d CP for %s" % [cp_need, _get_unit_label(unit_id)])
		return false
	if GameManager != null and not GameManager.spend_resources(unit_data.cost):
		print("[Production] queue failed: not enough resources for %s" % _get_unit_label(unit_id))
		return false
	if AbilityProgression != null and cp_need > 0:
		if not AbilityProgression.try_spend_command_points(cp_need):
			if GameManager != null:
				GameManager.add_resources(unit_data.cost)
			print("[Production] queue failed: CP spend for %s" % _get_unit_label(unit_id))
			return false
	production_queue.append(unit_id)
	if active_unit_id == "":
		_start_next_production()
	print("[Production] queued %s (%d/%d)" % [_get_unit_label(unit_id), get_production_queue_items().size(), max_production_queue])
	return true


func queue_default_unit() -> bool:
	if building_data == null or building_data.produces_units.is_empty():
		return false
	return queue_unit(building_data.produces_units[0])


func selected() -> void:
	if selection_sprite != null:
		selection_sprite.visible = true
	print("[Selection] selected building %s" % get_selection_key())


func deselect() -> void:
	if selection_sprite != null:
		selection_sprite.visible = false


func get_selection_key() -> String:
	return building_id if building_id != "" else "building"


func get_building_display_label() -> String:
	if building_data != null and building_data.display_name != "":
		return building_data.display_name
	return get_selection_key()


func get_producible_units() -> Array[String]:
	if building_data == null:
		return []
	return building_data.produces_units


func get_default_production_unit_id() -> String:
	if building_data == null or building_data.produces_units.is_empty():
		return ""
	return building_data.produces_units[0]


func get_default_production_label() -> String:
	var unit_id := get_default_production_unit_id()
	if unit_id == "":
		return ""
	return _get_unit_label(unit_id)


func get_production_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if building_data == null:
		return options
	for unit_id in building_data.produces_units:
		var udata: UnitData = DataRegistry.get_unit(unit_id) if DataRegistry else null
		var cp: int = udata.command_point_cost if udata != null else 0
		options.append({
			"unit_id": unit_id,
			"label": _get_unit_label(unit_id),
			"cp_cost": cp,
		})
	return options


func get_production_queue_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var power_low := GameManager != null and GameManager.is_power_low()
	if active_unit_id != "":
		var ucp := _unit_command_point_cost(active_unit_id)
		items.append({
			"unit_id": active_unit_id,
			"label": _get_unit_label(active_unit_id),
			"active": true,
			"timer": production_timer,
			"cp_cost": ucp,
			"paused_by_power": power_low,
		})
	for unit_id in production_queue:
		var qcp := _unit_command_point_cost(unit_id)
		items.append({
			"unit_id": unit_id,
			"label": _get_unit_label(unit_id),
			"active": false,
			"timer": 0.0,
			"cp_cost": qcp,
			"paused_by_power": false,
		})
	return items


func get_max_production_queue() -> int:
	return max_production_queue


func cancel_production_at(index: int) -> bool:
	var items := get_production_queue_items()
	if index < 0 or index >= items.size():
		return false
	var unit_id := str(items[index].get("unit_id", ""))
	if unit_id == "":
		return false
	var unit_data: UnitData = DataRegistry.get_unit(unit_id) if DataRegistry else null
	if bool(items[index].get("active", false)):
		active_unit_id = ""
		production_timer = 0.0
		_start_next_production()
	else:
		var queue_index := index
		if active_unit_id != "":
			queue_index -= 1
		if queue_index < 0 or queue_index >= production_queue.size():
			return false
		production_queue.remove_at(queue_index)
	if GameManager != null and unit_data != null:
		GameManager.add_resources(unit_data.cost)
	var cp_refund: int = 0
	if unit_data != null:
		cp_refund = maxi(0, unit_data.command_point_cost)
	if AbilityProgression != null and cp_refund > 0:
		AbilityProgression.add_command_points(cp_refund)
	print("[Production] cancelled %s" % _get_unit_label(unit_id))
	return true


func get_production_debug_state() -> Dictionary:
	return {
		"active": active_unit_id,
		"queue_size": production_queue.size(),
		"timer": production_timer,
		"completed": is_completed,
		"paused_by_power": GameManager != null and GameManager.is_power_low() and active_unit_id != ""
	}


func get_inspect_summary() -> Dictionary:
	var hp_max := building_data.max_health if building_data != null else 0
	return {
		"building_id": building_id,
		"display_name": get_building_display_label(),
		"max_integrity": hp_max,
		"power_consumed": building_data.power_consumed if building_data != null else 0,
		"power_provided": building_data.power_provided if building_data != null else 0,
		"completed": is_completed,
		"ghost": is_ghost,
		"build_progress": get_build_progress_ratio(),
	}


func _apply_footprint() -> void:
	var footprint := get_footprint()
	footprint.x = max(footprint.x, 1.0)
	footprint.y = max(footprint.y, 1.0)
	if mesh_instance != null:
		mesh_instance.scale = Vector3(footprint.x, 1.0, footprint.y)
	if occupancy_shape != null and occupancy_shape.shape is BoxShape3D:
		var shape := occupancy_shape.shape as BoxShape3D
		shape.size = Vector3(footprint.x, 1.0, footprint.y)
	if click_shape != null and click_shape.shape is BoxShape3D:
		var click_box := click_shape.shape as BoxShape3D
		click_box.size = Vector3(footprint.x, 1.2, footprint.y)
	if cancel_shape != null and cancel_shape.shape is BoxShape3D:
		var cancel_box := cancel_shape.shape as BoxShape3D
		cancel_box.size = Vector3(max(footprint.x * 0.7, 1.0), 0.35, max(footprint.y * 0.35, 0.6))
	_set_selection_indicator_size(Vector2(footprint.x, footprint.y))


func _apply_building_visual() -> void:
	if building_visual != null and is_instance_valid(building_visual):
		building_visual.queue_free()
		building_visual = null
	if building_data == null or building_data.building_scene == null or visual_root == null:
		if mesh_instance != null:
			mesh_instance.visible = true
		return
	var instance := building_data.building_scene.instantiate()
	if instance is Node3D:
		building_visual = instance as Node3D
		visual_root.add_child(building_visual)
		_fit_visual_to_footprint()


func _should_show_footprint_indicator() -> bool:
	return is_ghost or not is_completed


func _fit_visual_to_footprint() -> void:
	if building_visual == null:
		return
	await get_tree().process_frame
	if building_visual == null or not is_instance_valid(building_visual):
		return
	var bounds := _get_visual_bounds(building_visual)
	if bounds.size.length_squared() <= 0.001:
		building_visual.position = Vector3.ZERO
		return
	var footprint := get_footprint()
	var safe_margin: float = clamp(visual_fit_margin, 0.1, 1.0)
	var fit_x: float = max(footprint.x * safe_margin, 0.1)
	var fit_z: float = max(footprint.y * safe_margin, 0.1)
	var scale_x: float = fit_x / max(bounds.size.x, 0.01)
	var scale_z: float = fit_z / max(bounds.size.z, 0.01)
	var uniform_scale: float = min(scale_x, scale_z)
	building_visual.scale *= uniform_scale
	await get_tree().process_frame
	bounds = _get_visual_bounds(building_visual)
	var center_offset := bounds.get_center()
	var desired_center := visual_root.global_position
	var correction := Vector3(
		center_offset.x - desired_center.x,
		bounds.position.y - desired_center.y,
		center_offset.z - desired_center.z
	)
	building_visual.global_position -= correction
	await get_tree().process_frame
	bounds = _get_visual_bounds(building_visual)
	_set_selection_indicator_size(Vector2(bounds.size.x, bounds.size.z))
	_set_interaction_area_size(Vector2(bounds.size.x, bounds.size.z), bounds.size.y)
	print("[BuildingVisual] fitted %s scale=%.2f footprint=(%.1f, %.1f)" % [get_selection_key(), uniform_scale, footprint.x, footprint.y])


func _set_selection_indicator_size(size: Vector2) -> void:
	if selection_sprite == null:
		return
	selection_sprite.scale = Vector3(max(size.x, 0.5), max(size.y, 0.5), 1.0)


func _set_interaction_area_size(size: Vector2, height: float) -> void:
	var width: float = max(size.x, 0.5)
	var depth: float = max(size.y, 0.5)
	var safe_height: float = max(height, 1.0)
	if occupancy_shape != null and occupancy_shape.shape is BoxShape3D:
		var occupancy_box := occupancy_shape.shape as BoxShape3D
		occupancy_box.size = Vector3(width, safe_height, depth)
		occupancy_shape.position.y = safe_height * 0.5
	if click_shape != null and click_shape.shape is BoxShape3D:
		var click_box := click_shape.shape as BoxShape3D
		click_box.size = Vector3(width, safe_height + 0.2, depth)
		click_shape.position.y = (safe_height + 0.2) * 0.5
	if cancel_shape != null and cancel_shape.shape is BoxShape3D:
		var cancel_box := cancel_shape.shape as BoxShape3D
		cancel_box.size = Vector3(max(width * 0.75, 1.0), 0.35, max(depth * 0.35, 0.6))
		cancel_shape.position.y = safe_height + 0.55
	if progress_label != null:
		progress_label.position.y = safe_height + 0.9
	if cancel_label != null:
		cancel_label.position.y = safe_height + 1.25


func _update_construction_labels() -> void:
	var show_progress := is_under_construction()
	if progress_label != null:
		progress_label.visible = show_progress
		if show_progress:
			progress_label.text = "%d%%" % int(round(get_build_progress_ratio() * 100.0))
	if cancel_label != null:
		cancel_label.visible = show_progress
	if cancel_shape != null:
		cancel_shape.disabled = not show_progress


func _get_visual_bounds(root: Node3D) -> AABB:
	var has_bounds := false
	var combined := AABB()
	for child in root.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null:
			continue
		var local_bounds := visual.get_aabb()
		var global_basis := visual.global_transform.basis
		var global_origin := visual.global_transform.origin
		var corners := [
			local_bounds.position,
			local_bounds.position + Vector3(local_bounds.size.x, 0.0, 0.0),
			local_bounds.position + Vector3(0.0, local_bounds.size.y, 0.0),
			local_bounds.position + Vector3(0.0, 0.0, local_bounds.size.z),
			local_bounds.position + Vector3(local_bounds.size.x, local_bounds.size.y, 0.0),
			local_bounds.position + Vector3(local_bounds.size.x, 0.0, local_bounds.size.z),
			local_bounds.position + Vector3(0.0, local_bounds.size.y, local_bounds.size.z),
			local_bounds.position + local_bounds.size
		]
		for corner in corners:
			var point: Vector3 = global_origin + global_basis * corner
			if not has_bounds:
				combined = AABB(point, Vector3.ZERO)
				has_bounds = true
			else:
				combined = combined.expand(point)
	return combined


func _get_total_build_time() -> float:
	if build_time_override > 0.0:
		return build_time_override
	if building_data != null and building_data.build_time > 0.0:
		return building_data.build_time
	return 1.0


func _update_visual() -> void:
	if mesh_instance == null:
		return
	mesh_instance.visible = _should_show_footprint_indicator()
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_instance.material_override = material
	if is_ghost:
		material.albedo_color = Color(0.3, 0.8, 1.0, 0.35) if ghost_valid else Color(1.0, 0.25, 0.25, 0.35)
		return
	var progress := get_build_progress_ratio()
	var base := Color(0.35, 0.55, 0.75, 0.85)
	var complete := Color(0.75, 0.9, 1.0, 1.0)
	material.albedo_color = base.lerp(complete, progress)


func _apply_start_power_impact() -> void:
	if power_consumed_applied:
		return
	if building_data == null or building_data.power_consumed <= 0:
		power_consumed_applied = true
		return
	if GameManager:
		GameManager.set_power_used(GameManager.power_used + building_data.power_consumed)
	power_consumed_applied = true


func _apply_complete_power_impact() -> void:
	if power_provided_applied:
		return
	if building_data == null or building_data.power_provided <= 0:
		power_provided_applied = true
		return
	if GameManager:
		GameManager.set_power_available(GameManager.power_available + building_data.power_provided)
	power_provided_applied = true


func _process_production(delta: float) -> void:
	if active_unit_id == "":
		_start_next_production()
		return
	if GameManager != null and GameManager.is_power_low():
		return
	production_timer = max(production_timer - delta, 0.0)
	if production_timer > 0.0:
		return
	_spawn_unit(active_unit_id)
	active_unit_id = ""
	_start_next_production()


func _start_next_production() -> void:
	if production_queue.is_empty():
		active_unit_id = ""
		production_timer = 0.0
		return
	active_unit_id = production_queue.pop_front()
	var unit_data: UnitData = DataRegistry.get_unit(active_unit_id) if DataRegistry else null
	production_timer = unit_data.build_time if unit_data != null and unit_data.build_time > 0.0 else 1.0


func _spawn_unit(unit_id: String) -> void:
	if unit_spawn_scene == null:
		return
	var unit_data: UnitData = DataRegistry.get_unit(unit_id) if DataRegistry else null
	var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var unit := unit_spawn_scene.instantiate() as Node3D
	if unit == null:
		return
	if unit_data != null:
		unit.set("unit_data", unit_data)
	unit.set("team_id", team_id)
	root.add_child(unit)
	unit.global_position = global_position + rally_offset
	print("[Production] spawned %s" % _get_unit_label(unit_id))


func _unit_command_point_cost(unit_id: String) -> int:
	var unit_data: UnitData = DataRegistry.get_unit(unit_id) if DataRegistry else null
	if unit_data == null:
		return 0
	return maxi(0, unit_data.command_point_cost)


func _get_unit_label(unit_id: String) -> String:
	var unit_data: UnitData = DataRegistry.get_unit(unit_id) if DataRegistry else null
	if unit_data != null and unit_data.display_name != "":
		return unit_data.display_name
	return unit_id
