-- =====================================================
-- Báo cáo "Khách sạn Đạt Chuẩn" (Tối ưu WHERE vs HAVING)
-- =====================================================

-- 1. Tạo bảng đặt phòng
CREATE TABLE Bookings (
    booking_id  INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id    INT NOT NULL,
    total_price DECIMAL(15, 2) NOT NULL,
    status      VARCHAR(20) NOT NULL      -- COMPLETED / CANCELLED
);

-- 2. Chèn dữ liệu mẫu
-- Dùng CTE đệ quy sinh n dòng giống nhau để file ngắn gọn (MySQL 8.0+)
--   Khách sạn 1: 60 đơn COMPLETED x 3.500.000                     -> ĐẠT
--   Khách sạn 2: 50 đơn COMPLETED x 3.200.000 (biên đúng 50 đơn)   -> ĐẠT
--   Khách sạn 3: 49 đơn COMPLETED x 4.000.000 + 10 đơn hủy        -> trượt (49 đơn)
--   Khách sạn 4: 55 đơn COMPLETED x 3.000.000 (biên đúng 3 triệu)  -> trượt (không > 3 triệu)
--   Khách sạn 5: 52 đơn COMPLETED x 2.900.000 + 20 đơn hủy x 10.000.000
--                -> trượt, nhưng LỌT nếu AVG tính cả đơn hủy
--   Khách sạn 6: 45 đơn COMPLETED x 4.000.000 + 10 đơn hủy x 4.000.000
--                -> trượt, nhưng LỌT nếu COUNT tính cả đơn hủy

INSERT INTO Bookings (hotel_id, total_price, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 60)
SELECT 1, 3500000, 'COMPLETED' FROM seq;

INSERT INTO Bookings (hotel_id, total_price, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 50)
SELECT 2, 3200000, 'COMPLETED' FROM seq;

INSERT INTO Bookings (hotel_id, total_price, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 49)
SELECT 3, 4000000, 'COMPLETED' FROM seq;

INSERT INTO Bookings (hotel_id, total_price, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 10)
SELECT 3, 4000000, 'CANCELLED' FROM seq;

INSERT INTO Bookings (hotel_id, total_price, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 55)
SELECT 4, 3000000, 'COMPLETED' FROM seq;

INSERT INTO Bookings (hotel_id, total_price, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 52)
SELECT 5, 2900000, 'COMPLETED' FROM seq;

INSERT INTO Bookings (hotel_id, total_price, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 20)
SELECT 5, 10000000, 'CANCELLED' FROM seq;

INSERT INTO Bookings (hotel_id, total_price, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 45)
SELECT 6, 4000000, 'COMPLETED' FROM seq;

INSERT INTO Bookings (hotel_id, total_price, status)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 10)
SELECT 6, 4000000, 'CANCELLED' FROM seq;

-- 3. Index hỗ trợ lọc theo status và gom nhóm theo hotel_id
CREATE INDEX idx_bookings_status_hotel_price ON Bookings (status, hotel_id, total_price);

-- -----------------------------------------------------
-- 4. CÁCH VIẾT SAI (KHÔNG DÙNG)
-- Quên lọc status -> đếm và tính trung bình cả đơn hủy
-- => khách sạn 3, 5 và 6 lọt vào danh sách vinh danh
-- -----------------------------------------------------
-- SELECT hotel_id
-- FROM Bookings
-- GROUP BY hotel_id
-- HAVING COUNT(*) >= 50 AND AVG(total_price) > 3000000;

-- -----------------------------------------------------
-- 5. GIẢI PHÁP 1 (TỐI ƯU NHẤT): lọc ở WHERE, điều kiện tổng hợp ở HAVING
-- -----------------------------------------------------
SELECT hotel_id,
       COUNT(*)         AS completed_bookings,
       AVG(total_price) AS avg_revenue
FROM Bookings
WHERE status = 'COMPLETED'
GROUP BY hotel_id
HAVING COUNT(*) >= 50
   AND AVG(total_price) > 3000000
ORDER BY avg_revenue DESC;
-- Kết quả mong đợi: hotel 1 (60 đơn, 3.500.000), hotel 2 (50 đơn, 3.200.000)

-- -----------------------------------------------------
-- 6. GIẢI PHÁP 2: không dùng WHERE, đếm/tính trung bình có điều kiện trong HAVING
-- -----------------------------------------------------
SELECT hotel_id,
       SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END)         AS completed_bookings,
       AVG(CASE WHEN status = 'COMPLETED' THEN total_price END)       AS avg_revenue
FROM Bookings
GROUP BY hotel_id
HAVING SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) >= 50
   AND AVG(CASE WHEN status = 'COMPLETED' THEN total_price END) > 3000000
ORDER BY avg_revenue DESC;

-- -----------------------------------------------------
-- 7. GIẢI PHÁP 3: lọc trong bảng tạm (derived table) rồi mới gom nhóm
-- -----------------------------------------------------
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
