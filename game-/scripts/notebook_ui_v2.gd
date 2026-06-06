extends CanvasLayer

# ==============================================================================
# notebook_ui_v2.gd
# 3-tab notebook: Vocabulary | Grammar | Review (Flashcard + AI hint)
# ==============================================================================

# ── Core nodes ────────────────────────────────────────────────────────────────
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var content_ui: Control               = %ContentUI
@onready var close_button: Button              = %CloseButton

# ── Tab buttons ───────────────────────────────────────────────────────────────
@onready var btn_vocab:   Button = %BtnVocab
@onready var btn_grammar: Button = %BtnGrammar
@onready var btn_review:  Button = %BtnReview

# ── Tab containers ────────────────────────────────────────────────────────────
@onready var tab_vocab:   HBoxContainer = %TabVocab
@onready var tab_grammar: HBoxContainer = %TabGrammar
@onready var tab_review:  HBoxContainer = %TabReview

# ── Vocab tab nodes ───────────────────────────────────────────────────────────
@onready var search_bar:    LineEdit    = %SearchBar
@onready var vocab_list:    VBoxContainer = %VocabList
@onready var vocab_stats:   Label       = %VocabStats
@onready var det_word:      Label       = %DetWord
@onready var det_cefr:      Label       = %DetCEFR
@onready var det_meaning:   Label       = %DetMeaning
@onready var det_mastery:   Label       = %DetMastery

# ── Grammar tab nodes ─────────────────────────────────────────────────────────
@onready var grammar_list:      VBoxContainer = %GrammarList
@onready var gr_det_title:      Label         = %GrDetTitle
@onready var gr_det_formula:    Label         = %GrDetFormula
@onready var gr_det_explanation:Label         = %GrDetExplanation

# ── Review tab nodes ──────────────────────────────────────────────────────────
@onready var review_status:   Label  = %ReviewStatusLabel
@onready var due_list:        VBoxContainer = %DueList
@onready var btn_start_review:Button = %BtnStartReview
@onready var flashcard_word:  Label  = %FlashcardWord
@onready var flashcard_meaning:Label = %FlashcardMeaning
@onready var hint_label:      Label  = %HintLabel
@onready var btn_ai_hint:     Button = %BtnAIHint
@onready var btn_flip:        Button = %BtnFlip
@onready var btn_forgot:      Button = %BtnForgot
@onready var btn_remember:    Button = %BtnRemember

# ── AI Example Nodes (Optional / Dynamically resolved) ──────────
@onready var btn_ai_example:    Button = get_node_or_null("%BtnAIExample")
@onready var ai_example_label:  Label  = get_node_or_null("%AIExampleLabel")
@onready var btn_gr_ai_example: Button = get_node_or_null("%BtnGrAIExample")
@onready var gr_ai_example_label: Label= get_node_or_null("%GrAIExampleLabel")

# ── State ─────────────────────────────────────────────────────────────────────
var progress_manager: Node
var ai_manager: Node
var current_tab_index := 0
var all_tabs: Array

# Review state
var review_queue: Array = []
var current_review_word: Dictionary = {}
var is_card_flipped := false
var review_started := false

# AI Example State
var current_vocab_detail: Dictionary = {}
var current_grammar_detail: Dictionary = {}
var _ai_example_target: String = "vocab"

# Tab button style cache
const COLOR_ACTIVE := Color(0.82, 0.71, 0.48, 1.0)
const COLOR_NORMAL := Color(0.70, 0.60, 0.42, 0.85)

# ==============================================================================
func _ready() -> void:
	add_to_group("notebook_ui")
	progress_manager = get_node_or_null("/root/ProgressManager")
	ai_manager       = get_node_or_null("/root/AIManager")

	all_tabs = [tab_vocab, tab_grammar, tab_review]

	# Signals
	close_button.pressed.connect(_on_close_requested)
	btn_vocab.pressed.connect(func(): _switch_tab(0))
	btn_grammar.pressed.connect(func(): _switch_tab(1))
	btn_review.pressed.connect(func(): _switch_tab(2))

	if btn_ai_example: btn_ai_example.hide()
	if ai_example_label: ai_example_label.hide()
	if btn_gr_ai_example: btn_gr_ai_example.hide()
	if gr_ai_example_label: gr_ai_example_label.hide()
	
	if search_bar:
		search_bar.text_changed.connect(_refresh_vocab_list)
	
	# Khởi tạo giá trị cho nút Lọc Tier (1->9)
	var tier_filter = get_node_or_null("%TierFilter")
	if tier_filter:
		tier_filter.clear()
		tier_filter.add_item("Tất cả Tier")
		for i in range(1, 10):
			tier_filter.add_item("Tier %d" % i)
		tier_filter.item_selected.connect(func(_idx): _refresh_vocab_list(search_bar.text))
	
	# Khởi tạo giá trị cho nút Lọc Status
	var status_filter = get_node_or_null("%StatusFilter")
	if status_filter:
		status_filter.clear()
		status_filter.add_item("Tất cả Status")
		status_filter.add_item("Stranger")
		status_filter.add_item("Familiar")
		status_filter.add_item("Practiced")
		status_filter.add_item("Adept")
		status_filter.item_selected.connect(func(_idx): _refresh_vocab_list(search_bar.text))
		
	btn_start_review.pressed.connect(_start_flashcard_session)
	btn_flip.pressed.connect(_on_flip_pressed)
	btn_ai_hint.pressed.connect(_on_ai_hint_pressed)
	btn_forgot.pressed.connect(func(): _submit_review(false))
	btn_remember.pressed.connect(func(): _submit_review(true))

	if ai_manager and ai_manager.has_signal("hint_ready"):
		ai_manager.hint_ready.connect(_on_ai_hint_ready)
	if ai_manager and ai_manager.has_signal("example_sentence_ready"):
		ai_manager.example_sentence_ready.connect(_on_example_sentence_ready)

	if btn_ai_example: btn_ai_example.pressed.connect(_on_vocab_ai_example_pressed)
	if btn_gr_ai_example: btn_gr_ai_example.pressed.connect(_on_grammar_ai_example_pressed)

	# Sổ tay sẽ đóng mặc định khi game bắt đầu
	hide()

# ==============================================================================
# PUBLIC API
# ==============================================================================
func toggle_notebook() -> void:
	if visible:
		_on_close_requested()
	else:
		show()
		get_tree().paused = true
		content_ui.hide()
		close_button.hide()
		animation_player.play("open_book")
		await animation_player.animation_finished
		content_ui.show()
		close_button.show()
		_switch_tab(0, false) # No page-turn anim on first open

func _on_close_requested() -> void:
	content_ui.hide()
	close_button.hide()
	animation_player.play_backwards("open_book")
	await animation_player.animation_finished
	hide()
	get_tree().paused = false

# ==============================================================================
# TAB SWITCHING
# ==============================================================================
var _is_switching_tab: bool = false

func _switch_tab(index: int, play_anim: bool = true) -> void:
	if _is_switching_tab:
		return
	if index == current_tab_index and all_tabs[index].visible:
		return

	_is_switching_tab = true

	var old_index := current_tab_index
	current_tab_index = index

	# Hide all, update button styles
	for i in range(all_tabs.size()):
		all_tabs[i].hide()
		_set_tab_btn_active(i, i == index)

	# Page-turn animation
	if play_anim:
		if index > old_index and animation_player.has_animation("turn_page_right"):
			animation_player.play("turn_page_right")
			await animation_player.animation_finished
		elif index < old_index and animation_player.has_animation("turn_page_left"):
			animation_player.play("turn_page_left")
			await animation_player.animation_finished

	all_tabs[index].show()

	match index:
		0: _refresh_vocab_list(search_bar.text)
		1: _refresh_grammar_list()
		2: _init_review_tab()

	_is_switching_tab = false

func _set_tab_btn_active(index: int, active: bool) -> void:
	var btns := [btn_vocab, btn_grammar, btn_review]
	var s := btns[index].get_theme_stylebox("normal") as StyleBoxFlat
	if s:
		s.bg_color = COLOR_ACTIVE if active else COLOR_NORMAL

# ==============================================================================
# TAB 1 — VOCABULARY
# ==============================================================================
func _refresh_vocab_list(query: String) -> void:
	for c in vocab_list.get_children():
		c.queue_free()
	if not progress_manager:
		return

	var raw_list: Array = progress_manager.search_vocab(query, 500)
	var filtered_list := []
	
	var tier_idx = 0
	if get_node_or_null("%TierFilter"): tier_idx = get_node_or_null("%TierFilter").selected
	var status_idx = 0
	if get_node_or_null("%StatusFilter"): status_idx = get_node_or_null("%StatusFilter").selected

	for v in raw_list:
		var enc = v.get("encounter_count", 0) as int
		if enc == 0: continue # Bỏ qua từ chưa từng gặp
		
		var tier = v.get("tier_id", 0) as int
		if tier_idx > 0 and tier != tier_idx: continue
		
		var mast = float(v.get("mastery_score", 0.0))
		var status_str = ""
		var icon_str = ""
		
		if mast > 0.8:
			status_str = "Adept"
			icon_str = "🌟"
		elif mast > 0.5:
			status_str = "Practiced"
			icon_str = "⚔️"
		elif mast > 0.2:
			status_str = "Familiar"
			icon_str = "👁️"
		else:
			status_str = "Stranger"
			icon_str = "💀"
			
		if status_idx == 1 and status_str != "Stranger": continue
		if status_idx == 2 and status_str != "Familiar": continue
		if status_idx == 3 and status_str != "Practiced": continue
		if status_idx == 4 and status_str != "Adept": continue
		
		v["icon_str"] = icon_str
		v["status_str"] = status_str
		filtered_list.append(v)

	vocab_stats.text = "Từ tìm thấy: %d" % filtered_list.size()

	for v in filtered_list:
		var btn := Button.new()
		btn.text        = "%s %s  —  %s" % [v.get("icon_str", ""), v.get("word",""), v.get("meaning","")]
		btn.flat        = true
		btn.alignment   = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0.02, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.05, 0.02, 0.01, 1))
		btn.pressed.connect(func(): _show_vocab_detail(v))
		vocab_list.add_child(btn)

	# Luôn dọn dẹp trang phải khi vừa chuyển tab hoặc tìm kiếm
	det_word.text    = ""
	det_cefr.text    = ""
	det_meaning.text = ""
	det_mastery.text = ""
	if btn_ai_example: btn_ai_example.hide()
	if ai_example_label: ai_example_label.hide()

func _show_vocab_detail(v: Dictionary) -> void:
	current_vocab_detail = v
	if btn_ai_example: btn_ai_example.show()
	if ai_example_label:
		ai_example_label.text = ""
		ai_example_label.show()

	det_word.text    = str(v.get("word", "")).to_upper()
	det_cefr.text    = "[%s]" % str(v.get("cefr_level", "?"))
	det_meaning.text = str(v.get("meaning", ""))

	var enc  := v.get("encounter_count", 0) as int
	var corr := v.get("correct_count",   0) as int
	var mast := float(v.get("mastery_score", 0.0))
	var rank := "%s %s (%.2f)" % [str(v.get("icon_str", "")), str(v.get("status_str", "")).capitalize(), mast]

	det_mastery.text = "Độ thuần thục: %s\nGặp: %d lần  |  Đúng: %d lần" % [rank, enc, corr]

# ==============================================================================
# TAB 2 — GRAMMAR
# ==============================================================================
func _refresh_grammar_list() -> void:
	for c in grammar_list.get_children():
		c.queue_free()
	if not progress_manager or not progress_manager.has_method("get_all_grammar"):
		return

	var list: Array = progress_manager.get_all_grammar()
	for g in list:
		var enc = g.get("encounter_count", 0) as int
		var btn := Button.new()
		btn.flat      = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 15)
		
		if enc == 0:
			btn.text = "[T%d] 🔒 %s" % [g.get("tier_id", 0), g.get("topic_name", "")]
			btn.disabled = true
			btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 0.8))
		else:
			btn.text = "[T%d] %s" % [g.get("tier_id", 0), g.get("topic_name", "")]
			btn.add_theme_color_override("font_color",       Color(0.15, 0.08, 0.02, 1))
			btn.add_theme_color_override("font_hover_color", Color(0.05, 0.02, 0.01, 1))
			btn.pressed.connect(func(): _show_grammar_detail(g))
			
		grammar_list.add_child(btn)

	# Luôn dọn dẹp trang phải khi vừa chuyển tab
	gr_det_title.text       = ""
	gr_det_formula.text     = ""
	gr_det_explanation.text = ""
	if btn_gr_ai_example: btn_gr_ai_example.hide()
	if gr_ai_example_label: gr_ai_example_label.hide()

func _show_grammar_detail(g: Dictionary) -> void:
	current_grammar_detail = g
	if btn_gr_ai_example: btn_gr_ai_example.show()
	if gr_ai_example_label:
		gr_ai_example_label.text = ""
		gr_ai_example_label.show()

	gr_det_title.text       = str(g.get("topic_name",      ""))
	gr_det_formula.text     = "📐 Công thức:\n"    + str(g.get("formula",        ""))
	gr_det_explanation.text = "\n💡 Giải thích:\n" + str(g.get("explanation_vi", ""))

# ==============================================================================
# TAB 3 — REVIEW (Flashcard)
# ==============================================================================
func _init_review_tab() -> void:
	review_started = false
	_reset_flashcard_ui()
	if not progress_manager:
		return

	review_queue   = progress_manager.get_due_review_words(20)
	var cnt        := review_queue.size()
	review_status.text = "🔥 Cần ôn hôm nay: %d từ" % cnt

	# Build the due-word list on the left page
	for c in due_list.get_children():
		c.queue_free()
	for w in review_queue:
		var lbl := Label.new()
		lbl.text = "• " + str(w.get("word", ""))
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.18, 0.1, 0.03, 1))
		due_list.add_child(lbl)

	btn_start_review.visible = cnt > 0
	if cnt == 0:
		flashcard_word.text = "🎉 Tuyệt vời!"
		hint_label.text     = "Hôm nay bạn không có từ nào cần ôn."

func _start_flashcard_session() -> void:
	review_started = true
	btn_start_review.hide()
	_next_flashcard()

func _next_flashcard() -> void:
	review_status.text = "🔥 Còn lại: %d từ" % review_queue.size()

	if review_queue.is_empty():
		flashcard_word.text   = "🎉 Xong!"
		flashcard_meaning.hide()
		hint_label.text       = "Phiên ôn tập hoàn thành. Xuất sắc!"
		btn_ai_hint.hide()
		btn_flip.hide()
		btn_forgot.hide()
		btn_remember.hide()
		return

	current_review_word = review_queue[0]
	is_card_flipped     = false

	flashcard_word.text = str(current_review_word.get("word", "")).to_upper()
	flashcard_meaning.text = ""
	flashcard_meaning.hide()
	hint_label.text = ""
	btn_ai_hint.show()
	btn_flip.show()
	btn_forgot.hide()
	btn_remember.hide()

func _reset_flashcard_ui() -> void:
	flashcard_word.text = "---"
	flashcard_meaning.hide()
	hint_label.text     = ""
	btn_ai_hint.show()
	btn_flip.show()
	btn_forgot.hide()
	btn_remember.hide()

func _on_flip_pressed() -> void:
	is_card_flipped = true
	flashcard_meaning.text = str(current_review_word.get("meaning", ""))
	flashcard_meaning.show()
	btn_flip.hide()
	btn_ai_hint.hide()
	btn_forgot.show()
	btn_remember.show()

func _on_ai_hint_pressed() -> void:
	if not ai_manager:
		hint_label.text = "(AIManager chưa sẵn sàng)"
		return
	hint_label.text = "✨ Elaria đang suy nghĩ..."
	ai_manager.request_npc_hint(
		current_review_word.get("word",    ""),
		current_review_word.get("meaning", "")
	)

func _on_ai_hint_ready(hint_text: String) -> void:
	if current_tab_index == 2 and not is_card_flipped:
		hint_label.text = "💡 " + hint_text

func _submit_review(is_correct: bool) -> void:
	if progress_manager:
		var word_id: int = current_review_word.get("word_id", -1)
		if word_id != -1:
			progress_manager.update_after_answer(word_id, is_correct, false) # Pass false for is_combat
	review_queue.pop_front()
	_next_flashcard()

# ==============================================================================
# AI EXAMPLE HANDLERS
# ==============================================================================
func _on_vocab_ai_example_pressed() -> void:
	if not ai_manager: return
	var word = current_vocab_detail.get("word", "")
	var meaning = current_vocab_detail.get("meaning", "")
	if word.is_empty(): return
	if ai_example_label:
		ai_example_label.text = "✨ Elaria đang suy nghĩ..."
	_ai_example_target = "vocab"
	ai_manager.request_example_sentence(word, meaning, false)

func _on_grammar_ai_example_pressed() -> void:
	if not ai_manager: return
	var topic = current_grammar_detail.get("topic_name", "")
	var formula = current_grammar_detail.get("formula", "")
	if topic.is_empty(): return
	if gr_ai_example_label:
		gr_ai_example_label.text = "✨ Elaria đang suy nghĩ..."
	_ai_example_target = "grammar"
	ai_manager.request_example_sentence(topic, formula, true)

func _on_example_sentence_ready(text: String) -> void:
	if _ai_example_target == "vocab":
		if ai_example_label:
			ai_example_label.text = text
	else:
		if gr_ai_example_label:
			gr_ai_example_label.text = text
