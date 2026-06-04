extends Node2D

# Tín hiệu phát ra khi hết giờ để báo cho BattleScene biết
signal timeout

@onready var kim_pivot = $KimPivot

# CHỈNH TẠI ĐÂY: Đổi thời gian gốc mặc định thành 20 giây
@export var default_total_time: float = 20.0 
@export var line_length: float = 100.0 # Chiều dài vạch đỏ (chỉnh cho vừa bán kính la bàn)

var total_time: float = 20.0 # Thời gian thực tế áp dụng cho hiệp hiện tại
var time_left: float = 20.0
var is_running: bool = false
var current_line_color: Color = Color.WHITE

func _ready():
	# Ép Godot vẽ vạch đỏ 12h ngay khi xuất hiện
	queue_redraw()
	# Chạy thử nghiệm ngay khi mở scene (Sau này vào game BattleScene sẽ gọi start_timer)
	start_timer()

func _draw():
	# Vẽ vạch đỏ cố định hướng 12 giờ làm mốc hết giờ (Tọa độ Y âm là đi lên trên)
	var start_point = Vector2(0, 0)
	var end_point = Vector2(0, -line_length)
	draw_line(start_point, end_point, current_line_color, 10.0) # Độ dày vạch là 10px

# Hàm này sẽ được gọi mỗi khi BattleScene đổi câu hỏi mới
func start_timer():
	# 1. Reset thời gian hiệp mới về mốc gốc 20 giây ban đầu
	var run_time = default_total_time
	current_line_color = Color.WHITE
	
	# 2. Tự động truy vết lên BattleScene để check hệ đạn
	var battle_scene = get_parent()
	if battle_scene:
		if not "current_bullet" in battle_scene and battle_scene.get_parent():
			battle_scene = battle_scene.get_parent()
			if not "current_bullet" in battle_scene and battle_scene.get_parent():
				battle_scene = battle_scene.get_parent()

		if battle_scene and "current_bullet" in battle_scene:
			var bullet = battle_scene.current_bullet
			
			# ⚡ ĐẠN ĐIỆN: Buff tăng 1.5 lần thời gian suy nghĩ (20s -> 30s)
			if bullet == "electric":
				# randf() sinh số ngẫu nhiên từ 0.0 đến 1.0
				# Nếu nhỏ hơn hoặc bằng 0.75 nghĩa là trúng tỷ lệ 75%
				if randf() <= 0.75:
					run_time = default_total_time * 1.5
					current_line_color = Color.GOLD
					print("[MagicTimer] TÊ LIỆT THÀNH CÔNG (75%)! Quái đứng hình, hiệp này được: ", run_time, " giây.")
				else:
					print("[MagicTimer] Đạn Điện trúng quái nhưng xui xẻo KHÔNG kích hoạt được tê liệt (25%)!")
				
			# ❄️ ĐẠN BĂNG: Chặt đôi thời gian suy nghĩ nếu hiệp trước gõ sai (20s -> 10s)
			elif bullet == "ice" and "is_monster_frozen" in battle_scene:
				if battle_scene.is_monster_frozen == false and battle_scene.current_ice_instance == null:
					run_time = default_total_time * 0.5
					current_line_color = Color.SKY_BLUE
					print("[MagicTimer] Thanh thời gian dính vụn Băng! Thời gian suy nghĩ bị bóp còn: ", run_time, " giây!")

	# 3. Áp chỉ số vừa tính toán vào bộ đếm và cho kim xoay
	total_time = run_time
	time_left = total_time
	is_running = true
	kim_pivot.rotation_degrees = 0 # Đặt kim về vị trí ban đầu (0 độ)
	queue_redraw()

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
		emit_signal("timeout") # Kích hoạt tín hiệu báo hết giờ cho BattleScene xử lý trừ máu
		print("HẾT GIỜ RỒI!")
		
