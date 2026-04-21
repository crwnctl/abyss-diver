extends Area3D

signal collected(relic: Node)

@export var rotate_speed: float = 1.2
@export var bob_height: float = 0.2
@export var bob_speed: float = 1.4
@export var collect_radius: float = 1.0

var start_y: float = 0.0
var elapsed: float = 0.0
var player: Node3D = null
var is_collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	start_y = global_position.y
	player = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	elapsed += delta
	rotate_y(rotate_speed * delta)
	global_position.y = start_y + sin(elapsed * bob_speed) * bob_height
	if is_collected:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player) and player.global_position.distance_to(global_position) <= collect_radius:
		_collect()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collect()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player_sensor"):
		_collect()

func _collect() -> void:
	if is_collected:
		return
	is_collected = true
	collected.emit(self)
	queue_free()

func collect_from_player() -> void:
	_collect()