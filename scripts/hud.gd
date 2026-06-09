extends CanvasLayer


@onready var shop_ui = get_node_or_null("ShopUI")
@onready var shop_button = get_node_or_null("ShopButton")
@onready var notebook_ui = get_node_or_null("NotebookUI2")

var guide_map_ui = null
var btn_guide_map = null
var feature_dock: PanelContainer = null

func _ready():
	# Đảm bảo HUD luôn hoạt động ngay cả khi game bị pause
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_viewport().size_changed.is_connected(_position_feature_dock):
		get_viewport().size_changed.connect(_position_feature_dock)
	
	if shop_ui != null:
		shop_ui.visible = false
		if not shop_ui.is_connected("closed", Callable(self, "_on_shop_closed")):
			shop_ui.connect("closed", Callable(self, "_on_shop_closed"))
			
	var gm_scene = load("res://scenes/GuideMapUI.tscn")
	if gm_scene:
		guide_map_ui = gm_scene.instantiate()
		add_child(guide_map_ui)
		
		btn_guide_map = TextureButton.new()
		btn_guide_map.texture_normal = _create_map_icon_texture(Color(0.95, 0.82, 0.50, 1.0))
		btn_guide_map.texture_hover = _create_map_icon_texture(Color(1.0, 0.90, 0.60, 1.0))
		btn_guide_map.texture_pressed = _create_map_icon_texture(Color(0.82, 0.66, 0.38, 1.0))
		btn_guide_map.pressed.connect(_on_guide_map_pressed)
		add_child(btn_guide_map)
		
	_build_feature_dock()

func _make_stylebox(bg_color: Color, border_color: Color, border_width: int = 2, radius: int = 8, margins: Vector4 = Vector4.ZERO) -> StyleBoxFlat:
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

func _build_feature_dock() -> void:
	if feature_dock != null:
		return

	feature_dock = PanelContainer.new()
	feature_dock.name = "FeatureDock"
	feature_dock.process_mode = Node.PROCESS_MODE_ALWAYS
	feature_dock.add_theme_stylebox_override("panel", _make_stylebox(
		Color(0.10, 0.065, 0.035, 0.82),
		Color(0.95, 0.74, 0.33, 0.95),
		2,
		8,
		Vector4(8, 8, 8, 8)
	))
	add_child(feature_dock)

	var list = HBoxContainer.new()
	list.name = "FeatureButtons"
	list.add_theme_constant_override("separation", 8)
	feature_dock.add_child(list)

	if btn_guide_map:
		_prepare_map_button(btn_guide_map)
		_reparent_to(btn_guide_map, list)
	if notebook_ui != null:
		var notebook_button = get_node_or_null("BtnNotebook")
		if notebook_button:
			_prepare_texture_button(notebook_button, "Notebook")
			_reparent_to(notebook_button, list)
	if shop_button != null:
		_prepare_texture_button(shop_button, "Shop")
		_reparent_to(shop_button, list)

	_position_feature_dock()

func _reparent_to(node: Control, new_parent: Node) -> void:
	if node.get_parent() == new_parent:
		return
	var old_parent = node.get_parent()
	if old_parent:
		old_parent.remove_child(node)
	new_parent.add_child(node)
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0

func _prepare_map_button(button: TextureButton) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Guide Map (M)"
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(58, 58)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _prepare_texture_button(button: TextureButton, label: String) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = label
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(58, 58)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.modulate = Color(1.0, 0.95, 0.84, 1.0)

func _position_feature_dock() -> void:
	if feature_dock == null:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var dock_size = feature_dock.get_combined_minimum_size()
	feature_dock.position = viewport_size - dock_size - Vector2(24.0, 24.0)

func _create_map_icon_texture(paper_color: Color) -> Texture2D:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var border := Color(0.25, 0.14, 0.06, 1.0)
	var fold := Color(0.76, 0.56, 0.28, 1.0)
	var route := Color(0.18, 0.38, 0.64, 1.0)
	var mark := Color(0.72, 0.12, 0.10, 1.0)

	for x in range(8, 40):
		for y in range(6, 42):
			image.set_pixel(x, y, paper_color)

	for y in range(6, 42):
		image.set_pixel(8, y, border)
		image.set_pixel(39, y, border)
	for x in range(8, 40):
		image.set_pixel(x, 6, border)
		image.set_pixel(x, 41, border)

	for y in range(8, 40):
		image.set_pixel(18, y, fold)
		image.set_pixel(29, y, fold)
	for x in range(10, 18):
		for y in range(7, 41):
			if (x + y) % 9 == 0:
				image.set_pixel(x, y, paper_color.lightened(0.10))
	for x in range(30, 38):
		for y in range(7, 41):
			if (x + y) % 8 == 0:
				image.set_pixel(x, y, paper_color.darkened(0.08))

	var route_points := [Vector2i(13, 32), Vector2i(17, 29), Vector2i(21, 27), Vector2i(25, 24), Vector2i(29, 20), Vector2i(33, 17)]
	for p in route_points:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				image.set_pixel(p.x + dx, p.y + dy, route)

	for dx in range(-3, 4):
		image.set_pixel(15 + dx, 14, mark)
		image.set_pixel(15, 14 + dx, mark)

	var texture := ImageTexture.create_from_image(image)
	return texture

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_on_guide_map_pressed()

func _on_guide_map_pressed():
	if guide_map_ui and guide_map_ui.has_method("toggle_guide_map"):
		guide_map_ui.toggle_guide_map()

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
