extends Node
## Simple skirmish AI: periodically issue attack-move for team-2 combat units toward the friendly force centroid.

const CMD_ATTACK_MOVE := 2

@export var enemy_team_id: int = 2
@export var player_team_id: int = 1
@export var order_interval: float = 14.0

var _cooldown: float = 0.0


func _process(delta: float) -> void:
	if GameManager == null or GameManager.state != GameManager.GameState.RUNNING:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = order_interval
	_issue_enemy_attack_move()


func _issue_enemy_attack_move() -> void:
	var target := _average_team_position(player_team_id)
	if target.length_squared() < 0.0001:
		target = Vector3(-6.0, 0.0, -4.0)
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u):
			continue
		var tv: Variant = u.get("team_id")
		if typeof(tv) != TYPE_INT or int(tv) != enemy_team_id:
			continue
		if not u.has_method("issue_command"):
			continue
		u.issue_command({
			"type": CMD_ATTACK_MOVE,
			"position": target,
			"target": null
		}, false)


func _average_team_position(team: int) -> Vector3:
	var sum := Vector3.ZERO
	var c := 0
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not u is Node3D:
			continue
		var tv: Variant = u.get("team_id")
		if typeof(tv) != TYPE_INT or int(tv) != team:
			continue
		sum += (u as Node3D).global_position
		c += 1
	if c == 0:
		return Vector3.ZERO
	return sum / float(c)
