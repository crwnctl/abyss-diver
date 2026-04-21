extends CharacterBody3D

enum AiMode {
	ROAM,
	TRACK,
	AMBUSH
}

@export var ai_mode: AiMode = AiMode.ROAM
@export var roam_speed: float = 2.2
@export var track_speed: float = 3.8
@export var visual_bob_height: float = 0.18
@export var visual_bob_speed: float = 2.1
@export var visual_sway_amount: float = 0.12
@export var visual_sway_speed: float = 1.5
@export var ambush_offset_distance: float = 6.0
@export var hit_radius: float = 1.05
@export var model_path: String = "res://assets/models/jellyfish.stl"
@export var start_from_node: String = "outer_1_e"
@export var start_to_node: String = "outer_1_ne"
@export var start_progress: float = 0.0

@onready var hit_area: Area3D = $HitArea
@onready var visual_mesh: MeshInstance3D = $MeshInstance3D

var player: Node3D
var visual_time: float = 0.0
var route_network
var current_node_id: String = ""
var next_node_id: String = ""
var segment_distance: float = 0.0
var current_move_direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	randomize()
	player = get_tree().get_first_node_in_group("player") as Node3D
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	hit_area.area_entered.connect(_on_hit_area_area_entered)
	route_network = get_tree().get_first_node_in_group("route_network")
	if route_network == null:
		await get_tree().process_frame
		route_network = get_tree().get_first_node_in_group("route_network")
	_load_visual_mesh()
	current_node_id = start_from_node
	next_node_id = start_to_node
	segment_distance = start_progress
	_update_route_transform()

func _physics_process(delta: float) -> void:
	visual_time += delta
	visual_mesh.position.y = sin(visual_time * visual_bob_speed) * visual_bob_height
	visual_mesh.rotation.z = sin(visual_time * visual_sway_speed) * visual_sway_amount

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D

	if route_network == null or current_node_id == "" or next_node_id == "":
		return

	var speed: float = track_speed if ai_mode != AiMode.ROAM else roam_speed
	_advance_along_route(delta, speed)
	_try_contact_damage()

func _try_contact_damage() -> void:
	if is_instance_valid(player) and player.global_position.distance_to(global_position) <= hit_radius:
		_damage_player(player)
		return
	for body in hit_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_node("PlayerStats"):
			_damage_player(body)
			break

func _on_hit_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_damage_player(body)

func _on_hit_area_area_entered(area: Area3D) -> void:
	if area.is_in_group("player_sensor"):
		var owner: Node = area.get_parent()
		if owner != null:
			_damage_player(owner)

func _damage_player(body: Node) -> void:
	if body.has_node("PlayerStats"):
		var stats: Node = body.get_node("PlayerStats")
		stats.kill()

func damage_player(body: Node) -> void:
	_damage_player(body)

func _load_visual_mesh() -> void:
	var mesh: ArrayMesh = _load_binary_stl_mesh(model_path)
	if mesh != null:
		visual_mesh.mesh = mesh
		visual_mesh.scale = Vector3.ONE * 1.2

func _load_binary_stl_mesh(path: String) -> ArrayMesh:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	if file.get_length() < 84:
		return null

	file.get_buffer(80)
	var triangle_count: int = file.get_32()
	if triangle_count <= 0:
		return null

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	vertices.resize(triangle_count * 3)
	normals.resize(triangle_count * 3)
	indices.resize(triangle_count * 3)

	for triangle_index in range(triangle_count):
		var normal: Vector3 = Vector3(file.get_float(), file.get_float(), file.get_float())
		for vertex_offset in range(3):
			var write_index: int = triangle_index * 3 + vertex_offset
			vertices[write_index] = Vector3(file.get_float(), file.get_float(), file.get_float())
			normals[write_index] = normal
			indices[write_index] = write_index
		file.get_16()

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _advance_along_route(delta: float, speed: float) -> void:
	var remaining_distance: float = speed * delta
	while remaining_distance > 0.0:
		var segment_length: float = route_network.get_segment_length(current_node_id, next_node_id)
		if segment_length <= 0.0:
			return

		var step: float = min(remaining_distance, segment_length - segment_distance)
		segment_distance += step
		remaining_distance -= step

		if segment_distance >= segment_length - 0.001:
			var reached_node: String = next_node_id
			var previous_node: String = current_node_id
			current_node_id = reached_node
			next_node_id = _pick_next_node(previous_node, reached_node)
			segment_distance = 0.0
			if next_node_id == "":
				next_node_id = previous_node

	_update_route_transform()

func _pick_next_node(previous_node: String, reached_node: String) -> String:
	if ai_mode == AiMode.TRACK and is_instance_valid(player):
		return route_network.pick_neighbor_toward_target(previous_node, reached_node, player.global_position)
	if ai_mode == AiMode.AMBUSH and is_instance_valid(player):
		var move_direction: Vector3 = player.get("current_move_direction") if player.get("current_move_direction") is Vector3 else -player.global_transform.basis.z
		var target_position: Vector3 = player.global_position + move_direction.normalized() * ambush_offset_distance
		return route_network.pick_neighbor_toward_target(previous_node, reached_node, target_position)
	return route_network.pick_random_neighbor(previous_node, reached_node)

func _update_route_transform() -> void:
	if route_network == null or current_node_id == "" or next_node_id == "":
		return

	var start: Vector3 = route_network.get_junction_position(current_node_id)
	var end: Vector3 = route_network.get_junction_position(next_node_id)
	var segment_length: float = start.distance_to(end)
	if segment_length <= 0.0:
		return

	var alpha: float = clamp(segment_distance / segment_length, 0.0, 1.0)
	global_position = start.lerp(end, alpha)
	current_move_direction = (end - start).normalized()
	var up_hint: Vector3 = Vector3.UP
	if absf(current_move_direction.dot(Vector3.UP)) > 0.95:
		up_hint = Vector3.FORWARD
	look_at(global_position + current_move_direction, up_hint)
