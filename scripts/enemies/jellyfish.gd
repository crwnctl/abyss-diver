extends CharacterBody3D

enum State {
	WANDER,
	CHASE,
	COOLDOWN
}

@export var detection_range: float = 8.0
@export var wander_radius: float = 5.0
@export var wander_speed: float = 1.8
@export var chase_speed: float = 4.6
@export var steering: float = 5.0
@export var contact_oxygen_damage: float = 20.0
@export var hit_cooldown: float = 1.2
@export var visual_bob_height: float = 0.18
@export var visual_bob_speed: float = 2.1
@export var visual_sway_amount: float = 0.12
@export var visual_sway_speed: float = 1.5

@onready var hit_area: Area3D = $HitArea
@onready var visual_mesh: Node3D = $MeshInstance3D

var state: State = State.WANDER
var spawn_origin: Vector3
var wander_target: Vector3
var cooldown_left: float = 0.0
var player: Node3D
var can_hit: bool = true
var visual_time: float = 0.0

func _ready() -> void:
	randomize()
	spawn_origin = global_position
	wander_target = _pick_wander_target()
	player = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	visual_time += delta
	visual_mesh.position.y = sin(visual_time * visual_bob_speed) * visual_bob_height
	visual_mesh.rotation.z = sin(visual_time * visual_sway_speed) * visual_sway_amount

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D

	if state == State.COOLDOWN:
		cooldown_left -= delta
		velocity = velocity.lerp(Vector3.ZERO, steering * delta)
		move_and_slide()
		if cooldown_left <= 0.0:
			state = State.WANDER
			can_hit = true
		return

	var move_target := wander_target
	var target_speed := wander_speed

	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= detection_range:
		state = State.CHASE
		move_target = player.global_position
		target_speed = chase_speed
	else:
		state = State.WANDER
		if global_position.distance_to(wander_target) < 0.8:
			wander_target = _pick_wander_target()

	var desired_velocity := (move_target - global_position).normalized() * target_speed
	velocity = velocity.lerp(desired_velocity, steering * delta)
	move_and_slide()

	_try_contact_damage()

func _try_contact_damage() -> void:
	if not can_hit:
		return

	for body in hit_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_node("PlayerStats"):
			var stats := body.get_node("PlayerStats")
			stats.consume_oxygen(contact_oxygen_damage)
			can_hit = false
			state = State.COOLDOWN
			cooldown_left = hit_cooldown
			break

func _pick_wander_target() -> Vector3:
	var random_offset := Vector3(
		randf_range(-wander_radius, wander_radius),
		randf_range(-1.2, 1.2),
		randf_range(-wander_radius, wander_radius)
	)
	return spawn_origin + random_offset
