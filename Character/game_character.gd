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
@export var show_health_bar: bool = true
@export var health_bar_size: Vector2 = Vector2(24, 4)
@export var health_bar_offset: Vector2 = Vector2(-12, -20)
@export var health_bar_background: Color = Color(0.15, 0.15, 0.15, 0.9)
@export var health_bar_fill: Color = Color(0.2, 0.9, 0.2, 0.95)
@export var health_bar_border: Color = Color(0, 0, 0, 1)

var health: int


# Initialize runtime stats from exported values.
func _ready() -> void:
	health = max_health
	queue_redraw()


func _process(delta: float) -> void:
	pass


func _draw() -> void:
	if not show_health_bar:
		return
	if max_health <= 0:
		return

	var ratio = clamp(float(health) / float(max_health), 0.0, 1.0)
	var bar_rect := Rect2(health_bar_offset, health_bar_size)
	var fill_rect := Rect2(
		health_bar_offset,
		Vector2(health_bar_size.x * ratio, health_bar_size.y)
	)

	draw_rect(bar_rect, health_bar_background, true)
	if fill_rect.size.x > 0:
		draw_rect(fill_rect, health_bar_fill, true)
	draw_rect(bar_rect, health_bar_border, false, 1.0)


func get_team() -> Team:
	return team


func is_alive() -> bool:
	return health > 0


func take_damage(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return

	health = max(0, health - amount)
	queue_redraw()
	if health == 0:
		die()


func heal(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return

	health = min(max_health, health + amount)
	queue_redraw()


func die() -> void:
	emit_signal("died", self)
	queue_free()
