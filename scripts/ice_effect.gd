extends AnimatedSprite2D

func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	play("starting")

func _on_animation_finished() -> void:
	if animation == "starting":
		stop()
		print("[IceEffect] Khối băng đông cứng, quái bị giam cầm!")
