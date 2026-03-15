extends Node2D
class_name LevelManager

@export var player: Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if player == null:
		printerr("Player is null!")
