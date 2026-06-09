extends Control

signal back_pressed 

@onready var volume_slider = $HBoxContainer/VolumeSlider
@onready var bright_slider = $HBoxContainer2/BrightSlider
@onready var back_button = $Backbutton
@onready var continue_button = $ContinueButton

# Called when the node enters the scene tree for the first time.
func _ready():
	$HBoxContainer/VolumeSlider.value_changed.connect(_on_volume_changed)
	
	$HBoxContainer2/BrightSlider.value_changed.connect(_on_brightness_changed)
	
	$Backbutton.pressed.connect(func(): back_pressed.emit())
	
	$ContinueButton.pressed.connect(func(): back_pressed.emit())
	
	if has_node("SaveGameButton"):
		$SaveGameButton.pressed.connect(_on_save_pressed)
	if has_node("QuitGameButton"):
		$QuitGameButton.pressed.connect(_on_quit_pressed)

func setup_mode(is_ingame: bool):
	if is_ingame:
		# Nếu đang chơi game: Hiện CONTINUE, ẩn EXIT (Backbutton)
		$ContinueButton.visible = true
		$Backbutton.visible = false
		if has_node("SaveGameButton"): $SaveGameButton.visible = true
		if has_node("QuitGameButton"): $QuitGameButton.visible = true
	else:
		# Nếu ở màn hình chính Title: Ẩn CONTINUE, hiện EXIT
		$ContinueButton.visible = false
		$Backbutton.visible = true
		if has_node("SaveGameButton"): $SaveGameButton.visible = false
		if has_node("QuitGameButton"): $QuitGameButton.visible = false
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_volume_changed(value):
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))

func _on_brightness_changed(value):
	GlobalBrightness.update_brightness(value)

func _on_save_pressed():
	DatabaseManager.save_game(GameManager.player_position.x, GameManager.player_position.y)
	if has_node("SaveGameButton"):
		$SaveGameButton.text = "SAVED!"
		var timer = get_tree().create_timer(2.0)
		timer.timeout.connect(func(): $SaveGameButton.text = "SAVE GAME")

func _on_quit_pressed():
	get_tree().quit()
