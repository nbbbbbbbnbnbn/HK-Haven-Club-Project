extends CharacterBody2D

@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var sugar_cube_scene: PackedScene = preload("res://Scene/sugar_cubes.tscn")

var speed: float = 250.0
var health: float = 100

func _ready() -> void:
	# Automatically add every spawned ant to the "enemies" group
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if player.reset:
		queue_free()
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
	
	# 4. Update the ant's animation based on movement
	handle_enemy_animation()

func handle_enemy_animation() -> void:
	if velocity.x > 10.0:
		animated_sprite.play("move right")
	elif velocity.x < -10.0:
		animated_sprite.play("move left")
	else:
		animated_sprite.pause()

func take_damage(amount: float) -> void:
	health -= amount
	print("Enemy took ", amount, " damage! Remaining health: ", health)
	
	if health <= 0:
		# Turn completely red upon death
		modulate = Color(1.0, 0.0, 0.0)
		
		# Stop physics processing so it stops moving
		set_physics_process(false)
		
		# THE FIX: Use set_deferred to safely turn off the collision shape
		$CollisionShape2D.set_deferred("disabled", true)
		
		# Spawn sugar cube safely using call_deferred to avoid the physics flushing error
		if sugar_cube_scene:
			var sugarCube = sugar_cube_scene.instantiate()
			sugarCube.global_position = global_position
			get_tree().current_scene.call_deferred("add_child", sugarCube)

		# Wait a brief moment so the player clearly sees the red defeated ant before it vanishes
		await get_tree().create_timer(0.2).timeout
		queue_free()
		
	else:
		# Flash almost completely white when hit
		modulate = Color(5.0, 5.0, 5.0) # High HDR white flash
		
		# Wait a short moment, then return to normal color
		await get_tree().create_timer(0.15).timeout
		modulate = Color(1.0, 1.0, 1.0) # Reset to normal
