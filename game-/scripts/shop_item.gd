extends Control

# ĐƯỜNG DẪN NODE (Chính xác theo cây Node của scene shopItem.tscn trong ảnh thứ 2)
@onready var name_label = $VBoxContainer/ItemName
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

func _ready():
	if buy_button != null:
		buy_button.pressed.connect(_on_buy_pressed)

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
