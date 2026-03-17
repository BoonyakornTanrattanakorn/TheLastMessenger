extends GameCharacter
class_name CombatNPC

enum State {
	PATROL,
	MOVE_TO_ENEMY,
	FIGHT_ENEMY
}

@onready var detection_area: Area2D = $DetectionArea

@export var speed = 200
@export var attack_range: float = 20.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.75

var state = State.PATROL
var target: GameCharacter
var _attack_cooldown_left: float = 0.0
var _last_known_position: Vector2 = Vector2.ZERO
var _has_last_known_position: bool = false


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = max(0.0, _attack_cooldown_left - delta)

	match(state):
		State.PATROL:
			_run_patrol_state()
		State.MOVE_TO_ENEMY:
			_run_move_to_enemy_state()
		State.FIGHT_ENEMY:
			_run_fight_enemy_state()
		_:
			velocity = Vector2.ZERO

	move_and_slide()


func _run_patrol_state() -> void:
	velocity = Vector2.ZERO
	_update_target_to_closest_enemy()
	if _has_valid_target():
		state = State.MOVE_TO_ENEMY
		return

	for body in detection_area.get_overlapping_bodies():
		if body is GameCharacter:
			var candidate := body as GameCharacter
			if _is_valid_enemy(candidate):
				target = candidate
				_last_known_position = target.position
				_has_last_known_position = true
				state = State.MOVE_TO_ENEMY
				return


func _run_move_to_enemy_state() -> void:
	_update_target_to_closest_enemy()
	if not _has_valid_target():
		_move_to_last_known_position_or_patrol()
		return

	if not _is_target_in_detection_area():
		target = null
		_move_to_last_known_position_or_patrol()
		return

	_last_known_position = target.position
	_has_last_known_position = true

	var distance_to_target := position.distance_to(target.position)
	if distance_to_target <= attack_range:
		velocity = Vector2.ZERO
		state = State.FIGHT_ENEMY
		return

	var dir := (target.position - position).normalized()
	velocity = dir * speed


func _run_fight_enemy_state() -> void:
	_update_target_to_closest_enemy()
	if not _has_valid_target():
		_move_to_last_known_position_or_patrol()
		return

	if not _is_target_in_detection_area():
		target = null
		state = State.MOVE_TO_ENEMY
		return

	_last_known_position = target.position
	_has_last_known_position = true

	var distance_to_target := position.distance_to(target.position)
	if distance_to_target > attack_range:
		state = State.MOVE_TO_ENEMY
		return

	velocity = Vector2.ZERO
	if _attack_cooldown_left == 0.0:
		target.take_damage(attack_damage)
		_attack_cooldown_left = attack_cooldown


func _has_valid_target() -> bool:
	return is_instance_valid(target) and _is_valid_enemy(target)


func _is_valid_enemy(candidate: GameCharacter) -> bool:
	if candidate == self:
		return false
	if not candidate.is_alive():
		return false
	return candidate.get_team() != get_team()


func _reset_to_patrol() -> void:
	target = null
	velocity = Vector2.ZERO
	state = State.PATROL
	_has_last_known_position = false


func _is_target_in_detection_area() -> bool:
	if not is_instance_valid(target):
		return false

	for body in detection_area.get_overlapping_bodies():
		if body == target:
			return true

	return false


func _move_to_last_known_position_or_patrol() -> void:
	if not _has_last_known_position:
		_reset_to_patrol()
		return

	var distance_to_last_known := position.distance_to(_last_known_position)
	if distance_to_last_known <= 4.0:
		_reset_to_patrol()
		return

	var dir := (_last_known_position - position).normalized()
	velocity = dir * speed
	state = State.MOVE_TO_ENEMY


func _update_target_to_closest_enemy() -> void:
	var closest_enemy := _find_closest_enemy_in_detection_area()
	if closest_enemy == null:
		return

	if not _has_valid_target():
		target = closest_enemy
		_last_known_position = target.position
		_has_last_known_position = true
		return

	var current_distance_sq := position.distance_squared_to(target.position)
	var closest_distance_sq := position.distance_squared_to(closest_enemy.position)
	if closest_enemy != target and closest_distance_sq < current_distance_sq:
		target = closest_enemy
		_last_known_position = target.position
		_has_last_known_position = true


func _find_closest_enemy_in_detection_area() -> GameCharacter:
	var closest_enemy: GameCharacter = null
	var closest_distance_sq := INF

	for body in detection_area.get_overlapping_bodies():
		if body is GameCharacter:
			var candidate := body as GameCharacter
			if not _is_valid_enemy(candidate):
				continue

			var candidate_distance_sq := position.distance_squared_to(candidate.position)
			if closest_enemy == null or candidate_distance_sq < closest_distance_sq:
				closest_enemy = candidate
				closest_distance_sq = candidate_distance_sq

	return closest_enemy
