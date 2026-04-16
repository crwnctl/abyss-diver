extends Control

@export var world_range: float = 16.0
@export var player_color: Color = Color(0.9, 1.0, 1.0, 1.0)
@export var jellyfish_color: Color = Color(1.0, 0.35, 0.7, 1.0)
@export var bubble_color: Color = Color(0.4, 0.9, 1.0, 1.0)
@export var marker_radius: float = 3.0

var player = null
var jellyfish_nodes = []
var bubble_nodes = []

func set_tracking(player_node, jellyfish_list, bubble_list) -> void:
	player = player_node
	jellyfish_nodes.clear()
	bubble_nodes.clear()

	for node in jellyfish_list:
		if node is Node3D:
			jellyfish_nodes.append(node)

	for node in bubble_list:
		if node is Node3D:
			bubble_nodes.append(node)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.02, 0.08, 0.1, 0.72), true)
	draw_rect(rect, Color(0.45, 0.8, 0.85, 0.5), false, 1.0)

	var center = rect.size * 0.5
	draw_line(Vector2(center.x, 0), Vector2(center.x, rect.size.y), Color(0.35, 0.65, 0.7, 0.35), 1.0)
	draw_line(Vector2(0, center.y), Vector2(rect.size.x, center.y), Color(0.35, 0.65, 0.7, 0.35), 1.0)

	if not is_instance_valid(player):
		return

	for bubble in bubble_nodes:
		if is_instance_valid(bubble):
			_draw_marker_for_world_point(player.global_position, bubble.global_position, bubble_color, marker_radius)

	for jelly in jellyfish_nodes:
		if is_instance_valid(jelly):
			_draw_marker_for_world_point(player.global_position, jelly.global_position, jellyfish_color, marker_radius + 0.8)

	draw_circle(center, marker_radius + 1.2, player_color)

func _draw_marker_for_world_point(origin: Vector3, target: Vector3, color: Color, radius: float) -> void:
	var offset_world = target - origin
	var offset = Vector2(offset_world.x, offset_world.z)
	var max_radius = min(size.x, size.y) * 0.45
	var pos = offset / world_range
	pos = pos.limit_length(1.0) * max_radius
	var draw_position = size * 0.5 + pos
	draw_circle(draw_position, radius, color)
