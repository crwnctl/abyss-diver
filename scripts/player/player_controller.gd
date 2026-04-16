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

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-80), deg_to_rad(80))
		head.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	player_stats.drain_oxygen(delta)

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var move_dir := Vector3.ZERO
	move_dir += -transform.basis.z * input_2d.y
	move_dir += transform.basis.x * input_2d.x
	move_dir = move_dir.normalized()

	var current_speed := move_speed
	if Input.is_action_pressed("boost"):
		current_speed = boost_speed

	var vertical_dir := 0.0
	if Input.is_action_pressed("move_up"):
		vertical_dir += 1.0
	if Input.is_action_pressed("move_down"):
		vertical_dir -= 1.0

	var target_velocity := move_dir * current_speed
	target_velocity.y = vertical_dir * vertical_speed

	velocity = velocity.lerp(target_velocity, acceleration * delta)

	# Mild drag so stopping feels underwater rather than instant.
	velocity.x = lerp(velocity.x, target_velocity.x, (acceleration + water_drag) * delta)
	velocity.y = lerp(velocity.y, target_velocity.y, (acceleration + water_drag * 0.5) * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, (acceleration + water_drag) * delta)

	move_and_slide()
