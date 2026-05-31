extends Node2D

# Tín hiệu phát ra khi hết giờ để báo cho BattleScene biết
signal timeout

@onready var kim_pivot = $KimPivot

@export var total_time: float = 30.0 # Tổng thời gian đếm ngược (10 giây)
@export var line_length: float = 100. # Chiều dài vạch đỏ (chỉnh cho vừa bán kính la bàn)

var time_left: float = 30.0
var is_running: bool = false

func _ready():
	# Ép Godot vẽ vạch đỏ 12h ngay khi xuất hiện
	queue_redraw()
	# Chạy thử nghiệm ngay khi mở scene để bạn test (Sau này vào game sẽ xóa dòng dưới này đi)
	start_timer()

func _draw():
	# Vẽ vạch đỏ cố định hướng 12 giờ làm mốc hết giờ (Tọa độ Y âm là đi lên trên)
	var start_point = Vector2(0, 0)
	var end_point = Vector2(0, -line_length)
	draw_line(start_point, end_point, Color.RED, 10.0) # Độ dày vạch là 3px

# Hàm này sẽ được gọi mỗi khi BattleScene đổi câu hỏi mới
func start_timer():
	time_left = total_time
	is_running = true
	kim_pivot.rotation_degrees = 0 # Đặt kim về vị trí ban đầu (0 độ)

func stop_timer():
	is_running = false

func _process(delta):
	if not is_running:
		return
		
	if time_left > 0:
		time_left -= delta
		
		# Tính góc xoay: quay đều theo thời gian từ 0 đến 360 độ
		var percentage = (total_time - time_left) / total_time
		kim_pivot.rotation_degrees = percentage * 360.0
	else:
		# Hết giờ!
		is_running = false
		time_left = 0
		kim_pivot.rotation_degrees = 360.0 # Kim chạm vạch đỏ
		emit_signal("timeout") # Kích hoạt tín hiệu báo hết giờ
		print("HẾT GIỜ RỒI!")
