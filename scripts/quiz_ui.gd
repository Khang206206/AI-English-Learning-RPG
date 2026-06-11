extends CanvasLayer

signal quiz_completed
signal quiz_result_closed
@export var chapel_music: AudioStream
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
var advance_ready = false
var question_token = 0

# Biến cờ hiệu để AI xử lý
var is_waiting_for_ai = false
var quiz_finished = false
var completion_recorded = false

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
	if chapel_music != null:
		BgmManager.play_music(chapel_music, -10)
	else:
		# Nếu bạn quên chưa kéo nhạc vào thì tự động tắt nhạc cũ cho an toàn
		BgmManager.stop_music()
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	# Sinh ra trạm kết nối mạng bằng code để tránh lỗi Null
	http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	http_request.timeout = 20.0
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	
	buttons = [btn_a, btn_b, btn_c, btn_d]
	
	for i in range(buttons.size()):
		buttons[i].focus_mode = Control.FOCUS_NONE
		buttons[i].pressed.connect(func(): _on_answer_selected(i))

func start_quiz():
	if DatabaseManager != null and DatabaseManager.has_completed_intro_quiz():
		return
	show()
	answers_container.show() # Đảm bảo nút đáp án hiện lên khi chơi lại
	current_question_index = 0
	user_results.clear()
	is_waiting_for_ai = false
	quiz_finished = false
	completion_recorded = false
	load_question()
	get_tree().paused = true 

func load_question():
	has_answered = false
	advance_ready = false
	question_token += 1
	prompt_text.hide()
	
	var q_data = quiz_data[current_question_index]
	question_text.text = q_data["question"]
	
	for i in range(buttons.size()):
		buttons[i].text = q_data["options"][i]
		buttons[i].modulate = Color.WHITE
		buttons[i].disabled = true
	_enable_answer_buttons_next_frame(question_token)

func _enable_answer_buttons_next_frame(token: int) -> void:
	await get_tree().process_frame
	if token != question_token or not visible or has_answered or is_waiting_for_ai:
		return
	for button in buttons:
		button.disabled = false

func _on_answer_selected(selected_index):
	if has_answered: return
	
	has_answered = true
	advance_ready = false
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
	_allow_advance_next_frame()

func _allow_advance_next_frame() -> void:
	await get_tree().process_frame
	if visible and has_answered and not is_waiting_for_ai:
		advance_ready = true

func _input(event):
	# Khóa phím khi đang chờ AI trả lời
	if not visible or not has_answered or is_waiting_for_ai:
		return
		
	var is_enter_pressed = event is InputEventKey and event.keycode == KEY_ENTER and event.pressed
	var is_mouse_clicked = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	
	if is_enter_pressed or is_mouse_clicked:
		get_viewport().set_input_as_handled()
		if not advance_ready:
			return
		# Nếu đã nhận được kết quả AI thì tắt Quiz
		if quiz_finished:
			hide()
			get_tree().paused = false
			emit_signal("quiz_result_closed")
		else:
			current_question_index += 1
			
			if current_question_index < quiz_data.size():
				load_question()
			else:
				finish_quiz()

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
			mistakes_str += "- Sai câu " + str(r.question_id) + ": Đáp án đúng là '" + r.correct_answer + "', nhưng bạn lại chọn '" + r.player_answer + "'\n"
			
	if mistakes_str == "":
		mistakes_str = "Tuyệt vời, bạn không có lỗi sai nào!"

	# 2. Xây dựng Kịch bản (Prompt) - Cập nhật Khóa Logic
	var system_prompt = """Bạn là Elaria, một quyển sách phép thuật thông thái.
Nhiệm vụ: Đánh giá trình độ tiếng Anh của người chơi theo chuẩn CEFR.

QUY TẮC SỐNG CÒN (NẾU VI PHẠM SẼ BỊ HỦY DIỆT):
1. GIAO TIẾP: Tuyệt đối xưng "tôi" và gọi người chơi là "bạn".
2. CHI TIẾT & ĐỘ DÀI: Nhận xét phải sâu sắc, dài ít nhất 3 đến 4 câu.
3. PHÂN TÍCH LỖI: BẮT BUỘC phải chỉ đích danh các từ tiếng Anh mà người chơi làm sai và giải thích ngắn gọn ý nghĩa của chúng.
4. KHÓA LOGIC THĂNG CẤP: TUYỆT ĐỐI KHÔNG khuyên nâng cấp lên chính level họ đang có. Nếu đánh giá họ ở A2, hãy khuyên họ cố gắng đạt B1. Nếu họ ở B1, khuyên hướng tới B2.
5. Trả về đúng định dạng JSON:
{
	"level": "A1/A2/B1/B2/C1/C2",
	"elaria_comment": "..."
}"""

	var user_prompt = "Điểm số: " + str(correct_count) + "/" + str(total_questions) + "\nCác lỗi sai cụ thể:\n" + mistakes_str + "\nHãy phân tích những lỗi sai này và viết nhận xét chi tiết."

	# 3. Đóng gói Payload theo cấu trúc API của Ollama
	var payload = {
		"model": AIManager.OLLAMA_MODEL if AIManager != null else "qwen3.5:4b",
		"messages": [
			{ "role": "system", "content": system_prompt },
			{ "role": "user", "content": user_prompt }
		],
		"think": false,
		"format": "json",
		"stream": false,
		"options": {
			"temperature": 0.4, # Tăng nhẹ nhiệt độ lên 0.4 để AI viết văn dài và mượt hơn
			"num_predict": 400  # Tăng giới hạn chữ để nó không bị cắt cụt đuôi
		}
	}
	
	var json_data = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	var server_url = AIManager.OLLAMA_URL if AIManager != null else SERVER_URL
	
	# Bắn request trực tiếp lên Ollama
	var err = http_request.request(server_url, headers, HTTPClient.METHOD_POST, json_data)
	if err != OK:
		_show_local_assessment(correct_count, total_questions, "Không thể gửi request tới Ollama (err=%d)." % err)

# --- XỬ LÝ KẾT QUẢ TỪ OLLAMA TRẢ VỀ ---
func _on_http_request_completed(result, response_code, _headers, body):
	is_waiting_for_ai = false
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response_data = json.data
			
			# Lọc lấy nội dung trả về từ Ollama (Lớp ngoài)
			if response_data.has("message") and response_data["message"].has("content"):
				var ai_output_str = response_data["message"]["content"]
				var extracted_json = _extract_json_object(ai_output_str)
				
				# Parse JSON một lần nữa để lấy dữ liệu (Lớp trong)
				var elaria_json = JSON.new()
				if extracted_json != "" and elaria_json.parse(extracted_json) == OK:
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
					_complete_intro_quiz_once()
					quiz_finished = true
					advance_ready = false
					_allow_advance_next_frame()
					return # Thành công, thoát hàm
					
	# Nếu code chạy xuống tới đây, nghĩa là có lỗi kết nối hoặc AI sinh JSON bị hỏng
	_show_local_assessment(_get_correct_count(), user_results.size(), "AI chưa trả về phản hồi hợp lệ.")

func _extract_json_object(text: String) -> String:
	var s = text.strip_edges()
	while "<think>" in s:
		var start = s.find("<think>")
		var end = s.find("</think>")
		if end == -1:
			s = s.substr(0, start).strip_edges()
			break
		s = (s.substr(0, start) + s.substr(end + 8)).strip_edges()
	if s.begins_with("```"):
		var fence_end = s.find("```", 3)
		if fence_end != -1:
			s = s.substr(3, fence_end - 3).strip_edges()
		if s.begins_with("json"):
			s = s.substr(4).strip_edges()
	var obj_start = s.find("{")
	var obj_end = s.rfind("}")
	if obj_start == -1 or obj_end == -1 or obj_end <= obj_start:
		return ""
	return s.substr(obj_start, obj_end - obj_start + 1)

func _get_correct_count() -> int:
	var correct_count = 0
	for result_data in user_results:
		if result_data.get("is_correct", false):
			correct_count += 1
	return correct_count

func _show_local_assessment(correct_count: int, total_questions: int, reason: String) -> void:
	is_waiting_for_ai = false
	var ratio = float(correct_count) / max(1.0, float(total_questions))
	var level = "A1"
	if ratio >= 0.9:
		level = "B2"
	elif ratio >= 0.75:
		level = "B1"
	elif ratio >= 0.55:
		level = "A2"
	var comment = "Tôi chưa kết nối được AI để viết nhận xét chi tiết, nên đây là đánh giá tạm thời theo điểm số. Bạn trả lời đúng %d/%d câu, tương ứng mức %s trong bài kiểm tra đầu vào. Hãy tiếp tục luyện các từ đã sai để hệ thống có thêm dữ liệu đánh giá chính xác hơn." % [correct_count, total_questions, level]
	question_text.text = "XẾP LOẠI CỦA BẠN: " + level + "\n\n" + comment + "\n\n(" + reason + ")"
	prompt_text.text = "Nhấn ENTER hoặc click chuột để tiếp tục"
	prompt_text.show()
	_complete_intro_quiz_once()
	quiz_finished = true
	advance_ready = false
	_allow_advance_next_frame()

func _complete_intro_quiz_once() -> void:
	if completion_recorded:
		return
	completion_recorded = true
	if DatabaseManager != null:
		DatabaseManager.mark_intro_quiz_completed()
	emit_signal("quiz_completed")
