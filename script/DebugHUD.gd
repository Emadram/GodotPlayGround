extends CanvasLayer

const AbilityCooldownRing := preload("res://script/AbilityCooldownOverlay.gd")
const CommanderRadialMenuScript := preload("res://script/CommanderRadialMenu.gd")

@export var player_interface_path: NodePath = NodePath("../Player_Interface")

@onready var label: Label = $Label
@onready var stop_button: Button = $CommandBar/StopButton
@onready var hold_button: Button = $CommandBar/HoldButton
@onready var attack_move_button: Button = $CommandBar/AttackMoveButton
@onready var guard_button: Button = $CommandBar/GuardButton
@onready var build_button: Button = $CommandBar/BuildButton
@onready var build_power_button: Button = $CommandBar/BuildPowerButton
@onready var build_barracks_button: Button = $CommandBar/BuildBarracksButton
@onready var build_supply_button: Button = $CommandBar/BuildSupplyButton
@onready var train_button: Button = $CommandBar/TrainButton

var production_queue_bar: HBoxContainer
var last_queue_signature: String = ""
var building_bar: VBoxContainer
var last_building_bar_signature: String = ""

var inspect_panel: PanelContainer
var inspect_body: Label
var last_inspect_signature: String = ""

var ability_bar: HBoxContainer
var _ability_slots: Array[Dictionary] = []

var commander_radial: Control

const HUD_STATS_FONT_SIZE: int = 26
const HUD_BUTTON_FONT_SIZE: int = 22
const HUD_BUILDING_FONT_SIZE: int = 22

## Bottom HUD layout (anchors to bottom; |offset_top| > |offset_bottom|).
const HUD_MARGIN_H: float = 20.0
const HUD_BOTTOM_INSET: float = 18.0
const HUD_COMMAND_ROW_HEIGHT: float = 62.0
const HUD_ABILITY_ROW_HEIGHT: float = 66.0
const HUD_BAR_SEPARATION: float = 14.0
const HUD_LABEL_CLEAR_ABOVE_BARS: float = 16.0

func _ready() -> void:
	_ensure_ability_bar()
	_ensure_commander_radial()
	_layout_hud()
	_update_text()
	_connect_buttons()
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_layout_hud()


func _unhandled_input(event: InputEvent) -> void:
	if commander_radial != null and commander_radial.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			commander_radial.toggle()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("commander_radial_toggle"):
		if commander_radial != null and commander_radial.has_method("toggle"):
			commander_radial.toggle()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_ensure_ability_bar()
	_update_command_visibility()
	_update_ability_slots()
	_update_building_bar()
	_update_inspect_panel()
	_update_text()

func _update_text() -> void:
	if label == null:
		return
	var fps := Engine.get_frames_per_second()
	var units := get_tree().get_nodes_in_group("units")
	var unit_count := units.size()
	var nav_recoveries := 0
	var moving_units := 0
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if not unit.has_method("get_navigation_stats"):
			continue
		var stats: Dictionary = unit.get_navigation_stats()
		nav_recoveries += int(stats.get("stuck_recoveries", 0))
		if bool(stats.get("moving", false)):
			moving_units += 1
	var resources := GameManager.resources if GameManager else 0
	var power_available := GameManager.power_available if GameManager else 0
	var power_used := GameManager.power_used if GameManager else 0
	var promo_points := GameManager.promotion_points if GameManager else 0
	var promo_level := GameManager.promotion_level if GameManager else 0
	var state_name := GameManager.get_state_name() if GameManager else "UNKNOWN"
	var production_state := _find_production_state()
	var cp := AbilityProgression.command_points if AbilityProgression else 0
	var low_power := GameManager.is_power_low() if GameManager else false
	var power_note := "\nLOW POWER" if low_power else ""
	label.text = "FPS: %d\nUnits: %d (Moving: %d)\nNav Recoveries: %d\nResources: %d\nPower: %d/%d%s\nPromotions: %d (L%d)\nCP: %d\nState: %s\nProduction: %s" % [fps, unit_count, moving_units, nav_recoveries, resources, power_used, power_available, power_note, promo_points, promo_level, cp, state_name, production_state]

func _find_builder_state_recursive(node: Node) -> String:
	if node == null:
		return "none"
	if node.has_method("get_builder_debug_state"):
		var state: Dictionary = node.get_builder_debug_state()
		return str(state.get("state", "none"))
	for child in node.get_children():
		var child_state := _find_builder_state_recursive(child)
		if child_state != "none":
			return child_state
	return "none"

func _find_production_state() -> String:
	for building in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(building):
			continue
		if not building.has_method("get_production_debug_state"):
			continue
		var state: Dictionary = building.get_production_debug_state()
		if not bool(state.get("completed", false)):
			continue
		return "%s q:%d t:%.1f" % [str(state.get("active", "")), int(state.get("queue_size", 0)), float(state.get("timer", 0.0))]
	return "none"

func _layout_hud() -> void:
	var cmd_top: float = -(HUD_BOTTOM_INSET + HUD_COMMAND_ROW_HEIGHT)
	var abl_bottom: float = cmd_top - HUD_BAR_SEPARATION
	var abl_top: float = abl_bottom - HUD_ABILITY_ROW_HEIGHT
	var label_bottom: float = abl_top - HUD_LABEL_CLEAR_ABOVE_BARS

	if label != null:
		label.anchor_left = 0.0
		label.anchor_right = 1.0
		label.anchor_top = 1.0
		label.anchor_bottom = 1.0
		label.offset_left = HUD_MARGIN_H
		label.offset_right = -HUD_MARGIN_H
		label.offset_top = -360.0
		label.offset_bottom = label_bottom
		label.add_theme_font_size_override("font_size", HUD_STATS_FONT_SIZE)
	if ability_bar != null:
		ability_bar.anchor_left = 0.0
		ability_bar.anchor_right = 1.0
		ability_bar.anchor_top = 1.0
		ability_bar.anchor_bottom = 1.0
		ability_bar.offset_left = HUD_MARGIN_H
		ability_bar.offset_right = -HUD_MARGIN_H
		ability_bar.offset_top = abl_top
		ability_bar.offset_bottom = abl_bottom
		ability_bar.add_theme_constant_override("separation", 14)
		for slot in _ability_slots:
			var abtn: Button = slot.get("button") as Button
			if abtn == null:
				continue
			var slot_root := abtn.get_parent() as Control
			if slot_root != null:
				slot_root.custom_minimum_size = Vector2(120.0, HUD_ABILITY_ROW_HEIGHT)
				slot_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slot_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			abtn.add_theme_font_size_override("font_size", HUD_BUTTON_FONT_SIZE)
			abtn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			abtn.clip_text = false
	var command_bar := get_node_or_null("CommandBar") as HBoxContainer
	if command_bar == null:
		return
	command_bar.anchor_left = 0.0
	command_bar.anchor_right = 1.0
	command_bar.anchor_top = 1.0
	command_bar.anchor_bottom = 1.0
	command_bar.offset_left = HUD_MARGIN_H
	command_bar.offset_right = -HUD_MARGIN_H
	command_bar.offset_top = cmd_top
	command_bar.offset_bottom = -HUD_BOTTOM_INSET
	command_bar.add_theme_constant_override("separation", 12)
	for child in command_bar.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size = Vector2(96.0, HUD_COMMAND_ROW_HEIGHT)
			button.add_theme_font_size_override("font_size", HUD_BUTTON_FONT_SIZE)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.clip_text = false
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _ensure_ability_bar() -> void:
	if AbilityProgression == null:
		return
	var defs: Array[Dictionary] = AbilityProgression.get_ability_definitions()
	var want: int = defs.size()
	if ability_bar == null or not is_instance_valid(ability_bar):
		ability_bar = HBoxContainer.new()
		ability_bar.name = "AbilityBar"
		add_child(ability_bar)
		_ability_slots.clear()
	elif _ability_slots.size() != want:
		for c in ability_bar.get_children():
			c.queue_free()
		_ability_slots.clear()
	else:
		return
	for def in defs:
		var id: StringName = def["id"]
		var slot_root := Control.new()
		slot_root.custom_minimum_size = Vector2(120.0, HUD_ABILITY_ROW_HEIGHT)
		slot_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var btn := Button.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.focus_mode = Control.FOCUS_NONE
		var label_txt: String = str(def.get("label", "Ability"))
		var cp: int = int(def.get("cp_cost", 0))
		btn.text = "%s\n%d CP" % [label_txt, cp]
		btn.add_theme_font_size_override("font_size", HUD_BUTTON_FONT_SIZE)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.clip_text = false
		btn.pressed.connect(func(aid := id):
			_on_ability_slot_pressed(aid)
		)
		var ring := AbilityCooldownRing.new()
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_root.add_child(btn)
		slot_root.add_child(ring)
		ability_bar.add_child(slot_root)
		_ability_slots.append({
			"id": id,
			"button": btn,
			"ring": ring,
		})


func _ensure_commander_radial() -> void:
	if commander_radial != null and is_instance_valid(commander_radial):
		return
	var radial := CommanderRadialMenuScript.new() as Control
	radial.name = "CommanderRadialMenu"
	radial.player_interface_path = player_interface_path
	add_child(radial)
	move_child(radial, get_child_count() - 1)
	commander_radial = radial


func _on_ability_slot_pressed(ability_id: StringName) -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("begin_commander_ability"):
		player_interface.begin_commander_ability(ability_id)


func _update_ability_slots() -> void:
	if AbilityProgression == null or ability_bar == null:
		return
	for slot in _ability_slots:
		var id: StringName = slot["id"]
		var ring: AbilityCooldownRing = slot["ring"] as AbilityCooldownRing
		if ring != null:
			ring.set_remaining_ratio(AbilityProgression.get_cooldown_ratio(id))
		var btn: Button = slot["button"] as Button
		var can_cast: bool = AbilityProgression.can_prepare_cast(id)
		btn.disabled = not can_cast
		btn.tooltip_text = _ability_tooltip(id, can_cast)


func _ability_tooltip(ability_id: StringName, can_cast: bool) -> String:
	if AbilityProgression == null:
		return ""
	var def: Dictionary = AbilityProgression.get_ability_def(ability_id)
	if def.is_empty():
		return ""
	if AbilityProgression.get_cooldown_remaining(ability_id) > 0.05:
		return "Cooldown: %.1fs" % AbilityProgression.get_cooldown_remaining(ability_id)
	if can_cast:
		return str(def.get("label", ""))
	var cost: int = int(def.get("cp_cost", 0))
	if cost > AbilityProgression.command_points:
		return "Need %d CP (have %d)" % [cost, AbilityProgression.command_points]
	var need_lv: int = int(def.get("min_promotion_level", 0))
	if GameManager and GameManager.promotion_level < need_lv:
		return "Requires promotion level %d" % need_lv
	if def.has("unlock_id"):
		var uid: StringName = def["unlock_id"] as StringName
		if uid != &"" and not AbilityProgression.has_unlock(uid):
			return "Locked until mission milestone (e.g. HQ online)"
	return "Unavailable"


func _update_command_visibility() -> void:
	var command_bar := get_node_or_null("CommandBar") as HBoxContainer
	if command_bar == null:
		return
	var has_selection := false
	var has_unit_selection := false
	var has_builder := false
	var has_combat := false
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("get_command_ui_state"):
		var state: Dictionary = player_interface.get_command_ui_state()
		has_selection = bool(state.get("has_selection", false))
		has_unit_selection = bool(state.get("has_unit_selection", false))
		has_builder = bool(state.get("has_builder", false))
		has_combat = bool(state.get("has_combat", false))
	command_bar.visible = has_selection
	if stop_button != null:
		stop_button.visible = has_unit_selection
	if hold_button != null:
		hold_button.visible = has_combat
	if attack_move_button != null:
		attack_move_button.visible = has_combat
	if guard_button != null:
		guard_button.visible = has_combat
	if build_button != null:
		build_button.visible = has_builder
	if build_power_button != null:
		build_power_button.visible = has_builder
	if build_barracks_button != null:
		build_barracks_button.visible = has_builder
	if build_supply_button != null:
		build_supply_button.visible = has_builder
	if train_button != null:
		train_button.visible = false


func _update_building_bar() -> void:
	_ensure_building_bar()
	if building_bar == null:
		return
	var player_interface := _get_player_interface()
	var state: Dictionary = {
		"has_building": false
	}
	if player_interface != null and player_interface.has_method("get_selected_building_bar_state"):
		state = player_interface.get_selected_building_bar_state()
	var has_building := bool(state.get("has_building", false))
	var signature := _get_building_bar_signature(state)
	if signature == last_building_bar_signature:
		building_bar.visible = has_building
		return
	last_building_bar_signature = signature
	for child in building_bar.get_children():
		child.queue_free()
	if not has_building:
		building_bar.visible = false
		return
	var title := Label.new()
	title.text = str(state.get("building_label", "Building"))
	if bool(state.get("power_low", false)):
		title.text += " — LOW POWER"
	title.add_theme_font_size_override("font_size", HUD_BUILDING_FONT_SIZE)
	building_bar.add_child(title)
	var power_low := bool(state.get("power_low", false))
	var items: Array = state.get("queue_items", [])
	var max_queue := int(state.get("max_queue", 0))
	var train_options: Array = state.get("train_options", [])
	for option in train_options:
		var production_option: Dictionary = option as Dictionary
		var train := Button.new()
		var train_label := str(production_option.get("label", "Unit"))
		var unit_id := str(production_option.get("unit_id", ""))
		var cp_train: int = int(production_option.get("cp_cost", 0))
		var cp_suffix := "  [%d CP]" % cp_train if cp_train > 0 else ""
		if max_queue > 0:
			train.text = "%s%s (%d/%d)" % [train_label, cp_suffix, items.size(), max_queue]
		else:
			train.text = "%s%s" % [train_label, cp_suffix]
		train.custom_minimum_size = Vector2(200.0, 52.0)
		train.add_theme_font_size_override("font_size", HUD_BUTTON_FONT_SIZE)
		train.pressed.connect(func(id := unit_id):
			_queue_selected_production(id)
		)
		train.disabled = power_low
		building_bar.add_child(train)
	if not items.is_empty():
		var queue_title := Label.new()
		queue_title.text = "Training (%d/%d)" % [items.size(), max_queue] if max_queue > 0 else "Training"
		queue_title.add_theme_font_size_override("font_size", HUD_BUILDING_FONT_SIZE)
		building_bar.add_child(queue_title)
	for i in range(items.size()):
		var item: Dictionary = items[i] as Dictionary
		var row := HBoxContainer.new()
		var label := str(item.get("label", "Unit"))
		if bool(item.get("active", false)):
			label = "%s %.1fs" % [label, float(item.get("timer", 0.0))]
			if bool(item.get("paused_by_power", false)):
				label += " (power)"
		var qcp: int = int(item.get("cp_cost", 0))
		if qcp > 0:
			label = "%s [%d CP]" % [label, qcp]
		var item_label := Label.new()
		item_label.text = label
		item_label.custom_minimum_size = Vector2(160.0, 44.0)
		item_label.add_theme_font_size_override("font_size", HUD_BUILDING_FONT_SIZE)
		row.add_child(item_label)
		var cancel := Button.new()
		cancel.text = "X"
		cancel.custom_minimum_size = Vector2(44.0, 44.0)
		cancel.add_theme_font_size_override("font_size", HUD_BUTTON_FONT_SIZE)
		cancel.pressed.connect(func(index := i):
			_cancel_production_item(index)
		)
		row.add_child(cancel)
		building_bar.add_child(row)
	building_bar.visible = true


func _ensure_building_bar() -> void:
	if building_bar != null and is_instance_valid(building_bar):
		return
	building_bar = VBoxContainer.new()
	building_bar.name = "BuildingBar"
	add_child(building_bar)
	building_bar.anchor_left = 1.0
	building_bar.anchor_right = 1.0
	building_bar.anchor_top = 0.0
	building_bar.anchor_bottom = 0.0
	building_bar.offset_left = -280.0
	building_bar.offset_top = 308.0
	building_bar.offset_right = -12.0
	building_bar.offset_bottom = 440.0
	building_bar.add_theme_constant_override("separation", 10)
	building_bar.visible = false


func _get_building_bar_signature(state: Dictionary) -> String:
	if not bool(state.get("has_building", false)):
		return "none"
	var parts: Array[String] = []
	parts.append(str(state.get("building_id", "")))
	parts.append(str(state.get("max_queue", 0)))
	parts.append("pl:%s" % str(state.get("power_low", false)))
	var options: Array = state.get("train_options", [])
	for option in options:
		var production_option: Dictionary = option as Dictionary
		parts.append("%s:%s:%d" % [str(production_option.get("unit_id", "")), str(production_option.get("label", "")), int(production_option.get("cp_cost", 0))])
	var items: Array = state.get("queue_items", [])
	for item in items:
		parts.append("%s:%s:%.1f:%d:%s" % [str(item.get("label", "")), str(item.get("active", false)), float(item.get("timer", 0.0)), int(item.get("cp_cost", 0)), str(item.get("paused_by_power", false))])
	return "|".join(parts)


func _queue_selected_production(unit_id: String = "") -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("queue_selected_production_unit"):
		player_interface.queue_selected_production_unit(unit_id)
	last_building_bar_signature = ""


func _cancel_production_item(index: int) -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("cancel_selected_production_at"):
		player_interface.cancel_selected_production_at(index)
	last_building_bar_signature = ""


func _ensure_inspect_panel() -> void:
	if inspect_panel != null and is_instance_valid(inspect_panel):
		return
	inspect_panel = PanelContainer.new()
	inspect_panel.name = "InspectPanel"
	inspect_panel.visible = false
	inspect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_body = Label.new()
	inspect_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_body.custom_minimum_size = Vector2(300.0, 80.0)
	inspect_body.add_theme_font_size_override("font_size", maxi(HUD_BUILDING_FONT_SIZE - 2, 14))
	inspect_panel.add_child(inspect_body)
	add_child(inspect_panel)
	inspect_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	inspect_panel.offset_left = 12.0
	inspect_panel.offset_top = 12.0
	inspect_panel.offset_right = 340.0
	inspect_panel.offset_bottom = 260.0


func _update_inspect_panel() -> void:
	_ensure_inspect_panel()
	var player_interface := _get_player_interface()
	if player_interface == null or not player_interface.has_method("get_inspect_panel_state"):
		inspect_panel.visible = false
		return
	var st: Dictionary = player_interface.get_inspect_panel_state()
	if not bool(st.get("visible", false)):
		inspect_panel.visible = false
		return
	var sig := str(st.get("signature", ""))
	if sig != last_inspect_signature:
		last_inspect_signature = sig
		var title := str(st.get("title", "Inspect"))
		var body := str(st.get("text", ""))
		inspect_body.text = "%s\n%s" % [title, body]
	inspect_panel.visible = true


func _connect_buttons() -> void:
	if stop_button != null:
		stop_button.pressed.connect(_on_stop_pressed)
	if hold_button != null:
		hold_button.pressed.connect(_on_hold_pressed)
	if attack_move_button != null:
		attack_move_button.pressed.connect(_on_attack_move_pressed)
	if guard_button != null:
		guard_button.pressed.connect(_on_guard_pressed)
	if build_button != null:
		build_button.pressed.connect(_on_build_pressed)
	if build_power_button != null:
		build_power_button.pressed.connect(_on_build_power_pressed)
	if build_barracks_button != null:
		build_barracks_button.pressed.connect(_on_build_barracks_pressed)
	if build_supply_button != null:
		build_supply_button.pressed.connect(_on_build_supply_pressed)
	if train_button != null:
		train_button.pressed.connect(_on_train_pressed)

func _get_player_interface() -> Node:
	if player_interface_path == NodePath(""):
		return null
	return get_node_or_null(player_interface_path)

func _on_stop_pressed() -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("issue_stop_command"):
		player_interface.issue_stop_command()

func _on_hold_pressed() -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("issue_hold_command"):
		player_interface.issue_hold_command()

func _on_attack_move_pressed() -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("set_attack_move_mode"):
		player_interface.set_attack_move_mode()

func _on_guard_pressed() -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("set_guard_mode"):
		player_interface.set_guard_mode()

func _on_build_pressed() -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("set_build_mode"):
		player_interface.set_build_mode("usa_command_center")

func _on_build_power_pressed() -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("set_build_mode"):
		player_interface.set_build_mode("usa_power_plant")

func _on_build_barracks_pressed() -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("set_build_mode"):
		player_interface.set_build_mode("usa_barracks")

func _on_build_supply_pressed() -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("set_build_mode"):
		player_interface.set_build_mode("usa_supply_depot")

func _on_train_pressed() -> void:
	var player_interface := _get_player_interface()
	if player_interface != null and player_interface.has_method("queue_selected_production_unit"):
		player_interface.queue_selected_production_unit()
