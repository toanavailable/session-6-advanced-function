# Module "Top User VIP Theo Từng Hạng Phòng"

Lắp ráp một câu lệnh SQL duy nhất kết hợp JOIN 3 bảng, hàm tổng hợp, gom nhóm nhiều cột, lọc ở `WHERE` và `HAVING`, và sắp xếp nhiều tầng, để tìm khách hàng chi tiêu nhiều nhất theo từng hạng sao khách sạn.

## 1. Đề bài

Bộ phận CSKH muốn tặng voucher Tết cho **những khách hàng chi nhiều tiền nhất, tương ứng với từng hạng khách sạn**.

| # | Yêu cầu | Kỹ thuật SQL |
|---|---|---|
| 1 | Hiển thị Tên khách hàng, Hạng khách sạn, Tổng tiền đã chi cho hạng đó | `JOIN` 3 bảng + `SUM()` |
| 2 | Chỉ tính đơn thành công (`status = 'COMPLETED'`) | `WHERE` |
| 3 | Chỉ hiển thị khách có tổng chi cho **một hạng** > 50.000.000 VNĐ | `HAVING` |
| 4 | 5 sao xếp đầu, cùng hạng thì ai chi nhiều hơn đứng trên | `ORDER BY` 2 tầng |

**Nỗi đau kỹ thuật:** dữ liệu nằm ở 3 bảng `Users` (tên), `Bookings` (doanh thu, trạng thái), `Hotels` (hạng sao). `GROUP BY` sai sẽ gộp nhầm chi tiêu ở khách sạn 4 sao với 5 sao.

## 2. Bản vẽ Data Flow & Grouping

### Luồng dữ liệu

```
 Users (user_id, full_name)        Bookings (user_id, hotel_id,        Hotels (hotel_id, star_rating)
            │                          status, total_price)                       │
            └──────── JOIN ON user_id ─────────┴──────── JOIN ON hotel_id ─────────┘
                                         │
                                         ▼
          Mỗi dòng = 1 đơn đặt phòng, kèm tên khách và hạng sao khách sạn
                                         │
                    WHERE status = 'COMPLETED' AND total_price > 0
                                         │   (loại đơn chưa thành công và dữ liệu rác)
                                         ▼
                 GROUP BY user_id, full_name, star_rating
                                         │   (mỗi cặp Khách hàng × Hạng sao là 1 nhóm)
                                         ▼
                        SUM(total_price) cho từng nhóm
                                         │
                       HAVING SUM(total_price) > 50.000.000
                                         │   (chỉ giữ nhóm đạt chuẩn VIP)
                                         ▼
                   ORDER BY star_rating DESC, total_spent DESC
```

### Gom nhóm theo những cột nào?

Mục tiêu là **mỗi cặp (Khách hàng, Hạng sao) là một dòng**. Vì vậy phải `GROUP BY` theo **cả hai chiều**:

```sql
GROUP BY u.user_id, u.full_name, h.star_rating
```

- `u.user_id`: định danh khách hàng. Gom theo `user_id` thay vì chỉ `full_name`, vì hai khách hàng khác nhau có thể **trùng tên**.
- `u.full_name`: cần hiển thị trong `SELECT`, nên đưa vào `GROUP BY` để hợp lệ với `ONLY_FULL_GROUP_BY`.
- `h.star_rating`: tách chi tiêu theo từng hạng sao. Gom theo **hạng sao**, không gom theo `hotel_id`, vì khách có thể ở nhiều khách sạn cùng hạng (ví dụ InterContinental và Sheraton đều 5 sao) và cần cộng dồn chúng.

Ví dụ với khách Nguyen Van A:

| booking_id | Khách sạn | Hạng | total_price | Nhóm |
|---|---|---|---|---|
| 1001 | InterContinental | 5 | 30.000.000 | (A, 5 sao) |
| 1002 | Sheraton | 5 | 25.000.000 | (A, 5 sao) |
| 1003 | Novotel | 4 | 60.000.000 | (A, 4 sao) |

Kết quả: A xuất hiện **2 dòng**, gồm 55.000.000 ở hạng 5 sao và 60.000.000 ở hạng 4 sao.

### Gom nhóm sai sẽ thế nào?

| Cách GROUP BY | Kết quả với khách A | Vấn đề |
|---|---|---|
| `user_id, full_name` | 1 dòng, 115.000.000 | Gộp nhầm chi tiêu 4 sao và 5 sao |
| `user_id, full_name, hotel_id` | 3 dòng: 30, 25, 60 triệu | Tách theo từng khách sạn, 5 sao không đạt 50 triệu dù tổng là 55 triệu |
| `user_id, full_name, star_rating` | 2 dòng: 55 và 60 triệu | ✅ Đúng yêu cầu |

## 3. Quy trình chống bẫy: đơn có giá âm

Một số đơn được hoàn tiền một phần nên `total_price` bị lưu là số âm, ví dụ đơn 1005 của Tran Thi B có giá -5.000.000.

### Xử lý ở WHERE hay HAVING?

**Ở `WHERE`**, với điều kiện `b.total_price > 0`.

- `total_price > 0` là điều kiện trên **từng đơn** (cột thường), không phải trên kết quả tổng hợp, nên thuộc về `WHERE`.
- `WHERE` chạy **trước** `GROUP BY`. Dòng rác bị loại sớm, nên Database không phải đưa nó vào nhóm và cộng vào `SUM`.
- `HAVING` **không thể** loại từng dòng. Khi đến `HAVING`, đơn -5.000.000 đã bị cộng vào tổng rồi. `HAVING` chỉ có thể loại **cả nhóm**, tức sẽ loại oan cả khách hàng thay vì chỉ loại dòng rác.

Trên dữ liệu mẫu, nếu không lọc giá âm, tổng 5 sao của Tran Thi B là 85.000.000 thay vì 90.000.000.

> **Lưu ý nghiệp vụ:** đề bài coi giá âm là **dữ liệu rác** nên lời giải loại bỏ chúng. Nếu sau này nghiệp vụ muốn tính **chi tiêu thực** (đã trừ phần hoàn tiền), chỉ cần bỏ điều kiện `total_price > 0`. Về lâu dài nên lưu khoản hoàn tiền ở một bảng riêng và thêm ràng buộc `CHECK (total_price >= 0)`.

### Các điều kiện đặt ở đâu?

| Điều kiện | Áp dụng cho | Đặt ở |
|---|---|---|
| `b.status = 'COMPLETED'` | Từng đơn | `WHERE` |
| `b.total_price > 0` | Từng đơn | `WHERE` |
| `SUM(b.total_price) > 50000000` | Từng nhóm (Khách × Hạng) | `HAVING` |

Nếu quên lọc `status`, đơn PENDING và CANCELLED sẽ bị tính: Tran Thi B thành 110.000.000, và Le Van C (chỉ có 10 triệu đơn thành công) lọt vào danh sách VIP với 60.000.000.

## 4. Mã nguồn Database

```sql
SELECT u.full_name          AS customer_name,
       h.star_rating        AS star_rating,
       SUM(b.total_price)   AS total_spent
FROM Bookings b
JOIN Users  u ON u.user_id  = b.user_id
JOIN Hotels h ON h.hotel_id = b.hotel_id
WHERE b.status = 'COMPLETED'
  AND b.total_price > 0
GROUP BY u.user_id, u.full_name, h.star_rating
HAVING SUM(b.total_price) > 50000000
ORDER BY h.star_rating DESC,
         total_spent DESC;
```

- `JOIN` dùng `INNER JOIN`, vì chỉ quan tâm các đơn có đầy đủ khách hàng và khách sạn.
- `WHERE` loại đơn chưa thành công và đơn giá âm **trước khi** gom nhóm.
- `GROUP BY` theo cặp Khách hàng × Hạng sao.
- `HAVING` giữ các nhóm có tổng chi trên 50 triệu. Điều kiện là **lớn hơn**, nên khách chi đúng 50.000.000 không đạt.
- `ORDER BY` sắp xếp 2 tầng: hạng sao giảm dần (5 sao lên đầu), trong cùng hạng thì tổng chi giảm dần.

## 5. Kết quả

Dữ liệu mẫu và cách mỗi đơn được xử lý:

| booking_id | Khách hàng | Khách sạn (hạng) | status | total_price | Xử lý |
|---|---|---|---|---|---|
| 1001 | Nguyen Van A | InterContinental (5) | COMPLETED | 30.000.000 | ✅ Nhóm (A, 5) |
| 1002 | Nguyen Van A | Sheraton (5) | COMPLETED | 25.000.000 | ✅ Nhóm (A, 5) |
| 1003 | Nguyen Van A | Novotel (4) | COMPLETED | 60.000.000 | ✅ Nhóm (A, 4) |
| 1004 | Tran Thi B | InterContinental (5) | COMPLETED | 90.000.000 | ✅ Nhóm (B, 5) |
| 1005 | Tran Thi B | InterContinental (5) | COMPLETED | -5.000.000 | Loại ở `WHERE` (giá âm) |
| 1006 | Tran Thi B | InterContinental (5) | PENDING | 20.000.000 | Loại ở `WHERE` (chưa thành công) |
| 1007 | Le Van C | Sheraton (5) | COMPLETED | 10.000.000 | Nhóm (C, 5), tổng 10 triệu, loại ở `HAVING` |
| 1008 | Le Van C | Sheraton (5) | CANCELLED | 50.000.000 | Loại ở `WHERE` (đã hủy) |
| 1009 | Pham Thi D | Novotel (4) | COMPLETED | 49.000.000 | Nhóm (D, 4), tổng 49 triệu, loại ở `HAVING` |

Báo cáo cuối cùng:

| customer_name | star_rating | total_spent |
|---|---|---|
| Tran Thi B | 5 | 90.000.000 |
| Nguyen Van A | 5 | 55.000.000 |
| Nguyen Van A | 4 | 60.000.000 |

Nguyen Van A xuất hiện **2 dòng**, đúng như thiết kế gom nhóm. Ở nhóm 5 sao, Tran Thi B chi nhiều hơn nên đứng trên.

## 6. Bài học rút ra

- Muốn một đối tượng xuất hiện nhiều dòng theo từng chiều phân loại, hãy `GROUP BY` theo **tổ hợp các cột** đó (Khách hàng × Hạng sao).
- Gom nhóm theo **khóa định danh** (`user_id`) thay vì tên, để không gộp nhầm những người trùng tên.
- Chọn đúng **mức độ chi tiết** của nhóm: theo `star_rating` chứ không theo `hotel_id`.
- Dữ liệu rác ở **từng dòng** phải lọc ở `WHERE`. `HAVING` chỉ lọc được **cả nhóm** sau khi đã cộng dồn.
- Thứ tự thực thi đầy đủ: **FROM / JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY**.
