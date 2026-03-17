extends CharacterBody2D
class_name GameCharacter

enum Team {
	ALLY,
	ENEMY,
	NEUTRAL
}

signal died(character: GameCharacter)

@export var team: Team = Team.NEUTRAL
@export var max_health: int = 100

var health: int


# Initialize runtime stats from exported values.
func _ready() -> void:
	health = max_health


func _process(delta: float) -> void:
	pass


func get_team() -> Team:
	return team


func is_alive() -> bool:
	return health > 0


func take_damage(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return

	health = max(0, health - amount)
	if health == 0:
		die()


func die() -> void:
	emit_signal("died", self)
	queue_free()
