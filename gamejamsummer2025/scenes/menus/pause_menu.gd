class_name PauseMenu extends CanvasLayer

const main_menu_scene:PackedScene = preload("res://scenes/menus/main_menu.tscn")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		queue_free()

func _on_resume_button_pressed() -> void:
	queue_free()

func _on_options_button_pressed() -> void:
	pass # Replace with function body.

func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_packed(main_menu_scene)
