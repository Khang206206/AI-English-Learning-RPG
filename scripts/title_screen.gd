extends Control

@export var title_music: AudioStream

func _ready():
	if title_music != null:
		BgmManager.play_music(title_music)
	else:
		# Nếu bạn quên chưa kéo nhạc vào thì tự động tắt nhạc cũ cho an toàn
		BgmManager.stop_music()

	$VBoxContainer/Button.pressed.connect(_on_start_pressed)

	$VBoxContainer/Button2.pressed.connect(_on_continue_pressed)

	$VBoxContainer/Button3.pressed.connect(_on_settings_pressed)

	$VBoxContainer/Button4.pressed.connect(_on_quit_pressed)

	$SettingsPanel.back_pressed.connect(_on_settings_back)
	
	if not DatabaseManager.has_save_data:
		$VBoxContainer/Button2.disabled = true
		$VBoxContainer/Button2.modulate.a = 0.5
	else:
		$VBoxContainer/Button2.disabled = false
		$VBoxContainer/Button2.modulate.a = 1.0

func _on_start_pressed():

	get_tree().change_scene_to_file(
        "res://scenes/chapel.tscn"
	)



func _on_continue_pressed():
	# Cờ báo cho Player script biết rằng cần set lại vị trí từ GameManager
	GameManager.should_load_position = true
	
	var scene_to_load = DatabaseManager.current_biome
	if not scene_to_load.begins_with("res://"):
		scene_to_load = "res://scenes/chapel.tscn"
		
	get_tree().change_scene_to_file(scene_to_load)



func _on_settings_pressed():

	$VBoxContainer.visible = false
	$SettingsPanel.setup_mode(false)
	$SettingsPanel.visible = true

func _on_settings_back():
	
	$VBoxContainer.visible = true
	$SettingsPanel.visible = false

func _on_quit_pressed():

	get_tree().quit()
