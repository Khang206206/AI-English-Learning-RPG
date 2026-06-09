extends Node2D
@export var lib1_music: AudioStream

const PLAYER_ENTER_LIBRARY_DIALOGUE = [
	{
		"name": "Bạn",
		"portrait": "res://assets/textures/player2/_Faces/face_normal.png",
		"text": "Khoan đã... Mình vừa bước vào trong một quyển sách sao?"
	},
	{
		"name": "Bạn",
		"portrait": "res://assets/textures/player2/_Faces/face_empty.png",
		"text": "Không khí ở đây lạ quá. Cứ như từng con chữ đang bay lơ lửng quanh mình."
	},
	{
		"name": "Bạn",
		"portrait": "res://assets/textures/player2/_Faces/face_normal.png",
		"text": "Đây là pháp thuật của thế giới này à? Hay mình vẫn còn đang mơ?"
	},
]

func _ready():
	if lib1_music != null:
		BgmManager.play_music(lib1_music)
	else:
		# Nếu bạn quên chưa kéo nhạc vào thì tự động tắt nhạc cũ cho an toàn
		BgmManager.stop_music()
	if GameManager.target_spawn_id != "":
		var spawn_point = get_node_or_null(GameManager.target_spawn_id)
		if spawn_point:
			# Truy cập vào nhân vật, sau đó mới truy cập vào sprite của nó
			var player = $PlayerSideView
			player.global_position = spawn_point.global_position
			
			# Nếu bạn muốn ép nhân vật chơi animation 'idle' từ đây:
			player.get_node("AnimatedSprite2D").play("idle") 
			
		GameManager.target_spawn_id = ""
	_maybe_start_player_entry_dialogue()

func _maybe_start_player_entry_dialogue() -> void:
	if DatabaseManager != null and DatabaseManager.has_completed_intro_quiz():
		return
	if GameManager != null and GameManager.has_seen_library_entry_dialogue:
		return
	if GameManager != null:
		GameManager.has_seen_library_entry_dialogue = true
	if DialogueSystem != null:
		DialogueSystem.start_dialogue(PLAYER_ENTER_LIBRARY_DIALOGUE)
