extends Node3D

const AIR_BUBBLE_SCENE := preload("res://scenes/collectibles/AirBubble.tscn")
const JELLYFISH_SCENE := preload("res://scenes/enemies/Jellyfish.tscn")

const BUBBLE_POSITIONS := [
	Vector3(-3.0, 1.2, -2.0),
	Vector3(-1.0, 1.5, 1.5),
	Vector3(1.5, 1.3, -1.0),
	Vector3(3.0, 1.4, 2.0),
	Vector3(-7.0, 1.2, 0.0),
	Vector3(-10.0, 1.2, 0.0),
	Vector3(-13.0, 1.3, 0.0),
	Vector3(-16.0, 1.2, 0.0),
	Vector3(-11.5, 1.3, -15.5),
	Vector3(-9.0, 1.2, -13.5),
	Vector3(-8.0, 1.4, -16.0),
	Vector3(-11.0, 1.2, -12.0),
	Vector3(8.0, 1.2, 0.0),
	Vector3(12.0, 1.3, 0.0),
	Vector3(16.0, 1.2, 0.0),
	Vector3(21.0, 1.2, -7.0),
	Vector3(22.5, 1.3, -5.5),
	Vector3(23.0, 1.2, -7.5),
	Vector3(20.0, 1.5, 6.0),
	Vector3(20.0, 3.5, 6.0),
	Vector3(20.0, 5.5, 6.0),
	Vector3(20.0, 7.5, 6.0),
	Vector3(20.0, 9.5, 6.0),
	Vector3(-6.0, 11.2, -6.0),
	Vector3(0.0, 11.3, -7.0),
	Vector3(6.0, 11.1, -5.5),
	Vector3(-6.5, 11.4, 5.5),
	Vector3(0.0, 11.2, 6.5),
	Vector3(6.0, 11.3, 5.0),
	Vector3(-14.0, 11.2, 0.0),
	Vector3(-18.0, 11.2, 0.0),
	Vector3(-25.0, 11.2, -1.5),
	Vector3(-23.0, 11.3, 0.0),
	Vector3(-25.5, 11.1, 1.5),
	Vector3(12.0, 11.2, 0.0),
	Vector3(17.0, 11.2, 0.0),
	Vector3(22.0, 11.2, 0.0),
	Vector3(25.0, 11.3, 0.0),
	Vector3(28.0, 11.5, 0.0),
	Vector3(28.0, 13.5, 0.0),
	Vector3(28.0, 15.5, 0.0),
	Vector3(28.0, 17.5, 0.0),
	Vector3(-20.0, 8.5, -10.0),
	Vector3(-20.0, 5.5, -10.0),
	Vector3(-20.0, 2.5, -10.0),
	Vector3(29.0, 21.2, -1.0),
	Vector3(30.5, 21.2, 1.0),
	Vector3(24.0, 21.1, 0.0),
	Vector3(21.0, 21.2, 0.0),
	Vector3(18.0, 21.1, 0.0),
	Vector3(15.0, 21.2, 0.0),
	Vector3(12.0, 21.3, 0.0),
	Vector3(9.0, 21.2, 0.0),
	Vector3(-1.0, 21.2, -2.0),
	Vector3(4.0, 21.3, -2.0),
	Vector3(-1.0, 21.2, 2.0),
	Vector3(4.0, 21.1, 2.5),
	Vector3(2.0, 21.2, -8.0),
	Vector3(2.0, 21.2, -12.0),
	Vector3(1.0, 21.2, -17.0),
	Vector3(2.5, 21.3, -18.5),
	Vector3(3.5, 21.2, -16.5),
	Vector3(0.0, 18.0, 8.0),
	Vector3(0.0, 15.0, 8.0),
	Vector3(0.0, 12.0, 8.0),
	Vector3(0.0, 9.0, 8.0),
	Vector3(0.0, 6.0, 8.0),
	Vector3(0.0, 3.0, 8.0)
]

const JELLYFISH_SPAWNS := [
	{
		"position": Vector3(6.0, 10.0, 2.0),
		"wander_radius": 7.0,
		"detection_range": 9.0,
		"chase_speed": 4.8
	},
	{
		"position": Vector3(14.0, 20.0, 0.0),
		"wander_radius": 5.0,
		"detection_range": 8.5,
		"chase_speed": 4.4
	}
]

@onready var player: CharacterBody3D = $Player
@onready var hud = $HUD
@onready var minimap_viewport: SubViewport = $MiniMapViewport
@onready var minimap_rig = $MiniMapRig

var is_game_over: bool = false

func _ready() -> void:
	minimap_viewport.size = Vector2i(400, 400)
	minimap_viewport.transparent_bg = true
	minimap_viewport.handle_input_locally = false
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	minimap_viewport.world_3d = get_viewport().world_3d
	hud.set_minimap_texture(minimap_viewport.get_texture())
	_spawn_test_entities()

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

func _spawn_test_entities() -> void:
	for index in range(BUBBLE_POSITIONS.size()):
		var bubble := AIR_BUBBLE_SCENE.instantiate()
		bubble.name = "Bubble_%02d" % index
		bubble.position = BUBBLE_POSITIONS[index]
		add_child(bubble)

	for index in range(JELLYFISH_SPAWNS.size()):
		var config: Dictionary = JELLYFISH_SPAWNS[index]
		var jellyfish := JELLYFISH_SCENE.instantiate()
		jellyfish.name = "Jellyfish_%02d" % index
		jellyfish.position = config["position"]
		jellyfish.wander_radius = config["wander_radius"]
		jellyfish.detection_range = config["detection_range"]
		jellyfish.chase_speed = config["chase_speed"]
		add_child(jellyfish)
