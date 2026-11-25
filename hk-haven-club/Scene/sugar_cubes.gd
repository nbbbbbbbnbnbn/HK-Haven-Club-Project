extends Area2D

@export var sugar_restore_amount: float = 20.0
@onready var player: CharacterBody2D = $"../Player" # Adjust path if needed to point to your player node

func _process(_delta: float) -> void:
	if player.reset:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# Check if the player entered the sugar cube area
	if body.is_in_group("player") or body.name == "Player":
		
		# ONLY consume the sugar cube if the player is uncurled
		if player and not player.is_curled:
			var bar = get_node_or_null("/root/Main/CanvasLayer/Control/Sugar meter")
			if bar:
				bar.value = min(bar.value + sugar_restore_amount, bar.max_value)
				print("Sugar consumed! Restored ", sugar_restore_amount)
				player.sugarEaten += 1
				
			# Remove the sugar cube from the game
			queue_free()
