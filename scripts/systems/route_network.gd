extends Node3D

const PLAYER_START_FROM := "outer_0_s"
const PLAYER_START_TO := "outer_0_se"
const PLAYER_START_PROGRESS := 2.0

@export var outer_radius: float = 8.0
@export var inner_radius: float = 4.0
@export var layer_center_base: float = 2.0
@export var layer_spacing: float = 10.0
@export var layer_count: int = 3
@export var corridor_width: float = 4.0
@export var corridor_height: float = 4.0
@export var wall_thickness: float = 0.9
@export var junction_clearance: float = 1.6
@export var minimap_pipe_radius: float = 1.35

var junction_positions: Dictionary = {}
var adjacency: Dictionary = {}
var segment_pairs: Array = []
var edge_lookup: Dictionary = {}
var geometry_root: Node3D
var minimap_geometry_root: Node3D
var materials: Dictionary = {}

func _ready() -> void:
	add_to_group("route_network")
	_create_materials()
	rebuild()

func rebuild() -> void:
	_clear_graph()
	_build_graph()
	_rebuild_geometry()

func get_player_start_edge() -> Dictionary:
	return {
		"from": PLAYER_START_FROM,
		"to": PLAYER_START_TO,
		"progress": PLAYER_START_PROGRESS
	}

func get_junction_position(id: String) -> Vector3:
	return junction_positions.get(id, Vector3.ZERO)

func get_neighbors(id: String) -> Array:
	if adjacency.has(id):
		return adjacency[id].duplicate()
	return []

func get_segment_length(from_id: String, to_id: String) -> float:
	return get_junction_position(from_id).distance_to(get_junction_position(to_id))

func get_direction(from_id: String, to_id: String) -> Vector3:
	return (get_junction_position(to_id) - get_junction_position(from_id)).normalized()

func get_segment_pairs() -> Array:
	return segment_pairs.duplicate(true)

func get_corridor_half_width() -> float:
	return corridor_width * 0.5

func get_corridor_half_height() -> float:
	return corridor_height * 0.5

func get_bubble_positions() -> Array:
	var positions: Array = []
	for segment in segment_pairs:
		var start: Vector3 = get_junction_position(segment[0])
		var end: Vector3 = get_junction_position(segment[1])
		var bubble_count := 2 if absf(end.y - start.y) > 0.1 else int(max(1.0, roundf(start.distance_to(end) / 10.0)))
		for index in range(bubble_count):
			var t := float(index + 1) / float(bubble_count + 1)
			positions.append(start.lerp(end, t))
	return positions

func pick_neighbor_by_preferences(previous_id: String, current_id: String, preferred_directions: Array) -> String:
	for preferred_direction in preferred_directions:
		if preferred_direction is Vector3:
			var candidate := _pick_neighbor_in_direction(previous_id, current_id, preferred_direction)
			if candidate != "":
				return candidate
	return pick_random_neighbor(previous_id, current_id)

func pick_random_neighbor(previous_id: String, current_id: String) -> String:
	var candidates: Array = []
	for neighbor in get_neighbors(current_id):
		if neighbor != previous_id:
			candidates.append(neighbor)
	if candidates.is_empty():
		return previous_id
	return candidates[randi() % candidates.size()]

func pick_neighbor_toward_target(previous_id: String, current_id: String, target_position: Vector3) -> String:
	var current_position := get_junction_position(current_id)
	var target_direction := (target_position - current_position).normalized()
	var candidate := _pick_neighbor_in_direction(previous_id, current_id, target_direction)
	if candidate != "":
		return candidate
	return pick_random_neighbor(previous_id, current_id)

func _clear_graph() -> void:
	junction_positions.clear()
	adjacency.clear()
	segment_pairs.clear()
	edge_lookup.clear()
	if geometry_root != null and is_instance_valid(geometry_root):
		remove_child(geometry_root)
		geometry_root.queue_free()
	if minimap_geometry_root != null and is_instance_valid(minimap_geometry_root):
		remove_child(minimap_geometry_root)
		minimap_geometry_root.queue_free()
	geometry_root = Node3D.new()
	geometry_root.name = "GeneratedGeometry"
	add_child(geometry_root)
	minimap_geometry_root = Node3D.new()
	minimap_geometry_root.name = "GeneratedMiniMapGeometry"
	add_child(minimap_geometry_root)

func _build_graph() -> void:
	for layer in range(layer_count):
		var center_y := layer_center_base + float(layer) * layer_spacing
		_build_ring("outer", layer, outer_radius, center_y)
		_build_ring("inner", layer, inner_radius, center_y)

		var center_id := _center_id(layer)
		_add_junction(center_id, Vector3(0.0, center_y, 0.0))
		for suffix in ["n", "e", "s", "w"]:
			_connect(_node_id("outer", layer, suffix), _node_id("inner", layer, suffix))
			_connect(_node_id("inner", layer, suffix), center_id)

	for layer in range(layer_count - 1):
		for ring in ["outer", "inner"]:
			for suffix in ["nw", "n", "ne", "e", "se", "s", "sw", "w"]:
				_connect(_node_id(ring, layer, suffix), _node_id(ring, layer + 1, suffix))
		_connect(_center_id(layer), _center_id(layer + 1))

func _build_ring(ring: String, layer: int, radius: float, y: float) -> void:
	var ids := {
		"nw": Vector3(-radius, y, -radius),
		"n": Vector3(0.0, y, -radius),
		"ne": Vector3(radius, y, -radius),
		"e": Vector3(radius, y, 0.0),
		"se": Vector3(radius, y, radius),
		"s": Vector3(0.0, y, radius),
		"sw": Vector3(-radius, y, radius),
		"w": Vector3(-radius, y, 0.0)
	}
	for suffix in ids.keys():
		_add_junction(_node_id(ring, layer, suffix), ids[suffix])

	_connect(_node_id(ring, layer, "nw"), _node_id(ring, layer, "n"))
	_connect(_node_id(ring, layer, "n"), _node_id(ring, layer, "ne"))
	_connect(_node_id(ring, layer, "ne"), _node_id(ring, layer, "e"))
	_connect(_node_id(ring, layer, "e"), _node_id(ring, layer, "se"))
	_connect(_node_id(ring, layer, "se"), _node_id(ring, layer, "s"))
	_connect(_node_id(ring, layer, "s"), _node_id(ring, layer, "sw"))
	_connect(_node_id(ring, layer, "sw"), _node_id(ring, layer, "w"))
	_connect(_node_id(ring, layer, "w"), _node_id(ring, layer, "nw"))

func _add_junction(id: String, position: Vector3) -> void:
	junction_positions[id] = position
	if not adjacency.has(id):
		adjacency[id] = []

func _connect(a: String, b: String) -> void:
	if not adjacency.has(a) or not adjacency.has(b):
		return
	if not adjacency[a].has(b):
		adjacency[a].append(b)
	if not adjacency[b].has(a):
		adjacency[b].append(a)

	var edge_key := _edge_key(a, b)
	if edge_lookup.has(edge_key):
		return
	edge_lookup[edge_key] = true
	segment_pairs.append([a, b])

func _rebuild_geometry() -> void:
	for segment in segment_pairs:
		_create_corridor_shell(segment[0], segment[1])
		_create_minimap_pipe(segment[0], segment[1])

	for junction_id in junction_positions.keys():
		_create_minimap_junction(String(junction_id))

func _create_corridor_shell(from_id: String, to_id: String) -> void:
	var start: Vector3 = get_junction_position(from_id)
	var end: Vector3 = get_junction_position(to_id)
	var delta: Vector3 = end - start
	var direction: Vector3 = delta.normalized()
	var start_trim: float = junction_clearance if get_neighbors(from_id).size() > 1 else 0.0
	var end_trim: float = junction_clearance if get_neighbors(to_id).size() > 1 else 0.0
	var trimmed_start: Vector3 = start + direction * start_trim
	var trimmed_end: Vector3 = end - direction * end_trim
	var center: Vector3 = (trimmed_start + trimmed_end) * 0.5
	var trimmed_delta: Vector3 = trimmed_end - trimmed_start
	var length: float = trimmed_delta.length()
	if length <= 0.01:
		return

	var material: Material = _material_for_height(center.y)
	if absf(trimmed_delta.x) > 0.1:
		_add_box("%s_%s_floor" % [from_id, to_id], center + Vector3(0.0, -corridor_height * 0.5 - wall_thickness * 0.5, 0.0), Vector3(length, wall_thickness, corridor_width + wall_thickness * 2.0), material)
		_add_box("%s_%s_ceiling" % [from_id, to_id], center + Vector3(0.0, corridor_height * 0.5 + wall_thickness * 0.5, 0.0), Vector3(length, wall_thickness, corridor_width + wall_thickness * 2.0), material)
		_add_box("%s_%s_left" % [from_id, to_id], center + Vector3(0.0, 0.0, -corridor_width * 0.5 - wall_thickness * 0.5), Vector3(length, corridor_height, wall_thickness), material)
		_add_box("%s_%s_right" % [from_id, to_id], center + Vector3(0.0, 0.0, corridor_width * 0.5 + wall_thickness * 0.5), Vector3(length, corridor_height, wall_thickness), material)
	elif absf(trimmed_delta.z) > 0.1:
		_add_box("%s_%s_floor" % [from_id, to_id], center + Vector3(0.0, -corridor_height * 0.5 - wall_thickness * 0.5, 0.0), Vector3(corridor_width + wall_thickness * 2.0, wall_thickness, length), material)
		_add_box("%s_%s_ceiling" % [from_id, to_id], center + Vector3(0.0, corridor_height * 0.5 + wall_thickness * 0.5, 0.0), Vector3(corridor_width + wall_thickness * 2.0, wall_thickness, length), material)
		_add_box("%s_%s_left" % [from_id, to_id], center + Vector3(-corridor_width * 0.5 - wall_thickness * 0.5, 0.0, 0.0), Vector3(wall_thickness, corridor_height, length), material)
		_add_box("%s_%s_right" % [from_id, to_id], center + Vector3(corridor_width * 0.5 + wall_thickness * 0.5, 0.0, 0.0), Vector3(wall_thickness, corridor_height, length), material)
	else:
		_add_box("%s_%s_west" % [from_id, to_id], center + Vector3(-corridor_width * 0.5 - wall_thickness * 0.5, 0.0, 0.0), Vector3(wall_thickness, length, corridor_width + wall_thickness * 2.0), material)
		_add_box("%s_%s_east" % [from_id, to_id], center + Vector3(corridor_width * 0.5 + wall_thickness * 0.5, 0.0, 0.0), Vector3(wall_thickness, length, corridor_width + wall_thickness * 2.0), material)
		_add_box("%s_%s_north" % [from_id, to_id], center + Vector3(0.0, 0.0, -corridor_width * 0.5 - wall_thickness * 0.5), Vector3(corridor_width, length, wall_thickness), material)
		_add_box("%s_%s_south" % [from_id, to_id], center + Vector3(0.0, 0.0, corridor_width * 0.5 + wall_thickness * 0.5), Vector3(corridor_width, length, wall_thickness), material)

func _add_box(name: String, position: Vector3, size: Vector3, material: Material) -> void:
	var box := CSGBox3D.new()
	box.name = name
	box.position = position
	box.size = size
	box.material = material
	box.use_collision = true
	geometry_root.add_child(box)

func _create_materials() -> void:
	materials.clear()
	materials[0] = _make_material(Color(0.13, 0.24, 0.22, 1.0))
	materials[1] = _make_material(Color(0.15, 0.26, 0.39, 1.0))
	materials[2] = _make_material(Color(0.18, 0.41, 0.47, 1.0))
	materials["pipe"] = _make_pipe_material()

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	material.metallic = 0.05
	return material

func _make_pipe_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.68, 0.94, 1.0, 0.18)
	material.emission_enabled = true
	material.emission = Color(0.33, 0.86, 1.0, 1.0)
	material.emission_energy_multiplier = 1.1
	material.roughness = 0.06
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _material_for_height(height: float) -> Material:
	var layer := int(round((height - layer_center_base) / layer_spacing))
	return materials.get(clamp(layer, 0, layer_count - 1), materials[0])

func _create_minimap_pipe(from_id: String, to_id: String) -> void:
	var start: Vector3 = get_junction_position(from_id)
	var end: Vector3 = get_junction_position(to_id)
	var delta: Vector3 = end - start
	var length: float = delta.length()
	if length <= 0.01:
		return

	var pipe := MeshInstance3D.new()
	pipe.name = "%s_%s_pipe" % [from_id, to_id]
	pipe.layers = 2
	pipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = minimap_pipe_radius
	mesh.bottom_radius = minimap_pipe_radius
	mesh.height = length
	mesh.radial_segments = 20
	mesh.rings = 4
	pipe.mesh = mesh
	pipe.material_override = materials["pipe"]
	pipe.transform = Transform3D(_basis_from_up_to(delta.normalized()), (start + end) * 0.5)
	minimap_geometry_root.add_child(pipe)

func _create_minimap_junction(junction_id: String) -> void:
	var bubble := MeshInstance3D.new()
	bubble.name = "%s_joint" % junction_id
	bubble.layers = 2
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = minimap_pipe_radius * 1.24
	mesh.height = minimap_pipe_radius * 2.48
	bubble.mesh = mesh
	bubble.material_override = materials["pipe"]
	bubble.position = get_junction_position(junction_id)
	minimap_geometry_root.add_child(bubble)

func _basis_from_up_to(direction: Vector3) -> Basis:
	var normalized_direction: Vector3 = direction.normalized()
	var dot: float = clamp(Vector3.UP.dot(normalized_direction), -1.0, 1.0)
	if dot > 0.9999:
		return Basis.IDENTITY
	if dot < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	var axis: Vector3 = Vector3.UP.cross(normalized_direction).normalized()
	var angle: float = acos(dot)
	return Basis(axis, angle).orthonormalized()

func _pick_neighbor_in_direction(previous_id: String, current_id: String, preferred_direction: Vector3) -> String:
	var direction := preferred_direction.normalized()
	if direction == Vector3.ZERO:
		return ""

	var best_neighbor := ""
	var best_score := 0.55
	for neighbor in get_neighbors(current_id):
		if neighbor == previous_id:
			continue
		var neighbor_direction := get_direction(current_id, neighbor)
		var score := neighbor_direction.dot(direction)
		if score > best_score:
			best_score = score
			best_neighbor = neighbor
	return best_neighbor

func _node_id(ring: String, layer: int, suffix: String) -> String:
	return "%s_%d_%s" % [ring, layer, suffix]

func _center_id(layer: int) -> String:
	return "center_%d" % layer

func _edge_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]