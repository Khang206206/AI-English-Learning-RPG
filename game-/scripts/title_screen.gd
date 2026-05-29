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

func _on_start_pressed():

	get_tree().change_scene_to_file(
        "res://scenes/chapel.tscn"
	)



func _on_continue_pressed():

	print("Continue game")



func _on_settings_pressed():

	$VBoxContainer.visible = false
	$SettingsPanel.setup_mode(false)
	$SettingsPanel.visible = true

func _on_settings_back():
	
	$VBoxContainer.visible = true
	$SettingsPanel.visible = false

func _on_quit_pressed():

	get_tree().quit()
