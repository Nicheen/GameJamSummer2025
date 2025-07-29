class_name SceneManager
extends Node

# Scene paths
const MAIN_MENU_SCENE = "res://scenes/menus/main_menu.tscn"
const GAME_SCENE = "res://scenes/main.tscn"
const OPTIONS_SCENE = "res://scenes/menus/options_menu.tscn"  # If you add this later

# Transition settings
@export var transition_duration: float = 0.5
@export var fade_color: Color = Color.BLACK

# Transition overlay
var transition_overlay: ColorRect
var is_transitioning: bool = false

# Signals
signal scene_transition_started(from_scene: String, to_scene: String)
signal scene_transition_finished(scene_name: String)

func _ready():
	setup_transition_overlay()
	print("Scene Manager ready")

func setup_transition_overlay():
	"""Create transition overlay for smooth scene changes"""
	transition_overlay = ColorRect.new()
	transition_overlay.name = "TransitionOverlay"
	transition_overlay.color = fade_color
	transition_overlay.anchors_preset = Control.PRESET_FULL_RECT
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_overlay.modulate = Color.TRANSPARENT
	
	# Add to a CanvasLayer so it renders on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "TransitionLayer"
	canvas_layer.layer = 100  # High layer to render on top
	get_tree().root.add_child(canvas_layer)
	canvas_layer.add_child(transition_overlay)

func change_scene_with_transition(scene_path: String):
	"""Change scene with smooth fade transition"""
	if is_transitioning:
		print("Scene transition already in progress")
		return
	
	is_transitioning = true
	var current_scene_name = get_tree().current_scene.scene_file_path if get_tree().current_scene else "unknown"
	
	scene_transition_started.emit(current_scene_name, scene_path)
	print("Starting transition from ", current_scene_name, " to ", scene_path)
	
	# Fade out
	await fade_out()
	
	# Change scene
	var result = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		print("ERROR: Failed to load scene: ", scene_path)
		is_transitioning = false
		return
	
	# Wait a frame for scene to load
	await get_tree().process_frame
	
	# Fade in
	await fade_in()
	
	is_transitioning = false
	scene_transition_finished.emit(scene_path)
	print("Scene transition completed: ", scene_path)

func fade_out() -> void:
	"""Fade screen to transition color"""
	if not transition_overlay:
		return
	
	var tween = create_tween()
	tween.tween_property(transition_overlay, "modulate", Color.WHITE, transition_duration)
	await tween.finished

func fade_in() -> void:
	"""Fade screen from transition color"""
	if not transition_overlay:
		return
	
	var tween = create_tween()
	tween.tween_property(transition_overlay, "modulate", Color.TRANSPARENT, transition_duration)
	await tween.finished

func change_to_main_menu():
	"""Transition to main menu"""
	change_scene_with_transition(MAIN_MENU_SCENE)

func change_to_game():
	"""Transition to main game scene"""
	change_scene_with_transition(GAME_SCENE)

func restart_current_scene():
	"""Restart the current scene with transition"""
	var current_scene_path = get_tree().current_scene.scene_file_path
	change_scene_with_transition(current_scene_path)

func quick_restart():
	"""Restart current scene without transition (faster)"""
	get_tree().reload_current_scene()

func quit_game():
	"""Quit the game with fade out"""
	if is_transitioning:
		return
	
	print("Quitting game...")
	await fade_out()
	get_tree().quit()

func is_scene_transitioning() -> bool:
	"""Check if a scene transition is in progress"""
	return is_transitioning

func set_transition_duration(duration: float):
	"""Set the transition duration"""
	transition_duration = max(0.1, duration)

func set_transition_color(color: Color):
	"""Set the transition fade color"""
	fade_color = color
	if transition_overlay:
		transition_overlay.color = fade_color

# Convenience functions for common transitions
func to_main_menu_from_game():
	"""Specific transition from game to main menu"""
	# Unpause game before transition
	get_tree().paused = false
	change_to_main_menu()

func restart_game():
	"""Restart game scene specifically"""
	# Unpause game before transition
	get_tree().paused = false
	change_to_game()

# Global access - can be used as autoload later if needed
static var instance: SceneManager

func _enter_tree():
	if not instance:
		instance = self

func _exit_tree():
	if instance == self:
		instance = null
