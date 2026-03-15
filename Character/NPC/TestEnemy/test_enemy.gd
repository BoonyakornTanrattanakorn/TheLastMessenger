extends GameCharacter
class_name TestNPC

var speed = 200
@onready var level: LevelManager = $".."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var dir = (level.player.position - position).normalized()
	velocity = dir * speed
	
	move_and_slide()
