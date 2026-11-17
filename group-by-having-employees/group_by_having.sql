-- =====================================================
-- Nhóm dữ liệu và lọc kết quả sau khi nhóm
-- =====================================================

-- 1. Tạo bảng
CREATE TABLE Employees (
    EmpId      INT PRIMARY KEY,
    FullName   VARCHAR(100) NOT NULL,
    Department VARCHAR(50) NULL
);

-- 2. Chèn dữ liệu mẫu
INSERT INTO Employees (EmpId, FullName, Department) VALUES
    (101, 'Nguyễn Văn Tuấn', 'IT'),
    (102, 'Trần Mai Phương', 'IT'),
    (103, 'Lê Quốc Bảo',     'Sales'),
    (104, 'Phạm Hải Yến',    'Sales'),
    (105, 'Hoàng Minh Trí',  'Sales'),
    (106, 'Đặng Thị Hoa',    'Marketing'),
    (107, 'Vũ Trọng Phụng',  NULL);      -- chưa được phân phòng ban

-- Bước 1: Đếm số nhân viên theo phòng ban
SELECT Department, COUNT(*) AS TotalEmployees
FROM Employees
GROUP BY Department;

-- Bước 2: Loại nhân viên chưa có phòng ban trước khi gom nhóm
SELECT Department, COUNT(*) AS TotalEmployees
FROM Employees
WHERE Department IS NOT NULL
GROUP BY Department;

-- Bước 3: Chỉ lấy phòng ban có từ 2 nhân viên trở lên
SELECT Department, COUNT(*) AS TotalEmployees
FROM Employees
WHERE Department IS NOT NULL
GROUP BY Department
HAVING TotalEmployees >= 2
ORDER BY TotalEmployees DESC;
-- Kết quả mong đợi: Sales 3, IT 2
