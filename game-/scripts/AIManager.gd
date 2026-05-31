extends Node

const OLLAMA_URL: String   = "http://127.0.0.1:11434/api/chat"
const OLLAMA_MODEL: String = "qwen3.5:4b"

# Queue riêng cho từng tier — key là tier_id (int), value là Array câu hỏi
var question_queues: Dictionary = {}

# [FIX 1] Dùng per-tier generating flag thay vì 1 flag global duy nhất.
# Flag global khiến toàn bộ hệ thống bị kẹt nếu 1 request đang chạy.
var _tier_generating: Dictionary = {}   # tier_id → bool

const MAX_QUEUE_SIZE: int = 5
const MANAGED_TIERS: Array = [1, 2]

var current_tier_id: int = 1

const THRESHOLD_HARD: float = 0.4


func _ready() -> void:
	for tier in MANAGED_TIERS:
		question_queues[tier]    = []
		_tier_generating[tier]   = false

	print("[AIManager] Khởi động — nạp queue cho %d tier..." % MANAGED_TIERS.size())
	check_and_fill_all_queues()


# ==============================================================================
# QUẢN LÝ HÀNG ĐỢI
# ==============================================================================

func check_and_fill_all_queues() -> void:
	# Ưu tiên 1: tier hiện tại
	if question_queues[current_tier_id].size() < MAX_QUEUE_SIZE \
	and not _tier_generating[current_tier_id]:
		_generate_for_tier(current_tier_id)
		return

	# Ưu tiên 2: các tier ngầm còn thiếu
	for tier in MANAGED_TIERS:
		if tier != current_tier_id \
		and question_queues[tier].size() < MAX_QUEUE_SIZE \
		and not _tier_generating[tier]:
			_generate_for_tier(tier)
			return


func _generate_for_tier(tier_id: int) -> void:
	_tier_generating[tier_id] = true

	var db = get_node_or_null("/root/DatabaseManager")
	if db == null:
		push_error("[AIManager] Không tìm thấy DatabaseManager!")
		_tier_generating[tier_id] = false
		return

	var vocab: Dictionary = db.get_weakest_vocab(tier_id)
	if vocab.is_empty():
		push_warning("[AIManager] DB rỗng cho tier %d." % tier_id)
		_tier_generating[tier_id] = false
		return

	var word: String          = vocab.get("word",           "")
	var meaning: String       = vocab.get("meaning",        "")
	var word_id: int          = vocab.get("word_id",        -1)
	var mastery_score: float  = vocab.get("mastery_score",  0.0)
	var encounter_count: int  = vocab.get("encounter_count",0)
	var avg_mastery: float    = db.get_tier_avg_mastery(tier_id)

	print("[AIManager] Nạp tier %d | word='%s' (id=%d) | mastery=%.2f" \
		% [tier_id, word, word_id, mastery_score])

	var difficulty: String = _resolve_difficulty(mastery_score, encounter_count, avg_mastery)
	var system_prompt: String = _build_prompt(word, meaning, difficulty)
	var user_msg: String = "Tạo câu hỏi MCQ cho từ: \"%s\"." % word

	var payload: Dictionary = {
		"model": OLLAMA_MODEL,
		"messages": [
			{ "role": "system", "content": system_prompt },
			{ "role": "user",   "content": user_msg }
		],
		# [FIX 3] Tắt "thinking mode" của qwen3 — nếu bật, model sinh
		# <think>...</think> trước JSON khiến parser fail hoàn toàn
		"think":   false,
		"format":  "json",
		"stream":  false,
		"options": {
			"temperature": 0.45,
			"num_predict": 512
		}
	}

	# [FIX 1] Mỗi request tạo HTTPRequest riêng → không dùng chung node,
	# không có race condition, không có deadlock is_generating.
	var http := HTTPRequest.new()
	add_child(http)

	# Truyền context vào lambda để coroutine tự xử lý hoàn toàn
	http.request_completed.connect(
		func(result, code, _headers, body):
			await _handle_response(result, code, body, word_id, word, meaning, tier_id)
			http.queue_free()
	)

	var err = http.request(
		OLLAMA_URL,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if err != OK:
		push_error("[AIManager] Gửi request thất bại (err=%d). Tier %d." % [err, tier_id])
		http.queue_free()
		_tier_generating[tier_id] = false
		# Thử lại sau 3 giây mà không block
		_retry_after(tier_id, 3.0)


# ==============================================================================
# XỬ LÝ RESPONSE — chạy trong coroutine riêng của từng request
# ==============================================================================

func _handle_response(
	_result, response_code: int, body: PackedByteArray,
	word_id: int, word: String, meaning: String, tier_id: int
) -> void:
	var raw: String = body.get_string_from_utf8()
	print("[AIManager] [DEBUG] Tier %d HTTP %d | %d chars | preview: %s" \
		% [tier_id, response_code, raw.length(), raw.left(300)])

	var pushed := false

	if response_code == 200:
		var outer := JSON.new()
		if outer.parse(raw) == OK:
			var outer_data: Variant = outer.get_data()
			if outer_data is Dictionary and outer_data.has("message"):
				# [FIX 3] Ưu tiên lấy từ key "content",
				# nhưng qwen3 đôi khi đặt JSON thực ở key "thinking" hoặc lẫn lộn
				var content: String = outer_data["message"].get("content", "").strip_edges()
				print("[AIManager] [DEBUG] content: %s" % content.left(300))

				var json_str: String = _extract_json(content)
				if not json_str.is_empty():
					var inner := JSON.new()
					if inner.parse(json_str) == OK:
						var q: Variant = inner.get_data()
						if q is Dictionary and q.has("question") and q.has("correct_answer"):
							# Chuẩn hoá: hỗ trợ cả format options[] lẫn A/B/C/D rời
							q = _normalize_question(q)
							q["word_id"] = word_id
							question_queues[tier_id].append(q)
							print("[AIManager] ✓ Tier %d '%s' | Queue: %d/%d" \
								% [tier_id, word, question_queues[tier_id].size(), MAX_QUEUE_SIZE])
							pushed = true
						else:
							push_warning("[AIManager] JSON thiếu key. Keys: %s" % str(q.keys() if q is Dictionary else []))
					else:
						push_warning("[AIManager] Parse inner JSON thất bại:\n%s" % json_str.left(300))
				else:
					push_warning("[AIManager] Không tìm thấy JSON object trong content.")
		else:
			push_warning("[AIManager] Parse outer JSON thất bại.")
	else:
		push_warning("[AIManager] HTTP %d từ Ollama." % response_code)

	if not pushed:
		push_warning("[AIManager] Dùng fallback cho tier %d '%s'." % [tier_id, word])
		_push_fallback(word_id, word, meaning, tier_id)

	# [FIX 1] Reset flag SAU KHI xử lý xong — không bao giờ bị kẹt
	_tier_generating[tier_id] = false

	# Tiếp tục nạp nếu còn thiếu
	check_and_fill_all_queues()


# ==============================================================================
# HELPERS — JSON EXTRACTION & NORMALISATION
# ==============================================================================

## Trích xuất JSON object đầu tiên từ chuỗi có thể chứa <think>...</think>,
## markdown ```json...``` hoặc văn bản thừa phía trước/sau.
func _extract_json(text: String) -> String:
	var s: String = text.strip_edges()

	# [FIX 3] Strip toàn bộ block <think>...</think> của qwen3
	while "<think>" in s:
		var t_start: int = s.find("<think>")
		var t_end: int   = s.find("</think>")
		if t_end == -1:
			# Tag chưa đóng — xóa từ <think> đến hết
			s = s.substr(0, t_start).strip_edges()
			break
		s = (s.substr(0, t_start) + s.substr(t_end + 8)).strip_edges()

	# Strip markdown code block
	if s.begins_with("```"):
		var fence_end: int = s.find("```", 3)
		if fence_end != -1:
			s = s.substr(3, fence_end - 3).strip_edges()
		if s.begins_with("json"):
			s = s.substr(4).strip_edges()

	# Lấy { } ngoài cùng
	var start: int = s.find("{")
	var end: int   = s.rfind("}")
	if start == -1 or end == -1 or end <= start:
		return ""
	return s.substr(start, end - start + 1)


## Chuẩn hoá câu hỏi: hỗ trợ cả 2 format AI hay trả về:
##   Format A: { "A": "...", "B": "...", "C": "...", "D": "...", "correct_answer": "A" }
##   Format B: { "options": ["...", "..."], "correct_answer": "Nội dung đáp án" }
## Output cuối luôn là Format A để battle_scene không cần thay đổi.
func _normalize_question(q: Dictionary) -> Dictionary:
	# Nếu đã có A/B/C/D đầy đủ → giữ nguyên
	if q.has("A") and q.has("B") and q.has("C") and q.has("D"):
		# Đảm bảo correct_answer là chữ cái A/B/C/D (không phải nội dung)
		return q

	# Nếu có options[] → chuyển sang A/B/C/D
	if q.has("options") and q["options"] is Array:
		var opts: Array = q["options"]
		while opts.size() < 4:
			opts.append("---")
		var labels: Array = ["A", "B", "C", "D"]
		for i in range(4):
			q[labels[i]] = _strip_prefix(str(opts[i]))

		# correct_answer có thể là nội dung hoặc chữ cái → chuẩn hoá về chữ cái
		var ca: String = str(q.get("correct_answer", "")).strip_edges()
		if ca.length() == 1 and ca.to_upper() in ["A","B","C","D"]:
			q["correct_answer"] = ca.to_upper()
		else:
			# Tìm option nào khớp nội dung
			for i in range(4):
				if _strip_prefix(str(opts[i])) == _strip_prefix(ca):
					q["correct_answer"] = labels[i]
					break

	return q


## Strip "A. ", "A) ", "(A) " khỏi đầu chuỗi
func _strip_prefix(s: String) -> String:
	var t: String = s.strip_edges()
	if t.length() < 2:
		return t
	var fc: String = t.substr(0, 1).to_upper()
	if fc not in ["A","B","C","D","1","2","3","4"]:
		return t
	var sc: String = t.substr(1, 1)
	if sc in [".", ")", ":", "-", " "]:
		return t.substr(2).strip_edges()
	if t.begins_with("(") and t.length() > 3 and t.substr(2,1) == ")":
		return t.substr(3).strip_edges()
	return t


# ==============================================================================
# FALLBACK
# ==============================================================================

func _push_fallback(word_id: int, word: String, meaning: String, tier_id: int) -> void:
	var distractors: Array = _make_distractors(meaning)
	var all_opts: Array    = ([meaning] + distractors)
	all_opts.shuffle()
	var labels: Array = ["A","B","C","D"]
	var correct_label: String = "A"
	var q: Dictionary = {
		"word_id":     word_id,
		"question":    "Từ \"%s\" trong tiếng Anh có nghĩa là gì?" % word,
		"explanation": "\"%s\" có nghĩa là \"%s\"." % [word, meaning]
	}
	for i in range(4):
		q[labels[i]] = all_opts[i]
		if all_opts[i] == meaning:
			correct_label = labels[i]
	q["correct_answer"] = correct_label
	question_queues[tier_id].append(q)
	print("[AIManager] [Fallback] Tier %d '%s' | Queue: %d/%d" \
		% [tier_id, word, question_queues[tier_id].size(), MAX_QUEUE_SIZE])


func _make_distractors(correct: String) -> Array:
	var pool: Array = [
		"Loài động vật hoang dã", "Công cụ chiến đấu",
		"Hiện tượng thiên nhiên", "Loài thực vật rừng",
		"Vật liệu xây dựng",      "Địa hình địa lý",
		"Sinh vật huyền thoại",   "Nguồn tài nguyên",
		"Kỹ năng sinh tồn",       "Hiệu ứng phép thuật",
	]
	pool = pool.filter(func(m): return m != correct)
	pool.shuffle()
	return pool.slice(0, 3)


## Thử lại nạp tier sau N giây mà không block bất kỳ coroutine nào
func _retry_after(tier_id: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_tier_generating[tier_id] = false
	check_and_fill_all_queues()


# ==============================================================================
# DDA — ĐỘ KHÓ ĐỘNG
# ==============================================================================

func _resolve_difficulty(mastery: float, encounters: int, avg_mastery: float) -> String:
	var advanced: bool = avg_mastery >= THRESHOLD_HARD

	if encounters == 0:
		return "Đây là LẦN ĐẦU người chơi gặp từ này. Tạo câu NHẬN DIỆN NGHĨA trực tiếp. Đáp án sai phải rõ ràng sai hơn."
	elif mastery < 0.3:
		if advanced:
			return "Người chơi gặp từ này %d lần nhưng vẫn hay sai dù tier đã khá. Tạo câu ĐIỀN VÀO CHỖ TRỐNG đơn giản." % encounters
		return "Người chơi gặp từ này %d lần nhưng vẫn hay sai. Tạo câu CỦNG CỐ: hỏi nghĩa hoặc nhận diện từ trong câu đơn giản." % encounters
	elif mastery < 0.6:
		if advanced:
			return "Người chơi đang tiến bộ (%d lần gặp), tier đã khá. Tạo câu ĐỒNG/TRÁI NGHĨA hoặc ĐIỀN VÀO CHỖ TRỐNG ngữ cảnh phong phú." % encounters
		return "Người chơi đã gặp %d lần và đang tiến bộ. Tạo câu MỨC TRUNG BÌNH: đồng nghĩa, trái nghĩa hoặc điền vào chỗ trống." % encounters
	else:
		return "Người chơi đã thành thạo từ này (%d lần gặp). Tạo câu NÂNG CAO: ngữ cảnh phức tạp, sắc thái nghĩa, phân biệt từ đồng nghĩa gần nhau." % encounters


# ==============================================================================
# PROMPT BUILDER
# ==============================================================================

func _build_prompt(word: String, meaning: String, difficulty: String) -> String:
	return """Bạn là Elaria, hệ thống tạo câu hỏi trắc nghiệm tiếng Anh cho game RPG.
Nhiệm vụ: Tạo 1 câu MCQ kiểm tra từ vựng tiếng Anh.

TỪ BẮT BUỘC: "%s" (nghĩa tiếng Việt: %s)

CHỈ THỊ ĐỘ KHÓ (BẮT BUỘC TUÂN THEO):
%s

QUY TẮC:
1. Câu hỏi PHẢI xoay quanh từ được chỉ định.
2. 3 đáp án sai cùng từ loại với đáp án đúng, nghe có lý, không quá dễ loại trừ.
3. KHÔNG để lộ nghĩa tiếng Việt trong nội dung câu hỏi.
4. Trả về ĐÚNG cấu trúc JSON sau, KHÔNG thêm bất kỳ văn bản nào khác:
{
    "question": "Nội dung câu hỏi?",
    "A": "Lựa chọn 1",
    "B": "Lựa chọn 2",
    "C": "Lựa chọn 3",
    "D": "Lựa chọn 4",
    "correct_answer": "A",
    "explanation": "Giải thích ngắn gọn bằng tiếng Việt."
}
"correct_answer" CHỈ ĐƯỢC chứa đúng 1 chữ cái in hoa (A, B, C, hoặc D).
KHÔNG sinh thêm bất kỳ văn bản nào ngoài JSON.""" \
	% [word, meaning, difficulty]


# ==============================================================================
# API CÔNG KHAI
# ==============================================================================

func get_question() -> Dictionary:
	var queue: Array = question_queues[current_tier_id]
	check_and_fill_all_queues()

	if not queue.is_empty():
		var q: Dictionary = queue.pop_front()
		print("[AIManager] Phát câu | tier %d | word_id=%d | Queue còn: %d" \
			% [current_tier_id, q.get("word_id",-1), queue.size()])
		return q

	push_warning("[AIManager] Queue rỗng! Dùng emergency fallback.")
	var db = get_node_or_null("/root/DatabaseManager")
	var vocab: Dictionary = db.get_weakest_vocab(current_tier_id) if db else {}
	if not vocab.is_empty():
		_push_fallback(vocab.get("word_id",-1), vocab.get("word","Forest"),
					   vocab.get("meaning","Khu rừng"), current_tier_id)
		return question_queues[current_tier_id].pop_front()

	return {
		"question": "Từ nào sau đây có nghĩa là 'Khu rừng'?",
		"A": "Desert", "B": "Ocean", "C": "Forest", "D": "Mountain",
		"correct_answer": "C",
		"explanation": "Câu dự phòng. 'Forest' có nghĩa là khu rừng.",
		"word_id": -1
	}


func set_tier(tier_id: int) -> void:
	if not question_queues.has(tier_id):
		push_warning("[AIManager] Tier %d không tồn tại." % tier_id)
		return
	current_tier_id = tier_id
	print("[AIManager] Chuyển sang tier %d | Queue: %d câu" \
		% [tier_id, question_queues[tier_id].size()])
	check_and_fill_all_queues()


func get_queue_size(tier_id: int = -1) -> int:
	var t: int = tier_id if tier_id != -1 else current_tier_id
	return question_queues[t].size() if question_queues.has(t) else 0
