extends CanvasLayer

@export var low_oxygen_threshold_percent: float = 25.0

@onready var oxygen_label: Label = $MarginContainer/VBoxContainer/Label
@onready var oxygen_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var low_oxygen_label: Label = $MarginContainer/VBoxContainer/LowOxygenLabel
@onready var oxygen_depleted_label: Label = $CenterContainer/OxygenDepletedLabel
@onready var minimap: Control = $TopRightMargin/MinimapPanel/Minimap

var low_oxygen_active: bool = false
var warning_time: float = 0.0

func _process(delta: float) -> void:
	warning_time += delta
	if low_oxygen_active:
		var pulse := 0.55 + 0.45 * sin(warning_time * 6.0)
		oxygen_bar.modulate = Color(1.0, pulse, pulse, 1.0)
		oxygen_label.modulate = Color(1.0, pulse, pulse, 1.0)
		low_oxygen_label.visible = pulse > 0.7
	else:
		oxygen_bar.modulate = Color(1, 1, 1, 1)
		oxygen_label.modulate = Color(1, 1, 1, 1)
		low_oxygen_label.visible = false

func set_oxygen(current: float, max_oxygen: float) -> void:
	oxygen_bar.max_value = max_oxygen
	oxygen_bar.value = current
	if max_oxygen <= 0.0:
		low_oxygen_active = false
		return

	var oxygen_percent := (current / max_oxygen) * 100.0
	low_oxygen_active = oxygen_percent > 0.0 and oxygen_percent <= low_oxygen_threshold_percent

func show_out_of_oxygen() -> void:
	oxygen_depleted_label.visible = true

func set_minimap_references(player: Node3D, jellyfish_nodes: Array, bubble_nodes: Array) -> void:
	minimap.set_tracking(player, jellyfish_nodes, bubble_nodes)
