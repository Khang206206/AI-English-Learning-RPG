extends Node

# ==============================================================================
# DatabaseManager.gd — AutoLoad Singleton
# Mô tả: Single Source of Truth — toàn bộ dữ liệu game đi qua file data.db
# ==============================================================================

# --- SIGNALS (Để các Node khác lắng nghe sự kiện quan trọng) ---
signal hp_changed(new_hp: int)          # Phát khi HP thay đổi → cập nhật HUD
signal game_over_triggered()            # Phát khi HP <= 0 → chuyển màn thua
signal game_saved()                     # Phát khi lưu game thành công
signal game_loaded(data: Dictionary)    # Phát khi tải game thành công, kèm data

# --- CẤU HÌNH DATABASE ---
# QUAN TRỌNG: Plugin godot-sqlite yêu cầu đường dẫn TƯƠNG ĐỐI (không có "res://")
# File data.db phải nằm trong thư mục gốc của dự án Godot
var db = null
const DB_PATH: String = "data.db"
const CURRENT_SAVE_SLOT: int = 1

# --- TRẠNG THÁI RUNTIME (Cache trong RAM, đồng bộ xuống DB khi cần) ---
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
	# Đóng kết nối DB an toàn khi thoát game, tránh corrupt file .db
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if db != null:
			db.close_db()
			print("[DatabaseManager] Đã đóng kết nối database an toàn.")

# ==============================================================================
# 1. KHỞI TẠO CẤU TRÚC CƠ SỞ DỮ LIỆU
# ==============================================================================

func init_database() -> void:
	# Khởi tạo động để tránh xung đột GDExtension trong Editor
	# KHÔNG dùng: var db: SQLite — sẽ gây lỗi "Identifier not declared"
	db = ClassDB.instantiate("SQLite")
	db.path = DB_PATH

	if not db.open_db():
		push_error("[DatabaseManager] NGHIÊM TRỌNG: Không thể mở file database tại: " + DB_PATH)
		return

	print("[DatabaseManager] Kết nối database thành công.")

	# Tối ưu hiệu suất đọc/ghi cho SQLite local (game offline)
	db.query("PRAGMA synchronous = NORMAL;")   # OFF rủi ro khi crash, NORMAL là cân bằng tốt
	db.query("PRAGMA journal_mode = WAL;")      # WAL tốt hơn MEMORY vì không mất data khi crash
	db.query("PRAGMA foreign_keys = ON;")       # Bật kiểm tra ràng buộc khóa ngoại

	_create_tables()
	seed_initial_data()

func _create_tables() -> void:
	# --- BẢNG 1: Player_Profile ---
	# Lưu toàn bộ trạng thái tiến trình của người chơi theo từng slot
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

	# KHẮC PHỤC SILENT BUG: Đảm bảo Slot 1 luôn tồn tại trước khi bất kỳ
	# lệnh UPDATE nào chạy. Nếu không có dòng này, UPDATE sẽ "thành công"
	# nhưng không thay đổi gì cả (0 rows affected).
	db.query_with_bindings(
		"INSERT OR IGNORE INTO Player_Profile (save_id, hp, current_biome) VALUES (?, ?, ?);",
		[CURRENT_SAVE_SLOT, max_hearts, current_biome]
	)

	# --- BẢNG 2: Enemy_Tier_Dict ---
	# Danh mục tĩnh phân cấp quái vật, liên kết với độ khó từ vựng
	db.query("""
		CREATE TABLE IF NOT EXISTS Enemy_Tier_Dict (
			tier_id         INTEGER PRIMARY KEY,
			enemy_type      TEXT    NOT NULL,
			required_level  INTEGER DEFAULT 1
		);
	""")

	# --- BẢNG 3: Vocabulary_Bank ---
	# Kho từ vựng toàn bộ game, phân cấp theo tier của quái vật
	db.query("""
		CREATE TABLE IF NOT EXISTS Vocabulary_Bank (
			word_id     INTEGER PRIMARY KEY AUTOINCREMENT,
			word        TEXT    NOT NULL,
			meaning     TEXT    NOT NULL,
			tier_id     INTEGER,
			FOREIGN KEY (tier_id) REFERENCES Enemy_Tier_Dict(tier_id)
		);
	""")

	# --- BẢNG 4: Player_Vocab_Mastery ---
	# Hồ sơ năng lực động: theo dõi từng từ của từng người chơi
	# Khóa chính kép (save_id + word_id) cho phép nhiều slot save
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
# Dùng INSERT OR IGNORE để hàm này có thể gọi nhiều lần mà không bị lỗi duplicate
# ==============================================================================

func seed_initial_data() -> void:
	_seed_enemies()
	_seed_vocabulary()

func _seed_enemies() -> void:
	db.query("SELECT COUNT(*) as total FROM Enemy_Tier_Dict;")
	if db.query_result.is_empty() or db.query_result[0]["total"] > 0:
		return  # Đã có dữ liệu, bỏ qua

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

func _seed_vocabulary() -> void:
	db.query("SELECT COUNT(*) as total FROM Vocabulary_Bank;")
	if db.query_result.is_empty() or db.query_result[0]["total"] > 0:
		return  # Đã có dữ liệu, bỏ qua

	print("[DatabaseManager] Nạp kho từ vựng chủ đề 'Beginner Forest'...")
	# [word, meaning, tier_id]
	var vocab_list = [
		# Tier 1 — Slime (Từ cơ bản, cụ thể)
		["Timber",      "Gỗ rừng / Cây lấy gỗ",           1],
		["Canopy",      "Vòm lá / Tán cây rừng",           1],
		["Flora",       "Hệ thực vật",                      1],
		["Mossy",       "Phủ rêu / Rêu phong",             1],
		["Fern",        "Cây dương xỉ",                     1],
		["Creek",       "Suối nhỏ / Lạch nước",            1],
		# Tier 2 — Goblin (Từ trung cấp, trừu tượng hơn)
		["Biodiversity","Đa dạng sinh học",                 2],
		["Dense",       "Dày đặc / Rậm rạp",               2],
		["Sustain",     "Duy trì / Chống đỡ",              2],
		["Foliage",     "Tán lá / Lớp lá cây",             2],
		["Predator",    "Động vật săn mồi",                 2],
		["Camouflage",  "Ngụy trang / Ẩn mình",            2],
	]
	for v in vocab_list:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Vocabulary_Bank (word, meaning, tier_id) VALUES (?, ?, ?);",
			v
		)
	print("[DatabaseManager] Đã nạp %d từ vựng thành công." % vocab_list.size())

# ==============================================================================
# 3. THUẬT TOÁN DDA — LẤY TỪ VỰNG YẾU NHẤT (Dynamic Difficulty Adjustment)
# ==============================================================================

## Trả về Dictionary từ vựng có Mastery Score thấp nhất cho tier được chỉ định.
## Mastery Score = correct_count / (encounter_count + 1)
## Dùng LEFT JOIN để bao gồm cả từ MỚI (chưa từng gặp → mastery_score = 0.0)
##
## Chiến lược chọn từ theo 2 bước:
##   Bước 1 (SQL): Lấy N từ có mastery_score THẤP NHẤT → tạo thành một "Weak Pool"
##   Bước 2 (GDScript): Chọn NGẪU NHIÊN 1 từ trong pool đó
##
## Lý do KHÔNG dùng ORDER BY RANDOM() đơn thuần:
##   - ORDER BY RANDOM() có thể trả về từ đã thành thạo nếu hên
##   - Cách này đảm bảo 100% từ được chọn thuộc nhóm YẾU NHẤT,
##     chỉ để yếu tố ngẫu nhiên quyết định "từ yếu nào" trong nhóm đó
##
## Tham số pool_size: số lượng ứng viên lấy từ DB (mặc định 5)
## Trả về {} (Dictionary rỗng) nếu không tìm thấy từ nào trong tier đó.
func get_weakest_vocab(tier_id: int, pool_size: int = 5) -> Dictionary:
	# --- BƯỚC 1: Kéo N từ yếu nhất từ DB ---
	var sql = """
		SELECT
			v.word_id,
			v.word,
			v.meaning,
			v.tier_id,
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
		WHERE v.tier_id = ?
		ORDER BY mastery_score ASC
		LIMIT ?;
	"""
	db.query_with_bindings(sql, [CURRENT_SAVE_SLOT, tier_id, pool_size])

	if db.query_result.is_empty():
		push_warning("[DatabaseManager] Không tìm thấy từ vựng cho tier_id = %d" % tier_id)
		return {}

	# --- BƯỚC 2: Chọn ngẫu nhiên 1 từ trong pool ---
	var weak_pool: Array = db.query_result.duplicate()
	var chosen: Dictionary = weak_pool[randi() % weak_pool.size()]

	print("[DatabaseManager] Pool %d từ (tier %d) → Chọn: '%s' (mastery: %.2f)" \
		% [weak_pool.size(), tier_id, chosen["word"], chosen["mastery_score"]])

	return chosen

# ==============================================================================
# 4. CẬP NHẬT SAU COMBAT — UPSERT MASTERY & ĐỒNG BỘ HP
# ==============================================================================

## Gọi sau mỗi lượt chiến đấu.
## - Nếu sai (is_correct = false): trừ 1 trái tim, phát signal game_over nếu hết máu
## - Thực hiện UPSERT vào Player_Vocab_Mastery (INSERT nếu mới, UPDATE nếu đã có)
## - Đồng bộ HP mới nhất xuống Player_Profile
func update_after_combat(word_id: int, is_correct: bool) -> void:
	# --- BƯỚC 1: Cập nhật HP runtime ---
	if not is_correct:
		player_hearts = max(0, player_hearts - 1)
		print("[DatabaseManager] Sai rồi! HP còn lại: %d/%d" % [player_hearts, max_hearts])

	# Phát signal để HUD cập nhật ngay lập tức (không phải đợi đến frame sau)
	emit_signal("hp_changed", player_hearts)

	# --- BƯỚC 2: UPSERT vào bảng Player_Vocab_Mastery ---
	# Kiểm tra xem từ này đã từng xuất hiện với save_slot này chưa
	db.query_with_bindings(
		"SELECT encounter_count FROM Player_Vocab_Mastery WHERE save_id = ? AND word_id = ?;",
		[CURRENT_SAVE_SLOT, word_id]
	)

	var correct_delta: int = 1 if is_correct else 0

	if db.query_result.is_empty():
		# Lần đầu gặp từ này → INSERT bản ghi mới
		db.query_with_bindings(
			"""INSERT INTO Player_Vocab_Mastery
				(save_id, word_id, encounter_count, correct_count)
			VALUES (?, ?, 1, ?);""",
			[CURRENT_SAVE_SLOT, word_id, correct_delta]
		)
	else:
		# Đã có bản ghi → UPDATE tăng dần bộ đếm
		db.query_with_bindings(
			"""UPDATE Player_Vocab_Mastery
			SET encounter_count = encounter_count + 1,
			    correct_count   = correct_count   + ?
			WHERE save_id = ? AND word_id = ?;""",
			[correct_delta, CURRENT_SAVE_SLOT, word_id]
		)

	# --- BƯỚC 3: Đồng bộ HP mới vào Player_Profile ---
	db.query_with_bindings(
		"UPDATE Player_Profile SET hp = ? WHERE save_id = ?;",
		[player_hearts, CURRENT_SAVE_SLOT]
	)

	# --- BƯỚC 4: Kiểm tra Game Over SAU KHI đã lưu xuống DB ---
	if player_hearts <= 0:
		print("[DatabaseManager] *** GAME OVER *** Người chơi đã hết mạng!")
		emit_signal("game_over_triggered")

# ==============================================================================
# 5. SAVE / LOAD TIẾN TRÌNH
# ==============================================================================

## Lưu tọa độ hiện tại và toàn bộ trạng thái vào Player_Profile.
## dead_enemies (Array) được serialize thành chuỗi JSON để lưu vào TEXT column.
func save_game(pos_x: float, pos_y: float) -> void:
	var serialized_enemies: String = JSON.stringify(dead_enemies)
	var timestamp: String        = Time.get_datetime_string_from_system()

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

## Đọc dữ liệu từ Player_Profile và phục hồi toàn bộ trạng thái runtime.
## dead_enemies_list (JSON string) được parse ngược lại thành Array GDScript.
func load_game(save_slot: int) -> void:
	db.query_with_bindings(
		"SELECT * FROM Player_Profile WHERE save_id = ?;",
		[save_slot]
	)

	if not db.query_result.is_empty():
		var data: Dictionary = db.query_result[0]

		# Phục hồi trạng thái runtime từ data đọc được
		player_hearts  = data.get("hp",            max_hearts)
		current_biome  = data.get("current_biome", "Beginner Forest")

		# Parse chuỗi JSON → Array (xử lý cả trường hợp dữ liệu rỗng/hỏng)
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
		# Không tìm thấy save → khởi tạo trạng thái mới (bình thường với người chơi mới)
		player_hearts = max_hearts
		dead_enemies  = []
		print("[DatabaseManager] Không tìm thấy Save Slot %d — bắt đầu hành trình mới!" % save_slot)
		emit_signal("hp_changed", player_hearts)

# ==============================================================================
# 6. TIỆN ÍCH BỔ SUNG
# ==============================================================================

## Thêm quái vật vào danh sách đã diệt (chỉ ghi nhớ trên RAM, gọi save_game() để lưu)
func mark_enemy_dead(enemy_id: int) -> void:
	if enemy_id not in dead_enemies:
		dead_enemies.append(enemy_id)

## Kiểm tra quái vật đã chết chưa (dùng trong World để spawn hay không)
func is_enemy_dead(enemy_id: int) -> bool:
	return enemy_id in dead_enemies

## Phục hồi toàn bộ HP (dùng khi người chơi qua màn / hồi sinh)
func restore_full_hp() -> void:
	player_hearts = max_hearts
	db.query_with_bindings(
		"UPDATE Player_Profile SET hp = ? WHERE save_id = ?;",
		[player_hearts, CURRENT_SAVE_SLOT]
	)
	emit_signal("hp_changed", player_hearts)
	print("[DatabaseManager] HP đã phục hồi đầy: %d/%d" % [player_hearts, max_hearts])

## Lấy thống kê tổng quan năng lực từ vựng của người chơi
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
