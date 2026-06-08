extends Area2D

@export_enum("QuizBook", "Battle", "NPC_Dialogue", "Notebook") var object_type: String = "QuizBook"

@export_group("Quiz Settings")
@export var quiz_ui_node: CanvasLayer

@export_group("Battle Settings")
@export_file("*.tscn") var battle_scene_path: String
@export var monster_data: MonsterData
@export var bypass_tier_check: bool = false # Biến dùng cho tester/dev để test quái mà không cần cày cuốc
@export var enemy_id: int = 0 # ID duy nhất để lưu tiến trình tiêu diệt quái

@export_group("Dialogue Settings")
var elaria_dialogue = [
	{
		"name": "Elaria", 
		"portrait": "res://art/portraits/elaria_normal.png", 
		"text": "Chào mừng bạn đã đến với Thư Viện Cổ Thư Aelphurion..."
	},
	{
		"name": "Elaria", 
		"portrait": "res://art/portraits/elaria_serious.png", 
		"text": "Ta cảm nhận được hệ thống AI ngầm đang dao động tri thức xung quanh bạn!"
	},
	{
		"name": "Elaria", 
		"portrait": "res://art/portraits/elaria_normal.png", 
		"text": "Hãy hoàn thành bài kiểm tra ngôn từ này để chứng minh năng lực của mình."
	},
]

@onready var prompt = $DoorInteract

var is_player_inside = false

func _ready():
	prompt.hide()
	
	if object_type == "Battle" and enemy_id > 0:
		if DatabaseManager.is_enemy_dead(enemy_id):
			queue_free() # Nếu quái này đã chết trước đó, tự động xóa khỏi map
			return
			
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
	elif object_type == "NPC_Dialogue":
		_handle_npc_dialogue_action()
	# 2. XỬ LÝ KHI CHỌN LOẠI NOTEBOOK
	elif object_type == "Notebook":
		_handle_notebook_action()
		
func _handle_quiz_action():
	if quiz_ui_node:
		quiz_ui_node.start_quiz()
	else:
		push_error("Loi: Chua gan Quiz UI Node")

func _handle_battle_action():
	if monster_data:
		var required_tier = monster_data.tier_id
		
		# Bỏ qua kiểm tra tier nếu biến bypass_tier_check = true
		if required_tier > 1 and not bypass_tier_check:
			var prev_tier_mastery = ProgressManager.get_tier_avg_mastery(required_tier - 1)
			if prev_tier_mastery < 0.3:
				prompt.hide()
				if DialogueSystem:
					DialogueSystem.start_dialogue([{
						"name": "Elaria",
						"portrait": "res://art/portraits/elaria_serious.png",
						"text": "Bạn chưa đủ kinh nghiệm để đối đầu với quái vật này! Hãy ôn tập đạt 30% mastery ở khu vực trước nhé."
					}])
				return
				
		if BgmManager != null:
			BgmManager.stop_music()
			
		GameManager.current_monster = monster_data
		GameManager.current_enemy_id = enemy_id
		AIManager.set_tier(monster_data.tier_id)
		GameManager.previous_scene_path = get_tree().current_scene.scene_file_path
		GameManager.should_load_position = true
		DatabaseManager.save_game(GameManager.player_position.x, GameManager.player_position.y)
		get_tree().change_scene_to_file(battle_scene_path)
	else:
		if BgmManager != null:
			BgmManager.stop_music()
			
		DatabaseManager.save_game(GameManager.player_position.x, GameManager.player_position.y)
		if battle_scene_path != null and battle_scene_path != "":
			get_tree().change_scene_to_file(battle_scene_path)
		else:
			push_error("Loi: Chua gan duong dan Battle Scene")

func _handle_npc_dialogue_action():
	prompt.hide()
	if DialogueSystem:
		DialogueSystem.start_dialogue(elaria_dialogue)
		if not DialogueSystem.dialogue_finished.is_connected(_on_dialogue_before_quiz_finished):
			DialogueSystem.dialogue_finished.connect(_on_dialogue_before_quiz_finished)
	else:
		push_error("Loi: Chua cai dat DialogueSystem trong Autoload")

func _on_dialogue_before_quiz_finished():
	if quiz_ui_node:
		quiz_ui_node.start_quiz()
	else:
		push_error("Loi: Chua gan Quiz UI Node cho NPC này")

func _handle_notebook_action():
	# Gọi thẳng Node đầu tiên nằm trong nhóm 'notebook_ui' (bất kể nó tên gì)
	var notebook = get_tree().get_first_node_in_group("notebook_ui")
	
	if notebook:
		notebook.toggle_notebook()
	else:
		push_error("Loi: Khong tim thay bat ky Node nao trong nhom 'notebook_ui'!")
