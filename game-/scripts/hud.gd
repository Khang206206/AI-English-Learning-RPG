extends CanvasLayer

@onready var shop_ui = $ShopUI

func _ready():
	# Đảm bảo HUD luôn hoạt động ngay cả khi game bị pause
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if shop_ui != null:
		shop_ui.visible = false
		# Kết nối tín hiệu khi người chơi bấm nút X đóng Shop từ bên trong
		if not shop_ui.is_connected("closed", Callable(self, "_on_shop_closed")):
			shop_ui.connect("closed", Callable(self, "_on_shop_closed"))

# Khi click chuột vào Logo Shop
func _on_shop_button_pressed():
	if shop_ui != null:
		shop_ui.visible = !shop_ui.visible
		get_tree().paused = shop_ui.visible

# Khi Shop gửi tín hiệu đóng lại
func _on_shop_closed():
	get_tree().paused = false
