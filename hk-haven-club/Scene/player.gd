extends CharacterBody2D

@export var walk_speed: float = 200.0
@export var launch_power: float = 600.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_curled: bool = false
var is_charging: bool = false
var charge_vector: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# 1. TOGGLE CURL STATE (Holding space or left click)
	if Input.is_action_pressed("curl"):
		is_curled = true
	else:
		is_curled = false

	# 2. MOVEMENT LOGIC BASED ON STATE
	if not is_curled:
		# NORMAL WALKING (Uncurled)
		var input_dir := Input.get_vector("move_left", "move_right", "ui_up", "ui_down")
		velocity.x = input_dir.x * walk_speed
		
		# Apply gravity if airborne
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			# ROLLED UP (Slopes affect you, keys don't control walking)
			# Apply stronger gravity/momentum so slopes feel fast and slippery
			if not is_on_floor():
				velocity += get_gravity() * 1.5 * delta
			else:
				# Add a bit of friction when rolling on flat ground
				velocity.x = move_toward(velocity.x, 0.0, 10.0)
			
		move_and_slide()
		handle_movement_animation(input_dir)
	
func handle_movement_animation(dir):
	
	if dir == Vector2(1,0):
		animated_sprite.play("move right")
	elif dir == Vector2(-1,0):
		pass # move left
	else:
		animated_sprite.pause()
