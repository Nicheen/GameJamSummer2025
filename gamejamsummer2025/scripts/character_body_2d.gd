extends CharacterBody2D

# Movement settings
@export var speed: float = 300.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

# Teleport settings
@export var teleport_cooldown: float = 0.2
@export var play_area_size: Vector2 = Vector2(1000, 600)
@export var play_area_center: Vector2 = Vector2(500, 300)

# Shooting settings
@export var projectile_scene: PackedScene = load("res://scenes/obj/Projectile.tscn")
@export var projectile_speed: float = 500.0
@export var shoot_cooldown: float = 0.3

# Health settings
@export var max_health: int = 100
@export var damage_per_hit: int = 10

# Wall state tracking
enum WallSide { BOTTOM, TOP }
var current_wall: WallSide = WallSide.BOTTOM

# Wall positioning settings
var wall_offset: float = 65.0  # Distance from wall edge to player center

# Internal variables
var teleport_timer: float = 0.0
var can_teleport: bool = true
var shoot_timer: float = 0.0
var can_shoot: bool = true
var current_health: int

# Optional: Visual feedback
@onready var sprite: Sprite2D = $Sprite2D
var teleport_effect_duration: float = 0.1
var is_teleporting: bool = false

# Signals
signal health_changed(new_health: int)
signal player_died

func _ready():
	# Set initial health
	current_health = max_health
	
	# Set initial position at bottom wall
	position_at_current_wall()
	
	# Connect to projectile hits
	connect_to_projectiles()
	
	print("Player initialized at: ", global_position, " on wall: ", current_wall)

func _physics_process(delta):
	handle_teleport_cooldown(delta)
	handle_shoot_cooldown(delta)
	handle_movement(delta)
	handle_teleport_input()
	handle_shoot_input()
	handle_teleport_effect(delta)
	
	# Keep player glued to current wall
	maintain_wall_position()
	
	# Apply movement
	move_and_slide()

func maintain_wall_position():
	# Ensure player stays glued to the current wall
	var half_size = play_area_size * 0.5
	var bounds = {
		"top": play_area_center.y - half_size.y,
		"bottom": play_area_center.y + half_size.y
	}
	
	match current_wall:
		WallSide.BOTTOM:
			global_position.y = bounds.bottom - wall_offset
		WallSide.TOP:
			global_position.y = bounds.top + wall_offset

func position_at_current_wall():
	# Position player at the current wall
	var half_size = play_area_size * 0.5
	var bounds = {
		"top": play_area_center.y - half_size.y,
		"bottom": play_area_center.y + half_size.y
	}
	
	# Start at center horizontally
	var new_position = Vector2(play_area_center.x, global_position.y)
	
	# Position at correct wall
	match current_wall:
		WallSide.BOTTOM:
			new_position.y = bounds.bottom - wall_offset
		WallSide.TOP:
			new_position.y = bounds.top + wall_offset
	
	global_position = new_position

func handle_movement(delta):
	# Get input direction using the Input Map actions
	var input_dir = Input.get_axis("move_left", "move_right")
	
	# Apply horizontal movement only (Y is controlled by wall position)
	if input_dir != 0:
		velocity.x = move_toward(velocity.x, input_dir * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
	
	# No vertical movement - player is glued to walls
	velocity.y = 0

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

func handle_shoot_input():
	if not can_shoot:
		return
	
	# Check for mouse click or shoot action
	if Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("ui_accept"):
		shoot_projectile()

func shoot_projectile():
	if not projectile_scene or not can_shoot:
		return
		
	print("=== SHOOTING PROJECTILE ===")
	
	# Get shoot direction toward mouse
	var mouse_pos = get_global_mouse_position()
	var shoot_direction = (mouse_pos - global_position).normalized()
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	
	# Position it in front of player
	var spawn_position = global_position + (shoot_direction * 80)
	projectile.global_position = spawn_position
	
	print("Spawning projectile at: ", spawn_position)
	print("Shoot direction: ", shoot_direction)
	
	# Add to scene first
	get_tree().current_scene.add_child(projectile)
	
	# Wait one frame then initialize
	await get_tree().process_frame
	
	# Initialize the projectile with play area bounds
	projectile.initialize(shoot_direction, projectile_speed, play_area_center, play_area_size)
	
	# Connect the hit signal
	if projectile.has_signal("hit_player"):
		var connection_result = projectile.hit_player.connect(_on_projectile_hit)
		if connection_result == OK:
			print("Successfully connected projectile hit signal")
		else:
			print("Failed to connect projectile hit signal: ", connection_result)
	else:
		print("ERROR: Projectile doesn't have hit_player signal!")
	
	print("Projectile setup complete")
	
	# Start cooldown
	start_shoot_cooldown()

func teleport_to_edge(direction: Vector2):
	var new_position = global_position
	var half_size = play_area_size * 0.5
	var bounds = {
		"top": play_area_center.y - half_size.y,
		"bottom": play_area_center.y + half_size.y
	}
	
	# Reset velocity when teleporting
	velocity = Vector2.ZERO
	
	# Store previous wall for comparison
	var previous_wall = current_wall
	
	# Teleport based on direction, not current wall state
	if direction.y > 0:  # Teleport down (to bottom wall)
		new_position.y = bounds.bottom - wall_offset
		current_wall = WallSide.BOTTOM
		
		# If already at bottom, teleport to center horizontally for repositioning
		if previous_wall == WallSide.BOTTOM:
			new_position.x = play_area_center.x
			print("Repositioned on BOTTOM wall")
		else:
			print("Teleported to BOTTOM wall")
			
	elif direction.y < 0:  # Teleport up (to top wall)
		new_position.y = bounds.top + wall_offset
		current_wall = WallSide.TOP
		
		# If already at top, teleport to center horizontally for repositioning
		if previous_wall == WallSide.TOP:
			new_position.x = play_area_center.x
			print("Repositioned on TOP wall")
		else:
			print("Teleported to TOP wall")
	
	# Apply teleportation
	global_position = new_position
	start_teleport_cooldown()
	start_teleport_effect()
	
	# NO MORE SPRITE ROTATION - removed the call to update_sprite_rotation()

func start_teleport_cooldown():
	can_teleport = false
	teleport_timer = teleport_cooldown

func handle_teleport_cooldown(delta):
	if not can_teleport:
		teleport_timer -= delta
		if teleport_timer <= 0:
			can_teleport = true

func start_shoot_cooldown():
	can_shoot = false
	shoot_timer = shoot_cooldown

func handle_shoot_cooldown(delta):
	if not can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true

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
	
	# Reposition player at current wall with new bounds
	position_at_current_wall()
	
	print("Play area updated - player repositioned at: ", global_position)

# REMOVED: update_sprite_rotation() function completely
# The player sprite will no longer rotate when teleporting

func connect_to_projectiles():
	# This function can be used to connect to existing projectiles if needed
	pass

func _on_projectile_hit():
	print("PLAYER HIT BY PROJECTILE!")
	take_damage(damage_per_hit)

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	
	# Emit health changed signal
	health_changed.emit(current_health)
	
	# Visual damage feedback
	if sprite:
		var tween = create_tween()
		tween.tween_method(set_sprite_modulate, Color.WHITE, Color.RED, 0.1)
		tween.tween_method(set_sprite_modulate, Color.RED, Color.WHITE, 0.1)
	
	# Check if player died
	if current_health <= 0:
		player_died.emit()
		print("Player died!")

func heal(amount: int):
	current_health += amount
	current_health = min(max_health, current_health)
	health_changed.emit(current_health)

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health
