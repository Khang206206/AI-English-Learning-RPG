extends RefCounted

const PLAYER_NORMAL := "res://assets/textures/player2/_Faces/face_normal.png"
const PLAYER_EMPTY := "res://assets/textures/player2/_Faces/face_empty.png"
const PLAYER_ANGRY := "res://assets/textures/player2/_Faces/face_angry.png"
const ELARIA_CALM := "res://assets/textures/npc_guide/portrait/Eleonore1.png"
const ELARIA_WARN := "res://assets/textures/npc_guide/portrait/Eleonore2.png"

static func get_battle_victory_dialogue(enemy_id: int) -> Array:
	match enemy_id:
		1:
			return [
				_narration("Khối bùn nhão Slime vỡ tung. Một luồng sáng nhỏ bay vào ngực The Seeker."),
				_narration("Cậu chợt thấy một căn phòng đầy sách cổ ngập tràn ánh nắng. Tiếng cười của một nhóm bạn trẻ vang lên trong ký ức."),
				_narration("Một giọng nói ấm áp gọi: \"Này Phúc, đừng có lười, đi đọc cuốn cổ ngữ đó đi!\" Rồi mọi thứ đứt đoạn."),
				_seeker("\"Phúc...? Tại sao cái tên này lại mang đến cảm giác hoài niệm và ấm áp đến vậy? Lồng ngực mình... đang nhói lên.\""),
				_elaria("\"Phúc? Một cái tên xa lạ, nhưng lại mang theo một luồng ma lực rất đỗi quen thuộc...\""),
				_elaria("\"Cậu đã từng có những người đồng hành, lữ khách ạ. Hãy tiến lên, những mảnh vỡ khác vẫn đang kẹt lại trong huyết quản của bọn quái vật.\""),
			]
		2:
			return [
				_narration("Tên Goblin gục xuống, đánh rơi một viên pha lê ký ức vỡ vụn. Một khung cảnh hỗn loạn hiện về."),
				_narration("Trời giông bão. Trên vách đá cao, một thanh niên đứng chắn trước mặt The Seeker, vung quyền trượng gọi sấm sét chặn hàng vạn quái vật."),
				_narration("Ai đó hét lên: \"Khang! Rút lui mau, mạch ma thuật của cậu sắp quá tải rồi!\""),
				_seeker("\"Ánh chớp đó... thật đáng sợ nhưng cũng thật vĩ đại. Khang là ai? Tại sao anh ấy lại sẵn sàng che chắn cho tôi trước hiểm nguy như thế?\""),
				_elaria("\"Một pháp sư mang sức mạnh sấm sét tên Khang sao? Trận chiến trong ký ức đó thật thảm khốc.\""),
				_elaria("\"Cậu không hề đơn độc, nhưng có vẻ như bóng tối đã chia cắt tất cả các cậu.\""),
			]
		3:
			return [
				_narration("Con sói đầu đàn ngã sụp, trả lại một đóa hoa ma thuật. Ánh sáng của nó ngấm vào tay The Seeker."),
				_narration("Cậu thấy mình đang chạy trốn trong một khu rừng rực lửa. Phía sau, một bóng người dũng cảm quay đầu lại."),
				_narration("Người đó lao vào hàm răng dã thú để câu giờ. Giọng nói vang vọng: \"Chạy đi! Tìm cuốn Cổ Thư! Sống sót nhé... Khoa sẽ lo liệu bọn này!\""),
				_seeker("\"Không... Khoa! Đừng bỏ lại tôi! Đừng đi về phía cái chết như thế!\"", PLAYER_EMPTY),
				_elaria("\"Cậu đang khóc sao, lữ khách? Kẻ tên Khoa đó đã dùng chính sinh mạng của mình để đổi lấy sự tồn tại của cậu ngày hôm nay.\""),
				_elaria("\"Đừng để sự hy sinh đó trở nên vô nghĩa.\""),
			]
		4:
			return [
				_narration("Thủ lĩnh Skeleton tan thành tro bụi. Một đoạn ký ức bùng nổ trong tâm trí The Seeker."),
				_narration("Tại một nơi xa lạ, một nhóm người đứng thành vòng tròn. Sắc mặt họ nhợt nhạt, sinh lực bị rút cạn để tạo nên ma thuật khởi nguyên."),
				_narration("Tiếng gào vang lên: \"Mạnh! Đổ thêm mana vào đi! Chúng ta không còn nhiều thời gian trước khi Sự Câm Lặng nuốt chửng nơi này!\""),
				_seeker("\"Ma thuật khởi nguyên... Bọn họ đang cố rèn thứ gì? Mạnh, Khoa, Khang, Phúc... Rốt cuộc tôi đã để họ phải gánh chịu điều gì?\""),
				_elaria("\"Họ đang dùng phần hồn của chính mình để rèn Thánh Tích cứu mạng thế giới!\""),
				_elaria("\"Khang, Khoa, Mạnh, Phúc... những người đồng hành của cậu quả thực là những pháp sư vĩ đại nhất ta từng chứng kiến.\""),
			]
		5:
			return [
				_narration("Orc tướng bại trận. Bầu trời trong ký ức sụp đổ thành một hố đen."),
				_narration("Một thanh niên đỡ lấy The Seeker đang bị thương, đẩy cậu vào vòng tròn dịch chuyển không gian và mỉm cười."),
				_narration("\"Nguyên tin cậu làm được. Hãy sống, tìm lại tri thức và quay về giải cứu tụi mình!\""),
				_seeker("\"Nguyên! Đừng đẩy tôi đi! Tôi không muốn chạy trốn nữa, tôi muốn chiến đấu cùng mọi người!\"", PLAYER_EMPTY),
				_elaria("\"Cậu chính là hy vọng cuối cùng được họ gửi gắm. Không phải tự nhiên Cổ Thư lại chọn cậu.\""),
				_elaria("\"Ma lực của cậu đang khôi phục rất nhanh. Hãy đi tìm mảnh ghép cuối cùng của bức tranh này!\""),
			]
		6:
			return [
				_narration("Cốt lõi Golem nổ tung. Lần này, bảy người bạn đứng trong vòng tròn ánh sáng hiện lên đầy đủ."),
				_narration("Khang, Khoa, Mạnh, Nguyên, Phúc, Phú... và cậu. Người thanh niên thứ sáu trao vào tay The Seeker cuốn Cổ Thư."),
				_narration("Phú nói: \"Trận chiến này tụi mình thua rồi. Đi đi, Albedou! Đừng quên tụi mình!\""),
				_narration("The Seeker bàng hoàng quỳ xuống. Cậu chính là Albedou. Thất Đại Pháp Sư huyền thoại chính là nhóm bạn chí cốt của cậu."),
				_albedou("\"Albedou... Đúng rồi, tên của tôi là Albedou! Khang, Khoa, Mạnh, Nguyên, Phúc, Phú...\""),
				_albedou("\"Chúng tôi là Thất Đại Pháp Sư của vùng đất này! Tôi đã nhớ ra tất cả rồi!\""),
				_elaria("\"Cậu đã nhớ ra tên mình rồi. Albedou! Cậu chính là mảnh ghép thứ bảy, một trong Thất Đại Pháp Sư của Aelphurion.\""),
				_elaria("\"Sự thật đã được phơi bày, giờ là lúc đối mặt với nó.\""),
			]
		7:
			return [
				_narration("Phù thủy gục ngã. Ảo ảnh tan biến, hé lộ lý do Albedou mất trí nhớ."),
				_narration("Sau khi chứng kiến sáu người bạn tan biến để rèn cổ ngữ, Albedou đã ôm cuốn Cổ Thư bỏ chạy."),
				_narration("Nỗi sợ The Silence và sự cô độc quá lớn đã khiến tâm trí cậu tự phong ấn, xóa sạch ký ức để trốn tránh thực tại đau đớn."),
				_albedou("\"Là do tôi... Là do tôi hèn nhát...\"", PLAYER_EMPTY),
				_albedou("\"Vì quá sợ hãi sự cô độc mà tôi đã phản bội lại sự hy sinh của họ, tự lừa dối chính bản thân mình...\"", PLAYER_EMPTY),
				_elaria("\"Mất trí nhớ không phải do lời nguyền, mà là do cậu đã quá sợ hãi sự thật...\""),
				_elaria("\"Nhưng nhìn lại xem, cậu của hiện tại đã không còn trốn chạy nữa. Cậu đã cầm vũ khí đứng lên chiến đấu vì họ!\""),
			]
		8:
			return [
				_narration("Kẻ gác cổng điên loạn sụp đổ. Albedou nhìn thấy linh hồn của Khang, Khoa, Mạnh, Nguyên, Phúc, Phú hòa vào vầng sáng của Cổ Thư."),
				_narration("Họ chưa từng bỏ rơi cậu."),
				_albedou("\"Mọi người... Ra là các cậu vẫn luôn ở đây. Cổ Thư này mang theo một phần linh hồn các cậu.\""),
				_albedou("\"Chúng ta vẫn đang sát cánh bên nhau ngay từ đầu!\""),
				_elaria("\"Họ luôn ở bên cậu, Albedou ạ. Đi đến cửa ải cuối cùng nào. Thời khắc phán quyết The Silence đã điểm!\""),
			]
		9:
			var end_line = _albedou("\"Ta là Albedou, Thất Đại Pháp Sư chưa bao giờ gục ngã!\"", PLAYER_ANGRY)
			end_line["next_scene"] = "res://scenes/CreditScene.tscn"
			
			# Xong xuôi rồi mới ném nó vào mảng để return
			return [end_line]
		_:
			return []

static func _narration(text: String) -> Dictionary:
	return {
		"name": "",
		"portrait": "",
		"hide_portrait": true,
		"text": text,
	}

static func _seeker(text: String, portrait_path: String = PLAYER_NORMAL) -> Dictionary:
	return {
		"name": "The Seeker",
		"portrait": portrait_path,
		"text": text,
	}

static func _albedou(text: String, portrait_path: String = PLAYER_NORMAL) -> Dictionary:
	return {
		"name": "Albedou",
		"portrait": portrait_path,
		"text": text,
	}

static func _elaria(text: String, portrait_path: String = ELARIA_WARN) -> Dictionary:
	return {
		"name": "Elaria",
		"portrait": portrait_path,
		"text": text,
	}
