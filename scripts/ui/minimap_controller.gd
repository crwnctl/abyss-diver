extends Node3D

@export var player_path: NodePath
@export var camera_path: NodePath
@export var marker_path: NodePath
@export var map_center: Vector3 = Vector3.ZERO
@export var follow_player_position: bool = false
@export var camera_height: float = 55.0
@export var camera_tilt_degrees: float = -65.0
@export var orthographic_size: float = 35.0
@export var marker_height_offset: float = 0.75

var player: Node3D
var minimap_camera: Camera3D
var player_marker: MeshInstance3D

func _ready() -> void:
	player = get_node_or_null(player_path)
	minimap_camera = get_node_or_null(camera_path)
	player_marker = get_node_or_null(marker_path)

	if minimap_camera != null:
		minimap_camera.current = false
		minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		minimap_camera.size = orthographic_size
		minimap_camera.cull_mask = 3
		minimap_camera.near = 0.05
		minimap_camera.far = 250.0

	if player_marker != null:
		player_marker.visible = player != null

	_update_minimap_state()

func _process(_delta: float) -> void:
	_update_minimap_state()

func set_player(player_node: Node3D) -> void:
	player = player_node
	if player_marker != null:
		player_marker.visible = player != null

func _update_minimap_state() -> void:
	if player == null:
		player = get_node_or_null(player_path)

	if player == null:
		return

	if follow_player_position:
		global_position = Vector3(player.global_position.x, map_center.y, player.global_position.z)
	else:
		global_position = map_center

	rotation.y = player.rotation.y

	if minimap_camera != null:
		minimap_camera.size = orthographic_size
		minimap_camera.global_position = global_position + Vector3.UP * camera_height
		minimap_camera.global_rotation_degrees = Vector3(camera_tilt_degrees, rotation_degrees.y, 0.0)

	if player_marker != null:
		player_marker.visible = true
		player_marker.global_position = player.global_position + Vector3.UP * marker_height_offset