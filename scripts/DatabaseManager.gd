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
signal intro_quiz_state_changed(is_completed: bool)
signal enemy_progress_changed()
signal gold_changed(new_gold: int)

var db = null
const DB_PATH: String = "user://data.db"
const SEED_DB_PATH: String = "res://data/data.db"
const CSV_PATH: String = "res://data/vocabulary.csv"
const ENEMIES_CSV_PATH: String = "res://data/enemies.csv"
const GRAMMAR_CSV_PATH: String = "res://data/grammar.csv"
const CURRENT_SAVE_SLOT: int = 1

var player_hearts: int = 20
var max_hearts: int = 20
var player_gold: int = 0
var current_biome: String = "Beginner Forest"
var dead_enemies: Array = []
var interacted_enemies: Array = []
var has_save_data: bool = false
var intro_quiz_completed: bool = false

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
	_ensure_user_database()
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
	_migrate_vocabulary_cefr_column()
	_migrate_grammar_srs_columns()
	_migrate_interacted_enemies_column()
	_migrate_intro_quiz_completed_column()
	seed_initial_data()

func _ensure_user_database() -> void:
	if FileAccess.file_exists(DB_PATH):
		return
	if not FileAccess.file_exists(SEED_DB_PATH):
		print("[DatabaseManager] Không tìm thấy seed DB, sẽ tạo database mới tại: " + DB_PATH)
		return

	var source := FileAccess.open(SEED_DB_PATH, FileAccess.READ)
	if source == null:
		push_warning("[DatabaseManager] Không thể đọc seed DB: " + SEED_DB_PATH)
		return

	var target := FileAccess.open(DB_PATH, FileAccess.WRITE)
	if target == null:
		push_warning("[DatabaseManager] Không thể tạo user DB: " + DB_PATH)
		source.close()
		return

	target.store_buffer(source.get_buffer(source.get_length()))
	source.close()
	target.close()
	print("[DatabaseManager] Đã tạo user DB từ seed: " + DB_PATH)

func _create_tables() -> void:
	db.query("""
		CREATE TABLE IF NOT EXISTS Player_Profile (
			save_id             INTEGER PRIMARY KEY,
			last_played         TEXT,
			hp                  INTEGER DEFAULT 20,
			gold                INTEGER DEFAULT 0,
			current_biome       TEXT    DEFAULT 'Beginner Forest',
			pos_x               REAL    DEFAULT 0.0,
			pos_y               REAL    DEFAULT 0.0,
			dead_enemies_list   TEXT    DEFAULT '[]',
			interacted_enemies_list TEXT DEFAULT '[]',
			intro_quiz_completed INTEGER DEFAULT 0
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
			cefr_level  TEXT    DEFAULT 'A1',
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
			streak              INTEGER DEFAULT 0,
			ease_factor         REAL    DEFAULT 2.5,
			interval_days       INTEGER DEFAULT 1,
			next_review_date    TEXT    DEFAULT '',
			last_reviewed_date  TEXT    DEFAULT '',
			PRIMARY KEY (save_id, grammar_id),
			FOREIGN KEY (save_id) REFERENCES Player_Profile(save_id),
			FOREIGN KEY (grammar_id) REFERENCES Grammar_Bank(grammar_id)
		);
	""")

	print("[DatabaseManager] Cấu trúc tất cả các bảng đã sẵn sàng.")

## Migration an toàn: thêm các cột SRS vào bảng Player_Grammar_Mastery nếu chưa có
func _migrate_grammar_srs_columns() -> void:
	var cols_to_add := {
		"streak": "ALTER TABLE Player_Grammar_Mastery ADD COLUMN streak INTEGER DEFAULT 0",
		"ease_factor": "ALTER TABLE Player_Grammar_Mastery ADD COLUMN ease_factor REAL DEFAULT 2.5",
		"interval_days": "ALTER TABLE Player_Grammar_Mastery ADD COLUMN interval_days INTEGER DEFAULT 1",
		"next_review_date": "ALTER TABLE Player_Grammar_Mastery ADD COLUMN next_review_date TEXT DEFAULT ''",
		"last_reviewed_date": "ALTER TABLE Player_Grammar_Mastery ADD COLUMN last_reviewed_date TEXT DEFAULT ''",
	}
	for column_name in cols_to_add.keys():
		if not _table_has_column("Player_Grammar_Mastery", column_name):
			db.query(cols_to_add[column_name])
	print("[DatabaseManager] Migration grammar SRS columns: done.")

func _migrate_vocabulary_cefr_column() -> void:
	if not _table_has_column("Vocabulary_Bank", "cefr_level"):
		db.query("ALTER TABLE Vocabulary_Bank ADD COLUMN cefr_level TEXT DEFAULT 'A1'")
	print("[DatabaseManager] Migration vocabulary cefr_level column: done.")

func _migrate_interacted_enemies_column() -> void:
	if not _table_has_column("Player_Profile", "interacted_enemies_list"):
		db.query("ALTER TABLE Player_Profile ADD COLUMN interacted_enemies_list TEXT DEFAULT '[]'")
	print("[DatabaseManager] Migration interacted_enemies_list column: done.")

func _migrate_intro_quiz_completed_column() -> void:
	if not _table_has_column("Player_Profile", "intro_quiz_completed"):
		db.query("ALTER TABLE Player_Profile ADD COLUMN intro_quiz_completed INTEGER DEFAULT 0")
	print("[DatabaseManager] Migration intro_quiz_completed column: done.")

func _table_has_column(table_name: String, column_name: String) -> bool:
	db.query("PRAGMA table_info(%s);" % table_name)
	for row in db.query_result:
		if str(row.get("name", "")) == column_name:
			return true
	return false

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
			"""INSERT INTO Enemy_Tier_Dict (tier_id, enemy_type, required_level, hp, vocabulary_theme)
			VALUES (?, ?, ?, ?, ?)
			ON CONFLICT(tier_id) DO UPDATE SET
			    enemy_type = excluded.enemy_type,
			    required_level = excluded.required_level,
			    hp = excluded.hp,
				vocabulary_theme = excluded.vocabulary_theme;""",
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
	print("[DatabaseManager] Nạp vật phẩm ban đầu...")
	var items = [
		[1, "Tinh Dược Sinh Lực", "Hồi ngay 4 HP cho người chơi trong chiến đấu. Không vượt quá giới hạn máu tối đa.", "potion", 4.0, 15],
		[2, "Lá Bài Tiên Tri", "Với câu trắc nghiệm, ẩn 2 đáp án sai. Với câu nhập chữ, hé lộ thêm 1 ký tự đầu của đáp án.", "fifty_fifty", 2.0, 30],
		[3, "Cuộn Giấy Không Gian", "Bỏ qua câu hỏi hiện tại và chuyển sang câu tiếp theo. Không gây sát thương và không trừ máu.", "skip", 1.0, 25],
		[4, "Băng Phong Thời Gian", "Dừng đồng hồ của câu hỏi hiện tại trong 10 giây, sau đó bộ đếm tiếp tục chạy.", "time_freeze", 10.0, 40],
		[5, "Hỏa Cầu", "Phép tấn công mạnh: trả lời đúng gây 5 sát thương. Trả lời sai hoặc hết giờ khiến người chơi chịu tổng cộng 5 sát thương.", "spell", 0.0, 60],
		[6, "Băng Tiễn", "Trả lời đúng gây 4 sát thương và có 50% đóng băng quái. Nếu dùng sai hoặc hết giờ, câu kế tiếp chỉ còn 10 giây.", "spell", 0.0, 60],
		[7, "Sét Đánh", "Trả lời đúng gây 4 sát thương; có 75% làm câu kế tiếp tăng lên 30 giây. Nếu dùng sai hoặc hết giờ, khóa phép trong 2 câu.", "spell", 0.0, 60],
		[8, "Gỗ Xưa", "Trả lời đúng gây 4 sát thương và hồi 1 HP. Trả lời sai hoặc hết giờ khiến quái hồi 1 HP.", "spell", 0.0, 60],
	]
	for it in items:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Item_Dict (item_id, name, description, item_type, effect_value, price) VALUES (?, ?, ?, ?, ?, ?);", it)
		db.query_with_bindings(
			"UPDATE Item_Dict SET name = ?, description = ?, item_type = ?, effect_value = ?, price = ? WHERE item_id = ?;",
			[it[1], it[2], it[3], it[4], it[5], it[0]])
	
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
		var parts = file.get_csv_line()
		line_number += 1

		if line_number == 1:
			continue

		if parts.size() < 3 or parts[0].strip_edges() == "":
			push_warning("[DatabaseManager] CSV dòng %d sai định dạng, bỏ qua." % line_number)
			skipped_count += 1
			continue

		var word = parts[0].strip_edges()
		var tier_str = ""
		var cefr_level = ""
		var meaning = ""

		if parts.size() >= 4 and parts[parts.size() - 2].strip_edges().is_valid_int():
			tier_str = parts[parts.size() - 2].strip_edges()
			cefr_level = parts[parts.size() - 1].strip_edges()
			meaning = ",".join(parts.slice(1, parts.size() - 2)).strip_edges()
		else:
			tier_str = parts[parts.size() - 1].strip_edges()
			meaning = ",".join(parts.slice(1, parts.size() - 1)).strip_edges()

		if not tier_str.is_valid_int():
			push_warning("[DatabaseManager] CSV dòng %d: tier_id '%s' không hợp lệ, bỏ qua." % [line_number, tier_str])
			skipped_count += 1
			continue

		var tier_id = tier_str.to_int()
		if cefr_level == "":
			cefr_level = _infer_cefr_level_for_tier(tier_id)

		db.query_with_bindings(
			"INSERT OR IGNORE INTO Vocabulary_Bank (word, meaning, tier_id, cefr_level) VALUES (?, ?, ?, ?);",
			[word, meaning, tier_id, cefr_level]
		)
		db.query_with_bindings(
			"UPDATE Vocabulary_Bank SET meaning = ?, tier_id = ?, cefr_level = ? WHERE word = ?;",
			[meaning, tier_id, cefr_level, word]
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
		["Timber",       "Gỗ rừng / Cây lấy gỗ",  1, "A1"],
		["Canopy",       "Vòm lá / Tán cây rừng", 1, "A1"],
		["Flora",        "Hệ thực vật",           1, "A1"],
		["Predator",     "Động vật săn mồi",      2, "A2"],
		["Camouflage",   "Ngụy trang / Ẩn mình",  2, "A2"],
		["Biodiversity", "Đa dạng sinh học",      2, "A2"],
	]
	for v in fallback:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Vocabulary_Bank (word, meaning, tier_id, cefr_level) VALUES (?, ?, ?, ?);",
			v
		)
	print("[DatabaseManager] Đã nạp %d từ dự phòng." % fallback.size())

func _infer_cefr_level_for_tier(tier_id: int) -> String:
	match tier_id:
		1:
			return "A1"
		2:
			return "A2"
		3, 4:
			return "B1"
		5, 6:
			return "B2"
		7, 8:
			return "C1"
		9:
			return "C2"
		_:
			return "A1"

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
	emit_signal("gold_changed", player_gold)

func spend_gold(amount: int) -> bool:
	if player_gold < amount:
		return false
	player_gold -= amount
	db.query_with_bindings(
		"UPDATE Player_Profile SET gold = ? WHERE save_id = ?;",
		[player_gold, CURRENT_SAVE_SLOT])
	emit_signal("gold_changed", player_gold)
	return true

# ==============================================================================
# 5. SAVE / LOAD TIẾN TRÌNH
# ==============================================================================

func _resolve_save_context(pos_x: float, pos_y: float, scene_path: String = "") -> Dictionary:
	var resolved_position := Vector2(pos_x, pos_y)
	var resolved_scene_path := scene_path

	if resolved_scene_path == "":
		var current_tree = Engine.get_main_loop() as SceneTree
		if current_tree and current_tree.current_scene:
			resolved_scene_path = current_tree.current_scene.scene_file_path

	# Nếu người chơi đang lưu giữa trận, luôn trả save về scene/vị trí lúc họ bấm F vào quái.
	if resolved_scene_path == "res://scenes/BattleScene.tscn" and GameManager != null:
		if GameManager.previous_scene_path != "":
			resolved_scene_path = GameManager.previous_scene_path
		resolved_position = GameManager.player_position

	return {
		"position": resolved_position,
		"scene_path": resolved_scene_path,
	}

func save_game(pos_x: float, pos_y: float, scene_path: String = "") -> void:
	var save_context = _resolve_save_context(pos_x, pos_y, scene_path)
	var resolved_position: Vector2 = save_context["position"]
	var resolved_scene_path: String = save_context["scene_path"]
	if resolved_scene_path != "":
		current_biome = resolved_scene_path

	var serialized_enemies: String = JSON.stringify(dead_enemies)
	var serialized_interacted: String = JSON.stringify(interacted_enemies)
	var timestamp: String          = Time.get_datetime_string_from_system()

	db.query_with_bindings(
		"""UPDATE Player_Profile
		SET last_played       = ?,
		    hp                = ?,
		    gold              = ?,
		    current_biome     = ?,
		    pos_x             = ?,
		    pos_y             = ?,
		    dead_enemies_list = ?,
		    interacted_enemies_list = ?,
		    intro_quiz_completed = ?
		WHERE save_id = ?;""",
		[timestamp, player_hearts, player_gold, current_biome, resolved_position.x, resolved_position.y, serialized_enemies, serialized_interacted, 1 if intro_quiz_completed else 0, CURRENT_SAVE_SLOT]
	)

	print("[DatabaseManager] Game đã lưu lúc %s | HP: %d | Vị trí: (%.1f, %.1f) | Gold: %d" \
		% [timestamp, player_hearts, resolved_position.x, resolved_position.y, player_gold])
	emit_signal("game_saved")

func save_and_quit(pos_x: float, pos_y: float, scene_path: String = "") -> void:
	restore_full_hp()
	save_game(pos_x, pos_y, scene_path)

	var current_tree = Engine.get_main_loop() as SceneTree
	if current_tree:
		current_tree.quit()

func reset_save_for_new_game() -> void:
	player_hearts = max_hearts
	player_gold = 0
	current_biome = "res://scenes/chapel.tscn"
	dead_enemies = []
	interacted_enemies = []
	has_save_data = false
	intro_quiz_completed = false

	db.query_with_bindings(
		"""UPDATE Player_Profile
		SET last_played = '',
		    hp = ?,
		    gold = ?,
		    current_biome = ?,
		    pos_x = 0.0,
		    pos_y = 0.0,
		    dead_enemies_list = '[]',
		    interacted_enemies_list = '[]',
		    intro_quiz_completed = 0
		WHERE save_id = ?;""",
		[player_hearts, player_gold, current_biome, CURRENT_SAVE_SLOT]
	)
	db.query_with_bindings("DELETE FROM Player_Vocab_Mastery WHERE save_id = ?;", [CURRENT_SAVE_SLOT])
	db.query_with_bindings("DELETE FROM Player_Grammar_Mastery WHERE save_id = ?;", [CURRENT_SAVE_SLOT])
	db.query_with_bindings("DELETE FROM Player_Inventory WHERE save_id = ?;", [CURRENT_SAVE_SLOT])
	for item_id in [1, 2, 3, 4]:
		db.query_with_bindings(
			"INSERT INTO Player_Inventory (save_id, item_id, quantity) VALUES (?, ?, 2);",
			[CURRENT_SAVE_SLOT, item_id]
		)

	if GameManager != null:
		GameManager.target_spawn_id = ""
		GameManager.current_monster = null
		GameManager.current_enemy_id = 0
		GameManager.player_position = Vector2.ZERO
		GameManager.previous_scene_path = "res://scenes/chapter_1.tscn"
		GameManager.should_load_position = false

	emit_signal("hp_changed", player_hearts)
	emit_signal("gold_changed", player_gold)
	emit_signal("intro_quiz_state_changed", intro_quiz_completed)
	print("[DatabaseManager] Đã reset dữ liệu cho New Game.")

func load_game(save_slot: int) -> void:
	db.query_with_bindings(
		"SELECT * FROM Player_Profile WHERE save_id = ?;",
		[save_slot]
	)

	if not db.query_result.is_empty():
		var data: Dictionary = db.query_result[0]

		player_hearts = data.get("hp",            max_hearts)
		player_gold   = data.get("gold",          0)
		current_biome = data.get("current_biome", "res://scenes/chapel.tscn")
		
		# Nạp vị trí người chơi
		var pos_x = float(data.get("pos_x", 0.0))
		var pos_y = float(data.get("pos_y", 0.0))
		if GameManager != null:
			GameManager.player_position = Vector2(pos_x, pos_y)
			
		var last_played = data.get("last_played", "")
		intro_quiz_completed = bool(data.get("intro_quiz_completed", 0))
		has_save_data = (last_played != null and str(last_played).strip_edges() != "") or intro_quiz_completed

		var raw_enemies: String = data.get("dead_enemies_list", "[]")
		var json_parser         = JSON.new()
		if json_parser.parse(raw_enemies) == OK and json_parser.get_data() is Array:
			dead_enemies = _normalize_enemy_id_array(json_parser.get_data())
		else:
			push_warning("[DatabaseManager] Không parse được dead_enemies_list, reset về [].")
			dead_enemies = []

		var raw_interacted: String = data.get("interacted_enemies_list", "[]")
		if json_parser.parse(raw_interacted) == OK and json_parser.get_data() is Array:
			interacted_enemies = _normalize_enemy_id_array(json_parser.get_data())
		else:
			push_warning("[DatabaseManager] Không parse được interacted_enemies_list, reset về [].")
			interacted_enemies = []

		print("[DatabaseManager] Tải game thành công! HP: %d/%d | Quái đã diệt: %d con | Gold: %d" \
			% [player_hearts, max_hearts, dead_enemies.size(), player_gold])

		emit_signal("hp_changed", player_hearts)
		emit_signal("gold_changed", player_gold)
		emit_signal("intro_quiz_state_changed", intro_quiz_completed)
		emit_signal("game_loaded", data)
	else:
		player_hearts = max_hearts
		player_gold = 0
		dead_enemies  = []
		interacted_enemies = []
		has_save_data = false
		intro_quiz_completed = false
		print("[DatabaseManager] Không tìm thấy Save Slot %d — bắt đầu hành trình mới!" % save_slot)
		emit_signal("hp_changed", player_hearts)
		emit_signal("gold_changed", player_gold)
		emit_signal("intro_quiz_state_changed", intro_quiz_completed)

# ==============================================================================
# 6. TIỆN ÍCH BỔ SUNG
# ==============================================================================

func _has_enemy_id(list: Array, enemy_id: int) -> bool:
	for value in list:
		if int(value) == enemy_id:
			return true
	return false

func _normalize_enemy_id_array(raw_list: Array) -> Array:
	var normalized: Array = []
	for value in raw_list:
		var enemy_id := int(value)
		if enemy_id > 0 and not _has_enemy_id(normalized, enemy_id):
			normalized.append(enemy_id)
	return normalized

func mark_enemy_dead(enemy_id: int) -> void:
	if enemy_id <= 0:
		return

	var changed := false
	if not _has_enemy_id(dead_enemies, enemy_id):
		dead_enemies.append(enemy_id)
		changed = true
	if not _has_enemy_id(interacted_enemies, enemy_id):
		interacted_enemies.append(enemy_id)
		changed = true

	if changed:
		has_save_data = true
		var timestamp: String = Time.get_datetime_string_from_system()
		db.query_with_bindings(
			"""UPDATE Player_Profile
			SET last_played = ?,
			    dead_enemies_list = ?,
			    interacted_enemies_list = ?
			WHERE save_id = ?;""",
			[timestamp, JSON.stringify(dead_enemies), JSON.stringify(interacted_enemies), CURRENT_SAVE_SLOT]
		)
		emit_signal("enemy_progress_changed")
		emit_signal("game_saved")
		print("[DatabaseManager] Đã lưu quái bị diệt! ID: %d" % enemy_id)

func is_enemy_dead(enemy_id: int) -> bool:
	return _has_enemy_id(dead_enemies, enemy_id)

func mark_enemy_interacted(enemy_id: int) -> void:
	if enemy_id <= 0:
		return
	if not _has_enemy_id(interacted_enemies, enemy_id):
		interacted_enemies.append(enemy_id)
		var serialized_interacted: String = JSON.stringify(interacted_enemies)
		has_save_data = true
		db.query_with_bindings(
			"UPDATE Player_Profile SET interacted_enemies_list = ?, last_played = ? WHERE save_id = ?;",
			[serialized_interacted, Time.get_datetime_string_from_system(), CURRENT_SAVE_SLOT]
		)
		emit_signal("enemy_progress_changed")
		emit_signal("game_saved")
		print("[DatabaseManager] Đã lưu quái đã tương tác! ID: %d" % enemy_id)

func has_interacted_with_enemy(enemy_id: int) -> bool:
	return _has_enemy_id(interacted_enemies, enemy_id)

func get_enemy_hp_for_tier(tier_id: int, fallback_hp: int = 20) -> int:
	db.query_with_bindings(
		"SELECT hp FROM Enemy_Tier_Dict WHERE tier_id = ?;",
		[tier_id]
	)
	if db.query_result.is_empty():
		return fallback_hp
	return int(db.query_result[0].get("hp", fallback_hp))

func has_completed_intro_quiz() -> bool:
	return intro_quiz_completed

func mark_intro_quiz_completed() -> void:
	if intro_quiz_completed:
		return
	intro_quiz_completed = true
	has_save_data = true

	var timestamp: String = Time.get_datetime_string_from_system()
	var pos := GameManager.player_position if GameManager != null else Vector2.ZERO
	var save_context := _resolve_save_context(pos.x, pos.y)
	var resolved_position: Vector2 = save_context["position"]
	var resolved_scene_path: String = save_context["scene_path"]
	if resolved_scene_path != "":
		current_biome = resolved_scene_path

	db.query_with_bindings(
		"""UPDATE Player_Profile
		SET last_played = ?,
		    current_biome = ?,
		    pos_x = ?,
		    pos_y = ?,
		    intro_quiz_completed = ?
		WHERE save_id = ?;""",
		[timestamp, current_biome, resolved_position.x, resolved_position.y, 1, CURRENT_SAVE_SLOT]
	)
	emit_signal("intro_quiz_state_changed", intro_quiz_completed)
	emit_signal("game_saved")
	print("[DatabaseManager] Đã đánh dấu hoàn thành bài test đầu game.")

func restore_full_hp() -> void:
	set_player_hp(max_hearts)
	print("[DatabaseManager] HP đã phục hồi đầy: %d/%d" % [player_hearts, max_hearts])

func set_player_hp(new_hp: int, check_game_over: bool = true) -> void:
	player_hearts = clampi(new_hp, 0, max_hearts)
	db.query_with_bindings(
		"UPDATE Player_Profile SET hp = ? WHERE save_id = ?;",
		[player_hearts, CURRENT_SAVE_SLOT]
	)
	emit_signal("hp_changed", player_hearts)
	if check_game_over and player_hearts <= 0:
		emit_signal("game_over_triggered")

# ==============================================================================
# 7. TÍNH NĂNG NOTEBOOK
# ==============================================================================

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
