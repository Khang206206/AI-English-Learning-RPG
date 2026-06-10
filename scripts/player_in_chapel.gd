extends CharacterBody2D

const SPEED = 150.0
const PLAYER_OPENING_DIALOGUE = [
	{
		"name": "",
		"portrait": "",
		"hide_portrait": true,
		"text": "The Seeker thức tỉnh trên nền đá lạnh của một nhà thờ xa lạ."
	},
	{
		"name": "",
		"portrait": "",
		"hide_portrait": true,
		"text": "Cậu không nhớ mình là ai, đến từ đâu, hay vì sao lại nằm ở nơi này."
	},
	{
		"name": "The Seeker",
		"portrait": "res://assets/textures/player2/_Faces/face_empty.png",
		"text": "\"Mình... là ai? Sao trong đầu mình trống rỗng thế này?\""
	},
	{
		"name": "",
		"portrait": "",
		"hide_portrait": true,
		"text": "Trên bục thờ, một quyển sách cổ bỗng phát sáng, như thể đang gọi cậu lại gần."
	},
	{
		"name": "The Seeker",
		"portrait": "res://assets/textures/player2/_Faces/face_normal.png",
		"text": "\"Quyển sách đó... nó đang kéo mình về phía nó.\""
	},
]

var is_dead = false
var is_waking = true
var should_show_opening_dialogue = false
var last_direction = "side"

@onready var sprite = $AnimatedSprite2D

func _ready():
	should_show_opening_dialogue = (
		not GameManager.should_load_position
		and DatabaseManager != null
		and not DatabaseManager.has_completed_intro_quiz()
	)
	sprite.play("wake")
	sprite.animation_finished.connect(_on_animation_finished)
	if GameManager.should_load_position:
		global_position = GameManager.player_position
		GameManager.should_load_position = false

func _physics_process(_delta):
	if is_dead or is_waking:
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

func _on_animation_finished():
	if sprite.animation == "wake":
		is_waking = false
		if should_show_opening_dialogue:
			should_show_opening_dialogue = false
			DialogueSystem.start_dialogue(PLAYER_OPENING_DIALOGUE)

func die():
	is_dead = true
	sprite.play("die")
