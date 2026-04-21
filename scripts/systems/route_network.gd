extends Node3D

const PLAYER_START_FROM := "grid_1_0_2"
const PLAYER_START_TO := "grid_2_0_2"
const PLAYER_START_PROGRESS := 1.2
const GRID_AXIS_INDEXES := [0, 1, 2]
const DEFAULT_LEVEL_LAYOUT := "---\n111\n111\n111\n---\n111\n111\n111\n---\n111\n111\n111\n---"

@export_multiline var level_layout_text: String = DEFAULT_LEVEL_LAYOUT
@export var outer_radius: float = 6.0
@export var inner_radius: float = 4.0
@export var layer_center_base: float = 2.0
@export var layer_spacing: float = 8.0
@export var layer_count: int = 3
@export var corridor_width: float = 4.0
@export var corridor_height: float = 4.0
@export var wall_thickness: float = 0.15
@export var junction_clearance: float = 1.0
@export var minimap_pipe_radius: float = 1.35

var junction_positions: Dictionary = {}
var adjacency: Dictionary = {}
var segment_pairs: Array = []
var edge_lookup: Dictionary = {}
var occupied_lookup: Dictionary = {}
var cell_indices: Dictionary = {}
var geometry_root: Node3D
var minimap_geometry_root: Node3D
var lantern_root: Node3D
var collision_root: StaticBody3D
var materials: Dictionary = {}
var geometry_batches: Dictionary = {}

func _ready() -> void:
	add_to_group("route_network")
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
	for segment_value in segment_pairs:
		var segment: Array = segment_value
		var start: Vector3 = get_junction_position(String(segment[0]))
		var end: Vector3 = get_junction_position(String(segment[1]))
		var bubble_count: int = 2 if absf(end.y - start.y) > 0.1 else int(max(1.0, roundf(start.distance_to(end) / 8.0)))
		for index in range(bubble_count):
			var t: float = float(index + 1) / float(bubble_count + 1)
			positions.append(start.lerp(end, t))
	return positions

func pick_neighbor_by_preferences(previous_id: String, current_id: String, preferred_directions: Array) -> String:
	for preferred_direction in preferred_directions:
		if preferred_direction is Vector3:
			var candidate: String = _pick_neighbor_in_direction(previous_id, current_id, preferred_direction)
			if candidate != "":
				return candidate
	return pick_random_neighbor(previous_id, current_id)

func pick_random_neighbor(previous_id: String, current_id: String) -> String:
	var candidates: Array = []
	for neighbor_value in get_neighbors(current_id):
		var neighbor: String = String(neighbor_value)
		if neighbor != previous_id:
			candidates.append(neighbor)
	if candidates.is_empty():
		return previous_id
	return String(candidates[randi() % candidates.size()])

func pick_neighbor_toward_target(previous_id: String, current_id: String, target_position: Vector3) -> String:
	var current_position: Vector3 = get_junction_position(current_id)
	var target_direction: Vector3 = (target_position - current_position).normalized()
	var candidate: String = _pick_neighbor_in_direction(previous_id, current_id, target_direction)
	if candidate != "":
		return candidate
	return pick_random_neighbor(previous_id, current_id)

func _clear_graph() -> void:
	junction_positions.clear()
	adjacency.clear()
	segment_pairs.clear()
	edge_lookup.clear()
	occupied_lookup.clear()
	cell_indices.clear()
	geometry_batches.clear()
	materials.clear()
	if geometry_root != null and is_instance_valid(geometry_root):
		remove_child(geometry_root)
		geometry_root.queue_free()
	if minimap_geometry_root != null and is_instance_valid(minimap_geometry_root):
		remove_child(minimap_geometry_root)
		minimap_geometry_root.queue_free()
	if lantern_root != null and is_instance_valid(lantern_root):
		remove_child(lantern_root)
		lantern_root.queue_free()

	geometry_root = Node3D.new()
	geometry_root.name = "GeneratedGeometry"
	add_child(geometry_root)
	collision_root = StaticBody3D.new()
	collision_root.name = "StaticGeometry"
	geometry_root.add_child(collision_root)

	minimap_geometry_root = Node3D.new()
	minimap_geometry_root.name = "GeneratedMiniMapGeometry"
	add_child(minimap_geometry_root)

	lantern_root = Node3D.new()
	lantern_root.name = "GeneratedLanterns"
	add_child(lantern_root)

func _build_graph() -> void:
	var parsed_layers: Array = _parse_level_layout(level_layout_text)
	layer_count = parsed_layers.size()
	for y_index in range(parsed_layers.size()):
		var layer_rows: Array = parsed_layers[y_index]
		var y_position: float = layer_center_base + float(y_index) * layer_spacing
		for z_index in GRID_AXIS_INDEXES:
			var row: String = String(layer_rows[z_index])
			for x_index in GRID_AXIS_INDEXES:
				if row.substr(x_index, 1) != "1":
					continue
				var cell_id: String = _grid_id(x_index, y_index, z_index)
				var position: Vector3 = Vector3(_axis_to_coordinate(x_index), y_position, _axis_to_coordinate(z_index))
				_add_junction(cell_id, position, Vector3i(x_index, y_index, z_index))

	for cell_id_value in occupied_lookup.keys():
		var cell_id: String = String(cell_id_value)
		var coords: Vector3i = cell_indices.get(cell_id, Vector3i.ZERO)
		if _has_cell(coords.x + 1, coords.y, coords.z):
			_connect(cell_id, _grid_id(coords.x + 1, coords.y, coords.z))
		if _has_cell(coords.x, coords.y, coords.z + 1):
			_connect(cell_id, _grid_id(coords.x, coords.y, coords.z + 1))
		if _has_cell(coords.x, coords.y + 1, coords.z):
			_connect(cell_id, _grid_id(coords.x, coords.y + 1, coords.z))

func _parse_level_layout(layout_text: String) -> Array:
	var normalized_text: String = layout_text if layout_text.strip_edges() != "" else DEFAULT_LEVEL_LAYOUT
	var layers: Array = []
	var current_rows: Array = []
	for raw_line_value in normalized_text.split("\n"):
		var line: String = String(raw_line_value).strip_edges()
		if line == "":
			continue
		if line == "---":
			if not current_rows.is_empty():
				layers.append(current_rows.duplicate())
				current_rows.clear()
			continue
		current_rows.append(line)
	if not current_rows.is_empty():
		layers.append(current_rows.duplicate())
	if layers.is_empty():
		layers = _parse_level_layout(DEFAULT_LEVEL_LAYOUT)

	var sanitized_layers: Array = []
	for layer_value in layers:
		var raw_rows: Array = layer_value
		if raw_rows.size() < 3:
			continue
		var sanitized_rows: Array = []
		for row_index in range(3):
			var row: String = String(raw_rows[row_index]).replace(" ", "")
			if row.length() < 3:
				row = row.rpad(3, "0")
			sanitized_rows.append(row.substr(0, 3))
		if sanitized_rows.size() == 3:
			sanitized_layers.append(sanitized_rows)
	if sanitized_layers.is_empty():
		return _parse_level_layout(DEFAULT_LEVEL_LAYOUT)
	return sanitized_layers

func _axis_to_coordinate(index: int) -> float:
	return (float(index) - 1.0) * outer_radius

func _add_junction(id: String, position: Vector3, coords: Vector3i) -> void:
	junction_positions[id] = position
	cell_indices[id] = coords
	occupied_lookup[id] = true
	if not adjacency.has(id):
		adjacency[id] = []

func _has_cell(x_index: int, y_index: int, z_index: int) -> bool:
	return occupied_lookup.has(_grid_id(x_index, y_index, z_index))

func _connect(a: String, b: String) -> void:
	if not adjacency.has(a) or not adjacency.has(b):
		return
	if not adjacency[a].has(b):
		adjacency[a].append(b)
	if not adjacency[b].has(a):
		adjacency[b].append(a)

	var edge_key: String = _edge_key(a, b)
	if edge_lookup.has(edge_key):
		return
	edge_lookup[edge_key] = true
	segment_pairs.append([a, b])

func _rebuild_geometry() -> void:
	for cell_id_value in occupied_lookup.keys():
		var cell_id: String = String(cell_id_value)
		_create_cell_shell(cell_id)
		_create_minimap_junction(cell_id)

	for segment_value in segment_pairs:
		var segment: Array = segment_value
		_create_minimap_pipe(String(segment[0]), String(segment[1]))
		_create_segment_lantern(String(segment[0]), String(segment[1]))

	_commit_geometry_batches()

func _create_cell_shell(cell_id: String) -> void:
	var center: Vector3 = get_junction_position(cell_id)
	var coords: Vector3i = cell_indices.get(cell_id, Vector3i.ZERO)
	var half_width: float = corridor_width * 0.5
	var half_height: float = corridor_height * 0.5
	var thickness: float = wall_thickness
	var material_index: int = _material_index_for_height(center.y)

	if not _has_cell(coords.x + 1, coords.y, coords.z):
		_queue_box(center + Vector3(half_width + thickness * 0.5, 0.0, 0.0), Vector3(thickness, corridor_height + thickness * 2.0, corridor_width + thickness * 2.0), material_index)
	if not _has_cell(coords.x - 1, coords.y, coords.z):
		_queue_box(center + Vector3(-half_width - thickness * 0.5, 0.0, 0.0), Vector3(thickness, corridor_height + thickness * 2.0, corridor_width + thickness * 2.0), material_index)
	if not _has_cell(coords.x, coords.y, coords.z + 1):
		_queue_box(center + Vector3(0.0, 0.0, half_width + thickness * 0.5), Vector3(corridor_width + thickness * 2.0, corridor_height + thickness * 2.0, thickness), material_index)
	if not _has_cell(coords.x, coords.y, coords.z - 1):
		_queue_box(center + Vector3(0.0, 0.0, -half_width - thickness * 0.5), Vector3(corridor_width + thickness * 2.0, corridor_height + thickness * 2.0, thickness), material_index)
	if not _has_cell(coords.x, coords.y + 1, coords.z):
		_queue_box(center + Vector3(0.0, half_height + thickness * 0.5, 0.0), Vector3(corridor_width + thickness * 2.0, thickness, corridor_width + thickness * 2.0), material_index)
	if not _has_cell(coords.x, coords.y - 1, coords.z):
		_queue_box(center + Vector3(0.0, -half_height - thickness * 0.5, 0.0), Vector3(corridor_width + thickness * 2.0, thickness, corridor_width + thickness * 2.0), material_index)

func _queue_box(position: Vector3, size: Vector3, material_index: int) -> void:
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return
	if not geometry_batches.has(material_index):
		geometry_batches[material_index] = []
	geometry_batches[material_index].append({
		"position": position,
		"size": size
	})

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	collision_shape.position = position
	collision_root.add_child(collision_shape)

func _commit_geometry_batches() -> void:
	for material_index_value in geometry_batches.keys():
		var material_index: int = int(material_index_value)
		var entries: Array = geometry_batches[material_index]
		if entries.is_empty():
			continue

		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3.ONE
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = entries.size()

		for index in range(entries.size()):
			var entry: Dictionary = entries[index]
			var size: Vector3 = entry["size"]
			var position: Vector3 = entry["position"]
			multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(size), position))

		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = "GeometryBatch_%d" % material_index
		instance.multimesh = multimesh
		instance.material_override = _get_wall_material(material_index)
		geometry_root.add_child(instance)

func _get_wall_material(layer_index: int) -> Material:
	if not materials.has(layer_index):
		materials[layer_index] = _make_wall_material(_wall_color_for_layer(layer_index))
	return materials[layer_index]

func _make_wall_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r * 0.35, color.g * 0.35, color.b * 0.4, 1.0)
	material.emission_energy_multiplier = 0.35
	material.roughness = 0.18
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _wall_color_for_layer(layer_index: int) -> Color:
	var hue: float = fposmod(0.52 + float(layer_index) * 0.05, 1.0)
	var value: float = 0.34 + min(float(layer_index), 6.0) * 0.03
	return Color.from_hsv(hue, 0.28, min(value, 0.6), 0.8)

func _create_segment_lantern(from_id: String, to_id: String) -> void:
	var start: Vector3 = get_junction_position(from_id)
	var end: Vector3 = get_junction_position(to_id)
	var delta: Vector3 = end - start
	if absf(delta.y) > 0.05:
		return
	if int(absf(start.x + start.z + end.x + end.z)) % 6 != 0:
		return

	var direction: Vector3 = delta.normalized()
	if direction.length_squared() <= 0.001:
		return
	var side: Vector3 = direction.cross(Vector3.UP).normalized()
	if side.length_squared() <= 0.001:
		return
	if int(round(start.x + end.z)) % 2 == 0:
		side = -side

	var anchor: Vector3 = start.lerp(end, 0.5) + side * (corridor_width * 0.5 - 0.35) + Vector3.UP * (corridor_height * 0.5 - 0.4)
	var lantern: Node3D = Node3D.new()
	lantern.name = "%s_%s_lantern" % [from_id, to_id]
	lantern.position = anchor

	var chain: MeshInstance3D = MeshInstance3D.new()
	var chain_mesh: CylinderMesh = CylinderMesh.new()
	chain_mesh.top_radius = 0.03
	chain_mesh.bottom_radius = 0.03
	chain_mesh.height = 0.5
	chain.mesh = chain_mesh
	chain.material_override = _make_lantern_material(Color(0.16, 0.14, 0.09, 1.0), 0.0)
	_add_unlit_mesh(chain, lantern)

	var bulb: MeshInstance3D = MeshInstance3D.new()
	var bulb_mesh: SphereMesh = SphereMesh.new()
	bulb_mesh.radius = 0.16
	bulb_mesh.height = 0.32
	bulb.mesh = bulb_mesh
	bulb.position = Vector3(0.0, -0.34, 0.0)
	bulb.material_override = _make_lantern_material(Color(1.0, 0.79, 0.36, 1.0), 1.15)
	_add_unlit_mesh(bulb, lantern)

	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(0.0, -0.34, 0.0)
	light.light_color = Color(1.0, 0.8, 0.45, 1.0)
	light.light_energy = 0.45
	light.omni_range = 5.2
	light.shadow_enabled = false
	lantern.add_child(light)
	lantern_root.add_child(lantern)

func _make_lantern_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.35
	material.metallic = 0.15 if emission_energy <= 0.0 else 0.0
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material

func _add_unlit_mesh(node: MeshInstance3D, target_parent: Node3D) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_parent.add_child(node)

func _material_index_for_height(height: float) -> int:
	var layer: int = int(round((height - layer_center_base) / layer_spacing))
	return max(layer, 0)

func _create_minimap_pipe(from_id: String, to_id: String) -> void:
	var start: Vector3 = get_junction_position(from_id)
	var end: Vector3 = get_junction_position(to_id)
	var delta: Vector3 = end - start
	var length: float = delta.length()
	if length <= 0.01:
		return

	var pipe: MeshInstance3D = MeshInstance3D.new()
	pipe.name = "%s_%s_pipe" % [from_id, to_id]
	pipe.layers = 2
	pipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = minimap_pipe_radius
	mesh.bottom_radius = minimap_pipe_radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 2
	pipe.mesh = mesh
	pipe.material_override = _get_pipe_material()
	pipe.transform = Transform3D(_basis_from_up_to(delta.normalized()), (start + end) * 0.5)
	minimap_geometry_root.add_child(pipe)

func _create_minimap_junction(junction_id: String) -> void:
	var bubble: MeshInstance3D = MeshInstance3D.new()
	bubble.name = "%s_joint" % junction_id
	bubble.layers = 2
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = minimap_pipe_radius * 1.2
	mesh.height = minimap_pipe_radius * 2.4
	mesh.radial_segments = 10
	mesh.rings = 6
	bubble.mesh = mesh
	bubble.material_override = _get_pipe_material()
	bubble.position = get_junction_position(junction_id)
	minimap_geometry_root.add_child(bubble)

func _get_pipe_material() -> Material:
	if not materials.has("pipe"):
		materials["pipe"] = _make_pipe_material()
	return materials["pipe"]

func _make_pipe_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.68, 0.94, 1.0, 0.18)
	material.emission_enabled = true
	material.emission = Color(0.33, 0.86, 1.0, 1.0)
	material.emission_energy_multiplier = 1.1
	material.roughness = 0.06
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

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
	var direction: Vector3 = preferred_direction.normalized()
	if direction == Vector3.ZERO:
		return ""

	var best_neighbor: String = ""
	var best_score: float = 0.55
	for neighbor_value in get_neighbors(current_id):
		var neighbor: String = String(neighbor_value)
		if neighbor == previous_id:
			continue
		var neighbor_direction: Vector3 = get_direction(current_id, neighbor)
		var score: float = neighbor_direction.dot(direction)
		if score > best_score:
			best_score = score
			best_neighbor = neighbor
	return best_neighbor

func _grid_id(x_index: int, y_index: int, z_index: int) -> String:
	return "grid_%d_%d_%d" % [x_index, y_index, z_index]

func _edge_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
