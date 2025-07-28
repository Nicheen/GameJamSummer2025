extends Node2D

# Game settings
@export var play_area_size: Vector2 = Vector2(1152, 648)  # Match your window size
@export var play_area_center: Vector2 = Vector2(576, 324)  # Half of window size

# Hardcoded scene paths
const PLAYER_SCENE = "res://scenes/obj/Player.tscn"
const PAUSE_MENU_SCENE = "res://scenes/menus/pause_menu.tscn" 
const DEATH_MENU_SCENE = "res://scenes/menus/death_menu.tscn"

# Game objects
var player: CharacterBody2D
var pause_menu: Control
var death_menu: Control

func _ready():
	# Set up the game
	setup_play_area()
	spawn_player()
	setup_pause_menu()
	setup_death_menu()
	
	print("Game scene ready!")
	print("Play area center: ", play_area_center)
	print("Play area size: ", play_area_size)

func setup_play_area():
	# Create grid background
	create_grid_background()

func spawn_player():
	# Load and instantiate the player scene
	var player_scene = load(PLAYER_SCENE)
	player = player_scene.instantiate()
	add_child(player)
	
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

func _on_player_died():
	print("Player died! Showing death screen...")
	
	# Show death menu instead of just printing
	if death_menu and death_menu.has_method("show_death_menu"):
		death_menu.show_death_menu()
	else:
		print("ERROR: Death menu not found or doesn't have show_death_menu method!")

func _on_player_health_changed(new_health: int):
	print("Player health: ", new_health)
	# Update UI health display here

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
	
	print("Grid background created successfully")
