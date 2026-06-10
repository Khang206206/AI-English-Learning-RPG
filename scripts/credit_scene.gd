extends Control

@export var normal_speed: float = 60.0
@export var fast_speed: float = 200.0
@export var title_music: AudioStream
@onready var credits_text = $RichTextLabel

func _ready():
	if title_music != null:
		BgmManager.play_music(title_music)
	else:
		# Nếu bạn quên chưa kéo nhạc vào thì tự động tắt nhạc cũ cho an toàn
		BgmManager.stop_music()
	# 1. Ép dòng chữ bắt đầu cuộn từ tít dưới mép dưới màn hình
	credits_text.position.y = get_viewport_rect().size.y
	
	# Bật nhạc Ending (Nếu bồ có node AudioStreamPlayer tên BGM_Credit)
	# $BGM_Credit.play()

func _process(delta):
	# 2. Xử lý logic tua nhanh nếu người chơi nhấn giữ phím Space hoặc Chuột trái
	var current_speed = normal_speed
	if Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		current_speed = fast_speed
		
	# 3. Trừ tọa độ Y để chữ trôi dần lên trên
	credits_text.position.y -= current_speed * delta
	
	# 4. Kiểm tra: Nếu đoạn chữ đã trôi lên qua khuất mép trên màn hình thì kết thúc
	# (credits_text.size.y là tổng chiều dài của cả đoạn văn)
	if credits_text.position.y < -credits_text.size.y - 60:
		end_credits()

# Hàm xử lý sau khi Credit chạy xong (Trở về Main Menu)
func end_credits():
	# Bồ đổi đường dẫn này về file màn hình Menu chính của nhóm bồ nha
	get_tree().change_scene_to_file("res://scenes/chapter_1.tscn")
