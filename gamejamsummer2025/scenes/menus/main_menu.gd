class_name MainMenu extends CanvasLayer

const main_scene:PackedScene = preload("res://scenes/main.tscn")

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(main_scene)

func _on_skill_tree_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/skill_tree.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
