extends CanvasLayer

# --- LIÊN KẾT GIAO DIỆN "TIA X" (Bỏ qua lỗi % của Godot) ---
@onready var search_bar = find_child("SearchBar", true, false)
@onready var vocab_list = find_child("VocabList", true, false)
@onready var tier_filter = find_child("TierFilter", true, false)
@onready var status_filter = find_child("StatusFilter", true, false)

@onready var btn_vocab = find_child("BtnVocab", true, false)
@onready var btn_grammar = find_child("BtnGrammar", true, false)

@onready var det_cefr = find_child("DetCefr", true, false)
@onready var det_word = find_child("DetWord", true, false)
@onready var det_meaning = find_child("DetMeaning", true, false)
@onready var det_mastery = find_child("DetMastery", true, false)
@onready var det_stats = find_child("DetStats", true, false)
@onready var mastery_bar = find_child("MasteryBar", true, false)
@onready var content_ui = $ContentUI # Thay bằng đúng đường dẫn hộp chứa UI của bạn
@onready var anim_player = $AnimationPlayer
@onready var book_bg = $BookBackground


var active_db = DatabaseManager 
var current_tab = "vocab"

var unlocked_spells = [
	{"name": "🔥 Fireball (Hiện tại đơn)", "desc": "Bắn cầu lửa cơ bản. Dùng diễn tả thói quen, chân lý.", "mastery": 100},
	{"name": "❄️ Ice Shield (Hiện tại tiếp diễn)", "desc": "Tạo khiên băng. Dùng cho hành động đang xảy ra ngay lúc này.", "mastery": 60},
	{"name": "⚡ Thunder Strike (Quá khứ đơn)", "desc": "Sấm sét diện rộng. Dùng cho hành động đã dứt điểm trong quá khứ.", "mastery": 20}
]

func _ready():
	add_to_group("notebook_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS 
	hide() 
	
	# Bọc bảo vệ: Có Node thì mới kết nối tín hiệu (Chống sập game)
	if search_bar: search_bar.text_changed.connect(func(text): _refresh_current_tab())
	if tier_filter: tier_filter.item_selected.connect(func(idx): _refresh_current_tab())
	if status_filter: status_filter.item_selected.connect(func(idx): _refresh_current_tab())
	
	if btn_vocab: btn_vocab.pressed.connect(func(): _switch_tab("vocab"))
	if btn_grammar: btn_grammar.pressed.connect(func(): _switch_tab("grammar"))
	$CloseButton.pressed.connect(_on_close_button_pressed)

# --- HỆ THỐNG MỞ / ĐÓNG ---
func toggle_notebook():
	if visible: close_notebook()
	else: open_notebook()

func open_notebook():
	show()
	get_tree().paused = true
	
	content_ui.hide() 
	
	anim_player.play("open_book")
	
	await anim_player.animation_finished 

	content_ui.show()
	_switch_tab("vocab")

func _on_close_button_pressed():
	hide()
	get_tree().paused = false
	
func close_notebook():
	hide()
	get_tree().paused = false

func _input(event):
	if visible and event is InputEventKey:
		if event.keycode == KEY_DELETE and event.pressed and not event.echo:
			close_notebook()

# --- HỆ THỐNG CHUYỂN TAB ---
func _switch_tab(tab_name):
	current_tab = tab_name
	_clear_detail_panel()
	_refresh_current_tab()

func _refresh_current_tab():
	if current_tab == "vocab":
		_render_vocabulary_tab()
	else:
		_render_grammar_tab()

func _clear_detail_panel():
	det_word.text = "CHỌN MỘT MỤC"
	det_meaning.text = "Nhấp vào danh sách bên trái để xem chi tiết."
	det_stats.text = ""
	det_mastery.text = ""
	mastery_bar.hide()

# --- [x] Xử lý Mastery 5 bậc ---
func _get_mastery_info(score: float, encounters: int) -> Dictionary:
	if encounters == 0: return {"text": "CHƯA GẶP", "val": 0}
	if score >= 0.8: return {"text": "👑 MASTER", "val": 100}
	if score >= 0.5: return {"text": "🌟 ADEPT", "val": 75}
	if score >= 0.3: return {"text": "⚔️ PRACTICED", "val": 50}
	if score > 0.0: return {"text": "👁️ FAMILIAR", "val": 25}
	return {"text": "💀 STRANGER", "val": 10}

# --- [x] Render Danh sách Từ vựng & Bộ lọc ---
func _render_vocabulary_tab():
	for child in vocab_list.get_children():
		child.queue_free()
		
	var query = search_bar.text
	var tier = tier_filter.get_selected_id() if tier_filter else 0
	
	var status_text = "All"
	if status_filter.selected == 1: status_text = "NeedPractice"
	elif status_filter.selected == 2: status_text = "Mastered"
	
	var vocab_data = active_db.search_encountered_vocab(query, tier, status_text)
	
	for v in vocab_data:
		var btn = Button.new()
		btn.text = v["word"].capitalize()
		var m_info = _get_mastery_info(v["mastery_score"], v["encounter_count"])
		
		btn.pressed.connect(func(): _display_word_detail(v, m_info))
		vocab_list.add_child(btn)

# --- [x] Thẻ chi tiết Từ vựng ---
func _display_word_detail(data: Dictionary, m_info: Dictionary):
	var cefr_raw = data.get("cefr_level")
	var cefr = str(cefr_raw) if cefr_raw != null and str(cefr_raw) != "" else "??"

	if det_cefr:
		det_cefr.text = "[" + cefr + "] "
		det_cefr.add_theme_color_override("font_color", Color("#3b352d")) # Đen mực tàu
		det_cefr.show()
		
	if det_word:
		det_word.text = str(data.get("word", "")).to_upper()
		det_word.add_theme_color_override("font_color", Color("#1e5631")) # Xanh lá đậm
		det_word.show()
		
	if det_meaning:
		det_meaning.text = "Nghĩa: " + data["meaning"]
		det_meaning.add_theme_color_override("font_color", Color("#3b352d")) # Đen mực tàu
		
	if det_stats:
		det_stats.text = "Gặp %d | Đúng %d" % [data["encounter_count"], data["correct_count"]]
		det_stats.add_theme_color_override("font_color", Color("#3b352d")) # Đen mực tàu
	
	if det_mastery:
		det_mastery.text = m_info["text"]
		det_mastery.add_theme_color_override("font_color", Color("#3b352d")) # Đen mực tàu
	
	if mastery_bar:
		mastery_bar.value = m_info["val"]
		
		# Ép thanh Progress Bar thành màu Đen
		var black_style = StyleBoxFlat.new()
		black_style.bg_color = Color("#3b352d")
		mastery_bar.add_theme_stylebox_override("fill", black_style)
		
		# Ép chữ % bên trong thanh thành màu Trắng cho nổi bật
		mastery_bar.add_theme_color_override("font_color", Color.WHITE)
		
		mastery_bar.show()
# --- [x] Render Tab Ngữ pháp ---
func _render_grammar_tab():
	for child in vocab_list.get_children():
		child.queue_free()
		
	for spell in unlocked_spells:
		var btn = Button.new()
		btn.text = spell["name"]
		btn.pressed.connect(func():
			det_word.bbcode_enabled = true # Ép bật màu
			det_word.text = "[color=#ffeb3b]%s[/color]" % spell["name"]
			det_meaning.text = spell["desc"]
			det_stats.text = "Độ thuần thục phép: %d%%" % spell["mastery"]
			det_mastery.text = ""
			if mastery_bar:
				mastery_bar.value = spell["mastery"]
				mastery_bar.show()
		)
		vocab_list.add_child(btn)
