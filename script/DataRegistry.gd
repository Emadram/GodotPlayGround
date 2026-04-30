extends Node

var units: Dictionary = {}
var buildings: Dictionary = {}
var weapons: Dictionary = {}
var armors: Dictionary = {}
var factions: Dictionary = {}
var economies: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	units = _build_dict(_load_resources_from_dir("res://data/units"))
	buildings = _build_dict(_load_resources_from_dir("res://data/buildings"))
	weapons = _build_dict(_load_resources_from_dir("res://data/weapons"))
	armors = _build_dict(_load_resources_from_dir("res://data/armors"))
	factions = _build_dict(_load_resources_from_dir("res://data/factions"))
	economies = _build_dict(_load_resources_from_dir("res://data/economy"))

func get_unit(id: String) -> UnitData:
	return units.get(id, null)

func get_building(id: String) -> BuildingData:
	return buildings.get(id, null)

func get_weapon(id: String) -> WeaponData:
	return weapons.get(id, null)

func get_armor(id: String) -> ArmorData:
	return armors.get(id, null)

func get_faction(id: String) -> FactionData:
	return factions.get(id, null)

func get_economy(id: String) -> EconomyData:
	return economies.get(id, null)

func _load_resources_from_dir(path: String) -> Array[Resource]:
	var results: Array[Resource] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var res_path := path.path_join(file_name)
				var res := ResourceLoader.load(res_path)
				if res != null:
					results.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results

func _build_dict(resources: Array[Resource]) -> Dictionary:
	var map: Dictionary = {}
	for res in resources:
		var id_value = res.get("id")
		if typeof(id_value) == TYPE_STRING and id_value != "":
			map[id_value] = res
	return map
