extends CharacterBody2D

@onready var player: CharacterBody2D = get_parent().get_node("Player")
var speed: float = 250.0

func _ready() -> void:
	# Automatically add every spawned ant to the "enemies" group
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	# 1. Apply gravity if not on the floor
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# 2. Chase the player if they exist in the scene
	if player:
		var direction = sign(player.global_position.x - global_position.x)
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
	
	# 3. Move the enemy
	floor_max_angle = deg_to_rad(60.0) # Allows walking up slopes up to 60 degrees
	move_and_slide()
	
func take_damage(amount: int) -> void:
	# Destroy/free the enemy when slammed!
	queue_free()
