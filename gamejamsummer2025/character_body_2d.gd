extends CharacterBody2D

# Movement settings
@export var speed: float = 300.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

# Teleport settings
@export var teleport_cooldown: float = 0.2
@export var play_area_size: Vector2 = Vector2(1000, 600)
@export var play_area_center: Vector2 = Vector2(500, 300)

# Wall state tracking
enum WallSide { BOTTOM, TOP }
var current_wall: WallSide = WallSide.BOTTOM

# Internal variables
var teleport_timer: float = 0.0
var can_teleport: bool = true

# Optional: Visual feedback
@onready var sprite: Sprite2D = $Sprite2D
var teleport_effect_duration: float = 0.1
var is_teleporting: bool = false

func _ready():
	# Set initial position
	global_position = Vector2(500, 200)

func _physics_process(delta):
	handle_teleport_cooldown(delta)
	handle_movement(delta)
	handle_teleport_input()
	handle_teleport_effect(delta)
	
	# Apply movement
	move_and_slide()

func handle_movement(delta):
	# Get input direction using the Input Map actions
	var input_dir = Input.get_axis("move_left", "move_right")
	
	# Apply movement based on current wall (only top and bottom)
	match current_wall:
		WallSide.BOTTOM:
			# Normal horizontal movement on bottom
			if input_dir != 0:
				velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, friction * delta)
				
		WallSide.TOP:
			# Horizontal movement on top (inverted gravity)
			if input_dir != 0:
				velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_teleport_input():
	if not can_teleport:
		return
	
	var teleport_direction = Vector2.ZERO
	
	# Use Input Map actions for teleporting
	if Input.is_action_just_pressed("teleport_up"):
		teleport_direction = Vector2(0, -1)
	elif Input.is_action_just_pressed("teleport_down"):
		teleport_direction = Vector2(0, 1)
	
	if teleport_direction != Vector2.ZERO:
		teleport_to_edge(teleport_direction)

func teleport_to_edge(direction: Vector2):
	var new_position = global_position
	var half_size = play_area_size * 0.5
	var bounds = {
		"top": play_area_center.y - half_size.y,
		"bottom": play_area_center.y + half_size.y
	}
	
	# Reset velocity when teleporting
	velocity = Vector2.ZERO
	
	# Teleport to edge and update current wall (only up/down)
	if direction.y > 0:  # Teleport down
		new_position.y = bounds.bottom - 50
		current_wall = WallSide.BOTTOM
	elif direction.y < 0:  # Teleport up
		new_position.y = bounds.top + 50
		current_wall = WallSide.TOP
	
	# Apply teleportation
	global_position = new_position
	start_teleport_cooldown()
	start_teleport_effect()
	
	# Update sprite rotation based on wall
	update_sprite_rotation()

func start_teleport_cooldown():
	can_teleport = false
	teleport_timer = teleport_cooldown

func handle_teleport_cooldown(delta):
	if not can_teleport:
		teleport_timer -= delta
		if teleport_timer <= 0:
			can_teleport = true

func start_teleport_effect():
	is_teleporting = true
	if sprite:
		var tween = create_tween()
		tween.tween_method(set_sprite_modulate, Color.WHITE, Color.CYAN, 0.1)
		tween.tween_method(set_sprite_modulate, Color.CYAN, Color.WHITE, 0.1)

func handle_teleport_effect(delta):
	if is_teleporting:
		teleport_effect_duration -= delta
		if teleport_effect_duration <= 0:
			is_teleporting = false
			teleport_effect_duration = 0.1

func set_sprite_modulate(color: Color):
	if sprite:
		sprite.modulate = color

func set_play_area(center: Vector2, size: Vector2):
	play_area_center = center
	play_area_size = size

func update_sprite_rotation():
	if not sprite:
		return
	
	var tween = create_tween()
	var target_rotation = 0.0
	
	match current_wall:
		WallSide.BOTTOM:
			target_rotation = 0.0  # Normal orientation
		WallSide.TOP:
			target_rotation = PI  # Upside down
	
	tween.tween_property(sprite, "rotation", target_rotation, 0.2)
