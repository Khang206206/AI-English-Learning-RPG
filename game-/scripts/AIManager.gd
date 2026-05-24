extends Node

var http_request: HTTPRequest
const OLLAMA_URL = "http://127.0.0.1:11434/api/chat"

# KHO CÂU HỎI VÀ TRẠNG THÁI
var question_queue: Array = []
var is_generating: bool = false
const MAX_QUEUE_SIZE: int = 5 # Luôn duy trì 5 câu hỏi sẵn sàng

var current_player_level: String = "A1"

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(Callable(self, "_on_ollama_replied"))
	
	print("[AIManager] Trạm phát sóng ngầm đã khởi động!")
	# Vừa mở game là bắt đầu nạp câu hỏi liền
	check_and_fill_queue()

# Kiểm tra xem kho câu hỏi có thiếu không, nếu thiếu thì gọi AI nặn thêm
func check_and_fill_queue():
	if question_queue.size() < MAX_QUEUE_SIZE and not is_generating:
		generate_question()

func generate_question():
	is_generating = true
	
	# Lấy level (Thích nghi độ khó)
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and "player_level" in game_manager:
		current_player_level = game_manager.player_level

	# --- MẢNG CHỐNG LẶP (ANTI-REPETITION) ---
	var sub_topics = [
		"động từ (Verb)", 
		"tính từ (Adjective)", 
		"danh từ (Noun)", 
		"trạng từ (Adverb)", 
		"từ đồng nghĩa (Synonym)", 
		"từ trái nghĩa (Antonym)", 
		"cụm động từ (Phrasal verbs)",
		"thành ngữ (Idiom)"
	]
	var random_topic = sub_topics.pick_random() # Bốc ngẫu nhiên 1 chủ đề

	# --- PROMPT GIỮ NGUYÊN ---
	var system_prompt = """Bạn là Elaria, một hệ thống tạo thử thách tiếng Anh cho game RPG.
Nhiệm vụ: Tạo 1 câu hỏi trắc nghiệm KIỂM TRA TỪ VỰNG HOẶC NGỮ PHÁP TIẾNG ANH ở mức độ %s.

QUY TẮC TỐI THƯỢNG (VI PHẠM SẼ BỊ HỦY DIỆT):
1. CHỦ ĐỀ BẮT BUỘC: CHỈ ĐƯỢC PHÉP hỏi về từ vựng (ý nghĩa, đồng nghĩa, trái nghĩa) HOẶC cấu trúc ngữ pháp tiếng Anh.
2. GIỚI HẠN LĨNH VỰC: Nội dung câu hỏi TUYỆT ĐỐI KHÔNG ĐƯỢC vượt ra khỏi mục đích học tiếng Anh. CẤM hoàn toàn việc hỏi về toán học, lịch sử, địa lý, khoa học hay kiến thức đời sống.
3. BẮT BUỘC trả về ĐÚNG cấu trúc JSON sau, KHÔNG thêm bất kỳ văn bản nào khác:
{
    "question": "Nội dung câu hỏi?",
    "A": "Lựa chọn 1",
    "B": "Lựa chọn 2",
    "C": "Lựa chọn 3",
    "D": "Lựa chọn 4",
    "correct_answer": "A", 
    "explanation": "Giải thích ngắn gọn bằng tiếng Việt tại sao lại chọn đáp án đó."
}
Lưu ý: Khóa 'correct_answer' CHỈ ĐƯỢC chứa đúng 1 chữ cái in hoa (A, B, C, hoặc D).""" % current_player_level

	# --- ĐÓNG GÓI PAYLOAD ---
	var payload = {
		"model": "qwen2.5:3b", # Nhớ khớp tên model máy bạn
		"messages": [
			{ "role": "system", "content": system_prompt },
			# NHÉT CHỦ ĐỀ NGẪU NHIÊN VÀO LỜI YÊU CẦU CỦA USER
			{ "role": "user", "content": "Hãy tạo ngay một câu hỏi tiếng Anh mới, tập trung vào: " + random_topic }
		],
		"format": "json",
		"stream": false,
		"options": {
			"temperature": 0.45  
		}
	}
	
	var json_data = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	http_request.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, json_data)
	
func _on_ollama_replied(_result, response_code, _headers, body):
	is_generating = false
	var success = false
	
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response_data = json.data
			if response_data.has("message") and response_data["message"].has("content"):
				var ai_output_str = response_data["message"]["content"]
				
				var question_json = JSON.new()
				if question_json.parse(ai_output_str) == OK:
					var q_data = question_json.data
					if q_data.has("correct_answer"):
						question_queue.append(q_data)
						print("[AIManager] +1 Câu hỏi. Số câu hỏi trong kho: ", question_queue.size())
						success = true

	if not success:
		print("[AIManager] Lỗi sinh câu hỏi. Thử lại sau 2 giây...")
		await get_tree().create_timer(2.0).timeout
		
	# Đệ quy: Tiếp tục nạp cho đến khi đầy MAX_QUEUE_SIZE
	check_and_fill_queue()

# Hàm để BattleScene gọi lấy câu hỏi (Instant - 0 giây)
func get_question() -> Dictionary:
	if question_queue.size() > 0:
		var q = question_queue.pop_front()
		# Vừa rút 1 câu hỏi ra, hệ thống tự động câu hỏi mới bù vào ngầm
		check_and_fill_queue() 
		return q
	else:
		# FALLBACK: Nếu người chơi đánh quá nhanh mà AI chưa rặn kịp
		print("[AIManager] Cảnh báo: Hết câu hỏi! Đang dùng câu hỏi dự phòng.")
		check_and_fill_queue()
		return {
			"question": "Hệ thống AI đang quá tải! Từ nào sau đây có nghĩa là 'Phép thuật'?",
			"A": "Science",
			"B": "Magic",
			"C": "Physics",
			"D": "Math",
			"correct_answer": "B",
			"explanation": "Câu hỏi chữa cháy. 'Magic' có nghĩa là phép thuật."
		}
