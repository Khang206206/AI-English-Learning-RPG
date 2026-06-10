extends Area2D

@export_enum("QuizBook", "Battle", "NPC_Dialogue", "Notebook") var object_type: String = "QuizBook"

@export_group("Quiz Settings")
@export var quiz_ui_node: CanvasLayer
@export var disable_after_intro_quiz_completed: bool = false

@export_group("Battle Settings")
@export_file("*.tscn") var battle_scene_path: String
@export var monster_data: MonsterData
@export var bypass_tier_check: bool = false # Biến dùng cho tester/dev để test quái mà không cần cày cuốc
@export var enemy_id: int = 0 # ID duy nhất để lưu tiến trình tiêu diệt quái

@export_group("Dialogue Settings")
var elaria_dialogue = [
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore1.png",
		"text": "\"Cuối cùng cậu cũng bước vào được thánh vực tri thức.\""
	},
	{
		"name": "The Seeker",
		"portrait": "res://assets/textures/player2/_Faces/face_normal.png",
		"text": "\"Cô là ai? Và nơi này là đâu? Tại sao mình lại chui vào một quyển sách?\""
	},
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore1.png",
		"text": "\"Ta là Elaria, người canh giữ Cổ Thư Aelphurion.\""
	},
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore2.png",
		"text": "\"Nơi này lưu giữ ngôn ngữ, ký ức và ma thuật của cả vùng đất. Còn cậu là người được Cổ Thư lựa chọn.\""
	},
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore1.png",
		"text": "\"Một thế lực tên The Silence đang nuốt chửng tri thức, bóp méo ngôn từ và đánh cắp ký ức của những pháp sư cuối cùng.\""
	},
	{
		"name": "The Seeker",
		"portrait": "res://assets/textures/player2/_Faces/face_empty.png",
		"text": "\"Ký ức...? Tôi không nhớ nổi cả tên mình. The Silence đã làm chuyện đó sao?\""
	},
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore2.png",
		"text": "\"Có thể. Những mảnh ký ức của cậu đang bị giam trong huyết quản của lũ sinh vật méo mó ngoài kia.\""
	},
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore1.png",
		"text": "\"Nhưng trước khi đối mặt với chúng, ta phải kiểm tra xem mạch ngôn từ của cậu còn đáp lại pháp thuật hay không.\""
	},
	{
		"name": "The Seeker",
		"portrait": "res://assets/textures/player2/_Faces/face_normal.png",
		"text": "\"Một bài kiểm tra sao...? Được rồi. Nếu đó là cách để lấy lại ký ức, tôi sẽ thử.\""
	},
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore2.png",
		"text": "\"Hãy tập trung. Ở thế giới này, tiếng Anh không chỉ là ngôn ngữ. Nó là pháp thuật.\""
	},
]

@onready var prompt = $DoorInteract
@onready var prompt_sprite: Sprite2D = $DoorInteract/Sprite2D
@onready var prompt_label: Label = $DoorInteract/Label

var is_player_inside = false
var default_prompt_texture: Texture2D = null
var default_prompt_label_text := "F"
var interaction_enabled := true

const LOCKED_PROMPT_TEXTURE = preload("res://assets/textures/Pixel Art Padlock Pack - Animated/Old Padlock/GOLD/Sprites/Old Padlock - GOLD - 0000 (2).png")

func _ready():
	prompt.hide()
	default_prompt_texture = prompt_sprite.texture
	default_prompt_label_text = prompt_label.text
	if disable_after_intro_quiz_completed and DatabaseManager != null:
		set_interaction_enabled(not DatabaseManager.has_completed_intro_quiz())
		if DatabaseManager.has_signal("intro_quiz_state_changed") and not DatabaseManager.intro_quiz_state_changed.is_connected(_on_intro_quiz_state_changed):
			DatabaseManager.intro_quiz_state_changed.connect(_on_intro_quiz_state_changed)
	_update_lock_state()
			
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _is_battle_locked_by_mastery() -> bool:
	if object_type != "Battle" or monster_data == null or bypass_tier_check:
		return false
	return not ProgressManager.can_access_tier(monster_data.tier_id)

func _update_lock_state() -> void:
	if prompt_sprite == null or prompt_label == null:
		return
	if _is_battle_locked_by_mastery():
		prompt_sprite.texture = LOCKED_PROMPT_TEXTURE
		prompt_sprite.scale = Vector2(0.055, 0.055)
		prompt_sprite.position = Vector2(3.75, 3.25)
		prompt_label.hide()
		if is_player_inside:
			prompt.show()
		else:
			prompt.hide()
	else:
		prompt_sprite.texture = default_prompt_texture
		prompt_sprite.scale = Vector2(1.4411764, 1.382353)
		prompt_sprite.position = Vector2(3.75, 3.25)
		prompt_label.text = default_prompt_label_text
		prompt_label.show()
		if is_player_inside:
			prompt.show()
		else:
			prompt.hide()

func _on_body_entered(body):
	if not interaction_enabled:
		return
	if "player" in body.name.to_lower():
		is_player_inside = true
		_update_lock_state()

func _on_body_exited(body):
	if "player" in body.name.to_lower():
		is_player_inside = false
		prompt.hide()

func _input(event):
	if interaction_enabled and is_player_inside and prompt.visible and event.is_action_pressed("interact"):
		do_action()

func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled:
		is_player_inside = false
		prompt.hide()

func _on_intro_quiz_state_changed(is_completed: bool) -> void:
	if disable_after_intro_quiz_completed:
		set_interaction_enabled(not is_completed)

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
			var required_mastery = ProgressManager.get_tier_unlock_threshold()
			if prev_tier_mastery < required_mastery:
				_update_lock_state()
				if DialogueSystem:
					DialogueSystem.start_dialogue([{
						"name": "Elaria",
						"portrait": "res://assets/textures/npc_guide/portrait/Eleonore2.png",
						"text": "Bạn chưa đủ kinh nghiệm để đối đầu với quái vật này! Hãy ôn tập đạt %d%% mastery ở khu vực trước nhé." % int(required_mastery * 100.0)
					}])
				return
				
		if BgmManager != null:
			BgmManager.stop_music()
			
		GameManager.current_monster = monster_data
		GameManager.current_enemy_id = enemy_id
		if enemy_id > 0:
			DatabaseManager.mark_enemy_interacted(enemy_id)
		AIManager.set_tier(monster_data.tier_id)
		GameManager.previous_scene_path = get_tree().current_scene.scene_file_path
		GameManager.should_load_position = true
		DatabaseManager.restore_full_hp()
		DatabaseManager.save_game(GameManager.player_position.x, GameManager.player_position.y)
		get_tree().change_scene_to_file(battle_scene_path)
	else:
		if BgmManager != null:
			BgmManager.stop_music()
			
		DatabaseManager.restore_full_hp()
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
