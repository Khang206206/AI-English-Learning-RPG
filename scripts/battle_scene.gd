extends Control

# 1. KÉO THẢ CÁC NODE VÀO BIẾN
@onready var question_label = $UI/MainPanel/question/QuestionBox/Label
@onready var btn_a = $UI/MainPanel/Answers/BtnA
@onready var btn_b = $UI/MainPanel/Answers/BtnB
@onready var btn_c = $UI/MainPanel/Answers/BtnC
@onready var btn_d = $UI/MainPanel/Answers/BtnD
@onready var answers_abcd_panel = $UI/MainPanel/Answers
@onready var text_input_panel = $UI/MainPanel/TextInputPanel
@onready var word_input = $UI/MainPanel/TextInputPanel/WordInput
@onready var submit_btn = $UI/MainPanel/TextInputPanel/SubmitBtn

@onready var ai_tutor_popup = $UI/AITutorPopup
@onready var explanation_text = $UI/AITutorPopup/ExplanationText
@onready var popup_close_btn = $UI/AITutorPopup/CloseBtn

@onready var player_hearts_container = $UI/MainPanel/TopHUD/PlayerHearts
@onready var monster_hearts_container = $UI/MainPanel/TopHUD/MonsterHearts
@onready var monster_anim = $Node2D/Monster_Anim
@onready var player_anim = $Node2D/Player_Anim
@onready var result_overlay = $ResultOverlay
@onready var result_label = $ResultOverlay/Label
@onready var try_again_btn = $ResultOverlay/TryAgain
@onready var go_back_btn = $ResultOverlay/GoBack
@onready var panel_border = $ResultOverlay/PanelBorder012
@onready var go_back2_btn = $ResultOverlay/GoBack2
@onready var panel_border2 = $ResultOverlay/PanelBorder013
@onready var panel_border3 = $ResultOverlay/PanelBorder014
@onready var bgm_player = $BGM_Player
@onready var victory_sfx = $Victory_SFX
@onready var defeat_sfx = $Defeat_SFX

@onready var magic_timer = $MagicTimer
@onready var btn_fire = $UI/MainPanel/MagicBullets/BtnFire
@onready var btn_electric = $UI/MainPanel/MagicBullets/BtnElectric
@onready var btn_ice = $UI/MainPanel/MagicBullets/BtnIce
@onready var btn_wood = $UI/MainPanel/MagicBullets/BtnWood

@onready var btn_potion = get_node_or_null("UI/MainPanel/Items/BtnPotion")
@onready var btn_fifty = get_node_or_null("UI/MainPanel/Items/BtnFifty")
@onready var btn_skip = get_node_or_null("UI/MainPanel/Items/BtnSkip")
@onready var btn_freeze = get_node_or_null("UI/MainPanel/Items/BtnFreeze")

@onready var label_potion = get_node_or_null("UI/MainPanel/Items/BtnPotion/Label")
@onready var label_fifty = get_node_or_null("UI/MainPanel/Items/BtnFifty/Label")
@onready var label_skip = get_node_or_null("UI/MainPanel/Items/BtnSkip/Label")
@onready var label_freeze = get_node_or_null("UI/MainPanel/Items/BtnFreeze/Label")

var current_bullet: String = "normal"
var is_monster_frozen: bool = false
# 2. KHAI BÁO BIẾN TRẠNG THÁI (State)
var current_question: Dictionary
var player_hp: int
var monster_hp: int = 20
var heart_red = preload("res://resources/ui/hearts/Heart_Full.tres")
var heart_3_4 = preload("res://resources/ui/hearts/Heart_3_4.tres")
var heart_2_4 = preload("res://resources/ui/hearts/Heart_2_4.tres")
var heart_1_4 = preload("res://resources/ui/hearts/Heart_1_4.tres")
var heart_black = preload("res://resources/ui/hearts/Heart_Hit.tres")
var is_game_over: bool = false # Đánh dấu xem player đã "chết" chưa
var is_player_time_frozen: bool = false # Người chơi có đang bị phạt giảm 50% thời gian không
var is_magic_locked: int = 0
var revealed_letters_count: int = 0

const SPELL_SCENE = preload("res://scenes/spell_effect.tscn")
const ICE_EFFECT_SCENE = preload("res://scenes/ice_effect.tscn")
var current_ice_instance: AnimatedSprite2D = null # Biến giữ thực thể băng để xóa khi rã băng
# 3. GLUE CODE
func _ready():
	ai_tutor_popup.hide()
	player_anim.play("idle")
	if GameManager.current_monster:
		# Gán SpriteFrames từ resource truyền sang
		monster_anim.flip_h = GameManager.current_monster.flip_h
		monster_anim.sprite_frames = GameManager.current_monster.idle_animation
		if "scale" in GameManager.current_monster:
			monster_anim.scale = GameManager.current_monster.scale
		elif "monster_scale" in GameManager.current_monster:
			monster_anim.scale = GameManager.current_monster.monster_scale
		else:
			monster_anim.scale = Vector2(1.0, 1.0)
		monster_anim.position = Vector2(984, 379)
		if "position_offset" in GameManager.current_monster:
			monster_anim.position += GameManager.current_monster.position_offset
		elif "monster_position" in GameManager.current_monster: # Đề phòng bồ đặt tên biến khác
			monster_anim.position += GameManager.current_monster.monster_position
		
		monster_anim.play("idle") # Chạy animation idle
		
	else:
		push_warning("Không có dữ liệu quái!")

	# Đồng bộ HP thực từ DatabaseManager thay vì dùng giá trị hardcode
	var db = get_node_or_null("/root/DatabaseManager")
	if db:
		player_hp = db.player_hearts
		db.hp_changed.connect(_on_db_hp_changed)

	btn_a.pressed.connect(func(): check_answer("A"))
	btn_b.pressed.connect(func(): check_answer("B"))
	btn_c.pressed.connect(func(): check_answer("C"))
	btn_d.pressed.connect(func(): check_answer("D"))
	submit_btn.pressed.connect(func(): check_answer(word_input.text.strip_edges()))
	word_input.text_submitted.connect(func(new_text): check_answer(new_text.strip_edges()))
	
	try_again_btn.pressed.connect(_on_try_again_pressed)
	go_back_btn.pressed.connect(_on_go_back_pressed)
	go_back2_btn.pressed.connect(_on_go_back_pressed)
	result_overlay.hide()
	
	popup_close_btn.pressed.connect(close_tutor_and_continue)
	setup_hearts()
	load_next_question()
	if bgm_player != null:
		bgm_player.play()
	if magic_timer:
		magic_timer.timeout.connect(_on_timer_timeout)
	
	# --- KẾT NỐI TÍN HIỆU CHO 4 NÚT ĐẠN NGUYÊN TỐ ---
	btn_fire.toggled.connect(_on_btn_fire_toggled)
	btn_electric.toggled.connect(_on_btn_electric_toggled)
	btn_ice.toggled.connect(_on_btn_ice_toggled)
	btn_wood.toggled.connect(_on_btn_wood_toggled)
	
	# Tự động cấu hình hiệu ứng Hover phát sáng nhẹ khi di chuột qua
	for button in $UI/MainPanel/MagicBullets.get_children():
		if button is TextureButton:
			button.mouse_entered.connect(func():
				# Chỉ làm sáng nhẹ nếu nút ĐANG KHÔNG ĐƯỢC CHỌN và KHÔNG BỊ KHÓA
				if not button.disabled and not button.button_pressed:
					button.modulate = Color(1.3, 1.3, 1.3, 1.0)
			)
			button.mouse_exited.connect(func():
				# Khi chuột đi ra, gọi hàm cập nhật chuẩn để giữ màu sáng rực nếu nút đang được bấm
				_update_button_visuals(button, button.button_pressed)
			)
			# Đặt màu mặc định ban đầu cho nút
			_update_button_visuals(button, button.button_pressed)

	# Kết nối tín hiệu cho các nút vật phẩm
	if btn_potion: btn_potion.pressed.connect(_use_potion)
	if btn_fifty: btn_fifty.pressed.connect(_use_fifty_fifty)
	if btn_skip: btn_skip.pressed.connect(_use_skip)
	if btn_freeze: btn_freeze.pressed.connect(_use_time_freeze)

func _get_item_quantity(item_id: int) -> int:
	var inventory = ProgressManager.get_inventory()
	for item in inventory:
		if item["item_id"] == item_id:
			return item["quantity"]
	return 0

func update_item_ui():
	if btn_potion:
		var count = _get_item_quantity(1)
		btn_potion.disabled = count <= 0
		if label_potion: label_potion.text = str(count)
		
	if btn_fifty:
		var count = _get_item_quantity(2)
		btn_fifty.disabled = (count <= 0)
		if label_fifty: label_fifty.text = str(count)
		
	if btn_skip:
		var count = _get_item_quantity(3)
		btn_skip.disabled = count <= 0
		if label_skip: label_skip.text = str(count)
		
	if btn_freeze:
		var count = _get_item_quantity(4)
		btn_freeze.disabled = count <= 0
		if label_freeze: label_freeze.text = str(count)

func setup_hearts():
	for child in player_hearts_container.get_children():
		child.queue_free()
	for child in monster_hearts_container.get_children():
		child.queue_free()
	var p_slots = player_hp / 4 if player_hp % 4 == 0 else (player_hp / 4) + 1
	for i in range(p_slots):
		var new_heart = TextureRect.new()
		new_heart.texture = heart_red
		new_heart.custom_minimum_size = Vector2(32, 32)
		new_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		new_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		player_hearts_container.add_child(new_heart)
	
	var m_slots = monster_hp / 4 if monster_hp % 4 == 0 else (monster_hp / 4) + 1	
	for i in range(m_slots):
		var new_heart = TextureRect.new()
		new_heart.texture = heart_red
		new_heart.custom_minimum_size = Vector2(32, 32)
		new_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		new_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		monster_hearts_container.add_child(new_heart)

# --- LOAD CÂU HỎI TỨC THÌ (0.1 giây) ---
func load_next_question():
	if is_magic_locked > 0:
		is_magic_locked -= 1
		if is_magic_locked == 0:
			print("[Combat] Mạch ma thuật phục hồi ở câu hỏi này!")
		else:
			print("[Combat] Mạch ma thuật đang bị phong ấn ở câu hỏi này!")
	current_question = AIManager.get_question()
	question_label.text = current_question.get("question", "Lỗi hiển thị câu hỏi")
	word_input.text = "" # Xóa chữ hiệp cũ
	revealed_letters_count = 0
	set_buttons_disabled(false)
	var ui_mode = current_question.get("ui_mode", "mcq")
	if ui_mode == "mcq": 
		answers_abcd_panel.show()
		text_input_panel.hide()
		# Nạp chữ ABCD như cũ của bồ
		btn_a.text = "A. " + current_question.get("A", "")
		btn_b.text = "B. " + current_question.get("B", "")
		btn_c.text = "C. " + current_question.get("C", "")
		btn_d.text = "D. " + current_question.get("D", "")
	else:
		answers_abcd_panel.hide() 
		text_input_panel.show()
		word_input.grab_focus()
	set_buttons_disabled(false)
	if magic_timer:
		magic_timer.show()
		magic_timer.start_timer()
	update_item_ui()


# 4. COMBAT STATE MACHINE
func check_answer(selected_choice: String):
	set_buttons_disabled(true)
	if magic_timer:
		magic_timer.stop_timer()

	var word_id: int     = current_question.get("word_id", -1)
	var grammar_id: int  = current_question.get("grammar_id", -1)
	var is_grammar: bool = (grammar_id != -1)
	var ui_mode = current_question.get("ui_mode", "mcq")
	var is_correct: bool = false

	if ui_mode == "mcq":
		is_correct = selected_choice == current_question["correct_answer"]
	else:
		var answer_input = selected_choice.to_lower().strip_edges()
		var correct_ans = str(current_question.get("correct_answer", "")).to_lower().strip_edges()
		var alternatives = current_question.get("accept_alternatives", [])
		is_correct = (answer_input == correct_ans) or (answer_input in alternatives)

	if is_correct:
		player_anim.position.y -= 40
		player_anim.play("attack")
		await get_tree().create_timer(0.1).timeout
		if SPELL_SCENE:
			var spell = SPELL_SCENE.instantiate()
			
			# 1. PHẢI ĐƯA VIÊN ĐẠN VÀO CÂY NODE TRƯỚC ĐỂ NÓ CÓ CHA TỔ TIÊN
			get_node("Node2D").add_child(spell) 
			
			# Tính toán vị trí (Giữ nguyên)
			var start_p = player_anim.global_position + Vector2(10, -5)
			var target_p = monster_anim.global_position
			
			# 2. RỒI MỚI GỌI LỆNH BẮN BAY ĐI
			spell.shoot(start_p, target_p)
		# Đợi animation kết thúc mới tiếp tục logic
		await player_anim.animation_finished 
		player_anim.position.y += 40
		player_anim.play("idle")
		match current_bullet:
			"fire":
				monster_hp -= 5 # Đạn lửa bạo kích mạnh: -5 máu lẻ (1 tim và 1/4 tim)
				print("[Combat] Đạn Lửa thiêu đốt! Quái bị trừ 5 máu.")
			"wood":
				monster_hp -= 4 # Đạn mộc gây sát thương cơ bản
				# Hồi lại 1 HP cho Player nhưng không vượt quá trần 20
				player_hp = clampi(player_hp + 1, 0, 20)
				# Đồng bộ ngược xuống DB để lưu trữ tiến trình tim mới hồi
				DatabaseManager.player_hearts = player_hp
				print("[Combat] Đạn Mộc hút máu! Hồi 1 HP cho người chơi.")
			"ice":
				monster_hp -= 4
				if randf() <= 0.5:
					is_monster_frozen = true 
					print("[Combat] Đạn Băng kích hoạt ĐÓNG BĂNG THÀNH CÔNG (50%)!")
					
					# ĐỨNG HÌNH QUÁI VÀ SINH KHỐI BĂNG:
					monster_anim.pause() # Dừng animation idle của quái vật lại
					
					if ICE_EFFECT_SCENE:
						var ice = ICE_EFFECT_SCENE.instantiate()
						get_node("Node2D").add_child(ice)
						ice.global_position = monster_anim.global_position
						current_ice_instance = ice
				else:
					is_monster_frozen = false
					print("[Combat] Đạn Băng trúng quái nhưng quái KHÔNG bị đóng băng (Xui xẻo)!")
			"electric":
				current_bullet = "electric"
				# ⚡ ĐẠN ĐIỆN ĐÂY NHA BỒ:
				monster_hp -= 4 # Gây 4 sát thương cơ bản
				print("[Combat] Đạn Điện giật tê liệt! Hiệp kế tiếp la bàn đếm ngược tăng lên 30 giây.")
			_:
				monster_hp -= 4 # Các hệ đạn khác (normal, ice, electric) gây 4 sát thương cơ bản
		update_health_ui()
		if is_grammar:
			ProgressManager.update_grammar_after_answer(grammar_id, true)
		else:
			ProgressManager.update_after_answer(word_id, true)
		print("Đánh trúng quái! Quái còn: ", monster_hp, " máu")
		
		if monster_hp <= 0:
			win_battle()
		else:
			await get_tree().create_timer(1.0).timeout
			load_next_question()
			
	else:
		if SPELL_SCENE:
			if is_monster_frozen:
				print("[Combat] Quái đang bị đóng băng! May quá không bị phản công.")
				is_monster_frozen = false
				# BỔ SUNG: Rã băng đồ họa và cho quái chạy tiếp idle
				if current_ice_instance and is_instance_valid(current_ice_instance):
					current_ice_instance.play("ending")
					await current_ice_instance.animation_finished
					current_ice_instance.queue_free()
				monster_anim.play("idle") # Cho quái thở tiếp
				
				await get_tree().create_timer(1.0).timeout
				load_next_question()
				return
			var spell = SPELL_SCENE.instantiate()
			get_node("Node2D").add_child(spell)
			# Điểm xuất phát: Từ giữa quái | Điểm đích: Vị trí của Player
			var start_p = monster_anim.global_position
			var target_p = player_anim.global_position + Vector2(10, -5)
			spell.shoot(start_p, target_p)
			await get_tree().create_timer(1.1).timeout
			var damage_will_take 
			if current_bullet == "fire":
				damage_will_take = 5
			else:
				damage_will_take = 4
			if player_hp - damage_will_take > 0: # Nếu trúng phát này mà chưa chết thì mới giật hit
				player_anim.play("hit")
				# Chờ anim hit diễn ra xong (tầm 0.2 - 0.3s) rồi trả về idle
				await get_tree().create_timer(0.3).timeout 
				player_anim.play("idle")
		# -------------------------------------------------------------------

		# Gọi ProgressManager xử lý trừ tim trong hệ thống và lưu SQLite
		if is_grammar:
			ProgressManager.update_grammar_after_answer(grammar_id, false)
		else:
			ProgressManager.update_after_answer(word_id, false)
		if current_bullet == "wood":
			monster_hp = clampi(monster_hp + 1, 0, 20) # Quái hút tinh hoa hồi 1 HP
			print("[Combat] Đạn Mộc phản pháo! Quái vật được hồi 1 HP.")
		if current_bullet == "fire":
			player_hp = max(0, player_hp - 1) # Bị quái phản công rát, trừ thêm 1 máu lẻ nữa (Tổng cộng thành 5)
			DatabaseManager.player_hearts = player_hp # Cập nhật lại cho DB giữ state
			print("[Combat] Đạn Lửa nổ ngược! Người chơi bị vả tổng cộng 5 máu.")
		if current_bullet == "ice":
			is_player_time_frozen = true
			print("[Combat] Đạn Băng nổ ngược! Bị đóng băng thanh thời gian ở hiệp sau.")
		if current_bullet == "electric":
			is_magic_locked = 2
			current_bullet = "normal"
			btn_electric.button_pressed = false # Nhả nút điện ra
			print("[Combat] Hết giờ khi dùng đạn Điện! Khóa mạch ma thuật ở hiệp sau.")

		update_health_ui()
		# Cập nhật lại biến player_hp local từ DatabaseManager để UI vẽ tim cho đúng
		player_hp = DatabaseManager.player_hearts 
		update_health_ui()
		explanation_text.text = current_question.get("explanation", "Rất tiếc, bạn đã chọn sai!")
		ai_tutor_popup.show()
		
		if player_hp <= 0:
			player_anim.play("die") # Chạy animation die của Player
			is_game_over = true

func close_tutor_and_continue():
	ai_tutor_popup.hide()
	if is_game_over:
		lose_battle()
	if player_hp > 0:
		load_next_question()

func set_buttons_disabled(is_disabled: bool):
	btn_a.disabled = is_disabled
	btn_b.disabled = is_disabled
	btn_c.disabled = is_disabled
	btn_d.disabled = is_disabled
	
	if not is_disabled:
		btn_a.modulate.a = 1.0
		btn_b.modulate.a = 1.0
		btn_c.modulate.a = 1.0
		btn_d.modulate.a = 1.0
	
	btn_fire.disabled = is_disabled
	btn_electric.disabled = is_disabled
	btn_ice.disabled = is_disabled
	btn_wood.disabled = is_disabled
	
	word_input.editable = !is_disabled
	submit_btn.disabled = is_disabled
	
	if is_magic_locked > 0 and not is_disabled:
		btn_fire.disabled = true
		btn_electric.disabled = true
		btn_ice.disabled = true
		btn_wood.disabled = true
	else:
		btn_fire.disabled = is_disabled
		# Trạng thái bình thường hoặc đang trong lúc chờ animation chạy
		btn_fire.disabled = is_disabled
		btn_electric.disabled = is_disabled
		btn_ice.disabled = is_disabled
		btn_wood.disabled = is_disabled
	
	# Bỏ dòng "if is_disabled:" cũ đi, luôn luôn ép cập nhật màu sắc mỗi khi trạng thái thay đổi
	_update_button_visuals(btn_fire, btn_fire.button_pressed)
	_update_button_visuals(btn_electric, btn_electric.button_pressed)
	_update_button_visuals(btn_ice, btn_ice.button_pressed)
	_update_button_visuals(btn_wood, btn_wood.button_pressed)

func win_battle():
	if current_ice_instance and is_instance_valid(current_ice_instance):
			current_ice_instance.queue_free()
	if magic_timer: magic_timer.hide()
	print("Victory!")
	if bgm_player != null and bgm_player.playing:
		bgm_player.stop() # Tắt nhạc nền đi
	if victory_sfx != null:
		victory_sfx.play() # Bật nhạc Victory
	var db = get_node_or_null("/root/DatabaseManager")
	if db:
		db.restore_full_hp()
	
	if GameManager.current_enemy_id > 0:
		DatabaseManager.mark_enemy_dead(GameManager.current_enemy_id)
		
	show_result_overlay(true)
	set_buttons_disabled(true)

func lose_battle():
	if current_ice_instance and is_instance_valid(current_ice_instance):
		current_ice_instance.queue_free()
	if magic_timer: magic_timer.hide()
	print("Game Over!")
	if bgm_player != null and bgm_player.playing:
		bgm_player.stop() # Tắt nhạc nền đi
	if defeat_sfx != null:
		defeat_sfx.play() # Bật nhạc Defeat
	var db = get_node_or_null("/root/DatabaseManager")
	if db:
		db.restore_full_hp()
	show_result_overlay(false)
	set_buttons_disabled(true)
	
func update_health_ui():
	var p_hearts = player_hearts_container.get_children()
	for i in range(p_hearts.size()):
		var heart_idx = i + 1
		if player_hp >= heart_idx * 4:
			p_hearts[i].texture = heart_red
		elif player_hp <= (heart_idx - 1) * 4:
			p_hearts[i].texture = heart_black
		else:
			var remainder = player_hp % 4
			match remainder:
				3: p_hearts[i].texture = heart_3_4
				2: p_hearts[i].texture = heart_2_4
				1: p_hearts[i].texture = heart_1_4
				_: p_hearts[i].texture = heart_black

	var m_hearts = monster_hearts_container.get_children()
	for i in range(m_hearts.size()):
		var heart_idx = i + 1
		if monster_hp >= heart_idx * 4:
			m_hearts[i].texture = heart_red
		elif monster_hp <= (heart_idx - 1) * 4:
			m_hearts[i].texture = heart_black
		else:
			var remainder = monster_hp % 4
			match remainder:
				3: m_hearts[i].texture = heart_3_4
				2: m_hearts[i].texture = heart_2_4
				1: m_hearts[i].texture = heart_1_4
				_: m_hearts[i].texture = heart_black
func show_result_overlay(is_win: bool):
	var background = $ResultOverlay/BG

	# Reset alpha về 0 cho tất cả elements trước khi tween
	background.modulate.a    = 0
	result_label.modulate.a  = 0
	go_back_btn.modulate.a   = 0
	go_back2_btn.modulate.a  = 0
	try_again_btn.modulate.a = 0
	panel_border.modulate.a  = 0
	panel_border2.modulate.a = 0
	panel_border3.modulate.a = 0

	if is_win:
		go_back_btn.visible   = false
		go_back2_btn.visible  = true
		try_again_btn.visible = false
		panel_border.visible  = false
		panel_border2.visible = false
		panel_border3.visible = true
		result_label.text     = "VICTORY!"
	else:
		go_back_btn.visible   = true
		go_back2_btn.visible  = false
		try_again_btn.visible = true
		panel_border.visible  = true
		panel_border2.visible = true
		panel_border3.visible = false
		result_label.text     = "GAME OVER!"

	result_overlay.show()

	# Tween fade-in cho các element đang visible
	var tween = create_tween()
	tween.parallel().tween_property(background,   "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(result_label, "modulate:a", 1.0, 0.5)

	if is_win:
		tween.parallel().tween_property(go_back2_btn,  "modulate:a", 1.0, 0.5)
		tween.parallel().tween_property(panel_border3, "modulate:a", 1.0, 0.5)
	else:
		tween.parallel().tween_property(go_back_btn,   "modulate:a", 1.0, 0.5)
		tween.parallel().tween_property(try_again_btn, "modulate:a", 1.0, 0.5)
		tween.parallel().tween_property(panel_border,  "modulate:a", 1.0, 0.5)
		tween.parallel().tween_property(panel_border2, "modulate:a", 1.0, 0.5)

	set_buttons_disabled(true)
	
func _on_try_again_pressed():
	get_tree().reload_current_scene()

func _on_go_back_pressed():
	get_tree().change_scene_to_file(GameManager.previous_scene_path)

# Lắng nghe signal từ DatabaseManager — đồng bộ HP runtime khi DB thay đổi
func _on_db_hp_changed(new_hp: int):
	player_hp = new_hp
	
func _on_timer_timeout():
	set_buttons_disabled(true)
	var word_id: int = current_question.get("word_id", -1)
	var grammar_id: int = current_question.get("grammar_id", -1)
	var is_grammar: bool = (grammar_id != -1)
	if SPELL_SCENE:
		if is_monster_frozen:
			print("[Combat] Quái đang bị đóng băng! May quá không bị phản công.")
			is_monster_frozen = false
			# BỔ SUNG: Rã băng đồ họa và cho quái chạy tiếp idle
			if current_ice_instance and is_instance_valid(current_ice_instance):
				current_ice_instance.play("ending") # Xóa block băng
				await current_ice_instance.animation_finished
				current_ice_instance.queue_free()
			monster_anim.play("idle") # Cho quái thở tiếp
				
			await get_tree().create_timer(1.0).timeout
			load_next_question()
			return
			
		var spell = SPELL_SCENE.instantiate()
		get_node("Node2D").add_child(spell)
		
		# Điểm xuất phát từ quái sang người chơi
		var start_p = monster_anim.global_position
		var target_p = player_anim.global_position + Vector2(10, -5)
		
		# Đợi đạn bay cắm vào người Player xong xuôi đã
		spell.shoot(start_p, target_p)
		await get_tree().create_timer(1.1).timeout
		var damage_will_take
		if current_bullet == "fire":
			damage_will_take = 5
		else:
			damage_will_take = 4
		if player_hp - damage_will_take > 0: # Nếu trúng phát này mà chưa chết thì mới giật hit
				player_anim.play("hit")
				# Chờ anim hit diễn ra xong (tầm 0.2 - 0.3s) rồi trả về idle
				await get_tree().create_timer(0.3).timeout 
				player_anim.play("idle")
	if is_grammar:
		ProgressManager.update_grammar_after_answer(grammar_id, false)
	else:
		ProgressManager.update_after_answer(word_id, false)
	if current_bullet == "wood":
			monster_hp = clampi(monster_hp + 1, 0, 20) # Quái hút tinh hoa hồi 1 HP
			print("[Combat] Đạn Mộc phản pháo! Quái vật được hồi 1 HP.")
	if current_bullet == "fire":
		player_hp = max(0, player_hp - 1) # Phạt thêm 1 máu lẻ (Tổng cộng thành 5)
		DatabaseManager.player_hearts = player_hp
		print("[Combat] Hết giờ! Đạn Lửa quá nhiệt nổ ngược 5 máu.")
	if current_bullet == "ice":
			is_player_time_frozen = true
			print("[Combat] Đạn Băng nổ ngược! Bị đóng băng thanh thời gian ở hiệp sau.")
	if current_bullet == "electric":
		is_magic_locked = 2
		current_bullet = "normal"
		btn_electric.button_pressed = false # Nhả nút điện ra
		print("[Combat] Hết giờ khi dùng đạn Điện! Khóa mạch ma thuật ở hiệp sau.")
	player_hp = DatabaseManager.player_hearts 
	update_health_ui()
	explanation_text.text = "Đã hết thời gian suy nghĩ! " + current_question.get("explanation", "")
	ai_tutor_popup.show()
	if player_hp <= 0:
		player_anim.play("die")
		is_game_over = true
# Hàm đổi màu nút theo trạng thái (Bình thường / Chọn sáng rực / Khóa mờ)
func _update_button_visuals(button: TextureButton, is_pressed: bool):
	if button.disabled:
		button.modulate = Color(0.2, 0.2, 0.2, 0.6) # Khóa mờ tịt
	elif is_pressed:
		button.modulate = Color(1.8, 1.8, 1.8, 1.0) # Chọn sáng rực HDR
	else:
		button.modulate = Color.WHITE # Trở về màu gốc

# Logic xử lý Toggle: Nhấp nút này tự nhả 3 nút kia ra, nhấp lại lần nữa về đạn thường
func _on_btn_fire_toggled(toggled_on: bool):
	_update_button_visuals(btn_fire, toggled_on)
	if toggled_on:
		current_bullet = "fire"
		btn_electric.button_pressed = false
		btn_ice.button_pressed = false
		btn_wood.button_pressed = false
	elif current_bullet == "fire":
		current_bullet = "normal"

func _on_btn_electric_toggled(toggled_on: bool):
	_update_button_visuals(btn_electric, toggled_on)
	if toggled_on:
		current_bullet = "electric"
		btn_fire.button_pressed = false
		btn_ice.button_pressed = false
		btn_wood.button_pressed = false
	elif current_bullet == "electric":
		current_bullet = "normal"

func _on_btn_ice_toggled(toggled_on: bool):
	_update_button_visuals(btn_ice, toggled_on)
	if toggled_on:
		current_bullet = "ice"
		btn_fire.button_pressed = false
		btn_electric.button_pressed = false
		btn_wood.button_pressed = false
	elif current_bullet == "ice":
		current_bullet = "normal"

func _on_btn_wood_toggled(toggled_on: bool):
	_update_button_visuals(btn_wood, toggled_on)
	if toggled_on:
		current_bullet = "wood"
		btn_fire.button_pressed = false
		btn_electric.button_pressed = false
		btn_ice.button_pressed = false
	elif current_bullet == "wood":
		current_bullet = "normal"

# ==========================================
# CÁC HÀM XỬ LÝ VẬT PHẨM (ITEMS)
# ==========================================
func _use_potion():
	if ProgressManager.consume_item(1):
		player_hp = clampi(player_hp + 4, 0, 20)
		DatabaseManager.player_hearts = player_hp
		update_health_ui()
		update_item_ui()
		print("[Battle] Dùng Tinh Dược Sinh Lực! HP: %d" % player_hp)

func _use_fifty_fifty():
	var ui_mode = current_question.get("ui_mode", "mcq")
	if ui_mode == "mcq":
		if ProgressManager.consume_item(2):
			var correct = current_question["correct_answer"]
			var wrong_btns = []
			for label in ["A", "B", "C", "D"]:
				if label != correct:
					wrong_btns.append(label)
			wrong_btns.shuffle()
			for i in range(2):
				match wrong_btns[i]:
					"A": btn_a.disabled = true; btn_a.modulate.a = 0.3
					"B": btn_b.disabled = true; btn_b.modulate.a = 0.3
					"C": btn_c.disabled = true; btn_c.modulate.a = 0.3
					"D": btn_d.disabled = true; btn_d.modulate.a = 0.3
			update_item_ui()
			print("[Battle] Dùng Lá Bài Tiên Tri! Ẩn 2 đáp án sai.")
	else:
		var correct_ans = str(current_question.get("correct_answer", "")).strip_edges()
		if correct_ans == "": return
		
		if revealed_letters_count >= correct_ans.length():
			print("[Battle] Đã hiển thị toàn bộ đáp án!")
			return
			
		if ProgressManager.consume_item(2):
			revealed_letters_count += 1
			while revealed_letters_count < correct_ans.length() and correct_ans[revealed_letters_count - 1] == " ":
				revealed_letters_count += 1
				
			var revealed_str = correct_ans.substr(0, revealed_letters_count)
			word_input.text = revealed_str
			word_input.caret_column = revealed_str.length()
			
			update_item_ui()
			print("[Battle] Dùng Lá Bài Tiên Tri! Hé lộ: ", revealed_str)

func _use_skip():
	if ProgressManager.consume_item(3):
		print("[Battle] Dùng Cuộn Giấy Không Gian! Bỏ qua câu hỏi.")
		if magic_timer: magic_timer.stop_timer()
		update_item_ui()
		load_next_question()

func _use_time_freeze():
	if ProgressManager.consume_item(4):
		print("[Battle] Dùng Băng Phong Thời Gian!")
		if magic_timer:
			magic_timer.stop_timer()
			# Khởi tạo timer 10s độc lập
			var timer = get_tree().create_timer(10.0)
			timer.timeout.connect(func():
				# Chỉ chạy lại timer nếu game chưa kết thúc và vẫn ở câu hỏi hiện tại
				if not is_game_over and magic_timer and !btn_a.disabled:
					magic_timer.start_timer()
					print("[Battle] Hết hiệu lực Băng Phong Thời Gian!")
			)
		update_item_ui()
