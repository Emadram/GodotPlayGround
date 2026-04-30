extends Node3D

func _ready() -> void:
	setup_selection_visual()
	deselect()


func setup_selection_visual() -> void:
	var selection_sprite:Sprite3D = $selected
	if selection_sprite == null:
		return
	selection_sprite.render_priority = 10
	var mat:StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_texture = selection_sprite.texture
	selection_sprite.material_override = mat


func selected() -> void:
	$selected.visible = true

func deselect() -> void:
	$selected.visible = false
