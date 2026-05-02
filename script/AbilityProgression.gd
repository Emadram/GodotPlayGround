extends Node
## Commander abilities (JSON override + defaults), CP spend, cooldowns, unlock hooks.

const CommanderEffectLibrary := preload("res://script/CommanderEffectLibrary.gd")

signal command_points_changed(current: int)
signal unlock_changed(unlock_id: StringName, unlocked: bool)
signal ability_cast(ability_id: StringName, world_position: Vector3)
signal ability_state_changed(ability_id: StringName)

const TARGET_NONE := 0
const TARGET_GROUND := 1

const COMMANDER_ABILITIES_JSON := "res://data/commander_abilities.json"

## Legacy ids (used if JSON omits "effect").
const ABILITY_AIRSTRIKE := &"cmd_airstrike"
const ABILITY_SUPPLY_DROP := &"cmd_supply_drop"

var command_points: int = 0
var _unlocks: Dictionary = {} # StringName -> bool
var _last_seen_promo_level: int = 0

var _ability_defs: Array[Dictionary] = []
var _def_by_id: Dictionary = {} # StringName -> Dictionary
var _cooldown_remaining: Dictionary = {} # StringName -> float


func _ready() -> void:
	_register_default_abilities()
	_try_load_commander_abilities_json()
	set_process(true)
	if GameManager:
		_last_seen_promo_level = GameManager.promotion_level
		GameManager.promotions_changed.connect(_on_promotions_changed)


func _process(delta: float) -> void:
	var any_changed := false
	for id in _cooldown_remaining.keys():
		var left: float = float(_cooldown_remaining[id])
		if left <= 0.0:
			continue
		left = maxf(0.0, left - delta)
		_cooldown_remaining[id] = left
		any_changed = true
		if left <= 0.0:
			ability_state_changed.emit(id)
	if any_changed:
		_emit_global_refresh()


func _emit_global_refresh() -> void:
	ability_state_changed.emit(&"")


func reset_for_match() -> void:
	_cooldown_remaining.clear()
	if GameManager:
		_last_seen_promo_level = GameManager.promotion_level
	else:
		_last_seen_promo_level = 0
	set_command_points(0)


func _register_default_abilities() -> void:
	_ability_defs.clear()
	_def_by_id.clear()
	_add_ability({
		"id": ABILITY_AIRSTRIKE,
		"label": "Airstrike",
		"effect": "airstrike",
		"cp_cost": 1,
		"cooldown": 20.0,
		"targeting": TARGET_GROUND,
		"min_promotion_level": 1,
	})
	_add_ability({
		"id": ABILITY_SUPPLY_DROP,
		"label": "Supply Drop",
		"effect": "supply_drop",
		"params": {"amount": 180},
		"cp_cost": 2,
		"cooldown": 35.0,
		"targeting": TARGET_NONE,
		"min_promotion_level": 0,
	})


func _try_load_commander_abilities_json() -> void:
	if not FileAccess.file_exists(COMMANDER_ABILITIES_JSON):
		return
	var text := FileAccess.get_file_as_string(COMMANDER_ABILITIES_JSON)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		push_warning("AbilityProgression: commander_abilities.json is not a JSON array, using defaults.")
		return
	var arr: Array = parsed
	if arr.is_empty():
		return
	var next_defs: Array[Dictionary] = []
	var next_by_id: Dictionary = {}
	for raw in arr:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = raw as Dictionary
		var id_str := str(d.get("id", "")).strip_edges()
		if id_str == "":
			continue
		var idsn := StringName(id_str)
		var targeting := str(d.get("targeting", "none")).to_lower()
		var tt := TARGET_NONE
		if targeting == "ground" or targeting == "world":
			tt = TARGET_GROUND
		var def := {
			"id": idsn,
			"label": str(d.get("label", id_str)),
			"effect": str(d.get("effect", "")),
			"cp_cost": int(d.get("cp_cost", 0)),
			"cooldown": float(d.get("cooldown", 0.0)),
			"targeting": tt,
			"min_promotion_level": int(d.get("min_promotion_level", 0)),
		}
		var prm: Variant = d.get("params", null)
		if typeof(prm) == TYPE_DICTIONARY:
			def["params"] = prm
		var uid := str(d.get("unlock_id", "")).strip_edges()
		if uid != "":
			def["unlock_id"] = StringName(uid)
		next_by_id[idsn] = def
		next_defs.append(def)
	if next_defs.is_empty():
		return
	_ability_defs = next_defs
	_def_by_id = next_by_id


func _add_ability(def: Dictionary) -> void:
	var id: StringName = def["id"]
	_def_by_id[id] = def
	_ability_defs.append(def)


func get_ability_definitions() -> Array[Dictionary]:
	return _ability_defs.duplicate()


func get_ability_id_at_hud_index(index: int) -> StringName:
	if index < 0 or index >= _ability_defs.size():
		return &""
	return _ability_defs[index]["id"] as StringName


func get_ability_def(ability_id: StringName) -> Dictionary:
	return _def_by_id.get(ability_id, {}) as Dictionary


func get_cooldown_remaining(ability_id: StringName) -> float:
	return maxf(0.0, float(_cooldown_remaining.get(ability_id, 0.0)))


func get_cooldown_ratio(ability_id: StringName) -> float:
	var def: Dictionary = get_ability_def(ability_id)
	if def.is_empty():
		return 0.0
	var total: float = float(def.get("cooldown", 1.0))
	if total <= 0.001:
		return 0.0
	return clampf(get_cooldown_remaining(ability_id) / total, 0.0, 1.0)


func _meets_promotion(def: Dictionary) -> bool:
	var need: int = int(def.get("min_promotion_level", 0))
	if GameManager == null:
		return need <= 0
	return GameManager.promotion_level >= need


func can_prepare_cast(ability_id: StringName) -> bool:
	var def: Dictionary = get_ability_def(ability_id)
	if def.is_empty():
		return false
	if not _meets_promotion(def):
		return false
	if get_cooldown_remaining(ability_id) > 0.0:
		return false
	var cost: int = int(def.get("cp_cost", 0))
	if cost > 0 and command_points < cost:
		return false
	if def.has("unlock_id"):
		var uid: StringName = def["unlock_id"] as StringName
		if uid != &"" and not has_unlock(uid):
			return false
	return true


func try_cast_ground(ability_id: StringName, world_position: Vector3, team_id: int) -> bool:
	var def: Dictionary = get_ability_def(ability_id)
	if def.is_empty():
		return false
	if int(def.get("targeting", TARGET_NONE)) != TARGET_GROUND:
		return false
	if not can_prepare_cast(ability_id):
		return false
	var cost: int = int(def.get("cp_cost", 0))
	if not try_spend_command_points(cost):
		return false
	var cd: float = float(def.get("cooldown", 0.0))
	if cd > 0.0:
		_cooldown_remaining[ability_id] = cd
	_run_ground_effect(def, world_position, team_id)
	ability_cast.emit(ability_id, world_position)
	ability_state_changed.emit(ability_id)
	return true


func try_cast_instant(ability_id: StringName, team_id: int) -> bool:
	var def: Dictionary = get_ability_def(ability_id)
	if def.is_empty():
		return false
	if int(def.get("targeting", TARGET_NONE)) != TARGET_NONE:
		return false
	if not can_prepare_cast(ability_id):
		return false
	var cost: int = int(def.get("cp_cost", 0))
	if not try_spend_command_points(cost):
		return false
	var cd: float = float(def.get("cooldown", 0.0))
	if cd > 0.0:
		_cooldown_remaining[ability_id] = cd
	_run_instant_effect(def, team_id)
	ability_cast.emit(ability_id, Vector3.ZERO)
	ability_state_changed.emit(ability_id)
	return true


func _effect_name(def: Dictionary) -> String:
	var e := str(def.get("effect", "")).strip_edges()
	if e != "":
		return e.to_lower()
	var id: StringName = def.get("id", &"") as StringName
	if id == ABILITY_AIRSTRIKE:
		return "airstrike"
	if id == ABILITY_SUPPLY_DROP:
		return "supply_drop"
	return ""


func _run_ground_effect(def: Dictionary, world_position: Vector3, team_id: int) -> void:
	CommanderEffectLibrary.run_ground(_effect_name(def), def, world_position, team_id)


func _run_instant_effect(def: Dictionary, team_id: int) -> void:
	CommanderEffectLibrary.run_instant(_effect_name(def), def, team_id)


func notify_structure_completed(structure_building_id: String) -> void:
	match structure_building_id:
		"usa_command_center":
			set_unlock(&"usa_hq_complete", true)
		"usa_barracks":
			set_unlock(&"usa_barracks_online", true)
		_:
			pass


func _on_promotions_changed(_points: int, level: int) -> void:
	if level > _last_seen_promo_level:
		add_command_points(level - _last_seen_promo_level)
		_last_seen_promo_level = level


func set_command_points(value: int) -> void:
	command_points = maxi(0, value)
	command_points_changed.emit(command_points)
	_emit_global_refresh()


func add_command_points(amount: int) -> void:
	if amount <= 0:
		return
	set_command_points(command_points + amount)


func try_spend_command_points(amount: int) -> bool:
	if amount <= 0:
		return true
	if command_points < amount:
		return false
	set_command_points(command_points - amount)
	return true


func set_unlock(unlock_id: StringName, unlocked: bool) -> void:
	_unlocks[unlock_id] = unlocked
	unlock_changed.emit(unlock_id, unlocked)
	_emit_global_refresh()


func has_unlock(unlock_id: StringName) -> bool:
	return bool(_unlocks.get(unlock_id, false))
