-- =====================================================
-- Truy vấn dữ liệu từ nhiều bảng với INNER, LEFT và RIGHT JOIN
-- =====================================================

-- 1. Tạo bảng
CREATE TABLE Departments (
    DeptId   INT PRIMARY KEY,
    DeptName VARCHAR(50) NOT NULL
);

CREATE TABLE Employees (
    EmpId   INT PRIMARY KEY,
    EmpName VARCHAR(100) NOT NULL,
    DeptId  INT NULL,
    FOREIGN KEY (DeptId) REFERENCES Departments(DeptId)
);

-- 2. Chèn dữ liệu mẫu
INSERT INTO Departments (DeptId, DeptName) VALUES
    (1, 'IT'),
    (2, 'Sales'),
    (3, 'Marketing');

INSERT INTO Employees (EmpId, EmpName, DeptId) VALUES
    (101, 'Nguyễn Văn Tuấn', 1),
    (102, 'Trần Mai Phương', 1),
    (103, 'Lê Quốc Bảo',     NULL);   -- chưa được phân phòng ban

-- Bước 1: INNER JOIN - chỉ lấy dữ liệu khớp ở cả hai bảng
SELECT *
FROM Employees e
INNER JOIN Departments d ON e.DeptId = d.DeptId;

-- Bước 2: LEFT JOIN - giữ toàn bộ nhân viên (bảng trái)
SELECT *
FROM Employees e
LEFT JOIN Departments d ON e.DeptId = d.DeptId;

-- Bước 3: RIGHT JOIN - giữ toàn bộ phòng ban (bảng phải)
SELECT *
FROM Employees e
RIGHT JOIN Departments d ON e.DeptId = d.DeptId;
