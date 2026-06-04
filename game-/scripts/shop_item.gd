extends Control

# ĐƯỜNG DẪN NODE (Chính xác theo cây Node của scene shopItem.tscn trong ảnh thứ 2)
@onready var name_label = $VBoxContainer/ItemName
@onready var icon_texture = $VBoxContainer/ItemBg/Icon
@onready var buy_button = $VBoxContainer/BuyButton

var item_name: String = ""
var item_price: int = 0

func _ready():
	# Tự động kết nối sự kiện khi người chơi click vào nút BUY của ô này
	if buy_button != null:
		buy_button.pressed.connect(_on_buy_pressed)

# Hàm nhận dữ liệu từ ShopUI để hiển thị lên từng ô đồ
func setup(p_name: String, p_icon_path: String, p_price: int):
	item_name = p_name
	item_price = p_price
	
	# Đổi chữ trên Label thành tên vật phẩm
	if name_label != null:
		name_label.text = p_name
		
	# Đổi chữ trên nút BUY thành giá tiền (ví dụ: "100 G")
	if buy_button != null:
		buy_button.text = str(p_price) + " G"
		
	# Tải ảnh từ đường dẫn file .tres và gán vào khung hiển thị Icon
	if icon_texture != null:
		if ResourceLoader.exists(p_icon_path):
			icon_texture.texture = load(p_icon_path)
		else:
			# Phòng trường hợp chưa tạo file .tres, hiển thị ô trống để không bị crash game
			icon_texture.texture = null

# Hàm xử lý khi người dùng nhấn nút BUY
func _on_buy_pressed():
	print("Người chơi yêu cầu mua vật phẩm: ", item_name, " với giá: ", item_price, " Gold")
	# Bạn có thể kết nối tín hiệu này hoặc gọi trực tiếp đến script Quản lý Nhân Vật (Player) 
	# để trừ tiền vàng và thêm món đồ này vào túi đồ (Inventory) của người chơi nhé!
