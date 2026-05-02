extends Object
## Registry for JSON `effect` strings on commander abilities. Built-ins live here; extend via `register_ground` / `register_instant`.

static var _ground_custom: Dictionary = {} ## String -> Callable(def, world_pos, team_id)
static var _instant_custom: Dictionary = {} ## String -> Callable(def, team_id)


static func register_ground(effect_name: String, handler: Callable) -> void:
	_ground_custom[effect_name.to_lower()] = handler


static func register_instant(effect_name: String, handler: Callable) -> void:
	_instant_custom[effect_name.to_lower()] = handler


static func _params(def: Dictionary) -> Dictionary:
	var raw: Variant = def.get("params", null)
	if typeof(raw) == TYPE_DICTIONARY:
		return raw as Dictionary
	return {}


static func run_ground(effect: String, def: Dictionary, world_position: Vector3, team_id: int) -> void:
	var key := effect.strip_edges().to_lower()
	if _ground_custom.has(key):
		(_ground_custom[key] as Callable).call(def, world_position, team_id)
		return
	var p := _params(def)
	match key:
		"airstrike":
			var radius: float = float(p.get("radius", 2.5))
			var damage: int = int(p.get("damage", 80))
			if GameManager:
				GameManager.apply_airstrike_damage(world_position, team_id, radius, damage)
		_:
			push_warning("CommanderEffectLibrary: unknown ground effect '%s'" % key)


static func run_instant(effect: String, def: Dictionary, team_id: int) -> void:
	var key := effect.strip_edges().to_lower()
	if _instant_custom.has(key):
		(_instant_custom[key] as Callable).call(def, team_id)
		return
	var p := _params(def)
	match key:
		"supply_drop":
			_grant_resources(int(p.get("amount", 180)))
		"grant_resources":
			_grant_resources(int(p.get("amount", 100)))
		_:
			push_warning("CommanderEffectLibrary: unknown instant effect '%s'" % key)


static func _grant_resources(amount: int) -> void:
	if amount <= 0:
		return
	if GameManager:
		GameManager.add_resources(amount)
