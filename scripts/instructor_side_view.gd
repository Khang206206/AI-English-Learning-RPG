extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D 

func _ready():
	# Luôn chơi hoạt ảnh đứng yên khi bắt đầu
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle") 
	
