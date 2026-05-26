extends Area2D

@export_enum("QuizBook", "Battle") var object_type: String = "QuizBook"

@export_group("Quiz Settings")
@export var quiz_ui_node: CanvasLayer

@export_group("Battle Settings")
@export_file("*.tscn") var battle_scene_path: String
@export var monster_data: MonsterData

@onready var prompt = $DoorInteract

var is_player_inside = false

func _ready():
	prompt.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if "player" in body.name.to_lower():
		is_player_inside = true
		prompt.show()

func _on_body_exited(body):
	if "player" in body.name.to_lower():
		is_player_inside = false
		prompt.hide()

func _input(event):
	if is_player_inside and prompt.visible and event.is_action_pressed("interact"):
		do_action()

func do_action():
	if object_type == "QuizBook":
		_handle_quiz_action()
	elif object_type == "Battle":
		_handle_battle_action()

func _handle_quiz_action():
	if quiz_ui_node:
		quiz_ui_node.start_quiz()
	else:
		push_error("Loi: Chua gan Quiz UI Node")

func _handle_battle_action():
	if monster_data:
		GameManager.current_monster = monster_data
		AIManager.set_tier(monster_data.tier_id)
		get_tree().change_scene_to_file(battle_scene_path)
	else:
		if battle_scene_path != null and battle_scene_path != "":
			get_tree().change_scene_to_file(battle_scene_path)
		else:
			push_error("Loi: Chua gan duong dan Battle Scene")
