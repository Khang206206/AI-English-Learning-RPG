extends Node2D

func _ready():
	# 1. Kiểm tra an toàn xem GameManager có tồn tại không
	if GameManager == null:
		print("LỖI: GameManager chưa được đăng ký trong Autoload!")
		return

	# 2. Kiểm tra xem có yêu cầu xuất hiện ở vị trí cụ thể nào không
	if GameManager.target_spawn_id != "":
		# Tìm node Marker2D dựa trên tên đang lưu
		var spawn_point = get_node_or_null(GameManager.target_spawn_id) 
		
		if spawn_point:
			# Kiểm tra xem node PlayerSideView có tồn tại không
			var player = get_node_or_null("PlayerSideView")
			if player:
				player.global_position = spawn_point.global_position 
				print("Đã đặt nhân vật vào vị trí: ", GameManager.target_spawn_id)
			else:
				print("LỖI: Không tìm thấy node PlayerSideView trong Scene này!")
		else:
			print("LỖI: Không tìm thấy Marker2D có tên: ", GameManager.target_spawn_id)
		
		# 3. Xóa ID sau khi dùng [cite: 9]
		GameManager.target_spawn_id = ""
