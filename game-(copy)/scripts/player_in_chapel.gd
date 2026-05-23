extends CharacterBody2D

const SPEED = 150.0
var is_dead = false
var is_waking = true

@onready var sprite = $AnimatedSprite2D

func _ready():
	sprite.play("wake")
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta):
	if is_dead or is_waking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		sprite.play("run")
		if direction.x != 0:
			sprite.flip_h = (direction.x < 0)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		sprite.play("idle")

	move_and_slide()

func _on_animation_finished():
	if sprite.animation == "wake":
		is_waking = false

func die():
	is_dead = true
	sprite.play("die")
