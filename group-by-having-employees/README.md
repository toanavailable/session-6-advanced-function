# Nhóm dữ liệu và Lọc kết quả sau khi nhóm

Thực hành đếm số nhân viên theo phòng ban bằng `GROUP BY` và `COUNT`, loại bỏ dữ liệu rỗng bằng `WHERE ... IS NOT NULL` trước khi gom nhóm, và lọc kết quả sau khi gom nhóm bằng `HAVING`.

## 1. Đề bài

- **Mục tiêu:** nhóm các bản ghi cùng giá trị và đếm bằng hàm tổng hợp; loại bản ghi rỗng trước khi gom nhóm; đặt điều kiện lọc trực tiếp trên kết quả hàm tổng hợp.
- **Dữ liệu:** bảng `Employees`:

| EmpId | FullName | Department |
|---|---|---|
| 101 | Nguyễn Văn Tuấn | IT |
| 102 | Trần Mai Phương | IT |
| 103 | Lê Quốc Bảo | Sales |
| 104 | Phạm Hải Yến | Sales |
| 105 | Hoàng Minh Trí | Sales |
| 106 | Đặng Thị Hoa | Marketing |
| 107 | Vũ Trọng Phụng | NULL |

- **Yêu cầu:** đếm nhân viên theo phòng ban (Bước 1), loại nhân viên chưa có phòng ban (Bước 2), chỉ lấy phòng ban có từ 2 nhân viên trở lên (Bước 3).

## 2. Phân tích

| Điều kiện | Áp dụng cho | Mệnh đề |
|---|---|---|
| `Department IS NOT NULL` | Từng **nhân viên** (dữ liệu ban đầu) | `WHERE` |
| `TotalEmployees >= 2` | Từng **phòng ban** (kết quả của `COUNT`) | `HAVING` |

Thứ tự thực thi: **FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY**.

- `WHERE` chạy **trước** `GROUP BY`, nên loại được nhân viên có `Department` là NULL trước khi gom nhóm.
- `HAVING` chạy **sau** `GROUP BY`, khi đã có kết quả `COUNT` của từng phòng ban, nên lọc được theo số lượng nhân viên. Đặt điều kiện này trong `WHERE` sẽ bị báo lỗi, vì lúc đó chưa có kết quả đếm.
- Phải dùng `IS NOT NULL`, không dùng `<> NULL`, vì so sánh với NULL bằng `<>` luôn cho kết quả UNKNOWN và loại hết mọi dòng.

## 3. Lời giải

### Bước 1: Đếm số lượng theo nhóm

```sql
SELECT Department, COUNT(*) AS TotalEmployees
FROM Employees
GROUP BY Department;
```

| Department | TotalEmployees |
|---|---|
| NULL | 1 |
| IT | 2 |
| Marketing | 1 |
| Sales | 3 |

`GROUP BY` coi tất cả giá trị NULL là **một nhóm riêng**, nên Vũ Trọng Phụng tạo thành nhóm `NULL`.

### Bước 2: Lọc dữ liệu rỗng (WHERE)

```sql
SELECT Department, COUNT(*) AS TotalEmployees
FROM Employees
WHERE Department IS NOT NULL
GROUP BY Department;
```

| Department | TotalEmployees |
|---|---|
| IT | 2 |
| Marketing | 1 |
| Sales | 3 |

Nhóm NULL đã biến mất vì nhân viên chưa có phòng ban bị loại trước khi gom nhóm.

### Bước 3: Lọc dữ liệu nhóm (HAVING)

```sql
SELECT Department, COUNT(*) AS TotalEmployees
FROM Employees
WHERE Department IS NOT NULL
GROUP BY Department
HAVING TotalEmployees >= 2
ORDER BY TotalEmployees DESC;
```

| Department | TotalEmployees |
|---|---|
| Sales | 3 |
| IT | 2 |

Marketing chỉ có 1 nhân viên nên bị loại ở `HAVING`.

- `HAVING TotalEmployees >= 2` dùng lại bí danh của cột đếm. MySQL cho phép cách viết này. Trên SQL Server hay PostgreSQL phải viết đầy đủ `HAVING COUNT(*) >= 2`.
- `ORDER BY TotalEmployees DESC` được thêm vào để kết quả hiện đúng thứ tự Sales trước, IT sau như Output mong đợi. Nếu không có `ORDER BY`, MySQL không đảm bảo thứ tự các nhóm.

## 4. Kết quả

| Bước | Kết quả |
|---|---|
| 1 | 4 nhóm: NULL (1), IT (2), Marketing (1), Sales (3) |
| 2 | 3 nhóm: IT (2), Marketing (1), Sales (3) |
| 3 | 2 nhóm: Sales (3), IT (2), khớp Output mong đợi |

Tự đánh giá:

| Tiêu chí | Kết quả |
|---|---|
| Các mệnh đề xếp đúng thứ tự FROM → WHERE → GROUP BY → HAVING | ✅ |
| Loại phòng ban rỗng bằng `WHERE`, lọc số lượng bằng `HAVING` | ✅ |
| Kết quả Bước 3 không còn bản ghi rỗng và phòng Marketing | ✅ |

## 5. Bài học rút ra

- `GROUP BY` gom tất cả giá trị NULL thành một nhóm riêng. Muốn loại chúng, lọc bằng `WHERE ... IS NOT NULL` trước khi gom nhóm.
- `WHERE` lọc **từng dòng** trước khi gom nhóm, `HAVING` lọc **từng nhóm** sau khi gom nhóm.
- Điều kiện trên kết quả hàm tổng hợp (`COUNT`, `SUM`...) chỉ được đặt ở `HAVING`.
- Muốn kết quả có thứ tự cố định, luôn thêm `ORDER BY`.
