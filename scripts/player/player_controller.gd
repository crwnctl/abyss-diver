extends CharacterBody3D

@export var move_speed: float = 2.1
@export var boost_speed: float = 3.4
@export var mouse_sensitivity: float = 0.0023
@export var look_yaw_limit_degrees: float = 75.0
@export var look_pitch_limit_degrees: float = 80.0
@export var turn_smoothing_speed: float = 5.5
@export var junction_decision_distance: float = 5.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var player_stats = $PlayerStats

var mouse_delta: Vector2 = Vector2.ZERO
var head_yaw: float = 0.0
var head_pitch: float = 0.0
var route_network
var current_node_id: String = ""
var next_node_id: String = ""
var segment_distance: float = 0.0
var current_move_direction: Vector3 = Vector3.FORWARD
var available_turn_options: Dictionary = {}
var selected_turn_label: String = ""
var junction_approach_ratio: float = 0.0
var tracked_junction_id: String = ""

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Input.use_accumulated_input = false
	camera.current = true
	camera.cull_mask = 1
	route_network = get_tree().get_first_node_in_group("route_network")
	if route_network == null:
		await get_tree().process_frame
		route_network = get_tree().get_first_node_in_group("route_network")
	_initialize_route_state()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_delta += event.relative

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	_apply_mouse_look()
	player_stats.drain_oxygen(delta)

	var current_speed := move_speed
	if Input.is_action_pressed("boost"):
		current_speed = boost_speed
	_advance_along_route(delta, current_speed)
	_apply_route_orientation(delta)
	_refresh_junction_preview()

func _apply_mouse_look() -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		mouse_delta = Vector2.ZERO
		return

	if mouse_delta == Vector2.ZERO:
		return

	head_yaw = clamp(head_yaw - mouse_delta.x * mouse_sensitivity, deg_to_rad(-look_yaw_limit_degrees), deg_to_rad(look_yaw_limit_degrees))
	head_pitch = clamp(head_pitch - mouse_delta.y * mouse_sensitivity, deg_to_rad(-look_pitch_limit_degrees), deg_to_rad(look_pitch_limit_degrees))
	head.rotation = Vector3(head_pitch, head_yaw, 0.0)
	mouse_delta = Vector2.ZERO

func _initialize_route_state() -> void:
	if route_network == null:
		return

	var start_edge: Dictionary = route_network.get_player_start_edge()
	current_node_id = String(start_edge.get("from", ""))
	next_node_id = String(start_edge.get("to", ""))
	segment_distance = float(start_edge.get("progress", 0.0))
	_update_route_transform()
	_snap_route_orientation()
	_refresh_junction_preview()

func _advance_along_route(delta: float, speed: float) -> void:
	if route_network == null or current_node_id == "" or next_node_id == "":
		return

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
			next_node_id = _choose_next_route(previous_node, reached_node)
			segment_distance = 0.0
			if next_node_id == "":
				next_node_id = previous_node

	_update_route_transform()

func _choose_next_route(previous_node: String, reached_node: String) -> String:
	var chosen_neighbor: String = ""
	if selected_turn_label != "" and available_turn_options.has(selected_turn_label):
		chosen_neighbor = String(available_turn_options[selected_turn_label])
	if chosen_neighbor == "":
		chosen_neighbor = route_network.pick_neighbor_by_preferences(previous_node, reached_node, _build_direction_preferences())
	_clear_junction_preview()
	return chosen_neighbor

func _build_direction_preferences() -> Array:
	var preferred_directions: Array = []
	var vertical_choice: float = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	if vertical_choice > 0.2:
		preferred_directions.append(Vector3.UP)
	elif vertical_choice < -0.2:
		preferred_directions.append(Vector3.DOWN)

	var horizontal_input: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if horizontal_input > 0.2:
		preferred_directions.append(global_transform.basis.x.normalized())
	elif horizontal_input < -0.2:
		preferred_directions.append(-global_transform.basis.x.normalized())

	preferred_directions.append(current_move_direction)
	return preferred_directions

func get_junction_indicator_state() -> Dictionary:
	return {
		"progress": junction_approach_ratio,
		"selected": selected_turn_label,
		"left": available_turn_options.has("left"),
		"right": available_turn_options.has("right"),
		"up": available_turn_options.has("up"),
		"down": available_turn_options.has("down")
	}

func _apply_route_orientation(delta: float) -> void:
	if current_move_direction.length_squared() <= 0.001:
		return

	var up_hint: Vector3 = Vector3.UP
	if absf(current_move_direction.dot(Vector3.UP)) > 0.95:
		up_hint = Vector3.FORWARD
	var target_basis: Basis = Basis.looking_at(current_move_direction, up_hint).orthonormalized()
	var current_quaternion: Quaternion = global_transform.basis.orthonormalized().get_rotation_quaternion()
	var target_quaternion: Quaternion = target_basis.get_rotation_quaternion()
	var blend_weight: float = min(1.0, turn_smoothing_speed * delta)
	global_transform = Transform3D(Basis(current_quaternion.slerp(target_quaternion, blend_weight)).orthonormalized(), global_position)
	head.rotation = Vector3(head_pitch, head_yaw, 0.0)

func _snap_route_orientation() -> void:
	if current_move_direction.length_squared() <= 0.001:
		return

	var up_hint: Vector3 = Vector3.UP
	if absf(current_move_direction.dot(Vector3.UP)) > 0.95:
		up_hint = Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(current_move_direction, up_hint).orthonormalized(), global_position)
	head.rotation = Vector3(head_pitch, head_yaw, 0.0)

func _refresh_junction_preview() -> void:
	if route_network == null or current_node_id == "" or next_node_id == "":
		_clear_junction_preview()
		return

	var segment_length: float = route_network.get_segment_length(current_node_id, next_node_id)
	if segment_length <= 0.0:
		_clear_junction_preview()
		return

	var remaining_distance: float = segment_length - segment_distance
	var turn_options: Dictionary = _build_turn_options(next_node_id, current_node_id)
	if remaining_distance > junction_decision_distance or turn_options.is_empty():
		_clear_junction_preview()
		return

	if tracked_junction_id != next_node_id:
		selected_turn_label = ""
		tracked_junction_id = next_node_id

	available_turn_options = turn_options
	junction_approach_ratio = clamp(1.0 - remaining_distance / junction_decision_distance, 0.0, 1.0)
	if selected_turn_label != "" and not available_turn_options.has(selected_turn_label):
		selected_turn_label = ""
	_capture_preselected_turn()

func _build_turn_options(junction_id: String, incoming_id: String) -> Dictionary:
	var options: Dictionary = {}
	var option_scores: Dictionary = {}
	var neighbors: Array = route_network.get_neighbors(junction_id)
	for neighbor_value in neighbors:
		var neighbor: String = String(neighbor_value)
		if neighbor == incoming_id:
			continue
		var direction: Vector3 = route_network.get_direction(junction_id, neighbor)
		var label: String = _classify_turn_direction(direction)
		if label == "":
			continue
		var score: float = _score_turn_direction(direction, label)
		if not option_scores.has(label) or score > float(option_scores[label]):
			option_scores[label] = score
			options[label] = neighbor
	return options

func _classify_turn_direction(direction: Vector3) -> String:
	if direction.dot(Vector3.UP) > 0.65:
		return "up"
	if direction.dot(Vector3.DOWN) > 0.65:
		return "down"

	var right_vector: Vector3 = _get_turn_right_vector()
	var horizontal_score: float = direction.dot(right_vector)
	if horizontal_score > 0.45:
		return "right"
	if horizontal_score < -0.45:
		return "left"
	return ""

func _score_turn_direction(direction: Vector3, label: String) -> float:
	match label:
		"up", "down":
			return absf(direction.dot(Vector3.UP))
		"left", "right":
			return absf(direction.dot(_get_turn_right_vector()))
		_:
			return 0.0

func _get_turn_right_vector() -> Vector3:
	var body_right: Vector3 = global_transform.basis.x.normalized()
	if body_right.length_squared() > 0.001:
		return body_right
	if absf(current_move_direction.dot(Vector3.UP)) < 0.95:
		var world_right: Vector3 = current_move_direction.cross(Vector3.UP).normalized()
		if world_right.length_squared() > 0.001:
			return world_right
	return Vector3.RIGHT

func _capture_preselected_turn() -> void:
	if Input.is_action_pressed("move_forward") and available_turn_options.has("up"):
		selected_turn_label = "up"
		return
	if Input.is_action_pressed("move_back") and available_turn_options.has("down"):
		selected_turn_label = "down"
		return
	if Input.is_action_pressed("move_left") and available_turn_options.has("left"):
		selected_turn_label = "left"
		return
	if Input.is_action_pressed("move_right") and available_turn_options.has("right"):
		selected_turn_label = "right"

func _clear_junction_preview() -> void:
	available_turn_options.clear()
	selected_turn_label = ""
	junction_approach_ratio = 0.0
	tracked_junction_id = ""

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
