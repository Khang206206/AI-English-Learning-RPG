extends Node2D

# 1. Tạo một ô trống bên cột Inspector để bạn kéo thả file nhạc vào
@export var chapel_music: AudioStream
@onready var open_shop_button = $HUD/OpenShop
@onready var shop_ui = $HUD/ShopUI

func _ready() -> void:
	# 2. Khi Chapel vừa load lên, gọi Nhạc công phát bài nhạc này
	if chapel_music != null:
		BgmManager.play_music(chapel_music)
	else:
		# Nếu bạn quên chưa kéo nhạc vào thì tự động tắt nhạc cũ cho an toàn
		BgmManager.stop_music()		
func _on_open_shop_pressed():
	# Hiện shop lên khi bấm nút
	$HUD/OpenShop.visible = false
	$HUD/ShopUi.visible = true
func _on_shop_visibility_changed():
	if shop_ui and open_shop_button:
		if not shop_ui.visible:
			open_shop_button.visible = true
