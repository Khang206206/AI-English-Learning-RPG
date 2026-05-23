extends CanvasLayer

@onready var question_text = $QuestionText
@onready var prompt_text = $PromptText
@onready var answers_container = $AnswersContainer
@onready var btn_a = $AnswersContainer/Btn_A
@onready var btn_b = $AnswersContainer/Btn_B
@onready var btn_c = $AnswersContainer/Btn_C
@onready var btn_d = $AnswersContainer/Btn_D

# Khai báo trạm kết nối mạng (Sử dụng cổng mặc định của Ollama)
var http_request: HTTPRequest
const SERVER_URL = "http://127.0.0.1:11434/api/chat"

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
	
	# Đóng gói dữ liệu bài thi
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

# --- PHẦN GỌI OLLAMA AI ĐÃ ĐƯỢC LÀM MỚI ---
func finish_quiz():
	is_waiting_for_ai = true
	answers_container.hide()
	prompt_text.hide()
	
	# Hiển thị thông báo chờ AI suy nghĩ
	question_text.text = "Elaria đang lật giở những trang sách ma thuật để đánh giá trình độ của bạn...\n(Quá trình này mất vài giây)"
	
	# 1. Tính toán điểm và lỗi sai
	var mistakes_str = ""
	var correct_count = 0
	var total_questions = user_results.size()
	
	for r in user_results:
		if r.is_correct:
			correct_count += 1
		else:
			mistakes_str += "Câu " + str(r.question_id) + " (Đúng: " + r.correct_answer + ", Chọn: " + r.player_answer + ")\n"
			
	if mistakes_str == "":
		mistakes_str = "Tuyệt vời, bạn không có lỗi sai nào!"

	# 2. Xây dựng Kịch bản (Prompt) cho Ollama
	var system_prompt = """Bạn là Elaria, một quyển sách phép thuật thông thái trong thế giới Aelphurion.
Nhiệm vụ: Đánh giá trình độ tiếng Anh của người chơi theo chuẩn CEFR (A1, A2, B1, B2, C1, C2).

QUY TẮC SỐNG CÒN CỦA ELARIA:
1. GIAO TIẾP TRỰC TIẾP: Tuyệt đối xưng "tôi" và gọi người chơi là "bạn".
2. CẤU TRÚC BẮT BUỘC:
   - Ý 1: Thông báo Level.
   - Ý 2: BẮT BUỘC liệt kê các từ tiếng Anh mà họ làm sai.
   - Ý 3: Đưa ra lời khuyên động viên.
3. Trả về đúng định dạng JSON:
{
    "level": "A1/A2/B1/B2/C1/C2",
    "elaria_comment": "..."
}"""

	var user_prompt = "Điểm số: " + str(correct_count) + "/" + str(total_questions) + "\nCác lỗi sai:\n" + mistakes_str

	# 3. Đóng gói Payload theo cấu trúc API của Ollama
	var payload = {
		"model": "qwen2.5:3b", # Lưu ý: Đổi thành "qwen2.5:3b" nếu máy team bạn chạy bản 3B
		"messages": [
			{ "role": "system", "content": system_prompt },
			{ "role": "user", "content": user_prompt }
		],
		"format": "json",
		"stream": false,
		"options": {
			"temperature": 0.35,
			"num_predict": 300
		}
	}
	
	var json_data = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	
	# Bắn request trực tiếp lên Ollama
	http_request.request(SERVER_URL, headers, HTTPClient.METHOD_POST, json_data)

# --- XỬ LÝ KẾT QUẢ TỪ OLLAMA TRẢ VỀ ---
func _on_http_request_completed(_result, response_code, _headers, body):
	is_waiting_for_ai = false
	
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response_data = json.data
			
			# Lọc lấy nội dung trả về từ Ollama (Lớp ngoài)
			if response_data.has("message") and response_data["message"].has("content"):
				var ai_output_str = response_data["message"]["content"]
				
				# Parse JSON một lần nữa để lấy dữ liệu (Lớp trong)
				var elaria_json = JSON.new()
				if elaria_json.parse(ai_output_str) == OK:
					var elaria_data = elaria_json.data
					var ai_level = elaria_data.get("level", "Unknown")
					var ai_comment = elaria_data.get("elaria_comment", "Elaria gật gù ghi chép lại kết quả.")
					
					# Lưu vào GameManager (Nếu có)
					if GameManager and GameManager.has_method("save_player_assessment"):
						GameManager.save_player_assessment(ai_level, ai_comment)

					# In kết quả ra màn hình UI
					question_text.text = "XẾP LOẠI CỦA BẠN: " + ai_level + "\n\n" + ai_comment
					prompt_text.text = "Nhấn ENTER hoặc click chuột để tiếp tục"
					prompt_text.show()
					quiz_finished = true
					return # Thành công, thoát hàm
					
	# Nếu code chạy xuống tới đây, nghĩa là có lỗi kết nối hoặc AI sinh JSON bị hỏng
	question_text.text = "Lỗi kết nối Server AI!\nHãy chắc chắn rằng Ollama đang chạy ngầm trên máy bạn."
	prompt_text.text = "Nhấn ENTER để thoát"
	prompt_text.show()
	quiz_finished = true
