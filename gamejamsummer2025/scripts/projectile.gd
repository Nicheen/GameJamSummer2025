extends RigidBody2D

# Projectile settings
var direction: Vector2
var speed: float = 500.0
var lifetime: float = 8.0  # Increased lifetime for bouncing projectiles
var max_bounces: int = 3
var current_bounces: int = 0

# Bounce settings
var bounce_damping: float = 0.8  # Velocity reduction after bounce
var warp_intensity: float = 0.3
var warp_duration: float = 0.2

# Anti-sticking settings
var min_velocity: float = 50.0  # Minimum velocity to maintain
var stuck_timer: float = 0.0
var stuck_threshold: float = 1.0  # Time before considering stuck
var last_position: Vector2
var position_check_timer: float = 0.0

# World boundaries (should match your play area)
var world_bounds: Rect2 = Rect2(0, 0, 1152, 648)

# Visual effects
@onready var sprite: Sprite2D = $Sprite2D
var original_scale: Vector2
var is_warping: bool = false

# Signals
signal hit_player
signal bounced(position: Vector2)

func _ready():
	# Set up physics
	gravity_scale = 0
	linear_damp = 0
	
	# Store original scale for warp effect
	if sprite:
		original_scale = sprite.scale
	
	# Initialize anti-sticking variables
	last_position = global_position
	
	# Set up collision detection for all types of interactions
	contact_monitor = true
	max_contacts_reported = 10
	
	# Connect collision signals for both area and body collisions
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Also listen for RigidBody2D collisions (other projectiles)
	if not body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.connect(_on_body_shape_entered)
	
	# Debug: Print collision setup
	print("Projectile collision setup:")
	print("  - Layer: ", collision_layer)
	print("  - Mask: ", collision_mask)
	print("  - Contact monitor: ", contact_monitor)
	
	# Auto-destroy after lifetime
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_destroy_projectile)
	add_child(timer)
	timer.start()
	
	print("Enhanced projectile created and ready")

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
	
	# Anti-sticking logic
	check_for_stuck_projectile(delta)
	
	# Ensure minimum velocity to prevent getting stuck
	maintain_minimum_velocity()
	
	# Update debug display
	update_debug_display()

func update_debug_display():
	# Update velocity debug label if it exists
	var velocity_label = get_node_or_null("VelocityDebug")
	if velocity_label:
		velocity_label.text = str(int(linear_velocity.length()))

func check_for_stuck_projectile(delta):
	position_check_timer += delta
	
	# Check position every 0.1 seconds
	if position_check_timer >= 0.1:
		var distance_moved = global_position.distance_to(last_position)
		
		# If we haven't moved much, we might be stuck
		if distance_moved < 5.0 and linear_velocity.length() < min_velocity:
			stuck_timer += position_check_timer
			print("Potential stuck projectile - distance moved: ", distance_moved, " velocity: ", linear_velocity.length())
			
			if stuck_timer >= stuck_threshold:
				print("Projectile appears stuck - applying unstuck force")
				unstuck_projectile()
		else:
			stuck_timer = 0.0
		
		last_position = global_position
		position_check_timer = 0.0

func maintain_minimum_velocity():
	var current_velocity = linear_velocity.length()
	if current_velocity > 0 and current_velocity < min_velocity:
		# Boost velocity to minimum while maintaining direction
		var velocity_direction = linear_velocity.normalized()
		linear_velocity = velocity_direction * min_velocity
		print("Boosted projectile velocity to maintain minimum speed")

func unstuck_projectile():
	# Apply a random force to get unstuck
	var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	linear_velocity = random_direction * speed * 0.7
	
	# Move slightly to get out of collision
	global_position += random_direction * 25
	
	# Reset stuck timer
	stuck_timer = 0.0
	
	# Start warp effect to show we're unsticking
	start_warp_effect()
	
	print("Applied unstuck force: ", random_direction, " new velocity: ", linear_velocity)

func check_world_boundaries():
	var pos = global_position
	var vel = linear_velocity
	var bounced = false
	var new_velocity = vel
	
	# Check left and right boundaries
	if pos.x <= world_bounds.position.x or pos.x >= world_bounds.position.x + world_bounds.size.x:
		new_velocity.x = -new_velocity.x
		bounced = true
		
		# Clamp position to stay within bounds
		pos.x = clamp(pos.x, world_bounds.position.x + 10, world_bounds.position.x + world_bounds.size.x - 10)
	
	# Check top and bottom boundaries
	if pos.y <= world_bounds.position.y or pos.y >= world_bounds.position.y + world_bounds.size.y:
		new_velocity.y = -new_velocity.y
		bounced = true
		
		# Clamp position to stay within bounds
		pos.y = clamp(pos.y, world_bounds.position.y + 10, world_bounds.position.y + world_bounds.size.y - 10)
	
	if bounced:
		handle_bounce(new_velocity, pos)

func _on_body_entered(body):
	print("Projectile collided with: ", body.name, " on layer: ", body.collision_layer)
	print("Body type: ", body.get_class())
	
	# Check if it's the player
	if is_player_target(body):
		print("Hit player - emitting signal and destroying projectile")
		hit_player.emit()
		_destroy_projectile()
		return
	# Check if it's an enemy
	elif is_enemy_target(body):
		print("Hit enemy - damaging and destroying projectile")
		if body.has_method("take_damage"):
			body.take_damage(10)  # Deal 10 damage to enemy
		_destroy_projectile()
		return
	elif body.collision_layer == 4:  # Wall layer
		print("Hit wall - bouncing")
		handle_wall_bounce(body)
	elif body.collision_layer == 2:  # Another projectile
		print("Hit another projectile - bouncing")
		handle_projectile_collision(body)
	else:
		print("Hit unknown object on layer ", body.collision_layer, " - bouncing")
		handle_generic_bounce()

func _on_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	print("Shape collision detected with: ", body.name if body else "unknown")
	
	# Additional collision detection for more reliable hits
	if body and is_player_target(body):
		print("Player hit detected via shape collision")
		hit_player.emit()
		_destroy_projectile()
		return
	elif body and is_enemy_target(body):
		print("Enemy hit detected via shape collision")
		if body.has_method("take_damage"):
			body.take_damage(10)
		_destroy_projectile()
		return
	elif body and body.collision_layer == 2 and body != self:  # Another projectile
		print("Projectile-to-projectile shape collision")
		handle_projectile_collision(body)

func handle_projectile_collision(other_projectile):
	# Get collision point and calculate bounce
	var collision_point = global_position
	var other_position = other_projectile.global_position
	
	# Calculate collision normal (from other projectile to this one)
	var collision_normal = (global_position - other_position).normalized()
	
	# If projectiles are too close, use velocity-based normal
	if collision_normal.length_squared() < 0.1:
		collision_normal = -linear_velocity.normalized()
	
	# Calculate reflected velocities for both projectiles
	var my_velocity = linear_velocity
	var other_velocity = other_projectile.linear_velocity
	
	# Simple elastic collision reflection
	var my_new_velocity = my_velocity.reflect(collision_normal)
	var other_new_velocity = other_velocity.reflect(-collision_normal)
	
	# Apply velocities with some damping
	linear_velocity = my_new_velocity * bounce_damping
	if other_projectile.has_method("apply_collision_bounce"):
		other_projectile.apply_collision_bounce(other_new_velocity * bounce_damping)
	else:
		other_projectile.linear_velocity = other_new_velocity * bounce_damping
	
	# Separate projectiles to prevent sticking
	var separation_distance = 30.0
	global_position = other_position + collision_normal * separation_distance
	other_projectile.global_position = other_position - collision_normal * separation_distance
	
	# Visual effects for both projectiles
	start_warp_effect()
	if other_projectile.has_method("start_warp_effect"):
		other_projectile.start_warp_effect()
	
	# Count bounces
	current_bounces += 1
	if current_bounces >= max_bounces:
		print("Projectile exceeded max bounces after projectile collision, destroying")
		_destroy_projectile()
		return
	
	bounced.emit(global_position)
	print("Projectile-to-projectile collision handled")

func apply_collision_bounce(new_velocity: Vector2):
	# Method to allow other projectiles to apply velocity to this one
	linear_velocity = new_velocity
	current_bounces += 1
	start_warp_effect()
	
	if current_bounces >= max_bounces:
		_destroy_projectile()

func handle_wall_bounce(wall_body):
	print("Handling wall bounce with: ", wall_body.name)
	
	# Calculate bounce direction based on collision normal
	var collision_normal = Vector2.ZERO
	
	# Method 1: Try to get collision normal from physics
	var space_state = get_world_2d().direct_space_state
	var ray_query = PhysicsRayQueryParameters2D.create(
		global_position - linear_velocity.normalized() * 30,
		global_position + linear_velocity.normalized() * 30
	)
	ray_query.collision_mask = 8  # Use bit 4 (which is layer 4: 2^3 = 8)
	ray_query.exclude = [get_rid()]  # Exclude self
	
	var result = space_state.intersect_ray(ray_query)
	if result and result.has("normal"):
		collision_normal = result.normal
		print("Got collision normal from raycast: ", collision_normal)
	else:
		# Method 2: Calculate normal based on wall position and projectile position
		if wall_body and wall_body.has_method("get_global_position"):
			var wall_pos = wall_body.global_position
			var to_projectile = (global_position - wall_pos).normalized()
			collision_normal = to_projectile
			print("Calculated normal from positions: ", collision_normal)
		else:
			# Method 3: Simple fallback - reflect velocity
			collision_normal = -linear_velocity.normalized()
			print("Using velocity-based normal: ", collision_normal)
	
	# Ensure we have a valid normal
	if collision_normal.length_squared() < 0.1:
		collision_normal = -linear_velocity.normalized()
		print("Fixed invalid normal to: ", collision_normal)
	
	# Calculate reflection
	var reflected_velocity = linear_velocity.reflect(collision_normal)
	
	# Add some randomness to prevent infinite bouncing in corners
	var random_angle = randf_range(-0.2, 0.2)  # Small random angle
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Original velocity: ", linear_velocity)
	print("Reflected velocity: ", reflected_velocity)
	
	# Apply bounce with slight separation to prevent sticking
	var separation_distance = 20.0
	var new_position = global_position + collision_normal * separation_distance
	
	handle_bounce(reflected_velocity, new_position)

func handle_generic_bounce():
	# Simple bounce by reversing velocity
	var new_velocity = -linear_velocity * bounce_damping
	handle_bounce(new_velocity, global_position)

func handle_bounce(new_velocity: Vector2, new_position: Vector2):
	current_bounces += 1
	
	# Check if we've exceeded max bounces
	if current_bounces >= max_bounces:
		print("Projectile exceeded max bounces, destroying")
		_destroy_projectile()
		return
	
	# Apply new velocity with damping
	linear_velocity = new_velocity * bounce_damping
	global_position = new_position
	
	# Start warp effect
	start_warp_effect()
	
	# Emit bounce signal
	bounced.emit(global_position)
	
	print("Projectile bounced! Bounce count: ", current_bounces, " New velocity: ", linear_velocity)

func start_warp_effect():
	if not sprite or is_warping:
		return
	
	is_warping = true
	
	# Store current values to ensure we return to them
	var start_scale = sprite.scale
	var start_color = sprite.modulate
	var start_rotation = sprite.rotation
	
	# Create sequential warp tween for better control
	var tween = create_tween()
	
	# Phase 1: Compress and flash
	tween.parallel().tween_property(sprite, "scale", original_scale * Vector2(1.5, 0.5), warp_duration * 0.2)
	tween.parallel().tween_property(sprite, "modulate", Color.CYAN, warp_duration * 0.2)
	tween.parallel().tween_property(sprite, "rotation", start_rotation + PI * 0.25, warp_duration * 0.2)
	
	# Phase 2: Expand and spin
	tween.parallel().tween_property(sprite, "scale", original_scale * Vector2(0.7, 1.3), warp_duration * 0.3)
	tween.parallel().tween_property(sprite, "modulate", Color.YELLOW, warp_duration * 0.3)
	tween.parallel().tween_property(sprite, "rotation", start_rotation + PI * 0.5, warp_duration * 0.3)
	
	# Phase 3: Return to normal - ENSURE we return to original values
	tween.parallel().tween_property(sprite, "scale", original_scale, warp_duration * 0.5)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, warp_duration * 0.5)
	tween.parallel().tween_property(sprite, "rotation", start_rotation, warp_duration * 0.5)
	
	# Wait for completion and force reset values
	await tween.finished
	
	# Force reset to ensure values are correct
	if sprite and not is_queued_for_deletion():
		sprite.scale = original_scale
		sprite.modulate = Color.WHITE
		sprite.rotation = start_rotation
	
	is_warping = false

func _destroy_projectile():
	print("Destroying projectile at position: ", global_position)
	
	# Optional: Add destruction effect
	if sprite and not is_queued_for_deletion():
		var tween = create_tween()
		tween.parallel().tween_property(sprite, "modulate", Color.TRANSPARENT, 0.2)
		tween.parallel().tween_property(sprite, "scale", original_scale * 2.0, 0.2)
		await tween.finished
	
	queue_free()

# Force destroy method that can be called externally
func force_destroy():
	print("Force destroying projectile")
	queue_free()

# Method to check if this projectile should hit the player
func is_player_target(body) -> bool:
	# Multiple ways to detect the player
	if body.collision_layer == 1:  # Player is on layer 1
		return true
	if body.has_method("take_damage") and "player" in body.name.to_lower():
		return true
	if body.get_script() and "character_body_2d" in str(body.get_script()).to_lower():
		return true
	return false

# Method to check if this projectile should hit an enemy
func is_enemy_target(body) -> bool:
	# Check for enemies on layer 5 (collision_layer = 16)
	if body.collision_layer == 16:  # Enemy layer
		return true
	if body.has_method("take_damage") and "enemy" in body.name.to_lower():
		return true
	return false

# Optional: Add trail effect
func add_trail_effect():
	# This could be expanded to create a particle trail
	pass
