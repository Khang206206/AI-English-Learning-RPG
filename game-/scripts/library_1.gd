extends Node2D
@export var lib1_music: AudioStream

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
