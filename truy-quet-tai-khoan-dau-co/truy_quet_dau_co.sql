-- =====================================================
-- Tool "Truy quét Tài khoản Đầu cơ" (Spam/Fraud Detection)
-- =====================================================

-- 1. Tạo bảng đặt phòng
CREATE TABLE Bookings (
    booking_id   INT PRIMARY KEY,
    user_id      INT,
    hotel_id     INT,
    booking_date DATE,
    status       VARCHAR(20)      -- COMPLETED / PENDING / CANCELLED
);

-- 2. Chèn dữ liệu mẫu
--   user 201: 12 đơn, 7 hủy (đầu cơ rõ ràng)
--   user 202: 10 đơn, 6 hủy (biên: đúng 10 đơn, 6 hủy)
--   user 203: 10 đơn, 5 hủy (biên: 5 hủy, chưa vượt 5)
--   user 204: 9 đơn, 9 hủy (hủy hết nhưng chỉ 9 đơn)
--   user 205: 15 đơn, 2 hủy (khách thân thiết)
--   user 206: 3 đơn, 0 hủy (khách thường)
INSERT INTO Bookings (booking_id, user_id, hotel_id, booking_date, status)
VALUES
    (1, 201, 101, '2026-04-02', 'CANCELLED'),
    (2, 201, 102, '2026-04-03', 'CANCELLED'),
    (3, 201, 103, '2026-04-04', 'CANCELLED'),
    (4, 201, 104, '2026-04-05', 'CANCELLED'),
    (5, 201, 100, '2026-04-06', 'CANCELLED'),
    (6, 201, 101, '2026-04-07', 'CANCELLED'),
    (7, 201, 102, '2026-04-08', 'CANCELLED'),
    (8, 201, 103, '2026-04-09', 'PENDING'),
    (9, 201, 104, '2026-04-10', 'COMPLETED'),
    (10, 201, 100, '2026-04-11', 'PENDING'),
    (11, 201, 101, '2026-04-12', 'COMPLETED'),
    (12, 201, 102, '2026-04-13', 'PENDING'),
    (13, 202, 103, '2026-04-14', 'CANCELLED'),
    (14, 202, 104, '2026-04-15', 'CANCELLED'),
    (15, 202, 100, '2026-04-16', 'CANCELLED'),
    (16, 202, 101, '2026-04-17', 'CANCELLED'),
    (17, 202, 102, '2026-04-18', 'CANCELLED'),
    (18, 202, 103, '2026-04-19', 'CANCELLED'),
    (19, 202, 104, '2026-04-20', 'COMPLETED'),
    (20, 202, 100, '2026-04-21', 'PENDING'),
    (21, 202, 101, '2026-04-22', 'COMPLETED'),
    (22, 202, 102, '2026-04-23', 'PENDING'),
    (23, 203, 103, '2026-04-24', 'CANCELLED'),
    (24, 203, 104, '2026-04-25', 'CANCELLED'),
    (25, 203, 100, '2026-04-26', 'CANCELLED'),
    (26, 203, 101, '2026-04-27', 'CANCELLED'),
    (27, 203, 102, '2026-04-28', 'CANCELLED'),
    (28, 203, 103, '2026-04-01', 'PENDING'),
    (29, 203, 104, '2026-04-02', 'COMPLETED'),
    (30, 203, 100, '2026-04-03', 'PENDING'),
    (31, 203, 101, '2026-04-04', 'COMPLETED'),
    (32, 203, 102, '2026-04-05', 'PENDING'),
    (33, 204, 103, '2026-04-06', 'CANCELLED'),
    (34, 204, 104, '2026-04-07', 'CANCELLED'),
    (35, 204, 100, '2026-04-08', 'CANCELLED'),
    (36, 204, 101, '2026-04-09', 'CANCELLED'),
    (37, 204, 102, '2026-04-10', 'CANCELLED'),
    (38, 204, 103, '2026-04-11', 'CANCELLED'),
    (39, 204, 104, '2026-04-12', 'CANCELLED'),
    (40, 204, 100, '2026-04-13', 'CANCELLED'),
    (41, 204, 101, '2026-04-14', 'CANCELLED'),
    (42, 205, 102, '2026-04-15', 'CANCELLED'),
    (43, 205, 103, '2026-04-16', 'CANCELLED'),
    (44, 205, 104, '2026-04-17', 'COMPLETED'),
    (45, 205, 100, '2026-04-18', 'PENDING'),
    (46, 205, 101, '2026-04-19', 'COMPLETED'),
    (47, 205, 102, '2026-04-20', 'PENDING'),
    (48, 205, 103, '2026-04-21', 'COMPLETED'),
    (49, 205, 104, '2026-04-22', 'PENDING'),
    (50, 205, 100, '2026-04-23', 'COMPLETED'),
    (51, 205, 101, '2026-04-24', 'PENDING'),
    (52, 205, 102, '2026-04-25', 'COMPLETED'),
    (53, 205, 103, '2026-04-26', 'PENDING'),
    (54, 205, 104, '2026-04-27', 'COMPLETED'),
    (55, 205, 100, '2026-04-28', 'PENDING'),
    (56, 205, 101, '2026-04-01', 'COMPLETED'),
    (57, 206, 102, '2026-04-02', 'COMPLETED'),
    (58, 206, 103, '2026-04-03', 'PENDING'),
    (59, 206, 104, '2026-04-04', 'COMPLETED');

-- -----------------------------------------------------
-- 3. CÁCH VIẾT SAI 1 (KHÔNG DÙNG)
-- WHERE lọc mất các đơn không hủy -> COUNT(*) chỉ còn đếm đơn hủy
-- -----------------------------------------------------
-- SELECT user_id, COUNT(*) AS total_bookings
-- FROM Bookings
-- WHERE status = 'CANCELLED'
-- GROUP BY user_id
-- HAVING COUNT(*) >= 10 AND COUNT(*) > 5;

-- -----------------------------------------------------
-- 4. CÁCH VIẾT SAI 2 (KHÔNG DÙNG)
-- COUNT đếm mọi giá trị khác NULL, kể cả số 0 -> đếm luôn đơn không hủy
-- -----------------------------------------------------
-- SELECT user_id,
--        COUNT(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_bookings
-- FROM Bookings
-- GROUP BY user_id;

-- -----------------------------------------------------
-- 5. CÂU LỆNH HOÀN CHỈNH
-- -----------------------------------------------------
SELECT user_id,
       COUNT(*) AS total_bookings,
       SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_bookings
FROM Bookings
GROUP BY user_id
HAVING COUNT(*) >= 10
   AND SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) > 5
ORDER BY cancelled_bookings DESC, user_id;

-- Kết quả mong đợi:
--   201  12  7
--   202  10  6

-- -----------------------------------------------------
-- 6. CÁCH VIẾT TƯƠNG ĐƯƠNG
-- -----------------------------------------------------
-- 6.1 COUNT + CASE không có ELSE (đơn không hủy -> NULL -> COUNT bỏ qua)
SELECT user_id,
       COUNT(*) AS total_bookings,
       COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END) AS cancelled_bookings
FROM Bookings
GROUP BY user_id
HAVING COUNT(*) >= 10
   AND COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END) > 5;

-- 6.2 Hàm IF của MySQL
SELECT user_id,
       COUNT(*) AS total_bookings,
       SUM(IF(status = 'CANCELLED', 1, 0)) AS cancelled_bookings
FROM Bookings
GROUP BY user_id
HAVING COUNT(*) >= 10
   AND SUM(IF(status = 'CANCELLED', 1, 0)) > 5;
