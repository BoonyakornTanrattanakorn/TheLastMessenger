extends "res://Character/NPC/combat_npc.gd"
class_name TestAlly

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	team = GameCharacter.Team.ALLY
	super._ready()
