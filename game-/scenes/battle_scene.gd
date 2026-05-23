extends Control

# 1. KÉO THẢ CÁC NODE VÀO BIẾN (Chỉnh lại đường dẫn nếu cây Node của bạn khác)
@onready var question_label = $UI/MainPanel/QuestionBox/Label
@onready var btn_a = $UI/MainPanel/Answers/BtnA
@onready var btn_b = $UI/MainPanel/Answers/BtnB
@onready var btn_c = $UI/MainPanel/Answers/BtnC
@onready var btn_d = $UI/MainPanel/Answers/BtnD

@onready var ai_tutor_popup = $UI/AITutorPopup
@onready var explanation_text = $UI/AITutorPopup/ExplanationText
@onready var popup_close_btn = $UI/AITutorPopup/CloseBtn

# 2. KHAI BÁO BIẾN TRẠNG THÁI (State)
var current_question: Dictionary
var player_hp: int = 3
var monster_hp: int = 3

# 3. GLUE CODE: Chạy ngay khi Scene vừa mở lên
func _ready():
	# Ẩn popup Gia sư AI lúc mới vào
	ai_tutor_popup.hide()
	
	# Kết nối tín hiệu (Signal) khi bấm 4 nút vào 1 hàm chung
	btn_a.pressed.connect(func(): check_answer("A"))
	btn_b.pressed.connect(func(): check_answer("B"))
	btn_c.pressed.connect(func(): check_answer("C"))
	btn_d.pressed.connect(func(): check_answer("D"))
	
	# Kết nối nút đóng Popup
	popup_close_btn.pressed.connect(close_tutor_and_continue)
	
	# Lấy câu hỏi đầu tiên
	load_next_question()

# Hàm bốc câu hỏi từ AIManager và gán lên UI
func load_next_question():
	# Tạo câu hỏi giả (nhớ thụt lề bằng phím Tab cho toàn bộ đoạn này)
	current_question = {
		"question": "Which word is the closest in meaning to 'Intriguing'?",
		"A": "Boring",
		"B": "Fascinating",
		"C": "Annoying",
		"D": "Exhausting",
		"correct_answer": "B",
		"explanation": "Sai rồi! 'Intriguing' mang nghĩa là hấp dẫn, thú vị. Đồng nghĩa với nó phải là 'Fascinating'."
	}
	
	# Gán nội dung lên UI
	question_label.text = current_question["question"]
	btn_a.text = "A. " + current_question["A"]
	btn_b.text = "B. " + current_question["B"]
	btn_c.text = "C. " + current_question["C"]
	btn_d.text = "D. " + current_question["D"]

# 4. COMBAT STATE MACHINE: Xử lý khi người chơi chọn đáp án
func check_answer(selected_choice: String):
	# Khóa các nút lại để tránh người chơi spam click
	set_buttons_disabled(true)
	
	if selected_choice == current_question["correct_answer"]:
		# TRẢ LỜI ĐÚNG
		monster_hp -= 1
		update_health_ui() # (Bạn sẽ cần viết hàm ẩn bớt icon trái tim)
		
		# TODO: Phát animation quái mất máu tại đây
		print("Đánh trúng quái! Quái còn: ", monster_hp, " máu")
		
		if monster_hp <= 0:
			win_battle()
		else:
			# Đợi 1 chút rồi qua câu tiếp theo
			await get_tree().create_timer(1.0).timeout 
			load_next_question()
			set_buttons_disabled(false)
			
	else:
		# TRẢ LỜI SAI
		player_hp -= 1
		update_health_ui()
		
		# TODO: Phát animation Player mất máu tại đây
		print("Sai rồi! Trừ 1 máu. Player còn: ", player_hp, " máu")
		
		# Hiện Gia sư AI giải thích lỗi sai
		explanation_text.text = current_question["explanation"]
		ai_tutor_popup.show()
		
		if player_hp <= 0:
			lose_battle()

func close_tutor_and_continue():
	ai_tutor_popup.hide()
	# Nếu chưa chết thì load câu mới
	if player_hp > 0:
		load_next_question()
		set_buttons_disabled(false)

func set_buttons_disabled(is_disabled: bool):
	btn_a.disabled = is_disabled
	btn_b.disabled = is_disabled
	btn_c.disabled = is_disabled
	btn_d.disabled = is_disabled

func win_battle():
	print("Victory!")
	# TODO: Phát hiệu ứng win, cộng exp, rồi đóng scene
	# queue_free() # Tạm thời xóa scene để đóng

func lose_battle():
	print("Game Over!")
	# TODO: Hiện màn hình thua
	
func update_health_ui():
	pass # Phần này ta sẽ code để ẩn/hiện các node Trái tim sau
