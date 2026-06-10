extends CanvasLayer

signal dialogue_finished

# Sử dụng find_child để tìm chính xác Node bất kể cấu trúc cây có thay đổi
@onready var panel = find_child("Panel", true, false)
@onready var dialogue_row = find_child("HBoxContainer", true, false)
@onready var portrait = find_child("Portrait", true, false)
@onready var portrait_frame = find_child("PortraitFrame", true, false)
@onready var name_label = find_child("NameLabel", true, false)
@onready var content_label = find_child("ContentLabel", true, false)
@onready var text_timer = find_child("TextTimer", true, false)
@onready var left_spacer = find_child("VBoxContainer", true, false)

const DEFAULT_PANEL_MIN_SIZE := Vector2(190, 180)
const DEFAULT_PANEL_RECT := Rect2(0, 0, 0, 276)
const DEFAULT_ROW_MARGIN := Rect2(0, 0, 0, 0)
const DEFAULT_ROW_SEPARATION := 105
const DEFAULT_PORTRAIT_FRAME_MIN_SIZE := Vector2.ZERO
const DEFAULT_PORTRAIT_RECT := Rect2(166, 47, 146, 148)
const DEFAULT_NAME_RECT := Rect2(107, 206, 280, 53)
const DEFAULT_NAME_FONT_SIZE := 23
const DEFAULT_CONTENT_FONT_SIZE := 20

const COMPACT_PANEL_MIN_SIZE := Vector2(190, 150)
const COMPACT_PANEL_RECT := Rect2(-500, -174, 500, -14)
const COMPACT_PORTRAIT_FRAME_RECT := Rect2(36, 20, 156, 116)
const COMPACT_PORTRAIT_RECT := Rect2(49, 12, 58, 58)
const COMPACT_NAME_RECT := Rect2(18, 72, 120, 28)
const COMPACT_NAME_FONT_SIZE := 15
const COMPACT_CONTENT_RECT := Rect2(224, 24, 696, 112)
const COMPACT_CONTENT_FONT_SIZE := 14

var dialogue_lines = []
var current_line_index = 0
var was_tree_paused_before_dialogue := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false # Ẩn giao diện khi bắt đầu game

func is_dialogue_active() -> bool:
	return visible and not dialogue_lines.is_empty()

# Hàm được gọi từ InteractableObject
func start_dialogue(lines: Array):
	dialogue_lines = lines
	current_line_index = 0
	was_tree_paused_before_dialogue = get_tree().paused
	visible = true
	get_tree().paused = true
	
	# Khóa người chơi lại thông qua Autoload GlobalPause của bạn
	if GlobalPause.has_signal("game_paused"):
		GlobalPause.game_paused.emit()
		
	show_line()

func show_line():
	# Kiểm tra an toàn xem các Node có bị null không trước khi gán dữ liệu
	if not name_label or not content_label or not portrait:
		push_error("Lỗi: Không tìm thấy các Node hiển thị UI trong DialogueSystem!")
		return
		
	var line = dialogue_lines[current_line_index]
	name_label.text = line["name"]
	content_label.text = line["text"]
	var layout_name := str(line.get("dialogue_layout", "default"))
	_apply_dialogue_layout(layout_name)
	
	# Nạp ảnh chân dung, nếu lỗi đường dẫn ảnh thì bỏ qua không làm crash game
	if ResourceLoader.exists(line["portrait"]):
		portrait.texture = load(line["portrait"])

	if layout_name != "bottom_compact":
		_apply_portrait_side(str(line.get("portrait_side", "right")))
	
	# Hiệu ứng chạy chữ mượt mà
	content_label.visible_ratio = 0
	var duration = content_label.text.length() * 0.03
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(content_label, "visible_ratio", 1.0, duration)

func _apply_portrait_side(side: String) -> void:
	if dialogue_row == null or portrait_frame == null or content_label == null:
		return
	if side == "left":
		dialogue_row.move_child(portrait_frame, 0)
		dialogue_row.move_child(content_label, 1)
		if left_spacer != null:
			dialogue_row.move_child(left_spacer, 2)
	else:
		if left_spacer != null:
			dialogue_row.move_child(left_spacer, 0)
		dialogue_row.move_child(content_label, 1)
		dialogue_row.move_child(portrait_frame, 2)

func _move_control_to_parent(control: Control, parent: Node) -> void:
	if control == null or parent == null or control.get_parent() == parent:
		return
	var old_parent = control.get_parent()
	if old_parent != null:
		old_parent.remove_child(control)
	parent.add_child(control)

func _set_control_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.anchor_left = 0
	control.anchor_top = 0
	control.anchor_right = 0
	control.anchor_bottom = 0
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y

func _apply_dialogue_layout(layout_name: String) -> void:
	if layout_name == "bottom_compact":
		_apply_bottom_compact_layout()
	else:
		_apply_default_layout()

func _apply_default_layout() -> void:
	if dialogue_row != null:
		_move_control_to_parent(left_spacer, dialogue_row)
		_move_control_to_parent(content_label, dialogue_row)
		_move_control_to_parent(portrait_frame, dialogue_row)
		dialogue_row.visible = true
	if panel != null:
		panel.clip_contents = false
		panel.anchor_left = 0
		panel.anchor_top = 0
		panel.anchor_right = 1
		panel.anchor_bottom = 0
		panel.offset_left = DEFAULT_PANEL_RECT.position.x
		panel.offset_top = DEFAULT_PANEL_RECT.position.y
		panel.offset_right = DEFAULT_PANEL_RECT.size.x
		panel.offset_bottom = DEFAULT_PANEL_RECT.size.y
		panel.custom_minimum_size = DEFAULT_PANEL_MIN_SIZE
	if dialogue_row != null:
		dialogue_row.offset_left = DEFAULT_ROW_MARGIN.position.x
		dialogue_row.offset_top = DEFAULT_ROW_MARGIN.position.y
		dialogue_row.offset_right = DEFAULT_ROW_MARGIN.size.x
		dialogue_row.offset_bottom = DEFAULT_ROW_MARGIN.size.y
		dialogue_row.add_theme_constant_override("separation", DEFAULT_ROW_SEPARATION)
	if left_spacer != null:
		left_spacer.visible = true
	if portrait_frame != null:
		portrait_frame.custom_minimum_size = DEFAULT_PORTRAIT_FRAME_MIN_SIZE
		portrait_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait_frame.size_flags_vertical = Control.SIZE_FILL
	if portrait != null:
		portrait.offset_left = DEFAULT_PORTRAIT_RECT.position.x
		portrait.offset_top = DEFAULT_PORTRAIT_RECT.position.y
		portrait.offset_right = DEFAULT_PORTRAIT_RECT.position.x + DEFAULT_PORTRAIT_RECT.size.x
		portrait.offset_bottom = DEFAULT_PORTRAIT_RECT.position.y + DEFAULT_PORTRAIT_RECT.size.y
	if name_label != null:
		name_label.offset_left = DEFAULT_NAME_RECT.position.x
		name_label.offset_top = DEFAULT_NAME_RECT.position.y
		name_label.offset_right = DEFAULT_NAME_RECT.position.x + DEFAULT_NAME_RECT.size.x
		name_label.offset_bottom = DEFAULT_NAME_RECT.position.y + DEFAULT_NAME_RECT.size.y
		name_label.add_theme_font_size_override("font_size", DEFAULT_NAME_FONT_SIZE)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if content_label != null:
		content_label.custom_minimum_size = Vector2.ZERO
		content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content_label.add_theme_font_size_override("normal_font_size", DEFAULT_CONTENT_FONT_SIZE)
		content_label.clip_contents = false
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _apply_bottom_compact_layout() -> void:
	if panel != null:
		_move_control_to_parent(portrait_frame, panel)
		_move_control_to_parent(content_label, panel)
	if dialogue_row != null:
		dialogue_row.visible = false
	if left_spacer != null:
		left_spacer.visible = false
	if panel != null:
		panel.clip_contents = true
		panel.anchor_left = 0.5
		panel.anchor_top = 1
		panel.anchor_right = 0.5
		panel.anchor_bottom = 1
		panel.offset_left = COMPACT_PANEL_RECT.position.x
		panel.offset_top = COMPACT_PANEL_RECT.position.y
		panel.offset_right = COMPACT_PANEL_RECT.size.x
		panel.offset_bottom = COMPACT_PANEL_RECT.size.y
		panel.custom_minimum_size = COMPACT_PANEL_MIN_SIZE
	if portrait_frame != null:
		portrait_frame.custom_minimum_size = Vector2.ZERO
		portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_set_control_rect(portrait_frame, COMPACT_PORTRAIT_FRAME_RECT)
	if portrait != null:
		portrait.offset_left = COMPACT_PORTRAIT_RECT.position.x
		portrait.offset_top = COMPACT_PORTRAIT_RECT.position.y
		portrait.offset_right = COMPACT_PORTRAIT_RECT.position.x + COMPACT_PORTRAIT_RECT.size.x
		portrait.offset_bottom = COMPACT_PORTRAIT_RECT.position.y + COMPACT_PORTRAIT_RECT.size.y
	if name_label != null:
		name_label.offset_left = COMPACT_NAME_RECT.position.x
		name_label.offset_top = COMPACT_NAME_RECT.position.y
		name_label.offset_right = COMPACT_NAME_RECT.position.x + COMPACT_NAME_RECT.size.x
		name_label.offset_bottom = COMPACT_NAME_RECT.position.y + COMPACT_NAME_RECT.size.y
		name_label.add_theme_font_size_override("font_size", COMPACT_NAME_FONT_SIZE)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if content_label != null:
		content_label.custom_minimum_size = Vector2.ZERO
		content_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		content_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_set_control_rect(content_label, COMPACT_CONTENT_RECT)
		content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		content_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content_label.add_theme_font_size_override("normal_font_size", COMPACT_CONTENT_FONT_SIZE)
		content_label.clip_contents = true
		content_label.fit_content = false
		content_label.scroll_active = false
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _input(event):
	# Thay 'is_action_just_pressed' thành 'is_action_pressed'
	if visible and event.is_action_pressed("ui_accept"): 
		get_viewport().set_input_as_handled()
		
		# Ngăn không cho sự kiện này kích hoạt liên tục khi đè giữ phím
		if event.is_echo(): 
			return
			
		if content_label.visible_ratio < 1.0:
			content_label.visible_ratio = 1.0 # Hiện toàn bộ chữ ngay lập tức nếu đang chạy
		else:
			current_line_index += 1
			if current_line_index < dialogue_lines.size():
				show_line()
			else:
				finish_dialogue()

func finish_dialogue():
	visible = false
	get_tree().paused = was_tree_paused_before_dialogue
	
	# Giải phóng người chơi ra ngoài
	if GlobalPause.has_signal("game_resumed"):
		GlobalPause.game_resumed.emit()
		
	dialogue_finished.emit() # Phát tín hiệu để kích hoạt màn hình Quiz tiếp theo
