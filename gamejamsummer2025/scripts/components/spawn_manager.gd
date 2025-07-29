class_name GameSpawner
extends Node

# Spawner settings
@export var play_area_size: Vector2 = Vector2(1152, 648)
@export var play_area_center: Vector2 = Vector2(576, 324)

# Scene paths
const PLAYER_SCENE = "res://scenes/obj/Player.tscn"
const ENEMY_SCENE = "res://scenes/obj/Enemy.tscn"
const ENEMY_BLOCK_SCENE = "res://scenes/obj/blocks/Block.tscn"
const ENEMY_BLOCK_LAZER_SCENE = "res://scenes/obj/blocks/BlockLazer.tscn"
const BOSS_SCENE = "res://scenes/obj/bosses/Boss1.tscn"

# Spawn configuration
@export var block_count: int = 20
@export var lazer_block_count: int = 10
@export var enemy_count: int = 5

# Spawned entities tracking
var spawned_entities: Dictionary = {
	"player": null,
	"enemies": [],
	"blocks": [],
	"lazer_blocks": [],
	"bosses": []
}

# Spawn positions grid
var all_spawn_positions: Array[Vector2] = []

# Signals
signal entities_spawned
signal spawn_failed(entity_type: String, reason: String)

func _ready():
	generate_spawn_positions()
	print("Spawner ready with ", all_spawn_positions.size(), " spawn positions")

func generate_spawn_positions():
	all_spawn_positions.clear()
	
	# X-positions (15 columns) - matching your current setup
	var x_positions = [926, 876, 826, 776, 726, 676, 626, 576, 526, 476, 426, 376, 326, 276, 226]
	
	# Y-positions (9 rows: 4 above, center, 4 below)
	var y_positions = [124, 174, 224, 274, 324, 374, 424, 474, 524]
	
	# Create all combinations
	for x in x_positions:
		for y in y_positions:
			all_spawn_positions.append(Vector2(x, y))
	
	print("Generated ", all_spawn_positions.size(), " spawn positions")

func spawn_all_entities():
	"""Main function to spawn all game entities in order"""
	print("=== Starting entity spawning sequence ===")
	
	clear_previous_spawns()
	
	# Spawn in order (order matters for position availability)
	spawn_blocks()
	spawn_lazer_blocks()
	spawn_enemies()
	spawn_player()
	
	entities_spawned.emit()
	print("=== Entity spawning complete ===")
	print_spawn_summary()

func clear_previous_spawns():
	"""Clear any previously spawned entities"""
	for category in spawned_entities.keys():
		if category == "player" and spawned_entities[category]:
			spawned_entities[category].queue_free()
			spawned_entities[category] = null
		elif category != "player":
			for entity in spawned_entities[category]:
				if is_instance_valid(entity):
					entity.queue_free()
			spawned_entities[category].clear()

func spawn_blocks():
	"""Spawn regular enemy blocks"""
	var selected_positions = get_random_spawn_positions(block_count)
	
	for pos in selected_positions:
		var block = create_entity(ENEMY_BLOCK_SCENE, pos)
		if block:
			connect_block_signals(block)
			spawned_entities.blocks.append(block)
	
	print("Spawned ", spawned_entities.blocks.size(), " blocks")

func spawn_lazer_blocks():
	"""Spawn lazer blocks in remaining positions"""
	var used_positions = get_used_positions()
	var available_positions = get_available_positions(used_positions)
	
	available_positions.shuffle()
	var spawn_count = min(lazer_block_count, available_positions.size())
	
	for i in range(spawn_count):
		var lazer_block = create_entity(ENEMY_BLOCK_LAZER_SCENE, available_positions[i])
		if lazer_block:
			connect_block_signals(lazer_block)
			spawned_entities.lazer_blocks.append(lazer_block)
	
	print("Spawned ", spawned_entities.lazer_blocks.size(), " lazer blocks")

func spawn_enemies():
	"""Spawn moving enemies in remaining positions"""
	var used_positions = get_used_positions()
	var available_positions = get_available_positions(used_positions)
	
	available_positions.shuffle()
	var spawn_count = min(enemy_count, available_positions.size())
	
	for i in range(spawn_count):
		var enemy = create_entity(ENEMY_SCENE, available_positions[i])
		if enemy:
			connect_enemy_signals(enemy)
			spawned_entities.enemies.append(enemy)
	
	print("Spawned ", spawned_entities.enemies.size(), " enemies")

func spawn_player():
	"""Spawn the player at the bottom center"""
	var player_scene = load(PLAYER_SCENE)
	if not player_scene:
		spawn_failed.emit("player", "Could not load player scene")
		return null
	
	var player = player_scene.instantiate()
	get_tree().current_scene.add_child(player)
	
	# Position player at bottom center
	var bottom_y = play_area_center.y + (play_area_size.y * 0.5) - 50
	player.global_position = Vector2(play_area_center.x, bottom_y)
	
	# Set up player
	if player.has_method("set_play_area"):
		player.set_play_area(play_area_center, play_area_size)
	
	spawned_entities.player = player
	print("Spawned player at: ", player.global_position)
	
	return player

func spawn_boss_at_center():
	"""Spawn a boss at the center position"""
	var center_positions = all_spawn_positions.filter(func(pos): return pos.y == 324)
	if center_positions.is_empty():
		spawn_failed.emit("boss", "No center positions available")
		return null
	
	var boss_pos = center_positions[center_positions.size() / 2]
	var boss = create_entity(BOSS_SCENE, boss_pos)
	
	if boss:
		connect_block_signals(boss)  # Bosses use same signals as blocks
		spawned_entities.bosses.append(boss)
		print("Spawned boss at: ", boss_pos)
	
	return boss

func create_entity(scene_path: String, position: Vector2) -> Node:
	"""Generic entity creation function"""
	var scene = load(scene_path)
	if not scene:
		spawn_failed.emit("entity", "Could not load scene: " + scene_path)
		return null
	
	var entity = scene.instantiate()
	entity.global_position = position
	get_tree().current_scene.add_child(entity)
	
	return entity

func connect_enemy_signals(enemy: Node):
	"""Connect enemy-specific signals"""
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_entity_died)
	if enemy.has_signal("enemy_hit"):
		enemy.enemy_hit.connect(_on_entity_hit)

func connect_block_signals(block: Node):
	"""Connect block-specific signals"""
	if block.has_signal("block_died"):
		block.block_died.connect(_on_entity_died)
	if block.has_signal("block_hit"):
		block.block_hit.connect(_on_entity_hit)

func get_used_positions() -> Array[Vector2]:
	"""Get all currently used spawn positions"""
	var used_positions: Array[Vector2] = []
	
	# Add block positions
	for block in spawned_entities.blocks:
		if is_instance_valid(block):
			used_positions.append(block.global_position)
	
	# Add lazer block positions
	for lazer_block in spawned_entities.lazer_blocks:
		if is_instance_valid(lazer_block):
			used_positions.append(lazer_block.global_position)
	
	# Add boss positions
	for boss in spawned_entities.bosses:
		if is_instance_valid(boss):
			used_positions.append(boss.global_position)
	
	return used_positions

func get_available_positions(used_positions: Array[Vector2]) -> Array[Vector2]:
	"""Get available spawn positions excluding used ones"""
	var used_position_strings: Array[String] = []
	for pos in used_positions:
		used_position_strings.append(str(pos.x) + "," + str(pos.y))
	
	var available_positions: Array[Vector2] = []
	for pos in all_spawn_positions:
		var pos_string = str(pos.x) + "," + str(pos.y)
		if not pos_string in used_position_strings:
			available_positions.append(pos)
	
	return available_positions

func get_random_spawn_positions(count: int) -> Array[Vector2]:
	"""Get random selection of spawn positions"""
	var available_positions = all_spawn_positions.duplicate()
	available_positions.shuffle()
	
	var selected_count = min(count, available_positions.size())
	return available_positions.slice(0, selected_count)

func get_total_enemy_count() -> int:
	"""Get total count of all enemy entities"""
	return (spawned_entities.blocks.size() + 
			spawned_entities.lazer_blocks.size() + 
			spawned_entities.enemies.size() + 
			spawned_entities.bosses.size())

func get_player() -> Node:
	"""Get the spawned player"""
	return spawned_entities.player

func get_all_enemies() -> Array:
	"""Get all enemy entities as a single array"""
	var all_enemies: Array = []
	all_enemies.append_array(spawned_entities.blocks)
	all_enemies.append_array(spawned_entities.lazer_blocks)
	all_enemies.append_array(spawned_entities.enemies)
	all_enemies.append_array(spawned_entities.bosses)
	return all_enemies

func print_spawn_summary():
	"""Print a summary of spawned entities"""
	print("=== Spawn Summary ===")
	print("Blocks: ", spawned_entities.blocks.size())
	print("Lazer Blocks: ", spawned_entities.lazer_blocks.size())
	print("Enemies: ", spawned_entities.enemies.size())
	print("Bosses: ", spawned_entities.bosses.size())
	print("Total Enemies: ", get_total_enemy_count())
	print("Player: ", "Yes" if spawned_entities.player else "No")

# Signal handlers that forward to main game manager
func _on_entity_died(score_points: int):
	# Forward to main scene - this will be connected by main scene
	pass

func _on_entity_hit(damage: int):
	# Forward to main scene - this will be connected by main scene
	pass
