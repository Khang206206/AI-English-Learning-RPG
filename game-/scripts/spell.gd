extends Node2D

@onready var anim = $AnimatedSprite2D 

func shoot(start_pos: Vector2, target_pos: Vector2):
	global_position = start_pos
	
	# 1. TỰ ĐỘNG ĐI TÌM BATTLE SCENE ĐỂ XEM ĐANG CHỌN ĐẠN GÌ
	var current_bullet = "normal"
	
	# Tìm kiếm xuyên suốt cây node để lôi bằng được node có tên "BattleScene" ra
	var battle_scene = get_tree().current_scene.find_child("BattleScene", true, false)
	
	# Dự phòng nếu BattleScene chính là node gốc ngoài cùng
	if not battle_scene and get_tree().current_scene.name == "BattleScene":
		battle_scene = get_tree().current_scene

	if battle_scene and "current_bullet" in battle_scene:
		current_bullet = battle_scene.current_bullet # Lấy chuẩn hệ đạn!

	# 2. ĐỊNH NGHĨA ANIMATION VÀ KÍCH THƯỚC THEO TỪNG HỆ ĐẠN ĐÃ CHỌN
	var anim_name: String = "spell1" 
	var target_scale: Vector2 = Vector2(3.0, 3.0) 
	
	match current_bullet:
		"fire":
			anim_name = "fire1" # Mai mốt sửa chữ "spell1" thành "fire" nha Phú
			target_scale = Vector2(6.0, 6.0)
		"electric":
			anim_name = "electric1" # Sửa thành "electric" sau
			target_scale = Vector2(3.0, 3.0)
		"ice":
			anim_name = "ice1" # Sửa thành "ice" sau
			target_scale = Vector2(3.0, 3.0)
		"wood":
			anim_name = "wood1" # Sửa thành "wood" sau
			target_scale = Vector2(3.0, 3.0)
		"normal":
			anim_name = "normal" # Đạn thường mặc định bay bốc ngẫu nhiên hoặc mặc định là spell1
			target_scale = Vector2(3.0, 3.0)

	# 3. CHẠY ANIMATION VÀ ÉP KÍCH THƯỚC
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
		scale = target_scale
	if start_pos.x > target_pos.x:
		scale.x = -abs(scale.x)
	# 4. LOGIC BAY GIỮ NGUYÊN
	var tween = create_tween()
	var fly_destination = target_pos 
	
	tween.tween_property(self, "global_position", fly_destination, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 2.0) 
	
	await tween.finished
	queue_free()
