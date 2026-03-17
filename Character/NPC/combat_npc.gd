extends GameCharacter
class_name CombatNPC

enum State {
	PATROL,
	MOVE_TO_ENEMY,
	FIGHT_ENEMY
}

@onready var detection_area: Area2D = $DetectionArea

@export var speed = 100
@export var detection_range: float = 180.0
@export_flags_2d_physics var line_of_sight_mask: int = 0x7FFFFFFF
@export var attack_range: float = 20.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 0.75
@export var attack_slot_radius: float = 14.0
@export var ally_avoidance_radius: float = 28.0
@export var ally_avoidance_strength: float = 1.35
@export var obstacle_avoidance_distance: float = 26.0
@export var obstacle_avoidance_strength: float = 2.1
@export var obstacle_probe_angle_deg: float = 28.0
@export_flags_2d_physics var obstacle_avoidance_mask: int = 0x7FFFFFFF

var state = State.PATROL
var target: GameCharacter
var _attack_cooldown_left: float = 0.0
var _last_known_position: Vector2 = Vector2.ZERO
var _has_last_known_position: bool = false


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = max(0.0, _attack_cooldown_left - delta)
	max_speed = speed

	match(state):
		State.PATROL:
			_run_patrol_state(delta)
		State.MOVE_TO_ENEMY:
			_run_move_to_enemy_state(delta)
		State.FIGHT_ENEMY:
			_run_fight_enemy_state(delta)
		_:
			apply_braking_force(delta)

	move_and_slide()


func _run_patrol_state(delta: float) -> void:
	apply_braking_force(delta)
	_update_target_to_closest_enemy()
	if _has_valid_target():
		state = State.MOVE_TO_ENEMY
		return

	if _try_support_ally_in_combat():
		state = State.MOVE_TO_ENEMY
		return


func _run_move_to_enemy_state(delta: float) -> void:
	_update_target_to_closest_enemy()
	if not _has_valid_target():
		_handle_lost_target(delta)
		return

	if not _is_target_in_detection_area():
		target = null
		_move_to_last_known_position_or_patrol(delta)
		return

	_last_known_position = target.position
	_has_last_known_position = true

	var distance_to_target := position.distance_to(target.position)
	if distance_to_target <= attack_range:
		apply_braking_force(delta)
		state = State.FIGHT_ENEMY
		return

	var attack_slot_position := _get_attack_slot_position(target)
	_move_towards_with_avoidance(attack_slot_position, delta)


func _run_fight_enemy_state(delta: float) -> void:
	_update_target_to_closest_enemy()
	if not _has_valid_target():
		_handle_lost_target(delta)
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

	apply_braking_force(delta)
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
	state = State.PATROL
	_has_last_known_position = false


func _is_target_in_detection_area() -> bool:
	if not is_instance_valid(target):
		return false

	for body in detection_area.get_overlapping_bodies():
		if body == target:
			return _can_detect(target)

	return false


func _can_detect(candidate: GameCharacter) -> bool:
	if not is_instance_valid(candidate):
		return false

	if position.distance_to(candidate.position) > detection_range:
		return false

	return _has_line_of_sight(candidate)


func _has_line_of_sight(candidate: GameCharacter) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, candidate.global_position)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = line_of_sight_mask

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true

	return result.get("collider") == candidate


func _move_to_last_known_position_or_patrol(delta: float) -> void:
	if not _has_last_known_position:
		_reset_to_patrol()
		return

	var distance_to_last_known := position.distance_to(_last_known_position)
	if distance_to_last_known <= 4.0:
		_reset_to_patrol()
		return

	_move_towards_with_avoidance(_last_known_position, delta)
	state = State.MOVE_TO_ENEMY


func _handle_lost_target(delta: float) -> void:
	# If the previous target was defeated, do not converge everyone on the death location.
	if target != null and (not is_instance_valid(target) or not target.is_alive()):
		_reset_to_patrol()
		return

	if _try_support_ally_in_combat():
		if _has_valid_target():
			state = State.MOVE_TO_ENEMY
			return

		_move_to_last_known_position_or_patrol(delta)
		return

	# If the target was only lost from vision/range, continue to last known position.
	_move_to_last_known_position_or_patrol(delta)


func _try_support_ally_in_combat() -> bool:
	var ally := _find_closest_detectable_ally_in_combat()
	if ally == null:
		return false

	var ally_target := ally.target
	if is_instance_valid(ally_target) and _is_valid_enemy(ally_target) and _can_detect(ally_target):
		target = ally_target
		_last_known_position = ally_target.position
		_has_last_known_position = true
		return true

	target = null
	_last_known_position = ally.position
	_has_last_known_position = true
	return true


func _find_closest_detectable_ally_in_combat() -> CombatNPC:
	var closest_ally: CombatNPC = null
	var closest_distance_sq := INF

	for body in detection_area.get_overlapping_bodies():
		if not (body is CombatNPC):
			continue

		var ally := body as CombatNPC
		if ally == self:
			continue
		if not ally.is_alive():
			continue
		if ally.get_team() != get_team():
			continue
		if ally.state == State.PATROL:
			continue
		if not ally._has_valid_target():
			continue
		if not _can_detect(ally):
			continue

		var candidate_distance_sq := position.distance_squared_to(ally.position)
		if closest_ally == null or candidate_distance_sq < closest_distance_sq:
			closest_ally = ally
			closest_distance_sq = candidate_distance_sq

	return closest_ally


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
			if not _can_detect(candidate):
				continue

			var candidate_distance_sq := position.distance_squared_to(candidate.position)
			if closest_enemy == null or candidate_distance_sq < closest_distance_sq:
				closest_enemy = candidate
				closest_distance_sq = candidate_distance_sq

	return closest_enemy


func _move_towards_with_avoidance(destination: Vector2, delta: float) -> void:
	var desired_dir := (destination - position).normalized()
	if desired_dir == Vector2.ZERO:
		apply_braking_force(delta)
		return

	var obstacle_avoidance := _get_obstacle_avoidance_vector(desired_dir)
	var steer := desired_dir + _get_ally_separation_vector() * ally_avoidance_strength + obstacle_avoidance * obstacle_avoidance_strength
	# Keep forward intent strong so tight passages remain traversable.
	if steer.dot(desired_dir) < 0.35:
		steer = desired_dir + obstacle_avoidance * (obstacle_avoidance_strength * 0.5)

	if steer == Vector2.ZERO:
		apply_braking_force(delta)
		return

	apply_movement_force(steer.normalized(), delta)


func _get_obstacle_avoidance_vector(desired_dir: Vector2) -> Vector2:
	var space_state := get_world_2d().direct_space_state
	var from := global_position
	var probe_angle := deg_to_rad(obstacle_probe_angle_deg)
	var probe_dirs := [
		desired_dir,
		desired_dir.rotated(-probe_angle),
		desired_dir.rotated(probe_angle)
	]

	var avoidance := Vector2.ZERO
	for probe_dir in probe_dirs:
		var query := PhysicsRayQueryParameters2D.create(from, from + probe_dir * obstacle_avoidance_distance)
		query.exclude = [self]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.collision_mask = obstacle_avoidance_mask

		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			continue

		var hit_pos: Vector2 = hit.get("position", from)
		var hit_normal: Vector2 = hit.get("normal", Vector2.ZERO)
		var hit_dist := from.distance_to(hit_pos)
		var weight = clamp(1.0 - (hit_dist / obstacle_avoidance_distance), 0.0, 1.0)
		avoidance += hit_normal * weight

	if avoidance == Vector2.ZERO:
		return Vector2.ZERO

	# Use lateral correction only, so walls do not kill forward motion in narrow gaps.
	var lateral := avoidance - desired_dir * avoidance.dot(desired_dir)
	if lateral == Vector2.ZERO:
		return Vector2.ZERO

	return lateral.normalized()


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
