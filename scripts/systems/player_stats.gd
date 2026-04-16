extends Node

signal oxygen_changed(current: float, max_oxygen: float)
signal oxygen_depleted

@export var max_oxygen: float = 100.0
@export var oxygen_drain_per_second: float = 5.0

var oxygen: float
var is_depleted: bool = false

func _ready() -> void:
	oxygen = max_oxygen
	is_depleted = false
	oxygen_changed.emit(oxygen, max_oxygen)

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
	consume_oxygen(max_oxygen)
