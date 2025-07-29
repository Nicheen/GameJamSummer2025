class_name GameManager
extends Node

# Game state
enum GameState {
	INITIALIZING,
	PLAYING,
	PAUSED,
	GAME_OVER,
	VICTORY
}

var current_state: GameState = GameState.INITIALIZING
var current_score: int = 0
var enemies_killed: int = 0
var total_enemies: int = 0
var game_won: bool = false

# Component references
var spawner: GameSpawner
var ui_manager: UIManager
var player: CharacterBody2D

# Signals
signal game_state_changed(old_state: GameState, new_state: GameState)
signal score_changed(new_score: int)
signal enemy_killed(score_points: int)
signal player_died
signal game_won_signal

func _ready():
	print("Game Manager initializing...")

func initialize_game(spawner_ref: GameSpawner, ui_ref: UIManager):
	"""Initialize the game with component references"""
	spawner = spawner_ref
	ui_manager = ui_ref
	
	setup_connections()
	start_game()

func setup_connections():
	"""Setup signal connections between components"""
	if spawner:
		spawner.entities_spawned.connect(_on_entities_spawned)
		spawner.spawn_failed.connect(_on_spawn_failed)
	
	if ui_manager:
		ui_manager.ui_ready.connect(_on_ui_ready)

func start_game():
	"""Start the game sequence"""
	print("Starting game...")
	change_state(GameState.INITIALIZING)
	
	if spawner:
		spawner.spawn_all_entities()

func _on_entities_spawned():
	"""Called when all entities have been spawned"""
	total_enemies = spawner.get_total_enemy_count()
	player = spawner.get_player()
	
	# Connect player signals
	if player:
		connect_player_signals()
	
	# Connect enemy signals
	connect_enemy_signals()
	
	# Update UI
	if ui_manager:
		ui_manager.set_total_enemies(total_enemies)
		ui_manager.update_score(current_score)
		
		if player and player.has_method("get_health"):
			ui_manager.update_health(player.get_health())
	
	change_state(GameState.PLAYING)
	print("Game ready! Total enemies: ", total_enemies)

func connect_player_signals():
	"""Connect signals from the player"""
	if not player:
		return
	
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)

func connect_enemy_signals():
	"""Connect signals from all enemies"""
	var all_enemies = spawner.get_all_enemies()
	
	for enemy in all_enemies:
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_enemy_died)
		elif enemy.has_signal("block_died"):
			enemy.block_died.connect(_on_enemy_died)
		
		if enemy.has_signal("enemy_hit"):
			enemy.enemy_hit.connect(_on_enemy_hit)
		elif enemy.has_signal("block_hit"):
			enemy.block_hit.connect(_on_enemy_hit)

func change_state(new_state: GameState):
	"""Change the game state"""
	var old_state = current_state
	current_state = new_state
	game_state_changed.emit(old_state, new_state)
	
	print("Game state changed: ", GameState.keys()[old_state], " -> ", GameState.keys()[new_state])
	
	# Handle state-specific logic
	match new_state:
		GameState.PLAYING:
			get_tree().paused = false
		GameState.PAUSED:
			get_tree().paused = true
		GameState.GAME_OVER:
			handle_game_over()
		GameState.VICTORY:
			handle_victory()

func handle_game_over():
	"""Handle game over state"""
	get_tree().paused = true
	if ui_manager:
		ui_manager.show_death_menu()
	
	player_died.emit()
	print("Game Over! Final score: ", current_score)

func handle_victory():
	"""Handle victory state"""
	game_won = true
	get_tree().paused = true
	
	if ui_manager:
		ui_manager.show_level_complete_message()
		# Show win menu after a delay
		await get_tree().create_timer(2.5, false).timeout
		ui_manager.show_win_menu()
	
	game_won_signal.emit()
	print("Victory! Final score: ", current_score)

func add_score(points: int, position: Vector2 = Vector2.ZERO):
	"""Add points to the score"""
	current_score += points
	score_changed.emit(current_score)
	
	if ui_manager:
		ui_manager.update_score(current_score)
		
		# Show floating score if position provided
		if position != Vector2.ZERO:
			ui_manager.create_floating_score(position, points)

func _on_player_died():
	"""Handle player death"""
	print("Player died!")
	change_state(GameState.GAME_OVER)

func _on_player_health_changed(new_health: int):
	"""Handle player health changes"""
	if ui_manager:
		ui_manager.update_health(new_health)
		
		# Show damage indicator if health decreased
		if new_health < (player.get_max_health() if player.has_method("get_max_health") else 100):
			ui_manager.show_damage_indicator()

func _on_enemy_died(score_points: int):
	"""Handle enemy death"""
	enemies_killed += 1
	add_score(score_points)
	
	if ui_manager:
		ui_manager.update_enemies_remaining(total_enemies - enemies_killed)
	
	enemy_killed.emit(score_points)
	print("Enemy killed! Score: ", current_score, " Enemies remaining: ", (total_enemies - enemies_killed))
	
	# Check win condition
	if enemies_killed >= total_enemies:
		change_state(GameState.VICTORY)

func _on_enemy_hit(damage: int):
	"""Handle enemy being hit (optional scoring)"""
	add_score(damage)

func _on_spawn_failed(entity_type: String, reason: String):
	"""Handle spawn failures"""
	print("ERROR: Failed to spawn ", entity_type, " - ", reason)

func _on_ui_ready():
	"""Called when UI is ready"""
	print("UI is ready")

func pause_game():
	"""Pause the game"""
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)

func resume_game():
	"""Resume the game"""
	if current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)

func restart_game():
	"""Restart the current scene"""
	get_tree().paused = false
	get_tree().reload_current_scene()

func quit_to_main_menu():
	"""Return to main menu"""
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func is_playing() -> bool:
	"""Check if game is in playing state"""
	return current_state == GameState.PLAYING

func is_paused() -> bool:
	"""Check if game is paused"""
	return current_state == GameState.PAUSED

func is_game_over() -> bool:
	"""Check if game is over"""
	return current_state == GameState.GAME_OVER or current_state == GameState.VICTORY

func get_current_score() -> int:
	"""Get the current score"""
	return current_score

func get_enemies_remaining() -> int:
	"""Get the number of enemies remaining"""
	return total_enemies - enemies_killed

func get_game_state() -> GameState:
	"""Get the current game state"""
	return current_state
