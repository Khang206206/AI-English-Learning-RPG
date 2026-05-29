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

func setup_mode(is_ingame: bool):
	if is_ingame:
		# Nếu đang chơi game: Hiện CONTINUE, ẩn EXIT (Backbutton)
		$ContinueButton.visible = true
		$Backbutton.visible = false
	else:
		# Nếu ở màn hình chính Title: Ẩn CONTINUE, hiện EXIT
		$ContinueButton.visible = false
		$Backbutton.visible = true
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_volume_changed(value):
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))

func _on_brightness_changed(value):
	GlobalBrightness.update_brightness(value)
