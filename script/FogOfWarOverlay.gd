extends MeshInstance3D

## Terrain fog-of-war: darkens ground outside friendly sight radii.

const MAX_SOURCES := 32

@export var friendly_team_id: int = 1
@export var fog_color: Color = Color(0.012, 0.018, 0.042, 0.84)
@export var edge_softness: float = 0.14

var _shader: Shader = preload("res://shader/fog_of_war_overlay.gdshader")
var _material: ShaderMaterial
var _vision_buf: PackedVector4Array = PackedVector4Array()


func _ready() -> void:
	_vision_buf.resize(MAX_SOURCES)
	_material = ShaderMaterial.new()
	_material.shader = _shader
	material_override = _material
	_apply_static_params()


func _process(_delta: float) -> void:
	var n_sources: int = _fill_vision_buffer()
	_material.set_shader_parameter("vision_packed", _vision_buf)
	_material.set_shader_parameter("vision_count", n_sources)


func _apply_static_params() -> void:
	_material.set_shader_parameter("fog_color", fog_color)
	_material.set_shader_parameter("edge_softness", edge_softness)


# Packs up to MAX_SOURCES vision circles: friendly units first, then buildings (same team filter as GameManager FoW).
func _fill_vision_buffer() -> int:
	var i: int = 0
	for node in get_tree().get_nodes_in_group("units"):
		if i >= MAX_SOURCES:
			break
		if not is_instance_valid(node) or not node is Node3D:
			continue
		var oid: Variant = node.get("team_id")
		if typeof(oid) != TYPE_INT or int(oid) != friendly_team_id:
			continue
		if typeof(node.get("is_dead")) == TYPE_BOOL and bool(node.get("is_dead")):
			continue
		i = _push_vision_entry(i, node as Node3D)
	for node in get_tree().get_nodes_in_group("buildings"):
		if i >= MAX_SOURCES:
			break
		if not is_instance_valid(node) or not node is Node3D:
			continue
		var bteam: Variant = node.get("team_id")
		if typeof(bteam) != TYPE_INT or int(bteam) != friendly_team_id:
			continue
		if typeof(node.get("is_ghost")) == TYPE_BOOL and bool(node.get("is_ghost")):
			continue
		i = _push_vision_entry(i, node as Node3D)
	for k in range(i, MAX_SOURCES):
		_vision_buf[k] = Vector4.ZERO
	return i


func _push_vision_entry(index: int, source: Node3D) -> int:
	var rng: float = 12.0
	if source.has_method("get_vision_range"):
		rng = float(source.call(&"get_vision_range"))
	var p: Vector3 = source.global_position
	_vision_buf[index] = Vector4(p.x, p.z, rng, 0.0)
	return index + 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_apply_static_params()
