extends CanvasLayer

# ==============================================================================
# notebook_ui_v2.gd
# 3-tab notebook: Vocabulary | Grammar | Review (Flashcard + AI hint)
# ==============================================================================

# ── Core nodes ────────────────────────────────────────────────────────────────
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var content_ui: Control               = %ContentUI
@onready var close_button: Button              = %CloseButton
@onready var book_background: Sprite2D         = %BookBackground
@onready var book_margin: MarginContainer      = $ContentUI/BookMargin
@onready var book_layout: VBoxContainer        = $ContentUI/BookMargin/BookLayout
@onready var tab_bar: HBoxContainer            = $ContentUI/BookMargin/BookLayout/TabBar
@onready var content_area: HBoxContainer       = $ContentUI/BookMargin/BookLayout/ContentArea

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
@onready var tier_filter:   OptionButton = %TierFilter
@onready var status_filter: OptionButton = %StatusFilter
@onready var vocab_stats_container: PanelContainer = $ContentUI/BookMargin/BookLayout/ContentArea/TabVocab/LeftPage/VocabStatsContainer

# ── Grammar tab nodes ─────────────────────────────────────────────────────────
@onready var grammar_list:      VBoxContainer = %GrammarList
@onready var gr_det_title:      Label         = %GrDetTitle
@onready var gr_det_formula:    Label         = %GrDetFormula
@onready var gr_det_explanation:Label         = %GrDetExplanation
@onready var grammar_title:     Label         = $ContentUI/BookMargin/BookLayout/ContentArea/TabGrammar/LeftPage/GrammarTitle

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
@onready var card_panel:      PanelContainer = $ContentUI/BookMargin/BookLayout/ContentArea/TabReview/RightPage/CardPanel
@onready var action_row:      HBoxContainer = $ContentUI/BookMargin/BookLayout/ContentArea/TabReview/RightPage/ActionRow

# ── Mini Test Nodes ───────────────────────────────────────────────────────────
@onready var btn_start_mini_test: Button = get_node_or_null("%BtnStartMiniTest")
@onready var mini_test_container: VBoxContainer = get_node_or_null("%MiniTestContainer")
@onready var mt_label_question: Label = get_node_or_null("%MTLabelQuestion")
@onready var mt_mcq_container: VBoxContainer = get_node_or_null("%MTMCQContainer")
@onready var mt_btn_a: Button = get_node_or_null("%MTBtnA")
@onready var mt_btn_b: Button = get_node_or_null("%MTBtnB")
@onready var mt_btn_c: Button = get_node_or_null("%MTBtnC")
@onready var mt_btn_d: Button = get_node_or_null("%MTBtnD")
@onready var mt_text_container: HBoxContainer = get_node_or_null("%MTTextContainer")
@onready var mt_line_edit: LineEdit = get_node_or_null("%MTLineEdit")
@onready var mt_btn_submit_text: Button = get_node_or_null("%MTBtnSubmitText")
@onready var mt_label_result: Label = get_node_or_null("%MTLabelResult")
@onready var mt_label_explanation: Label = get_node_or_null("%MTLabelExplanation")
@onready var mt_btn_next: Button = get_node_or_null("%MTBtnNext")

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
var _reviewed_items_today: Array = []
var current_review_word: Dictionary = {}
var is_card_flipped := false
var review_started := false
var _current_review_type: String = "vocab" # "vocab" or "grammar"

# Mini Test state
var _mini_test_questions: Array = []
var _current_mt_index: int = 0

# AI Example State
var current_vocab_detail: Dictionary = {}
var current_grammar_detail: Dictionary = {}
var _ai_example_target: String = "vocab"

# Style palette
const COLOR_ACTIVE := Color(0.93, 0.74, 0.33, 1.0)
const COLOR_NORMAL := Color(0.52, 0.37, 0.20, 0.94)
const COLOR_PAGE := Color(0.94, 0.86, 0.66, 0.92)
const COLOR_PAGE_SOFT := Color(0.98, 0.91, 0.70, 0.78)
const COLOR_PANEL_DARK := Color(0.24, 0.14, 0.07, 1.0)
const COLOR_INK := Color(0.12, 0.07, 0.03, 1.0)
const COLOR_MUTED_INK := Color(0.38, 0.26, 0.13, 1.0)
const COLOR_GREEN := Color(0.12, 0.38, 0.18, 1.0)
const COLOR_RED := Color(0.62, 0.12, 0.08, 1.0)
const COLOR_BLUE := Color(0.16, 0.25, 0.48, 1.0)
const COLOR_PURPLE := Color(0.32, 0.18, 0.45, 1.0)

# ==============================================================================
func _ready() -> void:
	add_to_group("notebook_ui")
	progress_manager = get_node_or_null("/root/ProgressManager")
	ai_manager       = get_node_or_null("/root/AIManager")

	all_tabs = [tab_vocab, tab_grammar, tab_review]
	_apply_notebook_theme()

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
	
	if btn_gr_ai_example: btn_gr_ai_example.pressed.connect(_on_grammar_ai_example_pressed)

	if ai_manager and ai_manager.has_signal("example_sentence_ready"):
		ai_manager.example_sentence_ready.connect(_on_example_sentence_ready)

	# Mini Test signals
	if btn_start_mini_test:
		btn_start_mini_test.pressed.connect(_on_start_mini_test_pressed)
	if mt_btn_a: mt_btn_a.pressed.connect(func(): _on_mt_mcq_pressed("A"))
	if mt_btn_b: mt_btn_b.pressed.connect(func(): _on_mt_mcq_pressed("B"))
	if mt_btn_c: mt_btn_c.pressed.connect(func(): _on_mt_mcq_pressed("C"))
	if mt_btn_d: mt_btn_d.pressed.connect(func(): _on_mt_mcq_pressed("D"))
	if mt_btn_submit_text: mt_btn_submit_text.pressed.connect(_on_mt_text_submitted)
	if mt_btn_next: mt_btn_next.pressed.connect(_next_mini_test_question)
	
	if ai_manager and ai_manager.has_signal("mini_test_ready"):
		ai_manager.mini_test_ready.connect(_on_mini_test_ready)

	if btn_ai_example: btn_ai_example.pressed.connect(_on_vocab_ai_example_pressed)

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
		
		# Force a full refresh of tab 0 when opening the notebook
		current_tab_index = -1
		_switch_tab(0, false) # No page-turn anim on first open

func _on_close_requested() -> void:
	content_ui.hide()
	close_button.hide()
	animation_player.play_backwards("open_book")
	await animation_player.animation_finished
	hide()
	get_tree().paused = false

# ==============================================================================
# VISUAL THEME
# ==============================================================================
func _make_stylebox(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 7, margins: Vector4 = Vector4.ZERO) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	return style

func _apply_notebook_theme() -> void:
	_align_book_to_viewport()

	book_margin.add_theme_constant_override("margin_left", 30)
	book_margin.add_theme_constant_override("margin_top", 20)
	book_margin.add_theme_constant_override("margin_right", 30)
	book_margin.add_theme_constant_override("margin_bottom", 26)
	book_layout.add_theme_constant_override("separation", 10)
	tab_bar.add_theme_constant_override("separation", 8)
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_theme_constant_override("separation", 0)

	for tab in [tab_vocab, tab_grammar, tab_review]:
		tab.add_theme_constant_override("separation", 168)
	vocab_list.add_theme_constant_override("separation", 7)
	grammar_list.add_theme_constant_override("separation", 7)
	due_list.add_theme_constant_override("separation", 7)
	var filter_bar := get_node_or_null("ContentUI/BookMargin/BookLayout/ContentArea/TabVocab/LeftPage/FilterBar") as HBoxContainer
	if filter_bar:
		filter_bar.add_theme_constant_override("separation", 8)

	for btn in [btn_vocab, btn_grammar, btn_review]:
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(136, 44)
		btn.add_theme_font_size_override("font_size", 18)

	search_bar.custom_minimum_size = Vector2(0, 38)
	search_bar.add_theme_font_size_override("font_size", 15)
	search_bar.add_theme_color_override("font_color", COLOR_INK)
	search_bar.add_theme_color_override("font_placeholder_color", Color(0.55, 0.43, 0.28, 0.95))
	search_bar.add_theme_stylebox_override("normal", _make_stylebox(Color(0.98, 0.91, 0.72, 1.0), Color(0.50, 0.30, 0.12, 1.0), 2, 7, Vector4(12, 7, 12, 7)))
	search_bar.add_theme_stylebox_override("focus", _make_stylebox(Color(1.0, 0.94, 0.76, 1.0), COLOR_ACTIVE, 2, 7, Vector4(12, 7, 12, 7)))

	_style_option_button(tier_filter)
	_style_option_button(status_filter)
	vocab_stats_container.add_theme_stylebox_override("panel", _make_stylebox(COLOR_PANEL_DARK, Color(0.12, 0.07, 0.03, 1.0), 2, 7, Vector4(12, 8, 12, 8)))
	vocab_stats.add_theme_font_size_override("font_size", 15)
	vocab_stats.add_theme_color_override("font_color", Color(0.98, 0.88, 0.64, 1.0))

	_style_detail_labels()
	_style_review_area()
	_style_close_button()

func _align_book_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	book_background.position = Vector2(viewport_size.x * 0.501, viewport_size.y * 0.292)
	book_background.scale = Vector2(viewport_size.x / 248.5, viewport_size.y / 185.15)

	content_ui.anchor_left = 0.0
	content_ui.anchor_top = 0.0
	content_ui.anchor_right = 1.0
	content_ui.anchor_bottom = 1.0
	content_ui.offset_left = max(72.0, viewport_size.x * 0.075)
	content_ui.offset_top = max(42.0, viewport_size.y * 0.075)
	content_ui.offset_right = -max(72.0, viewport_size.x * 0.075)
	content_ui.offset_bottom = -max(48.0, viewport_size.y * 0.085)

func _style_close_button() -> void:
	close_button.text = "X"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.anchor_left = 1.0
	close_button.anchor_top = 0.0
	close_button.anchor_right = 1.0
	close_button.anchor_bottom = 0.0
	close_button.offset_left = -96.0
	close_button.offset_top = 28.0
	close_button.offset_right = -50.0
	close_button.offset_bottom = 68.0
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.80, 1.0))
	close_button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.35, 0.12, 0.08, 1.0), Color(0.12, 0.05, 0.03, 1.0), 2, 6))
	close_button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.58, 0.16, 0.10, 1.0), Color(0.12, 0.05, 0.03, 1.0), 2, 6))
	close_button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.22, 0.08, 0.05, 1.0), Color(0.12, 0.05, 0.03, 1.0), 2, 6))

func _style_option_button(button: OptionButton) -> void:
	if not button:
		return
	button.custom_minimum_size = Vector2(118, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", COLOR_INK)
	button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.95, 0.84, 0.60, 1.0), Color(0.46, 0.28, 0.12, 1.0), 2, 7, Vector4(10, 7, 10, 7)))
	button.add_theme_stylebox_override("hover", _make_stylebox(Color(1.0, 0.90, 0.66, 1.0), Color(0.46, 0.28, 0.12, 1.0), 2, 7, Vector4(10, 7, 10, 7)))
	button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.84, 0.68, 0.42, 1.0), Color(0.32, 0.18, 0.08, 1.0), 2, 7, Vector4(10, 7, 10, 7)))

func _style_action_button(button: Button, variant: String = "primary", min_size: Vector2 = Vector2(112, 40)) -> void:
	if not button:
		return
	var bg := Color(0.58, 0.40, 0.20, 1.0)
	var hover := Color(0.70, 0.49, 0.24, 1.0)
	var text := Color(1.0, 0.90, 0.68, 1.0)
	match variant:
		"accent":
			bg = COLOR_ACTIVE
			hover = Color(1.0, 0.84, 0.45, 1.0)
			text = COLOR_INK
		"success":
			bg = Color(0.20, 0.47, 0.22, 1.0)
			hover = Color(0.28, 0.60, 0.30, 1.0)
		"danger":
			bg = Color(0.60, 0.16, 0.10, 1.0)
			hover = Color(0.76, 0.22, 0.14, 1.0)
		"ai":
			bg = Color(0.38, 0.22, 0.52, 1.0)
			hover = Color(0.50, 0.30, 0.66, 1.0)
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_stylebox_override("normal", _make_stylebox(bg, Color(0.13, 0.07, 0.03, 1.0), 2, 7, Vector4(12, 8, 12, 8)))
	button.add_theme_stylebox_override("hover", _make_stylebox(hover, Color(0.13, 0.07, 0.03, 1.0), 2, 7, Vector4(12, 8, 12, 8)))
	button.add_theme_stylebox_override("pressed", _make_stylebox(bg.darkened(0.18), Color(0.13, 0.07, 0.03, 1.0), 2, 7, Vector4(12, 8, 12, 8)))

func _style_detail_labels() -> void:
	det_word.add_theme_font_size_override("font_size", 42)
	det_word.add_theme_color_override("font_color", COLOR_GREEN)
	det_cefr.add_theme_font_size_override("font_size", 16)
	det_cefr.add_theme_color_override("font_color", COLOR_MUTED_INK)
	det_meaning.add_theme_font_size_override("font_size", 23)
	det_meaning.add_theme_color_override("font_color", COLOR_INK)
	det_mastery.add_theme_font_size_override("font_size", 16)
	det_mastery.add_theme_color_override("font_color", COLOR_RED)
	if ai_example_label:
		ai_example_label.add_theme_font_size_override("font_size", 15)
		ai_example_label.add_theme_color_override("font_color", COLOR_GREEN)

	grammar_title.text = "Ngữ pháp đã mở"
	grammar_title.add_theme_font_size_override("font_size", 20)
	grammar_title.add_theme_color_override("font_color", COLOR_PURPLE)
	gr_det_title.add_theme_font_size_override("font_size", 30)
	gr_det_title.add_theme_color_override("font_color", COLOR_BLUE)
	gr_det_formula.add_theme_font_size_override("font_size", 18)
	gr_det_formula.add_theme_color_override("font_color", COLOR_RED)
	gr_det_explanation.add_theme_font_size_override("font_size", 16)
	gr_det_explanation.add_theme_color_override("font_color", COLOR_INK)
	if gr_ai_example_label:
		gr_ai_example_label.add_theme_font_size_override("font_size", 15)
		gr_ai_example_label.add_theme_color_override("font_color", COLOR_GREEN)

	_style_action_button(btn_ai_example, "ai", Vector2(128, 42))
	_style_action_button(btn_gr_ai_example, "ai", Vector2(128, 42))

func _style_review_area() -> void:
	review_status.add_theme_font_size_override("font_size", 19)
	review_status.add_theme_color_override("font_color", COLOR_RED)
	card_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.98, 0.92, 0.73, 0.96), Color(0.48, 0.30, 0.14, 1.0), 3, 9, Vector4(24, 22, 24, 22)))
	flashcard_word.add_theme_font_size_override("font_size", 44)
	flashcard_word.add_theme_color_override("font_color", COLOR_INK)
	flashcard_meaning.add_theme_font_size_override("font_size", 23)
	flashcard_meaning.add_theme_color_override("font_color", COLOR_GREEN)
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", COLOR_PURPLE)
	action_row.add_theme_constant_override("separation", 10)
	_style_action_button(btn_start_review, "accent", Vector2(160, 42))
	_style_action_button(btn_ai_hint, "ai", Vector2(100, 40))
	_style_action_button(btn_flip, "accent", Vector2(104, 40))
	_style_action_button(btn_forgot, "danger", Vector2(92, 40))
	_style_action_button(btn_remember, "success", Vector2(104, 40))
	_style_action_button(btn_start_mini_test, "accent", Vector2(154, 40))
	_style_mini_test_controls()

func _style_mini_test_controls() -> void:
	if not mini_test_container:
		return
	mini_test_container.add_theme_constant_override("separation", 9)
	if mt_label_question:
		mt_label_question.add_theme_font_size_override("font_size", 18)
		mt_label_question.add_theme_color_override("font_color", COLOR_INK)
	for btn in [mt_btn_a, mt_btn_b, mt_btn_c, mt_btn_d]:
		_style_action_button(btn, "primary", Vector2(0, 38))
		if btn:
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if mt_line_edit:
		mt_line_edit.custom_minimum_size = Vector2(0, 38)
		mt_line_edit.add_theme_font_size_override("font_size", 15)
		mt_line_edit.add_theme_color_override("font_color", COLOR_INK)
		mt_line_edit.add_theme_color_override("font_uneditable_color", COLOR_INK)
		mt_line_edit.add_theme_color_override("font_placeholder_color", Color(0.48, 0.36, 0.20, 0.85))
		mt_line_edit.add_theme_color_override("caret_color", COLOR_INK)
		mt_line_edit.add_theme_color_override("selection_color", Color(0.93, 0.74, 0.33, 0.45))
		mt_line_edit.add_theme_stylebox_override("normal", _make_stylebox(Color(0.98, 0.91, 0.72, 1.0), Color(0.50, 0.30, 0.12, 1.0), 2, 7, Vector4(10, 7, 10, 7)))
		mt_line_edit.add_theme_stylebox_override("focus", _make_stylebox(Color(1.0, 0.94, 0.76, 1.0), COLOR_ACTIVE, 2, 7, Vector4(10, 7, 10, 7)))
		mt_line_edit.add_theme_stylebox_override("read_only", _make_stylebox(Color(0.86, 0.80, 0.62, 1.0), Color(0.46, 0.38, 0.25, 1.0), 2, 7, Vector4(10, 7, 10, 7)))
	if mt_btn_submit_text:
		_style_action_button(mt_btn_submit_text, "accent", Vector2(96, 38))
	if mt_label_explanation:
		mt_label_explanation.add_theme_font_size_override("font_size", 14)
		mt_label_explanation.add_theme_color_override("font_color", COLOR_GREEN)
	if mt_btn_next:
		_style_action_button(mt_btn_next, "accent", Vector2(100, 38))

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
	_style_tab_button(btns[index], active)

func _update_tab_style(s: StyleBoxFlat, active: bool) -> void:
	if s:
		s.bg_color = COLOR_ACTIVE if active else COLOR_NORMAL

func _style_tab_button(button: Button, active: bool) -> void:
	button.add_theme_color_override("font_color", COLOR_INK if active else Color(0.98, 0.88, 0.66, 1.0))
	button.add_theme_color_override("font_hover_color", COLOR_INK if active else Color(1.0, 0.92, 0.74, 1.0))
	button.add_theme_stylebox_override("normal", _make_stylebox(
		COLOR_ACTIVE if active else COLOR_NORMAL,
		Color(0.24, 0.13, 0.06, 1.0),
		2,
		8,
		Vector4(16, 8, 16, 8)
	))
	button.add_theme_stylebox_override("hover", _make_stylebox(
		Color(1.0, 0.84, 0.45, 1.0) if active else Color(0.62, 0.43, 0.22, 1.0),
		Color(0.24, 0.13, 0.06, 1.0),
		2,
		8,
		Vector4(16, 8, 16, 8)
	))
	button.add_theme_stylebox_override("pressed", _make_stylebox(
		Color(0.76, 0.55, 0.22, 1.0),
		Color(0.16, 0.08, 0.04, 1.0),
		2,
		8,
		Vector4(16, 8, 16, 8)
	))

func _create_list_item_style(bg_color: Color) -> StyleBoxFlat:
	var style = _make_stylebox(bg_color, Color(0.55, 0.38, 0.18, 1), 1, 7, Vector4(12, 9, 12, 9))
	style.border_width_left = 4
	return style

func _create_status_list_style(bg_color: Color, status_color: Color) -> StyleBoxFlat:
	var style = _create_list_item_style(bg_color)
	style.border_color = status_color
	return style

func _get_mastery_color(status: String) -> Color:
	match status:
		"Adept":
			return Color(0.88, 0.68, 0.20, 1.0)
		"Practiced":
			return Color(0.20, 0.48, 0.76, 1.0)
		"Familiar":
			return Color(0.27, 0.52, 0.30, 1.0)
		_:
			return Color(0.52, 0.20, 0.16, 1.0)

func _trim_for_list(value: String, max_length: int = 42) -> String:
	if value.length() <= max_length:
		return value
	return value.substr(0, max_length - 3) + "..."

func _create_due_review_row(item: Dictionary) -> PanelContainer:
	var is_grammar := str(item.get("_review_type", "vocab")) == "grammar"
	var row = PanelContainer.new()
	row.add_theme_stylebox_override("panel", _make_stylebox(
		Color(0.91, 0.81, 0.60, 0.58),
		COLOR_PURPLE if is_grammar else COLOR_GREEN,
		1,
		7,
		Vector4(10, 7, 10, 7)
	))

	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_INK)
	if is_grammar:
		label.text = "Grammar  |  " + _trim_for_list(str(item.get("topic_name", "")), 36)
	else:
		label.text = "Vocab  |  " + _trim_for_list(str(item.get("word", "")), 38)
	row.add_child(label)
	return row

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

	var total_words = progress_manager.get_total_vocab_count() if progress_manager.has_method("get_total_vocab_count") else raw_list.size()
	var base_text = "Từ tìm thấy: %d/%d" % [filtered_list.size(), total_words]
	
	var mastery_text = ""
	if progress_manager.has_method("get_tier_avg_mastery") and progress_manager.has_method("get_global_avg_mastery"):
		var avg = 0.0
		if tier_idx > 0:
			avg = progress_manager.get_tier_avg_mastery(tier_idx)
			mastery_text = "  |  Độ thuần thục Tier %d: %d%%" % [tier_idx, round(avg * 100)]
		else:
			avg = progress_manager.get_global_avg_mastery()
			mastery_text = "  |  Độ thuần thục tổng: %d%%" % round(avg * 100)
			
	vocab_stats.text = base_text + mastery_text

	for v in filtered_list:
		var btn := Button.new()
		var status := str(v.get("status_str", "Stranger"))
		var status_color := _get_mastery_color(status)
		var word := str(v.get("word", ""))
		var meaning := _trim_for_list(str(v.get("meaning", "")), 46)
		var tier := int(v.get("tier_id", 0))
		var cefr := str(v.get("cefr_level", "?"))
		btn.text = "%s  %s  [%s]\nT%d  %s  -  %s" % [v.get("icon_str", ""), word, cefr, tier, status, meaning]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 62)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0.02, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.05, 0.02, 0.01, 1))
		
		var style_normal = _create_status_list_style(Color(0.90, 0.80, 0.58, 0.52), status_color)
		var style_hover = _create_status_list_style(Color(0.98, 0.88, 0.62, 0.90), status_color)
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_hover)
		
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

	det_word.text = str(v.get("word", "")).to_upper()
	det_cefr.text = "CEFR  %s  |  Tier %s" % [str(v.get("cefr_level", "?")), str(v.get("tier_id", "?"))]
	det_meaning.text = "Nghĩa\n" + str(v.get("meaning", ""))

	var enc  := v.get("encounter_count", 0) as int
	var corr := v.get("correct_count",   0) as int
	var mast := float(v.get("mastery_score", 0.0))
	var rank := "%s %s (%.2f)" % [str(v.get("icon_str", "")), str(v.get("status_str", "")).capitalize(), mast]

	det_mastery.text = "Độ thuần thục\n%s\nGặp: %d lần  |  Đúng: %d lần" % [rank, enc, corr]

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
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 58)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 16)
		
		if enc == 0:
			btn.text = "T%d  Locked\n%s" % [g.get("tier_id", 0), _trim_for_list(str(g.get("topic_name", "")), 44)]
			btn.disabled = true
			btn.add_theme_color_override("font_disabled_color", Color(0.34, 0.32, 0.28, 0.86))
			var style_disabled = _create_status_list_style(Color(0.62, 0.58, 0.50, 0.44), Color(0.22, 0.22, 0.20, 1.0))
			btn.add_theme_stylebox_override("disabled", style_disabled)
		else:
			var topic := _trim_for_list(str(g.get("topic_name", "")), 44)
			btn.text = "T%d  Unlocked\n%s" % [g.get("tier_id", 0), topic]
			btn.add_theme_color_override("font_color",       Color(0.15, 0.08, 0.02, 1))
			btn.add_theme_color_override("font_hover_color", Color(0.05, 0.02, 0.01, 1))
			
			var style_normal = _create_status_list_style(Color(0.90, 0.80, 0.58, 0.52), COLOR_BLUE)
			var style_hover = _create_status_list_style(Color(0.98, 0.88, 0.62, 0.90), COLOR_BLUE)
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_hover)
			btn.add_theme_stylebox_override("pressed", style_hover)
			
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

	gr_det_title.text = str(g.get("topic_name", ""))
	gr_det_formula.text = "Công thức\n" + str(g.get("formula", ""))
	
	var enc = g.get("encounter_count", 0) as int
	var corr = g.get("correct_count", 0) as int
	var mast = 0.0
	if enc > 0:
		mast = float(corr) / float(enc)
	var progress_str = "\n\nTiến độ: Gặp %d lần  |  Đúng %d lần  |  Độ thuần thục: %d%%" % [enc, corr, round(mast * 100)]
	
	gr_det_explanation.text = "Giải thích\n" + str(g.get("explanation_vi", "")) + progress_str

# ==============================================================================
# TAB 3 — REVIEW (Flashcard)
# ==============================================================================
func _init_review_tab() -> void:
	review_started = false
	_reviewed_items_today.clear()
	_reset_flashcard_ui()
	if not progress_manager:
		return

	# Lấy cả từ vựng lẫn ngữ pháp cần ôn
	var vocab_due: Array = progress_manager.get_due_review_words(20)
	var grammar_due: Array = []
	if progress_manager.has_method("get_due_review_grammar"):
		grammar_due = progress_manager.get_due_review_grammar(10)

	# Đánh dấu loại và gộp vào hàng đợi chung
	for v in vocab_due:
		v["_review_type"] = "vocab"
	for g in grammar_due:
		g["_review_type"] = "grammar"

	review_queue = vocab_due + grammar_due
	review_queue.shuffle()

	var cnt := review_queue.size()
	var vocab_cnt := vocab_due.size()
	var grammar_cnt := grammar_due.size()
	var reviewed_today = progress_manager.get_reviewed_today_count() if progress_manager.has_method("get_reviewed_today_count") else 0
	review_status.text = "🔥 Cần ôn hôm nay: %d từ + %d ngữ pháp\n✅ Đã ôn: %d" % [vocab_cnt, grammar_cnt, reviewed_today]

	# Xây dựng danh sách bên trái
	for c in due_list.get_children():
		c.queue_free()
	for item in review_queue:
		due_list.add_child(_create_due_review_row(item))

	btn_start_review.visible = cnt > 0
	if cnt == 0:
		flashcard_word.text = "🎉 Tuyệt vời!"
		if reviewed_today > 0:
			hint_label.text = "Bạn đã ôn tập toàn bộ nội dung của hôm nay."
		else:
			hint_label.text = "Hôm nay bạn không có nội dung nào cần ôn."
		btn_ai_hint.hide()
		btn_flip.hide()
	else:
		_prepare_current_flashcard()

func _start_flashcard_session() -> void:
	review_started = true
	btn_start_review.hide()
	_next_flashcard()

func _next_flashcard() -> void:
	var reviewed_today = progress_manager.get_reviewed_today_count() if progress_manager and progress_manager.has_method("get_reviewed_today_count") else 0
	review_status.text = "🔥 Còn lại: %d\n✅ Đã ôn hôm nay: %d" % [review_queue.size(), reviewed_today]

	if review_queue.is_empty():
		flashcard_word.text   = "🎉 Xong!"
		flashcard_meaning.hide()
		hint_label.text       = "Phiên ôn tập hoàn thành. Xuất sắc!"
		btn_ai_hint.hide()
		btn_flip.hide()
		btn_forgot.hide()
		btn_remember.hide()
		if btn_start_mini_test and _reviewed_items_today.size() > 0:
			btn_start_mini_test.show()
		return

	_prepare_current_flashcard()

func _prepare_current_flashcard() -> void:
	if review_queue.is_empty():
		return

	current_review_word = review_queue[0]
	_current_review_type = current_review_word.get("_review_type", "vocab")
	is_card_flipped = false

	if _current_review_type == "grammar":
		flashcard_word.text = str(current_review_word.get("topic_name", "")).to_upper()
		flashcard_meaning.text = ""
	else:
		flashcard_word.text = str(current_review_word.get("word", "")).to_upper()
		flashcard_meaning.text = ""

	flashcard_word.show()
	flashcard_meaning.hide()
	hint_label.text = ""
	btn_ai_hint.show()
	btn_flip.show()
	btn_forgot.hide()
	btn_remember.hide()

func _reset_flashcard_ui() -> void:
	card_panel.show()
	action_row.show()
	flashcard_word.show()
	flashcard_word.text = "---"
	flashcard_meaning.hide()
	hint_label.show()
	hint_label.text     = ""
	btn_ai_hint.hide()
	btn_flip.hide()
	btn_forgot.hide()
	btn_remember.hide()
	if btn_start_mini_test:
		btn_start_mini_test.hide()
	if mini_test_container:
		mini_test_container.hide()

func _on_flip_pressed() -> void:
	if current_review_word.is_empty():
		_prepare_current_flashcard()
		if current_review_word.is_empty():
			return

	is_card_flipped = true
	if _current_review_type == "grammar":
		# Mặt sau: Công thức + giải thích
		var formula = str(current_review_word.get("formula", ""))
		var explanation = str(current_review_word.get("explanation_vi", ""))
		flashcard_meaning.text = "📐 %s\n\n%s" % [formula, explanation]
	else:
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
	if _current_review_type == "grammar":
		ai_manager.request_npc_hint(
			current_review_word.get("topic_name", ""),
			current_review_word.get("formula",    "")
		)
	else:
		ai_manager.request_npc_hint(
			current_review_word.get("word",    ""),
			current_review_word.get("meaning", "")
		)

func _on_ai_hint_ready(hint_text: String) -> void:
	if current_tab_index == 2 and not is_card_flipped:
		hint_label.text = "💡 " + hint_text

func _submit_review(is_correct: bool) -> void:
	if progress_manager:
		if _current_review_type == "grammar":
			var grammar_id: int = current_review_word.get("grammar_id", -1)
			if grammar_id != -1:
				progress_manager.update_grammar_after_answer(grammar_id, is_correct, false)
		else:
			var word_id: int = current_review_word.get("word_id", -1)
			if word_id != -1:
				progress_manager.update_after_answer(word_id, is_correct, false)
	
	var item_copy = current_review_word.duplicate()
	item_copy["_was_forgotten"] = not is_correct
	_reviewed_items_today.append(item_copy)
	
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

# ==============================================================================
# MINI TEST LOGIC
# ==============================================================================

func _on_start_mini_test_pressed() -> void:
	btn_start_mini_test.hide()
	flashcard_word.text = "⏳ Đang tạo\nbài kiểm tra..."
	hint_label.text = "Elaria đang chuẩn bị câu hỏi, vui lòng đợi..."
	
	# Chọn 1 Vocab và 1 Grammar từ _reviewed_items_today
	var vocabs = []
	var grammars = []
	for item in _reviewed_items_today:
		if item.has("word_id"):
			vocabs.append(item)
		elif item.has("grammar_id"):
			grammars.append(item)
	
	# Ưu tiên "_was_forgotten"
	vocabs.sort_custom(func(a, b): return a.get("_was_forgotten", false) and not b.get("_was_forgotten", false))
	grammars.sort_custom(func(a, b): return a.get("_was_forgotten", false) and not b.get("_was_forgotten", false))
	
	var v_item = vocabs[0] if vocabs.size() > 0 else {"word": "hello", "meaning": "xin chào"}
	var g_item = grammars[0] if grammars.size() > 0 else {"topic_name": "Present Simple", "formula": "S + V(s/es)"}
	
	if ai_manager and ai_manager.has_method("request_mini_test"):
		ai_manager.request_mini_test(v_item, g_item)
	else:
		flashcard_word.text = "❌ Lỗi hệ thống"

func _on_mini_test_ready(questions: Array) -> void:
	if questions.is_empty():
		flashcard_word.text = "❌ AI không phản hồi."
		hint_label.text = "Vui lòng thử lại sau."
		btn_start_mini_test.show()
		return
	
	_mini_test_questions = questions
	_current_mt_index = 0
	
	# Hide flashcard elements
	card_panel.hide()
	action_row.hide()
	flashcard_word.hide()
	flashcard_meaning.hide()
	hint_label.hide()
	
	# Show Mini Test UI
	mini_test_container.show()
	_show_mini_test_question(_current_mt_index)

func _show_mini_test_question(index: int) -> void:
	if index >= _mini_test_questions.size():
		_finish_mini_test()
		return
	
	var q = _mini_test_questions[index]
	mt_label_question.text = "Câu %d: " % (index + 1) + q.get("question", "")
	
	mt_label_result.hide()
	mt_label_explanation.hide()
	mt_btn_next.hide()
	
	if q.get("type", "mcq") == "mcq":
		mt_mcq_container.show()
		mt_text_container.hide()
		mt_btn_a.text = "A. " + q.get("A", "")
		mt_btn_b.text = "B. " + q.get("B", "")
		mt_btn_c.text = "C. " + q.get("C", "")
		mt_btn_d.text = "D. " + q.get("D", "")
		mt_btn_a.disabled = false
		mt_btn_b.disabled = false
		mt_btn_c.disabled = false
		mt_btn_d.disabled = false
	else:
		mt_mcq_container.hide()
		mt_text_container.show()
		mt_line_edit.text = ""
		mt_line_edit.editable = true
		mt_btn_submit_text.disabled = false

func _on_mt_mcq_pressed(option: String) -> void:
	mt_btn_a.disabled = true
	mt_btn_b.disabled = true
	mt_btn_c.disabled = true
	mt_btn_d.disabled = true
	_handle_mini_test_answer(option)

func _on_mt_text_submitted() -> void:
	var ans = mt_line_edit.text.strip_edges()
	if ans.is_empty(): return
	mt_line_edit.editable = false
	mt_btn_submit_text.disabled = true
	_handle_mini_test_answer(ans)

func _handle_mini_test_answer(user_ans: String) -> void:
	var q = _mini_test_questions[_current_mt_index]
	var correct_ans = str(q.get("correct_answer", "")).strip_edges()
	
	var is_correct = false
	if q.get("type", "mcq") == "mcq":
		is_correct = (user_ans.to_upper() == correct_ans.to_upper())
	else:
		is_correct = (user_ans.to_lower() == correct_ans.to_lower())
	
	mt_label_result.show()
	if is_correct:
		mt_label_result.text = "✅ ĐÚNG!"
		mt_label_result.add_theme_color_override("font_color", Color(0.1, 0.6, 0.1))
	else:
		mt_label_result.text = "❌ SAI! Đáp án đúng: " + correct_ans
		mt_label_result.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	
	mt_label_explanation.text = q.get("explanation", "")
	mt_label_explanation.show()
	mt_btn_next.show()
	
	# Update SRS Database
	if progress_manager:
		var item_id = q.get("item_id", -1)
		var item_type = q.get("item_type", "vocab")
		if item_id != -1:
			if item_type == "grammar":
				progress_manager.update_grammar_after_answer(item_id, is_correct, false)
			else:
				progress_manager.update_after_answer(item_id, is_correct, false)

func _next_mini_test_question() -> void:
	_current_mt_index += 1
	_show_mini_test_question(_current_mt_index)

func _finish_mini_test() -> void:
	mini_test_container.hide()
	card_panel.show()
	action_row.show()
	flashcard_word.show()
	flashcard_meaning.hide()
	hint_label.show()
	
	flashcard_word.text = "🎉 Tuyệt vời!"
	hint_label.text = "Bạn đã ôn tập toàn bộ nội dung của hôm nay."
	
	btn_ai_hint.hide()
	btn_flip.hide()
	btn_forgot.hide()
	btn_remember.hide()
