extends Area2D

@onready var prompt = $DoorInteract # Đường dẫn đến nút F bên trong nó

func _ready():
	prompt.hide()
	# Tự kết nối tín hiệu với chính mình
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name.contains("Player"):
		prompt.show()

func _on_body_exited(body):
	if body.name.contains("Player"):
		prompt.hide()

func _input(event):
	if prompt.visible and event.is_action_pressed("interact"):
		do_action()

func do_action():
	print("Bạn vừa tương tác với: ", name)
	# Bạn có thể dùng lệnh match name để phân loại hành động
