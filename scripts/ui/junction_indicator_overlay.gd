extends Control

const DIRECTIONS := ["left", "right", "up", "down"]

var approach_progress: float = 0.0
var selected_direction: String = ""
var available_directions: Dictionary = {
	"left": false,
	"right": false,
	"up": false,
	"down": false
}

func set_state(state: Dictionary) -> void:
	approach_progress = clamp(float(state.get("progress", 0.0)), 0.0, 1.0)
	selected_direction = String(state.get("selected", ""))
	for direction_name in DIRECTIONS:
		available_directions[direction_name] = bool(state.get(direction_name, false))
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	for direction_name in DIRECTIONS:
		var is_selected: bool = selected_direction == direction_name
		var is_available: bool = bool(available_directions.get(direction_name, false))
		if not is_selected and not is_available:
			continue
		_draw_direction_glow(direction_name, is_selected)

func _draw_direction_glow(direction_name: String, is_selected: bool) -> void:
	var edge_color: Color = _get_edge_color(is_selected)
	var transparent: Color = Color(edge_color.r, edge_color.g, edge_color.b, 0.0)
	var edge_width: float = min(size.x * 0.18, 160.0)
	var edge_height: float = min(size.y * 0.18, 120.0)
	var inset: float = min(size.x, size.y) * 0.08
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()

	match direction_name:
		"left":
			points = PackedVector2Array([
				Vector2(0.0, 0.0),
				Vector2(edge_width, inset),
				Vector2(edge_width, size.y - inset),
				Vector2(0.0, size.y)
			])
			colors = PackedColorArray([edge_color, transparent, transparent, edge_color])
		"right":
			points = PackedVector2Array([
				Vector2(size.x, 0.0),
				Vector2(size.x - edge_width, inset),
				Vector2(size.x - edge_width, size.y - inset),
				Vector2(size.x, size.y)
			])
			colors = PackedColorArray([edge_color, transparent, transparent, edge_color])
		"up":
			points = PackedVector2Array([
				Vector2(0.0, 0.0),
				Vector2(size.x, 0.0),
				Vector2(size.x - inset, edge_height),
				Vector2(inset, edge_height)
			])
			colors = PackedColorArray([edge_color, edge_color, transparent, transparent])
		"down":
			points = PackedVector2Array([
				Vector2(inset, size.y - edge_height),
				Vector2(size.x - inset, size.y - edge_height),
				Vector2(size.x, size.y),
				Vector2(0.0, size.y)
			])
			colors = PackedColorArray([transparent, transparent, edge_color, edge_color])
		_:
			return

	draw_polygon(points, colors)

func _get_edge_color(is_selected: bool) -> Color:
	if is_selected:
		return Color(0.62, 0.33, 0.92, 0.44)

	var blend_color: Color = Color(0.28, 0.96, 0.48, 0.14).lerp(Color(0.95, 0.18, 0.22, 0.44), approach_progress)
	blend_color.a = 0.12 + approach_progress * 0.32
	return blend_color