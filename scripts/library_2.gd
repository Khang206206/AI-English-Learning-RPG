extends Node2D
@export var lib2_music: AudioStream

const ELARIA_AFTER_QUIZ_DIALOGUE = [
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore1.png",
		"text": "Không tệ chút nào. Quyển sách đã không chọn nhầm người."
	},
	{
		"name": "Bạn",
		"portrait": "res://assets/textures/player2/_Faces/face_happy.png",
		"text": "Mình vẫn chưa hiểu hết, nhưng có vẻ mình thật sự có thể dùng pháp thuật ở đây."
	},
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore2.png",
		"text": "Đây mới chỉ là khởi đầu. Bên ngoài nhà thờ, quái vật đang lang thang khắp vùng đất này."
	},
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore1.png",
		"text": "Chúng được sinh ra từ những tri thức méo mó. Muốn đánh bại chúng, cậu phải rèn luyện từ vựng và ngữ pháp."
	},
	{
		"name": "Bạn",
		"portrait": "res://assets/textures/player2/_Faces/face_normal.png",
		"text": "Nói cách khác... càng học tốt tiếng Anh, mình càng mạnh hơn?"
	},
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore2.png",
		"text": "Chính xác. Hãy bước ra khỏi quyển sách, rời khỏi nhà thờ, và bắt đầu hành trình của cậu."
	},
	{
		"name": "Elaria",
		"portrait": "res://assets/textures/npc_guide/portrait/Eleonore1.png",
		"text": "Ngoài kia sẽ có những quái vật đầu tiên chờ đợi. Đừng sợ. Mỗi trận chiến cũng là một bài học."
	},
	{
		"name": "Bạn",
		"portrait": "res://assets/textures/player2/_Faces/face_normal.png",
		"text": "Được. Nếu đây là thế giới dùng tiếng Anh làm pháp thuật, thì mình sẽ học cách chiến đấu bằng nó."
	},
]

@onready var to_chapel = $ToChapel
@onready var quiz_ui = $QuizUI

var has_played_after_quiz_dialogue := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if lib2_music != null:
		BgmManager.play_music(lib2_music)
	else:
		# Nếu bạn quên chưa kéo nhạc vào thì tự động tắt nhạc cũ cho an toàn
		BgmManager.stop_music()
	_apply_intro_quiz_gate_state()
	if quiz_ui != null and not quiz_ui.quiz_completed.is_connected(_on_intro_quiz_completed):
		quiz_ui.quiz_completed.connect(_on_intro_quiz_completed)
	if quiz_ui != null and quiz_ui.has_signal("quiz_result_closed") and not quiz_ui.quiz_result_closed.is_connected(_on_intro_quiz_result_closed):
		quiz_ui.quiz_result_closed.connect(_on_intro_quiz_result_closed)
	if DatabaseManager != null and DatabaseManager.has_signal("intro_quiz_state_changed") and not DatabaseManager.intro_quiz_state_changed.is_connected(_on_intro_quiz_state_changed):
		DatabaseManager.intro_quiz_state_changed.connect(_on_intro_quiz_state_changed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _apply_intro_quiz_gate_state() -> void:
	if to_chapel != null and to_chapel.has_method("set_gate_enabled"):
		to_chapel.set_gate_enabled(DatabaseManager.has_completed_intro_quiz())

func _on_intro_quiz_completed() -> void:
	_apply_intro_quiz_gate_state()

func _on_intro_quiz_result_closed() -> void:
	if has_played_after_quiz_dialogue:
		return
	has_played_after_quiz_dialogue = true
	if DialogueSystem != null:
		DialogueSystem.start_dialogue(ELARIA_AFTER_QUIZ_DIALOGUE)

func _on_intro_quiz_state_changed(_is_completed: bool) -> void:
	_apply_intro_quiz_gate_state()
