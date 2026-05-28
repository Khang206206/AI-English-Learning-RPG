extends Control


func _ready():

	$VBoxContainer/Button.pressed.connect(_on_start_pressed)

	$VBoxContainer/Button2.pressed.connect(_on_continue_pressed)

	$VBoxContainer/Button3.pressed.connect(_on_options_pressed)

	$VBoxContainer/Button4.pressed.connect(_on_quit_pressed)



func _on_start_pressed():

	get_tree().change_scene_to_file(
        "res://scenes/chapel.tscn"
	)



func _on_continue_pressed():

	print("Continue game")



func _on_options_pressed():

	print("Options")



func _on_quit_pressed():

	get_tree().quit()
