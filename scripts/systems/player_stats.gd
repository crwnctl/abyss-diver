extends Node

signal oxygen_changed(current: float, max_oxygen: float)
signal oxygen_depleted
signal health_changed(current: float, max_health: float)
signal health_depleted

@export var max_oxygen: float = 100.0
@export var oxygen_drain_per_second: float = 5.0
@export var max_health: float = 100.0

var oxygen: float
var health: float
var is_depleted: bool = false
var is_health_depleted: bool = false

func _ready() -> void:
	oxygen = max_oxygen
	health = max_health
	is_depleted = false
	is_health_depleted = false
	oxygen_changed.emit(oxygen, max_oxygen)
	health_changed.emit(health, max_health)

func drain_oxygen(delta: float) -> void:
	consume_oxygen(oxygen_drain_per_second * delta)

func consume_oxygen(amount: float) -> void:
	oxygen = max(oxygen - amount, 0.0)
	oxygen_changed.emit(oxygen, max_oxygen)

	if oxygen <= 0.0 and not is_depleted:
		is_depleted = true
		oxygen_depleted.emit()

func restore_oxygen(amount: float) -> void:
	oxygen = min(oxygen + amount, max_oxygen)
	if oxygen > 0.0:
		is_depleted = false
	oxygen_changed.emit(oxygen, max_oxygen)

func kill() -> void:
	consume_health(max_health)

func consume_health(amount: float) -> void:
	health = max(health - amount, 0.0)
	health_changed.emit(health, max_health)

	if health <= 0.0 and not is_health_depleted:
		is_health_depleted = true
		health_depleted.emit()

func restore_health(amount: float) -> void:
	health = min(health + amount, max_health)
	if health > 0.0:
		is_health_depleted = false
	health_changed.emit(health, max_health)
