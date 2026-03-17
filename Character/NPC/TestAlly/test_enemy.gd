extends "res://Character/NPC/combat_npc.gd"
class_name TestEnemy

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	team = GameCharacter.Team.ENEMY
	super._ready()
