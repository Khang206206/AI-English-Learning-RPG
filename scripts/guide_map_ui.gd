extends CanvasLayer

# ==============================================================================
# guide_map_ui.gd
# 3 tabs: Guide | Map | Monster List
# ==============================================================================

@onready var content_ui: Control = %ContentUI
@onready var close_button: Button = %CloseButton
@onready var background: ColorRect = $ContentUI/Background
@onready var main_panel: Panel = $ContentUI/Panel
@onready var tab_bar: HBoxContainer = $ContentUI/Panel/TabBar
@onready var tabs_root: Control = $ContentUI/Panel/Tabs
@onready var guide_text: RichTextLabel = $ContentUI/Panel/Tabs/TabGuide/GuideText

# Tab Buttons
@onready var btn_guide: Button = %BtnGuide
@onready var btn_map: Button = %BtnMap
@onready var btn_monster: Button = %BtnMonster

# Tabs
@onready var tab_guide: Control = %TabGuide
@onready var tab_map: Control = %TabMap
@onready var tab_monster: Control = %TabMonster

# Map Nodes
@onready var map_container: Control = %MapContainer
@onready var map_monsters_container: Control = %MapMonstersContainer

# Monster List Nodes
@onready var monster_list_container: VBoxContainer = %MonsterListContainer
@onready var mon_name_label: Label = %MonNameLabel
@onready var mon_tier_label: Label = %MonTierLabel
@onready var mon_texture: TextureRect = %MonTexture
@onready var mon_story_label: Label = %MonStoryLabel
@onready var mon_learning_label: Label = %MonLearningLabel
@onready var mon_locked_overlay: ColorRect = %MonLockedOverlay
@onready var scroll_container_map: ScrollContainer = %ScrollContainerMap
@onready var right_detail_panel: Panel = $ContentUI/Panel/Tabs/TabMonster/HBox/RightDetail/Panel

var all_tabs: Array
var current_tab_index := 0
var progress_manager: Node
var header_stats_label: Label
var map_legend_panel: PanelContainer

const COLOR_ACTIVE := Color(0.95, 0.78, 0.36, 1.0)
const COLOR_NORMAL := Color(0.45, 0.32, 0.18, 0.95)
const COLOR_PANEL := Color(0.86, 0.76, 0.56, 1.0)
const COLOR_PANEL_DARK := Color(0.25, 0.16, 0.09, 1.0)
const COLOR_INK := Color(0.13, 0.08, 0.04, 1.0)
const COLOR_MUTED_INK := Color(0.36, 0.25, 0.14, 1.0)
const COLOR_LOCKED := Color(0.13, 0.13, 0.13, 1.0)
const COLOR_DISCOVERED := Color(0.88, 0.68, 0.26, 1.0)
const COLOR_DEFEATED := Color(0.74, 0.10, 0.08, 1.0)
const COLOR_GATED := Color(0.85, 0.66, 0.22, 1.0)
const DEFAULT_MARKER_PATH := "res://icon.svg"
const DEFAULT_SILHOUETTE_PATH := "res://icon.svg"
const DEFAULT_TEXTURE_PATH := "res://icon.svg"

var map_center_offset := Vector2.ZERO

var monster_db = [
	{
		"enemy_id": 1,
		"tier": 1,
		"name": "Slime",
		"asset_key": "slime",
		"pos": Vector2(-232.0, 265.0),
		"portrait_path": "res://assets/textures/guide_map/monsters/slime/portrait.png",
		"marker_path": "res://assets/textures/guide_map/monsters/slime/marker.png",
		"silhouette_path": "res://assets/textures/guide_map/monsters/slime/silhouette.png",
		"story": "Một sinh vật nhầy nhụa thường thấy ở những khu rừng ẩm ướt. Chúng hấp thụ ma lực và kiến thức cơ bản của những nhà mạo hiểm đã ngã xuống.",
		"learning": "Từ vựng A1/A2, Thì hiện tại đơn."
	},
	{
		"enemy_id": 2,
		"tier": 2,
		"name": "Goblin",
		"asset_key": "goblin",
		"pos": Vector2(-52.0, 184.0),
		"portrait_path": "res://assets/textures/guide_map/monsters/goblin/portrait.png",
		"marker_path": "res://assets/textures/guide_map/monsters/goblin/marker.png",
		"silhouette_path": "res://assets/textures/guide_map/monsters/goblin/silhouette.png",
		"story": "Sinh vật nhỏ thó, ranh ma thường đi theo bầy. Goblin thích đánh cắp các mảnh giấy ghi chú ngữ pháp của con người.",
		"learning": "Từ vựng B1, Thì hiện tại tiếp diễn."
	},
	{
		"enemy_id": 3,
		"tier": 3,
		"name": "Wolf",
		"asset_key": "wolf",
		"pos": Vector2(-262.0, 27.0),
		"portrait_path": "res://assets/textures/guide_map/monsters/wolf/portrait.png",
		"marker_path": "res://assets/textures/guide_map/monsters/wolf/marker.png",
		"silhouette_path": "res://assets/textures/guide_map/monsters/wolf/silhouette.png",
		"story": "Sói rừng hung dữ, di chuyển theo bầy.",
		"learning": "Từ vựng B1."
	},
	{
		"enemy_id": 4,
		"tier": 4,
		"name": "Skeleton",
		"asset_key": "skeleton",
		"pos": Vector2(234.0, 250.0),
		"portrait_path": "res://assets/textures/guide_map/monsters/skeleton/portrait.png",
		"marker_path": "res://assets/textures/guide_map/monsters/skeleton/marker.png",
		"silhouette_path": "res://assets/textures/guide_map/monsters/skeleton/silhouette.png",
		"story": "Bộ xương khô được hồi sinh nhờ tà thuật.",
		"learning": "Thì quá khứ đơn."
	},
	{
		"enemy_id": 5,
		"tier": 5,
		"name": "Orc",
		"asset_key": "orc",
		"pos": Vector2(233.0, 57.0),
		"portrait_path": "res://assets/textures/guide_map/monsters/orc/portrait.png",
		"marker_path": "res://assets/textures/guide_map/monsters/orc/marker.png",
		"silhouette_path": "res://assets/textures/guide_map/monsters/orc/silhouette.png",
		"story": "Chiến binh Orc to xác và tàn bạo.",
		"learning": "So sánh hơn, so sánh nhất."
	},
	{
		"enemy_id": 6,
		"tier": 6,
		"name": "Golem",
		"asset_key": "golem",
		"pos": Vector2(-118.0, 95.0),
		"portrait_path": "res://assets/textures/guide_map/monsters/golem/portrait.png",
		"marker_path": "res://assets/textures/guide_map/monsters/golem/marker.png",
		"silhouette_path": "res://assets/textures/guide_map/monsters/golem/silhouette.png",
		"story": "Khối đá khổng lồ được nung nấu bằng phép thuật cổ đại.",
		"learning": "Câu bị động."
	},
	{
		"enemy_id": 7,
		"tier": 7,
		"name": "The Witch",
		"asset_key": "witch",
		"pos": Vector2(-142.0, -174.0),
		"portrait_path": "res://assets/textures/guide_map/monsters/witch/portrait.png",
		"marker_path": "res://assets/textures/guide_map/monsters/witch/marker.png",
		"silhouette_path": "res://assets/textures/guide_map/monsters/witch/silhouette.png",
		"story": "Phù thủy bí ẩn sống sâu trong rừng. Cô ta nắm giữ những công thức câu phức tạp và sẵn sàng trừng phạt những ai sai chính tả.",
		"learning": "Từ vựng B1/B2, Câu điều kiện."
	},
	{
		"enemy_id": 8,
		"tier": 8,
		"name": "Minotaur",
		"asset_key": "minotaur",
		"pos": Vector2(-114.0, -230.0),
		"portrait_path": "res://assets/textures/guide_map/monsters/minotaur/portrait.png",
		"marker_path": "res://assets/textures/guide_map/monsters/minotaur/marker.png",
		"silhouette_path": "res://assets/textures/guide_map/monsters/minotaur/silhouette.png",
		"story": "Quái vật nửa người nửa bò mộng.",
		"learning": "Mệnh đề quan hệ."
	},
	{
		"enemy_id": 9,
		"tier": 9,
		"name": "Demon King",
		"asset_key": "demon_king",
		"pos": Vector2(44.0, -308.0),
		"portrait_path": "res://assets/textures/guide_map/monsters/demon_king/portrait.png",
		"marker_path": "res://assets/textures/guide_map/monsters/demon_king/marker.png",
		"silhouette_path": "res://assets/textures/guide_map/monsters/demon_king/silhouette.png",
		"story": "Chúa tể hắc ám đứng đầu binh đoàn quái vật.",
		"learning": "Câu gián tiếp."
	}
]

var map_loaded: bool = false

func _ready() -> void:
	add_to_group("guide_map_ui")
	progress_manager = get_node_or_null("/root/ProgressManager")
	
	all_tabs = [tab_guide, tab_map, tab_monster]
	_apply_visual_theme()
	_ensure_header()
	_build_guide_tab()
	_ensure_map_legend()
	
	close_button.pressed.connect(_on_close_requested)
	btn_guide.pressed.connect(func(): _switch_tab(0))
	btn_map.pressed.connect(func(): _switch_tab(1))
	btn_monster.pressed.connect(func(): _switch_tab(2))
	if DatabaseManager != null and DatabaseManager.has_signal("enemy_progress_changed") and not DatabaseManager.enemy_progress_changed.is_connected(_on_enemy_progress_changed):
		DatabaseManager.enemy_progress_changed.connect(_on_enemy_progress_changed)
	
	hide()
	
func toggle_guide_map() -> void:
	if visible:
		_on_close_requested()
	else:
		show()
		get_tree().paused = true
		_play_open_animation()
		_switch_tab(0)

func _on_close_requested() -> void:
	hide()
	get_tree().paused = false

func _on_enemy_progress_changed() -> void:
	_update_header_stats()
	if not visible:
		return
	match current_tab_index:
		1:
			_refresh_map_tab()
		2:
			_refresh_monster_tab()

func _switch_tab(index: int) -> void:
	current_tab_index = index
	_update_header_stats()
	
	for i in range(all_tabs.size()):
		all_tabs[i].hide()
		_set_tab_btn_active(i, i == index)
		
	all_tabs[index].show()
	all_tabs[index].modulate.a = 1.0
	
	match index:
		1: _refresh_map_tab()
		2: _refresh_monster_tab()

func _set_tab_btn_active(index: int, active: bool) -> void:
	var btns := [btn_guide, btn_map, btn_monster]
	var btn = btns[index]
	btn.add_theme_color_override("font_color", COLOR_INK if active else Color(0.98, 0.88, 0.65, 1.0))
	btn.add_theme_stylebox_override("normal", _make_stylebox(
		COLOR_ACTIVE if active else COLOR_NORMAL,
		Color(0.25, 0.14, 0.07, 1.0),
		2,
		7,
		Vector4(16, 8, 16, 8)
	))
	btn.add_theme_stylebox_override("hover", _make_stylebox(
		Color(1.0, 0.84, 0.45, 1.0) if active else Color(0.58, 0.41, 0.22, 1.0),
		Color(0.25, 0.14, 0.07, 1.0),
		2,
		7,
		Vector4(16, 8, 16, 8)
	))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(
		Color(0.76, 0.55, 0.22, 1.0),
		Color(0.18, 0.09, 0.04, 1.0),
		2,
		7,
		Vector4(16, 8, 16, 8)
	))

func _make_stylebox(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 6, margins: Vector4 = Vector4.ZERO) -> StyleBoxFlat:
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

func _apply_visual_theme() -> void:
	background.color = Color(0.02, 0.015, 0.01, 0.72)

	main_panel.anchor_left = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -520.0
	main_panel.offset_top = -330.0
	main_panel.offset_right = 520.0
	main_panel.offset_bottom = 330.0
	main_panel.add_theme_stylebox_override("panel", _make_stylebox(
		COLOR_PANEL,
		Color(0.25, 0.13, 0.06, 1.0),
		7,
		8,
		Vector4(0, 0, 0, 0)
	))

	tab_bar.offset_left = 28.0
	tab_bar.offset_top = 92.0
	tab_bar.offset_right = -28.0
	tab_bar.offset_bottom = 134.0
	tab_bar.add_theme_constant_override("separation", 8)

	tabs_root.offset_left = 28.0
	tabs_root.offset_top = 148.0
	tabs_root.offset_right = -28.0
	tabs_root.offset_bottom = -28.0

	scroll_container_map.add_theme_stylebox_override("panel", _make_stylebox(
		Color(0.10, 0.085, 0.065, 1.0),
		Color(0.28, 0.18, 0.10, 1.0),
		3,
		6
	))

	right_detail_panel.add_theme_stylebox_override("panel", _make_stylebox(
		Color(0.93, 0.84, 0.64, 1.0),
		Color(0.38, 0.23, 0.10, 1.0),
		3,
		8,
		Vector4(14, 14, 14, 14)
	))

	monster_list_container.add_theme_constant_override("separation", 8)
	mon_texture.custom_minimum_size = Vector2(128, 128)
	mon_name_label.add_theme_font_size_override("font_size", 30)
	mon_name_label.add_theme_color_override("font_color", COLOR_INK)
	mon_tier_label.add_theme_font_size_override("font_size", 16)
	mon_tier_label.add_theme_color_override("font_color", COLOR_MUTED_INK)
	mon_story_label.add_theme_font_size_override("font_size", 16)
	mon_story_label.add_theme_color_override("font_color", COLOR_INK)
	mon_learning_label.add_theme_font_size_override("font_size", 16)
	mon_learning_label.add_theme_color_override("font_color", COLOR_INK)
	mon_locked_overlay.color = Color(0.03, 0.025, 0.02, 0.66)
	var lock_icon := mon_locked_overlay.get_node_or_null("LockIcon") as Label
	if lock_icon:
		lock_icon.text = "LOCKED"
		lock_icon.add_theme_font_size_override("font_size", 24)
		lock_icon.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48, 1.0))

	close_button.text = "X"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.anchor_left = 1.0
	close_button.anchor_right = 1.0
	close_button.offset_left = -72.0
	close_button.offset_top = 18.0
	close_button.offset_right = -24.0
	close_button.offset_bottom = 58.0
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62, 1.0))
	close_button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.35, 0.12, 0.08, 1.0), Color(0.12, 0.05, 0.03, 1.0), 2, 6))
	close_button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.58, 0.16, 0.10, 1.0), Color(0.12, 0.05, 0.03, 1.0), 2, 6))
	close_button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.22, 0.08, 0.05, 1.0), Color(0.12, 0.05, 0.03, 1.0), 2, 6))

	for btn in [btn_guide, btn_map, btn_monster]:
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 17)

func _ensure_header() -> void:
	var existing = main_panel.get_node_or_null("AtlasHeader")
	if existing:
		header_stats_label = existing.find_child("StatsLabel", true, false) as Label
		_update_header_stats()
		return

	var header = HBoxContainer.new()
	header.name = "AtlasHeader"
	header.anchor_right = 1.0
	header.offset_left = 30.0
	header.offset_top = 20.0
	header.offset_right = -92.0
	header.offset_bottom = 78.0
	header.add_theme_constant_override("separation", 16)
	main_panel.add_child(header)
	main_panel.move_child(header, 0)

	var title_box = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)

	var title = Label.new()
	title.text = "GUIDE MAP"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", COLOR_INK)
	title_box.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Adventure Atlas / Monster Codex"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", COLOR_MUTED_INK)
	title_box.add_child(subtitle)

	var stats_panel = PanelContainer.new()
	stats_panel.custom_minimum_size = Vector2(260, 54)
	stats_panel.add_theme_stylebox_override("panel", _make_stylebox(
		COLOR_PANEL_DARK,
		Color(0.12, 0.07, 0.03, 1.0),
		2,
		7,
		Vector4(12, 8, 12, 8)
	))
	header.add_child(stats_panel)

	header_stats_label = Label.new()
	header_stats_label.name = "StatsLabel"
	header_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_stats_label.add_theme_font_size_override("font_size", 15)
	header_stats_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.66, 1.0))
	stats_panel.add_child(header_stats_label)
	_update_header_stats()

func _update_header_stats() -> void:
	if header_stats_label == null:
		return

	var discovered := 0
	var defeated := 0
	for m in monster_db:
		if DatabaseManager.has_interacted_with_enemy(m.enemy_id):
			discovered += 1
		if DatabaseManager.is_enemy_dead(m.enemy_id):
			defeated += 1

	header_stats_label.text = "Khám phá %d/%d\nĐã hạ %d/%d" % [discovered, monster_db.size(), defeated, monster_db.size()]

func _play_open_animation() -> void:
	content_ui.modulate.a = 0.0
	content_ui.scale = Vector2(0.98, 0.98)
	content_ui.pivot_offset = get_viewport().get_visible_rect().size / 2.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(content_ui, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(content_ui, "scale", Vector2.ONE, 0.12)

func _build_guide_tab() -> void:
	guide_text.hide()
	if tab_guide.get_node_or_null("GuideRows"):
		return

	var scroll = ScrollContainer.new()
	scroll.name = "GuideRows"
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	tab_guide.add_child(scroll)

	var rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)

	var title = Label.new()
	title.text = "Hành trang phiêu lưu"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", COLOR_INK)
	rows.add_child(title)

	var intro = Label.new()
	intro.text = "Theo dấu bản đồ, mở khóa codex quái vật và dùng kiến thức tiếng Anh để vượt qua từng trận đấu."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 16)
	intro.add_theme_color_override("font_color", COLOR_MUTED_INK)
	rows.add_child(intro)

	rows.add_child(_create_guide_row("WASD", "Di chuyển", "Đi qua các khu vực, tìm NPC, đồ vật và quái vật trên bản đồ."))
	rows.add_child(_create_guide_row("F", "Tương tác", "Đứng gần mục tiêu và tương tác để mở khóa thông tin hoặc bắt đầu sự kiện."))
	rows.add_child(_create_guide_row("BATTLE", "Chiến đấu", "Trả lời câu hỏi từ vựng/ngữ pháp chính xác để gây sát thương."))
	rows.add_child(_create_guide_row("GUIDE MAP", "Danh sách quái", "Quái đã gặp sẽ hiện portrait, câu chuyện và nội dung học tập tương ứng."))
	rows.add_child(_create_guide_row("MAP", "Theo dõi tiến độ", "Marker đen là chưa rõ, marker màu là đã gặp, gạch đỏ là đã hạ."))
	rows.add_child(_create_guide_row("NOTEBOOK", "Sổ tay học tập", "Xem lại từ vựng, ngữ pháp và nội dung cần ôn luyện trong hành trình."))
	rows.add_child(_create_guide_row("SETTINGS", "Thiết lập", "Điều chỉnh âm thanh, độ sáng và các tùy chọn trải nghiệm game."))
	rows.add_child(_create_guide_row("SHOP", "Cửa hàng", "Mua vật phẩm và hỗ trợ chiến đấu để chuẩn bị cho các trận khó hơn."))

func _create_guide_row(key_text: String, title_text: String, desc_text: String) -> PanelContainer:
	var row = PanelContainer.new()
	row.add_theme_stylebox_override("panel", _make_stylebox(
		Color(0.94, 0.85, 0.64, 1.0),
		Color(0.45, 0.28, 0.12, 1.0),
		2,
		7,
		Vector4(12, 10, 12, 10)
	))

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	var key_card = PanelContainer.new()
	key_card.custom_minimum_size = Vector2(92, 46)
	key_card.add_theme_stylebox_override("panel", _make_stylebox(
		COLOR_PANEL_DARK,
		Color(0.12, 0.07, 0.03, 1.0),
		2,
		6
	))
	hbox.add_child(key_card)

	var key = Label.new()
	key.text = key_text
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 16)
	key.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62, 1.0))
	key_card.add_child(key)

	var copy = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	hbox.add_child(copy)

	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_INK)
	copy.add_child(title)

	var desc = Label.new()
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", COLOR_MUTED_INK)
	copy.add_child(desc)

	return row

func _ensure_map_legend() -> void:
	if map_legend_panel != null:
		return
	if tab_map.get_node_or_null("MapLegend"):
		map_legend_panel = tab_map.get_node_or_null("MapLegend") as PanelContainer
		return

	map_legend_panel = PanelContainer.new()
	map_legend_panel.name = "MapLegend"
	map_legend_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_legend_panel.anchor_left = 1.0
	map_legend_panel.anchor_right = 1.0
	map_legend_panel.offset_left = -260.0
	map_legend_panel.offset_top = 12.0
	map_legend_panel.offset_right = -14.0
	map_legend_panel.offset_bottom = 112.0
	map_legend_panel.add_theme_stylebox_override("panel", _make_stylebox(
		Color(0.13, 0.09, 0.055, 0.90),
		Color(0.78, 0.57, 0.25, 1.0),
		2,
		7,
		Vector4(12, 8, 12, 8)
	))
	tab_map.add_child(map_legend_panel)

	var rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	map_legend_panel.add_child(rows)

	var title = Label.new()
	title.text = "Legend"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62, 1.0))
	rows.add_child(title)
	rows.add_child(_create_legend_row(Color(0.04, 0.04, 0.04, 1.0), "Chưa khám phá"))
	rows.add_child(_create_legend_row(COLOR_DISCOVERED, "Đã gặp"))
	rows.add_child(_create_legend_row(COLOR_DEFEATED, "Đã hạ"))

func _create_legend_row(color: Color, text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	var swatch = ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(14, 14)
	row.add_child(swatch)

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.68, 1.0))
	row.add_child(label)
	return row

func _resolve_texture_path(primary_path: String, fallback_path: String = "") -> String:
	if primary_path != "" and ResourceLoader.exists(primary_path):
		return primary_path
	if fallback_path != "" and ResourceLoader.exists(fallback_path):
		return fallback_path
	if ResourceLoader.exists(DEFAULT_TEXTURE_PATH):
		return DEFAULT_TEXTURE_PATH
	return ""

func _load_texture_or_null(primary_path: String, fallback_path: String = "") -> Texture2D:
	var resolved_path := _resolve_texture_path(primary_path, fallback_path)
	if resolved_path == "":
		return null
	return load(resolved_path)

func _create_cross_off_overlay(marker_size: int) -> Control:
	var overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.custom_minimum_size = Vector2(marker_size, marker_size)
	overlay.size = Vector2(marker_size, marker_size)

	var line_length = marker_size * 1.35
	var line_thickness = max(4.0, marker_size * 0.14)
	var line_color = Color(1.0, 0.0, 0.0, 0.95)

	for angle in [-45.0, 45.0]:
		var line = ColorRect.new()
		line.color = line_color
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.size = Vector2(line_length, line_thickness)
		line.position = Vector2((marker_size - line_length) / 2.0, (marker_size - line_thickness) / 2.0)
		line.pivot_offset = Vector2(line_length / 2.0, line_thickness / 2.0)
		line.rotation_degrees = angle
		overlay.add_child(line)

	return overlay

func _get_monster_status(m: Dictionary) -> String:
	if DatabaseManager.is_enemy_dead(m.enemy_id):
		return "defeated"
	if DatabaseManager.has_interacted_with_enemy(m.enemy_id):
		return "discovered"
	return "locked"

func _get_status_label(status: String) -> String:
	match status:
		"defeated":
			return "Đã hạ"
		"discovered":
			return "Đã gặp"
		_:
			return "Chưa rõ"

func _get_status_color(status: String) -> Color:
	match status:
		"defeated":
			return COLOR_DEFEATED
		"discovered":
			return COLOR_DISCOVERED
		_:
			return COLOR_LOCKED

func _is_monster_gated(m: Dictionary) -> bool:
	if progress_manager == null:
		return false
	var tier := int(m.get("tier", 1))
	if tier <= 1:
		return false
	if _get_monster_status(m) == "locked":
		return false
	return not progress_manager.can_access_tier(tier)

func _create_marker_frame(marker_size: int, status: String) -> Panel:
	var frame_size = marker_size + 14
	var frame = Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = Vector2(-frame_size / 2.0, -frame_size / 2.0)
	frame.size = Vector2(frame_size, frame_size)
	frame.custom_minimum_size = Vector2(frame_size, frame_size)
	frame.add_theme_stylebox_override("panel", _make_stylebox(
		Color(0.10, 0.065, 0.035, 0.92),
		_get_status_color(status),
		3,
		8
	))
	return frame

func _create_map_marker(m: Dictionary, marker_size: int, status: String) -> Control:
	var marker = Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.custom_minimum_size = Vector2(marker_size, marker_size)
	marker.size = Vector2(marker_size, marker_size)

	var has_interacted = status != "locked"
	var marker_path = m.marker_path if has_interacted else m.silhouette_path
	var marker_fallback = DEFAULT_MARKER_PATH if has_interacted else DEFAULT_SILHOUETTE_PATH
	var marker_texture = _load_texture_or_null(marker_path, marker_fallback)

	if marker_texture != null:
		var tex = TextureRect.new()
		tex.texture = marker_texture
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.position = Vector2(-marker_size / 2.0, -marker_size / 2.0)
		tex.size = Vector2(marker_size, marker_size)
		tex.custom_minimum_size = Vector2(marker_size, marker_size)
		if not has_interacted:
			tex.modulate = Color.BLACK
		marker.add_child(tex)
	else:
		var fallback = Panel.new()
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.position = Vector2(-marker_size / 2.0, -marker_size / 2.0)
		fallback.size = Vector2(marker_size, marker_size)
		fallback.custom_minimum_size = Vector2(marker_size, marker_size)
		fallback.add_theme_stylebox_override("panel", _make_stylebox(_get_status_color(status), Color.WHITE, 2, int(marker_size / 2)))
		marker.add_child(fallback)

	return marker

# ==============================================================================
# MAP TAB
# ==============================================================================

func _refresh_map_tab() -> void:
	_update_header_stats()
	if not map_loaded:
		var map_bg = ColorRect.new()
		map_bg.color = Color(0.08, 0.065, 0.05, 1) # Nền tối cho phần ngoài rìa bản đồ
		map_bg.custom_minimum_size = Vector2(3000, 3000)
		map_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_bg.z_index = -10 # Phải nhỏ hơn -1 để không che lớp Ground
		map_container.add_child(map_bg)
		
		_load_map_layers()
		map_loaded = true
		
	for c in map_monsters_container.get_children():
		c.queue_free()
		
	for m in monster_db:
		var status := _get_monster_status(m)
		var marker_size = 38
		var node = Control.new()
		node.position = m.pos + map_center_offset # Dịch tâm (0,0) về giữa ảnh
		node.z_index = 10 # Đảm bảo quái vật luôn đè lên trên TileMap

		node.add_child(_create_marker_frame(marker_size, status))
		node.add_child(_create_map_marker(m, marker_size, status))
		
		var lbl = Label.new()
		lbl.text = "T%d  %s" % [m.tier, _get_status_label(status)]
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(92, 22)
		lbl.position = Vector2(-46, marker_size/2 + 8)
		node.add_child(lbl)
		
		if status == "defeated":
			var cross = _create_cross_off_overlay(marker_size + 10)
			cross.position = Vector2(-(marker_size + 10) / 2.0, -(marker_size + 10) / 2.0)
			node.add_child(cross)
			
		map_monsters_container.add_child(node)

func _load_map_layers() -> void:
	# Load ảnh tĩnh Map.png thay vì copy TileMapLayer
	var map_tex_path = "res://assets/textures/Chapter 1/Map.png"
	if ResourceLoader.exists(map_tex_path):
		var map_tex = load(map_tex_path)
		var tex_rect = TextureRect.new()
		tex_rect.texture = map_tex
		map_container.add_child(tex_rect)
		
		map_center_offset = map_tex.get_size() / 2.0
		
		# Cập nhật kích thước Map Container theo kích thước thật của ảnh
		map_container.custom_minimum_size = map_tex.get_size()
		
		# Đẩy layer quái vật xuống dưới cùng của danh sách con (vẽ sau cùng -> nổi lên trên ảnh Map)
		map_container.move_child(map_monsters_container, -1)

# ==============================================================================
# MONSTER LIST TAB
# ==============================================================================

func _create_list_item_style(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	style.border_width_left = 5
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.55, 0.36, 0.16, 1)
	return style

func _create_list_item_hover_style(bg_color: Color, status: String) -> StyleBoxFlat:
	var style = _create_list_item_style(bg_color)
	style.border_color = _get_status_color(status)
	return style

func _refresh_monster_tab() -> void:
	_update_header_stats()
	for c in monster_list_container.get_children():
		c.queue_free()
		
	# Mặc định ẩn chi tiết
	mon_name_label.text = ""
	mon_tier_label.text = ""
	mon_story_label.text = ""
	mon_learning_label.text = ""
	mon_texture.texture = null
	mon_locked_overlay.show()
	
	for m in monster_db:
		var status := _get_monster_status(m)
		var is_gated := _is_monster_gated(m)
		var has_interacted = status != "locked"
		var icon_path = m.portrait_path if has_interacted else m.silhouette_path
		var icon_fallback = DEFAULT_TEXTURE_PATH if has_interacted else DEFAULT_SILHOUETTE_PATH
		
		var btn = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 76)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_constant_override("icon_max_width", 50)
		btn.icon = _load_texture_or_null(icon_path, icon_fallback)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		if has_interacted and is_gated:
			btn.text = "  Tier %d  %s\n  LOCKED | Ôn lại Tier %d" % [m.tier, m.name, max(m.tier - 1, 1)]
			btn.add_theme_color_override("font_color", Color(0.26, 0.18, 0.08, 1))
		elif has_interacted:
			btn.text = "  Tier %d  %s\n  %s" % [m.tier, m.name, _get_status_label(status)]
			btn.add_theme_color_override("font_color", Color(0.15, 0.08, 0.02, 1))
		else:
			btn.text = "  Tier %d  ???\n  %s" % [m.tier, _get_status_label(status)]
			btn.add_theme_color_override("font_color", Color(0.32, 0.31, 0.30, 1))
			
		var normal_color = Color(0.58, 0.50, 0.34, 0.74) if is_gated else (Color(0.90, 0.80, 0.58, 0.68) if has_interacted else Color(0.55, 0.52, 0.46, 0.58))
		var hover_color = Color(0.72, 0.61, 0.40, 0.92) if is_gated else (Color(0.98, 0.88, 0.62, 0.94) if has_interacted else Color(0.68, 0.65, 0.58, 0.86))
		var style_normal = _create_list_item_hover_style(normal_color, status)
		var style_hover = _create_list_item_hover_style(hover_color, status)
		if is_gated:
			style_normal.border_color = COLOR_GATED
			style_hover.border_color = COLOR_GATED
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_hover)
		
		btn.pressed.connect(func(): _show_monster_detail(m, has_interacted, is_gated))
		monster_list_container.add_child(btn)

func _show_monster_detail(m: Dictionary, has_interacted: bool, is_gated: bool = false) -> void:
	var status := _get_monster_status(m)
	if has_interacted:
		mon_name_label.text = m.name
		if is_gated:
			mon_locked_overlay.show()
			mon_tier_label.text = "Tier %d  |  LOCKED" % [m.tier]
			mon_story_label.text = "%s\n\nBạn cần đạt lại 30%% mastery ở Tier %d để chiến đấu với quái vật này." % [m.story, max(m.tier - 1, 1)]
			mon_learning_label.text = "Nội dung học tập\n" + m.learning
		else:
			mon_locked_overlay.hide()
			mon_tier_label.text = "Tier %d  |  %s" % [m.tier, _get_status_label(status)]
			mon_story_label.text = m.story
			mon_learning_label.text = "Nội dung học tập\n" + m.learning
		mon_texture.texture = _load_texture_or_null(m.portrait_path, DEFAULT_TEXTURE_PATH)
	else:
		mon_locked_overlay.show()
		mon_name_label.text = "???"
		mon_tier_label.text = "Tier %d  |  %s" % [m.tier, _get_status_label(status)]
		mon_story_label.text = "Nội dung bị khóa. Hãy tìm và tương tác với quái vật này trên bản đồ."
		mon_learning_label.text = ""
		mon_texture.texture = _load_texture_or_null(m.silhouette_path, DEFAULT_SILHOUETTE_PATH)
