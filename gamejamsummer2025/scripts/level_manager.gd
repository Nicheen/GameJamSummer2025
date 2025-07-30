extends Node

var main_scene: Node2D
var current_level: int = 1

func start_level(level: int):
	current_level = level
	print("Starting level: ", level)
	
	# Rensa tidigare enemies/blocks
	clear_level()
	
	# Spawna nya baserat på level
	spawn_level_content(level)
	
	# Uppdatera UI
	update_level_ui()

func clear_level():
	# Ta bort alla befintliga enemies och blocks
	for enemy in main_scene.enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	for block in main_scene.blocks:
		if is_instance_valid(block):
			block.queue_free()
	
	for lazer_block in main_scene.lazer_blocks:
		if is_instance_valid(lazer_block):
			lazer_block.queue_free()
	
	# Rensa arrays
	main_scene.enemies.clear()
	main_scene.blocks.clear()
	main_scene.lazer_blocks.clear()
	
	# Återställ räknare
	main_scene.enemies_killed = 0
	main_scene.total_enemies = 0

func spawn_level_content(level: int):
	# Beräkna antal enemies baserat på level
	var base_blocks = 15
	var base_enemies = 3
	var base_lazer = 1
	
	# Öka svårighetsgrad varje level
	var blocks_count = base_blocks + (level - 1) * 3  # +3 block per level
	var enemies_count = base_enemies + (level - 1) * 1  # +1 enemy per level  
	var lazer_count = base_lazer + (level - 1) / 3  # +1 lazer var 3:e level
	
	# Max gränser
	blocks_count = min(blocks_count, 40)
	enemies_count = min(enemies_count, 10)
	lazer_count = min(lazer_count, 5)
	
	# Spawna innehåll
	spawn_blocks_for_level(blocks_count)
	spawn_lazer_for_level(lazer_count)  
	spawn_enemies_for_level(enemies_count)
	
	print("Level ", level, " spawned: ", blocks_count, " blocks, ", enemies_count, " enemies, ", lazer_count, " lazer")

func spawn_blocks_for_level(count: int):
	var selected_positions = main_scene.get_random_spawn_positions(count)
	for pos in selected_positions:
		main_scene.spawn_enemy_kvadrat_at_position(pos)

func spawn_lazer_for_level(count: int):
	# Hitta lediga positioner
	var used_positions: Array[Vector2] = []
	for block in main_scene.blocks:
		used_positions.append(block.global_position)
	
	var available_positions = main_scene.all_spawn_positions.filter(
		func(pos): return not pos in used_positions
	)
	
	available_positions.shuffle()
	var spawn_count = min(count, available_positions.size())
	
	for i in range(spawn_count):
		main_scene.spawn_enemy_lazer_at_position(available_positions[i])

func spawn_enemies_for_level(count: int):
	# Samma logik som din befintliga spawn_enemies men med count parameter
	var used_positions: Array[Vector2] = []
	for block in main_scene.blocks:
		used_positions.append(block.global_position)
	for lazer_block in main_scene.lazer_blocks:
		used_positions.append(lazer_block.global_position)
	
	var available_positions = main_scene.all_spawn_positions.filter(
		func(pos): return not pos in used_positions
	)
	
	available_positions.shuffle()
	var spawn_count = min(count, available_positions.size())
	
	for i in range(spawn_count):
		main_scene.spawn_enemy_at_position(available_positions[i])

func update_level_ui():
	# Uppdatera UI för att visa current level
	if main_scene.score_label:
		main_scene.score_label.text = "Level: " + str(current_level) + " | Score: " + str(main_scene.current_score)

func level_completed():
	print("Level ", current_level, " completed!")
	
	# Kort paus innan nästa level
	await get_tree().create_timer(2.0).timeout
	
	current_level += 1
	start_level(current_level)
