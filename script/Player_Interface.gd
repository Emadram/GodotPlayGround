extends Node2D

# NODES
@onready var player_camera:Node3D = $CameraBase
@onready var player_camera_visibleunits_Area3D:Area3D = $CameraBase/visibleunits_area3D
@onready var ui_dragbox:NinePatchRect = $UI/ui_dragbox



# Variables
@onready var BoxSelectionUnits_Visible:Dictionary = {}
# {unit_id : unit_node}


# CONSTANTS
const min_drag_squared:int = 128

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
	if Input.is_action_just_pressed("mouse_leftclick"): # Runs once
		drag_rectangle_area.position = get_global_mouse_position()
		mouse_left_click = true
	if Input.is_action_just_released("mouse_leftclick"):
		mouse_left_click = false
		ui_dragbox.visible = false
		cast_selection()
		
# Unit selector
func cast_selection() -> void:
	for unit in BoxSelectionUnits_Visible.values():
		if drag_rectangle_area.abs().has_point( player_camera.get_Vector2_from_Vector3(unit.transform.origin)):
			unit.selected()
		else:
			unit.deselect()
	
func _process(delta: float) -> void:
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
