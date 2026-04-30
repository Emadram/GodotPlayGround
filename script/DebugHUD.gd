extends CanvasLayer

@onready var label: Label = $Label

func _ready() -> void:
	_update_text()

func _process(delta: float) -> void:
	_update_text()

func _update_text() -> void:
	if label == null:
		return
	var fps := Engine.get_frames_per_second()
	var unit_count := get_tree().get_nodes_in_group("units").size()
	var resources := GameManager.resources if GameManager else 0
	var power_available := GameManager.power_available if GameManager else 0
	var power_used := GameManager.power_used if GameManager else 0
	var promo_points := GameManager.promotion_points if GameManager else 0
	var promo_level := GameManager.promotion_level if GameManager else 0
	var state_name := GameManager.get_state_name() if GameManager else "UNKNOWN"
	label.text = "FPS: %d\nUnits: %d\nResources: %d\nPower: %d/%d\nPromotions: %d (L%d)\nState: %s" % [fps, unit_count, resources, power_used, power_available, promo_points, promo_level, state_name]
