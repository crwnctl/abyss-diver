extends Node3D

@export var player_path: NodePath
@export var camera_path: NodePath
@export var marker_path: NodePath
@export var map_center: Vector3 = Vector3.ZERO
@export var follow_player_position: bool = true
@export var orbit_radius: float = 48.0
@export var camera_height: float = 18.0
@export var orbit_speed: float = 0.42
@export var camera_fov: float = 38.0
@export var marker_height_offset: float = 0.75
@export var follow_smoothing: float = 2.5

var player: Node3D
var minimap_camera: Camera3D
var player_marker: MeshInstance3D
var orbit_angle: float = 0.0
var is_initialized: bool = false

func _ready() -> void:
	player = get_node_or_null(player_path)
	minimap_camera = get_node_or_null(camera_path)
	player_marker = get_node_or_null(marker_path)

	if minimap_camera != null:
		minimap_camera.current = false
		minimap_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		minimap_camera.fov = camera_fov
		minimap_camera.cull_mask = 2
		minimap_camera.near = 0.05
		minimap_camera.far = 250.0

	if player_marker != null:
		player_marker.visible = player != null

	_update_minimap_state(0.0)

func _process(delta: float) -> void:
	orbit_angle = wrapf(orbit_angle + delta * orbit_speed, 0.0, TAU)
	_update_minimap_state(delta)

func set_player(player_node: Node3D) -> void:
	player = player_node
	if player_marker != null:
		player_marker.visible = player != null

func _update_minimap_state(delta: float) -> void:
	if player == null:
		player = get_node_or_null(player_path)

	if player == null:
		return

	if follow_player_position:
		var target_position: Vector3 = Vector3(map_center.x, player.global_position.y, map_center.z)
		if not is_initialized:
			global_position = target_position
			is_initialized = true
		else:
			var blend_weight: float = min(1.0, follow_smoothing * max(delta, 0.0))
			global_position = global_position.lerp(target_position, blend_weight)
	else:
		global_position = map_center
		is_initialized = true

	if minimap_camera != null:
		var orbit_offset := Vector3(cos(orbit_angle) * orbit_radius, camera_height, sin(orbit_angle) * orbit_radius)
		minimap_camera.global_position = global_position + orbit_offset
		minimap_camera.look_at(global_position, Vector3.UP)

	if player_marker != null:
		player_marker.visible = true
		player_marker.global_position = player.global_position + Vector3.UP * marker_height_offset