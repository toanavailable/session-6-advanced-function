# Truy vấn Dữ liệu từ nhiều bảng với INNER, LEFT và RIGHT JOIN

Thực hành nối hai bảng `Employees` và `Departments` qua khóa ngoại `DeptId`, so sánh kết quả của `INNER JOIN`, `LEFT JOIN` và `RIGHT JOIN`, và dùng bí danh (Alias) cho bảng.

## 1. Đề bài

- **Mục tiêu:** nối dữ liệu giữa hai bảng có quan hệ khóa chính – khóa ngoại; dùng `INNER JOIN` lấy phần chung; dùng `LEFT JOIN` / `RIGHT JOIN` lấy toàn bộ một bảng cùng phần chung; đặt bí danh cho bảng.
- **Dữ liệu:** `Employees.DeptId` là khóa ngoại tham chiếu tới `Departments.DeptId`.

| DeptId | DeptName |
|---|---|
| 1 | IT |
| 2 | Sales |
| 3 | Marketing |

| EmpId | EmpName | DeptId |
|---|---|---|
| 101 | Nguyễn Văn Tuấn | 1 |
| 102 | Trần Mai Phương | 1 |
| 103 | Lê Quốc Bảo | NULL |

## 2. Phân tích

Quan hệ giữa hai bảng:

| Trường hợp | Ví dụ |
|---|---|
| Nhân viên **có** phòng ban, phòng ban **có** nhân viên | Tuấn, Phương thuộc IT |
| Nhân viên **chưa có** phòng ban | Lê Quốc Bảo (`DeptId` là NULL) |
| Phòng ban **chưa có** nhân viên | Sales, Marketing |

Ba loại JOIN khác nhau ở chỗ **giữ lại những dòng không khớp của bảng nào**:

| Loại JOIN | Giữ lại |
|---|---|
| `INNER JOIN` | Chỉ các dòng khớp ở cả hai bảng |
| `LEFT JOIN` | Toàn bộ bảng **trái** (`Employees`) + phần khớp |
| `RIGHT JOIN` | Toàn bộ bảng **phải** (`Departments`) + phần khớp |

Dòng nào không tìm thấy dòng khớp ở bảng còn lại thì các cột của bảng đó được điền **NULL**.

Câu lệnh dùng bí danh `e` cho `Employees` và `d` cho `Departments`, giúp điều kiện nối ngắn gọn: `e.DeptId = d.DeptId` thay vì `Employees.DeptId = Departments.DeptId`.

## 3. Lời giải

### Bước 1: Lấy dữ liệu chung (INNER JOIN)

```sql
SELECT *
FROM Employees e
INNER JOIN Departments d ON e.DeptId = d.DeptId;
```

| EmpId | EmpName | DeptId (Employees) | DeptId (Departments) | DeptName |
|---|---|---|---|---|
| 101 | Nguyễn Văn Tuấn | 1 | 1 | IT |
| 102 | Trần Mai Phương | 1 | 1 | IT |

Chỉ có 2 nhân viên thuộc IT. Lê Quốc Bảo bị loại vì `DeptId` là NULL, và Sales, Marketing bị loại vì không có nhân viên.

### Bước 2: Lấy dữ liệu bảng trái (LEFT JOIN)

```sql
SELECT *
FROM Employees e
LEFT JOIN Departments d ON e.DeptId = d.DeptId;
```

| EmpId | EmpName | DeptId (Employees) | DeptId (Departments) | DeptName |
|---|---|---|---|---|
| 101 | Nguyễn Văn Tuấn | 1 | 1 | IT |
| 102 | Trần Mai Phương | 1 | 1 | IT |
| 103 | Lê Quốc Bảo | NULL | NULL | NULL |

`LEFT JOIN` giữ **toàn bộ nhân viên**. Lê Quốc Bảo xuất hiện, và vì chưa có phòng ban nên các cột lấy từ `Departments` là NULL.

### Bước 3: Lấy dữ liệu bảng phải (RIGHT JOIN)

```sql
SELECT *
FROM Employees e
RIGHT JOIN Departments d ON e.DeptId = d.DeptId;
```

| EmpId | EmpName | DeptId (Employees) | DeptId (Departments) | DeptName |
|---|---|---|---|---|
| 101 | Nguyễn Văn Tuấn | 1 | 1 | IT |
| 102 | Trần Mai Phương | 1 | 1 | IT |
| NULL | NULL | NULL | 2 | Sales |
| NULL | NULL | NULL | 3 | Marketing |

`RIGHT JOIN` giữ **toàn bộ phòng ban**. Marketing xuất hiện với thông tin nhân viên là NULL. Lê Quốc Bảo không còn xuất hiện, vì anh không khớp với phòng ban nào.

### Lưu ý so với Output mong đợi của đề bài

Bảng Output mong đợi của Bước 3 chỉ có dòng **Marketing**, nhưng kết quả thực tế có thêm dòng **Sales**. Lý do là theo dữ liệu đầu vào, phòng Sales (`DeptId = 2`) **cũng chưa có nhân viên nào**, nên `RIGHT JOIN` giữ lại cả Sales lẫn Marketing. Kết quả 4 dòng ở trên là đúng với dữ liệu đã cho.

Ngoài ra, `SELECT *` trả về đủ 5 cột, gồm cả `DeptName`. Bảng Output của đề bài chỉ hiển thị 4 cột đầu.

## 4. Kết quả

| Bước | Loại JOIN | Số dòng | Dòng đặc biệt |
|---|---|---|---|
| 1 | INNER JOIN | 2 | Không có |
| 2 | LEFT JOIN | 3 | Lê Quốc Bảo, phần phòng ban là NULL |
| 3 | RIGHT JOIN | 4 | Sales và Marketing, phần nhân viên là NULL |

Tự đánh giá:

| Tiêu chí | Kết quả |
|---|---|
| Điều kiện nối `e.DeptId = d.DeptId` đúng ở cả 3 câu lệnh | ✅ |
| Bước 2 có Lê Quốc Bảo, các cột từ `Departments` là NULL | ✅ |
| Bước 3 có phòng Marketing, các cột từ `Employees` là NULL | ✅ (kèm thêm Sales, xem lưu ý ở trên) |

## 5. Bài học rút ra

- `INNER JOIN` chỉ giữ dữ liệu **khớp ở cả hai bảng**.
- `LEFT JOIN` giữ toàn bộ bảng **trái**, `RIGHT JOIN` giữ toàn bộ bảng **phải**. Phần không khớp được điền NULL.
- `A RIGHT JOIN B` cho kết quả giống `B LEFT JOIN A` (chỉ khác thứ tự cột). Trong thực tế, người ta thường đổi thứ tự bảng và dùng `LEFT JOIN` cho dễ đọc.
- Đặt bí danh cho bảng (`e`, `d`) giúp câu lệnh ngắn gọn, và bắt buộc phải dùng khi hai bảng có cột trùng tên như `DeptId`.
- Khi dùng `SELECT *` với JOIN, các cột trùng tên sẽ xuất hiện hai lần. Thực tế nên liệt kê rõ các cột cần lấy.
