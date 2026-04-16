extends CharacterBody3D

@export var move_speed: float = 4.5
@export var boost_speed: float = 7.5
@export var acceleration: float = 7.0
@export var mouse_sensitivity: float = 0.0023
@export var vertical_speed: float = 3.5
@export var water_drag: float = 5.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var player_stats = $PlayerStats

var pitch: float = 0.0
var mouse_delta: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Input.use_accumulated_input = false
	camera.current = true
	camera.cull_mask = 1

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

	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")

	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	forward = forward.normalized()
	right = right.normalized()

	var move_dir: Vector3 = (right * input_x) + (forward * input_z)

	var current_speed := move_speed
	if Input.is_action_pressed("boost"):
		current_speed = boost_speed

	var vertical_dir := 0.0
	if Input.is_action_pressed("move_up"):
		vertical_dir += 1.0
	if Input.is_action_pressed("move_down"):
		vertical_dir -= 1.0

	move_dir += Vector3.UP * vertical_dir
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	var target_velocity := move_dir * current_speed
	target_velocity.y *= vertical_speed / max(current_speed, 0.001)

	velocity = velocity.lerp(target_velocity, acceleration * delta)

	# Mild drag so stopping feels underwater rather than instant.
	velocity.x = lerp(velocity.x, target_velocity.x, (acceleration + water_drag) * delta)
	velocity.y = lerp(velocity.y, target_velocity.y, (acceleration + water_drag * 0.5) * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, (acceleration + water_drag) * delta)

	move_and_slide()

func _apply_mouse_look() -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		mouse_delta = Vector2.ZERO
		return

	if mouse_delta == Vector2.ZERO:
		return

	rotation.y -= mouse_delta.x * mouse_sensitivity
	pitch -= mouse_delta.y * mouse_sensitivity
	pitch = clamp(pitch, deg_to_rad(-80.0), deg_to_rad(80.0))
	head.rotation.x = pitch
	mouse_delta = Vector2.ZERO
