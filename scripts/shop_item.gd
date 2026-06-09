extends Control

# ĐƯỜNG DẪN NODE (Chính xác theo cây Node của scene shopItem.tscn trong ảnh thứ 2)
@onready var name_label = $VBoxContainer/ItemName
@onready var item_bg = $VBoxContainer/ItemBg
@onready var icon_texture = $VBoxContainer/ItemBg/Icon
@onready var buy_button = $VBoxContainer/BuyButton
# Khai báo UI Owned (Phần người dùng cần thêm node trong Design)
@onready var owned_label = $VBoxContainer/OwnedLabel
# (Optional) SpinBox để chọn số lượng mua (Phần người dùng cần thêm node trong Design)
@onready var quantity_box = $VBoxContainer/QuantityBox

var item_name: String = ""
var item_price: int = 0
var item_id: int = -1
var item_desc: String = ""
var item_type: String = "item"

const COLOR_INK := Color(0.13, 0.07, 0.03, 1.0)
const COLOR_GOLD := Color(0.95, 0.74, 0.33, 1.0)
const COLOR_CARD := Color(0.93, 0.82, 0.58, 0.92)
const COLOR_DARK := Color(0.22, 0.13, 0.07, 1.0)

func _ready():
	_apply_item_theme()
	if buy_button != null:
		buy_button.pressed.connect(_on_buy_pressed)

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

func _apply_item_theme() -> void:
	scale = Vector2.ONE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	custom_minimum_size = Vector2(210, 174)
	size = custom_minimum_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS

	var card = get_node_or_null("CardPanel") as Panel
	if card == null:
		card = Panel.new()
		card.name = "CardPanel"
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(card)
		move_child(card, 0)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 0
	card.offset_top = 0
	card.offset_right = 0
	card.offset_bottom = 0
	card.add_theme_stylebox_override("panel", _make_stylebox(COLOR_CARD, Color(0.45, 0.28, 0.13, 1.0), 2, 8))

	var vbox = $VBoxContainer
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 3)

	name_label.custom_minimum_size = Vector2(178, 30)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", COLOR_INK)
	name_label.add_theme_color_override("font_outline_color", Color(0.95, 0.84, 0.62, 0.65))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	item_bg.custom_minimum_size = Vector2(52, 52)
	item_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	quantity_box.custom_minimum_size = Vector2(58, 24)
	quantity_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quantity_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quantity_box.add_theme_font_size_override("font_size", 12)
	quantity_box.add_theme_color_override("font_color", COLOR_INK)

	owned_label.custom_minimum_size = Vector2(178, 16)
	owned_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	owned_label.add_theme_font_size_override("font_size", 10)
	owned_label.add_theme_color_override("font_color", Color(0.22, 0.16, 0.08, 1.0))
	owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	buy_button.custom_minimum_size = Vector2(78, 26)
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.add_theme_font_size_override("font_size", 12)
	buy_button.add_theme_color_override("font_color", COLOR_INK)
	buy_button.add_theme_color_override("font_hover_color", COLOR_INK)
	buy_button.add_theme_stylebox_override("normal", _make_stylebox(COLOR_GOLD, COLOR_DARK, 2, 6, Vector4(10, 6, 10, 6)))
	buy_button.add_theme_stylebox_override("hover", _make_stylebox(Color(1.0, 0.84, 0.42, 1.0), COLOR_DARK, 2, 6, Vector4(10, 6, 10, 6)))
	buy_button.add_theme_stylebox_override("pressed", _make_stylebox(COLOR_GOLD.darkened(0.16), COLOR_DARK, 2, 6, Vector4(10, 6, 10, 6)))
	buy_button.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.58, 0.54, 0.44, 1.0), Color(0.32, 0.28, 0.20, 1.0), 2, 6, Vector4(10, 6, 10, 6)))

func setup(p_name: String, p_icon_path: String, p_price: int, p_item_id: int = -1, p_desc: String = "", p_owned: int = 0, p_type: String = "item"):
	item_name = p_name
	item_price = p_price
	item_id = p_item_id
	item_desc = p_desc
	item_type = p_type
	
	if name_label != null:
		name_label.text = p_name
		
	if buy_button != null:
		if item_type == "spell":
			if p_owned > 0:
				buy_button.text = "BOUGHT"
				buy_button.disabled = true
				buy_button.modulate.a = 0.5 # Làm mờ nút
			else:
				buy_button.text = str(p_price) + " G"
				buy_button.disabled = false
				buy_button.modulate.a = 1.0
		else:
			buy_button.text = str(p_price) + " G"
			buy_button.disabled = false
			buy_button.modulate.a = 1.0
		
	if icon_texture != null:
		if ResourceLoader.exists(p_icon_path):
			icon_texture.texture = load(p_icon_path)
		else:
			icon_texture.texture = null
			
	if owned_label != null:
		if item_id != -1 and item_type != "spell":
			owned_label.text = "Đang có: %d" % p_owned
			owned_label.visible = true
		else:
			owned_label.visible = false
			
	if quantity_box != null:
		if item_type == "spell":
			quantity_box.visible = false
		else:
			quantity_box.visible = true
			quantity_box.value = 1 # Reset về 1 mỗi lần mở
			
	# Nạp text cho Tooltip (Godot tự hiển thị khi hover)
	if item_id != -1:
		self.tooltip_text = "%s\n%s\nĐang có: %d" % [item_name, item_desc, p_owned]
	else:
		self.tooltip_text = "%s\n%s" % [item_name, item_desc]

func _on_buy_pressed():
	if item_id == -1:
		return
		
	var qty = 1
	if quantity_box != null and quantity_box.visible:
		qty = int(quantity_box.value)
		if qty <= 0: return

	var total_price = item_price * qty
	
	if DatabaseManager.spend_gold(total_price):
		ProgressManager.add_item(item_id, qty)
		print("[Shop] Mua thành công %d %s" % [qty, item_name])
		DatabaseManager.save_game(GameManager.player_position.x, GameManager.player_position.y)
		
		# Gọi cha để update UI Gold và Refresh
		var shop_ui = _get_shop_ui(self)
		if shop_ui:
			shop_ui._update_gold_display()
			# Làm mới danh sách item để cập nhật số lượng
			if item_type == "spell":
				shop_ui._on_tab_spell_pressed()
			else:
				shop_ui._on_tab_item_pressed()
	else:
		print("[Shop] Không đủ Gold để mua %s!" % item_name)

func _get_shop_ui(node: Node) -> Node:
	var parent = node.get_parent()
	while parent:
		if parent.has_method("_update_gold_display"):
			return parent
		parent = parent.get_parent()
	return null

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var shop_ui = _get_shop_ui(self)
		if shop_ui and shop_ui.has_method("show_item_description"):
			# THAY ĐỔI: Truyền thêm tham số thứ 3 là vị trí global_position của ô này
			shop_ui.show_item_description(item_name, item_desc, self.global_position)
