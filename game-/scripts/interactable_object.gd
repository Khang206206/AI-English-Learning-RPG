extends Area2D

@export_enum("QuizBook", "ReadSign") var object_type: String = "QuizBook"

@export_group("Quiz Settings")
@export var quiz_ui_node: CanvasLayer

@onready var prompt = $DoorInteract

var is_player_inside = false

func _ready():
	prompt.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name.contains("Player"):
		is_player_inside = true
		prompt.show()

func _on_body_exited(body):
	if body.name.contains("Player"):
		is_player_inside = false
		prompt.hide()

func _input(event):
	if is_player_inside and prompt.visible and event.is_action_pressed("interact"):
		do_action()

func do_action():
	if object_type == "QuizBook":
		_handle_quiz_action()

func _handle_quiz_action():
	if quiz_ui_node:
		quiz_ui_node.start_quiz()
