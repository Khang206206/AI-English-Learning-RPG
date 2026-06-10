extends Node

# ==============================================================================
# AIManager.gd — AutoLoad Singleton
# Trách nhiệm: Quản lý queue câu hỏi, giao tiếp HTTP với Ollama,
#              chọn loại câu hỏi (DDA), build prompt, parse JSON
# Phụ thuộc: ProgressManager (vocab + mastery), DatabaseManager (gián tiếp)
# ==============================================================================

const OLLAMA_URL: String   = "http://127.0.0.1:11434/api/chat"
const OLLAMA_MODEL: String = "qwen3.5:4b"
const QUESTION_TIMEOUT_SECONDS: float = 20.0
const VERBOSE_AI_LOGS: bool = false

# Queue riêng cho từng tier — key là tier_id (int), value là Array câu hỏi
var question_queues: Dictionary = {}

# Per-tier generating flag — tránh race condition khi nhiều tier cùng nạp
var _tier_generating: Dictionary = {}   # tier_id → bool

const MAX_QUEUE_SIZE: int = 5
const MANAGED_TIERS: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9]

const TIER_THEMES: Dictionary = {
	1: "Nature & Forest (Thiên nhiên & Rừng rậm)",
	2: "Camping & Tools (Cắm trại & Vật dụng)",
	3: "Survival & Weather (Sinh tồn & Thời tiết)",
	4: "Ancient Ruins & History (Di tích cổ & Lịch sử)",
	5: "Combat & Weaponry (Chiến đấu & Vũ khí)",
	6: "Caves & Mining (Hang động & Khai khoáng)",
	7: "Magic & Alchemy (Phép thuật & Giả kim)",
	8: "Labyrinths & Myths (Mê cung & Thần thoại)",
	9: "Demons & Underworld (Ác quỷ & Địa ngục)",
}

var current_tier_id: int = 1
var ollama_url: String = OLLAMA_URL

# ── Question type constants ──
const QTYPE_MCQ:  String = "mcq"
const QTYPE_TEXT: String = "text_input"


# ── Signal cho NPC hint ──
signal hint_ready(hint_text: String)
signal example_sentence_ready(sentence_text: String)
signal mini_test_ready(questions: Array)

# ── Biến quản lý gián đoạn (Preemption) ──
var current_bg_http: HTTPRequest = null
var current_bg_tier: int = -1

func _debug_log(message: String) -> void:
	if VERBOSE_AI_LOGS:
		print(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var env_ollama_url := OS.get_environment("AI_RPG_OLLAMA_URL").strip_edges()
	if not env_ollama_url.is_empty():
		ollama_url = env_ollama_url
	
	for tier in MANAGED_TIERS:
		question_queues[tier]  = []
		_tier_generating[tier] = false

	_debug_log("[AIManager] Khởi động — nạp queue cho %d tier..." % MANAGED_TIERS.size())
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

## Hủy request ngầm đang chạy (nếu có) để nhường đường cho request ưu tiên cao
func _interrupt_background_task() -> void:
	if is_instance_valid(current_bg_http):
		current_bg_http.cancel_request()
		current_bg_http.queue_free()
		current_bg_http = null
		
		if current_bg_tier != -1:
			_tier_generating[current_bg_tier] = false
			_debug_log("[AIManager] Đã hủy tạo câu hỏi ngầm tier %d để ưu tiên người chơi." % current_bg_tier)
			current_bg_tier = -1

func _generate_for_tier(tier_id: int) -> void:
	_tier_generating[tier_id] = true

	var progress = get_node_or_null("/root/ProgressManager")
	if progress == null:
		push_error("[AIManager] Không tìm thấy ProgressManager!")
		_tier_generating[tier_id] = false
		return

	var is_grammar: bool = false
	if randf() <= 0.25:
		is_grammar = true

	var target_data: Dictionary = {}
	if is_grammar:
		target_data = progress.get_weakest_grammar(tier_id)
		if target_data.is_empty():
			is_grammar = false
	
	if not is_grammar:
		target_data = progress.get_weakest_vocab(tier_id)

	if target_data.is_empty():
		push_warning("[AIManager] Không lấy được dữ liệu vocab/grammar cho tier %d." % tier_id)
		_tier_generating[tier_id] = false
		return

	var config: Dictionary = {}
	var system_prompt: String = ""
	var user_msg: String = ""
	var target_id: int = -1
	var word_or_topic: String = ""
	var meaning_or_formula: String = ""

	if is_grammar:
		target_id = target_data.get("grammar_id", -1)
		word_or_topic = target_data.get("topic_name", "")
		meaning_or_formula = target_data.get("formula", "")
		var mastery_score: float = target_data.get("mastery_score", 0.0)
		var encounter_count: int = target_data.get("encounter_count", 0)
		
		# Lấy 1 từ vựng ngẫu nhiên để tạo bối cảnh
		var context_vocab: Dictionary = progress.get_weakest_vocab(tier_id)
		var context_word: String = context_vocab.get("word", "adventurer") if not context_vocab.is_empty() else "adventurer"
		
		_debug_log("[AIManager] Nạp Ngữ pháp tier %d | topic='%s' (id=%d) | mastery=%.2f" \
			% [tier_id, word_or_topic, target_id, mastery_score])
			
		config = _resolve_grammar_config(mastery_score, encounter_count, word_or_topic)
		system_prompt = _build_grammar_prompt(word_or_topic, meaning_or_formula, context_word, config, tier_id)
		user_msg = "Tạo câu hỏi ngữ pháp về: \"%s\"." % word_or_topic
	else:
		target_id = target_data.get("word_id", -1)
		word_or_topic = target_data.get("word", "")
		meaning_or_formula = target_data.get("meaning", "")
		var mastery_score: float = target_data.get("mastery_score", 0.0)
		var encounter_count: int = target_data.get("encounter_count", 0)
		var avg_mastery: float = progress.get_tier_avg_mastery(tier_id)

		_debug_log("[AIManager] Nạp Từ vựng tier %d | word='%s' (id=%d) | mastery=%.2f" \
			% [tier_id, word_or_topic, target_id, mastery_score])

		config = _resolve_question_config(mastery_score, encounter_count, avg_mastery, tier_id)
		system_prompt = _build_prompt(word_or_topic, meaning_or_formula, config, tier_id)
		user_msg = "Tạo câu hỏi cho từ: \"%s\"." % word_or_topic

	var payload: Dictionary = {
		"model": OLLAMA_MODEL,
		"messages": [
			{ "role": "system", "content": system_prompt },
			{ "role": "user",   "content": user_msg }
		],
		"think":   false,
		"format":  "json",
		"stream":  false,
		"options": {
			"temperature": 0.45,
			"num_predict": 512
		}
	}

	var http := HTTPRequest.new()
	add_child(http)
	
	current_bg_http = http
	current_bg_tier = tier_id
	var completed := [false]
	var timeout_timer := get_tree().create_timer(QUESTION_TIMEOUT_SECONDS, true)

	timeout_timer.timeout.connect(func():
		if completed[0]:
			return
		completed[0] = true
		if current_bg_http == http:
			current_bg_http = null
			current_bg_tier = -1
		if is_instance_valid(http):
			http.cancel_request()
			http.queue_free()
		push_warning("[AIManager] Timeout %.0fs khi tạo câu hỏi tier %d. Dùng fallback." % [QUESTION_TIMEOUT_SECONDS, tier_id])
		if is_grammar:
			_push_grammar_fallback(target_id, word_or_topic, meaning_or_formula, tier_id)
		else:
			_push_fallback(target_id, word_or_topic, meaning_or_formula, tier_id)
		_tier_generating[tier_id] = false
		check_and_fill_all_queues()
	)

	http.request_completed.connect(
		func(result, code, _headers, body):
			if completed[0]:
				return
			completed[0] = true
			if current_bg_http == http:
				current_bg_http = null
				current_bg_tier = -1
			await _handle_response(result, code, body, target_id, word_or_topic, meaning_or_formula, tier_id, config, is_grammar)
			if is_instance_valid(http):
				http.queue_free()
	)

	var err = http.request(
		ollama_url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if err != OK:
		completed[0] = true
		if current_bg_http == http:
			current_bg_http = null
			current_bg_tier = -1
		push_error("[AIManager] Gửi request thất bại (err=%d). Tier %d." % [err, tier_id])
		http.queue_free()
		_tier_generating[tier_id] = false
		_retry_after(tier_id, 3.0)


# ==============================================================================
# XỬ LÝ RESPONSE
# ==============================================================================

func _handle_response(
	_result, response_code: int, body: PackedByteArray,
	target_id: int, word_or_topic: String, meaning: String, tier_id: int,
	config: Dictionary, is_grammar: bool = false
) -> void:
	var raw: String    = body.get_string_from_utf8()
	var ui_mode: String = config.get("ui_mode", QTYPE_MCQ)
	var q_type: String  = config.get("q_type",  "vocab_meaning")

	_debug_log("[AIManager] Tier %d HTTP %d | %d chars | preview: %s" \
		% [tier_id, response_code, raw.length(), raw.left(300)])

	var pushed := false

	if response_code == 200:
		var outer := JSON.new()
		if outer.parse(raw) == OK:
			var outer_data: Variant = outer.get_data()
			if outer_data is Dictionary and outer_data.has("message"):
				var content: String = outer_data["message"].get("content", "").strip_edges()
				_debug_log("[AIManager] content: %s" % content.left(300))

				var json_str: String = _extract_json(content)
				if not json_str.is_empty():
					var inner := JSON.new()
					if inner.parse(json_str) == OK:
						var q: Variant = inner.get_data()
						if q is Dictionary and q.has("question") and q.has("correct_answer"):
							if is_grammar:
								q["grammar_id"]    = target_id
							else:
								q["word_id"]       = target_id
							q["question_type"] = q_type
							q["ui_mode"]       = ui_mode

							if ui_mode == QTYPE_MCQ:
								q = _normalize_question(q)
							else:
								q["correct_answer"] = str(q["correct_answer"]).strip_edges().to_lower()
								if not q.has("accept_alternatives") or not (q["accept_alternatives"] is Array):
									q["accept_alternatives"] = []

							question_queues[tier_id].append(q)
							_debug_log("[AIManager] Tier %d '%s' [%s] | Queue: %d/%d"
								% [tier_id, word_or_topic, q_type, question_queues[tier_id].size(), MAX_QUEUE_SIZE])
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
		push_warning("[AIManager] Dùng fallback cho tier %d '%s'." % [tier_id, word_or_topic])
		if is_grammar:
			_push_grammar_fallback(target_id, word_or_topic, meaning, tier_id)
		else:
			_push_fallback(target_id, word_or_topic, meaning, tier_id)

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
	var roll: int = randi() % 2
	if roll == 0:
		return {
			"difficulty": "Đã thành thạo (%d lần). Tạo câu ĐIỀN TỪ nâng cao: câu dài, ngữ cảnh phức tạp." % encounters,
			"q_type": "fill_in_blank", "ui_mode": QTYPE_TEXT,
		}
	else:
		return {
			"difficulty": "Đã thành thạo (%d lần). Tạo câu PHÂN BIỆT TỪ ĐỒNG NGHĨA GẦN NHAU." % encounters,
			"q_type": "synonym_antonym", "ui_mode": QTYPE_MCQ,
		}

func _resolve_grammar_config(mastery: float, encounters: int, topic: String) -> Dictionary:
	if encounters == 0 or mastery < 0.3:
		return {
			"difficulty": "Nhận biết cơ bản: Chọn câu có cấu trúc đúng nhất hoặc điền đúng công thức. Cung cấp 4 đáp án (1 đúng, 3 sai rõ ràng).",
			"q_type": "grammar_mcq", "ui_mode": QTYPE_MCQ
		}
	if mastery < 0.6:
		return {
			"difficulty": "Tìm lỗi sai: Cho 4 câu tiếng Anh. 3 câu bị sai cấu trúc %s, 1 câu hoàn toàn đúng. Người chơi phải chọn câu ĐÚNG." % topic,
			"q_type": "error_identification", "ui_mode": QTYPE_MCQ
		}
	return {
		"difficulty": "Vận dụng cao: Điền từ vào chỗ trống (Fill in the blank) mà KHÔNG CÓ GỢI Ý. Yêu cầu tự chia động từ hoặc tự gõ cấu trúc.",
		"q_type": "grammar_text", "ui_mode": QTYPE_TEXT
	}


# ==============================================================================
# PROMPT BUILDER
# ==============================================================================

func _build_prompt(word: String, meaning: String, config: Dictionary, tier_id: int) -> String:
	var q_type: String     = config.get("q_type",    "vocab_meaning")
	var difficulty: String = config.get("difficulty", "")
	var ui_mode: String    = config.get("ui_mode",    QTYPE_MCQ)
	var theme: String      = TIER_THEMES.get(tier_id, "General English")

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
CHỦ ĐỀ NGỮ CẢNH: "%s"

CHỈ THỊ (BẮT BUỘC):
%s

QUY TẮC:
1. Câu hỏi PHẢI liên quan đến từ "%s".
2. KHÔNG để lộ nghĩa tiếng Việt trong câu hỏi.
3. Điền từ: dùng ___ đánh dấu chỗ trống, correct_answer viết thường.
4. MCQ: 3 đáp án sai hợp lý, cùng từ loại.
5. Trả về ĐÚNG JSON sau, KHÔNG thêm văn bản:
%s
KHÔNG sinh gì ngoài JSON.""" % [word, meaning, theme, difficulty, word, json_template]

func _build_grammar_prompt(topic: String, formula: String, context_word: String, config: Dictionary, tier_id: int) -> String:
	var q_type: String     = config.get("q_type",    "grammar_mcq")
	var difficulty: String = config.get("difficulty", "")
	var ui_mode: String    = config.get("ui_mode",    QTYPE_MCQ)
	var theme: String      = TIER_THEMES.get(tier_id, "General English")

	var json_template: String
	if ui_mode == QTYPE_TEXT:
		json_template = """{
    "question_type": "%s",
    "question": "Câu có chỗ trống ___",
    "correct_answer": "phần cần điền viết thường",
    "accept_alternatives": ["dạng viết tắt nếu có"],
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

	return """Bạn là Elaria, hệ thống tạo câu hỏi ngữ pháp tiếng Anh cho game RPG.

CHỦ ĐIỂM NGỮ PHÁP: "%s"
CÔNG THỨC: "%s"
TỪ VỰNG NGỮ CẢNH: "%s"
CHỦ ĐỀ: "%s"

CHỈ THỊ (BẮT BUỘC):
%s

QUY TẮC:
1. Nội dung câu hỏi PHẢI tuân thủ chủ điểm ngữ pháp "%s".
2. Dùng từ vựng "%s" hoặc chủ đề "%s" để làm nội dung câu (giúp câu sinh động).
3. KHÔNG để lộ đáp án.
4. Trả về ĐÚNG JSON sau:
%s
KHÔNG sinh gì ngoài JSON.""" % [topic, formula, context_word, theme, difficulty, topic, context_word, theme, json_template]


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
	_debug_log("[AIManager] Fallback tier %d '%s' | Queue: %d/%d" \
		% [tier_id, word, question_queues[tier_id].size(), MAX_QUEUE_SIZE])

func _push_grammar_fallback(grammar_id: int, topic: String, formula: String, tier_id: int) -> void:
	var q: Dictionary = {
		"grammar_id":    grammar_id,
		"question_type": "grammar_mcq",
		"ui_mode":       QTYPE_MCQ,
		"question":      "Công thức của cấu trúc '%s' là gì?" % topic,
		"A":             formula,
		"B":             "S + is/am/are + V-ing",
		"C":             "S + had + V3",
		"D":             "S + will + V",
		"correct_answer": "A",
		"explanation":   "Công thức đúng là: %s" % formula
	}
	question_queues[tier_id].append(q)


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
	_interrupt_background_task()
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

	var timer := Timer.new()
	timer.wait_time = 20.0
	timer.one_shot = true
	add_child(timer)

	var _completed: Array[bool] = [false]

	http.request_completed.connect(func(_r, code, _h, body):
		if _completed[0]: return
		_completed[0] = true
		if is_instance_valid(timer):
			timer.queue_free()

		var hint: String = "Elaria chưa nghĩ ra mẹo nào..."
		if code == 200:
			var raw: String = body.get_string_from_utf8()
			var outer := JSON.new()
			if outer.parse(raw) == OK and outer.get_data() is Dictionary:
				var outer_data = outer.get_data()
				if outer_data.has("message"):
					var content: String = outer_data["message"].get("content", "")
					var js: String = _extract_json(content)
					var p := JSON.new()
					if p.parse(js) == OK and p.get_data() is Dictionary:
						hint = p.get_data().get("hint", hint)
		emit_signal("hint_ready", hint)
		check_and_fill_all_queues()
		if is_instance_valid(http):
			http.queue_free()
	)

	timer.timeout.connect(func():
		if _completed[0]: return
		_completed[0] = true
		emit_signal("hint_ready", "⏳ Ollama đang bận, thử lại sau nhé!")
		check_and_fill_all_queues()
		if is_instance_valid(http):
			http.cancel_request()
			http.queue_free()
	)
	timer.start()

	var err = http.request(ollama_url, ["Content-Type: application/json"],
				 HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_completed[0] = true
		emit_signal("hint_ready", "Không thể kết nối Ollama...")
		check_and_fill_all_queues()
		if is_instance_valid(http): http.queue_free()
		if is_instance_valid(timer): timer.queue_free()


## Gửi request đến Ollama để tạo 1 câu ví dụ
func request_example_sentence(word_or_topic: String, meaning_or_formula: String, is_grammar: bool = false) -> void:
	_interrupt_background_task()
	var prompt: String = ""
	if is_grammar:
		prompt = "Make 1 English sentence using the grammar: '%s' (%s). Reply JSON: {\"en\": \"English sentence\", \"vi\": \"Vietnamese translation\"}" % [word_or_topic, meaning_or_formula]
	else:
		prompt = "Make 1 English sentence using the word '%s' (meaning: %s). Reply JSON: {\"en\": \"English sentence\", \"vi\": \"Vietnamese translation\"}" % [word_or_topic, meaning_or_formula]

	_debug_log("[AIManager] Requesting example sentence for: '%s'" % word_or_topic)

	var payload: Dictionary = {
		"model": OLLAMA_MODEL,
		"messages": [
			{"role": "system", "content": "You create example sentences. Reply ONLY with valid JSON: {\"en\": \"...\", \"vi\": \"...\"}"},
			{"role": "user",   "content": prompt}
		],
		"think": false, "format": "json", "stream": false,
		"options": {"temperature": 0.5, "num_predict": 150}
	}
	var http := HTTPRequest.new()
	add_child(http)

	var timer := Timer.new()
	timer.wait_time = 20.0
	timer.one_shot = true
	add_child(timer)

	var _completed: Array[bool] = [false]

	http.request_completed.connect(func(result: int, code: int, _h, body):
		if _completed[0]: return
		_completed[0] = true
		if is_instance_valid(timer): timer.queue_free()

		var output: String = "Elaria chưa nghĩ ra câu nào..."
		_debug_log("[AIManager] Example result=%d, HTTP code=%d" % [result, code])
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var raw: String = body.get_string_from_utf8()
			_debug_log("[AIManager] Example raw: %s" % raw.left(500))
			var outer := JSON.new()
			if outer.parse(raw) == OK and outer.get_data() is Dictionary:
				var outer_data: Dictionary = outer.get_data()
				if outer_data.has("message"):
					var content: String = str(outer_data["message"].get("content", ""))
					_debug_log("[AIManager] Example content: %s" % content.left(300))
					var js: String = _extract_json(content)
					if not js.is_empty():
						var p := JSON.new()
						if p.parse(js) == OK and p.get_data() is Dictionary:
							var data: Dictionary = p.get_data()
							var en_str: String = str(data.get("en", data.get("sentence", "")))
							var vi_str: String = str(data.get("vi", data.get("translation", "")))
							if not en_str.is_empty():
								output = "📖 %s\n📝 %s" % [en_str, vi_str]
								_debug_log("[AIManager] Example sentence OK.")
		elif result != HTTPRequest.RESULT_SUCCESS:
			_debug_log("[AIManager] Example request failed. Result enum: %d" % result)
			output = "⏳ Ollama đang bận, thử lại sau nhé!"
		emit_signal("example_sentence_ready", output)
		check_and_fill_all_queues()
		if is_instance_valid(http):
			http.queue_free()
	)

	timer.timeout.connect(func():
		if _completed[0]: return
		_completed[0] = true
		push_warning("[AIManager] Timeout 20s khi tạo câu ví dụ.")
		emit_signal("example_sentence_ready", "⏳ Ollama đang bận, thử lại sau nhé!")
		check_and_fill_all_queues()
		if is_instance_valid(http):
			http.cancel_request()
			http.queue_free()
	)
	timer.start()

	var err = http.request(ollama_url, ["Content-Type: application/json"],
				 HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_completed[0] = true
		push_warning("[AIManager] Gửi request câu ví dụ thất bại (err=%d)." % err)
		emit_signal("example_sentence_ready", "Không thể kết nối Ollama...")
		check_and_fill_all_queues()
		if is_instance_valid(http): http.queue_free()
		if is_instance_valid(timer): timer.queue_free()
	else:
		_debug_log("[AIManager] Example request sent. Waiting max 20s.")


# ==============================================================================
# 3. MINI TEST SAU PHIÊN ÔN TẬP
# ==============================================================================

func request_mini_test(vocab_item: Dictionary, grammar_item: Dictionary) -> void:
	_interrupt_background_task()
	
	var is_vocab_mcq = (randi() % 2 == 0)
	
	var v_word = vocab_item.get("word", "")
	var v_mean = vocab_item.get("meaning", "")
	var v_id   = vocab_item.get("word_id", -1)
	
	var g_topic = grammar_item.get("topic_name", "")
	var g_form  = grammar_item.get("formula", "")
	var g_id    = grammar_item.get("grammar_id", -1)
	
	var type_v = "mcq" if is_vocab_mcq else "text"
	var type_g = "text" if is_vocab_mcq else "mcq"
	
	var prompt = """You are an English teacher generating a mini test. Create exactly 2 questions in JSON.
Question 1 (Vocabulary): About the word '%s' (meaning: %s). It MUST be a %s question.
Question 2 (Grammar): About the topic '%s' (formula: %s). It MUST be a %s question.

Rules for 'mcq' (Multiple Choice):
- Generate question testing the knowledge. Do NOT include Vietnamese in the question.
- Provide 4 options A, B, C, D. Only 1 is correct.

Rules for 'text' (Fill in the blank):
- Generate an English sentence with a missing word/phrase marked by "___".
- The correct_answer MUST be exactly what goes in the blank (lowercase).

MUST return strictly this JSON format:
{
  "q1": {
    "type": "%s",
    "question": "...", "A": "...", "B": "...", "C": "...", "D": "...",
    "correct_answer": "A", "explanation": "Vietnamese explanation"
  },
  "q2": {
    "type": "%s",
    "question": "...", "correct_answer": "...", "explanation": "Vietnamese explanation"
  }
}
Return ONLY valid JSON.""" % [
		v_word, v_mean, "Multiple Choice (mcq)" if type_v=="mcq" else "Fill in the blank (text)",
		g_topic, g_form, "Multiple Choice (mcq)" if type_g=="mcq" else "Fill in the blank (text)",
		type_v, type_g
	]
	
	_debug_log("[AIManager] Requesting Mini Test.")
	
	var payload: Dictionary = {
		"model": OLLAMA_MODEL,
		"messages": [
			{"role": "system", "content": "You return only valid JSON without markdown formatting."},
			{"role": "user",   "content": prompt}
		],
		"think": false, "format": "json", "stream": false,
		"options": {"temperature": 0.5, "num_predict": 300}
	}
	
	var http := HTTPRequest.new()
	add_child(http)
	
	var timer := Timer.new()
	timer.wait_time = 15.0
	timer.one_shot = true
	add_child(timer)
	
	var _completed = [false]
	
	http.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
		if _completed[0]: return
		_completed[0] = true
		if is_instance_valid(timer): timer.stop()
		
		var out_questions: Array = []
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var raw: String = body.get_string_from_utf8()
			var outer := JSON.new()
			if outer.parse(raw) == OK and outer.get_data() is Dictionary:
				var content: String = str(outer.get_data().get("message", {}).get("content", ""))
				var js: String = _extract_json(content)
				var p := JSON.new()
				if not js.is_empty() and p.parse(js) == OK and p.get_data() is Dictionary:
					var data: Dictionary = p.get_data()
					if data.has("q1") and data.has("q2"):
						var q1: Dictionary = data["q1"]
						q1["item_id"] = v_id
						q1["item_type"] = "vocab"
						
						var q2: Dictionary = data["q2"]
						q2["item_id"] = g_id
						q2["item_type"] = "grammar"
						
						out_questions = [q1, q2]
		
		emit_signal("mini_test_ready", out_questions)
		check_and_fill_all_queues()
		if is_instance_valid(http): http.queue_free()
		if is_instance_valid(timer): timer.queue_free()
	)
	
	timer.timeout.connect(func():
		if _completed[0]: return
		_completed[0] = true
		emit_signal("mini_test_ready", [])
		check_and_fill_all_queues()
		if is_instance_valid(http):
			http.cancel_request()
			http.queue_free()
		if is_instance_valid(timer): timer.queue_free()
	)
	timer.start()
	
	var err = http.request(ollama_url, ["Content-Type: application/json"],
				 HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_completed[0] = true
		emit_signal("mini_test_ready", [])
		if is_instance_valid(http): http.queue_free()
		if is_instance_valid(timer): timer.queue_free()


# ==============================================================================
# API CÔNG KHAI
# ==============================================================================

func get_question() -> Dictionary:
	var queue: Array = question_queues[current_tier_id]
	check_and_fill_all_queues()

	if not queue.is_empty():
		var q: Dictionary = queue.pop_front()
		_debug_log("[AIManager] Phát câu | tier %d | word_id=%d | Queue còn: %d" \
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
	_debug_log("[AIManager] Chuyển sang tier %d | Queue: %d câu" \
		% [tier_id, question_queues[tier_id].size()])
	check_and_fill_all_queues()


func get_queue_size(tier_id: int = -1) -> int:
	var t: int = tier_id if tier_id != -1 else current_tier_id
	return question_queues[t].size() if question_queues.has(t) else 0
