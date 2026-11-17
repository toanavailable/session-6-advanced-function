# Tool "Truy quét Tài khoản Đầu cơ" (Spam/Fraud Detection)

Dùng `GROUP BY`, `HAVING` và kỹ thuật **đếm có điều kiện** (`CASE WHEN` bên trong hàm tổng hợp) để tìm các tài khoản đặt phòng hàng loạt rồi hủy hàng loạt, chỉ bằng một câu lệnh SQL.

## 1. Đề bài

- **Vấn đề:** vào các dịp Lễ, nhiều tài khoản ảo dùng tool giữ hàng loạt phòng đẹp nhưng không thanh toán, rồi hủy hàng loạt, gây thiệt hại cho đối tác khách sạn.
- **Yêu cầu của đội Anti-Fraud:** lấy danh sách `user_id` thỏa mãn **đồng thời**:
  1. Tổng số lần đặt phòng (bất kể trạng thái) **≥ 10**.
  2. Số đơn bị hủy (`status = 'CANCELLED'`) **> 5**.
- **Bẫy:** `COUNT(*)` đếm được tổng đơn, nhưng đếm riêng số đơn hủy **trên cùng một dòng `SELECT`** là thách thức nếu không biết kết hợp hàm tổng hợp với rẽ nhánh.

## 2. Thiết kế I/O và luồng xử lý

### Input và Output

| | Nội dung |
|---|---|
| **Input** | Bảng `Bookings`, dùng cột `user_id` để gom nhóm và cột `status` để phân biệt đơn hủy |
| **Output** | `user_id`, `total_bookings` (tổng đơn), `cancelled_bookings` (số đơn hủy) của các tài khoản nghi vấn |

### Vì sao không dùng `WHERE status = 'CANCELLED'`?

Hai tiêu chí cần **hai tập dữ liệu khác nhau** của cùng một khách hàng:

- Tiêu chí 1 cần **toàn bộ** đơn.
- Tiêu chí 2 chỉ cần **đơn hủy**.

Nếu lọc `WHERE status = 'CANCELLED'`, các đơn không hủy bị loại **trước khi** gom nhóm, nên `COUNT(*)` chỉ còn đếm được đơn hủy và tiêu chí 1 bị tính sai. Ví dụ user 202 có 10 đơn nhưng chỉ 6 đơn hủy, nên sau khi lọc chỉ còn 6 và không đạt "≥ 10". Cách này trả về **rỗng** trên dữ liệu mẫu.

Vì vậy phải giữ **tất cả** các đơn trong nhóm, và tìm cách đếm riêng đơn hủy **ngay bên trong nhóm**.

### Ý tưởng: đếm có điều kiện

Đặt `CASE WHEN` **bên trong** `SUM()` để biến mỗi đơn thành một con số:

```sql
SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END)
```

- `CASE WHEN` chạy cho **từng dòng** trong nhóm: đơn hủy thành `1`, đơn khác thành `0`.
- `SUM()` cộng các số đó lại, nên kết quả chính là **số đơn hủy**.

Ví dụ với user 202:

| status | CASE WHEN trả về |
|---|---|
| CANCELLED × 6 | 1, 1, 1, 1, 1, 1 |
| COMPLETED / PENDING × 4 | 0, 0, 0, 0 |
| **SUM** | **6** |

Trong cùng một nhóm, `COUNT(*)` vẫn đếm đủ 10 đơn, còn `SUM(CASE ...)` chỉ đếm 6 đơn hủy. Cả hai con số nằm trên **cùng một dòng** kết quả.

### Bẫy phụ: `COUNT` với `ELSE 0`

```sql
COUNT(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END)   -- SAI
```

`COUNT` đếm mọi giá trị **khác NULL**, và số `0` cũng khác NULL. Vì vậy cách viết này đếm **tất cả** các đơn, cho kết quả bằng `COUNT(*)`. Nếu muốn dùng `COUNT`, phải **bỏ `ELSE`** để đơn không hủy trả về `NULL`:

```sql
COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END)          -- ĐÚNG
```

### Luồng thực thi

```
FROM Bookings
  → GROUP BY user_id               gom mọi đơn theo khách hàng (không lọc trước)
  → HAVING COUNT(*) >= 10          tiêu chí 1: tổng đơn
       AND SUM(CASE ...) > 5       tiêu chí 2: số đơn hủy
  → SELECT                         hiển thị user_id, tổng đơn, số đơn hủy
  → ORDER BY                       tài khoản hủy nhiều nhất lên đầu
```

Cả hai tiêu chí đều là điều kiện trên **hàm tổng hợp**, nên phải đặt ở `HAVING` và nối với nhau bằng `AND`.

## 3. Lời giải

```sql
SELECT user_id,
       COUNT(*) AS total_bookings,
       SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_bookings
FROM Bookings
GROUP BY user_id
HAVING COUNT(*) >= 10
   AND SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) > 5
ORDER BY cancelled_bookings DESC, user_id;
```

- `COUNT(*)`: tổng số đơn của mỗi khách, bất kể trạng thái.
- `SUM(CASE WHEN ... THEN 1 ELSE 0 END)`: số đơn hủy của mỗi khách.
- `HAVING ... >= 10 AND ... > 5`: giữ lại khách thỏa **đồng thời** hai tiêu chí. Lưu ý dấu: tiêu chí 1 là **≥ 10**, tiêu chí 2 là **> 5** (tức từ 6 trở lên).
- `ORDER BY`: đưa tài khoản hủy nhiều nhất lên đầu để đội Anti-Fraud xử lý trước.

### Cách viết tương đương

```sql
-- COUNT + CASE không có ELSE
COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END)

-- Hàm IF của MySQL
SUM(IF(status = 'CANCELLED', 1, 0))
```

`SUM(CASE ...)` là cách được khuyên dùng vì là cú pháp chuẩn SQL, chạy được trên mọi hệ quản trị. `IF()` chỉ có trong MySQL.

## 4. Kết quả

Dữ liệu mẫu có 6 khách hàng, bao gồm các trường hợp biên:

| user_id | Tổng đơn | Đơn hủy | Tiêu chí 1 (≥ 10) | Tiêu chí 2 (> 5) | Kết luận |
|---|---|---|---|---|---|
| 201 | 12 | 7 | ✅ | ✅ | **Đầu cơ** |
| 202 | 10 | 6 | ✅ (biên) | ✅ | **Đầu cơ** |
| 203 | 10 | 5 | ✅ | ❌ (5 chưa > 5) | Bình thường |
| 204 | 9 | 9 | ❌ | ✅ | Bình thường |
| 205 | 15 | 2 | ✅ | ❌ | Khách thân thiết |
| 206 | 3 | 0 | ❌ | ❌ | Khách thường |

Kết quả truy vấn:

| user_id | total_bookings | cancelled_bookings |
|---|---|---|
| 201 | 12 | 7 |
| 202 | 10 | 6 |

So sánh với các cách viết sai trên cùng dữ liệu:

| Cách viết | Kết quả |
|---|---|
| `WHERE status = 'CANCELLED'` rồi `COUNT(*)` | Rỗng, bỏ sót cả 201 và 202 |
| `COUNT(CASE ... ELSE 0 END)` | Đếm thành tổng đơn (201 ra 12 thay vì 7) |
| `SUM(CASE ... ELSE 0 END)` | Đúng: 201 và 202 |

## 5. Bài học rút ra

- Khi cần **nhiều phép đếm khác nhau trên cùng một nhóm**, không lọc bằng `WHERE` mà dùng **đếm có điều kiện**: đặt `CASE WHEN` bên trong hàm tổng hợp.
- `SUM(CASE WHEN điều_kiện THEN 1 ELSE 0 END)` hoặc `COUNT(CASE WHEN điều_kiện THEN 1 END)`. **Không** dùng `COUNT` kèm `ELSE 0`.
- Điều kiện trên kết quả hàm tổng hợp đặt ở `HAVING`, nhiều điều kiện nối bằng `AND`.
- Kiểm tra kỹ các giá trị biên (đúng 10 đơn, đúng 5 đơn hủy) để chắc chắn dùng đúng `>=` hay `>`.
