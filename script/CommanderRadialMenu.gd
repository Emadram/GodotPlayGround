extends Control
## Full-screen overlay: radial-ish arc of commander ability buttons; toggles with `commander_radial_toggle`.

@export var player_interface_path: NodePath = NodePath("../Player_Interface")

var _dim: ColorRect
var _host: Control


func _ready() -> void:
	visible = false
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.03, 0.06, 0.45)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)
	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)


func toggle() -> void:
	visible = not visible
	mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	if visible:
		_rebuild_slots()
		grab_focus()
	else:
		release_focus()


func _on_dim_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle()


func _rebuild_slots() -> void:
	for c in _host.get_children():
		c.queue_free()
	if AbilityProgression == null:
		return
	var defs: Array[Dictionary] = AbilityProgression.get_ability_definitions()
	var n: int = defs.size()
	if n <= 0:
		return
	var vp := get_viewport_rect().size
	var center := Vector2(vp.x * 0.5, vp.y * 0.72)
	var radius: float = 150.0
	for i in range(n):
		var def: Dictionary = defs[i]
		var id: StringName = def["id"] as StringName
		var label_txt := str(def.get("label", "?"))
		var cp: int = int(def.get("cp_cost", 0))
		var ang: float
		if n == 1:
			ang = -PI * 0.5
		else:
			ang = -PI * 0.82 + PI * 1.64 * (float(i) / float(n - 1))
		var btn := Button.new()
		btn.text = "%s\n%d CP" % [label_txt, cp]
		var sz := Vector2(148.0, 56.0)
		btn.custom_minimum_size = sz
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(func(aid := id):
			_on_radial_ability_pressed(aid)
		)
		_host.add_child(btn)
		btn.position = center + Vector2(cos(ang), sin(ang)) * radius - sz * 0.5


func _on_radial_ability_pressed(ability_id: StringName) -> void:
	var pi := _get_player_interface()
	if pi != null and pi.has_method("begin_commander_ability"):
		pi.begin_commander_ability(ability_id)
	toggle()


func _get_player_interface() -> Node:
	if player_interface_path == NodePath(""):
		return null
	return get_node_or_null(player_interface_path)
