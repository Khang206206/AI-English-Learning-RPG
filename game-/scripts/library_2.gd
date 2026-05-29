extends Node2D
@export var lib2_music: AudioStream


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if lib2_music != null:
		BgmManager.play_music(lib2_music)
	else:
		# Nếu bạn quên chưa kéo nhạc vào thì tự động tắt nhạc cũ cho an toàn
		BgmManager.stop_music()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
