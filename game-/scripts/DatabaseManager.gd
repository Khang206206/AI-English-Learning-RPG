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
const ENEMIES_CSV_PATH: String = "enemies.csv"
const GRAMMAR_CSV_PATH: String = "grammar.csv"
const CURRENT_SAVE_SLOT: int = 1

var player_hearts: int = 20
var max_hearts: int = 20
var player_gold: int = 100
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
			hp                  INTEGER DEFAULT 20,
			gold                INTEGER DEFAULT 100,
			current_biome       TEXT    DEFAULT 'Beginner Forest',
			pos_x               REAL    DEFAULT 0.0,
			pos_y               REAL    DEFAULT 0.0,
			dead_enemies_list   TEXT    DEFAULT '[]'
		);
	""")

	db.query_with_bindings(
		"INSERT OR IGNORE INTO Player_Profile (save_id, hp, gold, current_biome) VALUES (?, ?, ?, ?);",
		[CURRENT_SAVE_SLOT, max_hearts, player_gold, current_biome]
	)

	db.query("""
		CREATE TABLE IF NOT EXISTS Enemy_Tier_Dict (
			tier_id           INTEGER PRIMARY KEY,
			enemy_type        TEXT    NOT NULL,
			required_level    INTEGER DEFAULT 1,
			hp                INTEGER DEFAULT 5,
			vocabulary_theme  TEXT    DEFAULT 'General English'
		);
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS Vocabulary_Bank (
			word_id     INTEGER PRIMARY KEY AUTOINCREMENT,
			word        TEXT    NOT NULL UNIQUE,
			meaning     TEXT    NOT NULL,
			tier_id     INTEGER,
			FOREIGN KEY (tier_id) REFERENCES Enemy_Tier_Dict(tier_id)
		);
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS Player_Vocab_Mastery (
			save_id             INTEGER NOT NULL,
			word_id             INTEGER NOT NULL,
			encounter_count     INTEGER DEFAULT 0,
			correct_count       INTEGER DEFAULT 0,
			streak              INTEGER DEFAULT 0,
			ease_factor         REAL    DEFAULT 2.5,
			interval_days       INTEGER DEFAULT 1,
			next_review_date    TEXT    DEFAULT '',
			last_reviewed_date  TEXT    DEFAULT '',
			PRIMARY KEY (save_id, word_id),
			FOREIGN KEY (save_id)  REFERENCES Player_Profile(save_id),
			FOREIGN KEY (word_id)  REFERENCES Vocabulary_Bank(word_id)
		);
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS Grammar_Bank (
			grammar_id      INTEGER PRIMARY KEY AUTOINCREMENT,
			topic_name      TEXT    NOT NULL UNIQUE,
			formula         TEXT    NOT NULL,
			explanation_vi  TEXT    NOT NULL,
			example_en      TEXT    DEFAULT '',
			tier_id         INTEGER DEFAULT 1,
			FOREIGN KEY (tier_id) REFERENCES Enemy_Tier_Dict(tier_id)
		);
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS Item_Dict (
			item_id         INTEGER PRIMARY KEY,
			name            TEXT    NOT NULL,
			description     TEXT    DEFAULT '',
			item_type       TEXT    NOT NULL,
			effect_value    REAL    DEFAULT 0,
			price           INTEGER DEFAULT 0
		);
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS Player_Inventory (
			save_id         INTEGER NOT NULL,
			item_id         INTEGER NOT NULL,
			quantity        INTEGER DEFAULT 0,
			PRIMARY KEY (save_id, item_id),
			FOREIGN KEY (save_id) REFERENCES Player_Profile(save_id),
			FOREIGN KEY (item_id) REFERENCES Item_Dict(item_id)
		);
	""")

	db.query("""
		CREATE TABLE IF NOT EXISTS Player_Grammar_Mastery (
			save_id             INTEGER NOT NULL,
			grammar_id          INTEGER NOT NULL,
			encounter_count     INTEGER DEFAULT 0,
			correct_count       INTEGER DEFAULT 0,
			PRIMARY KEY (save_id, grammar_id),
			FOREIGN KEY (save_id) REFERENCES Player_Profile(save_id),
			FOREIGN KEY (grammar_id) REFERENCES Grammar_Bank(grammar_id)
		);
	""")

	print("[DatabaseManager] Cấu trúc tất cả các bảng đã sẵn sàng.")

# ==============================================================================
# 2. SEED DỮ LIỆU BAN ĐẦU
# ==============================================================================

func seed_initial_data() -> void:
	_seed_enemies()
	_seed_from_csv()
	_seed_vocabulary_fallback()
	_seed_grammar()
	_seed_items()

func _seed_enemies() -> void:
	db.query("SELECT COUNT(*) as total FROM Enemy_Tier_Dict;")
	if not db.query_result.is_empty() and db.query_result[0]["total"] > 0:
		return

	if not FileAccess.file_exists(ENEMIES_CSV_PATH):
		push_warning("[DatabaseManager] Không tìm thấy '%s'. Bỏ qua." % ENEMIES_CSV_PATH)
		return

	var file = FileAccess.open(ENEMIES_CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("[DatabaseManager] Không thể mở file CSV: %s" % ENEMIES_CSV_PATH)
		return

	print("[DatabaseManager] Nạp dữ liệu quái vật từ CSV...")
	var imported_count: int = 0
	var is_first_line: bool = true

	while not file.eof_reached():
		var parts = file.get_csv_line()
		if is_first_line:
			is_first_line = false
			continue
			
		if parts.size() < 5 or parts[0].strip_edges() == "":
			continue

		var tier_id = parts[0].strip_edges().to_int()
		var enemy_type = parts[1].strip_edges()
		var req_level = parts[2].strip_edges().to_int()
		var hp = parts[3].strip_edges().to_int()
		var vocab_theme = parts[4].strip_edges()

		db.query_with_bindings(
			"INSERT OR IGNORE INTO Enemy_Tier_Dict (tier_id, enemy_type, required_level, hp, vocabulary_theme) VALUES (?, ?, ?, ?, ?);",
			[tier_id, enemy_type, req_level, hp, vocab_theme]
		)
		imported_count += 1

	file.close()
	print("[DatabaseManager] Đã nạp %d quái vật từ CSV." % imported_count)

func _seed_grammar() -> void:
	db.query("SELECT COUNT(*) as total FROM Grammar_Bank;")
	if not db.query_result.is_empty() and db.query_result[0]["total"] > 0:
		return

	if not FileAccess.file_exists(GRAMMAR_CSV_PATH):
		push_warning("[DatabaseManager] Không tìm thấy '%s'. Bỏ qua." % GRAMMAR_CSV_PATH)
		return

	var file = FileAccess.open(GRAMMAR_CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("[DatabaseManager] Không thể mở file CSV: %s" % GRAMMAR_CSV_PATH)
		return

	print("[DatabaseManager] Nạp chủ điểm ngữ pháp từ CSV...")
	var imported_count: int = 0
	var is_first_line: bool = true

	while not file.eof_reached():
		var parts = file.get_csv_line()
		if is_first_line:
			is_first_line = false
			continue
			
		if parts.size() < 5 or parts[0].strip_edges() == "":
			continue

		var topic_name = parts[0].strip_edges()
		var formula = parts[1].strip_edges()
		var explanation = parts[2].strip_edges()
		var example = parts[3].strip_edges()
		var tier_id = parts[4].strip_edges().to_int()

		db.query_with_bindings(
			"INSERT OR IGNORE INTO Grammar_Bank (topic_name, formula, explanation_vi, example_en, tier_id) VALUES (?, ?, ?, ?, ?);", 
			[topic_name, formula, explanation, example, tier_id]
		)
		imported_count += 1

	file.close()
	print("[DatabaseManager] Đã nạp %d chủ điểm ngữ pháp từ CSV." % imported_count)

func _seed_items() -> void:
	db.query("SELECT COUNT(*) as total FROM Item_Dict;")
	if not db.query_result.is_empty() and db.query_result[0]["total"] > 0:
		return
	print("[DatabaseManager] Nạp vật phẩm ban đầu...")
	var items = [
		[1, "Tinh Dược Sinh Lực",     "Hồi 1 máu cho người chơi.",     "potion",      1.0, 15],
		[2, "Lá Bài Tiên Tri",   "Dùng cho câu 4 đáp án, loại bỏ 2 đáp án sai.",          "fifty_fifty", 2.0, 30],
		[3, "Cuộn Giấy Không Gian",  "Bỏ qua câu hỏi hiện tại, không mất máu.",     "skip",        1.0, 25],
		[4, "Băng Phong Thời Gian",    "Dừng thời gian (timer) của câu hỏi đó lại.",   "time_freeze", 1.0, 40],
		[5, "Hỏa Cầu",      "Gây 5 sát thương. Bị phản công mất 5 HP.",       "spell",       0.0, 60],
		[6, "Băng Tiễn",    "Gây 4 sát thương. 50% đóng băng quái 1 lượt.",    "spell",       0.0, 60],
		[7, "Sét Đánh",     "Gây 4 sát thương. 75% tăng thời gian 1.5x.",      "spell",       0.0, 60],
		[8, "Gỗ Xưa",       "Gây 4 sát thương. Hồi 1 HP cho người chơi.",      "spell",       0.0, 60],
	]
	for it in items:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Item_Dict (item_id, name, description, item_type, effect_value, price) VALUES (?, ?, ?, ?, ?, ?);", it)
	
	for item_id in [1, 2, 3, 4]:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Player_Inventory (save_id, item_id, quantity) VALUES (?, ?, 2);",
			[CURRENT_SAVE_SLOT, item_id])
	print("[DatabaseManager] Đã nạp %d vật phẩm + starter kit." % items.size())

# ==============================================================================
# 3. IMPORT TỪ VỰNG TỪ CSV
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

		if parts.size() < 3:
			push_warning("[DatabaseManager] CSV dòng %d sai định dạng, bỏ qua: '%s'" % [line_number, raw_line])
			skipped_count += 1
			continue

		var word       = parts[0].strip_edges()
		var tier_str   = parts[parts.size() - 1].strip_edges()
		var meaning    = ",".join(parts.slice(1, parts.size() - 1)).strip_edges()

		if not tier_str.is_valid_int():
			push_warning("[DatabaseManager] CSV dòng %d: tier_id '%s' không hợp lệ, bỏ qua." % [line_number, tier_str])
			skipped_count += 1
			continue

		db.query_with_bindings(
			"INSERT OR IGNORE INTO Vocabulary_Bank (word, meaning, tier_id) VALUES (?, ?, ?);",
			[word, meaning, tier_str.to_int()]
		)
		imported_count += 1

	file.close()
	print("[DatabaseManager] CSV: Nạp %d từ thành công, bỏ qua %d dòng lỗi." % [imported_count, skipped_count])

func _seed_vocabulary_fallback() -> void:
	db.query("SELECT COUNT(*) as total FROM Vocabulary_Bank;")
	if not db.query_result.is_empty() and db.query_result[0]["total"] > 0:
		return

	push_warning("[DatabaseManager] Vocabulary_Bank trống! Dùng bộ từ dự phòng tối thiểu.")
	var fallback = [
		["Timber",      "Gỗ rừng / Cây lấy gỗ",  1],
		["Canopy",      "Vòm lá / Tán cây rừng", 1],
		["Flora",       "Hệ thực vật",           1],
		["Predator",    "Động vật săn mồi",      2],
		["Camouflage",  "Ngụy trang / Ẩn mình",  2],
		["Biodiversity","Đa dạng sinh học",      2],
	]
	for v in fallback:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Vocabulary_Bank (word, meaning, tier_id) VALUES (?, ?, ?);",
			v
		)
	print("[DatabaseManager] Đã nạp %d từ dự phòng." % fallback.size())

# ==============================================================================
# 4. GOLD API
# ==============================================================================

func get_gold() -> int:
	return player_gold

func add_gold(amount: int) -> void:
	player_gold += amount
	db.query_with_bindings(
		"UPDATE Player_Profile SET gold = ? WHERE save_id = ?;",
		[player_gold, CURRENT_SAVE_SLOT])

func spend_gold(amount: int) -> bool:
	if player_gold < amount:
		return false
	player_gold -= amount
	db.query_with_bindings(
		"UPDATE Player_Profile SET gold = ? WHERE save_id = ?;",
		[player_gold, CURRENT_SAVE_SLOT])
	return true

# ==============================================================================
# 5. SAVE / LOAD TIẾN TRÌNH
# ==============================================================================

func save_game(pos_x: float, pos_y: float) -> void:
	var serialized_enemies: String = JSON.stringify(dead_enemies)
	var timestamp: String          = Time.get_datetime_string_from_system()

	db.query_with_bindings(
		"""UPDATE Player_Profile
		SET last_played       = ?,
		    hp                = ?,
		    gold              = ?,
		    current_biome     = ?,
		    pos_x             = ?,
		    pos_y             = ?,
		    dead_enemies_list = ?
		WHERE save_id = ?;""",
		[timestamp, player_hearts, player_gold, current_biome, pos_x, pos_y, serialized_enemies, CURRENT_SAVE_SLOT]
	)

	print("[DatabaseManager] Game đã lưu lúc %s | HP: %d | Vị trí: (%.1f, %.1f) | Gold: %d" \
		% [timestamp, player_hearts, pos_x, pos_y, player_gold])
	emit_signal("game_saved")

func load_game(save_slot: int) -> void:
	db.query_with_bindings(
		"SELECT * FROM Player_Profile WHERE save_id = ?;",
		[save_slot]
	)

	if not db.query_result.is_empty():
		var data: Dictionary = db.query_result[0]

		player_hearts = data.get("hp",            max_hearts)
		player_gold   = data.get("gold",          100)
		current_biome = data.get("current_biome", "Beginner Forest")

		var raw_enemies: String = data.get("dead_enemies_list", "[]")
		var json_parser         = JSON.new()
		if json_parser.parse(raw_enemies) == OK and json_parser.get_data() is Array:
			dead_enemies = json_parser.get_data()
		else:
			push_warning("[DatabaseManager] Không parse được dead_enemies_list, reset về [].")
			dead_enemies = []

		print("[DatabaseManager] Tải game thành công! HP: %d/%d | Quái đã diệt: %d con | Gold: %d" \
			% [player_hearts, max_hearts, dead_enemies.size(), player_gold])

		emit_signal("hp_changed", player_hearts)
		emit_signal("game_loaded", data)
	else:
		player_hearts = max_hearts
		player_gold = 100
		dead_enemies  = []
		print("[DatabaseManager] Không tìm thấy Save Slot %d — bắt đầu hành trình mới!" % save_slot)
		emit_signal("hp_changed", player_hearts)

# ==============================================================================
# 6. TIỆN ÍCH BỔ SUNG
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

# ==============================================================================
# 7. TÍNH NĂNG NOTEBOOK
# ==============================================================================

func search_encountered_vocab(search_text: String = "", filter_tier: int = 0, status_filter: String = "All") -> Array:
	# Cập nhật query bỏ cefr_level
	var sql = """
		SELECT 
			v.word, v.meaning, v.tier_id,
			COALESCE(m.encounter_count, 0) AS encounter_count, 
			COALESCE(m.correct_count, 0) AS correct_count,
			COALESCE(CAST(m.correct_count AS REAL) / NULLIF(m.encounter_count, 0), 0.0) AS mastery_score
		FROM Vocabulary_Bank v
		JOIN Player_Vocab_Mastery m ON v.word_id = m.word_id
		WHERE m.save_id = ? AND m.encounter_count > 0
	"""
	var bindings = [CURRENT_SAVE_SLOT]
	
	if search_text.strip_edges() != "":
		sql += " AND v.word LIKE ?"
		bindings.append("%" + search_text.strip_edges() + "%")
		
	if filter_tier > 0:
		sql += " AND v.tier_id = ?"
		bindings.append(filter_tier)
		
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
