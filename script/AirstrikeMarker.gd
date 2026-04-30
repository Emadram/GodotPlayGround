extends Node3D

@export var lifetime: float = 0.8

func _ready() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(func():
		queue_free()
	)
