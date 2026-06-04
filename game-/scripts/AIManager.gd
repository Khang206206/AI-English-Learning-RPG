extends Node

# ==============================================================================
# AIManager.gd — AutoLoad Singleton
# Trách nhiệm: Quản lý queue câu hỏi, giao tiếp HTTP với Ollama,
#              chọn loại câu hỏi (DDA), build prompt, parse JSON
# Phụ thuộc: ProgressManager (vocab + mastery), DatabaseManager (gián tiếp)
# ==============================================================================

const OLLAMA_URL: String   = "http://127.0.0.1:11434/api/chat"
const OLLAMA_MODEL: String = "qwen3.5:4b"

# Queue riêng cho từng tier — key là tier_id (int), value là Array câu hỏi
var question_queues: Dictionary = {}

# Per-tier generating flag — tránh race condition khi nhiều tier cùng nạp
var _tier_generating: Dictionary = {}   # tier_id → bool

const MAX_QUEUE_SIZE: int = 5
const MANAGED_TIERS: Array = [1, 2]

var current_tier_id: int = 1

# ── Question type constants ──
const QTYPE_MCQ:  String = "mcq"
const QTYPE_TEXT: String = "text_input"


# ── Signal cho NPC hint ──
signal hint_ready(hint_text: String)


func _ready() -> void:
	for tier in MANAGED_TIERS:
		question_queues[tier]  = []
		_tier_generating[tier] = false

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

	var progress = get_node_or_null("/root/ProgressManager")
	if progress == null:
		push_error("[AIManager] Không tìm thấy ProgressManager!")
		_tier_generating[tier_id] = false
		return

	var vocab: Dictionary = progress.get_weakest_vocab(tier_id)
	if vocab.is_empty():
		push_warning("[AIManager] ProgressManager trả về rỗng cho tier %d." % tier_id)
		_tier_generating[tier_id] = false
		return

	var word: String          = vocab.get("word",           "")
	var meaning: String       = vocab.get("meaning",        "")
	var word_id: int          = vocab.get("word_id",        -1)
	var mastery_score: float  = vocab.get("mastery_score",  0.0)
	var encounter_count: int  = vocab.get("encounter_count", 0)
	var avg_mastery: float    = progress.get_tier_avg_mastery(tier_id)

	print("[AIManager] Nạp tier %d | word='%s' (id=%d) | mastery=%.2f" \
		% [tier_id, word, word_id, mastery_score])

	var config: Dictionary    = _resolve_question_config(mastery_score, encounter_count, avg_mastery, tier_id)
	var system_prompt: String = _build_prompt(word, meaning, config)
	var user_msg: String      = "Tạo câu hỏi cho từ: \"%s\"." % word

	var payload: Dictionary = {
		"model": OLLAMA_MODEL,
		"messages": [
			{ "role": "system", "content": system_prompt },
			{ "role": "user",   "content": user_msg }
		],
		# Tắt "thinking mode" của qwen3 — tránh <think>...</think> làm parser fail
		"think":   false,
		"format":  "json",
		"stream":  false,
		"options": {
			"temperature": 0.45,
			"num_predict": 512
		}
	}

	# Mỗi request tạo HTTPRequest riêng → không race condition
	var http := HTTPRequest.new()
	add_child(http)

	# Truyền config vào lambda để _handle_response có đủ metadata
	http.request_completed.connect(
		func(result, code, _headers, body):
			await _handle_response(result, code, body, word_id, word, meaning, tier_id, config)
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
		_retry_after(tier_id, 3.0)


# ==============================================================================
# XỬ LÝ RESPONSE
# ==============================================================================

func _handle_response(
	_result, response_code: int, body: PackedByteArray,
	word_id: int, word: String, meaning: String, tier_id: int,
	config: Dictionary
) -> void:
	var raw: String    = body.get_string_from_utf8()
	var ui_mode: String = config.get("ui_mode", QTYPE_MCQ)
	var q_type: String  = config.get("q_type",  "vocab_meaning")

	print("[AIManager] [DEBUG] Tier %d HTTP %d | %d chars | preview: %s" \
		% [tier_id, response_code, raw.length(), raw.left(300)])

	var pushed := false

	if response_code == 200:
		var outer := JSON.new()
		if outer.parse(raw) == OK:
			var outer_data: Variant = outer.get_data()
			if outer_data is Dictionary and outer_data.has("message"):
				var content: String = outer_data["message"].get("content", "").strip_edges()
				print("[AIManager] [DEBUG] content: %s" % content.left(300))

				var json_str: String = _extract_json(content)
				if not json_str.is_empty():
					var inner := JSON.new()
					if inner.parse(json_str) == OK:
						var q: Variant = inner.get_data()
						if q is Dictionary and q.has("question") and q.has("correct_answer"):
							q["word_id"]       = word_id
							q["question_type"] = q_type
							q["ui_mode"]       = ui_mode

							if ui_mode == QTYPE_MCQ:
								q = _normalize_question(q)
							else:
								q["correct_answer"] = str(q["correct_answer"]).strip_edges().to_lower()
								if not q.has("accept_alternatives") or not (q["accept_alternatives"] is Array):
									q["accept_alternatives"] = []

							question_queues[tier_id].append(q)
							print("[AIManager] ✓ Tier %d '%s' [%s] | Queue: %d/%d"
								% [tier_id, word, q_type, question_queues[tier_id].size(), MAX_QUEUE_SIZE])
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

	# Reset flag SAU KHI xử lý xong
	_tier_generating[tier_id] = false
	check_and_fill_all_queues()


# ==============================================================================
# DDA — CHỌN LOẠI CÂU HỎI THEO MASTERY
# ==============================================================================

func _resolve_question_config(
	mastery: float, encounters: int, avg_mastery: float, tier_id: int
) -> Dictionary:

	if encounters == 0:
		return {
			"difficulty": "LẦN ĐẦU gặp từ. Tạo câu NHẬN DIỆN NGHĨA trực tiếp bằng tiếng Việt. 3 đáp án sai rõ ràng sai.",
			"q_type": "vocab_meaning", "ui_mode": QTYPE_MCQ,
		}

	if mastery < 0.3:
		if encounters % 2 == 0:
			return {
				"difficulty": "Gặp %d lần, vẫn hay sai. Tạo câu ĐIỀN TỪ: câu tiếng Anh ngắn (5-8 từ) có chỗ trống ___ = từ mục tiêu." % encounters,
				"q_type": "fill_in_blank", "ui_mode": QTYPE_TEXT,
			}
		return {
			"difficulty": "Gặp %d lần, vẫn hay sai. Tạo câu NHẬN DIỆN NGHĨA đơn giản. Đáp án sai cùng chủ đề nhưng nghĩa khác hẳn." % encounters,
			"q_type": "vocab_meaning", "ui_mode": QTYPE_MCQ,
		}

	if mastery < 0.6:
		var roll: int = randi() % 3
		if roll == 0:
			return {
				"difficulty": "Đã gặp %d lần, đang tiến bộ. Tạo câu ĐỒNG/TRÁI NGHĨA: 'Which word is a synonym/antonym of X?'. 4 đáp án tiếng Anh." % encounters,
				"q_type": "synonym_antonym", "ui_mode": QTYPE_MCQ,
			}
		elif roll == 1:
			return {
				"difficulty": "Đã gặp %d lần, đang tiến bộ. Tạo câu ĐIỀN TỪ: câu tiếng Anh có ngữ cảnh phong phú, ___ = từ mục tiêu." % encounters,
				"q_type": "fill_in_blank", "ui_mode": QTYPE_TEXT,
			}
		return {
			"difficulty": "Đã gặp %d lần, đang tiến bộ. Tạo câu XÁC ĐỊNH LỖI SAI: cho 4 câu tiếng Anh dùng từ mục tiêu, 3 câu sai ngữ pháp/ngữ nghĩa, 1 câu đúng." % encounters,
			"q_type": "error_identification", "ui_mode": QTYPE_MCQ,
		}

	# mastery >= 0.6
	var roll: int = randi() % 3
	if roll == 0:
		return {
			"difficulty": "Đã thành thạo (%d lần). Tạo câu ĐIỀN TỪ nâng cao: câu dài, ngữ cảnh phức tạp." % encounters,
			"q_type": "fill_in_blank", "ui_mode": QTYPE_TEXT,
		}
	elif roll == 1:
		return {
			"difficulty": "Đã thành thạo (%d lần). Tạo câu PHÂN BIỆT TỪ ĐỒNG NGHĨA GẦN NHAU." % encounters,
			"q_type": "synonym_antonym", "ui_mode": QTYPE_MCQ,
		}

	# roll == 2: grammar
	var progress = get_node_or_null("/root/ProgressManager")
	var grammar: Dictionary = progress.get_random_grammar(tier_id) if progress else {}
	var topic: String = grammar.get("topic_name", "Present Simple")
	return {
		"difficulty": "Đã thành thạo (%d lần). Tạo câu NGỮ PHÁP: chia động từ/danh từ theo '%s'." % [encounters, topic],
		"q_type": "grammar_mcq", "ui_mode": QTYPE_MCQ,
		"grammar_topic": topic,
	}


# ==============================================================================
# PROMPT BUILDER
# ==============================================================================

func _build_prompt(word: String, meaning: String, config: Dictionary) -> String:
	var q_type: String     = config.get("q_type",    "vocab_meaning")
	var difficulty: String = config.get("difficulty", "")
	var ui_mode: String    = config.get("ui_mode",    QTYPE_MCQ)

	var json_template: String
	if ui_mode == QTYPE_TEXT:
		json_template = """{
    "question_type": "%s",
    "question": "Câu có chỗ trống ___",
    "correct_answer": "từ cần điền viết thường",
    "accept_alternatives": ["dạng khác nếu có"],
    "explanation": "Giải thích bằng tiếng Việt."
}""" % q_type
	else:
		json_template = """{
    "question_type": "%s",
    "question": "Nội dung câu hỏi?",
    "A": "Lựa chọn 1", "B": "Lựa chọn 2",
    "C": "Lựa chọn 3", "D": "Lựa chọn 4",
    "correct_answer": "A",
    "explanation": "Giải thích bằng tiếng Việt."
}""" % q_type

	return """Bạn là Elaria, hệ thống tạo câu hỏi tiếng Anh cho game RPG.

TỪ BẮT BUỘC: "%s" (nghĩa: %s)

CHỈ THỊ (BẮT BUỘC):
%s

QUY TẮC:
1. Câu hỏi PHẢI liên quan đến từ "%s".
2. KHÔNG để lộ nghĩa tiếng Việt trong câu hỏi.
3. Điền từ: dùng ___ đánh dấu chỗ trống, correct_answer viết thường.
4. MCQ: 3 đáp án sai hợp lý, cùng từ loại.
5. Trả về ĐÚNG JSON sau, KHÔNG thêm văn bản:
%s
KHÔNG sinh gì ngoài JSON.""" % [word, meaning, difficulty, word, json_template]


# ==============================================================================
# HELPERS — JSON EXTRACTION & NORMALISATION
# ==============================================================================

## Trích xuất JSON object đầu tiên từ chuỗi có thể chứa <think>...</think>,
## markdown ```json...``` hoặc văn bản thừa phía trước/sau.
func _extract_json(text: String) -> String:
	var s: String = text.strip_edges()

	# Strip toàn bộ block <think>...</think> của qwen3
	while "<think>" in s:
		var t_start: int = s.find("<think>")
		var t_end: int   = s.find("</think>")
		if t_end == -1:
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
		return q

	# Nếu có options[] → chuyển sang A/B/C/D
	if q.has("options") and q["options"] is Array:
		var opts: Array = q["options"]
		while opts.size() < 4:
			opts.append("---")
		var labels: Array = ["A", "B", "C", "D"]
		for i in range(4):
			q[labels[i]] = _strip_prefix(str(opts[i]))

		var ca: String = str(q.get("correct_answer", "")).strip_edges()
		if ca.length() == 1 and ca.to_upper() in ["A","B","C","D"]:
			q["correct_answer"] = ca.to_upper()
		else:
			var found: bool = false
			var clean_ca: String = _strip_prefix(ca).to_lower().replace(".", "").replace(",", "").strip_edges()
			for i in range(4):
				var clean_opt: String = _strip_prefix(str(opts[i])).to_lower().replace(".", "").replace(",", "").strip_edges()
				if clean_opt != "" and clean_opt == clean_ca:
					q["correct_answer"] = labels[i]
					found = true
					break
			
			if not found:
				q["correct_answer"] = "A"
				push_warning("[AIManager] Fallback correct_answer = A do không map được: " + ca)

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
		"word_id":       word_id,
		"question_type": "vocab_meaning",
		"ui_mode":       QTYPE_MCQ,
		"question":      "Từ \"%s\" trong tiếng Anh có nghĩa là gì?" % word,
		"explanation":   "\"%s\" có nghĩa là \"%s\"." % [word, meaning]
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
# NPC HINT — Elaria gợi ý mẹo nhớ từ
# ==============================================================================

## Gửi request đến Ollama để sinh mẹo nhớ từ cho NPC.
## Kết quả phát về qua signal hint_ready(hint_text: String).
func request_npc_hint(word: String, meaning: String) -> void:
	var prompt: String = """Tạo 1 mẹo nhớ từ "%s" (nghĩa: %s) ngắn 1-2 câu, tiếng Việt,
liên tưởng âm thanh hoặc hình ảnh. JSON: {"hint": "..."}""" % [word, meaning]

	var payload: Dictionary = {
		"model": OLLAMA_MODEL,
		"messages": [
			{"role": "system", "content": "Bạn là Elaria, NPC phù thủy trong game RPG."},
			{"role": "user",   "content": prompt}
		],
		"think": false, "format": "json", "stream": false,
		"options": {"temperature": 0.7, "num_predict": 150}
	}
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		var hint: String = "Elaria đang suy nghĩ..."
		if code == 200:
			var js: String = _extract_json(body.get_string_from_utf8())
			var p := JSON.new()
			if p.parse(js) == OK and p.get_data() is Dictionary:
				hint = p.get_data().get("hint", hint)
		emit_signal("hint_ready", hint)
		http.queue_free()
	)
	http.request(OLLAMA_URL, ["Content-Type: application/json"],
				 HTTPClient.METHOD_POST, JSON.stringify(payload))


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
	var progress = get_node_or_null("/root/ProgressManager")
	var vocab: Dictionary = progress.get_weakest_vocab(current_tier_id) if progress else {}
	if not vocab.is_empty():
		_push_fallback(vocab.get("word_id",-1), vocab.get("word","Forest"),
					   vocab.get("meaning","Khu rừng"), current_tier_id)
		return question_queues[current_tier_id].pop_front()

	return {
		"question": "Từ nào sau đây có nghĩa là 'Khu rừng'?",
		"A": "Desert", "B": "Ocean", "C": "Forest", "D": "Mountain",
		"correct_answer": "C",
		"explanation": "Câu dự phòng. 'Forest' có nghĩa là khu rừng.",
		"word_id": -1,
		"question_type": "vocab_meaning",
		"ui_mode": QTYPE_MCQ,
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
