extends CanvasLayer

@export var low_oxygen_threshold_percent: float = 25.0

@onready var oxygen_label: Label = $MarginContainer/VBoxContainer/OxygenLabel
@onready var oxygen_bar: ProgressBar = $MarginContainer/VBoxContainer/OxygenBar
@onready var low_oxygen_label: Label = $MarginContainer/VBoxContainer/LowOxygenLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var treasure_label: Label = $MarginContainer/VBoxContainer/TreasureLabel
@onready var treasure_bar: ProgressBar = $MarginContainer/VBoxContainer/TreasureBar
@onready var oxygen_depleted_label: Label = $CenterContainer/OxygenDepletedLabel
@onready var win_label: Label = $WinContainer/WinLabel
@onready var minimap_panel: Panel = $MiniMapPanel
@onready var minimap_texture: TextureRect = $MiniMapPanel/MiniMapTexture
@onready var junction_overlay: Control = $JunctionIndicatorOverlay

var low_oxygen_active: bool = false
var warning_time: float = 0.0
var tracked_player: Node = null

func _ready() -> void:
	_set_mouse_ignore(self)
	_configure_minimap_panel()

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

	if tracked_player != null and tracked_player.has_method("get_junction_indicator_state"):
		junction_overlay.call("set_state", tracked_player.get_junction_indicator_state())

func set_oxygen(current: float, max_oxygen: float) -> void:
	oxygen_bar.max_value = max_oxygen
	oxygen_bar.value = current
	if max_oxygen <= 0.0:
		low_oxygen_active = false
		return

	var oxygen_percent := (current / max_oxygen) * 100.0
	low_oxygen_active = oxygen_percent > 0.0 and oxygen_percent <= low_oxygen_threshold_percent

func set_health(current: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current

func set_treasure(current: float, total: float) -> void:
	treasure_bar.max_value = max(total, 1.0)
	treasure_bar.value = current
	treasure_label.text = "Treasure %d/%d" % [int(current), int(total)]

func show_out_of_oxygen() -> void:
	oxygen_depleted_label.visible = true
	win_label.visible = false

func show_win() -> void:
	win_label.visible = true
	oxygen_depleted_label.visible = false

func set_minimap_references(route_network_node, player: Node3D, bubbles: Array, jellyfish: Array) -> void:
	pass

func set_minimap_texture(texture: Texture2D) -> void:
	minimap_texture.texture = texture

func set_player(player: Node) -> void:
	tracked_player = player

func _configure_minimap_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	minimap_panel.add_theme_stylebox_override("panel", style)

func _set_mouse_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_ignore(child)
