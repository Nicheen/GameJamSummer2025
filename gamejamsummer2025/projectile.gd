extends RigidBody2D

# Projectile settings
var direction: Vector2
var speed: float = 500.0
var play_area_center: Vector2
var play_area_size: Vector2
var bounce_count: int = 0
var max_bounces: int = 5
var lifetime: float = 10.0

# Signals
signal hit_player

# Optional: Visual components
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	# Set up physics
	gravity_scale = 0  # No gravity for projectiles
	linear_damp = 0    # No air resistance
	
	# Set up collision detection
	body_entered.connect(_on_body_entered)
	
	# Start lifetime timer
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_expired)
	add_child(timer)
	timer.start()

func initialize(shoot_direction: Vector2, projectile_speed: float, area_center: Vector2, area_size: Vector2):
	direction = shoot_direction.normalized()
	speed = projectile_speed
	play_area_center = area_center
	play_area_size = area_size
	
	# Set initial velocity
	linear_velocity = direction * speed

func _physics_process(delta):
	check_bounds_collision()

func check_bounds_collision():
	var half_size = play_area_size * 0.5
	var bounds = {
		"left": play_area_center.x - half_size.x,
		"right": play_area_center.x + half_size.x,
		"top": play_area_center.y - half_size.y,
		"bottom": play_area_center.y + half_size.y
	}
	
	var pos = global_position
	var vel = linear_velocity
	var bounced = false
	
	# Check horizontal bounds
	if pos.x <= bounds.left or pos.x >= bounds.right:
		vel.x = -vel.x  # Reverse horizontal velocity
		bounced = true
		
		# Keep within bounds
		if pos.x <= bounds.left:
			pos.x = bounds.left + 5
		else:
			pos.x = bounds.right - 5
	
	# Check vertical bounds
	if pos.y <= bounds.top or pos.y >= bounds.bottom:
		vel.y = -vel.y  # Reverse vertical velocity
		bounced = true
		
		# Keep within bounds
		if pos.y <= bounds.top:
			pos.y = bounds.top + 5
		else:
			pos.y = bounds.bottom - 5
	
	if bounced:
		global_position = pos
		linear_velocity = vel
		bounce_count += 1
		
		# Optional: Add bounce effect
		create_bounce_effect()
		
		# Destroy after too many bounces
		if bounce_count >= max_bounces:
			queue_free()

func create_bounce_effect():
	# Visual effect when bouncing
	if sprite:
		var tween = create_tween()
		var original_scale = sprite.scale
		tween.tween_property(sprite, "scale", original_scale * 1.2, 0.1)
		tween.tween_property(sprite, "scale", original_scale, 0.1)

func _on_body_entered(body):
	# Check if it hit the player
	if body.has_method("take_damage"):
		hit_player.emit()
		queue_free()
	else:
		# Hit something else, bounce off it
		var collision_normal = (global_position - body.global_position).normalized()
		linear_velocity = linear_velocity.bounce(collision_normal)
		bounce_count += 1
		create_bounce_effect()
		
		if bounce_count >= max_bounces:
			queue_free()

func _on_lifetime_expired():
	queue_free()
