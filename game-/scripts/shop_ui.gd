extends Control

# ĐƯỜNG DẪN NODE 
@onready var item_grid = $Background/MarginContainer/VBoxContainer/Body/ItemGrid
@onready var tab_spell = $Background/MarginContainer/VBoxContainer/Header/HeaderContainer/TabContainer/TabSpell
@onready var tab_item = $Background/MarginContainer/VBoxContainer/Header/HeaderContainer/TabContainer/TabItem
@onready var close_button = $Background/MarginContainer/VBoxContainer/Header/HeaderContainer/CloseButton

signal closed
# Tải sẵn file scene mẫu ô vật phẩm (ShopItem.tscn)
# Hãy chắc chắn rằng tên file trong thư mục của bạn viết đúng chữ hoa/thường (ví dụ: shopItem.tscn)
const SHOP_ITEM_SCENE = preload("res://scenes/shopItem.tscn")

# -------------------------------------------------------------
# DANH SÁCH VẬT PHẨM (Hãy thay đổi đường dẫn icon_path thành các file .tres bạn tạo)
# -------------------------------------------------------------
var spell_list = [
	{"name": "HỎA CẦU", "icon_path": "res://item_tres/fire.tres", "price": 100},
	{"name": "BĂNG TIỄN", "icon_path": "res://item_tres/ice.tres", "price": 120},
	{"name": "SÉT ĐÁNH", "icon_path": "res://item_tres/electric.tres", "price": 150},
	{"name": "GỖ XƯA", "icon_path": "res://item_tres/wood.tres", "price": 80}
]

var equipment_list = [
	{"name": "BÌNH MÁU", "icon_path": "res://item_tres/hp.tres", "price": 500},
	{"name": "SKIP", "icon_path": "res://item_tres/skip.tres", "price": 200},
	{"name": "LOẠI TRỪ", "icon_path": "res://item_tres/50_50.tres", "price": 150},
	{"name": "ĐÓNG BĂNG", "icon_path": "res://item_tres/time_freeze.tres", "price": 300}
]

func _ready():
	# Kiểm tra an toàn xem đường dẫn lấy Node có chuẩn chưa
	if tab_spell == null or tab_item == null or close_button == null:
		push_error("LỖI: Một trong các Node điều khiển của Shop bị NULL. Hãy kiểm tra lại cây Node!")
		return
		
	# Kết nối sự kiện click chuột cho các nút bấm
	tab_spell.pressed.connect(_on_tab_spell_pressed)
	tab_item.pressed.connect(_on_tab_item_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Mặc định lúc mở shop sẽ hiển thị tab Spell (Phép thuật) trước
	_load_items_into_grid(spell_list)
	_update_tab_visuals(true)

# Hàm đóng Shop khi nhấn nút [X]
func _on_close_pressed():
	visible = false

func _on_close_button_pressed():
	# Cách đơn giản nhất để đóng shop và hiện lại nút ở chapel
	emit_signal("closed")
	visible = false
	
# Khi click vào Tab Spells
func _on_tab_spell_pressed():
	_load_items_into_grid(spell_list)
	_update_tab_visuals(true)

# Khi click vào Tab Items
func _on_tab_item_pressed():
	_load_items_into_grid(equipment_list)
	_update_tab_visuals(false)

# Hàm thay đổi trạng thái sáng tối của 2 nút Tab để biết tab nào đang được chọn
func _update_tab_visuals(is_spell_active: bool):
	if is_spell_active:
		tab_spell.modulate = Color(1, 1, 1)      # Sáng rõ (Active)
		tab_item.modulate = Color(0.6, 0.6, 0.6)  # Tối đi (Inactive)
	else:
		tab_item.modulate = Color(1, 1, 1)       # Sáng rõ (Active)
		tab_spell.modulate = Color(0.6, 0.6, 0.6) # Tối đi (Inactive)

# Hàm quan trọng: Xóa các ô đồ cũ và tự động sinh các ô đồ mới vào Grid
func _load_items_into_grid(items_data: Array):
	if item_grid == null:
		return
		
	# Bước 1: Xóa sạch toàn bộ các ô đồ cũ đang hiển thị trong Grid
	for child in item_grid.get_children():
		child.queue_free()
		
	# Bước 2: Lặp qua từng món đồ trong danh sách và tạo ô đồ mới
	for item_info in items_data:
		var item_instance = SHOP_ITEM_SCENE.instantiate()
		item_grid.add_child(item_instance) # Đưa vào lưới Grid
		
		# Gọi hàm setup bên trong ô đồ để nạp Tên, Ảnh (.tres) và Giá tiền
		if item_instance.has_method("setup"):
			item_instance.setup(item_info["name"], item_info["icon_path"], item_info["price"])
