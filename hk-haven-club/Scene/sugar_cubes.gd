extends Area2D

@export var sugar_restore_amount: float = 25.0
@onready var player: CharacterBody2D = $"../Player"

func _on_body_entered(body: Node2D) -> void:
	# Check if the player picked it up
	if body.name == "Player" or body.is_in_group("player"):
		# If your player has a reference to the sugar bar or a sugar replenishment function:
		if body.has_method("add_sugar"):
			body.add_sugar(sugar_restore_amount)
		
		# Alternatively, if you want it to directly target the progress bar via path:
		var bar = get_node_or_null("/root/Main/CanvasLayer/Control/ProgressBar")
		if bar and not player.is_curled:
			bar.value = min(bar.value + sugar_restore_amount, bar.max_value)
			
			# Play pickup effect/sound here if desired, then remove the sugar cube
			queue_free()
