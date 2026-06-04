extends Node

# ==============================================================================
# DatabaseManager.gd — AutoLoad Singleton
# Mô tả: Single Source of Truth — toàn bộ dữ liệu game đi qua file data.db
# Kho từ vựng được nạp từ vocabulary.csv đặt cùng cấp với data.db
# ==============================================================================

signal hp_changed(new_hp: int)
signal game_over_triggered()
signal game_saved()
signal game_loaded(data: Dictionary)

var db = null
const DB_PATH: String = "data.db"
const CSV_PATH: String = "vocabulary.csv"
const CURRENT_SAVE_SLOT: int = 1

var player_hearts: int = 5
var max_hearts: int = 5
var current_biome: String = "Beginner Forest"
var dead_enemies: Array = []

# ==============================================================================
# VÒNG ĐỜI NODE
# ==============================================================================

func _ready() -> void:
	print("[DatabaseManager] ===== Khởi động hệ thống dữ liệu =====")
	init_database()
	load_game(CURRENT_SAVE_SLOT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if db != null:
			db.close_db()
			print("[DatabaseManager] Đã đóng kết nối database an toàn.")

# ==============================================================================
# 1. KHỞI TẠO CƠ SỞ DỮ LIỆU
# ==============================================================================

func init_database() -> void:
	db = ClassDB.instantiate("SQLite")
	db.path = DB_PATH

	if not db.open_db():
		push_error("[DatabaseManager] NGHIÊM TRỌNG: Không thể mở file database tại: " + DB_PATH)
		return

	print("[DatabaseManager] Kết nối database thành công.")
	db.query("PRAGMA synchronous = NORMAL;")
	db.query("PRAGMA journal_mode = WAL;")
	db.query("PRAGMA foreign_keys = ON;")

	_create_tables()
	seed_initial_data()

func _create_tables() -> void:
	db.query("""
		CREATE TABLE IF NOT EXISTS Player_Profile (
			save_id             INTEGER PRIMARY KEY,
			last_played         TEXT,
			hp                  INTEGER DEFAULT 5,
			current_biome       TEXT    DEFAULT 'Beginner Forest',
			pos_x               REAL    DEFAULT 0.0,
			pos_y               REAL    DEFAULT 0.0,
			dead_enemies_list   TEXT    DEFAULT '[]'
		);
	""")

	db.query_with_bindings(
		"INSERT OR IGNORE INTO Player_Profile (save_id, hp, current_biome) VALUES (?, ?, ?);",
		[CURRENT_SAVE_SLOT, max_hearts, current_biome]
	)

	db.query("""
		CREATE TABLE IF NOT EXISTS Enemy_Tier_Dict (
			tier_id         INTEGER PRIMARY KEY,
			enemy_type      TEXT    NOT NULL,
			required_level  INTEGER DEFAULT 1
		);
	""")

	# UNIQUE trên cột word: đảm bảo INSERT OR IGNORE hoạt động đúng
	# khi seed_initial_data() bị gọi nhiều lần — không bao giờ bị từ trùng
	db.query("""
		CREATE TABLE IF NOT EXISTS Vocabulary_Bank (
			word_id     INTEGER PRIMARY KEY AUTOINCREMENT,
			word        TEXT    NOT NULL UNIQUE,
			meaning     TEXT    NOT NULL,
			tier_id     INTEGER,
			cefr_level  TEXT    DEFAULT 'A1',
			FOREIGN KEY (tier_id) REFERENCES Enemy_Tier_Dict(tier_id)
		);
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS Player_Vocab_Mastery (
			save_id         INTEGER NOT NULL,
			word_id         INTEGER NOT NULL,
			encounter_count INTEGER DEFAULT 0,
			correct_count   INTEGER DEFAULT 0,
			PRIMARY KEY (save_id, word_id),
			FOREIGN KEY (save_id)  REFERENCES Player_Profile(save_id),
			FOREIGN KEY (word_id)  REFERENCES Vocabulary_Bank(word_id)
		);
	""")

	print("[DatabaseManager] Cấu trúc 4 bảng đã sẵn sàng.")

# ==============================================================================
# 2. SEED DỮ LIỆU BAN ĐẦU
# ==============================================================================

func seed_initial_data() -> void:
	_seed_enemies()
	_seed_from_csv()
	_seed_vocabulary_fallback()

func _seed_enemies() -> void:
	db.query("SELECT COUNT(*) as total FROM Enemy_Tier_Dict;")
	if db.query_result.is_empty() or db.query_result[0]["total"] > 0:
		return

	print("[DatabaseManager] Nạp dữ liệu quái vật ban đầu...")
	var enemies = [
		[1, "Slime",       1],
		[2, "Goblin",      2],
		[3, "Dragon_Boss", 3],
	]
	for e in enemies:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Enemy_Tier_Dict (tier_id, enemy_type, required_level) VALUES (?, ?, ?);",
			e
		)

# ==============================================================================
# 3. IMPORT TỪ VỰNG TỪ CSV
#
# Định dạng file vocabulary.csv (đặt cùng cấp với data.db):
#   word,meaning,tier_id          ← dòng header bắt buộc
#   Timber,Gỗ rừng / Cây lấy gỗ,1
#   Biodiversity,Đa dạng sinh học,2
#
# Quy tắc parser:
#   - Bỏ qua dòng 1 (header) và dòng trống
#   - Cột meaning được ghép lại nếu có dấu phẩy bên trong
#   - INSERT OR IGNORE → chạy nhiều lần không sinh từ trùng
#   - Nếu không tìm thấy CSV → in warning rồi thoát, fallback xử lý tiếp
# ==============================================================================

func _seed_from_csv() -> void:
	if not FileAccess.file_exists(CSV_PATH):
		push_warning("[DatabaseManager] Không tìm thấy '%s'. Bỏ qua bước nạp CSV." % CSV_PATH)
		return

	var file = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("[DatabaseManager] Không thể mở file CSV: %s" % CSV_PATH)
		return

	var imported_count: int = 0
	var skipped_count: int  = 0
	var line_number: int    = 0

	while not file.eof_reached():
		var raw_line = file.get_line().strip_edges()
		line_number += 1

		if line_number == 1 or raw_line == "":
			continue

		var parts = raw_line.split(",")

		if parts.size() < 4:
			push_warning("[DatabaseManager] CSV dòng %d sai định dạng, bỏ qua: '%s'" % [line_number, raw_line])
			skipped_count += 1
			continue

		var word       = parts[0].strip_edges()
		var cefr_level = parts[parts.size() - 1].strip_edges()
		var tier_str   = parts[parts.size() - 2].strip_edges()
		var meaning    = ",".join(parts.slice(1, parts.size() - 2)).strip_edges()

		if not tier_str.is_valid_int():
			push_warning("[DatabaseManager] CSV dòng %d: tier_id '%s' không hợp lệ, bỏ qua." % [line_number, tier_str])
			skipped_count += 1
			continue

		db.query_with_bindings(
			"INSERT OR IGNORE INTO Vocabulary_Bank (word, meaning, tier_id, cefr_level) VALUES (?, ?, ?, ?);",
			[word, meaning, tier_str.to_int(), cefr_level]
		)
		imported_count += 1

	file.close()
	print("[DatabaseManager] CSV: Nạp %d từ thành công, bỏ qua %d dòng lỗi." % [imported_count, skipped_count])

# Chạy chỉ khi CSV bị thiếu VÀ Vocabulary_Bank vẫn trống
# Đảm bảo game không crash trong mọi tình huống
func _seed_vocabulary_fallback() -> void:
	db.query("SELECT COUNT(*) as total FROM Vocabulary_Bank;")
	if not db.query_result.is_empty() and db.query_result[0]["total"] > 0:
		return

	push_warning("[DatabaseManager] Vocabulary_Bank trống! Dùng bộ từ dự phòng tối thiểu.")
	var fallback = [
		["Timber",      "Gỗ rừng / Cây lấy gỗ",  1, "B1"],
		["Canopy",      "Vòm lá / Tán cây rừng", 1, "B2"],
		["Flora",       "Hệ thực vật",           1, "C1"],
		["Predator",    "Động vật săn mồi",      2, "B2"],
		["Camouflage",  "Ngụy trang / Ẩn mình",  2, "C1"],
		["Biodiversity","Đa dạng sinh học",      2, "C1"],
	]
	for v in fallback:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Vocabulary_Bank (word, meaning, tier_id, cefr_level) VALUES (?, ?, ?, ?);",
			v
		)
	print("[DatabaseManager] Đã nạp %d từ dự phòng." % fallback.size())

# ==============================================================================
# 4. THUẬT TOÁN DDA — LẤY TỪ VỰNG YẾU NHẤT
# ==============================================================================

func get_weakest_vocab(tier_id: int, pool_size: int = 15) -> Dictionary:
	# JOIN thêm Enemy_Tier_Dict để trả về enemy_type cùng với vocab
	# AIManager dùng enemy_type này để nhét vào prompt (Context-Aware Thematic)
	var sql = """
		SELECT
			v.word_id,
			v.word,
			v.meaning,
			v.tier_id,
			e.enemy_type,
			COALESCE(
				CAST(m.correct_count AS REAL) / (m.encounter_count + 1),
				0.0
			) AS mastery_score,
			COALESCE(m.encounter_count, 0) AS encounter_count,
			COALESCE(m.correct_count,   0) AS correct_count
		FROM Vocabulary_Bank v
		LEFT JOIN Player_Vocab_Mastery m
			ON  v.word_id = m.word_id
			AND m.save_id = ?
		LEFT JOIN Enemy_Tier_Dict e
			ON  v.tier_id = e.tier_id
		WHERE v.tier_id = ?
		ORDER BY mastery_score ASC, RANDOM()
		LIMIT ?;
	"""
	db.query_with_bindings(sql, [CURRENT_SAVE_SLOT, tier_id, pool_size])

	if db.query_result.is_empty():
		push_warning("[DatabaseManager] Không tìm thấy từ vựng cho tier_id = %d" % tier_id)
		return {}

	var weak_pool: Array = db.query_result.duplicate()
	var chosen: Dictionary = weak_pool[randi() % weak_pool.size()]

	print("[DatabaseManager] Pool %d từ (tier %d) → Chọn: '%s' (mastery: %.2f)" \
		% [weak_pool.size(), tier_id, chosen["word"], chosen["mastery_score"]])

	return chosen

# ==============================================================================
# 5. CẬP NHẬT SAU COMBAT
# ==============================================================================

func update_after_combat(word_id: int, is_correct: bool) -> void:
	if word_id == -1:
		if not is_correct:
			player_hearts = max(0, player_hearts - 1)
			emit_signal("hp_changed", player_hearts)
			if player_hearts <= 0:
				emit_signal("game_over_triggered")
		return

	if not is_correct:
		player_hearts = max(0, player_hearts - 1)
		print("[DatabaseManager] Sai rồi! HP còn lại: %d/%d" % [player_hearts, max_hearts])

	emit_signal("hp_changed", player_hearts)

	db.query_with_bindings(
		"SELECT encounter_count FROM Player_Vocab_Mastery WHERE save_id = ? AND word_id = ?;",
		[CURRENT_SAVE_SLOT, word_id]
	)

	var correct_delta: int = 1 if is_correct else 0

	if db.query_result.is_empty():
		db.query_with_bindings(
			"""INSERT INTO Player_Vocab_Mastery
				(save_id, word_id, encounter_count, correct_count)
			VALUES (?, ?, 1, ?);""",
			[CURRENT_SAVE_SLOT, word_id, correct_delta]
		)
	else:
		db.query_with_bindings(
			"""UPDATE Player_Vocab_Mastery
			SET encounter_count = encounter_count + 1,
			    correct_count   = correct_count   + ?
			WHERE save_id = ? AND word_id = ?;""",
			[correct_delta, CURRENT_SAVE_SLOT, word_id]
		)

	db.query_with_bindings(
		"UPDATE Player_Profile SET hp = ? WHERE save_id = ?;",
		[player_hearts, CURRENT_SAVE_SLOT]
	)

	if player_hearts <= 0:
		print("[DatabaseManager] *** GAME OVER *** Người chơi đã hết mạng!")
		emit_signal("game_over_triggered")

# ==============================================================================
# 6. SAVE / LOAD TIẾN TRÌNH
# ==============================================================================

func save_game(pos_x: float, pos_y: float) -> void:
	var serialized_enemies: String = JSON.stringify(dead_enemies)
	var timestamp: String          = Time.get_datetime_string_from_system()

	db.query_with_bindings(
		"""UPDATE Player_Profile
		SET last_played       = ?,
		    hp                = ?,
		    current_biome     = ?,
		    pos_x             = ?,
		    pos_y             = ?,
		    dead_enemies_list = ?
		WHERE save_id = ?;""",
		[timestamp, player_hearts, current_biome, pos_x, pos_y, serialized_enemies, CURRENT_SAVE_SLOT]
	)

	print("[DatabaseManager] Game đã lưu lúc %s | HP: %d | Vị trí: (%.1f, %.1f)" \
		% [timestamp, player_hearts, pos_x, pos_y])
	emit_signal("game_saved")

func load_game(save_slot: int) -> void:
	db.query_with_bindings(
		"SELECT * FROM Player_Profile WHERE save_id = ?;",
		[save_slot]
	)

	if not db.query_result.is_empty():
		var data: Dictionary = db.query_result[0]

		player_hearts = data.get("hp",            max_hearts)
		current_biome = data.get("current_biome", "Beginner Forest")

		var raw_enemies: String = data.get("dead_enemies_list", "[]")
		var json_parser         = JSON.new()
		if json_parser.parse(raw_enemies) == OK and json_parser.get_data() is Array:
			dead_enemies = json_parser.get_data()
		else:
			push_warning("[DatabaseManager] Không parse được dead_enemies_list, reset về [].")
			dead_enemies = []

		print("[DatabaseManager] Tải game thành công! HP: %d/%d | Quái đã diệt: %d con" \
			% [player_hearts, max_hearts, dead_enemies.size()])

		emit_signal("hp_changed", player_hearts)
		emit_signal("game_loaded", data)
	else:
		player_hearts = max_hearts
		dead_enemies  = []
		print("[DatabaseManager] Không tìm thấy Save Slot %d — bắt đầu hành trình mới!" % save_slot)
		emit_signal("hp_changed", player_hearts)

# ==============================================================================
# 7. TIỆN ÍCH BỔ SUNG
# ==============================================================================

func mark_enemy_dead(enemy_id: int) -> void:
	if enemy_id not in dead_enemies:
		dead_enemies.append(enemy_id)

func is_enemy_dead(enemy_id: int) -> bool:
	return enemy_id in dead_enemies

func restore_full_hp() -> void:
	player_hearts = max_hearts
	db.query_with_bindings(
		"UPDATE Player_Profile SET hp = ? WHERE save_id = ?;",
		[player_hearts, CURRENT_SAVE_SLOT]
	)
	emit_signal("hp_changed", player_hearts)
	print("[DatabaseManager] HP đã phục hồi đầy: %d/%d" % [player_hearts, max_hearts])

## Trả về mastery trung bình (0.0 → 1.0) của toàn bộ từ trong một tier.
## AIManager dùng giá trị này để quyết định:
##   < 0.4  → người chơi còn yếu → sinh MCQ dễ, câu hỏi nhận diện nghĩa cơ bản
##   0.4-0.6 → trung bình → MCQ khó hơn (đồng/trái nghĩa, điền vào chỗ trống)
##   >= 0.6 → đã quen từ đủ → kích hoạt Reading Passage thay cho MCQ thuần túy
func get_tier_avg_mastery(tier_id: int) -> float:
	db.query_with_bindings("""
		SELECT
			AVG(
				COALESCE(
					CAST(m.correct_count AS REAL) / (m.encounter_count + 1),
					0.0
				)
			) AS avg_mastery
		FROM Vocabulary_Bank v
		LEFT JOIN Player_Vocab_Mastery m
			ON v.word_id = m.word_id AND m.save_id = ?
		WHERE v.tier_id = ?;
	""", [CURRENT_SAVE_SLOT, tier_id])

	if db.query_result.is_empty() or db.query_result[0]["avg_mastery"] == null:
		return 0.0

	return float(db.query_result[0]["avg_mastery"])

func get_mastery_summary() -> Array:
	db.query_with_bindings(
		"""SELECT
			v.word, v.meaning, v.tier_id,
			COALESCE(m.encounter_count, 0) AS encounter_count,
			COALESCE(m.correct_count,   0) AS correct_count,
			COALESCE(
				ROUND(CAST(m.correct_count AS REAL) / (m.encounter_count + 1) * 100, 1),
				0.0
			) AS mastery_percent
		FROM Vocabulary_Bank v
		LEFT JOIN Player_Vocab_Mastery m
			ON v.word_id = m.word_id AND m.save_id = ?
		ORDER BY mastery_percent ASC, v.tier_id ASC;""",
		[CURRENT_SAVE_SLOT]
	)
	return db.query_result.duplicate()

# ==============================================================================
# 5.TÍNH NĂNG NOTEBOOK
# ==============================================================================

# --- HÀM TÌM KIẾM MVP ---
func search_encountered_vocab(search_text: String = "", filter_tier: int = 0, status_filter: String = "All") -> Array:
	var sql = """
		SELECT 
			v.word, v.meaning, v.tier_id, v.cefr_level,
			COALESCE(m.encounter_count, 0) AS encounter_count, 
			COALESCE(m.correct_count, 0) AS correct_count,
			COALESCE(CAST(m.correct_count AS REAL) / NULLIF(m.encounter_count, 0), 0.0) AS mastery_score
		FROM Vocabulary_Bank v
		JOIN Player_Vocab_Mastery m ON v.word_id = m.word_id
		WHERE m.save_id = ? AND m.encounter_count > 0
	"""
	var bindings = [CURRENT_SAVE_SLOT]
	
	# [x] Tìm kiếm từ (Real-time)
	if search_text.strip_edges() != "":
		sql += " AND v.word LIKE ?"
		bindings.append("%" + search_text.strip_edges() + "%")
		
	# [x] Bộ lọc đơn giản: Tier
	if filter_tier > 0:
		sql += " AND v.tier_id = ?"
		bindings.append(filter_tier)
		
	# [x] Bộ lọc đơn giản: Trạng thái (Mastery)
	if status_filter == "NeedPractice":
		sql += " AND (CAST(m.correct_count AS REAL) / NULLIF(m.encounter_count, 0)) < 0.8"
	elif status_filter == "Mastered":
		sql += " AND (CAST(m.correct_count AS REAL) / NULLIF(m.encounter_count, 0)) >= 0.8"

	sql += " ORDER BY v.word ASC;"
	db.query_with_bindings(sql, bindings)
	return db.query_result.duplicate()

func get_grammar_spells() -> Array:
	return [
		{
			"title": "PRESENT SIMPLE (Thì Hiện Tại Đơn)",
			"spell_name": "Bùa: Đóng băng Slime 🧊",
			"structure": "S + V(s/es)  ||  S + do/does + V_inf",
			"example": "The warrior fights dangerous monsters every day.",
			"progress": 80,
			"unlocked": true
		},
		{
			"title": "PRESENT CONTINUOUS (Thì Hiện Tại Tiếp Diễn)",
			"spell_name": "Bùa: Tốc Biến Trốn Chạy ⚡",
			"structure": "S + am/is/are + V_ing",
			"example": "The Goblin is stealing our forest timber right now!",
			"progress": 40,
			"unlocked": true
		},
		{
			"title": "PRESENT PERFECT (Thì Hiện Tại Hoàn Thành)",
			"spell_name": "Bùa: Triệu Hồi Cổ Thư 📜",
			"structure": "S + have/has + V_pii",
			"example": "You have explored the deep corners of Aelphurion library.",
			"progress": 0,
			"unlocked": false
		}
	]
	
