extends Node3D

const AIR_BUBBLE_SCENE := preload("res://scenes/collectibles/AirBubble.tscn")
const GOLD_RELIC_SCENE := preload("res://scenes/collectibles/GoldRelic.tscn")
const JELLYFISH_SCENE := preload("res://scenes/enemies/Jellyfish.tscn")

const JELLYFISH_CONFIGS := [
	{
		"name": "Jellyfish_Roam",
		"mode": 0,
		"from": "grid_2_1_1",
		"to": "grid_2_1_2",
		"progress": 1.4
	},
	{
		"name": "Jellyfish_Track",
		"mode": 1,
		"from": "grid_1_1_0",
		"to": "grid_1_1_1",
		"progress": 0.8
	},
	{
		"name": "Jellyfish_Ambush",
		"mode": 2,
		"from": "grid_0_2_1",
		"to": "grid_0_2_2",
		"progress": 0.6
	}
]

@onready var player: CharacterBody3D = $Player
@onready var hud = $HUD
@onready var minimap_rig = $MiniMapRig
@onready var minimap_viewport: SubViewport = $MiniMapViewport
@onready var route_network = $MazeBlockout

var is_game_over: bool = false
var relics_collected: int = 0
var relic_total: int = 0

func _ready() -> void:
	randomize()
	var spawned_entities: Dictionary = _spawn_route_entities()
	hud.set_minimap_texture(minimap_viewport.get_texture())
	hud.set_player(player)
	minimap_rig.set_player(player)

	var player_stats = player.get_node("PlayerStats")
	player_stats.oxygen_changed.connect(hud.set_oxygen)
	player_stats.health_changed.connect(hud.set_health)
	player_stats.oxygen_depleted.connect(_on_player_oxygen_depleted)
	player_stats.health_depleted.connect(_on_player_health_depleted)
	hud.set_oxygen(player_stats.oxygen, player_stats.max_oxygen)
	hud.set_health(player_stats.health, player_stats.max_health)
	hud.set_treasure(relics_collected, relic_total)

func _on_player_oxygen_depleted() -> void:
	if is_game_over:
		return

	is_game_over = true
	player.set_physics_process(false)
	hud.show_out_of_oxygen()
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func _on_player_health_depleted() -> void:
	if is_game_over:
		return

	is_game_over = true
	player.set_physics_process(false)
	hud.show_out_of_oxygen()
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func _on_relic_collected(_relic: Node) -> void:
	relics_collected += 1
	hud.set_treasure(relics_collected, relic_total)
	if relics_collected >= relic_total and relic_total > 0 and not is_game_over:
		is_game_over = true
		player.set_physics_process(false)
		hud.show_win()

func _spawn_route_entities() -> Dictionary:
	var bubble_positions: Array = route_network.get_bubble_positions()
	var bubbles: Array = []
	for index in range(bubble_positions.size()):
		var bubble := AIR_BUBBLE_SCENE.instantiate()
		bubble.name = "Bubble_%02d" % index
		bubble.position = bubble_positions[index] + Vector3.UP * 0.18
		add_child(bubble)
		bubbles.append(bubble)

	var relic_positions: Array = _pick_relic_positions(bubble_positions)
	relic_total = relic_positions.size()
	for index in range(relic_positions.size()):
		var relic: Area3D = GOLD_RELIC_SCENE.instantiate()
		relic.name = "Relic_%02d" % index
		relic.position = relic_positions[index] + Vector3.UP * 0.3
		relic.collected.connect(_on_relic_collected)
		add_child(relic)

	var jellyfish_nodes: Array = []
	for config in JELLYFISH_CONFIGS:
		var jellyfish: Node3D = JELLYFISH_SCENE.instantiate()
		jellyfish.name = config["name"]
		jellyfish.set("ai_mode", config["mode"])
		jellyfish.set("start_from_node", config["from"])
		jellyfish.set("start_to_node", config["to"])
		jellyfish.set("start_progress", config["progress"])
		add_child(jellyfish)
		jellyfish_nodes.append(jellyfish)

	return {
		"bubbles": bubbles,
		"jellyfish": jellyfish_nodes
	}

func _pick_relic_positions(candidate_positions: Array) -> Array:
	var shuffled_positions: Array = candidate_positions.duplicate()
	shuffled_positions.shuffle()
	var selected_positions: Array = []
	for position_value in shuffled_positions:
		var candidate_position: Vector3 = position_value
		if candidate_position.distance_to(player.global_position) < 10.0:
			continue
		var is_far_enough: bool = true
		for chosen_position in selected_positions:
			if candidate_position.distance_to(chosen_position) < 10.0:
				is_far_enough = false
				break
		if is_far_enough:
			selected_positions.append(candidate_position)
		if selected_positions.size() >= 2:
			break
	return selected_positions
