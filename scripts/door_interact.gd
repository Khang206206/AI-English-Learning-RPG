extends Area2D # Nên dùng Area2D thay vì Node2D để tối ưu va chạm 

# Cho phép chọn map đích trực tiếp từ Inspector
@export_file("*.tscn") var target_scene_path: String 
# Tên Marker2D ở map bên kia nhân vật sẽ xuất hiện
@export var destination_spawn_id: String 

# Sử dụng % để tìm node theo tên độc nhất, tránh lỗi đường dẫn 
@onready var door_prompt = %DoorInteract 

var is_player_inside = false

func _ready():
	# Kiểm tra an toàn để tránh lỗi "null instance" 
	if door_prompt:
		door_prompt.hide()
	else:
		print("Cảnh báo: Không tìm thấy node DoorInteract. Hãy chuột phải vào node đó và chọn 'Access as Unique Name'")

	# Kết nối tín hiệu 
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name.contains("Player"):
		is_player_inside = true
		if door_prompt: door_prompt.show()

func _on_body_exited(body):
	if body.name.contains("Player"):
		is_player_inside = false
		if door_prompt: door_prompt.hide()

func _input(event):
	# Kiểm tra phím F và người chơi đang đứng trong vùng 
	if is_player_inside and event.is_action_pressed("interact"):
		open_door()

func open_door():
	if target_scene_path == "":
		print("Cửa này chưa có địa chỉ map đích!")
		return
	
	# Lưu ID điểm xuất hiện vào GameManager trước khi đi [cite: 3, 4]
	if destination_spawn_id != "":
		GameManager.target_spawn_id = destination_spawn_id
	
	print("Đang di chuyển sang: ", target_scene_path)
	get_tree().change_scene_to_file(target_scene_path)
