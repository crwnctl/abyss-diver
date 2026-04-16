extends Area3D

@export var oxygen_restore_amount: float = 10.0
@export var rotate_speed: float = 1.5
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0

var start_y: float
var time_passed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	start_y = global_position.y

func _process(delta: float) -> void:
	time_passed += delta
	rotate_y(rotate_speed * delta)
	global_position.y = start_y + sin(time_passed * bob_speed) * bob_height

func _on_body_entered(body: Node) -> void:
	if body.has_node("PlayerStats"):
		body.get_node("PlayerStats").restore_oxygen(oxygen_restore_amount)
		queue_free()
