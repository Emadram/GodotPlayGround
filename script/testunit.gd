extends Node3D

func _ready() -> void:
	deselect()


func selected() -> void:
	$selected.visible = true

func deselect() -> void:
	$selected.visible = false
