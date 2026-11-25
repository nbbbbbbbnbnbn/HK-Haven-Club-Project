extends CharacterBody2D

@export var walk_speed: float = 300.0          # Walk speed is 300
@export var min_launch_power: float = 300.0  # Minimum launch speed on a quick click
@export var max_launch_power: float = 1500.0 # Maximum launch speed cap
@export var charge_speed: float = 1200.0     # How fast the power builds up while holding click
@export var roll_friction: float = 100.0     # Lowered friction so it keeps momentum longer
@export var roll_acceleration: float = 1900.0 # Much higher acceleration for faster rolling
@export var launch_cooldown: float = 5.0     # 5 seconds cooldown for the launch
@export var drain_rate: float = 2.5
@export var sugarEaten = 0
@export var reset: bool = false

@export var default_max_launch_power: float = 1500.0
@export var default_charge_speed: float = 1200.0

# Speed threshold required to deal damage and bounce off enemies
@export var impact_speed_threshold: float = 600.0 
@export var bounce_power: float = -1000.0     # Upward bounce velocity when slamming an enemy
@export var knockback_x_power: float = 750.0  # Horizontal knockback so you pop out of dips/swarms
@export var hit_invuln_duration: float = 0.45 # Brief window to escape ant piles cleanly
@export var tutorialDone: bool = false

@onready var haveFun: Label = $"../CanvasLayer/Control/HaveFun"
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var arrow: Node2D = $Node2D
@onready var sugarBar: ProgressBar = $"../CanvasLayer/Control/Sugar meter"
@onready var gameOverScreen: Control = $"../CanvasLayer/Control/Game over screen"
@onready var launch_bar: ProgressBar = $"Node2D/Charge bar"
@onready var cooldown_bar: ProgressBar = $"../CanvasLayer/Control/Cooldown node/Cooldown"
@onready var cooldown_node: Control = $"../CanvasLayer/Control/Cooldown node"
@onready var sugar_meter: ProgressBar = $"../CanvasLayer/Control/Sugar meter"
@onready var hitbox: Area2D = $Hitbox
var sugar_meter_original_position: Vector2

@export var is_curled: bool = false
var is_charging: bool = false
var current_launch_power: float = 0.0
var cooldown_timer: float = 0.0
var hit_invuln_timer: float = 0.0
var has_hit_enemy_this_jump: bool = false
var teleported: bool = false
var last_facing_dir: float = 1.0

func _ready() -> void:
	haveFun.visible = false
	
	if sugar_meter:
		sugar_meter_original_position = sugar_meter.position
	gameOverScreen.visible = false
	if launch_bar:
		launch_bar.visible = false
	arrow.visible = false
	position.x = 22959.0
	position.y = 1003.0
	cooldown_node.visible = false

func _physics_process(delta: float) -> void:
	if hit_invuln_timer > 0.0:
		hit_invuln_timer -= delta

	if not teleported and sugarEaten >= 1:
		position.x = -645.0
		position.y = 215.0
		velocity = Vector2.ZERO
		teleported = true
		havefunFunc()

	if tutorialDone:
		sugarBar.value -= drain_rate * delta

	# Shake sugar meter when below 50%
	if sugar_meter:
		if sugarBar.value < (sugarBar.max_value * 0.5) and sugarBar.value > 0:
			sugar_meter.position = sugar_meter_original_position + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		else:
			sugar_meter.position = sugar_meter_original_position

	if sugarEaten >= 1:
		tutorialDone = true

	if sugarBar.value > 0:
		gameOverScreen.visible = false

		# Decrease cooldown timer
		if cooldown_timer > 0:
			cooldown_timer -= delta
			cooldown_bar.value = cooldown_timer
		else:
			cooldown_node.visible = false

		# 1. CURL TOGGLE
		if Input.is_action_just_pressed("curl"):
			is_curled = !is_curled
			if not is_curled:
				is_charging = false
				arrow.visible = false
				if launch_bar:
					launch_bar.visible = false

		# 2. AIMING & CHARGING (while curled)
		if is_curled:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and cooldown_timer <= 0:
				if not is_charging:
					is_charging = true
					current_launch_power = min_launch_power

				arrow.visible = true
				arrow.look_at(get_global_mouse_position())

				if launch_bar:
					launch_bar.visible = true
					launch_bar.value = current_launch_power

				velocity = Vector2.ZERO
				current_launch_power = min(current_launch_power + charge_speed * delta, max_launch_power)
			else:
				arrow.visible = false
				if launch_bar:
					launch_bar.visible = false

				if is_charging:
					is_charging = false
					var launch_dir = (get_global_mouse_position() - global_position).normalized()
					velocity = launch_dir * current_launch_power
					cooldown_node.visible = true
					cooldown_timer = launch_cooldown
					cooldown_bar.max_value = launch_cooldown
					cooldown_bar.value = cooldown_timer
					has_hit_enemy_this_jump = false
		else:
			arrow.visible = false
			if launch_bar:
				launch_bar.visible = false
			is_charging = false

		# 3. MOVEMENT & GRAVITY
		if is_curled:
			if not is_on_floor():
				velocity += get_gravity() * 1.8 * delta
			else:
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

		# Check overlapping enemies when not in hit invulnerability so curling/touching always registers
		if hitbox and hit_invuln_timer <= 0.0:
			for body in hitbox.get_overlapping_bodies():
				if body.is_in_group("enemies"):
					_resolve_enemy_contact(body)
					break

		# 4. APPLY PHYSICS
		floor_max_angle = deg_to_rad(60.0)
		move_and_slide()
	else:
		gameOverScreen.visible = true

func handle_movement_animation() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return

	var frames := animated_sprite.sprite_frames

	if velocity.x > 10.0:
		last_facing_dir = 1.0
		if is_curled:
			if frames.has_animation("roll right"):
				animated_sprite.play("roll right")
		else:
			if frames.has_animation("move right"):
				animated_sprite.play("move right")
	elif velocity.x < -10.0:
		last_facing_dir = -1.0
		if is_curled:
			if frames.has_animation("roll left"):
				animated_sprite.play("roll left")
		else:
			if frames.has_animation("move left"):
				animated_sprite.play("move left")
	else:
		if is_curled:
			# Show curled pose even when standing still
			if frames.has_animation("curl"):
				animated_sprite.play("curl")
			else:
				var idle_roll_anim := "roll right" if last_facing_dir >= 0.0 else "roll left"
				if frames.has_animation(idle_roll_anim):
					animated_sprite.animation = idle_roll_anim
					animated_sprite.frame = 0
					animated_sprite.pause()
		else:
			# Show uncurled pose when standing still and is_curled is false
			if frames.has_animation("idle"):
				animated_sprite.play("idle")
			else:
				var idle_move_anim := "move right" if last_facing_dir >= 0.0 else "move left"
				if frames.has_animation(idle_move_anim):
					animated_sprite.animation = idle_move_anim
					animated_sprite.frame = 0
					animated_sprite.pause()
				else:
					animated_sprite.pause()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and hit_invuln_timer <= 0.0:
		_resolve_enemy_contact(body)

func _resolve_enemy_contact(body: Node2D) -> void:
	hit_invuln_timer = hit_invuln_duration

	# Push horizontally away from the enemy so you pop out of tight dips/swarms
	var push_dir: float = -1.0 if body.global_position.x >= global_position.x else 1.0
	if abs(body.global_position.x - global_position.x) < 4.0:
		push_dir = -1.0 if last_facing_dir >= 0.0 else 1.0

	if not is_curled and tutorialDone:
		sugarBar.value -= 20.0
		velocity.x = push_dir * knockback_x_power
		velocity.y = min(velocity.y, -450.0)
		modulate = Color(5.0, 5.0, 5.0)
		await get_tree().create_timer(0.15).timeout
		modulate = Color(1.0, 1.0, 1.0)

	print("Hit an enemy! Current speed: ", velocity.length(), " | Is curled: ", is_curled)

	if is_curled or velocity.length() > impact_speed_threshold:
		if body.has_method("take_damage"):
			var calculated_damage = max(velocity.length() * 0.1, 15.0)
			body.take_damage(calculated_damage)

		has_hit_enemy_this_jump = true
		velocity.x = push_dir * knockback_x_power
		velocity.y = bounce_power
		cooldown_timer = 0.0
		max_launch_power *= 1.1
		charge_speed *= 1.1

func havefunFunc() -> void:
	haveFun.visible = true
	await get_tree().create_timer(2).timeout
	haveFun.visible = false

func _on_retry_button_down() -> void:
	sugarBar.value = 100
	position.x = -645.0
	position.y = 215.0
	velocity = Vector2.ZERO
	hit_invuln_timer = 0.0
	max_launch_power = default_max_launch_power
	charge_speed = default_charge_speed
	reset = true
	await get_tree().create_timer(2).timeout
	reset = false
