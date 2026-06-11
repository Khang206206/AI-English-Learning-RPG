extends Area2D

@export_file("*.tscn") var target_scene_path: String
@export var destination_spawn_id: String

@export_group("Flash Effect")
@export var use_flash: bool = false
@export var flash_animation_player: AnimationPlayer

@onready var prompt = $DoorInteract
var is_player_inside = false
var gate_enabled := true

@export_group("Audio Settings")
@export var keep_bgm: bool = false

func _ready():
	prompt.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if not gate_enabled:
		return
	if body.name.contains("Player"):
		is_player_inside = true
		prompt.show()

func _on_body_exited(body):
	if body.name.contains("Player"):
		is_player_inside = false
		prompt.hide()

func _input(event):
	if gate_enabled and is_player_inside and prompt.visible and event.is_action_pressed("interact"):
		change_scene()

func set_gate_enabled(enabled: bool) -> void:
	gate_enabled = enabled
	visible = enabled
	if not enabled:
		is_player_inside = false
		prompt.hide()

func change_scene():
	if target_scene_path == "":
		return
		
	if BgmManager != null and not keep_bgm:
		BgmManager.stop_music()

	if GameManager != null:
		GameManager.target_spawn_id = destination_spawn_id

	if use_flash and flash_animation_player:
		flash_animation_player.play("flash_and_change")
		await flash_animation_player.animation_finished

	get_tree().change_scene_to_file(target_scene_path)
