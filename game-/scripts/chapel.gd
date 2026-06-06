extends Node2D

# 1. Tạo một ô trống bên cột Inspector để bạn kéo thả file nhạc vào
@export var chapel_music: AudioStream


func _ready() -> void:
	# 2. Khi Chapel vừa load lên, gọi Nhạc công phát bài nhạc này
	if chapel_music != null:
		BgmManager.play_music(chapel_music)
	else:
		# Nếu bạn quên chưa kéo nhạc vào thì tự động tắt nhạc cũ cho an toàn
		BgmManager.stop_music()		
