extends RigidBody2D

# Projectile settings
var direction: Vector2
var speed: float = 500.0
var lifetime: float = 8.0
var max_bounces: int = 3
var current_bounces: int = 0

# Bounce settings
var bounce_damping: float = 0.8
var min_velocity: float = 50.0

# World boundaries (should match your play area)
var world_bounds: Rect2 = Rect2(0, 0, 1152, 648)

# Visual effects
@onready var sprite: Sprite2D = $Sprite2D
var original_scale: Vector2

# Signals
signal hit_player
signal bounced(position: Vector2)

func _ready():
	# Set up physics
	gravity_scale = 0
	linear_damp = 0
	
	# Store original scale
	if sprite:
		original_scale = sprite.scale
	
	# Set up collision detection
	contact_monitor = true
	max_contacts_reported = 10
	
	# Connect collision signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	print("Projectile collision setup:")
	print("  - Layer: ", collision_layer)
	print("  - Mask: ", collision_mask)
	
	# Auto-destroy after lifetime
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_destroy_projectile)
	add_child(timer)
	timer.start()

func initialize(shoot_direction: Vector2, projectile_speed: float, area_center: Vector2 = Vector2.ZERO, area_size: Vector2 = Vector2.ZERO):
	direction = shoot_direction.normalized()
	speed = projectile_speed
	
	# Update world bounds if provided
	if area_size != Vector2.ZERO:
		var half_size = area_size * 0.5
		world_bounds = Rect2(area_center - half_size, area_size)
	
	# Set velocity immediately
	linear_velocity = direction * speed
	print("Projectile initialized with velocity: ", linear_velocity)

func _physics_process(delta):
	# Check for world boundary collisions
	check_world_boundaries()
	
	# Ensure minimum velocity to prevent getting stuck
	maintain_minimum_velocity()

func maintain_minimum_velocity():
	var current_velocity = linear_velocity.length()
	if current_velocity > 0 and current_velocity < min_velocity:
		# Boost velocity to minimum while maintaining direction
		var velocity_direction = linear_velocity.normalized()
		linear_velocity = velocity_direction * min_velocity

func check_world_boundaries():
	var pos = global_position
	var vel = linear_velocity
	var bounced = false
	var new_velocity = vel
	
	# Check left and right boundaries
	if pos.x <= world_bounds.position.x or pos.x >= world_bounds.position.x + world_bounds.size.x:
		new_velocity.x = -new_velocity.x
		bounced = true
		pos.x = clamp(pos.x, world_bounds.position.x + 10, world_bounds.position.x + world_bounds.size.x - 10)
	
	# Check top and bottom boundaries
	if pos.y <= world_bounds.position.y or pos.y >= world_bounds.position.y + world_bounds.size.y:
		new_velocity.y = -new_velocity.y
		bounced = true
		pos.y = clamp(pos.y, world_bounds.position.y + 10, world_bounds.position.y + world_bounds.size.y - 10)
	
	if bounced:
		handle_bounce(new_velocity, pos)

func _on_body_entered(body):
	print("Projectile collided with: ", body.name, " on layer: ", body.collision_layer)
	
	# Check if it's the player
	if is_player_target(body):
		print("Hit player - destroying projectile immediately")
		hit_player.emit()
		queue_free()  # Immediate destruction, no animations
		return
	# Check if it's an enemy
	elif is_enemy_target(body):
		print("Hit enemy - destroying projectile immediately")
		if body.has_method("take_damage"):
			body.take_damage(10)
		queue_free()  # Immediate destruction, no animations
		return
	elif body.collision_layer == 4:  # Wall layer
		print("Hit wall - bouncing")
		handle_wall_bounce(body)
	elif body.collision_layer == 2:  # Another projectile
		print("Hit another projectile - bouncing")
		handle_projectile_collision(body)
	else:
		print("Hit unknown object - bouncing")
		handle_generic_bounce()

func handle_projectile_collision(other_projectile):
	# Simple projectile collision without fancy effects
	var collision_normal = (global_position - other_projectile.global_position).normalized()
	
	if collision_normal.length_squared() < 0.1:
		collision_normal = -linear_velocity.normalized()
	
	var reflected_velocity = linear_velocity.reflect(collision_normal)
	linear_velocity = reflected_velocity * bounce_damping
	
	# Separate projectiles
	global_position = other_projectile.global_position + collision_normal * 30
	
	current_bounces += 1
	if current_bounces >= max_bounces:
		queue_free()
		return
	
	bounced.emit(global_position)

func handle_wall_bounce(wall_body):
	# Simple wall bounce calculation
	var collision_normal = -linear_velocity.normalized()
	var reflected_velocity = linear_velocity.reflect(collision_normal)
	
	# Add small random angle to prevent infinite bouncing
	var random_angle = randf_range(-0.2, 0.2)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	handle_bounce(reflected_velocity, global_position)

func handle_generic_bounce():
	var new_velocity = -linear_velocity * bounce_damping
	handle_bounce(new_velocity, global_position)

func handle_bounce(new_velocity: Vector2, new_position: Vector2):
	current_bounces += 1
	
	if current_bounces >= max_bounces:
		queue_free()
		return
	
	linear_velocity = new_velocity * bounce_damping
	global_position = new_position
	
	bounced.emit(global_position)
	print("Projectile bounced! Bounce count: ", current_bounces)

func _destroy_projectile():
	print("Destroying projectile (lifetime expired)")
	queue_free()

func is_player_target(body) -> bool:
	if body.collision_layer == 1:  # Player is on layer 1
		return true
	if body.has_method("take_damage") and "player" in body.name.to_lower():
		return true
	return false

func is_enemy_target(body) -> bool:
	if body.collision_layer == 16:  # Enemy layer
		return true
	if body.has_method("take_damage") and "enemy" in body.name.to_lower():
		return true
	return false
