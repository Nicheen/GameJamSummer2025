extends Node2D

# Game settings
@export var play_area_size: Vector2 = Vector2(1152, 648)  # Match your window size
@export var play_area_center: Vector2 = Vector2(576, 324)  # Half of window size

# Hardcoded scene paths
const PLAYER_SCENE = "res://scenes/obj/Player.tscn"
const PAUSE_MENU_SCENE = "res://scenes/menus/pause_menu.tscn"

# Game objects
var player: CharacterBody2D
var pause_menu: Control

func _ready():
	# Set up the game
	setup_play_area()
	spawn_player()
	setup_pause_menu()
	
	print("Game scene ready!")
	print("Play area center: ", play_area_center)
	print("Play area size: ", play_area_size)

func setup_play_area():
	# You can draw bounds or set up background here
	# For now, we'll just use the values
	pass

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

func _on_player_died():
	print("Player died! Game over!")
	# Handle game over logic here
	# You could restart the level, show game over screen, etc.

func _on_player_health_changed(new_health: int):
	print("Player health: ", new_health)
	# Update UI health display here
