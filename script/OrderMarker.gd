extends Node3D

@export var lifetime: float = 0.6

@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(func():
		queue_free()
	)

func setup(color: Color, scale_value: float) -> void:
	if mesh == null:
		return
	var mat := mesh.material_override
	if mat != null:
		var new_mat := mat.duplicate() as StandardMaterial3D
		new_mat.albedo_color = color
		mesh.material_override = new_mat
	scale = Vector3.ONE * scale_value
