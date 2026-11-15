extends ProgressBar

@onready var player: CharacterBody2D = $"../.."

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	min_value = player.min_launch_power
	max_value = player.max_launch_power
