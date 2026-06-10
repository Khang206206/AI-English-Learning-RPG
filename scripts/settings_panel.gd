extends Control

signal back_pressed 

@onready var volume_slider = $HBoxContainer/VolumeSlider
@onready var bright_slider = $HBoxContainer2/BrightSlider
@onready var back_button = $Backbutton
@onready var continue_button = $ContinueButton
@onready var quit_dialog = $QuitDialog
@onready var quit_dialog_label = $QuitDialog/QuitDialogVBox/QuitDialogLabel
@onready var save_and_quit_button = $QuitDialog/QuitDialogVBox/SaveAndQuitButton
@onready var quit_without_saving_button = $QuitDialog/QuitDialogVBox/QuitWithoutSavingButton
@onready var cancel_quit_button = $QuitDialog/QuitDialogVBox/CancelQuitButton
@onready var volume_row = $HBoxContainer
@onready var brightness_row = $HBoxContainer2
@onready var save_game_button = get_node_or_null("SaveGameButton")
@onready var quit_game_button = get_node_or_null("QuitGameButton")

var is_ingame_mode := false
var close_panel_on_quit_cancel := false
var quit_dialog_only_mode := false
var is_battle_mode := false

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
	save_and_quit_button.pressed.connect(_on_save_and_quit_pressed)
	quit_without_saving_button.pressed.connect(_on_quit_without_saving_pressed)
	cancel_quit_button.pressed.connect(_hide_quit_dialog)

func setup_mode(is_ingame: bool):
	is_ingame_mode = is_ingame
	is_battle_mode = _is_battle_scene_active()
	quit_dialog_only_mode = false
	_reset_quit_dialog_content()
	_apply_base_visibility()
	_hide_quit_dialog()
	if is_ingame:
		# Nếu đang chơi game: Hiện CONTINUE, ẩn EXIT (Backbutton)
		$ContinueButton.visible = true
		$Backbutton.visible = false
		if has_node("SaveGameButton"): $SaveGameButton.visible = true
		if has_node("QuitGameButton"):
			$QuitGameButton.visible = true
			$QuitGameButton.text = "QUIT BATTLE" if is_battle_mode else "QUIT GAME"
	else:
		# Nếu ở màn hình chính Title: Ẩn CONTINUE, hiện EXIT
		$ContinueButton.visible = false
		$Backbutton.visible = true
		if has_node("SaveGameButton"): $SaveGameButton.visible = false
		if has_node("QuitGameButton"): $QuitGameButton.visible = false
	_apply_dialogue_save_guard()
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_volume_changed(value):
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))

func _on_brightness_changed(value):
	GlobalBrightness.update_brightness(value)

func _on_save_pressed():
	if _is_dialogue_active():
		return
	DatabaseManager.save_game(GameManager.player_position.x, GameManager.player_position.y)
	if has_node("SaveGameButton"):
		$SaveGameButton.text = "SAVED!"
		var timer = get_tree().create_timer(2.0)
		timer.timeout.connect(func(): $SaveGameButton.text = "SAVE GAME")

func _on_quit_pressed():
	if _is_dialogue_active():
		return
	show_quit_dialog()

func show_quit_dialog(close_panel_on_cancel: bool = false, dialog_only: bool = false) -> void:
	if _is_dialogue_active():
		return
	is_battle_mode = _is_battle_scene_active()
	close_panel_on_quit_cancel = close_panel_on_cancel
	quit_dialog_only_mode = dialog_only
	_apply_quit_dialog_content()
	_apply_base_visibility()
	quit_dialog.show()

func _hide_quit_dialog() -> void:
	if quit_dialog != null:
		quit_dialog.hide()
	quit_dialog_only_mode = false
	_apply_base_visibility()
	if close_panel_on_quit_cancel:
		close_panel_on_quit_cancel = false
		back_pressed.emit()

func _apply_base_visibility() -> void:
	if volume_row != null:
		volume_row.visible = not quit_dialog_only_mode
	if brightness_row != null:
		brightness_row.visible = not quit_dialog_only_mode
	if continue_button != null:
		continue_button.visible = (not quit_dialog_only_mode) and is_ingame_mode
	if back_button != null:
		back_button.visible = (not quit_dialog_only_mode) and (not is_ingame_mode)
	if save_game_button != null:
		save_game_button.visible = (not quit_dialog_only_mode) and is_ingame_mode and (not is_battle_mode)
	if quit_game_button != null:
		quit_game_button.visible = not quit_dialog_only_mode
		quit_game_button.text = "QUIT BATTLE" if is_battle_mode else "QUIT GAME"
	_apply_dialogue_save_guard()

func _on_save_and_quit_pressed() -> void:
	if _is_dialogue_active():
		return
	if is_battle_mode:
		_quit_battle()
		return
	if not is_ingame_mode and not DatabaseManager.has_save_data:
		get_tree().quit()
		return

	DatabaseManager.save_and_quit(
		GameManager.player_position.x,
		GameManager.player_position.y,
		_resolve_settings_save_scene_path()
	)

func _resolve_settings_save_scene_path() -> String:
	if is_ingame_mode:
		return ""
	return DatabaseManager.current_biome if DatabaseManager.current_biome.begins_with("res://") else ""

func _on_quit_without_saving_pressed() -> void:
	get_tree().quit()

func _is_battle_scene_active() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false
	return current_scene.scene_file_path == "res://scenes/BattleScene.tscn" or current_scene.name == "BattleScene"

func _apply_quit_dialog_content() -> void:
	if is_battle_mode:
		if quit_dialog_label != null:
			quit_dialog_label.text = "ARE YOU SURE YOU WANT\nTO QUIT THE BATTLE?"
			quit_dialog_label.custom_minimum_size = Vector2(0, 72)
			quit_dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		if save_and_quit_button != null:
			save_and_quit_button.text = "QUIT BATTLE"
		if quit_without_saving_button != null:
			quit_without_saving_button.hide()
		return
	_reset_quit_dialog_content()

func _reset_quit_dialog_content() -> void:
	if quit_dialog_label != null:
		quit_dialog_label.text = "QUIT THE GAME?"
		quit_dialog_label.custom_minimum_size = Vector2.ZERO
		quit_dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if save_and_quit_button != null:
		save_and_quit_button.text = "SAVE AND QUIT"
	if quit_without_saving_button != null:
		quit_without_saving_button.show()

func _quit_battle() -> void:
	if DatabaseManager != null:
		DatabaseManager.restore_full_hp()
		DatabaseManager.save_game(
			GameManager.player_position.x,
			GameManager.player_position.y,
			GameManager.previous_scene_path
		)
	GameManager.should_load_position = true
	_hide_quit_dialog()
	back_pressed.emit()
	get_tree().paused = false
	if BgmManager != null:
		BgmManager.stop_music()
	get_tree().change_scene_to_file(GameManager.previous_scene_path)

func _is_dialogue_active() -> bool:
	return DialogueSystem != null and DialogueSystem.has_method("is_dialogue_active") and DialogueSystem.is_dialogue_active()

func _apply_dialogue_save_guard() -> void:
	var disabled := _is_dialogue_active()
	if save_game_button != null:
		save_game_button.disabled = disabled
	if quit_game_button != null:
		quit_game_button.disabled = disabled
	if save_and_quit_button != null:
		save_and_quit_button.disabled = disabled
