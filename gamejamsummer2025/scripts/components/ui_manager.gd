class_name UIManager
extends Node

# Menu scene paths
const PAUSE_MENU_SCENE = "res://scenes/menus/pause_menu.tscn"
const DEATH_MENU_SCENE = "res://scenes/menus/death_menu.tscn"
const WIN_MENU_SCENE = "res://scenes/menus/win_menu.tscn"

# UI elements
var score_label: Label
var enemies_remaining_label: Label
var health_label: Label
var ui_layer: CanvasLayer

# Menu references
var pause_menu: Control
var death_menu: Control
var win_menu: Control

# Game state tracking
var current_score: int = 0
var total_enemies: int = 0
var enemies_remaining: int = 0
var player_health: int = 100

# Signals
signal ui_ready

func _ready():
	setup_ui_layer()
	setup_game_ui()
	setup_menus()
	ui_ready.emit()
	print("UI Manager ready")

func setup_ui_layer():
	"""Create the main UI layer"""
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	get_tree().current_scene.add_child(ui_layer)

func setup_game_ui():
	"""Setup in-game UI elements"""
	create_score_label()
	create_enemies_label()
	create_health_label()

func create_score_label():
	"""Create and setup score label"""
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "Score: 0"
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	ui_layer.add_child(score_label)

func create_enemies_label():
	"""Create and setup enemies remaining label"""
	enemies_remaining_label = Label.new()
	enemies_remaining_label.name = "EnemiesLabel"
	enemies_remaining_label.text = "Enemies: 0"
	enemies_remaining_label.position = Vector2(20, 50)
	enemies_remaining_label.add_theme_font_size_override("font_size", 20)
	enemies_remaining_label.add_theme_color_override("font_color", Color.WHITE)
	ui_layer.add_child(enemies_remaining_label)

func create_health_label():
	"""Create and setup health label"""
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "Health: 100"
	health_label.position = Vector2(20, 80)
	health_label.add_theme_font_size_override("font_size", 20)
	health_label.add_theme_color_override("font_color", Color.GREEN)
	ui_layer.add_child(health_label)

func setup_menus():
	"""Setup all game menus"""
	setup_pause_menu()
	setup_death_menu()
	setup_win_menu()

func setup_pause_menu():
	"""Load and setup pause menu"""
	var pause_menu_scene = load(PAUSE_MENU_SCENE)
	if pause_menu_scene:
		pause_menu = pause_menu_scene.instantiate()
		get_tree().current_scene.add_child(pause_menu)
		print("Pause menu setup complete")
	else:
		print("ERROR: Could not load pause menu scene")

func setup_death_menu():
	"""Load and setup death menu"""
	var death_menu_scene = load(DEATH_MENU_SCENE)
	if death_menu_scene:
		death_menu = death_menu_scene.instantiate()
		get_tree().current_scene.add_child(death_menu)
		print("Death menu setup complete")
	else:
		print("ERROR: Could not load death menu scene")

func setup_win_menu():
	"""Load and setup win menu"""
	var win_menu_scene = load(WIN_MENU_SCENE)
	if win_menu_scene:
		win_menu = win_menu_scene.instantiate()
		get_tree().current_scene.add_child(win_menu)
		print("Win menu setup complete")
	else:
		print("ERROR: Could not load win menu scene")

func update_score(new_score: int):
	"""Update the score display"""
	current_score = new_score
	if score_label:
		score_label.text = "Score: " + str(current_score)

func update_enemies_remaining(remaining: int):
	"""Update enemies remaining display"""
	enemies_remaining = remaining
	if enemies_remaining_label:
		enemies_remaining_label.text = "Enemies: " + str(enemies_remaining)

func update_health(new_health: int):
	"""Update health display with color coding"""
	player_health = new_health
	if health_label:
		health_label.text = "Health: " + str(player_health)
		
		# Color code health
		if player_health > 70:
			health_label.add_theme_color_override("font_color", Color.GREEN)
		elif player_health > 30:
			health_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			health_label.add_theme_color_override("font_color", Color.RED)

func set_total_enemies(total: int):
	"""Set the total enemy count for tracking"""
	total_enemies = total
	update_enemies_remaining(total)

func show_death_menu():
	"""Show death menu with final score"""
	if death_menu and death_menu.has_method("show_death_menu"):
		update_death_menu_score()
		death_menu.show_death_menu()
	else:
		print("ERROR: Death menu not available or missing show_death_menu method")

func show_win_menu():
	"""Show win menu with final score"""
	if win_menu and win_menu.has_method("show_win_menu"):
		win_menu.show_win_menu(current_score)
	else:
		print("ERROR: Win menu not available or missing show_win_menu method")

func update_death_menu_score():
	"""Update the score in death menu"""
	if not death_menu:
		return
		
	var score_label_in_death_menu = death_menu.get_node_or_null("Panel/VBoxContainer/ScoreLabel")
	if score_label_in_death_menu:
		score_label_in_death_menu.text = "Final Score: " + str(current_score)

func show_game_over_screen(won: bool):
	"""Show appropriate game over screen"""
	if won:
		show_win_menu()
	else:
		show_death_menu()

func hide_all_menus():
	"""Hide all menu overlays"""
	if pause_menu and pause_menu.visible:
		pause_menu.visible = false
	if death_menu and death_menu.visible:
		death_menu.visible = false
	if win_menu and win_menu.visible:
		win_menu.visible = false

func create_floating_score(position: Vector2, points: int, color: Color = Color.YELLOW):
	"""Create a floating score effect at the given position"""
	var floating_label = Label.new()
	floating_label.text = "+" + str(points)
	floating_label.add_theme_font_size_override("font_size", 18)
	floating_label.add_theme_color_override("font_color", color)
	floating_label.global_position = position
	
	ui_layer.add_child(floating_label)
	
	# Animate the floating effect
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move up and fade out
	tween.tween_property(floating_label, "global_position", position + Vector2(0, -50), 1.0)
	tween.tween_property(floating_label, "modulate", Color.TRANSPARENT, 1.0)
	
	# Clean up after animation
	tween.finished.connect(func(): floating_label.queue_free())

func show_damage_indicator():
	"""Show screen damage effect"""
	if not ui_layer:
		return
	
	# Create red overlay for damage
	var damage_overlay = ColorRect.new()
	damage_overlay.color = Color(1, 0, 0, 0.3)
	damage_overlay.size = Vector2(1152, 648)  # Full screen
	damage_overlay.position = Vector2.ZERO
	ui_layer.add_child(damage_overlay)
	
	# Flash effect
	var tween = create_tween()
	tween.tween_property(damage_overlay, "color", Color.TRANSPARENT, 0.3)
	tween.finished.connect(func(): damage_overlay.queue_free())

func show_level_complete_message():
	"""Show level complete message"""
	var complete_label = Label.new()
	complete_label.text = "LEVEL COMPLETE!"
	complete_label.add_theme_font_size_override("font_size", 48)
	complete_label.add_theme_color_override("font_color", Color.GOLD)
	complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	complete_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	complete_label.size = Vector2(1152, 648)
	complete_label.position = Vector2.ZERO
	
	ui_layer.add_child(complete_label)
	
	# Animate appearance
	complete_label.modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.tween_property(complete_label, "modulate", Color.WHITE, 0.5)
	tween.tween_delay(2.0)
	tween.tween_property(complete_label, "modulate", Color.TRANSPARENT, 0.5)
	tween.finished.connect(func(): complete_label.queue_free())

func get_current_score() -> int:
	"""Get the current score value"""
	return current_score

func get_pause_menu() -> Control:
	"""Get reference to pause menu"""
	return pause_menu

func get_death_menu() -> Control:
	"""Get reference to death menu"""
	return death_menu

func get_win_menu() -> Control:
	"""Get reference to win menu"""
	return win_menu
