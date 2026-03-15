extends GameCharacter
class_name Player

var speed = 200
const sprint_multiplier = 2

func _physics_process(delta):
	# Get the input direction vector
	var direction = Input.get_vector("left", "right", "up", "down")

	# Set the character's velocity
	if direction != Vector2.ZERO:
		# Normalize to ensure consistent speed in all directions
		velocity = direction.normalized() * speed 
		if Input.is_action_pressed("sprint"):
			velocity *= sprint_multiplier
	else:
		velocity = Vector2.ZERO

	# Move the character
	move_and_slide()
