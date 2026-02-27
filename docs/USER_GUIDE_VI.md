# Hướng Dẫn Sử Dụng Và Kiểm Thử TapMacro (Tiếng Việt)

Phiên bản tài liệu: 2.1  
Ngày cập nhật: 2026-02-27  
Đối tượng: Người mới hoàn toàn, chưa từng dùng app auto clicker

---

## 1) TapMacro là gì?

`TapMacro` là ứng dụng Android giúp bạn tự động hóa thao tác chạm trên màn hình theo kịch bản (`script`) do bạn tạo.

Ứng dụng hoạt động dựa trên:

1. `Accessibility Service` để gửi thao tác chạm/gesture.
2. `Overlay` để hiển thị bộ điều khiển nổi và marker vị trí chạm.
3. `Foreground Service` để duy trì trạng thái chạy ổn định, có thông báo rõ ràng khi đang chạy/ghi.

---

## 2) Trước khi bắt đầu: hiểu đúng về phạm vi app

App phù hợp cho:

1. Tự động thao tác lặp lại (tap, double tap, swipe, multi-touch).
2. Ghi lại thao tác tap cơ bản rồi chỉnh sửa lại trong editor.
3. Chạy theo lịch (scheduler) trong các điều kiện cụ thể.

App không phù hợp cho:

1. Màn hình chứa dữ liệu nhạy cảm (mật khẩu, OTP, thanh toán).
2. App đích có policy cấm automation.
3. Tác vụ yêu cầu độ chính xác tuyệt đối khi layout app đích thay đổi liên tục.

---

## 3) Thuật ngữ quan trọng

1. `Script`: Bộ kịch bản tự động.
2. `Step`: Một hành động trong script.
3. `Loop`: Số lần lặp script.
4. `Interval`: Khoảng nghỉ giữa các step.
5. `Run Options`: Tuỳ chọn trước khi chạy (delay, stop rule, performance mode).
6. `Recorder`: Màn ghi thao tác để tạo script.
7. `Scheduler`: Đặt lịch chạy script (once/daily/weekly).
8. `Condition`: Điều kiện bắt buộc trước/trong lúc chạy (pin, màn hình, app foreground, khung giờ, charging).

---

## 4) Checklist cài đặt lần đầu (bắt buộc)

Mở app lần đầu và làm đúng thứ tự sau:

1. Hoàn tất `Onboarding`.
2. Vào `Permissions Hub` và bật:
   - Accessibility
   - Overlay (Draw over other apps)
   - Notifications
   - Exact Alarm (khuyến nghị để scheduler ổn định)
3. Tắt tối ưu pin cho TapMacro (nếu máy có mục Battery optimization).
4. Mở `Settings` và bật `Volume Key Stop` để có nút dừng khẩn cấp phụ.
5. Tuỳ nhu cầu, chọn `Default Home Mode` trong `Settings`.

Kết quả mong đợi:

1. Trong Permissions Hub, các mục chính báo trạng thái `ON`.
2. Nút tiếp tục vào Home hoạt động bình thường.

---

## 5) Tổng quan các màn hình chính

1. `Home Shell`: màn chính có 2 tab `Normal` và `Advanced`.
2. `Normal`: dùng nhanh cho user phổ thông (1 mục tiêu, nhiều mục tiêu, dừng nhanh).
3. `Advanced`: toàn bộ chức năng đầy đủ trước đây (script/editor/recorder/scheduler/import-export).
4. `Script List`: Danh sách script, tạo/sửa/chạy/xoá.
5. `Script Editor`: Chỉnh step, timing, gesture, conditions.
6. `Recorder`: Ghi thao tác thành script.
7. `Import/Export`: Nhập/xuất script theo 2 định dạng.
8. `Scheduler`: Đặt lịch chạy script.
9. `Settings`: Tùy chọn hành vi app.
10. `Help`: Hướng dẫn xử lý sự cố, xuất support log.
11. `Privacy Policy`: Mô tả dữ liệu và cách app dùng Accessibility.

### Cách chọn tab cho đúng nhu cầu

1. Dùng `Normal` nếu bạn chỉ cần chạy nhanh và ít chỉnh sâu.
2. Dùng `Advanced` nếu bạn cần editor chi tiết, recorder, scheduler, import/export.
3. Bạn có thể chuyển qua lại giữa 2 tab bất kỳ lúc nào, dữ liệu script dùng chung.
4. Lần đầu vào Home, app sẽ hỏi bạn chọn mode mặc định.
5. Có thể mở lại hộp chọn mode trong `Settings > Show mode chooser again`.

---

## 6) Luồng dùng chuẩn cho người mới

Dùng đúng luồng này để giảm lỗi:

1. Cấp quyền đầy đủ.
2. Tạo script đơn giản (1-2 step).
3. Chạy thử loop nhỏ (3-5 vòng).
4. Chỉnh vị trí bằng overlay nếu lệch.
5. Tăng loop/độ phức tạp dần.
6. Export backup sau khi script chạy ổn định.

---

## 7) Hướng dẫn tạo script từ đầu (chi tiết)

### 7.1 Tạo script mới

1. Mở `Script List`.
2. Nhấn `New Script`.
3. Đặt tên rõ nghĩa, ví dụ `farm_coin_daily`.
4. Lưu script.

### 7.2 Thêm step bằng overlay

1. Trong `Script Editor`, vào tab mục tiêu/targets.
2. Chọn thêm điểm bằng overlay.
3. Kéo marker đến vị trí cần tap.
4. Xác nhận lưu marker.
5. Lặp lại để thêm step tiếp theo.

### 7.3 Chọn loại gesture cho từng step

Tuỳ use case, chỉnh step thành:

1. `tap`: Chạm 1 lần.
2. `double_tap`: Chạm 2 lần.
3. `swipe`: Vuốt từ điểm A đến điểm B.
4. `multi_touch`: Chạm đa điểm.

### 7.4 Chỉnh timing và loop

1. Đặt `intervalMs` phù hợp (khởi đầu 250-500ms).
2. Đặt `loopCount` nhỏ để test trước.
3. Nếu cần giữ lâu, chỉnh `holdMs` cho step.

### 7.5 Chỉnh conditions (nếu cần)

Bạn có thể bật:

1. `requireCharging`.
2. `requireScreenOn`.
3. `requireForegroundApp`.
4. `minBatteryPct`.
5. `timeWindow` (khung giờ chạy).

### 7.6 Validate và Save

1. Nhấn `Validate`.
2. Nếu không lỗi, nhấn `Save`.

---

## 8) Cách chạy script đúng chuẩn

### 8.1 Chạy thủ công

1. Từ `Home`, `Script List`, hoặc `Script Editor`, nhấn `Run`.
2. Màn `Run Options` xuất hiện.
3. Chọn:
   - Start delay
   - Stop rule
   - Performance mode
4. Xác nhận chạy.

### 8.2 Khi đang chạy

1. Bộ điều khiển nổi xuất hiện.
2. Có thể `Pause` hoặc `Resume`.
3. Có thể `Stop` bất kỳ lúc nào.

### 8.3 Dừng khẩn cấp

Dùng một trong các cách:

1. Nút `STOP` trên overlay.
2. Nút stop trong Home/panel.
3. Nút volume nếu đã bật `Volume Key Stop`.

---

## 9) Cách dùng Recorder (ghi thao tác)

### 9.1 Ghi mới

1. Mở `Recorder`.
2. Nhấn `Start Recording`.
3. App đếm ngược (thường 3 giây).
4. Thực hiện thao tác tap cần ghi.
5. Nhấn `Stop Recording`.

### 9.2 Sửa timeline sau ghi

1. Xem danh sách step đã ghi.
2. Chỉnh step sai toạ độ/delay.
3. Xoá step thừa.
4. Thêm step thủ công nếu cần.

### 9.3 Lưu thành script

1. Nhấn `Save As Script`.
2. Đặt tên script.
3. Mở Script List để kiểm tra script vừa tạo.

---

## 10) Import / Export (2 định dạng)

App hỗ trợ:

1. `Schema 1.0 JSON`.
2. `Internal JSON`.

### 10.1 Export

1. Mở `Import/Export`.
2. Chọn định dạng.
3. Chọn `Export Selected` hoặc `Export All`.
4. Kiểm tra file đã được tạo.

### 10.2 Import

1. Chọn file JSON.
2. App tự nhận diện format.
3. Nếu hợp lệ, script xuất hiện trong Script List.
4. Nếu trùng ID, app tự tạo ID mới để tránh ghi đè.

### 10.3 Xử lý lỗi import thường gặp

1. JSON hỏng hoặc thiếu field bắt buộc.
2. Sai schemaVersion cho Schema 1.0.
3. Sai kiểu dữ liệu step/condition.

Nguyên tắc an toàn:

1. File sai sẽ bị reject toàn bộ.
2. Không ghi dữ liệu nửa chừng vào repository.

---

## 11) Scheduler (đặt lịch chạy)

### 11.1 Các kiểu lịch

1. `Once`: Chạy 1 lần tại thời điểm cụ thể.
2. `Daily`: Chạy mỗi ngày.
3. `Weekly`: Chạy theo thứ trong tuần.

### 11.2 Tạo lịch chuẩn

1. Mở `Scheduler`.
2. Chọn script cần chạy.
3. Chọn kiểu lịch.
4. Chọn thời gian.
5. Với weekly: chọn đúng các thứ.
6. Bật schedule.

### 11.3 Điều kiện để scheduler chạy ổn

1. Exact Alarm nên bật.
2. Accessibility và Overlay phải còn ON.
3. App không bị hệ thống chặn nền quá mạnh.
4. Conditions của script phải thoả tại thời điểm chạy.

---

## 12) Quy trình test app từ A-Z cho người mới

Dưới đây là kịch bản test thực chiến. Làm theo thứ tự:

### Test Case 1: Khởi tạo và quyền

1. Cài app mới.
2. Mở app, đi qua onboarding.
3. Bật lần lượt quyền trong Permissions Hub.

Kỳ vọng:

1. Không crash.
2. Trạng thái quyền cập nhật đúng ngay sau khi quay lại app.

### Test Case 2: Script tối thiểu

1. Tạo script 1 step tap.
2. Loop 3 lần.
3. Run script.

Kỳ vọng:

1. Tap đúng vị trí.
2. Dừng đúng sau 3 vòng.

### Test Case 3: Script nhiều gesture

1. Tạo script gồm tap, double_tap, swipe.
2. Run với interval 300ms.

Kỳ vọng:

1. Thứ tự step đúng.
2. Không bỏ step.

### Test Case 4: Condition fail

1. Bật `requireCharging`.
2. Rút sạc và bấm run.

Kỳ vọng:

1. App không chạy.
2. Hiển thị cảnh báo condition rõ ràng.

### Test Case 5: Recorder roundtrip

1. Ghi 5 thao tác tap.
2. Save thành script.
3. Run script mới.

Kỳ vọng:

1. Script mới xuất hiện trong danh sách.
2. Chạy được.

### Test Case 6: Import/Export roundtrip

1. Export script theo `Schema 1.0`.
2. Import lại file vừa export.
3. Run script import.
4. Lặp lại với `Internal JSON`.

Kỳ vọng:

1. Import thành công.
2. Script chạy đúng.

### Test Case 7: Scheduler once

1. Tạo lịch `Once` sau 2-3 phút.
2. Chờ trigger.

Kỳ vọng:

1. Script được trigger đúng thời điểm.
2. Trạng thái lịch cập nhật bình thường.

### Test Case 8: Dừng khẩn cấp

1. Chạy script loop cao.
2. Bấm STOP overlay.
3. Chạy lại và thử volume key stop.

Kỳ vọng:

1. Dừng tức thời.
2. Không treo app.

### Test Case 9: Đổi orientation/môi trường

1. Chạy script ở portrait.
2. Đổi landscape, chạy lại.

Kỳ vọng:

1. Nếu lệch vị trí, chỉnh lại marker được.
2. App không crash.

### Test Case 10: Reboot máy

1. Đặt lịch weekly.
2. Reboot máy.
3. Kiểm tra lịch có được restore.

Kỳ vọng:

1. Lịch vẫn tồn tại.
2. Vẫn có thể trigger theo lịch.

---

## 13) Edge case bạn nên test thêm

1. Tắt Accessibility khi script đang chạy.
2. Tắt Overlay khi script đang chạy.
3. Pin xuống dưới ngưỡng `minBatteryPct` khi đang chạy.
4. App đích không còn ở foreground khi bật `requireForegroundApp`.
5. Ra ngoài `timeWindow` giữa chừng.
6. Import file JSON corrupt.
7. Import file thiếu step bắt buộc.

Kỳ vọng chung:

1. App dừng an toàn.
2. Có thông báo lỗi rõ ràng.
3. Không mất dữ liệu script cũ.

---

## 14) Cách đọc lỗi nhanh và sửa đúng

### Lỗi: bấm Run nhưng không chạy

Kiểm tra:

1. Accessibility ON chưa.
2. Overlay ON chưa.
3. Script có step enabled không.
4. Có condition nào đang fail không.

### Lỗi: chạy sai vị trí

Khắc phục:

1. Vào editor kéo lại marker bằng overlay.
2. Giữ cố định orientation.
3. Tăng interval nếu app đích chuyển màn hình chậm.

### Lỗi: scheduler không trigger

Khắc phục:

1. Bật Exact Alarm.
2. Bỏ tối ưu pin cho app.
3. Kiểm tra giờ hệ thống.
4. Kiểm tra condition của script tại thời điểm trigger.

### Lỗi: import thất bại

Khắc phục:

1. Kiểm tra JSON hợp lệ.
2. Đảm bảo đúng format schema/internal.
3. Test lại bằng file export trực tiếp từ app.

---

## 15) Khuyến nghị vận hành an toàn

1. Luôn bắt đầu với loop nhỏ.
2. Luôn có phương án dừng khẩn cấp.
3. Không chạy script trên màn hình nhạy cảm.
4. Backup định kỳ bằng export.
5. Đặt tên script theo mục đích và môi trường chạy.

---

## 16) Checklist trước khi dùng hằng ngày

1. Accessibility ON.
2. Overlay ON.
3. Exact Alarm ON nếu dùng scheduler.
4. Script đã validate.
5. Đã test nhanh 1 vòng trước khi chạy dài.

---

## 17) Checklist trước khi release nội bộ cho tester

1. `flutter analyze` pass.
2. `flutter test` pass.
3. Build debug/release thành công.
4. Chạy full 10 test case ở mục 12.
5. Chạy edge cases ở mục 13.
6. Xuất support logs khi có lỗi.

---

## 18) Mẫu báo lỗi gửi kỹ thuật

```text
Thiết bị: [VD: Pixel 7 / Samsung S23 / Xiaomi 13]
Android: [VD: 14]
Phiên bản app: [x.y.z]
Màn hình gặp lỗi: [Home/Editor/Recorder/Scheduler/...]
Các bước tái hiện:
1) ...
2) ...
3) ...
Kỳ vọng: [...]
Thực tế: [...]
Ảnh/video: [link]
Support log: [đính kèm]
```

---

## 19) FAQ ngắn

1. App có cần internet để chạy script không?  
Không bắt buộc cho tính năng chạy script cục bộ.

2. Vì sao phải dùng Accessibility?  
Android yêu cầu cơ chế này để app có thể thực hiện thao tác tự động.

3. Vì sao phải dùng Overlay?  
Để hiển thị nút điều khiển nổi và marker chỉnh toạ độ.

4. Có nên chạy khi tắt màn hình không?  
Không nên, độ ổn định thấp và nhiều condition có thể fail.

---

## 20) Lộ trình học dùng app trong 60 phút

1. 10 phút đầu: cấp quyền + làm quen Home/Script List.
2. 15 phút tiếp: tạo script 2 step và chạy thử.
3. 15 phút tiếp: dùng recorder ghi script ngắn rồi save.
4. 10 phút tiếp: export/import 1 script.
5. 10 phút cuối: tạo scheduler once và test dừng khẩn cấp.

Nếu hoàn thành hết mục này, bạn đã đủ tự tin để sử dụng app hằng ngày và bắt đầu QA nâng cao.
