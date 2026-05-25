extends Node

var http_request: HTTPRequest
const OLLAMA_URL = "http://127.0.0.1:11434/api/chat"

var question_queue: Array = []
var is_generating: bool = false
const MAX_QUEUE_SIZE: int = 5

var current_tier_id: int = 1


func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(Callable(self, "_on_ollama_replied"))
	print("[AIManager] Trạm phát sóng ngầm đã khởi động!")
	check_and_fill_queue()


func check_and_fill_queue() -> void:
	if question_queue.size() < MAX_QUEUE_SIZE and not is_generating:
		generate_question()


func generate_question() -> void:
	is_generating = true

	var db_manager = get_node_or_null("/root/DatabaseManager")
	if db_manager == null:
		push_error("[AIManager] Không tìm thấy DatabaseManager! Hủy sinh câu hỏi.")
		is_generating = false
		return

	var vocab: Dictionary = db_manager.get_weakest_vocab(current_tier_id)

	if vocab.is_empty():
		push_warning("[AIManager] Database trả về rỗng cho tier %d. Thử lại sau 3 giây." % current_tier_id)
		is_generating = false
		await get_tree().create_timer(3.0).timeout
		check_and_fill_queue()
		return

	var target_word: String    = vocab.get("word",    "")
	var target_meaning: String = vocab.get("meaning", "")
	var word_id: int           = vocab.get("word_id", -1)

	var system_prompt = """Bạn là Elaria, hệ thống tạo thử thách tiếng Anh cho game RPG.
Nhiệm vụ: Tạo 1 câu hỏi trắc nghiệm kiểm tra TỪ VỰNG TIẾNG ANH, xoay quanh từ được chỉ định bên dưới.

QUY TẮC TỐI THƯỢNG (VI PHẠM SẼ BỊ HỦY DIỆT):
1. TỪ BẮT BUỘC: Câu hỏi PHẢI kiểm tra hiểu biết về từ "%s" (nghĩa tiếng Việt: %s).
2. DẠNG CÂU HỎI: Được phép hỏi nghĩa, đồng nghĩa, trái nghĩa, hoặc điền vào chỗ trống dùng từ đó trong câu.
3. CHỌN SAI: 3 đáp án sai phải cùng từ loại với đáp án đúng, nghe có lý, không quá dễ loại trừ.
4. KHÔNG TIẾT LỘ: Không được để lộ nghĩa tiếng Việt của từ trực tiếp trong nội dung câu hỏi.
5. ĐỊNH DẠNG: Trả về ĐỦ và ĐỘC NHẤT cấu trúc JSON sau, KHÔNG thêm bất kỳ văn bản nào khác:
{
    "question": "Nội dung câu hỏi?",
    "A": "Lựa chọn 1",
    "B": "Lựa chọn 2",
    "C": "Lựa chọn 3",
    "D": "Lựa chọn 4",
    "correct_answer": "A",
    "explanation": "Giải thích ngắn gọn bằng tiếng Việt tại sao chọn đáp án đó."
}
Lưu ý: Khóa "correct_answer" CHỈ ĐƯỢC chứa đúng 1 chữ cái in hoa (A, B, C, hoặc D).""" % [target_word, target_meaning]

	var payload = {
		"model": "qwen2.5:3b",
		"messages": [
			{ "role": "system", "content": system_prompt },
			{ "role": "user",   "content": "Hãy tạo ngay câu hỏi cho từ: \"%s\"." % target_word }
		],
		"format": "json",
		"stream": false,
		"options": { "temperature": 0.45 }
	}

	var json_data = JSON.stringify(payload)
	var headers   = ["Content-Type: application/json"]

	http_request.set_meta("pending_word_id", word_id)
	http_request.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, json_data)


func _on_ollama_replied(_result, response_code, _headers, body) -> void:
	is_generating = false

	var pending_word_id: int = http_request.get_meta("pending_word_id", -1)
	http_request.remove_meta("pending_word_id")

	var success = false

	if response_code == 200:
		var outer_json = JSON.new()
		if outer_json.parse(body.get_string_from_utf8()) == OK:
			var response_data = outer_json.data
			if response_data.has("message") and response_data["message"].has("content"):
				var ai_output_str = response_data["message"]["content"]

				var inner_json = JSON.new()
				if inner_json.parse(ai_output_str) == OK:
					var q_data: Dictionary = inner_json.data
					if q_data.has("correct_answer") and pending_word_id != -1:
						q_data["word_id"] = pending_word_id
						question_queue.append(q_data)
						print("[AIManager] +1 câu (word_id=%d). Kho: %d/%d" \
							% [pending_word_id, question_queue.size(), MAX_QUEUE_SIZE])
						success = true

	if not success:
		print("[AIManager] Lỗi sinh câu hỏi. Thử lại sau 2 giây...")
		await get_tree().create_timer(2.0).timeout

	check_and_fill_queue()


func get_question() -> Dictionary:
	if question_queue.size() > 0:
		var q = question_queue.pop_front()
		check_and_fill_queue()
		return q

	print("[AIManager] Cảnh báo: Hết câu hỏi! Dùng câu dự phòng.")
	check_and_fill_queue()
	return {
		"question": "Hệ thống AI đang quá tải! Từ nào sau đây có nghĩa là 'Phép thuật'?",
		"A": "Science",
		"B": "Magic",
		"C": "Physics",
		"D": "Math",
		"correct_answer": "B",
		"explanation": "Câu dự phòng. 'Magic' có nghĩa là phép thuật.",
		"word_id": -1
	}


func set_tier(tier_id: int) -> void:
	current_tier_id = tier_id
	print("[AIManager] Đổi tier sang: %d" % tier_id)
