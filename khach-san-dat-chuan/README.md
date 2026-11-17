# Báo cáo "Khách sạn Đạt Chuẩn" (Tối ưu WHERE vs HAVING)

Đề xuất và so sánh hiệu năng các cách viết truy vấn tìm khách sạn đối tác đạt chuẩn vinh danh, từ đó chọn ra câu lệnh tối ưu nhất dựa trên nguyên tắc "lọc càng sớm càng tốt".

## 1. Đề bài

Cuối năm, hệ thống vinh danh các khách sạn đối tác xuất sắc. Một khách sạn đạt chuẩn khi thỏa **đồng thời**:

1. Có **ít nhất 50 đơn** đặt phòng thành công (`status = 'COMPLETED'`).
2. **Doanh thu trung bình mỗi đơn** (`AVG(total_price)`) **lớn hơn 3.000.000 VNĐ**.

Yêu cầu: đề xuất ít nhất 2 giải pháp, so sánh hiệu năng, và viết câu lệnh tối ưu nhất để xuất danh sách `hotel_id`.

## 2. Phân tích

### Bóc tách điều kiện

| Điều kiện | Áp dụng cho | Loại | Nơi đặt hợp lý |
|---|---|---|---|
| `status = 'COMPLETED'` | Từng **đơn** | Cột thường | `WHERE` |
| `COUNT(*) >= 50` | Từng **khách sạn** | Hàm tổng hợp | `HAVING` |
| `AVG(total_price) > 3000000` | Từng **khách sạn** | Hàm tổng hợp | `HAVING` |

Điểm mấu chốt: **cả hai điều kiện tổng hợp chỉ được tính trên đơn COMPLETED**. Nếu quên lọc trạng thái, đơn hủy sẽ làm sai cả số lượng đơn lẫn giá trị trung bình.

### Cách viết sai: quên lọc trạng thái

```sql
SELECT hotel_id
FROM Bookings
GROUP BY hotel_id
HAVING COUNT(*) >= 50 AND AVG(total_price) > 3000000;
```

- `COUNT(*)` đếm cả đơn hủy: khách sạn có 45 đơn thành công và 10 đơn hủy thành 55 đơn, lọt qua tiêu chí 1.
- `AVG(total_price)` tính cả giá đơn hủy: khách sạn có trung bình đơn thành công 2,9 triệu nhưng nhiều đơn hủy giá cao sẽ bị đẩy trung bình lên gần 4,9 triệu, lọt qua tiêu chí 2.

Trên dữ liệu mẫu, cách này trả về **5 khách sạn**, trong khi chỉ có **2** khách sạn thật sự đạt chuẩn.

### Thứ tự thực thi

```
FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY
```

Điều kiện đặt ở `WHERE` loại dữ liệu **trước** khi gom nhóm. Điều kiện đặt ở `HAVING` chỉ loại dữ liệu **sau** khi đã gom nhóm và tính toán xong. Đây là cơ sở để so sánh hiệu năng các giải pháp bên dưới.

## 3. Đề xuất đa giải pháp

### Giải pháp 1: Lọc ở WHERE, điều kiện tổng hợp ở HAVING

```sql
SELECT hotel_id,
       COUNT(*)         AS completed_bookings,
       AVG(total_price) AS avg_revenue
FROM Bookings
WHERE status = 'COMPLETED'
GROUP BY hotel_id
HAVING COUNT(*) >= 50
   AND AVG(total_price) > 3000000
ORDER BY avg_revenue DESC;
```

Loại đơn không thành công ngay từ đầu, sau đó chỉ gom nhóm và tính toán trên đơn COMPLETED.

### Giải pháp 2: Không dùng WHERE, tính có điều kiện trong HAVING

```sql
SELECT hotel_id,
       SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END)   AS completed_bookings,
       AVG(CASE WHEN status = 'COMPLETED' THEN total_price END) AS avg_revenue
FROM Bookings
GROUP BY hotel_id
HAVING SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) >= 50
   AND AVG(CASE WHEN status = 'COMPLETED' THEN total_price END) > 3000000
ORDER BY avg_revenue DESC;
```

Giữ **toàn bộ** đơn trong nhóm, dùng `CASE WHEN` để chỉ đếm và tính trung bình các đơn COMPLETED. Với `AVG`, `CASE` **không có `ELSE`** để đơn khác trả về `NULL` và bị `AVG` bỏ qua. Nếu viết `ELSE 0`, các số 0 sẽ kéo trung bình xuống sai.

### Giải pháp 3: Lọc trong bảng tạm (derived table) rồi gom nhóm

```sql
SELECT t.hotel_id,
       COUNT(*)           AS completed_bookings,
       AVG(t.total_price) AS avg_revenue
FROM (
    SELECT hotel_id, total_price
    FROM Bookings
    WHERE status = 'COMPLETED'
) AS t
GROUP BY t.hotel_id
HAVING COUNT(*) >= 50
   AND AVG(t.total_price) > 3000000
ORDER BY avg_revenue DESC;
```

Tách bước lọc ra một truy vấn con, truy vấn ngoài chỉ gom nhóm và áp điều kiện tổng hợp.

## 4. Bảng so sánh và đánh giá (Trade-off)

| Tiêu chí | Giải pháp 1: WHERE + HAVING | Giải pháp 2: CASE trong HAVING | Giải pháp 3: Derived table |
|---|---|---|---|
| **Lượng dữ liệu đưa vào GROUP BY** | ✅ Chỉ đơn COMPLETED | ❌ Toàn bộ đơn, kể cả đơn hủy | ✅ Chỉ đơn COMPLETED |
| **Sử dụng Index** | ✅ Index trên `status` lọc thẳng tới đơn COMPLETED, không cần quét cả bảng | ❌ Không có điều kiện lọc, buộc phải quét toàn bộ bảng | ✅ Như giải pháp 1, vì MySQL 8.0 thường gộp (merge) bảng tạm vào truy vấn ngoài |
| **Chi phí tính toán mỗi dòng** | ✅ Thấp: chỉ cộng và đếm | ❌ Cao hơn: mỗi dòng phải chạy `CASE WHEN`, và lặp lại trong cả `SELECT` lẫn `HAVING` | ✅ Thấp |
| **Bộ nhớ khi gom nhóm** | ✅ Ít | ❌ Nhiều hơn, tỷ lệ thuận với số đơn hủy | ✅ Ít |
| **Độ dễ đọc** | ✅ Ngắn gọn, đúng nguyên tắc WHERE / HAVING | ⚠️ Dài, lặp biểu thức `CASE` | ⚠️ Dài hơn, thêm một tầng truy vấn |
| **Khi nào nên dùng** | Mặc định cho bài toán này | Khi cần **nhiều thống kê khác nhau trên cùng nhóm**, ví dụ vừa đếm đơn thành công vừa đếm đơn hủy | Khi bước lọc phức tạp, cần tách riêng cho dễ bảo trì |

**Nhận xét:**

- Giải pháp 2 **cho kết quả đúng** nhưng **kém hiệu năng nhất**: mọi đơn hủy đều phải được đọc, đưa vào nhóm và chạy `CASE WHEN`, chỉ để rồi bị bỏ qua khi tính toán. Bảng càng lớn và tỷ lệ đơn hủy càng cao thì chênh lệch càng rõ.
- Giải pháp 1 và 3 tương đương về hiệu năng trên MySQL 8.0, vì bộ tối ưu thường gộp bảng tạm vào truy vấn ngoài. Có thể kiểm chứng bằng `EXPLAIN`. Giải pháp 1 gọn hơn nên được ưu tiên.
- Index gợi ý: `(status, hotel_id, total_price)`. Đây là **covering index** cho giải pháp 1: `WHERE` dùng cột đầu `status`, `GROUP BY` dùng cột thứ hai `hotel_id`, và `AVG` đọc `total_price` ngay trong Index mà không cần quay lại bảng gốc.

## 5. Thực thi: câu lệnh tối ưu nhất

```sql
CREATE INDEX idx_bookings_status_hotel_price ON Bookings (status, hotel_id, total_price);

SELECT hotel_id,
       COUNT(*)         AS completed_bookings,
       AVG(total_price) AS avg_revenue
FROM Bookings
WHERE status = 'COMPLETED'
GROUP BY hotel_id
HAVING COUNT(*) >= 50
   AND AVG(total_price) > 3000000
ORDER BY avg_revenue DESC;
```

## 6. Kết quả

Dữ liệu mẫu có 6 khách sạn, được thiết kế để kiểm tra các giá trị biên và các bẫy:

| hotel_id | Đơn COMPLETED | TB đơn COMPLETED | Đơn hủy | Đúng nghiệp vụ | Cách viết sai |
|---|---|---|---|---|---|
| 1 | 60 | 3.500.000 | 0 | ✅ Đạt | Đạt |
| 2 | 50 (biên) | 3.200.000 | 0 | ✅ Đạt | Đạt |
| 3 | 49 | 4.000.000 | 10 | Trượt (49 đơn) | ❌ Lọt (đếm thành 59 đơn) |
| 4 | 55 | 3.000.000 (biên) | 0 | Trượt (không > 3 triệu) | Trượt |
| 5 | 52 | 2.900.000 | 20 × 10.000.000 | Trượt (TB thấp) | ❌ Lọt (TB thành ~4.870.000) |
| 6 | 45 | 4.000.000 | 10 | Trượt (45 đơn) | ❌ Lọt (đếm thành 55 đơn) |

Cả ba giải pháp đều trả về cùng một kết quả:

| hotel_id | completed_bookings | avg_revenue |
|---|---|---|
| 1 | 60 | 3.500.000 |
| 2 | 50 | 3.200.000 |

## 7. Bài học rút ra

- **Lọc càng sớm càng tốt:** điều kiện trên cột thường đặt ở `WHERE` để giảm dữ liệu trước khi gom nhóm. `HAVING` chỉ dành cho điều kiện trên hàm tổng hợp.
- Các giải pháp có thể cùng cho kết quả đúng nhưng khác nhau rất nhiều về hiệu năng. Hãy chọn cách để Database xử lý ít dữ liệu nhất.
- Khi tính thống kê trên một phần dữ liệu, đừng quên lọc. Đơn hủy làm sai cả `COUNT` lẫn `AVG`.
- Với `AVG` có điều kiện, dùng `CASE WHEN ... THEN giá_trị END` (không có `ELSE`) để giá trị không thỏa trở thành `NULL` và bị bỏ qua.
- Thiết kế Index theo thứ tự **cột lọc → cột gom nhóm → cột tính toán** để có covering index.
