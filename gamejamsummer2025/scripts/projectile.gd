extends RigidBody2D

# Simple projectile that just flies forward
var direction: Vector2
var speed: float = 500.0
var lifetime: float = 5.0

# Signals
signal hit_player

func _ready():
	# Set up physics
	gravity_scale = 0
	linear_damp = 0
	
	# Set up collision detection
	contact_monitor = true
	max_contacts_reported = 10
	
	# Connect collision signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()
	
	print("Projectile created and ready")

func initialize(shoot_direction: Vector2, projectile_speed: float, area_center: Vector2 = Vector2.ZERO, area_size: Vector2 = Vector2.ZERO):
	direction = shoot_direction.normalized()
	speed = projectile_speed
	
	# Set velocity immediately
	linear_velocity = direction * speed
	print("Projectile initialized with velocity: ", linear_velocity)

func _on_body_entered(body):
	print("Projectile collided with: ", body.name)
	
	# If it hits the player, emit signal and destroy
	if body.has_method("take_damage"):
		print("Hit player - emitting signal")
		hit_player.emit()
		queue_free()
	else:
		# Hit something else, just destroy for now
		print("Hit non-player object, destroying")
		queue_free()
