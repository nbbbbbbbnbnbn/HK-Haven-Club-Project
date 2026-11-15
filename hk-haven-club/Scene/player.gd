extends CharacterBody2D

@export var walk_speed: float = 300.0          # Walk speed is 300
@export var min_launch_power: float = 300.0  # Minimum launch speed on a quick click
@export var max_launch_power: float = 1500.0 # Maximum launch speed cap
@export var charge_speed: float = 1200.0     # How fast the power builds up while holding click
@export var roll_friction: float = 100.0     # Lowered friction so it keeps momentum longer
@export var roll_acceleration: float = 1900.0 # Much higher acceleration for faster rolling
@export var launch_cooldown: float = 5.0     # 5 seconds cooldown for the launch
@export var drain_rate:float = 5.0

@export var default_max_launch_power: float = 1500.0
@export var default_charge_speed: float = 1200.0

# Speed threshold required to deal damage and bounce off enemies
@export var impact_speed_threshold: float = 600.0 
@export var bounce_power: float = -1000.0     # Upward bounce velocity when slamming an enemy

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arrow: Node2D = $Node2D
@onready var sugarBar: ProgressBar = $"../CanvasLayer/Control/ProgressBar"
@onready var gameOverScreen: Control = $"../CanvasLayer/Control/Game over screen"

@export var is_curled: bool = false
var is_charging: bool = false
var current_launch_power: float = 0.0
var cooldown_timer: float = 0.0
var has_hit_enemy_this_jump: bool = false # Tracks if you successfully comboed

func _ready() -> void:
	gameOverScreen.visible = false
	position.x = 681.0
	position.y = 569.0

func _physics_process(delta: float) -> void:
	
	sugarBar.value -= drain_rate * delta
	
	if sugarBar.value > 0:
		# Decrease the cooldown timer every frame if it's running
		if cooldown_timer > 0:
			cooldown_timer -= delta
		
		# 1. SPACEBAR: CURL / UN-CURL TOGGLE STATE
		if Input.is_action_pressed("curl"):
			is_curled = true
		else:
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
					
					# Start the 5-second cooldown timer & reset combo tracking for this launch
					cooldown_timer = launch_cooldown
					has_hit_enemy_this_jump = false 
		else:
			arrow.visible = false
			is_charging = false

		# 3. STATE-BASED MOVEMENT & GRAVITY
		if is_curled:
			if not is_on_floor():
				velocity += get_gravity() * 1.8 * delta
			else:
				# WHEN YOU LAND ON THE FLOOR:
				# If you landed WITHOUT hitting an enemy, reset stats back to default!
				if not has_hit_enemy_this_jump:
					max_launch_power = default_max_launch_power
					charge_speed = default_charge_speed
					
				var floor_normal = get_floor_normal()
				var slope_direction = Vector2(floor_normal.y, -floor_normal.x)
				
				if abs(floor_normal.x) > 0.1:
					velocity += slope_direction * -sign(floor_normal.x) * roll_acceleration * delta
					velocity += get_gravity() * 0.8 * delta
				else:
					velocity.x = move_toward(velocity.x, 0.0, roll_friction * delta)
					
			handle_movement_animation()
					
		else:
			var input_dir := Input.get_vector("move_left", "move_right", "ui_up", "ui_down")
			velocity.x = input_dir.x * walk_speed
			
			if not is_on_floor():
				velocity += get_gravity() * delta
				
			handle_movement_animation()

		# 4. Apply physics movement
		floor_max_angle = deg_to_rad(60.0)
		move_and_slide()
	else:
		gameOverScreen.visible = true

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
		if not is_curled:
			sugarBar.value -= 20.0
			modulate = Color(5.0, 5.0, 5.0) # High HDR white flash
		
			# Wait a short moment, then return to normal color
			await get_tree().create_timer(0.15).timeout
			modulate = Color(1.0, 1.0, 1.0) # Reset to normal
		
		print("Hit an enemy! Current speed: ", velocity.length(), " | Is curled: ", is_curled)
		
		if is_curled or velocity.length() > 600.0:
			if body.has_method("take_damage"):
				var calculated_damage = velocity.length() * 0.1
				body.take_damage(calculated_damage)
			
			# Successful hit! Mark it, bounce, reset cooldown, and scale up stats!
			has_hit_enemy_this_jump = true
			velocity.y = bounce_power
			cooldown_timer = 0.0
			max_launch_power *= 1.1
			charge_speed *= 1.1
