extends CanvasLayer

@onready var question_text = $QuestionText
@onready var prompt_text = $PromptText
@onready var answers_container = $AnswersContainer
@onready var btn_a = $AnswersContainer/Btn_A
@onready var btn_b = $AnswersContainer/Btn_B
@onready var btn_c = $AnswersContainer/Btn_C
@onready var btn_d = $AnswersContainer/Btn_D

# Khai báo trạm kết nối mạng
var http_request: HTTPRequest
const SERVER_URL = "http://127.0.0.1:8000/evaluate_level"

var buttons = []
var current_question_index = 0
var has_answered = false
var user_results = []

# Biến cờ hiệu để AI xử lý
var is_waiting_for_ai = false
var quiz_finished = false

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
	
	# Sinh ra trạm kết nối mạng bằng code để tránh lỗi Null
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	
	buttons = [btn_a, btn_b, btn_c, btn_d]
	
	for i in range(buttons.size()):
		buttons[i].focus_mode = Control.FOCUS_NONE
		buttons[i].pressed.connect(func(): _on_answer_selected(i))

func start_quiz():
	show()
	answers_container.show() # Đảm bảo nút đáp án hiện lên khi chơi lại
	current_question_index = 0
	user_results.clear()
	is_waiting_for_ai = false
	quiz_finished = false
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
	
	# Đóng gói dữ liệu bài thi (chuẩn định dạng AI cần)
	var result_data = {
		"question_id": current_question_index + 1,
		"correct_answer": quiz_data[current_question_index]["options"][correct_index],
		"player_answer": quiz_data[current_question_index]["options"][selected_index],
		"is_correct": selected_index == correct_index
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
	# Khóa phím khi đang chờ AI trả lời
	if not visible or not has_answered or is_waiting_for_ai:
		return
		
	var is_enter_pressed = event is InputEventKey and event.keycode == KEY_ENTER and event.pressed
	var is_mouse_clicked = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	
	if is_enter_pressed or is_mouse_clicked:
		# Nếu đã nhận được kết quả AI thì tắt Quiz
		if quiz_finished:
			hide()
			get_tree().paused = false
		else:
			current_question_index += 1
			
			if current_question_index < quiz_data.size():
				load_question()
			else:
				finish_quiz()

# --- PHẦN GỌI AI ĐƯỢC THÊM VÀO ĐÂY ---
func finish_quiz():
	is_waiting_for_ai = true
	answers_container.hide()
	prompt_text.hide()
	
	# Hiển thị thông báo chờ AI suy nghĩ
	question_text.text = "Elaria đang lật giở những trang sách ma thuật để đánh giá trình độ của bạn...\n(Quá trình này mất vài giây)"
	
	var payload = {
		"player_id": "The_Wandering_Seeker",
		"results": user_results
	}
	var json_data = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	
	http_request.request(SERVER_URL, headers, HTTPClient.METHOD_POST, json_data)

func _on_http_request_completed(_result, response_code, _headers, body):
	is_waiting_for_ai = false
	
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response_data = json.data
			var ai_level = response_data.get("level", "Unknown")
			var ai_comment = response_data.get("elaria_comment", "Elaria gật gù ghi chép lại kết quả.")

			# Lưu vào GameManager
			if GameManager and GameManager.has_method("save_player_assessment"):
				GameManager.save_player_assessment(ai_level, ai_comment)

			# In kết quả ra màn hình
			question_text.text = "XẾP LOẠI CỦA BẠN: " + ai_level + "\n\n" + ai_comment
			prompt_text.text = "Nhấn ENTER hoặc click chuột để tiếp tục"
			prompt_text.show()
			quiz_finished = true
	else:
		question_text.text = "Lỗi kết nối Server AI! Không thể liên lạc với Elaria."
		prompt_text.text = "Nhấn ENTER để thoát"
		prompt_text.show()
		quiz_finished = true
