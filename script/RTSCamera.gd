extends Node3D
# CameraMove
@export_range(0,100,1) var camera_move_speed:float = 20.0

# CameraRotate
var camera_rotation_direction:int = 0
@export_range(0,10,0.1) var camera_rotation_speed:float = 0.20
@export_range(0,20,1) var camera_base_rotation_speed:float = 10
@export_range(0,10,1) var camera_socket_rotation_x_min:float = -10.20
@export_range(0,10,1) var camera_socket_rotation_x_max:float = -0.20
# CameraPan
@export_range(0,32,4) var camera_automatic_pan_margin:int = 16
@export_range(0,20,0.5) var camera_automatic_pan_speed:float = 16.5


# CameraZoom
var camera_zoom_direction:float = 0
@export_range(0,100,1) var camera_zoom_speed = 40.0
@export_range(0,100,1) var camera_zoom_min = 4.0
@export_range(0,100,1) var camera_zoom_max = 25.0
@export_range(0,2,0.1) var camera_zoom_speed_damp:float = 0.92

# Flags
var camera_can_process:bool = true
var camera_can_move_base:bool = true
var camera_can_zoom:bool = true
var camera_can_automatic_pan:bool = false
var camera_can_rotate_base:bool = true
var camera_can_rotate_socket_x:bool = true
var camera_can_rotate_by_mouse_offset:bool = true

# Internal Flag
var camera_is_rotating_base:bool = false
var camera_is_rotating_mouse:bool = false
var mouse_last_postion:Vector2 = Vector2.ZERO

# Nodes
@onready var camera_socket:Node3D = $CameraSocket
@onready var camera:Camera3D = $CameraSocket/Camera3D


func _ready() -> void:
	pass

#Camera function calls go here 
func _process(delta: float) -> void:
	if !camera_can_process:return
	
	camera_base_move(delta)
	camera_zoom_update(delta)
	camera_automatic_pan(delta)
	camera_base_rotate(delta)
	camera_rotate_to_mouse_offsets(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Camera Zoom
	if event.is_action("camera_zoom_in"):
		camera_zoom_direction = -1
	elif event.is_action("camera_zoom_out"):
		camera_zoom_direction = 1
		
	if event.is_action_pressed("camera_rotate_right"):
		camera_rotation_direction = 1
		camera_is_rotating_base = true
	elif event.is_action_pressed("camera_rotate_left"):
		camera_rotation_direction = -1
		camera_is_rotating_base = true
	elif event.is_action_released("camera_rotate_left") or event.is_action_released("camera_rotate_right"):
		camera_is_rotating_base = false
		
	if event.is_action_pressed("camera_rotate_mouse"):
		mouse_last_postion = get_viewport().get_mouse_position()
		camera_is_rotating_mouse = true
	elif event.is_action_released("camera_rotate_mouse"):
		camera_is_rotating_mouse = false
		

# Moves the base of the camera with WASD
func camera_base_move(delta:float) -> void:
	if !camera_can_move_base:return
	var velocity_direction:Vector3 = Vector3.ZERO
	
	if Input.is_action_pressed("camera_forward"): velocity_direction -= transform.basis.z
	if Input.is_action_pressed("camera_backward"): velocity_direction += transform.basis.z
	if Input.is_action_pressed("camera_right"): velocity_direction -= transform.basis.x
	if Input.is_action_pressed("camera_left"): velocity_direction += transform.basis.x
	
	position += velocity_direction.normalized() * camera_move_speed * delta

# Controls the zoom of the camera
func camera_zoom_update(delta:float) -> void:
	if !camera_can_zoom:return
	
	var new_zoom:float = clamp(camera.position.z + camera_zoom_speed * camera_zoom_direction * delta, camera_zoom_min, camera_zoom_max)
	camera.position.z = new_zoom
	camera_zoom_direction *= camera_zoom_speed_damp

# Rotate the camera socket based on mouse offsets
func camera_rotate_to_mouse_offsets(delta:float) -> void:
	if !camera_can_rotate_by_mouse_offset or !camera_is_rotating_mouse:return
	var mouse_offset:Vector2 = get_viewport().get_mouse_position()
	mouse_offset = mouse_offset - mouse_last_postion
	
	mouse_last_postion = get_viewport().get_mouse_position()
	
	camera_base_rotate_left_right(delta,mouse_offset.x)
	camera_socket_rotate_x(delta,mouse_offset.y)
	
	

# Rotates the camera base
func camera_base_rotate(delta:float) -> void:
	if !camera_can_rotate_base or !camera_is_rotating_base:return
	
	#TO ROTATE
	camera_base_rotate_left_right(delta,camera_rotation_direction * camera_rotation_speed)

# Rotates the socket of the camera
func camera_socket_rotate_x(delta:float, dir:float) -> void:
	if !camera_can_rotate_socket_x:return;
	
	var new_rotation_x:float = camera_socket.rotation.x
	new_rotation_x -= dir * delta * camera_rotation_speed
	
	new_rotation_x = clamp(new_rotation_x,camera_socket_rotation_x_min, camera_socket_rotation_x_max)
	#new_rotation_x = new_rotation_x
	camera_socket.rotation.x = new_rotation_x

# Rotate the camera base left to right
func camera_base_rotate_left_right(delta:float, dir:float) -> void:
	rotation.y += dir * camera_rotation_speed * delta
	
	
	
# Pans the camera automatically based on the screen margin
func camera_automatic_pan(delta:float) -> void:
	if !camera_can_automatic_pan:return
	
	var viewport_current:Viewport = get_viewport()
	var pan_direction:Vector2 = Vector2(-1,-1) # Starts negative
	var viewport_visible_rectangle:Rect2i = Rect2i(viewport_current.get_visible_rect())
	var viewport_size:Vector2i = viewport_visible_rectangle.size
	var current_mouse_position:Vector2 = viewport_current.get_mouse_position()
	var margin:float = camera_automatic_pan_margin # Shortcut var
	
	var zoom_factor:float = camera.position.z * 0.1
	
	# X Pan
	if ((current_mouse_position.x < margin) or (current_mouse_position.x > viewport_size.x - margin)):
		if current_mouse_position.x > viewport_size.x/2 :
			pan_direction.x = 1
		translate( Vector3(pan_direction.x * delta * camera_automatic_pan_speed * zoom_factor,0,0))
		
	# Y Pan
	if ((current_mouse_position.y < margin) or (current_mouse_position.y > viewport_size.y - margin)):
		if current_mouse_position.y > viewport_size.x/2 :
			pan_direction.y = 1
		translate( Vector3(0,0,pan_direction.y * delta * camera_automatic_pan_speed * zoom_factor))

# Unrpoject Vector3 to Vector2		
func get_Vector2_from_Vector3(unproject_from_vec3:Vector3) -> Vector2:
	return camera.unproject_position(unproject_from_vec3)
	
	
	
	
	
