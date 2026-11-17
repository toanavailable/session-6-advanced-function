# Cảnh báo "Phòng Chết" (Dead Inventory)

Tìm các phòng có trong bảng `Rooms` nhưng chưa từng xuất hiện trong bảng `Bookings`. Bài phân tích vì sao `NOT IN` trả về rỗng khi gặp `NULL`, và đề xuất các cách viết an toàn.

## 1. Đề bài

- **Vấn đề:** nhiều phòng được tạo trên hệ thống nhưng chưa từng có ai đặt (Inventory chết). Giám đốc sản phẩm cần danh sách `room_id` và tên phòng thuộc diện này để nhắc đối tác hạ giá.
- **Ràng buộc:** tìm các `room_id` **có** trong `Rooms` nhưng **hoàn toàn không xuất hiện** trong `Bookings`.
- **Yêu cầu:** giải thích bẫy `NOT IN` với `NULL`, đề xuất cách khắc phục, và viết câu lệnh an toàn, tối ưu nhất.

## 2. Phân tích bẫy NOT IN và NULL

### Cách viết nguy hiểm

```sql
SELECT room_id, room_name
FROM Rooms
WHERE room_id NOT IN (SELECT room_id FROM Bookings);
```

Giả sử truy vấn con trả về danh sách `(1, 2, 2, 4, NULL)`, vì có một đơn đặt phòng bị lỗi khiến `room_id` là `NULL`.

### Giải thích bằng toán học

`NOT IN` là phép **phủ định của một chuỗi `OR`**, theo luật De Morgan biến thành **một chuỗi `AND`**:

```
x NOT IN (1, 2, 4, NULL)
⟺ NOT (x = 1 OR x = 2 OR x = 4 OR x = NULL)
⟺ x <> 1 AND x <> 2 AND x <> 4 AND x <> NULL
```

SQL dùng **logic ba giá trị**: TRUE, FALSE và UNKNOWN. Mọi phép so sánh với `NULL` đều cho ra **UNKNOWN**, nên vế cuối `x <> NULL` luôn là UNKNOWN. Khi đó:

| Trường hợp | Các vế còn lại | Kết hợp với UNKNOWN qua AND | Kết quả |
|---|---|---|---|
| Phòng 3 (thật sự chưa được đặt) | TRUE | TRUE AND UNKNOWN | **UNKNOWN** |
| Phòng 1 (đã được đặt) | có ít nhất 1 vế FALSE | FALSE AND UNKNOWN | **FALSE** |

Điều kiện **không bao giờ** đạt được TRUE với bất kỳ phòng nào. `WHERE` chỉ giữ dòng có điều kiện **TRUE**, nên kết quả là **0 dòng**.

Chỉ cần **một** bản ghi `NULL` duy nhất trong `Bookings` là toàn bộ báo cáo trả về rỗng. Câu lệnh vẫn chạy bình thường, không báo lỗi, nên Giám đốc sản phẩm sẽ tưởng rằng hệ thống **không có phòng chết nào**.

## 3. Thiết kế giải pháp an toàn

### Cách 1: Sửa truy vấn con, loại NULL trước khi so sánh

```sql
SELECT room_id, room_name
FROM Rooms
WHERE room_id NOT IN (
    SELECT room_id FROM Bookings WHERE room_id IS NOT NULL
)
ORDER BY room_id;
```

Danh sách so sánh không còn `NULL`, nên phép `AND` chỉ gồm TRUE và FALSE. Cách này đúng, nhưng phụ thuộc vào việc lập trình viên **nhớ** thêm `IS NOT NULL`. Quên một lần là lỗi quay lại.

### Cách 2: NOT EXISTS

```sql
SELECT r.room_id, r.room_name
FROM Rooms r
WHERE NOT EXISTS (
    SELECT 1 FROM Bookings b WHERE b.room_id = r.room_id
)
ORDER BY r.room_id;
```

`EXISTS` chỉ hỏi "có tồn tại dòng nào khớp không" và luôn trả về TRUE hoặc FALSE, **không bao giờ UNKNOWN**. Dòng có `room_id` là `NULL` đơn giản là không khớp với phòng nào, nên không ảnh hưởng đến kết quả.

### Cách 3: LEFT JOIN + IS NULL

```sql
SELECT r.room_id, r.room_name
FROM Rooms r
LEFT JOIN Bookings b ON b.room_id = r.room_id
WHERE b.booking_id IS NULL
ORDER BY r.room_id;
```

- `LEFT JOIN` giữ **toàn bộ phòng**. Phòng nào không có đơn đặt khớp thì các cột của `Bookings` được điền `NULL`.
- `WHERE b.booking_id IS NULL` giữ lại đúng những phòng **không khớp** với đơn nào.
- Kiểm tra `booking_id` (khóa chính, không bao giờ `NULL` trong dữ liệu thật) giúp chắc chắn `NULL` ở đây chỉ xuất hiện khi **không có dòng khớp**.
- Đơn có `room_id` là `NULL` không khớp với phòng nào, nên không làm hỏng kết quả.

### So sánh

| Tiêu chí | NOT IN (gốc) | NOT IN + IS NOT NULL | NOT EXISTS | LEFT JOIN + IS NULL |
|---|---|---|---|---|
| An toàn với NULL | ❌ Trả về rỗng | ✅ (nếu nhớ thêm điều kiện) | ✅ Luôn an toàn | ✅ Luôn an toàn |
| Hiệu năng (MySQL 8.0, có Index trên `Bookings.room_id`) | Có thể phải duyệt cả danh sách | Tốt | Tốt, được tối ưu thành anti-join | Tốt, được tối ưu thành anti-join |
| Dễ đọc | Dễ nhưng sai | Dễ | Rõ ý "không tồn tại" | Quen thuộc, dùng kiến thức JOIN |

## 4. Code hoàn chỉnh

```sql
CREATE INDEX idx_bookings_room ON Bookings (room_id);

SELECT r.room_id, r.room_name
FROM Rooms r
LEFT JOIN Bookings b ON b.room_id = r.room_id
WHERE b.booking_id IS NULL
ORDER BY r.room_id;
```

Chọn **LEFT JOIN + IS NULL** vì an toàn với `NULL` mà không phụ thuộc vào việc nhớ thêm điều kiện, và có thể dùng Index trên `Bookings.room_id` để dò nhanh từng phòng thay vì quét cả bảng. `NOT EXISTS` là lựa chọn tương đương về độ an toàn và hiệu năng.

### Mở rộng: phòng không được đặt trong 1 năm gần nhất

Bối cảnh đề bài nhắc đến "suốt 1 năm qua". Nếu cần đúng mốc thời gian này, đưa điều kiện ngày vào **mệnh đề `ON`**:

```sql
SELECT r.room_id, r.room_name
FROM Rooms r
LEFT JOIN Bookings b
       ON b.room_id = r.room_id
      AND b.booking_date >= CURDATE() - INTERVAL 1 YEAR
WHERE b.booking_id IS NULL
ORDER BY r.room_id;
```

Phải đặt điều kiện ngày trong `ON`. Nếu đặt trong `WHERE`, các dòng có `booking_date` là `NULL` (phòng không khớp đơn nào) sẽ bị loại, và `LEFT JOIN` trở thành `INNER JOIN`, nên kết quả rỗng.

## 5. Kết quả

Dữ liệu mẫu:

| Bảng | Dữ liệu |
|---|---|
| `Rooms` | Phòng 1 đến 6 |
| `Bookings` | Phòng 1 (2026), phòng 2 (2 đơn năm 2026), phòng 4 (2024), và **1 đơn có `room_id` NULL** |

| Câu lệnh | Kết quả (room_id) |
|---|---|
| `NOT IN` gốc | **Rỗng** (dính bẫy NULL) |
| `NOT IN` + `IS NOT NULL` | 3, 5, 6 |
| `NOT EXISTS` | 3, 5, 6 |
| `LEFT JOIN` + `IS NULL` | 3, 5, 6 |
| Mở rộng 1 năm gần nhất (chạy ngày 17/11/2026) | 3, 4, 5, 6 |

Kết quả của câu lệnh chốt:

| room_id | room_name |
|---|---|
| 3 | Suite Tổng thống |
| 5 | Family Room |
| 6 | Bungalow Hướng Núi |

## 6. Bài học rút ra

- **Không dùng `NOT IN` với truy vấn con** trên cột có thể chứa `NULL`. Một giá trị `NULL` là đủ để kết quả thành rỗng.
- Nguyên nhân là **logic ba giá trị**: `x <> NULL` là UNKNOWN, và `TRUE AND UNKNOWN` vẫn là UNKNOWN.
- Ưu tiên **`NOT EXISTS`** hoặc **`LEFT JOIN … IS NULL`** để tìm dữ liệu "có ở bảng A nhưng không có ở bảng B".
- Với `LEFT JOIN … IS NULL`, kiểm tra `IS NULL` trên **khóa chính** của bảng bên phải.
- Điều kiện lọc bảng bên phải của `LEFT JOIN` đặt trong **`ON`**, không đặt trong `WHERE`.
