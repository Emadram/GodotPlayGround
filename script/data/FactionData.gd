extends Resource
class_name FactionData

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color(1, 1, 1, 1)
@export var starting_cash: int = 10000
@export var starting_power: int = 0
@export var economy_id: String = ""
@export var starting_units: Array[String] = []
@export var starting_buildings: Array[String] = []
