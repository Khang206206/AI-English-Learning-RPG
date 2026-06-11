extends CanvasLayer

@export var title_music: AudioStream
signal dialogue_finished

# 🌟 4 Ô THUỘC TÍNH ĐỂ BỒ KÉO THẢ FILE NHẠC CHO TỪNG ĐỨA NGOÀI INSPECTOR
@export var sound_seeker: AudioStream
@export var sound_albedou: AudioStream
@export var sound_elaria: AudioStream
@export var sound_narration: AudioStream

# 🌟 TỐC ĐỘ BÍP: Cứ sau bao nhiêu giây thì kêu 1 tiếng (0.07 là chuẩn Undertale)
@export var blip_rate: float = 0.07 

# Sử dụng find_child để tìm chính xác Node bất kể cấu trúc cây có thay đổi
@onready var panel = find_child("Panel", true, false)
@onready var dialogue_row = find_child("HBoxContainer", true, false)
@onready var portrait = find_child("Portrait", true, false)
@onready var portrait_frame = find_child("PortraitFrame", true, false)
@onready var name_label = find_child("NameLabel", true, false)
@onready var content_label = find_child("ContentLabel", true, false)
@onready var text_timer = find_child("TextTimer", true, false)
@onready var left_spacer = find_child("VBoxContainer", true, false)
@onready var blip_player = find_child("BlipPlayer", true, false)

const DEFAULT_PANEL_MIN_SIZE := Vector2(190, 180)
const DEFAULT_PANEL_RECT := Rect2(0, 0, 0, 276)
const DEFAULT_ROW_MARGIN := Rect2(0, 0, 0, 0)
const DEFAULT_ROW_SEPARATION := 105
const DEFAULT_PORTRAIT_FRAME_MIN_SIZE := Vector2.ZERO
const DEFAULT_PORTRAIT_RECT := Rect2(166, 47, 146, 148)
const DEFAULT_NAME_RECT := Rect2(107, 206, 280, 53)
const DEFAULT_NAME_FONT_SIZE := 23
const DEFAULT_CONTENT_FONT_SIZE := 20
const DEFAULT_NARRATION_MARGIN := Vector4(64, 38, 64, 38)
const DEFAULT_NARRATION_FONT_SIZE := 18

const COMPACT_PANEL_MIN_SIZE := Vector2(190, 150)
const COMPACT_PANEL_RECT := Rect2(-500, -174, 500, -14)
const COMPACT_PORTRAIT_FRAME_RECT := Rect2(36, 20, 156, 116)
const COMPACT_PORTRAIT_RECT := Rect2(49, 12, 58, 58)
const COMPACT_NAME_RECT := Rect2(18, 72, 120, 28)
const COMPACT_NAME_FONT_SIZE := 15
const COMPACT_CONTENT_RECT := Rect2(224, 24, 696, 112)
const COMPACT_CONTENT_NO_PORTRAIT_RECT := Rect2(46, 24, 874, 112)
const COMPACT_CONTENT_FONT_SIZE := 14

var dialogue_lines = []
var current_line_index = 0
var was_tree_paused_before_dialogue := false

# 🌟 BIẾN QUẢN LÝ NHỊP ĐIỆU TIẾNG BÍP TỰ ĐỘNG VÀ TWEEN CHẠY CHỮ
var is_typing := false
var blip_timer := 0.0
var text_tween: Tween # Biến dùng để nắm đầu và giết Tween khi người chơi bấm bỏ qua

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false # Ẩn giao diện khi bắt đầu game
	_apply_name_label_style(DEFAULT_NAME_FONT_SIZE)

# Hàm chạy theo thời gian thực để phát tiếng bíp đều đặn
func _process(delta):
	if is_typing:
		if content_label and content_label.visible_ratio >= 1.0:
			is_typing = false # Tự tắt bíp khi chữ chạy xong hoàn toàn
		else:
			blip_timer -= delta
			if blip_timer <= 0.0:
				_play_blip_sound()
				blip_timer = blip_rate # Đặt lại bộ đếm thời gian cho tiếng bíp tiếp theo

func is_dialogue_active() -> bool:
	return visible and not dialogue_lines.is_empty()

# Hàm được gọi từ InteractableObject
func start_dialogue(lines: Array):
	dialogue_lines = lines
	current_line_index = 0
	was_tree_paused_before_dialogue = get_tree().paused
	visible = true
	get_tree().paused = true
	
	if GlobalPause.has_signal("game_paused"):
		GlobalPause.game_paused.emit()
		
	show_line()

func show_line():
	if not name_label or not content_label or not portrait:
		push_error("Lỗi: Không tìm thấy các Node hiển thị UI trong DialogueSystem!")
		return
	var line = dialogue_lines[current_line_index]
	
	if line.has("music"):
		var music_path = str(line.get("music", ""))
		if music_path != "" and BgmManager.has_method("play_music"):
			var new_bgm = load(music_path)
			if new_bgm:
				BgmManager.play_music(new_bgm)
	elif line.has("stop_music") and line.get("stop_music") == true:
		if BgmManager.has_method("stop_music"):
			BgmManager.stop_music()
			
	var portrait_path := str(line.get("portrait", ""))
	var hide_portrait := bool(line.get("hide_portrait", false)) or portrait_path == ""
	
	var char_name = str(line.get("name", ""))
	name_label.text = char_name
	content_label.text = str(line.get("text", ""))
	var layout_name := str(line.get("dialogue_layout", "default"))
	_apply_dialogue_layout(layout_name, hide_portrait)
	
	# TỰ ĐỘNG ĐỔI GIỌNG BÍP CHO TỪNG NV ĐANG NÓI
	if blip_player:
		if char_name == "The Seeker":
			blip_player.stream = sound_seeker
		elif char_name == "Albedou":
			blip_player.stream = sound_albedou
		elif char_name == "Elaria":
			blip_player.stream = sound_elaria
		else:
			blip_player.stream = sound_narration
	
	if not hide_portrait:
		if ResourceLoader.exists(portrait_path):
			portrait.texture = load(portrait_path)
		else:
			portrait.texture = null

	if not hide_portrait and layout_name != "bottom_compact":
		_apply_portrait_side(str(line.get("portrait_side", "right")))
	
	# 🌟 KHÚC AN TOÀN: Kiểm tra xem có cái Tween cũ nào chưa chạy xong không thì giết nó trước
	if text_tween and text_tween.is_valid():
		text_tween.kill()
		
	# HIỆU ỨNG CHẠY CHỮ VÀ KÍCH HOẠT NHỊP BÍP LIÊN TỤC
	content_label.visible_ratio = 0.0
	var duration = content_label.text.length() * 0.03
	
	# Lưu cái Tween mới tạo vào biến text_tween toàn cục
	text_tween = create_tween()
	text_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	text_tween.tween_property(content_label, "visible_ratio", 1.0, duration)
	
	# KÍCH HOẠT TIẾNG BÍP LIÊN TỤC KHÔNG CHỜ CHỮ
	is_typing = true
	blip_timer = 0.0 # Kêu ngay lập tức từ chữ đầu tiên

func _play_blip_sound():
	if blip_player and blip_player.stream != null:
		blip_player.play()

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

func _apply_dialogue_layout(layout_name: String, hide_portrait: bool = false) -> void:
	if layout_name == "bottom_compact":
		_apply_bottom_compact_layout()
	elif hide_portrait:
		_apply_default_narration_layout()
	else:
		_apply_default_layout()
	_apply_portrait_visibility(hide_portrait, layout_name)

func _apply_name_label_style(font_size: int) -> void:
	if name_label == null:
		return
	name_label.modulate = Color.WHITE
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_font_size_override("font_size", font_size)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _apply_portrait_visibility(hide_portrait: bool, layout_name: String) -> void:
	if portrait_frame != null:
		portrait_frame.visible = not hide_portrait
	if portrait != null:
		portrait.visible = not hide_portrait
	if name_label != null:
		name_label.visible = not hide_portrait

	if layout_name != "bottom_compact":
		if left_spacer != null:
			left_spacer.visible = not hide_portrait
		return

	if content_label != null and hide_portrait:
		_set_control_rect(content_label, COMPACT_CONTENT_NO_PORTRAIT_RECT)
		content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _set_control_stretch_margins(control: Control, margins: Vector4) -> void:
	if control == null:
		return
	control.anchor_left = 0
	control.anchor_top = 0
	control.anchor_right = 1
	control.anchor_bottom = 1
	control.offset_left = margins.x
	control.offset_top = margins.y
	control.offset_right = -margins.z
	control.offset_bottom = -margins.w

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
		_apply_name_label_style(DEFAULT_NAME_FONT_SIZE)
	if content_label != null:
		content_label.custom_minimum_size = Vector2.ZERO
		content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content_label.add_theme_font_size_override("normal_font_size", DEFAULT_CONTENT_FONT_SIZE)
		content_label.clip_contents = false
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _apply_default_narration_layout() -> void:
	if panel != null:
		_move_control_to_parent(content_label, panel)
	if dialogue_row != null:
		dialogue_row.visible = false
	if left_spacer != null:
		left_spacer.visible = false
	if panel != null:
		panel.clip_contents = true
		panel.anchor_left = 0
		panel.anchor_top = 0
		panel.anchor_right = 1
		panel.anchor_bottom = 0
		panel.offset_left = DEFAULT_PANEL_RECT.position.x
		panel.offset_top = DEFAULT_PANEL_RECT.position.y
		panel.offset_right = DEFAULT_PANEL_RECT.size.x
		panel.offset_bottom = DEFAULT_PANEL_RECT.size.y
		panel.custom_minimum_size = DEFAULT_PANEL_MIN_SIZE
	if content_label != null:
		content_label.custom_minimum_size = Vector2.ZERO
		content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_set_control_stretch_margins(content_label, DEFAULT_NARRATION_MARGIN)
		content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content_label.add_theme_font_size_override("normal_font_size", DEFAULT_NARRATION_FONT_SIZE)
		content_label.clip_contents = true
		content_label.fit_content = false
		content_label.scroll_active = false
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
		_apply_name_label_style(COMPACT_NAME_FONT_SIZE)
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
	if visible and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		
		if event.is_echo(): 
			return
			
		# 🌟 KHÚC THAY ĐỔI ĂN TIỀN NHẤT CHỖ NÀY NÈ 🌟
		if content_label.visible_ratio < 1.0:
			# 1. Giết cái Tween đang chạy ngầm ngay lập tức để nó không kéo chữ lại
			if text_tween and text_tween.is_valid():
				text_tween.kill()
			
			# 2. Quăng chữ ra hết màn hình 100%
			content_label.visible_ratio = 1.0
			
			# 3. Chốt chặn tắt tiếng bíp ngay lập tức
			is_typing = false 
		else:
			# Nếu chữ đã đầy rồi, bấm Space lần nữa sẽ vọt qua thoại kế tiếp
			current_line_index += 1
			if current_line_index < dialogue_lines.size():
				show_line()
			else:
				finish_dialogue()

func finish_dialogue():
	visible = false
	is_typing = false # Đảm bảo tắt hẳn tiếng bíp khi đóng hộp thoại
	get_tree().paused = was_tree_paused_before_dialogue
	
	if GlobalPause.has_signal("game_resumed"):
		GlobalPause.game_resumed.emit()
		
	dialogue_finished.emit() # Phát tín hiệu kích hoạt Quiz
	
	if dialogue_lines.size() > 0:
		var last_line = dialogue_lines.back()
		if last_line.has("next_scene"):
			var next_scene_path = str(last_line.get("next_scene", ""))
			if next_scene_path != "":
				get_tree().change_scene_to_file(next_scene_path)
