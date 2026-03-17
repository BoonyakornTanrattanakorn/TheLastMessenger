extends GameCharacter
class_name CombatNPC

enum State {
	PATROL,
	MOVE_TO_ENEMY,
	FIGHT_ENEMY
}

@onready var detection_area: Area2D = $DetectionArea

@export var speed = 100
@export var attack_range: float = 20.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.75
@export var attack_slot_radius: float = 14.0
@export var ally_avoidance_radius: float = 28.0
@export var ally_avoidance_strength: float = 1.35

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


func _run_move_to_enemy_state() -> void:
	_update_target_to_closest_enemy()
	if not _has_valid_target():
		_handle_lost_target()
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

	var attack_slot_position := _get_attack_slot_position(target)
	_move_towards_with_avoidance(attack_slot_position)


func _run_fight_enemy_state() -> void:
	_update_target_to_closest_enemy()
	if not _has_valid_target():
		_handle_lost_target()
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

	_move_towards_with_avoidance(_last_known_position)
	state = State.MOVE_TO_ENEMY


func _handle_lost_target() -> void:
	# If the previous target was defeated, do not converge everyone on the death location.
	if target != null and (not is_instance_valid(target) or not target.is_alive()):
		_reset_to_patrol()
		return

	# If the target was only lost from vision/range, continue to last known position.
	_move_to_last_known_position_or_patrol()


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


func _move_towards_with_avoidance(destination: Vector2) -> void:
	var desired_dir := (destination - position).normalized()
	if desired_dir == Vector2.ZERO:
		velocity = Vector2.ZERO
		return

	var steer := desired_dir + _get_ally_separation_vector() * ally_avoidance_strength
	if steer == Vector2.ZERO:
		velocity = Vector2.ZERO
		return

	velocity = steer.normalized() * speed


func _get_ally_separation_vector() -> Vector2:
	var separation := Vector2.ZERO
	var nearby_allies := 0
	var avoid_radius_sq := ally_avoidance_radius * ally_avoidance_radius

	for body in detection_area.get_overlapping_bodies():
		if not (body is GameCharacter):
			continue

		var other := body as GameCharacter
		if other == self:
			continue
		if not other.is_alive():
			continue
		if other.get_team() != get_team():
			continue

		var to_me := position - other.position
		var dist_sq := to_me.length_squared()
		if dist_sq <= 0.001 or dist_sq > avoid_radius_sq:
			continue

		# Stronger push when the ally is closer.
		separation += to_me.normalized() * (1.0 - (dist_sq / avoid_radius_sq))
		nearby_allies += 1

	if nearby_allies == 0:
		return Vector2.ZERO

	return separation / float(nearby_allies)


func _get_attack_slot_position(enemy: GameCharacter) -> Vector2:
	var slot_angle := float(get_instance_id() % 360) * PI / 180.0
	var offset := Vector2(cos(slot_angle), sin(slot_angle)) * attack_slot_radius
	return enemy.position + offset
