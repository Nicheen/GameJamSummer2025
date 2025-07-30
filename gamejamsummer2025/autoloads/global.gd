extends Node

const GRID_SIZE: int = 32
const PLAY_AREA_SIZE: Vector2 = Vector2(1152, 648)  # Match your window size
const PLAY_AREA_CENTER: Vector2 = Vector2(576, 324)  # Half of window size

var save_data:SaveData

func _ready():
	save_data = SaveData.load_or_create()
