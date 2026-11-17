-- =====================================================
-- Tính năng "Giá chỉ từ..." trên danh sách Khách sạn
-- =====================================================

-- 1. Tạo bảng phòng
CREATE TABLE Rooms (
    room_id         INT PRIMARY KEY,
    hotel_id        INT,
    room_name       VARCHAR(100),
    price_per_night DECIMAL(12, 2)
);

-- 2. Chèn dữ liệu mẫu
INSERT INTO Rooms (room_id, hotel_id, room_name, price_per_night)
VALUES
    (1, 101, 'Deluxe Ocean View', 2500000),
    (2, 101, 'Standard Twin',      800000),
    (3, 101, 'Suite',             5000000),
    (4, 102, 'Superior Double',   1200000),
    (5, 102, 'Family Room',       1800000),
    (6, 103, 'Dorm Bed',           300000),
    (7, 103, 'Private Room',       650000),
    (8, 103, 'Capsule',            300000);   -- trùng giá rẻ nhất với Dorm Bed

-- -----------------------------------------------------
-- 3. ĐOẠN CODE LỖI (KHÔNG DÙNG)
-- room_name không nằm trong GROUP BY và không nằm trong hàm tổ hợp
-- MySQL 8.0: ERROR 1055 ... incompatible with sql_mode=only_full_group_by
-- -----------------------------------------------------
-- SELECT hotel_id, room_name, MIN(price_per_night)
-- FROM Rooms
-- GROUP BY hotel_id;

-- -----------------------------------------------------
-- 4. CODE ĐÃ SỬA: ID khách sạn và giá phòng rẻ nhất
-- -----------------------------------------------------
SELECT hotel_id,
       MIN(price_per_night) AS min_price
FROM Rooms
GROUP BY hotel_id
ORDER BY hotel_id;

-- Kết quả mong đợi:
-- 101   800000
-- 102  1200000
-- 103   300000

-- -----------------------------------------------------
-- 5. MỞ RỘNG: nếu vẫn cần tên phòng rẻ nhất
-- So khớp lại với bảng gốc để lấy đúng dòng có giá thấp nhất
-- -----------------------------------------------------
SELECT r.hotel_id, r.room_name, r.price_per_night AS min_price
FROM Rooms r
JOIN (
    SELECT hotel_id, MIN(price_per_night) AS min_price
    FROM Rooms
    GROUP BY hotel_id
) m ON r.hotel_id = m.hotel_id
   AND r.price_per_night = m.min_price
ORDER BY r.hotel_id, r.room_name;
