# Cập nhật Yana ngay trong app (bản thiết kế)

Trạng thái: đã duyệt cách A ngày 2026-11-27, đã viết mã và thử trên một máy.

## Hiện nay (đọc mã và bản đã cài)
- `AppUpdater.swift` hỏi GitHub Releases, tải **cả bản** (`.dmg` 475 MB) vào Downloads rồi người dùng tự kéo vào
  Applications. App chưa ký bằng Developer ID (chữ ký adhoc), `Yana.app` nặng 1,3 GB vì có Yana Studio bên trong.
- Dữ liệu người dùng nằm ngoài app (cài đặt, `~/.yana`, Keychain) nên không mất khi thay app. Nhưng chữ ký adhoc đổi
  theo mỗi bản, nên macOS có thể hỏi lại quyền Keychain và Tự động hóa.

## Muốn đạt
Bấm **Cập nhật**: app tự tải, tự kiểm, tự thay, tự mở lại. Chỉ tải phần thay đổi khi được.

## Hai cách
| | A. Dùng Sparkle 2 (đề xuất) | B. Tự viết |
|---|---|---|
| Tự thay app và mở lại | Có sẵn | Phải viết script thay thế |
| Chỉ tải phần đổi | Có (delta) | Gần như phải tự làm |
| Kiểm chữ ký bản cập nhật | EdDSA, đã dùng rộng rãi | Phải tự làm, dễ sai |
| Thư viện mới | Có (MIT, 2.10.1 ngày 2026-10-25) | Không |
| Công việc | Ít | Nhiều, rủi ro hỏng app người dùng |

## Cách A hoạt động
1. Khóa EdDSA: **chủ dự án tạo và giữ khóa riêng** (trong Keychain của máy phát hành). App chỉ chứa khóa công khai.
2. Phát hành: `scripts/package.sh` tạo `.zip`; `generate_appcast` tạo `appcast.xml`, chữ ký và các file delta; tất cả
   đính vào GitHub Release.
3. Trong app: Sparkle đọc appcast qua HTTPS, tải delta (không được thì tải cả bản), kiểm chữ ký, đóng app, thay, mở lại.
4. Giao diện: giữ bảng thông báo hiện có của Yana, nút "Cập nhật và mở lại", "Để sau", "Bỏ qua bản này", ghi chú mới.
5. Tùy chọn: tự tải ngầm, cài khi thoát app (mặc định tắt).

## An toàn
- Bản cập nhật sai chữ ký bị từ chối, app cũ còn nguyên.
- App chạy từ ổ đĩa ảnh hoặc Downloads không tự thay được: báo người dùng kéo vào Applications trước.
- Không cập nhật khi Yana đang chạy lệnh hoặc chờ duyệt; Studio đang mở thì hỏi đóng.
- Mất khóa riêng thì không phát hành cập nhật được nữa: cần cất một bản dự phòng ngoại tuyến.

## Giới hạn phải biết trước
- Người đang dùng 1.0.0 **vẫn phải cài tay một lần cuối** lên bản có Sparkle.
- Chưa có Developer ID: macOS 14.4 trở lên còn quét Gatekeeper với bản cập nhật; **phải thử trên máy thật**.
  Mua Developer ID (99 USD một năm) giúp hết cảnh báo và hết hỏi lại quyền.
- Chưa biết delta nhỏ được bao nhiêu với app 1,3 GB; đo giữa hai bản build trước khi hứa.

## Các bước làm
1. Thử nghiệm: hai bản build giả, cập nhật qua appcast cục bộ, đo delta, xem Gatekeeper và Keychain.
2. Gắn Sparkle (qua kiểm duyệt phụ thuộc), thay phần tải thủ công, giữ giao diện.
3. Sửa lỗi app đọc Keychain trên luồng chính lúc mở (cần, vì mỗi bản mới có thể làm macOS hỏi lại).
4. Sửa script đóng gói và quy trình phát hành, viết hướng dẫn cất khóa.

## Cần chủ dự án quyết
- Chọn A hay B.
- Có mua Developer ID không.
- Có tách Yana Studio thành gói tải riêng để app nhẹ hơn không (việc lớn, tính sau).

Nguồn: https://github.com/sparkle-project/Sparkle ,
https://github.com/sparkle-project/sparkle-project.github.io/blob/master/documentation/publishing/index.md

## Kết quả thử 2026-11-27 (một máy, bản build adhoc)
- Bản thử 0.0.1 tự cập nhật lên 0.0.2 qua appcast cục bộ, chỉ tải appcast và file delta; chữ ký bundle còn đúng.
- Sửa một byte trong gói: Sparkle không cài, app giữ bản cũ.
- Delta từ bản 1.0.0 đã cài sang mã hiện tại, Studio bên trong giữ nguyên: 2,5 MB (bản zip đầy đủ 428,7 MB).
  Khi Studio đổi thì gói sẽ lớn hơn; chưa đo.
- Chưa thử: giao diện hỏi cập nhật, tải qua Internet từ GitHub Releases, cảnh báo Gatekeeper và Keychain.

## Phát hành một bản (chủ dự án làm)
1. Một lần duy nhất: chạy `yana-app/.build/artifacts/sparkle/Sparkle/bin/generate_keys`. Lệnh lưu khóa riêng vào
   Keychain và in khóa công khai. Cất một bản dự phòng ngoại tuyến (`generate_keys -x <file>`), không đưa vào repo.
2. `SPARKLE_PUBLIC_KEY=<khóa công khai> STUDIO_APP=<đường dẫn> yana-app/scripts/package.sh 1.1.0`
3. `yana-app/scripts/appcast.sh 1.1.0`
4. Đính `appcast.xml`, file `.zip`, các file `.delta` và `.dmg` vào release `app-v1.1.0`.
   Giữ các zip cũ trong `yana-app/dist/updates` để lần sau còn tạo được delta.
