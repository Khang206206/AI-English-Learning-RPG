extends Node2D

# 1. Tạo một ô trống bên cột Inspector để bạn kéo thả file nhạc vào
@export var chapel_music: AudioStream

@onready var to_library = $ToLibrary
@onready var to_map_1 = $ToMap1


func _ready() -> void:
	# 2. Khi Chapel vừa load lên, gọi Nhạc công phát bài nhạc này
	if chapel_music != null:
		BgmManager.play_music(chapel_music)
	else:
		# Nếu bạn quên chưa kéo nhạc vào thì tự động tắt nhạc cũ cho an toàn
		BgmManager.stop_music()
	_apply_intro_quiz_gate_state()
	if DatabaseManager != null and DatabaseManager.has_signal("intro_quiz_state_changed") and not DatabaseManager.intro_quiz_state_changed.is_connected(_on_intro_quiz_state_changed):
		DatabaseManager.intro_quiz_state_changed.connect(_on_intro_quiz_state_changed)

func _apply_intro_quiz_gate_state() -> void:
	var has_completed_intro_quiz := DatabaseManager.has_completed_intro_quiz()
	if to_library != null and to_library.has_method("set_gate_enabled"):
		to_library.set_gate_enabled(not has_completed_intro_quiz)
	if to_map_1 != null and to_map_1.has_method("set_gate_enabled"):
		to_map_1.set_gate_enabled(has_completed_intro_quiz)

func _on_intro_quiz_state_changed(_is_completed: bool) -> void:
	_apply_intro_quiz_gate_state()
