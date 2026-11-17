-- =====================================================
-- Cảnh báo "Phòng Chết" (Dead Inventory)
-- =====================================================

-- 1. Tạo bảng
CREATE TABLE Rooms (
    room_id   INT PRIMARY KEY,
    hotel_id  INT,
    room_name VARCHAR(100)
);

CREATE TABLE Bookings (
    booking_id   INT PRIMARY KEY,
    room_id      INT NULL,          -- có thể NULL (phòng đã xóa, lỗi đồng bộ...)
    booking_date DATE,
    status       VARCHAR(20)
);

-- 2. Chèn dữ liệu mẫu
INSERT INTO Rooms (room_id, hotel_id, room_name)
VALUES
    (1, 101, 'Deluxe Ocean View'),
    (2, 101, 'Standard Twin'),
    (3, 101, 'Suite Tổng thống'),     -- chưa từng được đặt
    (4, 102, 'Superior Double'),     -- chỉ được đặt từ năm 2024
    (5, 102, 'Family Room'),         -- chưa từng được đặt
    (6, 103, 'Bungalow Hướng Núi');  -- chưa từng được đặt

INSERT INTO Bookings (booking_id, room_id, booking_date, status)
VALUES
    (1, 1,    '2026-03-10', 'COMPLETED'),
    (2, 2,    '2026-05-02', 'COMPLETED'),
    (3, 2,    '2026-08-15', 'CANCELLED'),
    (4, 4,    '2024-06-20', 'COMPLETED'),
    (5, NULL, '2026-09-01', 'CANCELLED');   -- bản ghi "bẩn": room_id bị NULL

-- 3. Index hỗ trợ JOIN / tra cứu theo room_id
CREATE INDEX idx_bookings_room ON Bookings (room_id);

-- -----------------------------------------------------
-- 4. CÁCH VIẾT NGUY HIỂM (KHÔNG DÙNG)
-- Bookings có 1 dòng room_id NULL -> NOT IN trả về 0 dòng
-- -----------------------------------------------------
SELECT room_id, room_name
FROM Rooms
WHERE room_id NOT IN (SELECT room_id FROM Bookings);
-- Kết quả: rỗng

-- -----------------------------------------------------
-- 5. CÁCH VÁ 1: sửa subquery, loại NULL trước khi so sánh
-- -----------------------------------------------------
SELECT room_id, room_name
FROM Rooms
WHERE room_id NOT IN (
    SELECT room_id FROM Bookings WHERE room_id IS NOT NULL
)
ORDER BY room_id;

-- -----------------------------------------------------
-- 6. CÁCH VÁ 2: NOT EXISTS (an toàn với NULL)
-- -----------------------------------------------------
SELECT r.room_id, r.room_name
FROM Rooms r
WHERE NOT EXISTS (
    SELECT 1 FROM Bookings b WHERE b.room_id = r.room_id
)
ORDER BY r.room_id;

-- -----------------------------------------------------
-- 7. CÂU LỆNH CHỐT: LEFT JOIN + IS NULL
-- -----------------------------------------------------
SELECT r.room_id, r.room_name
FROM Rooms r
LEFT JOIN Bookings b ON b.room_id = r.room_id
WHERE b.booking_id IS NULL
ORDER BY r.room_id;
-- Kết quả mong đợi: 3 Suite Tổng thống, 5 Family Room, 6 Bungalow Hướng Núi

-- -----------------------------------------------------
-- 8. MỞ RỘNG: phòng không có lượt đặt nào trong 1 năm gần nhất
-- Điều kiện thời gian đặt trong ON (không phải WHERE) để giữ LEFT JOIN
-- Kết quả phụ thuộc ngày chạy, tính đến 17/11/2026: phòng 3, 4, 5, 6
-- -----------------------------------------------------
SELECT r.room_id, r.room_name
FROM Rooms r
LEFT JOIN Bookings b
       ON b.room_id = r.room_id
      AND b.booking_date >= CURDATE() - INTERVAL 1 YEAR
WHERE b.booking_id IS NULL
ORDER BY r.room_id;
