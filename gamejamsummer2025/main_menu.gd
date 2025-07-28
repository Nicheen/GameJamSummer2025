extends Control

@export var scene_to_start: PackedScene

func _ready():
	# Connect buttons using Godot 4.x syntax
	$VBoxContainer/btn_start.pressed.connect(_on_start_pressed)
	$VBoxContainer/btn_quit.pressed.connect(_on_quit_pressed)
	# If you add options button later:
	# $VBoxContainer/btn_options.pressed.connect(_on_options_pressed)

func _on_start_pressed():
	# Load your game scene - replace with your actual game scene path
	if scene_to_start:
		get_tree().change_scene_to_packed(scene_to_start)
	else:
		print("Error: No start scene assigned!")

func _on_quit_pressed():
	get_tree().quit()

# Optional: If you add an options button
func _on_options_pressed():
	# Load options scene or show options popup
	print("Options pressed - implement later")
	# get_tree().change_scene_to_file("res://Options.tscn")
