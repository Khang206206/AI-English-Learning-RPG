extends Control

# 1. KÉO THẢ CÁC NODE VÀO BIẾN
@onready var question_label = $UI/MainPanel/question/QuestionBox/Label
@onready var btn_a = $UI/MainPanel/Answers/BtnA
@onready var btn_b = $UI/MainPanel/Answers/BtnB
@onready var btn_c = $UI/MainPanel/Answers/BtnC
@onready var btn_d = $UI/MainPanel/Answers/BtnD

@onready var ai_tutor_popup = $UI/AITutorPopup
@onready var explanation_text = $UI/AITutorPopup/ExplanationText
@onready var popup_close_btn = $UI/AITutorPopup/CloseBtn

@onready var player_hearts_container = $UI/MainPanel/TopHUD/PlayerHearts
@onready var monster_hearts_container = $UI/MainPanel/TopHUD/MonsterHearts

# 2. KHAI BÁO BIẾN TRẠNG THÁI (State)
var current_question: Dictionary
var player_hp: int = 3
var monster_hp: int = 15
var heart_red = preload("res://assets/hearts/Heart_Full.tres")
var heart_black = preload("res://assets/hearts/Heart_Hit.tres")

# 3. GLUE CODE
func _ready():
	ai_tutor_popup.hide()
	
	btn_a.pressed.connect(func(): check_answer("A"))
	btn_b.pressed.connect(func(): check_answer("B"))
	btn_c.pressed.connect(func(): check_answer("C"))
	btn_d.pressed.connect(func(): check_answer("D"))
	
	popup_close_btn.pressed.connect(close_tutor_and_continue)
	setup_hearts()
	load_next_question()

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
	# Lấy đạn từ kho ngầm AIManager
	current_question = AIManager.get_question()
	
	# Gán nội dung ngay lập tức lên UI
	question_label.text = current_question.get("question", "Lỗi hiển thị câu hỏi")
	btn_a.text = "A. " + current_question.get("A", "")
	btn_b.text = "B. " + current_question.get("B", "")
	btn_c.text = "C. " + current_question.get("C", "")
	btn_d.text = "D. " + current_question.get("D", "")
	
	set_buttons_disabled(false)

# 4. COMBAT STATE MACHINE
func check_answer(selected_choice: String):
	set_buttons_disabled(true)
	
	if selected_choice == current_question["correct_answer"]:
		monster_hp -= 1
		update_health_ui()
		print("Đánh trúng quái! Quái còn: ", monster_hp, " máu")
		
		if monster_hp <= 0:
			win_battle()
		else:
			await get_tree().create_timer(1.0).timeout
			load_next_question()
			
	else:
		player_hp -= 1
		update_health_ui()
		print("Sai rồi! Trừ 1 máu. Player còn: ", player_hp, " máu")
		
		explanation_text.text = current_question.get("explanation", "Rất tiếc, bạn đã chọn sai!")
		ai_tutor_popup.show()
		
		if player_hp <= 0:
			lose_battle()
		else:
			await get_tree().create_timer(4.0).timeout 
			ai_tutor_popup.hide()
			load_next_question()

func close_tutor_and_continue():
	ai_tutor_popup.hide()
	if player_hp > 0:
		load_next_question()

func set_buttons_disabled(is_disabled: bool):
	btn_a.disabled = is_disabled
	btn_b.disabled = is_disabled
	btn_c.disabled = is_disabled
	btn_d.disabled = is_disabled

func win_battle():
	print("Victory!")

func lose_battle():
	print("Game Over!")
	
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
