extends Node2D

@onready var anim = $AnimatedSprite2D 

func shoot(start_pos: Vector2, target_pos: Vector2) -> void:
	global_position = start_pos
	
	var current_bullet: String = "normal"
	
	var current_scene = get_tree().current_scene
	var battle_scene = null
	if current_scene:
		battle_scene = current_scene.find_child("BattleScene", true, false)
	
	if not battle_scene and current_scene and current_scene.name == "BattleScene":
		battle_scene = current_scene

	if battle_scene:
		var battle_bullet = battle_scene.get("current_bullet")
		if battle_bullet != null:
			current_bullet = str(battle_bullet)

	var anim_name: String = "normal" 
	var target_scale: Vector2 = Vector2(3.0, 3.0) 
	
	match current_bullet:
		"fire":
			anim_name = "fire1"
			target_scale = Vector2(6.0, 6.0)
		"electric":
			anim_name = "electric1"
			target_scale = Vector2(3.0, 3.0)
		"ice":
			anim_name = "ice1"
			target_scale = Vector2(3.0, 3.0)
		"wood":
			anim_name = "wood1"
			target_scale = Vector2(3.0, 3.0)
		"normal":
			anim_name = "normal"
			target_scale = Vector2(3.0, 3.0)

	if anim != null and anim.sprite_frames != null:
		if not anim.sprite_frames.has_animation(anim_name) and anim.sprite_frames.has_animation("normal"):
			anim_name = "normal"
			target_scale = Vector2(3.0, 3.0)
		if anim.sprite_frames.has_animation(anim_name):
			anim.play(anim_name)
	scale = target_scale
	if start_pos.x > target_pos.x:
		scale.x = -abs(scale.x)

	var tween = create_tween()
	var fly_destination = target_pos 
	
	tween.tween_property(self, "global_position", fly_destination, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 2.0) 
	
	await tween.finished
	queue_free()
