extends Node

var http_request: HTTPRequest
const OLLAMA_URL = "http://127.0.0.1:11434/api/chat"

# Queue riêng cho từng tier — key là tier_id (int), value là Array câu hỏi
# Nạp song song ngay từ đầu game → đổi tier không bao giờ phải chờ
var question_queues: Dictionary = {}
var is_generating: bool = false
const MAX_QUEUE_SIZE: int = 5

# Danh sách tier cần nạp — thêm tier mới vào đây khi mở rộng game
const MANAGED_TIERS: Array = [1, 2]

var current_tier_id: int = 1

# Ngưỡng avg_mastery để điều chỉnh độ khó MCQ
# < THRESHOLD_HARD  → MCQ cơ bản: nhận diện nghĩa trực tiếp
# >= THRESHOLD_HARD → MCQ nâng cao: đồng/trái nghĩa, điền vào chỗ trống
const THRESHOLD_HARD: float = 0.4

# Tier đang được nạp ngầm hiện tại (tránh gọi generate song song)
var _generating_tier_id: int = -1


func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(Callable(self, "_on_ollama_replied"))

	# Khởi tạo queue rỗng cho tất cả tier
	for tier in MANAGED_TIERS:
		question_queues[tier] = []

	print("[AIManager] Trạm phát sóng ngầm đã khởi động! Nạp queue cho %d tier..." % MANAGED_TIERS.size())
	check_and_fill_all_queues()


# Quét tất cả tier, nạp tier nào đang thiếu câu hỏi
# Ưu tiên nạp tier hiện tại trước, các tier còn lại nạp ngầm sau
func check_and_fill_all_queues() -> void:
	if is_generating:
		return

	# Ưu tiên 1: tier hiện tại người chơi đang dùng
	if question_queues[current_tier_id].size() < MAX_QUEUE_SIZE:
		generate_question_for_tier(current_tier_id)
		return

	# Ưu tiên 2: các tier còn lại nạp ngầm theo thứ tự
	for tier in MANAGED_TIERS:
		if tier != current_tier_id and question_queues[tier].size() < MAX_QUEUE_SIZE:
			generate_question_for_tier(tier)
			return


func generate_question_for_tier(tier_id: int) -> void:
	is_generating = true
	_generating_tier_id = tier_id

	var db_manager = get_node_or_null("/root/DatabaseManager")
	if db_manager == null:
		push_error("[AIManager] Không tìm thấy DatabaseManager! Hủy sinh câu hỏi.")
		is_generating = false
		_generating_tier_id = -1
		return

	var vocab: Dictionary = db_manager.get_weakest_vocab(tier_id)

	if vocab.is_empty():
		push_warning("[AIManager] Database trả về rỗng cho tier %d. Thử lại sau 3 giây." % tier_id)
		is_generating = false
		_generating_tier_id = -1
		await get_tree().create_timer(3.0).timeout
		check_and_fill_all_queues()
		return

	var target_word: String    = vocab.get("word",            "")
	var target_meaning: String = vocab.get("meaning",         "")
	var word_id: int           = vocab.get("word_id",         -1)
	var mastery_score: float   = vocab.get("mastery_score",   0.0)
	var encounter_count: int   = vocab.get("encounter_count", 0)

	var avg_mastery: float             = db_manager.get_tier_avg_mastery(tier_id)
	var difficulty_instruction: String = _resolve_difficulty_instruction(mastery_score, encounter_count, avg_mastery)

	print("[AIManager] Nạp tier %d | word='%s' | avg_mastery=%.2f | word_mastery=%.2f" \
		% [tier_id, target_word, avg_mastery, mastery_score])

	var system_prompt = _build_mcq_prompt(target_word, target_meaning, difficulty_instruction)
	var user_message  = "Hãy tạo ngay câu hỏi MCQ cho từ: \"%s\"." % target_word

	var payload = {
		"model": "qwen2.5:3b",
		"messages": [
			{ "role": "system", "content": system_prompt },
			{ "role": "user",   "content": user_message }
		],
		"format": "json",
		"stream": false,
		"options": { "temperature": 0.45 }
	}

	var json_data = JSON.stringify(payload)
	var headers   = ["Content-Type: application/json"]

	http_request.set_meta("pending_word_id", word_id)
	http_request.set_meta("pending_tier_id", tier_id)
	http_request.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, json_data)


# ==============================================================================
# DDA LOGIC
# ==============================================================================

func _resolve_difficulty_instruction(mastery_score: float, encounter_count: int, avg_mastery: float) -> String:
	var tier_is_advanced: bool = avg_mastery >= THRESHOLD_HARD

	if encounter_count == 0:
		return "Đây là LẦN ĐẦU người chơi gặp từ này. Hãy tạo câu hỏi NHẬN DIỆN NGHĨA trực tiếp (hỏi từ này có nghĩa là gì?). Đáp án sai phải rõ ràng sai hơn để người chơi có cơ hội thành công lần đầu."

	elif mastery_score < 0.3:
		if tier_is_advanced:
			return "Người chơi gặp từ này %d lần nhưng vẫn hay sai dù trình độ tier đã khá. Hãy tạo câu hỏi ĐIỀN VÀO CHỖ TRỐNG với câu đơn giản, giúp họ ghi nhớ từ qua ngữ cảnh." % encounter_count
		return "Người chơi gặp từ này %d lần nhưng vẫn hay sai. Hãy tạo câu hỏi CỦNG CỐ: hỏi nghĩa hoặc nhận diện từ trong câu đơn giản. Đừng tăng độ khó." % encounter_count

	elif mastery_score < 0.6:
		if tier_is_advanced:
			return "Người chơi đang tiến bộ với từ này (%d lần gặp) và trình độ tier đã khá. Hãy tạo câu hỏi ĐỒNG/TRÁI NGHĨA hoặc ĐIỀN VÀO CHỖ TRỐNG trong câu có ngữ cảnh phong phú." % encounter_count
		return "Người chơi đã gặp từ này %d lần và đang tiến bộ. Hãy tạo câu hỏi MỨC TRUNG BÌNH: hỏi đồng nghĩa, trái nghĩa hoặc điền vào chỗ trống trong câu có ngữ cảnh." % encounter_count

	else:
		return "Người chơi đã thành thạo từ này (mastery cao, gặp %d lần). Hãy tạo câu hỏi NÂNG CAO: dùng ngữ cảnh phức tạp, hỏi sắc thái nghĩa (nuance), hoặc phân biệt từ đồng nghĩa gần nhau. Đáp án sai phải tinh tế, khó loại trừ." % encounter_count


# ==============================================================================
# PROMPT BUILDER
# ==============================================================================

func _build_mcq_prompt(word: String, meaning: String, difficulty_instruction: String) -> String:
	return """Bạn là Elaria, hệ thống tạo thử thách tiếng Anh cho game RPG.
Nhiệm vụ: Tạo 1 câu hỏi trắc nghiệm (MCQ) kiểm tra từ vựng tiếng Anh.

TỪ BẮT BUỘC: "%s" (nghĩa tiếng Việt: %s)

CHỈ THỊ ĐỘ KHÓ (BẮT BUỘC TUÂN THEO):
%s

QUY TẮC CHUNG:
1. Câu hỏi PHẢI xoay quanh từ được chỉ định, không hỏi về chủ đề khác.
2. 3 đáp án sai phải cùng từ loại với đáp án đúng, nghe có lý, không quá dễ loại trừ.
3. KHÔNG để lộ nghĩa tiếng Việt trong nội dung câu hỏi.
4. Trả về ĐỦ cấu trúc JSON sau, KHÔNG thêm bất kỳ văn bản nào khác:
{
    "question": "Nội dung câu hỏi?",
    "A": "Lựa chọn 1",
    "B": "Lựa chọn 2",
    "C": "Lựa chọn 3",
    "D": "Lựa chọn 4",
    "correct_answer": "A",
    "explanation": "Giải thích ngắn gọn bằng tiếng Việt tại sao chọn đáp án đó."
}
Lưu ý: "correct_answer" CHỈ ĐƯỢC chứa đúng 1 chữ cái in hoa (A, B, C, hoặc D).""" \
	% [word, meaning, difficulty_instruction]


# ==============================================================================
# XỬ LÝ PHẢN HỒI TỪ OLLAMA
# ==============================================================================

func _on_ollama_replied(_result, response_code, _headers, body) -> void:
	is_generating = false

	var pending_word_id: int = http_request.get_meta("pending_word_id", -1)
	var pending_tier_id: int = http_request.get_meta("pending_tier_id", current_tier_id)
	http_request.remove_meta("pending_word_id")
	http_request.remove_meta("pending_tier_id")
	_generating_tier_id = -1

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
					if q_data.has("correct_answer") and q_data.has("question") and pending_word_id != -1:
						q_data["word_id"] = pending_word_id
						question_queues[pending_tier_id].append(q_data)
						print("[AIManager] +1 câu tier %d (word_id=%d). Kho tier %d: %d/%d" \
							% [pending_tier_id, pending_word_id, pending_tier_id,
							   question_queues[pending_tier_id].size(), MAX_QUEUE_SIZE])
						success = true

	if not success:
		print("[AIManager] Lỗi sinh câu hỏi tier %d. Thử lại sau 2 giây..." % pending_tier_id)
		await get_tree().create_timer(2.0).timeout

	check_and_fill_all_queues()


# ==============================================================================
# API CÔNG KHAI
# ==============================================================================

func get_question() -> Dictionary:
	var queue: Array = question_queues[current_tier_id]

	if queue.size() > 0:
		var q = queue.pop_front()
		check_and_fill_all_queues()
		return q

	print("[AIManager] Cảnh báo: Hết câu hỏi tier %d! Dùng câu dự phòng." % current_tier_id)
	check_and_fill_all_queues()
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


# Chỉ đổi con trỏ tier — KHÔNG xóa queue, KHÔNG gây delay
func set_tier(tier_id: int) -> void:
	if not question_queues.has(tier_id):
		push_warning("[AIManager] Tier %d không tồn tại trong MANAGED_TIERS." % tier_id)
		return
	current_tier_id = tier_id
	print("[AIManager] Chuyển sang tier %d | Queue sẵn sàng: %d câu" \
		% [tier_id, question_queues[tier_id].size()])
	check_and_fill_all_queues()
