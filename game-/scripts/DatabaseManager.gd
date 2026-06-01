extends Node

# ==============================================================================
# DatabaseManager.gd — AutoLoad Singleton
# Trách nhiệm: Data Layer — Schema, CRUD, Save/Load, HP state
# KHÔNG chứa learning logic (xem ProgressManager.gd)
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
	# ── Player_Profile (thêm cột gold) ──
	db.query("""
		CREATE TABLE IF NOT EXISTS Player_Profile (
			save_id             INTEGER PRIMARY KEY,
			last_played         TEXT,
			hp                  INTEGER DEFAULT 5,
			gold                INTEGER DEFAULT 0,
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

	# ── Enemy_Tier_Dict (giữ nguyên) ──
	db.query("""
		CREATE TABLE IF NOT EXISTS Enemy_Tier_Dict (
			tier_id         INTEGER PRIMARY KEY,
			enemy_type      TEXT    NOT NULL,
			required_level  INTEGER DEFAULT 1
		);
	""")

	# ── Vocabulary_Bank (giữ nguyên) ──
	# UNIQUE trên cột word: đảm bảo INSERT OR IGNORE hoạt động đúng
	db.query("""
		CREATE TABLE IF NOT EXISTS Vocabulary_Bank (
			word_id     INTEGER PRIMARY KEY AUTOINCREMENT,
			word        TEXT    NOT NULL UNIQUE,
			meaning     TEXT    NOT NULL,
			tier_id     INTEGER,
			FOREIGN KEY (tier_id) REFERENCES Enemy_Tier_Dict(tier_id)
		);
	""")

	# ── Player_Vocab_Mastery (NÂNG CẤP: thêm cột SRS) ──
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
			FOREIGN KEY (save_id) REFERENCES Player_Profile(save_id),
			FOREIGN KEY (word_id) REFERENCES Vocabulary_Bank(word_id)
		);
	""")

	# ── Grammar_Bank (MỚI) ──
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

	# ── Item_Dict (MỚI) ──
	db.query("""
		CREATE TABLE IF NOT EXISTS Item_Dict (
			item_id         INTEGER PRIMARY KEY,
			name            TEXT    NOT NULL,
			description     TEXT    DEFAULT '',
			item_type       TEXT    NOT NULL,
			effect_value    REAL    DEFAULT 1.0
		);
	""")

	# ── Player_Inventory (MỚI) ──
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

	print("[DatabaseManager] Cấu trúc 7 bảng đã sẵn sàng.")

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

		if parts.size() < 3:
			push_warning("[DatabaseManager] CSV dòng %d sai định dạng, bỏ qua: '%s'" % [line_number, raw_line])
			skipped_count += 1
			continue

		var word     = parts[0].strip_edges()
		# Ghép lại các phần giữa để xử lý meaning có dấu phẩy
		var meaning  = ",".join(parts.slice(1, parts.size() - 1)).strip_edges()
		var tier_str = parts[parts.size() - 1].strip_edges()

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

# Chạy chỉ khi CSV bị thiếu VÀ Vocabulary_Bank vẫn trống
# Đảm bảo game không crash trong mọi tình huống
func _seed_vocabulary_fallback() -> void:
	db.query("SELECT COUNT(*) as total FROM Vocabulary_Bank;")
	if not db.query_result.is_empty() and db.query_result[0]["total"] > 0:
		return

	push_warning("[DatabaseManager] Vocabulary_Bank trống! Dùng bộ từ dự phòng tối thiểu.")
	var fallback = [
		["Timber",      "Gỗ rừng / Cây lấy gỗ",  1],
		["Canopy",      "Vòm lá / Tán cây rừng",  1],
		["Flora",       "Hệ thực vật",             1],
		["Predator",    "Động vật săn mồi",        2],
		["Camouflage",  "Ngụy trang / Ẩn mình",   2],
		["Biodiversity","Đa dạng sinh học",        2],
	]
	for v in fallback:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Vocabulary_Bank (word, meaning, tier_id) VALUES (?, ?, ?);",
			v
		)
	print("[DatabaseManager] Đã nạp %d từ dự phòng." % fallback.size())

func _seed_grammar() -> void:
	db.query("SELECT COUNT(*) as total FROM Grammar_Bank;")
	if not db.query_result.is_empty() and db.query_result[0]["total"] > 0:
		return
	print("[DatabaseManager] Nạp ngữ pháp ban đầu...")
	var data = [
		["Present Simple",       "S + V(s/es)",                   "Thì hiện tại đơn: thói quen, sự thật.",          "The slime attacks every night.",         1],
		["Singular & Plural",    "N + s/es/ies",                  "Danh từ số ít/nhiều.",                            "One fern → Many ferns.",                 1],
		["Articles a/an/the",    "a + phụ âm | an + nguyên âm",  "Mạo từ không xác định và xác định.",             "A slime appeared. The slime was green.", 1],
		["Past Simple",          "S + V-ed/V2",                   "Thì quá khứ đơn: đã xảy ra và kết thúc.",        "The goblin ambushed the traveler.",      2],
		["Prepositions of Place","in/on/at/under/behind",         "Giới từ chỉ nơi chốn.",                           "The treasure is behind the waterfall.",  2],
		["Present Continuous",   "S + am/is/are + V-ing",         "Thì hiện tại tiếp diễn: đang xảy ra.",            "The predator is lurking.",               2],
		["Present Perfect",      "S + have/has + V3",             "Thì hiện tại hoàn thành.",                        "The dragon has destroyed the village.",  3],
		["Passive Voice",        "S + be + V3",                   "Câu bị động: nhấn mạnh đối tượng chịu tác động.","The forest was burned by the dragon.",   3],
	]
	for g in data:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Grammar_Bank (topic_name, formula, explanation_vi, example_en, tier_id) VALUES (?, ?, ?, ?, ?);", g)
	print("[DatabaseManager] Đã nạp %d chủ điểm ngữ pháp." % data.size())

func _seed_items() -> void:
	db.query("SELECT COUNT(*) as total FROM Item_Dict;")
	if not db.query_result.is_empty() and db.query_result[0]["total"] > 0:
		return
	print("[DatabaseManager] Nạp vật phẩm ban đầu...")
	var items = [
		[1, "Bình Máu",     "Hồi phục 1 HP.",              "potion",      1.0],
		[2, "Phép 50/50",   "Loại bỏ 2 đáp án sai.",       "fifty_fifty", 2.0],
		[3, "Gợi ý từ NPC", "Elaria gợi ý mẹo nhớ từ.",   "hint",        1.0],
		[4, "Bỏ qua câu",   "Bỏ qua câu, không mất máu.", "skip",        1.0],
	]
	for it in items:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Item_Dict VALUES (?, ?, ?, ?, ?);", it)
	for item_id in [1, 2, 3, 4]:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Player_Inventory (save_id, item_id, quantity) VALUES (?, ?, 3);",
			[CURRENT_SAVE_SLOT, item_id])
	print("[DatabaseManager] Đã nạp %d vật phẩm + starter kit." % items.size())

# ==============================================================================
# 4. SAVE / LOAD TIẾN TRÌNH
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
# 5. TIỆN ÍCH BỔ SUNG
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
