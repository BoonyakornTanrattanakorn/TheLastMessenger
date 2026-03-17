extends GameCharacter
class_name Player

@export var speed: float = 100.0
@export var sprint_multiplier: float = 2.0

func _ready() -> void:
	super._ready()
	team = GameCharacter.Team.ALLY
	
func _physics_process(delta: float) -> void:
	# Get the input direction vector
	var direction = Input.get_vector("left", "right", "up", "down")
	max_speed = speed

	# Apply movement force toward desired direction.
	if direction != Vector2.ZERO:
		var force_scale := 1.0
		if Input.is_action_pressed("sprint"):
			force_scale = sprint_multiplier
		apply_movement_force(direction, delta, force_scale)
	else:
		apply_braking_force(delta)

	# Move the character
	move_and_slide()
