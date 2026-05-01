extends Resource
class_name BuildingData

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var building_scene: PackedScene
@export var cost: int = 0
@export var build_time: float = 0.0
@export var max_health: int = 1000
@export var power_provided: int = 0
@export var power_consumed: int = 0
@export var footprint: Vector2 = Vector2.ONE
# Used by ConstructionSite.get_vision_range() for FoW overlay and enemy reveal (same units as friendly vision).
@export var sight_range: float = 12.0
@export var faction_id: String = ""
@export var produces_units: Array[String] = []
