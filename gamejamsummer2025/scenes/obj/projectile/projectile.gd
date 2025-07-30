extends RigidBody2D

# Core projectile settings
var direction: Vector2
var speed: float = 500.0
var lifetime: float = 8.0
var is_player_projectile: bool = false

# World boundaries - default to your game area
var world_bounds: Rect2 = Rect2(200, 0, 752, 648)  # Your actual play area bounds

# Player reference for damage dealing
var player_reference: Node = null

# Components (now as Node references)
@onready var collision_handler: ProjectileCollisionHandler = $CollisionHandler
@onready var effect_manager: ProjectileEffectManager = $EffectManager

# Visual effects
@onready var sprite: Sprite2D = $Sprite2D
var original_scale: Vector2

# Boundary checking
var boundary_check_enabled: bool = true
var boundary_damage: int = 10

# Signals
signal hit_player
signal bounced(position: Vector2)
signal projectile_destroyed_by_collision(was_save: bool)
signal projectile_exited_bounds(exit_direction: String)

func _ready():
	setup_physics()
	setup_components()
	setup_auto_destroy()
	find_player_reference()
	
	print("Projectile created - Layer: ", collision_layer, " Mask: ", collision_mask)
	print("World bounds set to: ", world_bounds)

func _physics_process(delta):
	if boundary_check_enabled:
		check_world_boundaries()

func setup_physics():
	gravity_scale = 0
	linear_damp = 0
	contact_monitor = true
	max_contacts_reported = 10
	
	if sprite:
		original_scale = sprite.scale

func setup_components():
	# Connect collision signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func setup_auto_destroy():
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_destroy_projectile)
	add_child(timer)
	timer.start()

func find_player_reference():
	# Try to find the player in the scene tree
	var scene_root = get_tree().current_scene
	if scene_root:
		player_reference = scene_root.find_child("Player*", true, false)
		if not player_reference:
			# Alternative search methods
			for child in scene_root.get_children():
				if child.has_method("take_damage") and "player" in child.name.to_lower():
					player_reference = child
					break
		
		if player_reference:
			print("Found player reference: ", player_reference.name)
		else:
			print("Warning: Could not find player reference for boundary damage")

func check_world_boundaries():
	var pos = global_position
	
	# Check if projectile has exited the play area vertically
	if pos.y < world_bounds.position.y:
		# Exited above
		handle_boundary_exit("top")
	elif pos.y > world_bounds.position.y + world_bounds.size.y:
		# Exited below
		handle_boundary_exit("bottom")
	
	# Optional: Also check horizontal bounds for cleanup
	if pos.x < world_bounds.position.x - 100 or pos.x > world_bounds.position.x + world_bounds.size.x + 100:
		# Projectile is far outside horizontal bounds, just destroy it
		print("Projectile exited horizontal bounds, destroying")
		_destroy_projectile()

func handle_boundary_exit(exit_direction: String):
	print("Projectile exited bounds: ", exit_direction, " at position: ", global_position)
	
	# Only damage player for vertical exits (top/bottom)
	if exit_direction == "top" or exit_direction == "bottom":
		damage_player_for_boundary_exit(exit_direction)
	
	# Emit signal for tracking/effects
	projectile_exited_bounds.emit(exit_direction)
	
	# Destroy the projectile
	_destroy_projectile()

func damage_player_for_boundary_exit(exit_direction: String):
	if not player_reference or not player_reference.has_method("take_damage"):
		print("Cannot damage player - no valid player reference")
		return
	
	print("Damaging player for projectile boundary exit: ", exit_direction)
	
	# Deal damage to player
	player_reference.take_damage(boundary_damage)
	
	# Optional: Create visual effect at boundary
	create_boundary_damage_effect(exit_direction)

func create_boundary_damage_effect(exit_direction: String):
	# Create a simple effect to show where the damage occurred
	var effect_position = Vector2.ZERO
	
	match exit_direction:
		"top":
			effect_position = Vector2(global_position.x, world_bounds.position.y)
		"bottom":
			effect_position = Vector2(global_position.x, world_bounds.position.y + world_bounds.size.y)
	
	# You can expand this to create particle effects, screen flash, etc.
	print("Boundary damage effect at: ", effect_position)
	
	# Example: Create a simple visual indicator (you'd need to implement this)
	if effect_manager and effect_manager.has_method("create_boundary_damage_effect"):
		effect_manager.create_boundary_damage_effect(effect_position, exit_direction)

func initialize(shoot_direction: Vector2, projectile_speed: float, area_center: Vector2 = Vector2.ZERO, area_size: Vector2 = Vector2.ZERO, from_player: bool = true):
	direction = shoot_direction.normalized()
	speed = projectile_speed
	is_player_projectile = from_player
	
	# Update world bounds if provided
	if area_size != Vector2.ZERO:
		var half_size = area_size * 0.5
		world_bounds = Rect2(area_center - half_size, area_size)
		print("Updated world bounds to: ", world_bounds)
	else:
		# Use default play area bounds (adjust these to match your game)
		world_bounds = Rect2(200, 0, 752, 648)  # Left wall at x=200, right wall at x=952
		print("Using default world bounds: ", world_bounds)
	
	# Set velocity
	linear_velocity = direction * speed
	print("Projectile initialized - From player: ", from_player, " Velocity: ", linear_velocity)

func set_player_reference(player: Node):
	"""Manually set the player reference if auto-detection fails"""
	player_reference = player
	print("Player reference set manually: ", player.name if player else "null")

func set_boundary_damage(damage: int):
	"""Configure how much damage is dealt when projectiles exit bounds"""
	boundary_damage = damage

func disable_boundary_checking():
	"""Disable boundary damage (useful for special projectile types)"""
	boundary_check_enabled = false

func enable_boundary_checking():
	"""Re-enable boundary damage checking"""
	boundary_check_enabled = true

func _on_body_entered(body):
	if collision_handler:
		collision_handler.handle_collision(body)

func create_explosion_at(position: Vector2, velocity1: Vector2, velocity2: Vector2):
	if effect_manager:
		effect_manager.create_explosion_effect(position, velocity1, velocity2)

func handle_bounce(new_velocity: Vector2, new_position: Vector2):
	if collision_handler:
		collision_handler.handle_bounce(new_velocity, new_position)

func _destroy_projectile():
	print("Destroying projectile at position: ", global_position)
	queue_free()

func force_destroy():
	print("Force destroying projectile")
	queue_free()
