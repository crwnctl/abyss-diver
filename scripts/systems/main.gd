extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hud = $HUD

var is_game_over: bool = false

func _ready() -> void:
	var player_stats = player.get_node("PlayerStats")
	player_stats.oxygen_changed.connect(hud.set_oxygen)
	player_stats.oxygen_depleted.connect(_on_player_oxygen_depleted)
	hud.set_oxygen(player_stats.oxygen, player_stats.max_oxygen)
	hud.set_minimap_references(player, get_tree().get_nodes_in_group("jellyfish"), get_tree().get_nodes_in_group("bubble"))

func _on_player_oxygen_depleted() -> void:
	if is_game_over:
		return

	is_game_over = true
	player.set_physics_process(false)
	hud.show_out_of_oxygen()
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
