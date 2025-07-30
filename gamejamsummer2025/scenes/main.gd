class_name GamePlay extends Node2D

const gameover_scene:PackedScene = preload("res://scenes/menus/game_over.tscn")
const pausemenu_scene:PackedScene = preload("res://scenes/menus/pause_menu.tscn")

@onready var hud: HUD = %HUD as HUD
@onready var player: Player = %PLAYER as Player
@onready var level_manager: LevelManager = %LevelManager as LevelManager

var current_level: int = 1
var enemies_killed: int = 0
var total_enemies: int = 0
var pause_menu: PauseMenu
var gameover_menu: GameOver

# declare getters and setters and more
var score:int:
	get:
		return score
	set(value):
		score = value
		hud.update_score(value)

func _ready():
	level_manager.start_level(current_level)

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		pause_game()

func _on_enemy_hit(damage: int):
	score += damage
	
func _on_enemy_died(score_points: int):
	enemies_killed += 1
	score += score_points

	if enemies_killed >= total_enemies:
		level_manager.level_completed()

func _on_player_died():
	if not gameover_menu:
		gameover_menu = gameover_scene.instantiate() as GameOver
		add_child(gameover_menu)
		gameover_menu.set_score(score)

# handle focus loass
func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		pause_game()

func pause_game():
	if not pause_menu:
		pause_menu = pausemenu_scene.instantiate() as PauseMenu
		add_child(pause_menu)
