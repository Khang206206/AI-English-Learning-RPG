extends Control

# ĐƯỜNG DẪN NODE 
@onready var item_grid = $Background/MarginContainer/VBoxContainer/Body/ItemGrid
@onready var tab_spell = $Background/MarginContainer/VBoxContainer/Header/HeaderContainer/TabContainer/TabSpell
@onready var tab_item = $Background/MarginContainer/VBoxContainer/Header/HeaderContainer/TabContainer/TabItem
@onready var close_button = $Background/MarginContainer/VBoxContainer/Header/HeaderContainer/CloseButton
# Khai báo UI Gold (Phần người dùng cần thêm node trong Design)
@onready var gold_label = $Background/MarginContainer/VBoxContainer/Header/GoldLabel

@onready var desc_overlay = $DescriptionOverlay
@onready var name_label = $DescriptionOverlay/ContentPanel/NameLabel
@onready var desc_label = $DescriptionOverlay/ContentPanel/DescLabel


signal closed
const SHOP_ITEM_SCENE = preload("res://scenes/shopItem.tscn")

const COLOR_INK := Color(0.13, 0.07, 0.03, 1.0)
const COLOR_GOLD := Color(1.0, 0.83, 0.28, 1.0)
const COLOR_PANEL := Color(0.94, 0.84, 0.58, 1.0)
const COLOR_DARK := Color(0.19, 0.10, 0.05, 1.0)
const COLOR_GREEN := Color(0.29, 0.66, 0.45, 1.0)

var is_spell_tab_active := true

func _ready():
	_apply_shop_theme()
	if not get_viewport().size_changed.is_connected(_center_shop):
		get_viewport().size_changed.connect(_center_shop)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	# Kết nối sự kiện để đóng bảng khi bấm vào vùng nền overlay
	desc_overlay.gui_input.connect(_on_overlay_input)
	desc_overlay.hide()
	
	if tab_spell == null or tab_item == null or close_button == null:
		push_error("LỖI: Một trong các Node điều khiển của Shop bị NULL. Hãy kiểm tra lại cây Node!")
		return
		
	tab_spell.pressed.connect(_on_tab_spell_pressed)
	tab_item.pressed.connect(_on_tab_item_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	_update_gold_display()
	_load_items_into_grid(_get_spell_list())
	_update_tab_visuals(true)

func _on_visibility_changed() -> void:
	if visible:
		_center_shop()
		_refresh_current_tab()

func _make_stylebox(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 8, margins: Vector4 = Vector4.ZERO) -> StyleBoxFlat:
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

func _apply_shop_theme() -> void:
	scale = Vector2.ONE
	custom_minimum_size = Vector2(720, 610)
	_center_shop()

	var margin = $Background/MarginContainer
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 34)

	var main_vbox = $Background/MarginContainer/VBoxContainer
	main_vbox.add_theme_constant_override("separation", 18)

	var header = $Background/MarginContainer/VBoxContainer/Header
	header.custom_minimum_size = Vector2(0, 86)

	var header_container = $Background/MarginContainer/VBoxContainer/Header/HeaderContainer
	header_container.offset_left = 0
	header_container.offset_top = 0
	header_container.offset_right = 0
	header_container.offset_bottom = 0
	header_container.add_theme_constant_override("separation", 18)

	var tab_container = $Background/MarginContainer/VBoxContainer/Header/HeaderContainer/TabContainer
	tab_container.add_theme_constant_override("separation", 10)

	for tab in [tab_spell, tab_item]:
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(134, 54)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tab.add_theme_font_size_override("font_size", 18)
		tab.add_theme_color_override("font_color", COLOR_INK)
		tab.add_theme_color_override("font_hover_color", COLOR_INK)

	if gold_label.get_parent() != header_container:
		gold_label.get_parent().remove_child(gold_label)
		header_container.add_child(gold_label)
		header_container.move_child(gold_label, 1)
	gold_label.custom_minimum_size = Vector2(190, 54)
	gold_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	gold_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.03, 1.0))
	gold_label.add_theme_constant_override("outline_size", 4)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(54, 54)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var body = $Background/MarginContainer/VBoxContainer/Body
	body.add_theme_constant_override("margin_left", 46)
	body.add_theme_constant_override("margin_top", 28)
	body.add_theme_constant_override("margin_right", 46)
	body.add_theme_constant_override("margin_bottom", 28)

	item_grid.columns = 2
	item_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 56)
	item_grid.add_theme_constant_override("v_separation", 28)

	var content_panel = $DescriptionOverlay/ContentPanel
	content_panel.custom_minimum_size = Vector2(220, 170)
	content_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.96, 0.86, 0.62, 1.0), Color(0.36, 0.20, 0.10, 1.0), 3, 8, Vector4(12, 10, 12, 10)))
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = 14
	name_label.offset_top = 10
	name_label.offset_right = -14
	name_label.offset_bottom = 36
	name_label.scale = Vector2.ONE
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", COLOR_INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	desc_label.offset_left = 14
	desc_label.offset_top = 42
	desc_label.offset_right = -14
	desc_label.offset_bottom = -12
	desc_label.scale = Vector2.ONE
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", COLOR_INK)

func _center_shop() -> void:
	var viewport_size = get_viewport_rect().size
	var target_size = Vector2(720, 610)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = (viewport_size - target_size) / 2.0
	size = target_size

func _update_gold_display():
	if gold_label != null:
		gold_label.text = "💰 Gold: %d" % DatabaseManager.get_gold()

func _get_spell_list() -> Array:
	DatabaseManager.db.query_with_bindings("""
		SELECT d.item_id, d.name, d.description, d.item_type, d.price,
		       COALESCE(i.quantity, 0) AS owned
		FROM Item_Dict d
		LEFT JOIN Player_Inventory i ON d.item_id = i.item_id AND i.save_id = ?
		WHERE d.item_type = 'spell'
		ORDER BY d.item_id ASC;
	""", [DatabaseManager.CURRENT_SAVE_SLOT])
	
	var result = []
	var icon_map = {
		"Hỏa Cầu": "res://resources/items/fire.tres",
		"Băng Tiễn": "res://resources/items/ice.tres",
		"Sét Đánh": "res://resources/items/electric.tres",
		"Gỗ Xưa": "res://resources/items/wood.tres",
	}
	
	for row in DatabaseManager.db.query_result:
		result.append({
			"item_id": row["item_id"],
			"name": row["name"],
			"icon_path": icon_map.get(row["name"], "res://resources/items/fire.tres"),
			"price": row["price"],
			"description": row["description"],
			"owned": row["owned"],
			"type": "spell",
		})
	return result

func _get_item_list() -> Array:
	DatabaseManager.db.query_with_bindings("""
		SELECT d.item_id, d.name, d.description, d.item_type, d.price,
		       COALESCE(i.quantity, 0) AS owned
		FROM Item_Dict d
		LEFT JOIN Player_Inventory i ON d.item_id = i.item_id AND i.save_id = ?
		WHERE d.item_type != 'spell'
		ORDER BY d.item_id ASC;
	""", [DatabaseManager.CURRENT_SAVE_SLOT])
	
	var result = []
	var icon_map = {
		"potion": "res://resources/items/hp.tres",
		"fifty_fifty": "res://resources/items/50_50.tres",
		"skip": "res://resources/items/skip.tres",
		"time_freeze": "res://resources/items/time_freeze.tres",
	}
	
	for row in DatabaseManager.db.query_result:
		result.append({
			"item_id": row["item_id"],
			"name": row["name"],
			"icon_path": icon_map.get(row["item_type"], "res://resources/items/hp.tres"),
			"price": row["price"],
			"description": row["description"],
			"owned": row["owned"],
			"type": "item",
		})
	return result

func _on_close_pressed():
	emit_signal("closed")
	visible = false

func _on_tab_spell_pressed():
	is_spell_tab_active = true
	_load_items_into_grid(_get_spell_list())
	_update_tab_visuals(true)

func _on_tab_item_pressed():
	is_spell_tab_active = false
	_load_items_into_grid(_get_item_list())
	_update_tab_visuals(false)

func _refresh_current_tab() -> void:
	_update_gold_display()
	if is_spell_tab_active:
		_load_items_into_grid(_get_spell_list())
		_update_tab_visuals(true)
	else:
		_load_items_into_grid(_get_item_list())
		_update_tab_visuals(false)

func _update_tab_visuals(is_spell_active: bool):
	_style_tab(tab_spell, is_spell_active)
	_style_tab(tab_item, not is_spell_active)

func _style_tab(tab: Button, active: bool) -> void:
	var bg = Color(0.94, 0.76, 0.35, 1.0) if active else Color(0.28, 0.61, 0.40, 1.0)
	var hover = Color(1.0, 0.84, 0.42, 1.0) if active else Color(0.36, 0.72, 0.50, 1.0)
	tab.modulate = Color.WHITE
	tab.add_theme_stylebox_override("normal", _make_stylebox(bg, COLOR_DARK, 3, 6, Vector4(12, 9, 12, 9)))
	tab.add_theme_stylebox_override("pressed", _make_stylebox(bg.darkened(0.12), COLOR_DARK, 3, 6, Vector4(12, 9, 12, 9)))
	tab.add_theme_stylebox_override("hover", _make_stylebox(hover, COLOR_DARK, 3, 6, Vector4(12, 9, 12, 9)))

func _load_items_into_grid(items_data: Array):
	if item_grid == null:
		return
		
	for child in item_grid.get_children():
		child.queue_free()
		
	for item_info in items_data:
		var item_instance = SHOP_ITEM_SCENE.instantiate()
		item_grid.add_child(item_instance)
		
		if item_instance.has_method("setup"):
			item_instance.setup(
				item_info["name"], 
				item_info["icon_path"], 
				item_info["price"],
				item_info.get("item_id", -1),
				item_info.get("description", ""),
				item_info.get("owned", 0),
				item_info.get("type", "item")
			)

# THAY ĐỔI: Thêm tham số item_pos vào hàm
func show_item_description(item_name: String, item_desc: String, item_pos: Vector2):
	name_label.text = item_name
	desc_label.text = item_desc
	
	var panel = $DescriptionOverlay/ContentPanel
	var viewport_size = get_viewport_rect().size
	var target_pos = item_pos + Vector2(132, -8)
	target_pos.x = clamp(target_pos.x, 24.0, viewport_size.x - panel.custom_minimum_size.x - 24.0)
	target_pos.y = clamp(target_pos.y, 24.0, viewport_size.y - panel.custom_minimum_size.y - 24.0)
	panel.global_position = target_pos
	
	desc_overlay.show()

func _on_overlay_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		desc_overlay.hide()
