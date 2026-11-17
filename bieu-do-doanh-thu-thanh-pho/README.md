# Fix bug Module "Biểu đồ Doanh thu theo Thành phố"

Phân tích vì sao đặt hàm `SUM()` trong mệnh đề `WHERE` khiến Database Engine từ chối câu lệnh, và viết lại truy vấn đúng để lấy dữ liệu cho biểu đồ tròn doanh thu theo thành phố.

## 1. Đề bài

- **Nghiệp vụ:** Ban Giám đốc cần biểu đồ tròn trên Dashboard hiển thị **tổng doanh thu của mỗi thành phố** (ví dụ Đà Nẵng: 5 tỷ, Nha Trang: 3 tỷ) để phân bổ ngân sách Marketing.
- **Đoạn code của Fresher:**

```sql
SELECT city, SUM(total_price) AS revenue
FROM Bookings
WHERE status = 'COMPLETED' AND SUM(total_price) > 0
GROUP BY city;
```

- **Nỗi đau:** hệ thống báo lỗi cú pháp, truy vấn không chạy được, dù logic "lấy doanh thu lớn hơn 0" nghe có vẻ hoàn toàn đúng.

## 2. Phân tích lỗi

### Thứ tự thực thi (Execution Order)

Database không chạy câu lệnh theo thứ tự viết, mà theo thứ tự logic:

```
FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY
```

| Bước | Mệnh đề | Dữ liệu đang có |
|---|---|---|
| 1 | `FROM Bookings` | Toàn bộ các đơn đặt phòng |
| 2 | `WHERE ...` | Từng **đơn lẻ**, **chưa gom nhóm** |
| 3 | `GROUP BY city` | Các nhóm theo thành phố |
| 4 | `HAVING ...` | Mỗi nhóm đã có giá trị `SUM()` |
| 5 | `SELECT ...` | Chọn cột hiển thị |

### Vì sao bị từ chối?

`WHERE` chạy ở **bước 2**, khi Database đang xét **từng đơn đặt phòng riêng lẻ**. Lúc này dữ liệu chưa được chia theo thành phố, nên **chưa tồn tại "tổng doanh thu của một thành phố"** để so sánh với 0. `SUM()` chỉ có ý nghĩa sau khi `GROUP BY` đã gom các dòng thành nhóm ở bước 3.

Vì vậy, dùng hàm tổ hợp trong `WHERE` là sai quy tắc. MySQL từ chối ngay với lỗi:

```
ERROR 1111 (HY000): Invalid use of group function
```

Logic "doanh thu lớn hơn 0" của Fresher là đúng, nhưng đặt **sai chỗ**. Điều kiện trên kết quả của hàm tổ hợp phải đặt ở `HAVING`, mệnh đề chạy **sau** `GROUP BY`.

### Tách hai loại điều kiện

| Điều kiện | Áp dụng cho | Đặt ở |
|---|---|---|
| `status = 'COMPLETED'` | Từng **đơn** (cột thường) | `WHERE` |
| `SUM(total_price) > 0` | Từng **thành phố** (hàm tổ hợp) | `HAVING` |

## 3. Lời giải

```sql
SELECT city, SUM(total_price) AS revenue
FROM Bookings
WHERE status = 'COMPLETED'
GROUP BY city
HAVING SUM(total_price) > 0
ORDER BY revenue DESC;
```

- `WHERE status = 'COMPLETED'`: loại các đơn bị hủy hoặc chưa hoàn tất **trước khi** gom nhóm. Đặt điều kiện này ở `WHERE` (không phải `HAVING`) giúp giảm dữ liệu phải gom nhóm và tính tổng.
- `GROUP BY city`: gom các đơn còn lại theo từng thành phố.
- `HAVING SUM(total_price) > 0`: loại các thành phố có tổng doanh thu bằng 0, vì một lát cắt 0% trên biểu đồ tròn không có ý nghĩa.
- `ORDER BY revenue DESC`: sắp thành phố doanh thu cao nhất lên đầu để biểu đồ dễ đọc.

## 4. Kết quả

Dữ liệu mẫu có 9 đơn ở 5 thành phố:

| booking_id | city | total_price | status | Xử lý |
|---|---|---|---|---|
| 1 | Đà Nẵng | 2.000.000.000 | COMPLETED | ✅ Tính |
| 2 | Đà Nẵng | 3.000.000.000 | COMPLETED | ✅ Tính |
| 3 | Đà Nẵng | 1.500.000.000 | CANCELLED | Loại ở `WHERE` |
| 4 | Nha Trang | 1.000.000.000 | COMPLETED | ✅ Tính |
| 5 | Nha Trang | 2.000.000.000 | COMPLETED | ✅ Tính |
| 6 | Nha Trang | 500.000.000 | PENDING | Loại ở `WHERE` |
| 7 | Phú Quốc | 4.000.000.000 | COMPLETED | ✅ Tính |
| 8 | Huế | 800.000.000 | CANCELLED | Loại ở `WHERE`, Huế không còn đơn nào |
| 9 | Đà Lạt | 0 | COMPLETED | Qua `WHERE`, nhưng tổng = 0 nên loại ở `HAVING` |

Kết quả trả về cho biểu đồ:

| city | revenue |
|---|---|
| Đà Nẵng | 5.000.000.000 |
| Phú Quốc | 4.000.000.000 |
| Nha Trang | 3.000.000.000 |

Đà Nẵng 5 tỷ và Nha Trang 3 tỷ khớp với ví dụ trong đề bài.

## 5. Bài học rút ra

- Database chạy theo thứ tự **FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY**, không theo thứ tự viết.
- **Không dùng hàm tổ hợp** (`SUM`, `COUNT`, `AVG`, `MAX`, `MIN`) trong `WHERE`, vì lúc đó dữ liệu chưa được gom nhóm.
- Điều kiện trên **cột thường** đặt ở `WHERE`, điều kiện trên **hàm tổ hợp** đặt ở `HAVING`.
- Lọc càng sớm càng tốt: đưa mọi điều kiện có thể lên `WHERE` để giảm khối lượng dữ liệu phải gom nhóm.
