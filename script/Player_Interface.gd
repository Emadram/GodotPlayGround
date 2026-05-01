extends Node2D

# NODES
@onready var player_camera:Node3D = $CameraBase
@onready var player_camera_visibleunits_Area3D:Area3D = $CameraBase/visibleunits_area3D
@onready var camera_3d:Camera3D = $CameraBase/CameraSocket/Camera3D
@onready var ui_dragbox:NinePatchRect = $UI/ui_dragbox
@onready var attack_move_cursor: Label = $UI/attack_move_cursor

@export var airstrike_marker_scene: PackedScene
@export var order_marker_scene: PackedScene
@export var construction_site_scene: PackedScene
@export var build_grid_size: float = 1.0



# Variables
@onready var BoxSelectionUnits_Visible:Dictionary = {}
# {unit_id : unit_node}
var selected_units: Array = []
var selection_groups: Dictionary = {}
var selected_buildings: Array = []

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

enum CommandMode {
	NORMAL,
	ATTACK_MOVE,
	GUARD,
	BUILD
}

var pending_command_mode: CommandMode = CommandMode.NORMAL
var pending_building_id: String = "usa_command_center"
var build_preview: Node3D
var build_preview_valid: bool = false
var last_input_debug: String = "none"
var last_build_debug: String = "idle"
var successful_build_orders: int = 0
var last_builder_candidate_count: int = 0
var suppress_next_left_release: bool = false
var last_click_time: float = -1.0
var last_click_key: String = ""
var double_click_time: float = 0.25


# CONSTANTS
const min_drag_squared:int = 128
const formation_spacing:float = 1.6
const player_team_id:int = 1
const ray_length: float = 2000.0
const move_marker_color := Color(0.2, 0.8, 1.0, 0.7)
const attack_marker_color := Color(1.0, 0.3, 0.3, 0.7)
const guard_marker_color := Color(0.3, 1.0, 0.4, 0.7)
const harvest_marker_color := Color(1.0, 0.85, 0.2, 0.7)
const attack_move_marker_color := Color(1.0, 0.5, 0.2, 0.7)
const build_marker_color := Color(0.55, 0.75, 1.0, 0.8)

# Internal Variables
var mouse_left_click:bool = false
var drag_rectangle_area:Rect2


func find_selectable_root(node: Node) -> Node3D:
	var current: Node = node
	while current:
		if current.has_method("selected") and current.has_method("deselect"):
			return current as Node3D
		current = current.get_parent()
	return null


func _ready() -> void:
	initialize_interface()
	if airstrike_marker_scene == null:
		airstrike_marker_scene = load("res://scene/airstrike_marker.tscn") as PackedScene
	if order_marker_scene == null:
		order_marker_scene = load("res://scene/order_marker.tscn") as PackedScene
	if construction_site_scene == null:
		construction_site_scene = load("res://scene/construction_site.tscn") as PackedScene
	

func unit_entered(unit:Node3D) -> void:
	var unit_node:Node3D = find_selectable_root(unit)
	if unit_node == null:
		return
	var unit_id:int = unit_node.get_instance_id()
	if BoxSelectionUnits_Visible.keys().has(unit_id):return
	BoxSelectionUnits_Visible[unit_id] = unit_node
	print("unit entered: ", unit ," id:", unit_id," unit_node", unit_node)
	debug_units_visible()
	
func unit_exited(unit:Node3D) -> void:
	var unit_node:Node3D = find_selectable_root(unit)
	if unit_node == null:
		return
	var unit_id:int = unit_node.get_instance_id()
	if !BoxSelectionUnits_Visible.keys().has(unit_id):return
	BoxSelectionUnits_Visible.erase(unit_id)
	print("unit exited: ", unit ," id:", unit_id," unit_node", unit_node)

# FOR DEBUG ONLY
func debug_units_visible() -> void:
	print(BoxSelectionUnits_Visible)
	
func initialize_interface() -> void:
	ui_dragbox.visible = false
	if attack_move_cursor != null:
		attack_move_cursor.visible = false
	player_camera_visibleunits_Area3D.body_entered.connect(unit_entered)
	player_camera_visibleunits_Area3D.body_exited.connect(unit_exited)
	
func _input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		if get_viewport().gui_get_hovered_control() != null:
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if pending_command_mode == CommandMode.BUILD:
				pending_command_mode = CommandMode.NORMAL
				_set_build_debug("build cancelled (right click)")
				_clear_build_preview()
				return
			issue_context_command(event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if pending_command_mode == CommandMode.BUILD:
					suppress_next_left_release = true
					mouse_left_click = false
					ui_dragbox.visible = false
					_set_input_debug("LMB build place: %s" % pending_building_id)
					_issue_build_from_preview(event.shift_pressed)
					return
				drag_rectangle_area.position = get_global_mouse_position()
				mouse_left_click = true
			else:
				if suppress_next_left_release:
					suppress_next_left_release = false
					mouse_left_click = false
					ui_dragbox.visible = false
					return
				mouse_left_click = false
				ui_dragbox.visible = false
				finalize_selection(event)
	if Input.is_action_just_pressed("airstrike"):
		request_airstrike_at_cursor()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("command_stop"):
			issue_stop_command()
			return
		if event.is_action_pressed("command_hold"):
			issue_hold_command()
			return
		if event.is_action_pressed("attack_move"):
			pending_command_mode = CommandMode.ATTACK_MOVE
			return
		if event.is_action_pressed("command_guard"):
			pending_command_mode = CommandMode.GUARD
			_set_input_debug("guard key")
			return
		if event.is_action_pressed("build_mode") or event.keycode == KEY_B or event.physical_keycode == KEY_B:
			_set_input_debug("build key code=%d phys=%d" % [event.keycode, event.physical_keycode])
			set_build_mode()
			return
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var group_index: int = event.keycode - KEY_1 + 1
			if event.ctrl_pressed:
				var valid_selection := _filter_valid_units(selected_units)
				if event.shift_pressed and selection_groups.has(group_index):
					selection_groups[group_index] = _merge_units(selection_groups[group_index], valid_selection)
				else:
					selection_groups[group_index] = valid_selection
			elif selection_groups.has(group_index):
				select_units(selection_groups[group_index], event.shift_pressed)
		
# Unit selector
func finalize_selection(event: InputEventMouseButton) -> void:
	var append := event.shift_pressed
	if pending_command_mode == CommandMode.BUILD:
		_issue_build_from_preview(append)
		return
	if pending_command_mode != CommandMode.NORMAL:
		issue_context_command(append)
		return
	if drag_rectangle_area.size.length_squared() > min_drag_squared:
		cast_selection(append)
	else:
		click_select(append)

func cast_selection(append: bool = false) -> void:
	var new_selection: Array = []
	for unit in BoxSelectionUnits_Visible.values():
		if drag_rectangle_area.abs().has_point(player_camera.get_Vector2_from_Vector3(unit.transform.origin)):
			new_selection.append(unit)
	select_units(new_selection, append)

func click_select(append: bool) -> void:
	var hit := get_mouse_hit()
	var cancel_target := get_cancel_building_from_hit(hit)
	if cancel_target != null:
		cancel_target.cancel_construction()
		return
	var target_unit := get_selectable_from_hit(hit)
	if target_unit == null:
		if hit.has("collider"):
			print("[Selection] no selectable root for collider: %s" % hit["collider"])
		else:
			print("[Selection] click missed selectable")
		if not append:
			clear_selection()
		return
	if target_unit.is_in_group("buildings"):
		select_buildings([target_unit], append)
		print("[Selection] building click: %s" % target_unit.name)
		last_click_time = float(Time.get_ticks_msec()) / 1000.0
		last_click_key = get_selection_key(target_unit)
		return
	var key := get_selection_key(target_unit)
	var now := float(Time.get_ticks_msec()) / 1000.0
	if key != "" and key == last_click_key and now - last_click_time <= double_click_time:
		var same_units := get_visible_units_by_key(key)
		select_units(same_units, false)
	else:
		select_units([target_unit], append)
	last_click_time = now
	last_click_key = key

func select_units(units: Array, append: bool = false) -> void:
	var new_selection := _filter_valid_units(units)
	if append:
		new_selection = _merge_units(selected_units, new_selection)
	for unit in selected_units:
		if is_instance_valid(unit) and not new_selection.has(unit):
			unit.deselect()
	selected_units.clear()
	for unit in new_selection:
		if is_instance_valid(unit):
			unit.selected()
			selected_units.append(unit)
	if not append:
		_clear_selected_buildings()


func select_buildings(buildings: Array, append: bool = false) -> void:
	var new_selection := _filter_valid_units(buildings)
	if append:
		new_selection = _merge_units(selected_buildings, new_selection)
	for building in selected_buildings:
		if is_instance_valid(building) and not new_selection.has(building):
			building.deselect()
	selected_buildings.clear()
	for building in new_selection:
		if is_instance_valid(building):
			building.selected()
			selected_buildings.append(building)
	if not append:
		_clear_selected_units()


func clear_selection() -> void:
	_clear_selected_units()
	_clear_selected_buildings()


func _clear_selected_units() -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.deselect()
	selected_units.clear()


func _clear_selected_buildings() -> void:
	for building in selected_buildings:
		if is_instance_valid(building):
			building.deselect()
	selected_buildings.clear()

func issue_context_command(queued: bool) -> void:
	selected_units = _filter_valid_units(selected_units)
	if selected_units.is_empty():
		return
	var hit := get_mouse_hit()
	var target_unit := get_selectable_from_hit(hit)
	var resource_node := get_resource_from_hit(hit)
	var target_position := Vector3.ZERO
	if hit.has("position"):
		target_position = hit["position"]
	else:
		target_position = get_mouse_world_position()

	if pending_command_mode == CommandMode.ATTACK_MOVE:
		pending_command_mode = CommandMode.NORMAL
		issue_move_like_command(CommandType.ATTACK_MOVE, target_position, queued)
		spawn_order_marker(target_position, attack_move_marker_color, 1.1)
		return
	if pending_command_mode == CommandMode.GUARD:
		pending_command_mode = CommandMode.NORMAL
		if target_unit != null and not _is_enemy(target_unit):
			issue_target_command(CommandType.GUARD, target_unit, queued)
			spawn_order_marker(target_unit.global_position + Vector3(0, 1.0, 0), guard_marker_color, 0.9)
		return

	if target_unit != null:
		if target_unit.is_in_group("buildings") and _has_selected_builder() and target_unit.has_method("is_under_construction") and target_unit.is_under_construction():
			issue_resume_build_command(target_unit, queued)
			spawn_order_marker(target_unit.global_position, build_marker_color, 1.0)
			return
		if _is_enemy(target_unit):
			issue_target_command(CommandType.ATTACK, target_unit, queued)
			spawn_order_marker(target_unit.global_position + Vector3(0, 1.0, 0), attack_marker_color, 0.9)
		else:
			issue_target_command(CommandType.GUARD, target_unit, queued)
			spawn_order_marker(target_unit.global_position + Vector3(0, 1.0, 0), guard_marker_color, 0.9)
		return
	if resource_node != null:
		issue_target_command(CommandType.HARVEST, resource_node, queued)
		spawn_order_marker(resource_node.global_position, harvest_marker_color, 0.9)
		return

	issue_move_like_command(CommandType.MOVE, target_position, queued)
	spawn_order_marker(target_position, move_marker_color, 1.0)

func issue_stop_command() -> void:
	pending_command_mode = CommandMode.NORMAL
	issue_simple_command(CommandType.STOP)

func issue_hold_command() -> void:
	pending_command_mode = CommandMode.NORMAL
	issue_simple_command(CommandType.HOLD)

func set_guard_mode() -> void:
	if not _has_selected_combat_unit():
		return
	pending_command_mode = CommandMode.GUARD

func set_attack_move_mode() -> void:
	if not _has_selected_combat_unit():
		return
	pending_command_mode = CommandMode.ATTACK_MOVE

func set_build_mode(building_id: String = "usa_command_center") -> void:
	if not _has_any_builder_available():
		_set_build_debug("build mode failed: no dozer available")
		return
	pending_building_id = building_id
	pending_command_mode = CommandMode.BUILD
	_set_build_debug("build mode active: %s" % building_id)
	_ensure_build_preview()

func issue_simple_command(cmd_type: int) -> void:
	selected_units = _filter_valid_units(selected_units)
	for unit in selected_units:
		if not is_instance_valid(unit):
			continue
		if unit.has_method("issue_command"):
			unit.issue_command(build_command(cmd_type), false)

func issue_move_like_command(cmd_type: int, target: Vector3, queued: bool) -> void:
	var units := _filter_units_for_command(cmd_type, selected_units)
	var positions := build_formation_positions(target, units.size(), formation_spacing)
	for i in range(units.size()):
		var unit = units[i]
		if not is_instance_valid(unit):
			continue
		var unit_target: Vector3 = positions[i]
		unit_target.y = unit.global_position.y
		issue_command_to_unit(unit, build_command(cmd_type, unit_target), queued)

func issue_target_command(cmd_type: int, target: Node3D, queued: bool) -> void:
	for unit in _filter_units_for_command(cmd_type, selected_units):
		if not is_instance_valid(unit):
			continue
		issue_command_to_unit(unit, build_command(cmd_type, Vector3.ZERO, target), queued)


func issue_resume_build_command(target: Node3D, queued: bool) -> void:
	for unit in _get_selected_builders():
		if not is_instance_valid(unit):
			continue
		issue_command_to_unit(unit, {
			"type": CommandType.BUILD,
			"position": target.global_position,
			"target": target,
			"building_id": target.get("building_id")
		}, queued)
	print("[Build] resume construction: %s" % target.get("building_id"))

func issue_command_to_unit(unit: Node, command: Dictionary, queued: bool) -> void:
	if unit.has_method("issue_command"):
		unit.issue_command(command, queued)
		return
	if int(command.get("type", CommandType.MOVE)) == CommandType.MOVE and unit.has_method("issue_move"):
		unit.issue_move(command.get("position", Vector3.ZERO), queued)

func get_mouse_world_position() -> Vector3:
	if camera_3d == null:
		return Vector3.ZERO
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := camera_3d.project_ray_origin(mouse_pos)
	var direction := camera_3d.project_ray_normal(mouse_pos)
	if abs(direction.y) < 0.001:
		return origin
	var t := (0.0 - origin.y) / direction.y
	return origin + direction * t

func build_formation_positions(center: Vector3, count: int, spacing: float) -> Array:
	var positions: Array = []
	if count <= 0:
		return positions
	var columns := int(ceil(sqrt(float(count))))
	var rows := int(ceil(float(count) / float(columns)))
	var start_x := -((columns - 1) * spacing) * 0.5
	var start_z := -((rows - 1) * spacing) * 0.5
	for i in range(count):
		var col := i % columns
		var row: int = int(i / float(columns))
		var pos := center + Vector3(start_x + col * spacing, 0.0, start_z + row * spacing)
		positions.append(pos)
	return positions

func build_command(cmd_type: int, position: Vector3 = Vector3.ZERO, target: Node3D = null) -> Dictionary:
	return {
		"type": cmd_type,
		"position": position,
		"target": target,
		"building_id": pending_building_id
	}

func spawn_order_marker(position: Vector3, color: Color, scale_value: float) -> void:
	if order_marker_scene == null:
		return
	var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var marker := order_marker_scene.instantiate()
	root.add_child(marker)
	marker.global_position = position
	if marker.has_method("setup"):
		marker.setup(color, scale_value)

func get_mouse_hit() -> Dictionary:
	if camera_3d == null:
		return {}
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := camera_3d.project_ray_origin(mouse_pos)
	var direction := camera_3d.project_ray_normal(mouse_pos)
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + direction * ray_length
	params.collide_with_areas = true
	params.collide_with_bodies = true
	if player_camera_visibleunits_Area3D != null:
		params.exclude = [player_camera_visibleunits_Area3D.get_rid()]
	return camera_3d.get_world_3d().direct_space_state.intersect_ray(params)

func get_selectable_from_hit(hit: Dictionary) -> Node3D:
	if not hit.has("collider"):
		return null
	return find_selectable_root(hit["collider"])

func get_resource_from_hit(hit: Dictionary) -> Node3D:
	if not hit.has("collider"):
		return null
	var current: Node = hit["collider"]
	while current:
		if current.has_method("take_supply"):
			return current as Node3D
		current = current.get_parent()
	return null


func get_cancel_building_from_hit(hit: Dictionary) -> Node3D:
	if not hit.has("collider"):
		return null
	var current: Node = hit["collider"]
	var saw_cancel_area := false
	while current:
		if current.name == "CancelArea":
			saw_cancel_area = true
		if saw_cancel_area and current.has_method("cancel_construction"):
			return current as Node3D
		current = current.get_parent()
	return null

func get_selection_key(unit: Node) -> String:
	if unit == null:
		return ""
	if unit.has_method("get_selection_key"):
		return unit.get_selection_key()
	return unit.name

func get_visible_units_by_key(key: String) -> Array:
	var results: Array = []
	for unit in BoxSelectionUnits_Visible.values():
		if not is_instance_valid(unit):
			continue
		if get_selection_key(unit) == key:
			results.append(unit)
	return results

func _is_enemy(unit: Node) -> bool:
	if unit == null:
		return false
	var other_team = unit.get("team_id")
	if typeof(other_team) != TYPE_INT:
		return false
	return other_team != player_team_id

func _merge_units(primary: Array, extra: Array) -> Array:
	var merged: Array = []
	for unit in primary:
		if is_instance_valid(unit) and not merged.has(unit):
			merged.append(unit)
	for unit in extra:
		if is_instance_valid(unit) and not merged.has(unit):
			merged.append(unit)
	return merged

func _filter_valid_units(units: Array) -> Array:
	var filtered: Array = []
	for unit in units:
		if is_instance_valid(unit):
			filtered.append(unit)
	return filtered

func request_airstrike_at_cursor() -> void:
	if GameManager == null:
		return
	if GameManager.promotion_level < 1:
		return
	var target := get_mouse_world_position()
	spawn_airstrike_marker(target)
	GameManager.request_airstrike(target, player_team_id)

func spawn_airstrike_marker(target_position: Vector3) -> void:
	if airstrike_marker_scene == null:
		return
	var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var marker := airstrike_marker_scene.instantiate()
	root.add_child(marker)
	marker.global_position = Vector3(target_position.x, 0.05, target_position.z)
	
func _process(_delta: float) -> void:
	if mouse_left_click:
		
		drag_rectangle_area.size = get_global_mouse_position() - drag_rectangle_area.position
		update_ui_dragbox()
		
		if !ui_dragbox.visible:
			if drag_rectangle_area.size.length_squared() > min_drag_squared:
				ui_dragbox.visible = true
	_update_build_preview()
	update_attack_move_cursor()
			

func update_ui_dragbox() -> void:
	ui_dragbox.size = abs(drag_rectangle_area.size)
	ui_dragbox.position = drag_rectangle_area.position
	#Detect when to scale the dragbox backwards
	#Detect X swap
	if drag_rectangle_area.size.x < 0:
		ui_dragbox.scale.x = -1
	else:
		ui_dragbox.scale.x = 1
	#Detect Y swap
	if drag_rectangle_area.size.y < 0:
		ui_dragbox.scale.y = -1
	else:
		ui_dragbox.scale.y = 1

func update_attack_move_cursor() -> void:
	if attack_move_cursor == null:
		return
	if pending_command_mode == CommandMode.ATTACK_MOVE:
		attack_move_cursor.visible = true
		attack_move_cursor.position = get_viewport().get_mouse_position() + Vector2(14, 18)
	else:
		attack_move_cursor.visible = false


func _issue_build_from_preview(queued: bool) -> void:
	_ensure_build_preview()
	_update_build_preview()
	if build_preview == null:
		_set_build_debug("build failed %s: no preview" % pending_building_id)
		return
	if not build_preview_valid:
		_set_build_debug("build failed %s: invalid footprint at %.1f, %.1f" % [pending_building_id, build_preview.global_position.x, build_preview.global_position.z])
		return
	if _issue_build_command(pending_building_id, build_preview.global_position, queued):
		successful_build_orders += 1
		_set_build_debug("build issued #%d %s at (%.1f, %.1f), queued=%s" % [successful_build_orders, pending_building_id, build_preview.global_position.x, build_preview.global_position.z, str(queued)])
		spawn_order_marker(build_preview.global_position, build_marker_color, 1.15)
		if not queued:
			pending_command_mode = CommandMode.NORMAL
			_clear_build_preview()
	else:
		_set_build_debug("build failed %s: no dozer candidates=%d" % [pending_building_id, last_builder_candidate_count])


func _issue_build_command(building_id: String, position: Vector3, queued: bool) -> bool:
	var builders := _get_selected_builders()
	if builders.is_empty():
		builders = _get_fallback_builders(position)
	else:
		last_builder_candidate_count = builders.size()
	var issued := 0
	for unit in builders:
		if not is_instance_valid(unit):
			continue
		if not unit.has_method("issue_command"):
			continue
		issue_command_to_unit(unit, {
			"type": CommandType.BUILD,
			"position": position,
			"target": null,
			"building_id": building_id
		}, queued)
		issued += 1
	return issued > 0


func _ensure_build_preview() -> void:
	if pending_command_mode != CommandMode.BUILD:
		return
	if build_preview != null and is_instance_valid(build_preview):
		return
	if construction_site_scene == null:
		return
	var site := construction_site_scene.instantiate()
	var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	root.add_child(site)
	build_preview = site as Node3D
	var building_data: BuildingData = DataRegistry.get_building(pending_building_id) if DataRegistry else null
	if build_preview != null and build_preview.has_method("configure") and building_data != null:
		build_preview.configure(pending_building_id, player_team_id, building_data, true)


func _clear_build_preview() -> void:
	if build_preview != null and is_instance_valid(build_preview):
		build_preview.queue_free()
	build_preview = null
	build_preview_valid = false


func _update_build_preview() -> void:
	if pending_command_mode != CommandMode.BUILD:
		_clear_build_preview()
		return
	_ensure_build_preview()
	if build_preview == null:
		return
	var snapped := get_mouse_world_position()
	var snap: float = maxf(build_grid_size, 0.1)
	snapped.x = round(snapped.x / snap) * snap
	snapped.z = round(snapped.z / snap) * snap
	snapped.y = 0.0
	build_preview.global_position = snapped
	build_preview_valid = _is_build_position_valid(snapped)
	if build_preview.has_method("set_ghost_valid"):
		build_preview.set_ghost_valid(build_preview_valid)


func _is_build_position_valid(position: Vector3) -> bool:
	var building_data: BuildingData = DataRegistry.get_building(pending_building_id) if DataRegistry else null
	if building_data == null:
		return false
	var world := camera_3d.get_world_3d() if camera_3d != null else null
	if world == null:
		return false
	var shape := BoxShape3D.new()
	var footprint := building_data.footprint
	footprint.x = max(footprint.x, 1.0)
	footprint.y = max(footprint.y, 1.0)
	shape.size = Vector3(footprint.x, 1.0, footprint.y)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, Vector3(position.x, 0.5, position.z))
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hits := world.direct_space_state.intersect_shape(query, 32)
	for hit in hits:
		var collider: Node = hit.get("collider", null)
		if collider == null:
			continue
		var root := _find_build_blocker_root(collider)
		if root == null:
			continue
		if build_preview != null and (root == build_preview or build_preview.is_ancestor_of(root)):
			continue
		return false
	return true


func _find_build_blocker_root(node: Node) -> Node:
	var current: Node = node
	while current:
		if current.is_in_group("buildings") or current.is_in_group("resource_nodes"):
			return current
		current = current.get_parent()
	return null


func _get_selected_builders() -> Array:
	var builders: Array = []
	selected_units = _filter_valid_units(selected_units)
	for unit in selected_units:
		if _is_builder_candidate(unit):
			builders.append(unit)
	return builders


func _get_fallback_builders(target_position: Vector3) -> Array:
	var candidates: Array = []
	for builder in get_tree().get_nodes_in_group("builders"):
		if _is_builder_candidate(builder):
			candidates.append(builder)
	for unit in get_tree().get_nodes_in_group("units"):
		if _is_builder_candidate(unit) and not candidates.has(unit):
			candidates.append(unit)
	if candidates.is_empty():
		var root := get_tree().root
		_collect_builder_candidates(root, candidates)
	last_builder_candidate_count = candidates.size()
	var best_builder: Node = null
	var best_distance: float = INF
	for unit in candidates:
		var distance := (unit as Node3D).global_position.distance_to(target_position)
		if distance < best_distance:
			best_distance = distance
			best_builder = unit
	if best_builder == null:
		return []
	return [best_builder]


func _is_builder_candidate(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if not (unit is Node3D):
		return false
	var other_team = unit.get("team_id")
	if typeof(other_team) == TYPE_INT and other_team != player_team_id:
		return false
	if unit.has_method("can_construct") and unit.can_construct():
		return true
	return false


func _has_any_builder_available() -> bool:
	if not get_tree().get_nodes_in_group("builders").is_empty():
		return true
	var candidates: Array = []
	var root := get_tree().root
	_collect_builder_candidates(root, candidates)
	return not candidates.is_empty()


func _has_selected_builder() -> bool:
	return not _get_selected_builders().is_empty()


func _has_selected_combat_unit() -> bool:
	for unit in selected_units:
		if _is_combat_unit(unit):
			return true
	return false


func _is_combat_unit(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if unit.has_method("can_attack"):
		return unit.can_attack()
	return unit.has_method("apply_damage") and not _is_builder_candidate(unit)


func _filter_units_for_command(cmd_type: int, units: Array) -> Array:
	var filtered: Array = []
	for unit in _filter_valid_units(units):
		match cmd_type:
			CommandType.ATTACK, CommandType.ATTACK_MOVE, CommandType.GUARD:
				if _is_combat_unit(unit):
					filtered.append(unit)
			CommandType.BUILD:
				if _is_builder_candidate(unit):
					filtered.append(unit)
			_:
				filtered.append(unit)
	return filtered


func _collect_builder_candidates(node: Node, into: Array) -> void:
	if node == null:
		return
	if _is_builder_candidate(node):
		into.append(node)
	for child in node.get_children():
		_collect_builder_candidates(child, into)


func _set_input_debug(message: String) -> void:
	last_input_debug = message
	print("[BuildInput] ", message)


func _set_build_debug(message: String) -> void:
	last_build_debug = message
	print("[Build] ", message)


func get_build_debug_state() -> Dictionary:
	var mode_name := "NORMAL"
	match pending_command_mode:
		CommandMode.ATTACK_MOVE:
			mode_name = "ATTACK_MOVE"
		CommandMode.GUARD:
			mode_name = "GUARD"
		CommandMode.BUILD:
			mode_name = "BUILD"
	return {
		"mode": mode_name,
		"preview_valid": build_preview_valid,
		"last_input": last_input_debug,
		"last_build": last_build_debug,
		"build_orders": successful_build_orders,
		"selected_builders": _get_selected_builders().size(),
		"fallback_candidates": last_builder_candidate_count
	}


func get_command_ui_state() -> Dictionary:
	selected_units = _filter_valid_units(selected_units)
	selected_buildings = _filter_valid_units(selected_buildings)
	var selected_count := selected_units.size()
	var has_builder := false
	var has_combat := false
	for unit in selected_units:
		if _is_builder_candidate(unit):
			has_builder = true
		if _is_combat_unit(unit):
			has_combat = true
	var production_label := _get_selected_production_label()
	return {
		"has_selection": selected_count > 0 or selected_buildings.size() > 0,
		"has_unit_selection": selected_count > 0,
		"has_builder": has_builder,
		"has_combat": has_combat,
		"can_train": production_label != "",
		"train_label": production_label
	}


func queue_selected_production_unit(unit_id: String = "") -> bool:
	for building in selected_buildings:
		if not is_instance_valid(building):
			continue
		if unit_id != "" and building.has_method("queue_unit") and building.queue_unit(unit_id):
			var label := _get_unit_label(unit_id)
			print("[Production] queued %s from %s" % [label, building.name])
			return true
		if unit_id == "" and building.has_method("queue_default_unit") and building.queue_default_unit():
			var label := _get_building_production_label(building)
			print("[Production] queued %s from %s" % [label, building.name])
			return true
	print("[Production] queue failed: select a completed production building with available units")
	return false


func cancel_selected_production_at(index: int) -> bool:
	for building in selected_buildings:
		if not is_instance_valid(building):
			continue
		if building.has_method("cancel_production_at") and building.cancel_production_at(index):
			return true
	print("[Production] cancel failed: no selected queue item at %d" % index)
	return false


func get_selected_production_queue_items() -> Array[Dictionary]:
	for building in selected_buildings:
		if not is_instance_valid(building):
			continue
		if not building.has_method("get_production_debug_state"):
			continue
		var state: Dictionary = building.get_production_debug_state()
		if not bool(state.get("completed", false)):
			continue
		if building.has_method("get_production_queue_items"):
			return building.get_production_queue_items()
	return []


func get_selected_building_bar_state() -> Dictionary:
	selected_buildings = _filter_valid_units(selected_buildings)
	if selected_buildings.is_empty():
		return {
			"has_building": false
		}
	var building: Node = selected_buildings[0]
	var building_label := get_selection_key(building)
	if building.has_method("get_building_display_label"):
		building_label = str(building.get_building_display_label())
	return {
		"has_building": true,
		"building_id": get_selection_key(building),
		"building_label": building_label,
		"train_label": _get_building_production_label(building),
		"train_options": _get_building_production_options(building),
		"queue_items": get_selected_production_queue_items(),
		"max_queue": _get_building_max_queue(building)
	}


func _get_selected_production_label() -> String:
	for building in selected_buildings:
		if not is_instance_valid(building):
			continue
		var label := _get_building_production_label(building)
		if label != "":
			return label
	return ""


func _get_building_production_label(building: Node) -> String:
	if building.has_method("get_default_production_label"):
		return str(building.get_default_production_label())
	return ""


func _get_building_production_options(building: Node) -> Array[Dictionary]:
	if building.has_method("get_production_options"):
		return building.get_production_options()
	var label := _get_building_production_label(building)
	if label == "":
		return []
	return [{
		"unit_id": "",
		"label": label
	}]


func _get_unit_label(unit_id: String) -> String:
	var unit_data: UnitData = DataRegistry.get_unit(unit_id) if DataRegistry else null
	if unit_data != null and unit_data.display_name != "":
		return unit_data.display_name
	return unit_id


func _get_building_max_queue(building: Node) -> int:
	if building.has_method("get_max_production_queue"):
		return int(building.get_max_production_queue())
	return 0
