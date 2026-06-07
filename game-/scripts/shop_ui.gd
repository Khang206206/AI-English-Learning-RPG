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

func _ready():
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
		"Hỏa Cầu": "res://item_tres/fire.tres",
		"Băng Tiễn": "res://item_tres/ice.tres",
		"Sét Đánh": "res://item_tres/electric.tres",
		"Gỗ Xưa": "res://item_tres/wood.tres",
	}
	
	for row in DatabaseManager.db.query_result:
		result.append({
			"item_id": row["item_id"],
			"name": row["name"],
			"icon_path": icon_map.get(row["name"], "res://item_tres/fire.tres"),
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
		"potion": "res://item_tres/hp.tres",
		"fifty_fifty": "res://item_tres/50_50.tres",
		"skip": "res://item_tres/skip.tres",
		"time_freeze": "res://item_tres/time_freeze.tres",
	}
	
	for row in DatabaseManager.db.query_result:
		result.append({
			"item_id": row["item_id"],
			"name": row["name"],
			"icon_path": icon_map.get(row["item_type"], "res://item_tres/hp.tres"),
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
	_load_items_into_grid(_get_spell_list())
	_update_tab_visuals(true)

func _on_tab_item_pressed():
	_load_items_into_grid(_get_item_list())
	_update_tab_visuals(false)

func _update_tab_visuals(is_spell_active: bool):
	if is_spell_active:
		tab_spell.modulate = Color(1, 1, 1)      # Sáng rõ
		tab_item.modulate = Color(0.6, 0.6, 0.6)  # Tối đi
	else:
		tab_item.modulate = Color(1, 1, 1)
		tab_spell.modulate = Color(0.6, 0.6, 0.6)

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
				item_info.get("owned", 0)
			)

# THAY ĐỔI: Thêm tham số item_pos vào hàm
func show_item_description(item_name: String, item_desc: String, item_pos: Vector2):
	name_label.text = item_name
	desc_label.text = item_desc
	
	# THAY ĐỔI: Đẩy bảng mô tả ContentPanel sang bên phải ô vật phẩm
	$DescriptionOverlay/ContentPanel.global_position = item_pos + Vector2(100, -10)
	
	desc_overlay.show()

func _on_overlay_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		desc_overlay.hide()
