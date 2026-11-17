-- =====================================================
-- Fix bug Module "Biểu đồ Doanh thu theo Thành phố"
-- =====================================================

-- 1. Tạo bảng đặt phòng
CREATE TABLE Bookings (
    booking_id  INT PRIMARY KEY,
    customer    VARCHAR(100),
    city        VARCHAR(50),
    total_price DECIMAL(15, 2),
    status      VARCHAR(20)      -- COMPLETED / CANCELLED / PENDING
);

-- 2. Chèn dữ liệu mẫu
INSERT INTO Bookings (booking_id, customer, city, total_price, status)
VALUES
    (1,  'Nguyễn Văn An',  'Đà Nẵng',   2000000000, 'COMPLETED'),
    (2,  'Trần Thị Bình',  'Đà Nẵng',   3000000000, 'COMPLETED'),
    (3,  'Lê Văn Cường',   'Đà Nẵng',   1500000000, 'CANCELLED'),  -- không tính
    (4,  'Phạm Minh Đức',  'Nha Trang', 1000000000, 'COMPLETED'),
    (5,  'Hoàng Văn Em',   'Nha Trang', 2000000000, 'COMPLETED'),
    (6,  'Võ Thị Phương',  'Nha Trang',  500000000, 'PENDING'),    -- không tính
    (7,  'Đặng Văn Giang', 'Phú Quốc',  4000000000, 'COMPLETED'),
    (8,  'Bùi Thị Hoa',    'Huế',        800000000, 'CANCELLED'),  -- Huế chỉ có đơn hủy
    (9,  'Đỗ Văn Khoa',    'Đà Lạt',             0, 'COMPLETED');  -- đơn 0đ (voucher 100%)

-- -----------------------------------------------------
-- 3. ĐOẠN CODE LỖI CỦA FRESHER (KHÔNG CHẠY ĐƯỢC)
-- WHERE chạy trước GROUP BY nên chưa có SUM() để so sánh
-- MySQL báo: ERROR 1111 (HY000): Invalid use of group function
-- -----------------------------------------------------
-- SELECT city, SUM(total_price) AS revenue
-- FROM Bookings
-- WHERE status = 'COMPLETED' AND SUM(total_price) > 0
-- GROUP BY city;

-- -----------------------------------------------------
-- 4. CODE ĐÃ SỬA
-- -----------------------------------------------------
SELECT city, SUM(total_price) AS revenue
FROM Bookings
WHERE status = 'COMPLETED'          -- lọc từng đơn trước khi gom nhóm
GROUP BY city
HAVING SUM(total_price) > 0         -- lọc từng thành phố sau khi đã tính tổng
ORDER BY revenue DESC;              -- thành phố doanh thu cao nhất lên đầu

-- Kết quả mong đợi:
-- Đà Nẵng    5.000.000.000
-- Phú Quốc   4.000.000.000
-- Nha Trang  3.000.000.000
