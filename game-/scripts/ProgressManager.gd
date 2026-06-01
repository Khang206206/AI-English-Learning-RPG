extends Node

# ==============================================================================
# ProgressManager.gd — AutoLoad Singleton
# Trách nhiệm: Quản lý tiến trình học tập, SRS (SM-2), mastery, inventory
# Phụ thuộc: DatabaseManager (truy cập db object và player state)
# PHẢI được đăng ký SAU DatabaseManager trong project.godot
# ==============================================================================

# ── Tiện ích truy cập DB (lazy proxy) ──
var db:
	get: return DatabaseManager.db


# ==============================================================================
# 1. THUẬT TOÁN DDA — LẤY TỪ VỰNG YẾU NHẤT
# (Chuyển từ DatabaseManager.get_weakest_vocab)
# ==============================================================================

## Lấy 1 từ yếu nhất (mastery thấp nhất) trong pool size từ của tier_id.
## AIManager gọi hàm này để chọn từ cho câu hỏi tiếp theo.
func get_weakest_vocab(tier_id: int, pool_size: int = 15) -> Dictionary:
	var save_id: int = DatabaseManager.CURRENT_SAVE_SLOT
	db.query_with_bindings("""
		SELECT
			v.word_id, v.word, v.meaning, v.tier_id, e.enemy_type,
			COALESCE(CAST(m.correct_count AS REAL) / (m.encounter_count + 1), 0.0) AS mastery_score,
			COALESCE(m.encounter_count, 0) AS encounter_count,
			COALESCE(m.correct_count, 0)   AS correct_count
		FROM Vocabulary_Bank v
		LEFT JOIN Player_Vocab_Mastery m ON v.word_id = m.word_id AND m.save_id = ?
		LEFT JOIN Enemy_Tier_Dict e      ON v.tier_id = e.tier_id
		WHERE v.tier_id = ?
		ORDER BY mastery_score ASC, RANDOM()
		LIMIT ?;
	""", [save_id, tier_id, pool_size])

	if db.query_result.is_empty():
		push_warning("[ProgressManager] Không tìm thấy từ vựng cho tier %d" % tier_id)
		return {}

	var pool: Array = db.query_result.duplicate()
	var chosen: Dictionary = pool[randi() % pool.size()]
	print("[ProgressManager] Pool %d từ (tier %d) → '%s' (mastery: %.2f)"
		% [pool.size(), tier_id, chosen["word"], chosen["mastery_score"]])
	return chosen


# ==============================================================================
# 2. CẬP NHẬT SAU TRẢ LỜI — TÍCH HỢP SM-2
# ==============================================================================

## Hàm chính: gọi sau mỗi câu hỏi trong trận đấu hoặc ôn tập.
## Tính toán SM-2, cập nhật mastery và HP trong cùng 1 lần gọi.
func update_after_answer(word_id: int, is_correct: bool) -> void:
	# ── Xử lý HP (ủy quyền cho DatabaseManager giữ state) ──
	if not is_correct:
		DatabaseManager.player_hearts = max(0, DatabaseManager.player_hearts - 1)
		print("[ProgressManager] Sai! HP: %d/%d"
			% [DatabaseManager.player_hearts, DatabaseManager.max_hearts])

	DatabaseManager.emit_signal("hp_changed", DatabaseManager.player_hearts)

	# ── Nếu word_id = -1 (emergency fallback) → chỉ xử lý HP ──
	if word_id == -1:
		_save_hp_and_check_gameover()
		return

	# ── Truy vấn bản ghi hiện tại ──
	var save_id: int = DatabaseManager.CURRENT_SAVE_SLOT
	db.query_with_bindings(
		"SELECT * FROM Player_Vocab_Mastery WHERE save_id = ? AND word_id = ?;",
		[save_id, word_id])

	var today: String      = Time.get_date_string_from_system()
	var correct_delta: int = 1 if is_correct else 0

	if db.query_result.is_empty():
		# ── Lần đầu gặp: INSERT ──
		var next_date: String = _add_days(today, 1)
		db.query_with_bindings("""
			INSERT INTO Player_Vocab_Mastery
				(save_id, word_id, encounter_count, correct_count,
				 streak, ease_factor, interval_days, next_review_date, last_reviewed_date)
			VALUES (?, ?, 1, ?, ?, 2.5, 1, ?, ?);""",
			[save_id, word_id, correct_delta,
			 (1 if is_correct else 0), next_date, today])
	else:
		# ── Đã gặp: cập nhật SM-2 ──
		var row: Dictionary   = db.query_result[0]
		var old_streak: int   = row.get("streak", 0)
		var old_ef: float     = row.get("ease_factor", 2.5)
		var old_interval: int = row.get("interval_days", 1)

		var new_streak: int
		var new_ef: float
		var new_interval: int

		if is_correct:
			new_streak = old_streak + 1
			new_ef     = max(1.3, old_ef + 0.1)
			match new_streak:
				1: new_interval = 1
				2: new_interval = 3
				_: new_interval = int(old_interval * new_ef)
		else:
			new_streak   = 0
			new_ef       = max(1.3, old_ef - 0.2)
			new_interval = 1

		var next_date: String = _add_days(today, new_interval)

		db.query_with_bindings("""
			UPDATE Player_Vocab_Mastery
			SET encounter_count    = encounter_count + 1,
			    correct_count      = correct_count + ?,
			    streak             = ?,
			    ease_factor        = ?,
			    interval_days      = ?,
			    next_review_date   = ?,
			    last_reviewed_date = ?
			WHERE save_id = ? AND word_id = ?;""",
			[correct_delta, new_streak, new_ef, new_interval, next_date, today,
			 save_id, word_id])

		print("[ProgressManager] SM-2: word=%d streak=%d interval=%d next=%s"
			% [word_id, new_streak, new_interval, next_date])

	_save_hp_and_check_gameover()


func _save_hp_and_check_gameover() -> void:
	db.query_with_bindings(
		"UPDATE Player_Profile SET hp = ? WHERE save_id = ?;",
		[DatabaseManager.player_hearts, DatabaseManager.CURRENT_SAVE_SLOT])
	if DatabaseManager.player_hearts <= 0:
		print("[ProgressManager] *** GAME OVER ***")
		DatabaseManager.emit_signal("game_over_triggered")


# ==============================================================================
# 3. MASTERY QUERIES (chuyển từ DatabaseManager)
# ==============================================================================

## Mastery trung bình (0.0–1.0) cho toàn bộ từ trong tier.
## AIManager dùng để quyết định độ khó và loại câu hỏi.
func get_tier_avg_mastery(tier_id: int) -> float:
	var save_id: int = DatabaseManager.CURRENT_SAVE_SLOT
	db.query_with_bindings("""
		SELECT AVG(COALESCE(
			CAST(m.correct_count AS REAL) / (m.encounter_count + 1), 0.0
		)) AS avg_mastery
		FROM Vocabulary_Bank v
		LEFT JOIN Player_Vocab_Mastery m ON v.word_id = m.word_id AND m.save_id = ?
		WHERE v.tier_id = ?;
	""", [save_id, tier_id])
	if db.query_result.is_empty() or db.query_result[0]["avg_mastery"] == null:
		return 0.0
	return float(db.query_result[0]["avg_mastery"])


## Tóm tắt toàn bộ tiến trình học (dùng cho màn hình Notebook/Stats).
func get_mastery_summary() -> Array:
	db.query_with_bindings("""
		SELECT v.word, v.meaning, v.tier_id,
			COALESCE(m.encounter_count, 0) AS encounter_count,
			COALESCE(m.correct_count, 0)   AS correct_count,
			COALESCE(m.streak, 0)          AS streak,
			COALESCE(m.next_review_date, '') AS next_review_date,
			COALESCE(ROUND(CAST(m.correct_count AS REAL) / (m.encounter_count + 1) * 100, 1), 0.0) AS mastery_percent
		FROM Vocabulary_Bank v
		LEFT JOIN Player_Vocab_Mastery m ON v.word_id = m.word_id AND m.save_id = ?
		ORDER BY mastery_percent ASC, v.tier_id ASC;
	""", [DatabaseManager.CURRENT_SAVE_SLOT])
	return db.query_result.duplicate()


# ==============================================================================
# 4. SRS — ÔN TẬP NGẮT QUÃNG
# ==============================================================================

## Trả về danh sách từ cần ôn hôm nay (next_review_date <= today).
func get_due_review_words(limit: int = 20) -> Array:
	var today: String = Time.get_date_string_from_system()
	db.query_with_bindings("""
		SELECT v.word_id, v.word, v.meaning, v.tier_id,
		       m.encounter_count, m.correct_count, m.streak,
		       m.ease_factor, m.interval_days, m.next_review_date,
		       COALESCE(CAST(m.correct_count AS REAL) / (m.encounter_count + 1), 0.0) AS mastery_score
		FROM Player_Vocab_Mastery m
		JOIN Vocabulary_Bank v ON v.word_id = m.word_id
		WHERE m.save_id = ? AND m.next_review_date <= ? AND m.next_review_date != ''
		ORDER BY m.next_review_date ASC, mastery_score ASC
		LIMIT ?;
	""", [DatabaseManager.CURRENT_SAVE_SLOT, today, limit])
	return db.query_result.duplicate()


## Đếm số từ cần ôn hôm nay (dùng cho badge UI).
func get_due_review_count() -> int:
	var today: String = Time.get_date_string_from_system()
	db.query_with_bindings("""
		SELECT COUNT(*) as total FROM Player_Vocab_Mastery
		WHERE save_id = ? AND next_review_date <= ? AND next_review_date != '';
	""", [DatabaseManager.CURRENT_SAVE_SLOT, today])
	if db.query_result.is_empty():
		return 0
	return db.query_result[0].get("total", 0)


# ==============================================================================
# 5. TÌM KIẾM TỪ VỰNG (cho Notebook)
# ==============================================================================

## Tìm từ theo keyword (tìm trên cả word lẫn meaning).
func search_vocab(keyword: String, limit: int = 30) -> Array:
	var pattern: String = "%" + keyword + "%"
	db.query_with_bindings("""
		SELECT v.word_id, v.word, v.meaning, v.tier_id,
		       COALESCE(m.encounter_count, 0) AS encounter_count,
		       COALESCE(m.correct_count, 0)   AS correct_count,
		       COALESCE(m.streak, 0)          AS streak,
		       COALESCE(m.next_review_date, '') AS next_review_date,
		       COALESCE(CAST(m.correct_count AS REAL) / (m.encounter_count + 1), 0.0) AS mastery_score
		FROM Vocabulary_Bank v
		LEFT JOIN Player_Vocab_Mastery m ON v.word_id = m.word_id AND m.save_id = ?
		WHERE v.word LIKE ? OR v.meaning LIKE ?
		ORDER BY v.tier_id ASC, v.word ASC
		LIMIT ?;
	""", [DatabaseManager.CURRENT_SAVE_SLOT, pattern, pattern, limit])
	return db.query_result.duplicate()


# ==============================================================================
# 6. INVENTORY (VẬT PHẨM)
# ==============================================================================

## Trả về danh sách vật phẩm trong túi đồ (quantity > 0).
func get_inventory() -> Array:
	db.query_with_bindings("""
		SELECT i.item_id, d.name, d.description, d.item_type, d.effect_value, i.quantity
		FROM Player_Inventory i
		JOIN Item_Dict d ON d.item_id = i.item_id
		WHERE i.save_id = ? AND i.quantity > 0
		ORDER BY d.item_type ASC;
	""", [DatabaseManager.CURRENT_SAVE_SLOT])
	return db.query_result.duplicate()


## Dùng 1 vật phẩm (giảm quantity). Trả về false nếu không đủ.
func consume_item(item_id: int) -> bool:
	var save_id: int = DatabaseManager.CURRENT_SAVE_SLOT
	db.query_with_bindings(
		"SELECT quantity FROM Player_Inventory WHERE save_id = ? AND item_id = ?;",
		[save_id, item_id])
	if db.query_result.is_empty() or db.query_result[0]["quantity"] <= 0:
		return false
	db.query_with_bindings(
		"UPDATE Player_Inventory SET quantity = quantity - 1 WHERE save_id = ? AND item_id = ?;",
		[save_id, item_id])
	return true


## Thêm vật phẩm vào túi đồ (reward sau trận, mua hàng, v.v.).
func add_item(item_id: int, qty: int = 1) -> void:
	var save_id: int = DatabaseManager.CURRENT_SAVE_SLOT
	db.query_with_bindings(
		"SELECT quantity FROM Player_Inventory WHERE save_id = ? AND item_id = ?;",
		[save_id, item_id])
	if db.query_result.is_empty():
		db.query_with_bindings(
			"INSERT INTO Player_Inventory (save_id, item_id, quantity) VALUES (?, ?, ?);",
			[save_id, item_id, qty])
	else:
		db.query_with_bindings(
			"UPDATE Player_Inventory SET quantity = quantity + ? WHERE save_id = ? AND item_id = ?;",
			[qty, save_id, item_id])


# ==============================================================================
# 7. NGỮ PHÁP
# ==============================================================================

## Trả về 1 chủ điểm ngữ pháp ngẫu nhiên theo tier (dùng cho grammar_mcq).
func get_random_grammar(tier_id: int) -> Dictionary:
	db.query_with_bindings(
		"SELECT * FROM Grammar_Bank WHERE tier_id = ? ORDER BY RANDOM() LIMIT 1;",
		[tier_id])
	if db.query_result.is_empty():
		return {}
	return db.query_result[0]


# ==============================================================================
# TIỆN ÍCH
# ==============================================================================

## Cộng N ngày vào chuỗi ISO date "YYYY-MM-DD".
func _add_days(date_str: String, days: int) -> String:
	var parts: PackedStringArray = date_str.split("-")
	if parts.size() < 3:
		return date_str
	var dt: Dictionary = {
		"year": parts[0].to_int(), "month": parts[1].to_int(), "day": parts[2].to_int(),
		"hour": 0, "minute": 0, "second": 0
	}
	var unix: int = Time.get_unix_time_from_datetime_dict(dt) + days * 86400
	var new_dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [new_dt["year"], new_dt["month"], new_dt["day"]]
