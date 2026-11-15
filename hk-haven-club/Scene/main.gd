extends Node2D

# Preload your enemy scene so we can spawn copies of it
@export var enemy_scene: PackedScene = preload("res://Scene/enemy.tscn")

@onready var player = $Player
@onready var timer: Timer = $SpawnTimer
@onready var first4Enemy: = 0
@onready var menu = $CanvasLayer/Menu

func _ready() -> void:
	# Randomize the random number generator seed
	randomize()
	start_spawn_timer()
	menu.visible = true


func start_spawn_timer() -> void:
	# Pick a random wait time between 5 and 10 seconds
	var random_time = 0.001
	if first4Enemy > 4:
		random_time = randf_range(2.0, 7.0)
	
	# Configure and start the existing Timer node
	timer.wait_time = random_time
	timer.one_shot = true
	timer.start()
	first4Enemy += 1

func _on_spawn_timer_timeout() -> void:
	spawn_ant()
	# Restart the timer for the next spawn
	start_spawn_timer()

func spawn_ant() -> void:
	if not enemy_scene:
		return
		
	# Instantiate a new ant
	var ant = enemy_scene.instantiate()
	
	# Define your spawn points in an array
	var spawn_points = [
		Vector2(5071.0, -821.0),
		Vector2(-11807.0, 344.0),
		Vector2(-4572.0, 349.0),
		Vector2(2018.0, 441.0)
	]
	
	# Randomly pick one of the positions from the array
	ant.global_position = spawn_points.pick_random()
	
	# Add the ant as a child of the Main scene
	get_tree().current_scene.add_child(ant)


func _on_button_button_down() -> void:
	menu.visible = false


func _on_retry_button_down() -> void:
	first4Enemy = 0
