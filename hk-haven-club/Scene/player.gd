extends CharacterBody2D

@export var walk_speed: float = 300.0          # Walk speed is 300
@export var min_launch_power: float = 300.0  # Minimum launch speed on a quick click
@export var max_launch_power: float = 1500.0 # Maximum launch speed cap
@export var charge_speed: float = 1200.0     # How fast the power builds up while holding click
@export var roll_friction: float = 100.0     # Lowered friction so it keeps momentum longer
@export var roll_acceleration: float = 1900.0 # Much higher acceleration for faster rolling
@export var launch_cooldown: float = 5.0     # 5 seconds cooldown for the launch

# Speed threshold required to deal damage and bounce off enemies
@export var impact_speed_threshold: float = 600.0 
@export var bounce_power: float = -1000.0     # Upward bounce velocity when slamming an enemy

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arrow: Node2D = $Node2D

var is_curled: bool = false
var is_charging: bool = false
var current_launch_power: float = 0.0
var cooldown_timer: float = 0.0

func _physics_process(delta: float) -> void:
	
	# Decrease the cooldown timer every frame if it's running
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
	# 1. SPACEBAR: CURL / UN-CURL TOGGLE STATE
	if Input.is_action_pressed("curl"):
		is_curled = true
	else:
		# Releasing spacebar instantly uncurls you and stops any charging
		is_curled = false
		is_charging = false
		arrow.visible = false
	
	# 2. LEFT CLICK CHARGING & LAUNCH (ONLY allowed if you are curled up!)
	if is_curled:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and cooldown_timer <= 0:
			if not is_charging:
				is_charging = true
				current_launch_power = min_launch_power
				
			arrow.visible = true
			arrow.look_at(get_global_mouse_position())
			
			# Freeze movement while charging up your shot
			velocity = Vector2.ZERO
			
			# Increase launch power the longer you hold click, capped at max_launch_power
			current_launch_power += charge_speed * delta
			current_launch_power = min(current_launch_power, max_launch_power)
		else:
			arrow.visible = false
			
			# If we WERE charging and just released the click, LAUNCH!
			if is_charging:
				is_charging = false
				var mouse_pos = get_global_mouse_position()
				var launch_dir = (mouse_pos - global_position).normalized()
				
				# Send the roly-poly flying using the accumulated charge power
				velocity = launch_dir * current_launch_power
				
				# Start the 5-second cooldown timer!
				cooldown_timer = launch_cooldown
	else:
		arrow.visible = false
		is_charging = false

	# 3. STATE-BASED MOVEMENT & GRAVITY
	if is_curled:
		# ==========================
		# ROLLED UP / AIRBORNE STATE
		# ==========================
		if not is_on_floor():
			# Apply heavy gravity so it arcs fast through the air
			velocity += get_gravity() * 1.8 * delta
		else:
			# Get the angle of the slope we are standing on
			var floor_normal = get_floor_normal()
			var slope_direction = Vector2(floor_normal.y, -floor_normal.x)
			
			# If we are on a slope, accelerate rapidly downwards and add gravity weight
			if abs(floor_normal.x) > 0.1:
				velocity += slope_direction * -sign(floor_normal.x) * roll_acceleration * delta
				velocity += get_gravity() * 0.8 * delta # Pulls you down the hill faster
			else:
				# Apply light friction when on completely flat ground
				velocity.x = move_toward(velocity.x, 0.0, roll_friction * delta)
				
		handle_movement_animation()
				
	else:
		# ==========================
		# NORMAL WALKING STATE
		# ==========================
		var input_dir := Input.get_vector("move_left", "move_right", "ui_up", "ui_down")
		velocity.x = input_dir.x * walk_speed
		
		# Apply gravity if airborne normally
		if not is_on_floor():
			velocity += get_gravity() * delta
			
		handle_movement_animation()

	# 4. Apply physics movement and check for enemy collisions
	floor_max_angle = deg_to_rad(60.0) # Allows walking up slopes up to 60 degrees
	move_and_slide()
	
	# Check all collisions that happened during this frame's move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# DEBUG: Prints what you are colliding with in the Output log
		print("Collided with: ", collider)
		
		# Check if we hit an enemy
		if collider and collider.is_in_group("enemies"):
			print("Hit an enemy! Current speed: ", velocity.length(), " | Is curled: ", is_curled)
			
			# Check if we are moving fast enough and are curled up
			if is_curled and velocity.length() >= impact_speed_threshold:
				if collider.has_method("take_damage"):
					collider.take_damage(50)
				
				# Bounce into the air and reset launch cooldown
				velocity.y = bounce_power
				cooldown_timer = 0.0

func handle_movement_animation():
	if velocity.x > 10.0:
		if is_curled:
			animated_sprite.play("roll right")
		else:
			animated_sprite.play("move right")
	elif velocity.x < -10.0:
		if is_curled:
			animated_sprite.play("roll left")
		else:
			animated_sprite.play("move left")
	else:
		animated_sprite.pause()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		print("Hit an enemy! Current speed: ", velocity.length(), " | Is curled: ", is_curled)
		
		# If we are curled up OR moving fast, squish the ant!
		if is_curled or velocity.length() > 150.0:
			if body.has_method("take_damage"):
				body.take_damage(50)
			
			# Bounce into the air and reset launch cooldown for combos
			velocity.y = bounce_power
			cooldown_timer = 0.0
