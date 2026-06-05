extends Node2D

@export_category("Kéo thả Node từ Scene")
@export var tilemap_1: TileMapLayer
@export var tilemap_2: TileMapLayer
@export var tunnel_area: Area2D
@export var roof_area: Area2D # LƯU Ý: Area2D này chỉ cần 1 CollisionShape2D trải dài khắp mặt cầu!

@export_category("Cấu hình hiệu ứng")
@export var target_alpha: float = 0.3
@export var fade_duration: float = 0.25

var tween: Tween
var is_on_roof: bool = false
var is_under_tunnel: bool = false

func _ready():
	if tunnel_area:
		tunnel_area.body_entered.connect(_on_tunnel_entered)
		tunnel_area.body_exited.connect(_on_tunnel_exited)
	if roof_area:
		roof_area.body_entered.connect(_on_roof_entered)
		roof_area.body_exited.connect(_on_roof_exited)

# ==================================
# ĐI TỪ TRÊN ĐỒI VÀO MẶT CẦU
# ==================================
func _on_roof_entered(body):
	if body.is_in_group("Player") or body is CharacterBody2D:
		if not is_under_tunnel:
			is_on_roof = true
			_set_tilemap_collision(false) # TẮT va chạm của gạch
			_fade_to(1.0)
			
			# TỰ ĐỘNG NÂNG Z-INDEX LÊN ĐỂ ĐỨNG TRÊN MÁI
			body.z_index = 2

func _on_roof_exited(body):
	if body.is_in_group("Player") or body is CharacterBody2D:
		is_on_roof = false
		if not is_under_tunnel:
			_set_tilemap_collision(true)
			# HẠ Z-INDEX XUỐNG KHI RỜI KHỎI MÁI
			body.z_index = 0

# ==================================
# ĐI TỪ DƯỚI LÒNG ĐẤT VÀO HẦM
# ==================================
func _on_tunnel_entered(body):
	if body.is_in_group("Player") or body is CharacterBody2D:
		if not is_on_roof:
			is_under_tunnel = true
			_set_tilemap_collision(true) # BẬT va chạm để không lọt ra ngoài hầm
			_fade_to(target_alpha) # Làm mờ mái hầm

func _on_tunnel_exited(body):
	if body.is_in_group("Player") or body is CharacterBody2D:
		is_under_tunnel = false
		if not is_on_roof:
			_fade_to(1.0)
			_set_tilemap_collision(true)

# ==================================
# HÀM XỬ LÝ CHUNG
# ==================================
func _fade_to(alpha_val: float):
	if tween and tween.is_running(): tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", alpha_val, fade_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_tilemap_collision(is_active: bool):
	if tilemap_1:
		tilemap_1.collision_enabled = is_active
	if tilemap_2:
		tilemap_2.collision_enabled = is_active
