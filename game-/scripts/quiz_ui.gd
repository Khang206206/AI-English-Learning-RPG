extends CanvasLayer

@onready var question_text = $QuestionText
@onready var prompt_text = $PromptText
@onready var btn_a = $AnswersContainer/Btn_A
@onready var btn_b = $AnswersContainer/Btn_B
@onready var btn_c = $AnswersContainer/Btn_C
@onready var btn_d = $AnswersContainer/Btn_D

var buttons = []
var current_question_index = 0
var has_answered = false
var user_results = []

var quiz_data = [
	{"question": "Câu 1: Từ nào sau đây có nghĩa là 'ngọn lửa lớn' hoặc 'đám cháy dữ dội'?", "options": ["A. Inferno", "B. Whisper", "C. Pavement", "D. Sibling"], "correct": 0},
	{"question": "Câu 2: Từ nào thể hiện ý nghĩa 'sự im lặng tuyệt đối' hay 'sự câm lặng'?", "options": ["A. Clamor", "B. Silence", "C. Echo", "D. Melody"], "correct": 1},
	{"question": "Câu 3: Từ nào diễn tả trạng thái 'u ám', 'tăm tối' hoặc 'ảm đạm' của một không gian?", "options": ["A. Radiant", "B. Vibrant", "C. Gloomy", "D. Luminous"], "correct": 2},
	{"question": "Câu 4: Từ nào mang ý nghĩa tâm linh là 'linh hồn' hoặc 'vật thể phi vật chất'?", "options": ["A. Armor", "B. Soul", "C. Shield", "D. Weapon"], "correct": 1},
	{"question": "Câu 5: Đâu là tính từ tiếng Anh có nghĩa là 'bị nguyền rủa'?", "options": ["A. Cursed", "B. Blessed", "C. Purified", "D. Sacred"], "correct": 0},
	{"question": "Câu 6: Từ nào có nghĩa là 'vực sâu' hoặc 'khoảng trống hắc ám không đáy'?", "options": ["A. Summit", "B. Abyss", "C. Plateau", "D. Valley"], "correct": 1},
	{"question": "Câu 7: Từ nào có nghĩa là 'lười biếng'?", "options": ["A. Diligent", "B. Energetic", "C. Lazy", "D. Creative"], "correct": 2},
	{"question": "Câu 8: Từ nào dùng để chỉ một 'bí mật chưa có lời giải' hoặc 'sự huyền bí'?", "options": ["A. Mystery", "B. Fact", "C. Evidence", "D. Truth"], "correct": 0},
	{"question": "Câu 9: Từ nào là động từ mang ý nghĩa 'hủy diệt', 'phá hủy' hoặc 'làm vỡ nát'?", "options": ["A. Create", "B. Construct", "C. Destroy", "D. Restore"], "correct": 2},
	{"question": "Câu 10: Từ nào có nghĩa là 'vĩnh cửu', 'mãi mãi' hoặc 'không bao giờ kết thúc'?", "options": ["A. Temporary", "B. Finite", "C. Brief", "D. Eternal"], "correct": 3},
	{"question": "Câu 11: Từ nào mang ý nghĩa tiêu cực chỉ 'sự tuyệt vọng tột cùng'?", "options": ["A. Despair", "B. Hope", "C. Joy", "D. Optimism"], "correct": 0},
	{"question": "Câu 12: Đâu là từ tiếng Anh có nghĩa là 'người dẫn đường' hoặc 'người hướng dẫn'?", "options": ["A. Guide", "B. Enemy", "C. Villain", "D. Target"], "correct": 0},
	{"question": "Câu 13: Từ nào nghĩa là 'tro bụi' hoặc 'tàn tro'?", "options": ["A. Ash", "B. Stone", "C. Water", "D. Metal"], "correct": 0},
	{"question": "Câu 14: Từ nào chỉ một 'cuốn sách ma thuật cổ đại'?", "options": ["A. Grimoire", "B. Magazine", "C. Newspaper", "D. Brochure"], "correct": 0},
	{"question": "Câu 15: Từ nào mang ý nghĩa hành động là 'thanh tẩy', 'làm sạch' khỏi độc tố?", "options": ["A. Purify", "B. Corrupt", "C. Infect", "D. Poison"], "correct": 0}
]

func _ready():
	hide()
	buttons = [btn_a, btn_b, btn_c, btn_d]
	
	for i in range(buttons.size()):
		buttons[i].focus_mode = Control.FOCUS_NONE
		buttons[i].pressed.connect(func(): _on_answer_selected(i))

func start_quiz():
	show()
	current_question_index = 0
	user_results.clear()
	load_question()
	get_tree().paused = true 

func load_question():
	has_answered = false
	prompt_text.hide()
	
	var q_data = quiz_data[current_question_index]
	question_text.text = q_data["question"]
	
	for i in range(buttons.size()):
		buttons[i].text = q_data["options"][i]
		buttons[i].modulate = Color.WHITE
		buttons[i].disabled = false

func _on_answer_selected(selected_index):
	if has_answered: return
	
	has_answered = true
	var correct_index = quiz_data[current_question_index]["correct"]
	
	var result_data = {
		"cau_hoi": current_question_index + 1,
		"cau_hoi_text": quiz_data[current_question_index]["question"],
		"da_chon": quiz_data[current_question_index]["options"][selected_index],
		"ket_qua": "Dung" if selected_index == correct_index else "Sai"
	}
	user_results.append(result_data)
	
	for i in range(buttons.size()):
		buttons[i].disabled = true
		if i == correct_index:
			buttons[i].modulate = Color.GREEN
		elif i == selected_index and selected_index != correct_index:
			buttons[i].modulate = Color.RED

	prompt_text.show()

func _input(event):
	if not visible or not has_answered:
		return
		
	var is_enter_pressed = event is InputEventKey and event.keycode == KEY_ENTER and event.pressed
	var is_mouse_clicked = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	
	if is_enter_pressed or is_mouse_clicked:
		current_question_index += 1
		
		if current_question_index < quiz_data.size():
			load_question()
		else:
			finish_quiz()

func finish_quiz():
	hide()
	get_tree().paused = false
