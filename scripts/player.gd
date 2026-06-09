extends CharacterBody2D

const SPEED = 150.0
var is_dead = false
var last_direction = "side"

@onready var sprite = $AnimatedSprite2D

func _ready():
	sprite.play("idle_down")
	if GameManager.should_load_position:
		global_position = GameManager.player_position
		GameManager.should_load_position = false

func _physics_process(_delta):
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		
		if abs(direction.y) > abs(direction.x):
			if direction.y > 0:
				sprite.play("run_down")
				last_direction = "down"
			else:
				sprite.play("run_up")
				last_direction = "up"
		else:
			sprite.play("run_side")
			last_direction = "side"
			sprite.flip_h = (direction.x < 0)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		sprite.play("idle_" + last_direction)

	move_and_slide()
	GameManager.player_position = global_position

func die():
	is_dead = true
	sprite.play("die")
