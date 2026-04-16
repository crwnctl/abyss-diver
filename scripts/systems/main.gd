extends Node3D

const AIR_BUBBLE_SCENE := preload("res://scenes/collectibles/AirBubble.tscn")
const JELLYFISH_SCENE := preload("res://scenes/enemies/Jellyfish.tscn")

const JELLYFISH_CONFIGS := [
	{
		"name": "Jellyfish_Roam",
		"mode": 0,
		"from": "outer_1_e",
		"to": "outer_1_ne",
		"progress": 2.0
	},
	{
		"name": "Jellyfish_Track",
		"mode": 1,
		"from": "inner_1_n",
		"to": "center_1",
		"progress": 1.0
	}
]

@onready var player: CharacterBody3D = $Player
@onready var hud = $HUD
@onready var minimap_rig = $MiniMapRig
@onready var minimap_viewport: SubViewport = $MiniMapViewport
@onready var route_network = $MazeBlockout

var is_game_over: bool = false

func _ready() -> void:
	var spawned_entities: Dictionary = _spawn_route_entities()
	hud.set_minimap_texture(minimap_viewport.get_texture())
	hud.set_player(player)
	minimap_rig.set_player(player)

	var player_stats = player.get_node("PlayerStats")
	player_stats.oxygen_changed.connect(hud.set_oxygen)
	player_stats.oxygen_depleted.connect(_on_player_oxygen_depleted)
	hud.set_oxygen(player_stats.oxygen, player_stats.max_oxygen)

func _on_player_oxygen_depleted() -> void:
	if is_game_over:
		return

	is_game_over = true
	player.set_physics_process(false)
	hud.show_out_of_oxygen()
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func _spawn_route_entities() -> Dictionary:
	var bubble_positions: Array = route_network.get_bubble_positions()
	var bubbles: Array = []
	for index in range(bubble_positions.size()):
		var bubble := AIR_BUBBLE_SCENE.instantiate()
		bubble.name = "Bubble_%02d" % index
		bubble.position = bubble_positions[index] + Vector3.UP * 0.18
		add_child(bubble)
		bubbles.append(bubble)

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
