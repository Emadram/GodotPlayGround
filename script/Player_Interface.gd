extends Node2D

# NODES
@onready var player_camera:Node3D = $CameraBase
@onready var player_camera_visibleunits_Area3D:Area3D = $CameraBase/visibleunits_area3D
@onready var camera_3d:Camera3D = $CameraBase/CameraSocket/Camera3D
@onready var ui_dragbox:NinePatchRect = $UI/ui_dragbox

@export var airstrike_marker_scene: PackedScene



# Variables
@onready var BoxSelectionUnits_Visible:Dictionary = {}
# {unit_id : unit_node}
var selected_units: Array = []
var selection_groups: Dictionary = {}


# CONSTANTS
const min_drag_squared:int = 128
const formation_spacing:float = 1.6
const player_team_id:int = 1

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
	player_camera_visibleunits_Area3D.body_entered.connect(unit_entered)
	player_camera_visibleunits_Area3D.body_exited.connect(unit_exited)
	
func _input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		issue_move_command(event.shift_pressed)
	if Input.is_action_just_pressed("airstrike"):
		request_airstrike_at_cursor()
	if Input.is_action_just_pressed("mouse_leftclick"): # Runs once
		drag_rectangle_area.position = get_global_mouse_position()
		mouse_left_click = true
	if Input.is_action_just_released("mouse_leftclick"):
		mouse_left_click = false
		ui_dragbox.visible = false
		cast_selection()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var group_index: int = event.keycode - KEY_1 + 1
			if event.ctrl_pressed:
				selection_groups[group_index] = _filter_valid_units(selected_units)
			elif selection_groups.has(group_index):
				select_units(selection_groups[group_index])
		
# Unit selector
func cast_selection() -> void:
	var new_selection: Array = []
	for unit in BoxSelectionUnits_Visible.values():
		if drag_rectangle_area.abs().has_point( player_camera.get_Vector2_from_Vector3(unit.transform.origin)):
			new_selection.append(unit)
	select_units(new_selection)

func select_units(units: Array) -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.deselect()
	selected_units.clear()
	for unit in units:
		if is_instance_valid(unit):
			unit.selected()
			selected_units.append(unit)

func issue_move_command(queued: bool) -> void:
	selected_units = _filter_valid_units(selected_units)
	if selected_units.is_empty():
		return
	var target := get_mouse_world_position()
	var positions := build_formation_positions(target, selected_units.size(), formation_spacing)
	for i in range(selected_units.size()):
		var unit = selected_units[i]
		if not is_instance_valid(unit):
			continue
		if unit.has_method("issue_move"):
			var unit_target: Vector3 = positions[i]
			unit_target.y = unit.global_position.y
			unit.issue_move(unit_target, queued)

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
