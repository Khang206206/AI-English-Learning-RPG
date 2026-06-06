extends CanvasLayer


@onready var shop_ui = get_node_or_null("ShopUI")
@onready var shop_button = get_node_or_null("ShopButton")
@onready var notebook_ui = get_node_or_null("NotebookUI2")

func _ready():
	# Đảm bảo HUD luôn hoạt động ngay cả khi game bị pause
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	shop_button.pressed.connect(_on_shop_button_pressed)
	
	if shop_ui != null:
		shop_ui.visible = false
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

# Khi click chuột vào Logo Quyển Sổ
func _on_btn_notebook_pressed():
	if notebook_ui != null:
		if notebook_ui.has_method("toggle_notebook"):
			notebook_ui.toggle_notebook()
