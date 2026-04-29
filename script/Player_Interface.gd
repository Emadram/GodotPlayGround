extends Node2D

# NODES
@onready var player_camera:Node3D = $CameraBase
@onready var player_camera_visibleunits_Area3D:Area3D = $CameraBase/visibleunits_area3D
@onready var ui_dragbox:NinePatchRect = $ui_dragbox



# Variables
@onready var BoxSelectionUnits_Visible:Dictionary = {}
# {unit_id : unit_node}


# CONSTANTS
const min_drag_squared:int = 128

# Internal Variables
var mouse_left_click:bool = false
var drag_rectangle_area:Rect2


func _ready() -> void:
	initialize_interface()
	

func unit_entered(unit:Node3D) -> void:
	var unit_id:int = unit.get_instance_id()
	if BoxSelectionUnits_Visible.keys().has(unit_id):return
	BoxSelectionUnits_Visible[unit_id] = unit.get_parent()
	print("unit entered: ", unit ," id:", unit_id," unit_node", unit.get_parent())
	
func unit_exited(unit:Node3D) -> void:
	var unit_id:int = unit.get_instance_id()
	if !BoxSelectionUnits_Visible.keys().has(unit_id):return
	BoxSelectionUnits_Visible.erase(unit_id)
	print("unit exited: ", unit ," id:", unit_id," unit_node", unit.get_parent())

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
		cast_selection()
		

func cast_selection() -> void:
	pass
	
func _process(delta: float) -> void:
	if mouse_left_click:
		if !ui_dragbox.visible:
			if drag_rectangle_area.size.length_squared() > min_drag_squared:
				ui_dragbox.visible = true
		else:
			update_ui_dragbox()
			
		drag_rectangle_area.size = get_global_mouse_position() - drag_rectangle_area.position

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
