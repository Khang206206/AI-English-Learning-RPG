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
var current_bullet: String = "normal"
# 2. KHAI BÁO BIẾN TRẠNG THÁI (State)
var current_question: Dictionary
var player_hp: int
var monster_hp: int = 5
var heart_red = preload("res://assets/hearts/Heart_Full.tres")
var heart_black = preload("res://assets/hearts/Heart_Hit.tres")
var is_game_over: bool = false # Đánh dấu xem player đã "chết" chưa

const SPELL_SCENE = preload("res://scenes/spell_effect.tscn")
# 3. GLUE CODE
func _ready():
	ai_tutor_popup.hide()
	player_anim.play("idle")
	if GameManager.current_monster:
		# Gán SpriteFrames từ resource truyền sang
		monster_anim.flip_h = GameManager.current_monster.flip_h
		monster_anim.sprite_frames = GameManager.current_monster.idle_animation
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

func setup_hearts():
	for child in player_hearts_container.get_children():
		child.queue_free()
	for child in monster_hearts_container.get_children():
		child.queue_free()
		
	for i in range(player_hp):
		var new_heart = TextureRect.new()
		new_heart.texture = heart_red
		new_heart.custom_minimum_size = Vector2(32, 32)
		new_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		new_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		player_hearts_container.add_child(new_heart)
		
	for i in range(monster_hp):
		var new_heart = TextureRect.new()
		new_heart.texture = heart_red
		new_heart.custom_minimum_size = Vector2(32, 32)
		new_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		new_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		monster_hearts_container.add_child(new_heart)

# --- LOAD CÂU HỎI TỨC THÌ (0.1 giây) ---
func load_next_question():
	current_question = AIManager.get_question()
	question_label.text = current_question.get("question", "Lỗi hiển thị câu hỏi")
	word_input.text = "" # Xóa chữ hiệp cũ
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

# 4. COMBAT STATE MACHINE
func check_answer(selected_choice: String):
	set_buttons_disabled(true)
	if magic_timer:
		magic_timer.stop_timer()

	var word_id: int     = current_question.get("word_id", -1)
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
		monster_hp -= 1
		update_health_ui()
		ProgressManager.update_after_answer(word_id, true)
		print("Đánh trúng quái! Quái còn: ", monster_hp, " máu")
		
		if monster_hp <= 0:
			win_battle()
		else:
			await get_tree().create_timer(1.0).timeout
			load_next_question()
			
	else:
		if SPELL_SCENE:
			var spell = SPELL_SCENE.instantiate()
			get_node("Node2D").add_child(spell)
			# Điểm xuất phát: Từ giữa quái | Điểm đích: Vị trí của Player
			var start_p = monster_anim.global_position
			var target_p = player_anim.global_position + Vector2(10, -5)
			spell.shoot(start_p, target_p)
			await get_tree().create_timer(1.1).timeout
			if player_hp > 1: # Nếu trúng phát này mà chưa chết thì mới giật hit
				player_anim.play("hit")
				# Chờ anim hit diễn ra xong (tầm 0.2 - 0.3s) rồi trả về idle
				await get_tree().create_timer(0.3).timeout 
				player_anim.play("idle")
		# -------------------------------------------------------------------

		# Gọi ProgressManager xử lý trừ tim trong hệ thống và lưu SQLite
		ProgressManager.update_after_answer(word_id, false)
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
	
	btn_fire.disabled = is_disabled
	btn_electric.disabled = is_disabled
	btn_ice.disabled = is_disabled
	btn_wood.disabled = is_disabled
	
	word_input.editable = !is_disabled
	submit_btn.disabled = is_disabled
	
	# Bỏ dòng "if is_disabled:" cũ đi, luôn luôn ép cập nhật màu sắc mỗi khi trạng thái thay đổi
	_update_button_visuals(btn_fire, btn_fire.button_pressed)
	_update_button_visuals(btn_electric, btn_electric.button_pressed)
	_update_button_visuals(btn_ice, btn_ice.button_pressed)
	_update_button_visuals(btn_wood, btn_wood.button_pressed)

func win_battle():
	if magic_timer: magic_timer.hide()
	print("Victory!")
	if bgm_player != null and bgm_player.playing:
		bgm_player.stop() # Tắt nhạc nền đi
	if victory_sfx != null:
		victory_sfx.play() # Bật nhạc Victory
	var db = get_node_or_null("/root/DatabaseManager")
	if db:
		db.restore_full_hp()
	show_result_overlay(true)
	set_buttons_disabled(true)

func lose_battle():
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
		if i < player_hp:
			p_hearts[i].texture = heart_red
		else:
			p_hearts[i].texture = heart_black

	var m_hearts = monster_hearts_container.get_children()
	for i in range(m_hearts.size()):
		if i < monster_hp:
			m_hearts[i].texture = heart_red
		else:
			m_hearts[i].texture = heart_black
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
	
	get_tree().change_scene_to_file("res://scenes/chapter_1.tscn")

# Lắng nghe signal từ DatabaseManager — đồng bộ HP runtime khi DB thay đổi
func _on_db_hp_changed(new_hp: int):
	player_hp = new_hp
	
func _on_timer_timeout():
	set_buttons_disabled(true)
	var word_id: int = current_question.get("word_id", -1)
	if SPELL_SCENE:
		var spell = SPELL_SCENE.instantiate()
		get_node("Node2D").add_child(spell)
		
		# Điểm xuất phát từ quái sang người chơi
		var start_p = monster_anim.global_position
		var target_p = player_anim.global_position + Vector2(10, -5)
		
		# Đợi đạn bay cắm vào người Player xong xuôi đã
		spell.shoot(start_p, target_p)
		await get_tree().create_timer(1.1).timeout
		if player_hp > 1: # Nếu trúng phát này mà chưa chết thì mới giật hit
				player_anim.play("hit")
				# Chờ anim hit diễn ra xong (tầm 0.2 - 0.3s) rồi trả về idle
				await get_tree().create_timer(0.3).timeout 
				player_anim.play("idle")
	ProgressManager.update_after_answer(word_id, false)
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
		
