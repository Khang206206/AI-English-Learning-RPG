extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_waking = true

@onready var sprite = $AnimatedSprite2D

func _ready():
	sprite.play("wake")
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	if is_waking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > 0:
			sprite.play("fail")

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sprite.play("jump")

	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		if is_on_floor():
			sprite.play("run")
		sprite.flip_h = (direction < 0)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():
			sprite.play("idle")

	move_and_slide()

func _on_animation_finished():
	if sprite.animation == "wake":
		is_waking = false
