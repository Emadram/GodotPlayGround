extends NavigationRegion3D
## Ensures a valid NavigationMesh exists. Editor bake was empty; geometry-based bake was unreliable here,
## so we define a large flat walkable quad (XZ) covering the ground plane, dock, and dropoff.

func _ready() -> void:
	call_deferred("_deferred_build_navigation_mesh")


func _deferred_build_navigation_mesh() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.65
	nm.agent_height = 2.2
	nm.agent_max_climb = 0.75
	nm.cell_size = 0.4
	nm.cell_height = 0.25
	# Slightly larger than the 60x60 ground plane; covers dock (~-10) and truck spawn.
	var half: float = 38.0
	var y: float = 0.02
	var verts := PackedVector3Array([
		Vector3(-half, y, -half),
		Vector3(half, y, -half),
		Vector3(half, y, half),
		Vector3(-half, y, half),
	])
	nm.set_vertices(verts)
	nm.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation_mesh = nm
	print("[WorldNavigation] navigation_mesh polygons=%s (manual quad)" % nm.get_polygon_count())
