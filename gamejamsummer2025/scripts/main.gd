extends Node2D

# Game settings
@export var play_area_size: Vector2 = Vector2(1152, 648)  # Match your window size
@export var play_area_center: Vector2 = Vector2(576, 324)  # Half of window size

# Hardcoded scene paths
const PLAYER_SCENE = "res://scenes/obj/Player.tscn"
const ENEMY_SCENE = "res://scenes/obj/Enemy.tscn"
const PAUSE_MENU_SCENE = "res://scenes/menus/pause_menu.tscn" 
const DEATH_MENU_SCENE = "res://scenes/menus/death_menu.tscn"
const WIN_MENU_SCENE = "res://scenes/menus/win_menu.tscn"

# Game objects
var player: CharacterBody2D
var pause_menu: Control
var death_menu: Control
var win_menu: Control
var enemies: Array[CharacterBody2D] = []

# Game state
var current_score: int = 0
var enemies_killed: int = 0
var total_enemies: int = 0
var game_won: bool = false

# UI elements
var score_label: Label
var enemies_remaining_label: Label

func _ready():
	# Set up the game
	setup_play_area()
	spawn_enemies()
	spawn_player()
	setup_pause_menu()
	setup_death_menu()
	setup_win_menu()
	setup_ui()
	
	print("Game scene ready!")
	print("Total enemies spawned: ", total_enemies)

func setup_play_area():
	# Create grid background
	create_grid_background()
	
func spawn_enemies():
	# Spawn enemies in the middle area
	var enemy_positions = [
		Vector2(576, 324),  # Center of screen
		Vector2(400, 250),  # Left-center
		Vector2(750, 250),  # Right-center
		Vector2(576, 200),  # Upper-center
		Vector2(576, 450),  # Lower-center
	]
	
	for pos in enemy_positions:
		spawn_enemy_at_position(pos)

func spawn_enemy_at_position(position: Vector2):
	var enemy_scene = load(ENEMY_SCENE)
	if not enemy_scene:
		print("ERROR: Could not load enemy scene at: ", ENEMY_SCENE)
		return
	
	var enemy = enemy_scene.instantiate()
	enemy.global_position = position
	
	# Connect enemy signals
	enemy.enemy_died.connect(_on_enemy_died)
	enemy.enemy_hit.connect(_on_enemy_hit)
	
	add_child(enemy)
	enemies.append(enemy)
	total_enemies += 1
	
	print("Spawned enemy at: ", position)
	
func spawn_player():
	# Load and instantiate the player scene
	var player_scene = load(PLAYER_SCENE)
	player = player_scene.instantiate()
	add_child(player)
	
	# Set player position to center bottom
	var bottom_y = play_area_center.y + (play_area_size.y * 0.5) - 50  # 50px från botten
	player.global_position = Vector2(play_area_center.x, bottom_y)
	
	# Set up the player
	if player.has_method("set_play_area"):
		player.set_play_area(play_area_center, play_area_size)
		print("Set player play area")
	
	# Connect player signals
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)

func setup_pause_menu():
	# Load and instantiate the pause menu
	var pause_menu_scene = load(PAUSE_MENU_SCENE)
	pause_menu = pause_menu_scene.instantiate()
	add_child(pause_menu)
	
	print("Pause menu setup complete")

func setup_death_menu():
	# Load and instantiate the death menu
	var death_menu_scene = load(DEATH_MENU_SCENE)
	death_menu = death_menu_scene.instantiate()
	add_child(death_menu)
	
	print("Death menu setup complete")

func setup_win_menu():
	# Load and instantiate the win menu
	var win_menu_scene = load(WIN_MENU_SCENE)
	win_menu = win_menu_scene.instantiate()
	add_child(win_menu)
	
	print("Win menu setup complete")
	
func setup_ui():
	# Create UI layer
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	
	# Score label
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 24)
	ui_layer.add_child(score_label)
	
	# Enemies remaining label
	enemies_remaining_label = Label.new()
	enemies_remaining_label.text = "Enemies: " + str(total_enemies)
	enemies_remaining_label.position = Vector2(20, 50)
	enemies_remaining_label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(enemies_remaining_label)
	
func _on_player_died():
	print("Player died! Final score: ", current_score)
	
	# Show death menu with score
	if death_menu and death_menu.has_method("show_death_menu"):
		# Update score display in death menu
		update_death_menu_score()
		death_menu.show_death_menu()
		
func _on_enemy_died(score_points: int):
	enemies_killed += 1
	current_score += score_points
	
	print("Enemy killed! Score: ", current_score, " Enemies remaining: ", (total_enemies - enemies_killed))
	
	# Update UI
	update_ui()
	
	# Check win condition
	if enemies_killed >= total_enemies:
		player_wins()
		
func _on_enemy_hit(damage: int):
	# Optional: Add score for hitting enemies
	current_score += damage
	update_ui()
	
func _on_player_health_changed(new_health: int):
	print("Player health: ", new_health)

func player_wins():
	game_won = true
	print("PLAYER WINS! Final score: ", current_score)
	
	# Show win menu with score
	if win_menu and win_menu.has_method("show_win_menu"):
		win_menu.show_win_menu(current_score)

func update_death_menu_score():
	# Update the score label in death menu
	var score_label_in_death_menu = death_menu.get_node_or_null("Panel/VBoxContainer/ScoreLabel")
	if score_label_in_death_menu:
		score_label_in_death_menu.text = "Final Score: " + str(current_score)
			
func update_ui():
	if score_label:
		score_label.text = "Score: " + str(current_score)
	
	if enemies_remaining_label:
		var remaining = total_enemies - enemies_killed
		enemies_remaining_label.text = "Enemies: " + str(remaining)
		
func create_grid_background():
	# Create a ColorRect that covers the entire screen
	var background = ColorRect.new()
	background.name = "GridBackground"
	background.anchors_preset = Control.PRESET_FULL_RECT
	background.size = play_area_size
	background.position = Vector2.ZERO
	
	# Create shader material
	var shader_material = ShaderMaterial.new()
	
	# Try to load the shader file
	var grid_shader = load("res://shaders/grid_shader.gdshader")
	if grid_shader == null:
		print("ERROR: Could not load grid shader at res://shaders/grid_shader.gdshader")
		print("Make sure the shader file exists in the shaders folder")
		return
	
	shader_material.shader = grid_shader
	
	# Set shader parameters
	shader_material.set_shader_parameter("grid_size", 50.0)
	shader_material.set_shader_parameter("line_width", 2.0)
	shader_material.set_shader_parameter("line_color", Color.WHITE)
	shader_material.set_shader_parameter("background_color", Color.BLACK)
	shader_material.set_shader_parameter("line_alpha", 0.3)
	
	# Apply material to background
	background.material = shader_material
	
	# Add as first child so it renders behind everything
	add_child(background)
	move_child(background, 0)
