extends Control

@export var corridor_color: Color = Color(0.62, 0.88, 0.96, 0.42)
@export var player_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var bubble_color: Color = Color(0.48, 0.9, 1.0, 0.95)
@export var jellyfish_color: Color = Color(1.0, 0.46, 0.72, 0.95)
@export var background_grid_color: Color = Color(0.3, 0.58, 0.66, 0.12)
@export var marker_radius: float = 4.0
@export var bubble_radius: float = 2.5
@export var jellyfish_radius: float = 3.6
@export var wireframe_line_width: float = 1.35

var route_network
var player: Node3D
var bubble_nodes: Array = []
var jellyfish_nodes: Array = []

func set_references(route_network_node, player_node: Node3D, bubbles: Array, jellyfish: Array) -> void:
	route_network = route_network_node
	player = player_node
	bubble_nodes = bubbles
	jellyfish_nodes = jellyfish
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.01, 0.06, 0.08, 0.1), true)
	_draw_grid(rect)

	if route_network == null or not is_instance_valid(player):
		return

	for segment in route_network.get_segment_pairs():
		_draw_corridor_outline(String(segment[0]), String(segment[1]))

	for bubble in bubble_nodes:
		if is_instance_valid(bubble):
			draw_circle(_project_point(bubble.global_position), bubble_radius, bubble_color)

	for jellyfish in jellyfish_nodes:
		if is_instance_valid(jellyfish):
			draw_circle(_project_point(jellyfish.global_position), jellyfish_radius, jellyfish_color)

	draw_circle(_project_point(player.global_position), marker_radius, player_color)

func _draw_grid(rect: Rect2) -> void:
	var center := rect.size * 0.5
	for offset in range(-4, 5):
		var x := center.x + float(offset) * 34.0
		var y := center.y + float(offset) * 26.0
		draw_line(Vector2(x, 0.0), Vector2(x, rect.size.y), background_grid_color, 1.0)
		draw_line(Vector2(0.0, y), Vector2(rect.size.x, y), background_grid_color, 1.0)

func _draw_corridor_outline(from_id: String, to_id: String) -> void:
	var start: Vector3 = route_network.get_junction_position(from_id)
	var end: Vector3 = route_network.get_junction_position(to_id)
	var direction: Vector3 = (end - start).normalized()
	var half_width: float = route_network.get_corridor_half_width()
	var half_height: float = route_network.get_corridor_half_height()

	if absf(direction.y) > 0.9:
		var x_offset := Vector3.RIGHT * half_width
		var z_offset := Vector3.FORWARD * half_width
		_draw_wire_line(_project_point(start + x_offset), _project_point(end + x_offset), corridor_color)
		_draw_wire_line(_project_point(start - x_offset), _project_point(end - x_offset), corridor_color)
		_draw_wire_line(_project_point(start + z_offset), _project_point(end + z_offset), corridor_color)
		_draw_wire_line(_project_point(start - z_offset), _project_point(end - z_offset), corridor_color)
		return

	var side: Vector3 = Vector3.UP.cross(direction).normalized()
	if side == Vector3.ZERO:
		side = Vector3.RIGHT
	var top_offset := Vector3.UP * half_height
	var side_offset := side * half_width

	_draw_wire_line(_project_point(start + side_offset + top_offset), _project_point(end + side_offset + top_offset), corridor_color)
	_draw_wire_line(_project_point(start - side_offset + top_offset), _project_point(end - side_offset + top_offset), corridor_color)
	_draw_wire_line(_project_point(start + side_offset - top_offset), _project_point(end + side_offset - top_offset), corridor_color)
	_draw_wire_line(_project_point(start - side_offset - top_offset), _project_point(end - side_offset - top_offset), corridor_color)

func _draw_wire_line(start: Vector2, end: Vector2, color: Color) -> void:
	draw_line(start, end, color, wireframe_line_width)

func _project_point(world_point: Vector3) -> Vector2:
	var pivot := player.global_position if is_instance_valid(player) else Vector3.ZERO
	var relative := world_point - pivot
	var projected := Vector2(relative.x * 9.5 - relative.z * 4.75, -relative.y * 12.0 + relative.z * 2.6)
	return size * 0.5 + projected