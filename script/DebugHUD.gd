extends CanvasLayer

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

func _ready() -> void:
	_layout_hud()
	_update_text()
	_connect_buttons()

func _process(_delta: float) -> void:
	_update_command_visibility()
	_update_building_bar()
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
	label.text = "FPS: %d\nUnits: %d (Moving: %d)\nNav Recoveries: %d\nResources: %d\nPower: %d/%d\nPromotions: %d (L%d)\nState: %s\nProduction: %s" % [fps, unit_count, moving_units, nav_recoveries, resources, power_used, power_available, promo_points, promo_level, state_name, production_state]

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
	if label != null:
		label.anchor_left = 0.0
		label.anchor_right = 0.0
		label.anchor_top = 1.0
		label.anchor_bottom = 1.0
		label.offset_left = 12.0
		label.offset_top = -250.0
		label.offset_right = 760.0
		label.offset_bottom = -72.0
	var command_bar := get_node_or_null("CommandBar") as HBoxContainer
	if command_bar == null:
		return
	command_bar.anchor_left = 0.0
	command_bar.anchor_right = 0.0
	command_bar.anchor_top = 1.0
	command_bar.anchor_bottom = 1.0
	command_bar.offset_left = 12.0
	command_bar.offset_top = -58.0
	command_bar.offset_right = 720.0
	command_bar.offset_bottom = -12.0
	command_bar.add_theme_constant_override("separation", 8)
	for child in command_bar.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size = Vector2(120.0, 44.0)

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
	building_bar.add_child(title)
	var items: Array = state.get("queue_items", [])
	var max_queue := int(state.get("max_queue", 0))
	var train_options: Array = state.get("train_options", [])
	for option in train_options:
		var production_option: Dictionary = option as Dictionary
		var train := Button.new()
		var train_label := str(production_option.get("label", "Unit"))
		var unit_id := str(production_option.get("unit_id", ""))
		train.text = "%s (%d/%d)" % [train_label, items.size(), max_queue] if max_queue > 0 else train_label
		train.custom_minimum_size = Vector2(160.0, 40.0)
		train.pressed.connect(func(id := unit_id):
			_queue_selected_production(id)
		)
		building_bar.add_child(train)
	if not items.is_empty():
		var queue_title := Label.new()
		queue_title.text = "Training (%d/%d)" % [items.size(), max_queue] if max_queue > 0 else "Training"
		building_bar.add_child(queue_title)
	for i in range(items.size()):
		var item: Dictionary = items[i] as Dictionary
		var row := HBoxContainer.new()
		var label := str(item.get("label", "Unit"))
		if bool(item.get("active", false)):
			label = "%s %.1fs" % [label, float(item.get("timer", 0.0))]
		var item_label := Label.new()
		item_label.text = label
		item_label.custom_minimum_size = Vector2(120.0, 32.0)
		row.add_child(item_label)
		var cancel := Button.new()
		cancel.text = "X"
		cancel.custom_minimum_size = Vector2(36.0, 32.0)
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
	building_bar.offset_left = -190.0
	building_bar.offset_top = 90.0
	building_bar.offset_right = -12.0
	building_bar.offset_bottom = 420.0
	building_bar.add_theme_constant_override("separation", 8)
	building_bar.visible = false


func _get_building_bar_signature(state: Dictionary) -> String:
	if not bool(state.get("has_building", false)):
		return "none"
	var parts: Array[String] = []
	parts.append(str(state.get("building_id", "")))
	parts.append(str(state.get("max_queue", 0)))
	var options: Array = state.get("train_options", [])
	for option in options:
		var production_option: Dictionary = option as Dictionary
		parts.append("%s:%s" % [str(production_option.get("unit_id", "")), str(production_option.get("label", ""))])
	var items: Array = state.get("queue_items", [])
	for item in items:
		parts.append("%s:%s:%.1f" % [str(item.get("label", "")), str(item.get("active", false)), float(item.get("timer", 0.0))])
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
