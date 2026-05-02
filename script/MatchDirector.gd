extends Node
## Skirmish end conditions: eliminate enemy combat units to win; lose all friendly combat while enemies remain.

@export var player_team_id: int = 1
@export var enemy_team_id: int = 2

var _had_enemy_combat: bool = false
var _player_had_combat: bool = false
var _overlay_layer: CanvasLayer
var _banner: Label
var _restart: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	if GameManager and not GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.VICTORY:
		_show_overlay(true)
	elif new_state == GameManager.GameState.DEFEAT:
		_show_overlay(false)


func _process(_delta: float) -> void:
	if GameManager == null:
		return
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	var e_cnt := _count_combat_units(enemy_team_id)
	if e_cnt > 0:
		_had_enemy_combat = true
	var p_cnt := _count_combat_units(player_team_id)
	if p_cnt > 0:
		_player_had_combat = true
	if _had_enemy_combat and e_cnt == 0:
		GameManager.end_match(true)
	elif _player_had_combat and p_cnt == 0 and e_cnt > 0:
		GameManager.end_match(false)


func _count_combat_units(team: int) -> int:
	var n := 0
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u):
			continue
		var tv: Variant = u.get("team_id")
		if typeof(tv) != TYPE_INT or int(tv) != team:
			continue
		if u.has_method("can_attack") and bool(u.call("can_attack")):
			if _is_unit_dead_for_match(u):
				continue
			n += 1
	return n


# Corpses stay in `units` until death animation timer calls `queue_free` — exclude them so victory fires when HP hits 0.
func _is_unit_dead_for_match(u: Node) -> bool:
	if "is_dead" in u and bool(u.get("is_dead")):
		return true
	if "current_health" in u:
		var ch: Variant = u.get("current_health")
		if typeof(ch) == TYPE_INT and int(ch) <= 0:
			return true
		if typeof(ch) == TYPE_FLOAT and float(ch) <= 0.0:
			return true
	if u.has_method("get_health_ratio"):
		var hr: float = float(u.call("get_health_ratio"))
		if hr <= 0.0001:
			return true
	return false


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 110
	_overlay_layer.visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var ctr := CenterContainer.new()
	ctr.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ctr)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	ctr.add_child(vb)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 38)
	vb.add_child(_banner)
	_restart = Button.new()
	_restart.text = "Restart mission"
	_restart.custom_minimum_size = Vector2(240.0, 52.0)
	_restart.pressed.connect(_on_restart_pressed)
	vb.add_child(_restart)
	add_child(_overlay_layer)


func _show_overlay(victory: bool) -> void:
	if _overlay_layer == null:
		return
	_banner.text = "Victory" if victory else "Defeat"
	_overlay_layer.visible = true


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
