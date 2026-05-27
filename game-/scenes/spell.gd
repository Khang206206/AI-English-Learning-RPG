extends Node2D

@onready var anim = $AnimatedSprite2D 

func shoot(start_pos: Vector2, target_pos: Vector2):
	global_position = start_pos
	
	# 1. TẠO TỪ ĐIỂN CHỨA TÊN PHÉP VÀ KÍCH THƯỚC (SCALE) TƯƠNG ỨNG
	var spell_data = {
		"spell1": Vector2(6.0, 6.0), 
		"spell2": Vector2(3, 3), 
		"spell3": Vector2(3, 3),
		"spell4": Vector2(3, 3)
		
	}
	
	# 2. LẤY NGẪU NHIÊN VÀ ÁP DỤNG
	var spell_list = spell_data.keys() # Lấy ra danh sách ["spell1", "spell2"]
	var random_spell = spell_list.pick_random()
	
	if anim.sprite_frames.has_animation(random_spell):
		anim.play(random_spell)
		# Ép kích thước (scale) của cục phép bằng đúng thông số đã cài ở trên
		scale = spell_data[random_spell] 
	
	# 3. LOGIC BAY NHƯ CŨ
	var tween = create_tween()
	var fly_destination = target_pos 
	
	tween.tween_property(self, "global_position", fly_destination, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 2.0) 
	
	await tween.finished
	queue_free()
