extends Control
## Tactical minimap: maps world XZ; enemy blips follow gameplay FoW (same rules as world visibility).

@export var player_interface_path: NodePath = NodePath("../Player_Interface")
## Player / UI owner team. Enemy units only draw when `visible` (FoW); other-team buildings only when inside friendly vision.
@export var viewer_team_id: int = 1
## World bounds (XZ) included on the minimap — align with playfield / nav quad (~±38).
@export var world_min_xz: Vector2 = Vector2(-38, -38)
@export var world_max_xz: Vector2 = Vector2(38, 38)
## >1 zooms the minimap toward the map center (smaller world window).
@export_range(0.55, 3.5, 0.05) var zoom_level: float = 1.0

var _player_if_cached: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.06, 0.08, 0.1, 0.92), true)
	draw_rect(r, Color(0.35, 0.55, 0.75, 0.9), false, 2.0)
	var grid_step := 0.25
	var gx := 0.0
	while gx <= 1.001:
		var x := r.position.x + gx * r.size.x
		draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y), Color(0.15, 0.2, 0.26, 0.35), 1.0)
		gx += grid_step
	var gy := 0.0
	while gy <= 1.001:
		var y := r.position.y + gy * r.size.y
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x + r.size.x, y), Color(0.15, 0.2, 0.26, 0.35), 1.0)
		gy += grid_step

	var tree := get_tree()
	if tree == null:
		return
	for b in tree.get_nodes_in_group("buildings"):
		if not is_instance_valid(b) or not b is Node3D:
			continue
		var n3b := b as Node3D
		var bteam := _read_team_id(b)
		if bteam != viewer_team_id:
			if GameManager == null or not GameManager.is_position_revealed_to_team(n3b.global_position, viewer_team_id):
				continue
		_draw_world_blip(n3b.global_position, Color(0.45, 0.75, 1.0, 0.85), _blip_radius(5.0), true)

	for u in tree.get_nodes_in_group("units"):
		if not is_instance_valid(u) or not u is Node3D:
			continue
		var n3 := u as Node3D
		var tid := _read_team_id(u)
		if tid != viewer_team_id:
			if not n3.visible:
				continue
		var col := Color(0.35, 0.95, 0.45, 0.95) if tid == viewer_team_id else Color(0.95, 0.35, 0.35, 0.95)
		var selected := false
		var pi := _get_player_interface()
		if pi != null and pi.has_method("is_node_in_selection"):
			selected = bool(pi.call("is_node_in_selection", u))
		if selected:
			col = Color(1.0, 0.92, 0.35, 1.0)
		var br := _blip_radius(4.0)
		_draw_world_blip(n3.global_position, col, br, false)
		if selected:
			var c := _world_to_minimap(n3.global_position)
			draw_arc(c, br + 3.0, 0.0, TAU, 24, Color(1.0, 0.92, 0.35, 0.75), 2.0, true)

	var cam := _find_rts_camera()
	if cam != null:
		var c := _world_to_minimap(cam.global_position)
		var tri := _camera_triangle_points(c)
		draw_colored_polygon(tri, Color(1.0, 1.0, 1.0, 0.55))


func _find_rts_camera() -> Node3D:
	var pi := _get_player_interface()
	if pi == null:
		return null
	var cam: Node = pi.get("player_camera") as Node
	if cam is Node3D:
		return cam as Node3D
	return null


func _get_player_interface() -> Node:
	if _player_if_cached != null and is_instance_valid(_player_if_cached):
		return _player_if_cached
	if player_interface_path == NodePath(""):
		return null
	_player_if_cached = get_node_or_null(player_interface_path)
	return _player_if_cached


func _read_team_id(node: Node) -> int:
	if "team_id" in node:
		var tv: Variant = node.get("team_id")
		if typeof(tv) == TYPE_INT:
			return int(tv)
	return 0


func _blip_radius(base: float) -> float:
	var m := minf(size.x, size.y)
	return maxf(3.0, base * (m / 200.0))


func _camera_triangle_points(c: Vector2) -> PackedVector2Array:
	var s := _blip_radius(8.0)
	var half := s * 0.75
	return PackedVector2Array([
		c + Vector2(0, -s),
		c + Vector2(-half, half * 0.85),
		c + Vector2(half, half * 0.85)
	])


func _world_to_minimap(world: Vector3) -> Vector2:
	var b: Array = _effective_world_bounds()
	var mn: Vector2 = b[0]
	var mx: Vector2 = b[1]
	var wx := world.x
	var wz := world.z
	var u := inverse_lerp(mn.x, mx.x, wx)
	var v := inverse_lerp(mn.y, mx.y, wz)
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	return Vector2(u * size.x, v * size.y)


func _minimap_to_world_xz(local_pos: Vector2) -> Vector2:
	var b: Array = _effective_world_bounds()
	var mn: Vector2 = b[0]
	var mx: Vector2 = b[1]
	var u := local_pos.x / maxf(size.x, 1.0)
	var v := local_pos.y / maxf(size.y, 1.0)
	var wx := lerpf(mn.x, mx.x, u)
	var wz := lerpf(mn.y, mx.y, v)
	return Vector2(wx, wz)


func _effective_world_bounds() -> Array:
	var ctr := (world_min_xz + world_max_xz) * 0.5
	var half := (world_max_xz - world_min_xz) * 0.5 / maxf(zoom_level, 0.01)
	return [ctr - half, ctr + half]


func _draw_world_blip(world: Vector3, color: Color, radius: float, square: bool) -> void:
	var c := _world_to_minimap(world)
	if square:
		draw_rect(Rect2(c - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), color, true)
	else:
		draw_circle(c, radius, color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_level = clampf(zoom_level + 0.12, 0.55, 3.5)
				accept_event()
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_level = clampf(zoom_level - 0.12, 0.55, 3.5)
				accept_event()
				return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var local := get_local_mouse_position()
			if Rect2(Vector2.ZERO, size).has_point(local):
				var xz := _minimap_to_world_xz(local)
				var pi := _get_player_interface()
				if pi != null and pi.has_method("pan_camera_to_world_xz"):
					pi.call("pan_camera_to_world_xz", xz.x, xz.y)
				accept_event()
