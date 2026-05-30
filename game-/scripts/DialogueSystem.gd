extends CanvasLayer

signal dialogue_finished

# Sử dụng find_child để tìm chính xác Node bất kể cấu trúc cây có thay đổi
@onready var panel = find_child("Panel", true, false)
@onready var portrait = find_child("Portrait", true, false)
@onready var name_label = find_child("NameLabel", true, false)
@onready var content_label = find_child("ContentLabel", true, false)
@onready var text_timer = find_child("TextTimer", true, false)

var dialogue_lines = []
var current_line_index = 0

func _ready():
	visible = false # Ẩn giao diện khi bắt đầu game

# Hàm được gọi từ InteractableObject
func start_dialogue(lines: Array):
	dialogue_lines = lines
	current_line_index = 0
	visible = true
	
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
	
	# Nạp ảnh chân dung, nếu lỗi đường dẫn ảnh thì bỏ qua không làm crash game
	if ResourceLoader.exists(line["portrait"]):
		portrait.texture = load(line["portrait"])
	
	# Hiệu ứng chạy chữ mượt mà
	content_label.visible_ratio = 0
	var duration = content_label.text.length() * 0.03
	var tween = create_tween()
	tween.tween_property(content_label, "visible_ratio", 1.0, duration)

func _input(event):
	# Thay 'is_action_just_pressed' thành 'is_action_pressed'
	if visible and event.is_action_pressed("ui_accept"): 
		
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
	
	# Giải phóng người chơi ra ngoài
	if GlobalPause.has_signal("game_resumed"):
		GlobalPause.game_resumed.emit()
		
	dialogue_finished.emit() # Phát tín hiệu để kích hoạt màn hình Quiz tiếp theo
