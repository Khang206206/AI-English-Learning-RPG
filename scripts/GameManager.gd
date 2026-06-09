extends Node

# Lưu tên của cổng đích mà nhân vật sẽ xuất hiện tại đó
var target_spawn_id = ""
var current_monster: MonsterData = null
var current_enemy_id: int = 0
var player_position: Vector2 = Vector2.ZERO
var previous_scene_path: String = "res://scenes/chapter_1.tscn"
var should_load_position: bool = false
var has_seen_library_entry_dialogue: bool = false
