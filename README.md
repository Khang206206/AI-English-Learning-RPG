# AI English Learning RPG

AI English Learning RPG là game nhập vai học tiếng Anh được xây dựng bằng Godot. Người chơi luyện từ vựng, ngữ pháp và phản xạ tiếng Anh thông qua khám phá bản đồ, tương tác NPC, notebook học tập và các trận chiến dạng câu hỏi.

Game được thiết kế để chạy offline. Phần AI local qua Ollama là tuỳ chọn, dùng để tạo nội dung học phong phú hơn khi máy người chơi đã có sẵn Ollama và model phù hợp.

## Tải Bản Chơi Ngay

Người chơi không cần clone repo và không cần cài Godot.

1. Vào mục **Releases** của repository.
2. Tải file `Game-Windows.zip` trong phần **Assets**.
3. Giải nén toàn bộ file zip.
4. Mở thư mục đã giải nén.
5. Chạy `Game.exe`.

Không tách riêng `Game.exe` khỏi các file đi kèm. Bản build cần `Game.pck`, thư mục `.godot`, `addons` và `data` để load game, database và SQLite extension.

## Yêu Cầu Hệ Thống

- Hệ điều hành: Windows 10/11 64-bit.
- Không cần internet để chơi sau khi đã tải game.
- Không cần Godot Editor.
- Ollama là tuỳ chọn, không bắt buộc.

## Chế Độ Offline

Các phần cốt lõi chạy trực tiếp trên máy người chơi:

- Gameplay và battle.
- Save data.
- Database từ vựng, ngữ pháp, quái vật và vật phẩm.
- Câu hỏi fallback trong battle.
- Notebook và tiến trình học tập.

Nếu không có Ollama, game vẫn chơi được. Tuy nhiên, một số nội dung AI động như gợi ý NPC, câu ví dụ, mini test hoặc câu hỏi sinh theo ngữ cảnh sẽ đơn giản hơn hoặc dùng fallback local.

## Ollama Tuỳ Chọn

Nếu người chơi muốn trải nghiệm AI local đầy đủ hơn, có thể cài Ollama và tải model:

```powershell
ollama pull qwen3.5:4b
ollama serve
```

Thông tin mặc định trong game:

```text
Ollama URL: http://127.0.0.1:11434/api/chat
Model: qwen3.5:4b
```

`127.0.0.1` là địa chỉ local trên máy người chơi. Game không gửi request AI ra server bên ngoài trong cấu hình mặc định này.

Nếu cần dùng endpoint Ollama khác:

```powershell
$env:AI_RPG_OLLAMA_URL="http://127.0.0.1:11434/api/chat"
```

## Cấu Trúc Bản Build Windows

File release `Game-Windows.zip` sau khi giải nén cần có cấu trúc:

```text
Game.exe
Game.pck
.godot/
  extension_list.cfg
addons/
  godot-sqlite/
    gdsqlite.gdextension
    bin/
      libgdsqlite.windows.template_release.x86_64.dll
data/
  data.db
  enemies.csv
  grammar.csv
  vocabulary.csv
```

Nếu thiếu các file hoặc thư mục trên, game có thể không mở được hoặc không load được database.

## Ghi Chú Phiên Bản

- Vàng khởi đầu của save mới là `0`.
- Cheat thắng trận bằng phím `E` đã bị vô hiệu hoá.
- Save runtime được lưu tại `user://data.db`.
- Database seed được copy từ `res://data/data.db` trong lần chạy đầu.
- SQLite GDExtension phải được phát hành kèm bản build.

Nếu máy đã từng chạy bản cũ, save cũ có thể vẫn giữ trạng thái hoặc số vàng cũ. Để kiểm tra trải nghiệm người chơi mới, hãy tạo New Game/reset save hoặc xoá save cũ trong userdata của Godot.

## Phát Triển Từ Source

Dự án sử dụng Godot 4.6.x.

Để chạy từ source:

1. Clone repository.
2. Mở project bằng Godot.
3. Đảm bảo addon `godot-sqlite` tồn tại trong thư mục `addons`.
4. Chạy project từ scene chính đã cấu hình trong `project.godot`.

Để export Windows, dùng preset `Windows Desktop` trong `export_presets.cfg`.

## Công Nghệ Chính

- Godot 4.6.x
- GDScript
- SQLite qua Godot SQLite GDExtension
- Ollama local AI, tuỳ chọn
- Model mặc định: `qwen3.5:4b`
