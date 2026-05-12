extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# QUAN TRỌNG: Đổi thành false để thoát khỏi trạng thái đứng im ban đầu [cite: 9]
var is_waking = false 

@onready var sprite = $AnimatedSprite2D

func _ready():
	# Cho nhân vật đứng yên ngay từ đầu [cite: 9]
	sprite.play("idle")
	is_waking = false # Đảm bảo biến này tắt đi để kích hoạt _physics_process [cite: 9]

func _physics_process(delta):
	# Nếu vẫn bị kẹt ở đây, nhân vật sẽ không bao giờ cập nhật is_on_floor() 
	if is_waking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Áp dụng trọng lực khi không ở trên sàn 
	if not is_on_floor():
		velocity.y += gravity * delta
		# Chỉ chơi hoạt ảnh rơi khi đang thực sự rớt xuống nhanh một chút
		if velocity.y > 50: 
			sprite.play("fail")
	else:
		# Reset vận tốc Y khi đã chạm đất để tránh tích tụ trọng lực
		velocity.y = 0

	# Nhảy 
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sprite.play("jump")

	# Di chuyển trái phải 
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
