extends Area2D

@export_file("*.tscn") var target_scene_path: String
@export var destination_spawn_id: String # Tên của Marker2D ở cảnh bên kia

@onready var prompt = $DoorInteract
var is_player_inside = false

func _input(event):
	if is_player_inside and event.is_action_pressed("interact"):
		# Thêm bước kiểm tra an toàn
		if GameManager == null:
			print("LỖI: GameManager chưa được nạp trong Autoload!")
			return
			
		# 1. Lưu ID điểm xuất hiện trước khi đi 
		GameManager.target_spawn_id = destination_spawn_id 
		
		# 2. Chuyển cảnh 
		if target_scene_path != "":
			get_tree().change_scene_to_file(target_scene_path) 
		else:
			print("Cảnh báo: Chưa chọn scene đích trong Inspector!")


func _ready():
	prompt.hide()
	# Kết nối tín hiệu
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name.contains("Player"):
		is_player_inside = true
		prompt.show()

func _on_body_exited(body):
	if body.name.contains("Player"):
		is_player_inside = false
		prompt.hide()


func change_scene():
	if target_scene_path == "":
		print("Cảnh báo: Bạn chưa chọn đường dẫn Scene đích!")
		return
		
	# Lệnh chuyển sang scene mới
	get_tree().change_scene_to_file(target_scene_path)
