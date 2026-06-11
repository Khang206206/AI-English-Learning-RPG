extends Node2D
@export var lib1_music: AudioStream

const PLAYER_ENTER_LIBRARY_DIALOGUE = [
	{
		"name": "",
		"portrait": "",
		"hide_portrait": true,
		"text": "Khoảnh khắc chạm vào trang sách, thế giới quanh The Seeker tan thành những dòng chữ phát sáng."
	},
	{
		"name": "",
		"portrait": "",
		"hide_portrait": true,
		"text": "Khi mở mắt, cậu đã đứng giữa một thư viện mênh mông, nơi từng con chữ lơ lửng như những vì sao."
	},
	{
		"name": "The Seeker",
		"portrait": "res://assets/textures/player2/_Faces/face_normal.png",
		"text": "\"Khoan đã... Mình vừa bước vào trong một quyển sách sao?\""
	},
	{
		"name": "The Seeker",
		"portrait": "res://assets/textures/player2/_Faces/face_empty.png",
		"text": "\"Không khí ở đây lạ quá. Cứ như từng con chữ đều có ma lực riêng.\""
	},
	{
		"name": "The Seeker",
		"portrait": "res://assets/textures/player2/_Faces/face_normal.png",
		"text": "\"Nếu quyển sách này gọi mình đến đây, có lẽ nó biết mình là ai.\""
	},
]

func _ready():
	if lib1_music != null:
		BgmManager.play_music(lib1_music, -1)
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
