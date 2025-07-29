extends Node2D

# Game settings
@export var play_area_size: Vector2 = Vector2(1152, 648)
@export var play_area_center: Vector2 = Vector2(576, 324)

# Component references
@onready var spawner: GameSpawner = $Components/SpawnManager
@onready var ui_manager: UIManager = $Components/UIManager
@onready var game_manager: GameManager = $Components/GameManager

# Visual components
var grid_background: ColorRect

func _ready():
	print("=== Main Scene Initializing ===")
	
	setup_play_area()
	setup_components()
	
	print("Main scene ready!")

func setup_play_area():
	"""Setup the visual play area"""
	create_grid_background()

func setup_components():
	"""Initialize all game components"""
	
	# Set play area for spawner
	if spawner:
		spawner.play_area_size = play_area_size
		spawner.play_area_center = play_area_center
	
	# Wait for components to be ready, then initialize game
	await get_tree().process_frame
	
	if game_manager and spawner and ui_manager:
		game_manager.initialize_game(spawner, ui_manager)
	else:
		print("ERROR: Missing required components!")
		print("Spawner: ", spawner != null)
		print("UI Manager: ", ui_manager != null) 
		print("Game Manager: ", game_manager != null)

func create_grid_background():
	"""Create the grid background using shader"""
	var background = ColorRect.new()
	background.name = "GridBackground"
	background.anchors_preset = Control.PRESET_FULL_RECT
	background.size = play_area_size
	background.position = Vector2.ZERO
	
	# Try to load and apply grid shader
	var grid_shader = load("res://shaders/grid_shader.gdshader")
	if grid_shader:
		var shader_material = ShaderMaterial.new()
		shader_material.shader = grid_shader
		
		# Set shader parameters
		shader_material.set_shader_parameter("grid_size", 50.0)
		shader_material.set_shader_parameter("line_width", 2.0)
		shader_material.set_shader_parameter("line_color", Color.WHITE)
		shader_material.set_shader_parameter("background_color", Color.BLACK)
		shader_material.set_shader_parameter("line_alpha", 0.3)
		
		background.material = shader_material
		print("Grid shader applied successfully")
	else:
		print("WARNING: Could not load grid shader, using plain background")
		background.color = Color.BLACK
	
	# Add as first child so it renders behind everything
	add_child(background)
	move_child(background, 0)
	grid_background = background

func _input(event):
	"""Handle global input events"""
	# Let pause menu handle ESC key
	pass

# Utility functions for external access
func get_spawner() -> GameSpawner:
	"""Get reference to spawner component"""
	return spawner

func get_ui_manager() -> UIManager:
	"""Get reference to UI manager component"""
	return ui_manager

func get_game_manager() -> GameManager:
	"""Get reference to game manager component"""
	return game_manager

func get_play_area_bounds() -> Rect2:
	"""Get the play area boundaries"""
	var half_size = play_area_size * 0.5
	return Rect2(play_area_center - half_size, play_area_size)
