extends CanvasLayer

signal game_paused
signal game_resumed

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # Để nó chạy được cả khi game đang Pause
	$SettingsPanel.back_pressed.connect(_on_resume)

func _input(event):
	if event.is_action_pressed("ui_cancel"): # Phím ESC
		# Không hiện Pause menu nếu đang ở màn hình Title
		if get_tree().current_scene.name == "TitleScreen": return

		if not visible:
			show_pause()
		else:
			_on_resume()

func show_pause():
	visible = true
	$SettingsPanel.visible = true
	$SettingsPanel.setup_mode(true)
	get_tree().paused = true

func _on_resume():
	visible = false
	get_tree().paused = false
