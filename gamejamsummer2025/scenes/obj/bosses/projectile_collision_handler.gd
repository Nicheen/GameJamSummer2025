class_name ProjectileCollisionHandler extends Node

# Bounce settings
var bounce_damping: float = 0.8
var max_bounces: int = 3
var current_bounces: int = 0

# Reference to parent projectile
var projectile: RigidBody2D

# Track processed collisions to prevent double-processing
var processed_bodies: Array[RID] = []

func _ready():
	projectile = get_parent().get_parent() as RigidBody2D
	
	# Connect to the correct RigidBody2D signals
	if projectile:
		# Use body_entered for Area2D detection or contact signals for RigidBody2D
		if not projectile.body_entered.is_connected(_on_body_entered):
			var connection_result = projectile.body_entered.connect(_on_body_entered)
			if connection_result != OK:
				print("Warning: Could not connect body_entered signal")
		
		# Also connect to contact monitoring if available
		projectile.contact_monitor = true
		projectile.max_contacts_reported = 10

func _on_body_entered(body):
	handle_collision(body)

# Alternative: Use _integrate_forces for RigidBody2D collision detection
func _integrate_forces(state: PhysicsDirectBodyState2D):
	if not projectile:
		return
		
	# Check for contacts in the physics state
	for i in range(state.get_contact_count()):
		var contact_body = state.get_contact_collider_object(i)
		if contact_body and not _is_body_processed(contact_body):
			_mark_body_processed(contact_body)
			handle_collision(contact_body)

func _is_body_processed(body) -> bool:
	return body.get_rid() in processed_bodies

func _mark_body_processed(body):
	processed_bodies.append(body.get_rid())
	# Clear old processed bodies to prevent memory leaks
	if processed_bodies.size() > 20:
		processed_bodies = processed_bodies.slice(-10)

func handle_collision(body):
	if not body or not projectile:
		return
	
	# Check collision type and handle accordingly
	# Only freeze for enemies and players (destructive collisions)
	if is_enemy_target(body):
		# Freeze to prevent bouncing, then destroy
		if projectile and is_instance_valid(projectile):
			projectile.freeze = true
			projectile.linear_velocity = Vector2.ZERO
			projectile.angular_velocity = 0.0
		handle_enemy_hit(body)
	elif is_player_target(body):
		# Freeze to prevent bouncing, then destroy
		if projectile and is_instance_valid(projectile):
			projectile.freeze = true
			projectile.linear_velocity = Vector2.ZERO
			projectile.angular_velocity = 0.0
		handle_player_hit(body)
	elif is_projectile_target(body):
		# Freeze both projectiles but don't destroy immediately (let explosion play)
		if projectile and is_instance_valid(projectile):
			projectile.freeze = true
			projectile.linear_velocity = Vector2.ZERO
			projectile.angular_velocity = 0.0
		handle_projectile_collision(body)
	elif body.collision_layer == 4:  # Wall layer
		# Don't freeze for walls - allow bouncing
		handle_wall_collision(body)
	else:
		print("Hit unknown object: ", body.name, " with layer: ", body.collision_layer)
		handle_generic_collision(body)

func handle_player_hit(player_body):
	print("=== HIT PLAYER ===")
	if projectile and is_instance_valid(projectile):
		projectile.hit_player.emit()
		projectile.queue_free()

func handle_enemy_hit(enemy_body):
	print("=== HIT ENEMY ===")
	print("Enemy name: ", enemy_body.name)
	print("Enemy class: ", enemy_body.get_class())
	print("Enemy has take_damage method: ", enemy_body.has_method("take_damage"))
	
	# Deal damage to enemy
	var damage_dealt = false
	
	if enemy_body.has_method("take_damage"):
		print("Calling take_damage(10) on enemy")
		enemy_body.take_damage(10)
		damage_dealt = true
	elif enemy_body.has_method("damage"):
		print("Calling damage(10) on enemy")
		enemy_body.damage(10)
		damage_dealt = true
	elif enemy_body.has_method("hit"):
		print("Calling hit(10) on enemy")
		enemy_body.hit(10)
		damage_dealt = true
	else:
		print("WARNING: Enemy has no damage methods!")
		# Force damage by accessing health directly if possible
		if enemy_body.has_method("set") and enemy_body.has_method("get"):
			if "health" in enemy_body:
				var current_health = enemy_body.get("health")
				if current_health != null:
					enemy_body.set("health", current_health - 10)
					print("Forced health reduction to: ", enemy_body.get("health"))
					damage_dealt = true
	
	if damage_dealt:
		print("Damage successfully dealt to enemy")
	else:
		print("Failed to deal damage to enemy")
	
	# Always destroy projectile when hitting enemy
	if projectile and is_instance_valid(projectile):
		print("Destroying projectile after enemy hit")
		projectile.queue_free()

func handle_projectile_collision(other_projectile):
	print("=== PROJECTILE COLLISION DETECTED ===")
	
	# Prevent double-processing of the same collision
	if not is_instance_valid(other_projectile) or not is_instance_valid(projectile):
		return
	
	# Stop both projectiles immediately
	if other_projectile.has_method("freeze"):
		other_projectile.freeze = true
		other_projectile.linear_velocity = Vector2.ZERO
		other_projectile.angular_velocity = 0.0
	
	# Check if this is a defensive save
	var is_defensive_save = check_if_defensive_save(other_projectile)
	
	# Get collision data
	var collision_point = (projectile.global_position + other_projectile.global_position) * 0.5
	var my_velocity = projectile.linear_velocity
	var other_velocity = other_projectile.linear_velocity if other_projectile.has_method("get") else Vector2.ZERO
	
	print("Collision at: ", collision_point)
	print("My velocity: ", my_velocity, " Other velocity: ", other_velocity)
	
	# Create explosion effect FIRST
	if projectile.has_method("create_explosion_at"):
		projectile.create_explosion_at(collision_point, my_velocity, other_velocity)
	
	# Emit signals for achievement tracking
	if projectile.has_signal("projectile_destroyed_by_collision"):
		projectile.projectile_destroyed_by_collision.emit(is_defensive_save)
	if other_projectile.has_signal("projectile_destroyed_by_collision"):
		other_projectile.projectile_destroyed_by_collision.emit(is_defensive_save)
	
	if is_defensive_save:
		print("DEFENSIVE SAVE ACHIEVED!")
	
	# DELAY the destruction to allow explosion animation to play
	print("Starting delayed destruction of both projectiles")
	
	# Hide the projectiles immediately but don't destroy them yet
	if projectile.has_method("set_visible"):
		projectile.set_visible(false)
	if other_projectile.has_method("set_visible"):
		other_projectile.set_visible(false)
	
	# Disable collision on both projectiles
	if projectile.has_method("set_collision_layer"):
		projectile.set_collision_layer(0)
		projectile.set_collision_mask(0)
	if other_projectile.has_method("set_collision_layer"):
		other_projectile.set_collision_layer(0)
		other_projectile.set_collision_mask(0)
	
	# Create a timer to destroy them after explosion animation
	var destruction_timer = Timer.new()
	destruction_timer.wait_time = 0.5  # Adjust this based on your explosion duration
	destruction_timer.one_shot = true
	destruction_timer.timeout.connect(_destroy_projectiles_after_explosion.bind(other_projectile))
	projectile.add_child(destruction_timer)
	destruction_timer.start()

func _destroy_projectiles_after_explosion(other_projectile):
	print("Destroying both projectiles after explosion animation")
	if is_instance_valid(other_projectile):
		other_projectile.queue_free()
	if is_instance_valid(projectile):
		projectile.queue_free()

func handle_wall_collision(wall_body):
	print("=== HANDLING WALL BOUNCE ===")
	print("Wall: ", wall_body.name)
	
	# DON'T freeze for walls - we want bouncing behavior
	# Make sure projectile is unfrozen for bouncing
	if projectile:
		projectile.freeze = false
	
	var collision_normal = calculate_wall_collision_normal(wall_body)
	var reflected_velocity = projectile.linear_velocity.reflect(collision_normal)
	
	# Add randomness to prevent infinite bouncing
	var random_angle = randf_range(-0.2, 0.2)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply bounce with separation
	var separation_distance = 20.0
	var new_position = projectile.global_position + collision_normal * separation_distance
	
	handle_bounce(reflected_velocity, new_position)

func handle_generic_collision(body):
	print("=== GENERIC COLLISION ===")
	print("Hit unknown object - bouncing")
	
	# Unfreeze for bouncing
	if projectile:
		projectile.freeze = false
	
	var new_velocity = -projectile.linear_velocity * bounce_damping
	handle_bounce(new_velocity, projectile.global_position)

func handle_bounce(new_velocity: Vector2, new_position: Vector2):
	current_bounces += 1
	
	# Check bounce limit
	if current_bounces >= max_bounces:
		print("Projectile exceeded max bounces, destroying")
		if projectile and is_instance_valid(projectile):
			projectile.queue_free()
		return
	
	# Apply bounce
	if projectile and is_instance_valid(projectile):
		projectile.freeze = false  # Unfreeze for movement
		projectile.linear_velocity = new_velocity * bounce_damping
		projectile.global_position = new_position
		
		# Emit signal
		if projectile.has_signal("bounced"):
			projectile.bounced.emit(projectile.global_position)
	
	print("Projectile bounced! Count: ", current_bounces, " New velocity: ", new_velocity * bounce_damping)

func calculate_wall_collision_normal(wall_body) -> Vector2:
	var collision_normal = Vector2.ZERO
	
	# Try raycast first
	var space_state = projectile.get_world_2d().direct_space_state
	var ray_query = PhysicsRayQueryParameters2D.create(
		projectile.global_position - projectile.linear_velocity.normalized() * 30,
		projectile.global_position + projectile.linear_velocity.normalized() * 30
	)
	ray_query.collision_mask = 8  # Wall layer mask
	ray_query.exclude = [projectile.get_rid()]
	
	var result = space_state.intersect_ray(ray_query)
	if result and result.has("normal"):
		collision_normal = result.normal
		print("Got collision normal from raycast: ", collision_normal)
	else:
		# Fallback: Calculate from positions
		if wall_body and wall_body.has_method("get_global_position"):
			var wall_pos = wall_body.global_position
			collision_normal = (projectile.global_position - wall_pos).normalized()
			print("Calculated normal from positions: ", collision_normal)
		else:
			# Final fallback
			collision_normal = -projectile.linear_velocity.normalized()
			print("Using velocity-based normal: ", collision_normal)
	
	# Validate normal
	if collision_normal.length_squared() < 0.1:
		collision_normal = -projectile.linear_velocity.normalized()
		print("Fixed invalid normal to: ", collision_normal)
	
	return collision_normal

func check_if_defensive_save(other_projectile) -> bool:
	if not projectile.has_method("get_distance_to_bounds"):
		return false
		
	var my_distance = projectile.get_distance_to_bounds()
	var other_distance = other_projectile.get_distance_to_bounds() if other_projectile.has_method("get_distance_to_bounds") else 999.0
	
	var save_threshold = 100.0
	var is_save = my_distance < save_threshold or other_distance < save_threshold
	
	print("Distance to bounds - Me: ", my_distance, " Other: ", other_distance)
	print("Is defensive save: ", is_save)
	
	return is_save

func is_player_target(body) -> bool:
	print("Checking if player target: ", body.name, " layer: ", body.collision_layer)
	
	if body.collision_layer == 1:  # Player layer
		print("Identified as player by layer")
		return true
	if body.has_method("take_damage") and "player" in body.name.to_lower():
		print("Identified as player by name and method")
		return true
	
	print("Not identified as player")
	return false

func is_enemy_target(body) -> bool:
	print("Checking if enemy target: ", body.name, " layer: ", body.collision_layer)
	
	# Check collision layer first
	if body.collision_layer == 16:  # Enemy layer
		print("Identified as enemy by layer 16")
		return true
	
	# Check for other common enemy layers
	if body.collision_layer == 32:  # Alternative enemy layer
		print("Identified as enemy by layer 32")
		return true
	
	# Check by group membership first (most reliable)
	if body.is_in_group("enemies") or body.is_in_group("enemy"):
		print("Identified as enemy by group membership")
		return true
	
	# Check by name and damage method
	if body.has_method("take_damage"):
		var name_lower = body.name.to_lower()
		if "enemy" in name_lower or "mob" in name_lower or "monster" in name_lower:
			print("Identified as enemy by name and method: ", body.name)
			return true
	
	# Check by script/class name
	if body.get_script():
		var script_path = body.get_script().resource_path
		if "enemy" in script_path.to_lower() or "mob" in script_path.to_lower():
			print("Identified as enemy by script path: ", script_path)
			return true
	
	print("Not identified as enemy")
	return false

func is_projectile_target(body) -> bool:
	print("Checking if projectile target: ", body.name, " layer: ", body.collision_layer)
	
	# Check collision layer
	if body.collision_layer == 2:  # Projectile layer
		print("Identified as projectile by layer 2")
		return true
	
	# Check by group membership
	if body.is_in_group("projectiles") or body.is_in_group("projectile"):
		print("Identified as projectile by group membership")
		return true
	
	# Check by class/script
	if body.get_script():
		var script_path = body.get_script().resource_path
		if "projectile" in script_path.to_lower():
			print("Identified as projectile by script path")
			return true
	
	# Check by name
	if "projectile" in body.name.to_lower():
		print("Identified as projectile by name")
		return true
	
	print("Not identified as projectile")
	return false
