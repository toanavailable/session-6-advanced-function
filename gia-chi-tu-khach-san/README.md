# Tính năng "Giá chỉ từ..." trên danh sách Khách sạn

Phân tích vì sao đưa cột `room_name` vào câu lệnh `GROUP BY hotel_id` vi phạm quy tắc gom nhóm và gây lỗi `ONLY_FULL_GROUP_BY` trên MySQL 8.0, đồng thời viết lại truy vấn lấy giá phòng rẻ nhất của mỗi khách sạn.

## 1. Đề bài

- **Nghiệp vụ:** dưới tên mỗi khách sạn trên màn hình tìm kiếm, hiển thị nhãn **"Giá chỉ từ: X VNĐ"**, với X là giá của căn phòng rẻ nhất thuộc khách sạn đó.
- **Đoạn code đang chạy trên server:**

```sql
SELECT hotel_id, room_name, MIN(price_per_night)
FROM Rooms
GROUP BY hotel_id;
```

- **Nỗi đau:** trên MySQL 8.0 (Strict Mode), câu lệnh báo lỗi `ONLY_FULL_GROUP_BY`.

## 2. Phân tích kiến trúc

### Quy tắc của phép gom nhóm

Sau `GROUP BY hotel_id`, **mỗi khách sạn chỉ còn đúng một dòng kết quả**. Vì vậy mỗi cột trong `SELECT` phải trả về **đúng một giá trị cho mỗi nhóm**, tức phải thuộc một trong hai loại:

1. **Cột nằm trong `GROUP BY`**: `hotel_id` có cùng một giá trị trong cả nhóm, nên hiển thị được.
2. **Cột nằm trong hàm tổ hợp**: `MIN(price_per_night)` gộp nhiều giá trị thành một con số duy nhất, nên hiển thị được.

### Vì sao `room_name` vi phạm?

`room_name` **không thuộc loại nào**. Một khách sạn có nhiều phòng với nhiều tên khác nhau, nên trong một nhóm có nhiều giá trị `room_name` nhưng chỉ có một ô để hiển thị:

| hotel_id | Các room_name trong nhóm | Ô hiển thị |
|---|---|---|
| 101 | Deluxe Ocean View, Standard Twin, Suite | ? |

Về mặt toán học, mỗi nhóm phải ánh xạ tới **một** giá trị, nhưng ở đây một nhóm ứng với **nhiều** giá trị. Database không có cơ sở để chọn tên nào.

Điểm mấu chốt là **`MIN()` chỉ tìm ra giá trị nhỏ nhất, chứ không "nhớ" giá trị đó thuộc dòng nào**. Các hàm tổ hợp tính trên cột một cách độc lập, nên `MIN(price_per_night)` không kéo theo `room_name` của căn phòng rẻ nhất.

### Hậu quả

- **MySQL 8.0** bật mặc định `ONLY_FULL_GROUP_BY`, nên **từ chối** câu lệnh (`ERROR 1055 ... incompatible with sql_mode=only_full_group_by`).
- Nếu tắt chế độ này (hoặc trên MySQL đời cũ), câu lệnh **chạy được nhưng sai**: MySQL lấy `room_name` của một dòng **bất kỳ** trong nhóm. Màn hình có thể hiện "Suite, giá chỉ từ 800.000đ", trong khi phòng Suite thực ra giá 5.000.000đ. Đây là lỗi nguy hiểm hơn vì không có thông báo nào.

## 3. Lời giải

Bỏ cột `room_name`, chỉ giữ cột phân nhóm và hàm tổ hợp:

```sql
SELECT hotel_id,
       MIN(price_per_night) AS min_price
FROM Rooms
GROUP BY hotel_id
ORDER BY hotel_id;
```

- `GROUP BY hotel_id`: gom các phòng theo từng khách sạn.
- `MIN(price_per_night) AS min_price`: lấy giá thấp nhất trong mỗi nhóm, dùng làm X cho nhãn "Giá chỉ từ".
- Mọi cột trong `SELECT` đều hợp lệ với `ONLY_FULL_GROUP_BY`.

### Mở rộng: nếu vẫn cần tên phòng rẻ nhất

Đề bài chấp nhận bỏ tên phòng, nhưng nếu sau này cần, phải tìm giá thấp nhất trước rồi **so khớp lại với bảng gốc** để lấy đúng dòng:

```sql
SELECT r.hotel_id, r.room_name, r.price_per_night AS min_price
FROM Rooms r
JOIN (
    SELECT hotel_id, MIN(price_per_night) AS min_price
    FROM Rooms
    GROUP BY hotel_id
) m ON r.hotel_id = m.hotel_id
   AND r.price_per_night = m.min_price
ORDER BY r.hotel_id, r.room_name;
```

Nếu nhiều phòng cùng có giá thấp nhất, cách này trả về **tất cả** các phòng đó, như khách sạn 103 trong dữ liệu mẫu.

## 4. Kết quả

Dữ liệu mẫu:

| room_id | hotel_id | room_name | price_per_night |
|---|---|---|---|
| 1 | 101 | Deluxe Ocean View | 2.500.000 |
| 2 | 101 | Standard Twin | 800.000 |
| 3 | 101 | Suite | 5.000.000 |
| 4 | 102 | Superior Double | 1.200.000 |
| 5 | 102 | Family Room | 1.800.000 |
| 6 | 103 | Dorm Bed | 300.000 |
| 7 | 103 | Private Room | 650.000 |
| 8 | 103 | Capsule | 300.000 |

Kết quả của truy vấn đã sửa:

| hotel_id | min_price | Nhãn hiển thị |
|---|---|---|
| 101 | 800.000 | Giá chỉ từ: 800.000 VNĐ |
| 102 | 1.200.000 | Giá chỉ từ: 1.200.000 VNĐ |
| 103 | 300.000 | Giá chỉ từ: 300.000 VNĐ |

Kết quả của truy vấn mở rộng:

| hotel_id | room_name | min_price |
|---|---|---|
| 101 | Standard Twin | 800.000 |
| 102 | Superior Double | 1.200.000 |
| 103 | Capsule | 300.000 |
| 103 | Dorm Bed | 300.000 |

## 5. Bài học rút ra

- Khi dùng `GROUP BY`, mọi cột trong `SELECT` phải **nằm trong `GROUP BY`** hoặc **nằm trong hàm tổ hợp**.
- Hàm tổ hợp như `MIN`/`MAX` chỉ trả về **giá trị**, không trả về **dòng** chứa giá trị đó.
- Không tắt `ONLY_FULL_GROUP_BY` để "chữa cháy": lỗi sẽ không biến mất mà chỉ chuyển thành dữ liệu sai một cách âm thầm.
- Muốn lấy thêm thông tin của dòng đạt giá trị nhỏ nhất/lớn nhất, hãy dùng truy vấn con kết hợp `JOIN` để so khớp lại với bảng gốc.
