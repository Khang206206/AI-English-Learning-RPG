extends AudioStreamPlayer

# Thêm biến volume_offset mặc định là 0.0 (giữ nguyên âm lượng gốc nếu không chỉnh)
func play_music(new_track: AudioStream, custom_volume: float = 0.0):
	# Nếu trùng bài đang phát và mức âm lượng không đổi -> Cứ kệ cho chạy tiếp
	if stream == new_track and playing and volume_db == custom_volume:
		return 
		
	stream = new_track
	
	# --- GÁN ÂM LƯỢNG RIÊNG CHO BÀI NHẠC NÀY ---
	volume_db = custom_volume
	# -------------------------------------------
	
	play()

func stop_music():
	if playing:
		stop()
