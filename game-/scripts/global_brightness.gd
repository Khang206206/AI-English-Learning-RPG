extends CanvasModulate

func _ready():
	# Mặc định lúc mới mở game là sáng bình thường (màu trắng)
	color = Color(1, 1, 1)

func update_brightness(value: float):
	color = Color(value, value, value)
