-- =====================================================
-- Module "Top User VIP Theo Từng Hạng Phòng"
-- =====================================================

-- 1. Tạo bảng
CREATE TABLE Users (
    user_id   INT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL
);

CREATE TABLE Hotels (
    hotel_id    INT PRIMARY KEY,
    hotel_name  VARCHAR(100) NOT NULL,
    star_rating INT NOT NULL
);

CREATE TABLE Bookings (
    booking_id  INT PRIMARY KEY,
    user_id     INT NOT NULL,
    hotel_id    INT NOT NULL,
    status      VARCHAR(20) NOT NULL,
    total_price DECIMAL(15, 2) NOT NULL,
    FOREIGN KEY (user_id)  REFERENCES Users(user_id),
    FOREIGN KEY (hotel_id) REFERENCES Hotels(hotel_id)
);

-- 2. Dữ liệu mẫu
INSERT INTO Users (user_id, full_name) VALUES
    (1, 'Nguyen Van A'),
    (2, 'Tran Thi B'),
    (3, 'Le Van C'),
    (4, 'Pham Thi D');

INSERT INTO Hotels (hotel_id, hotel_name, star_rating) VALUES
    (101, 'InterContinental', 5),
    (102, 'Sheraton', 5),
    (103, 'Novotel', 4),
    (104, 'Muong Thanh Standard', 3);

INSERT INTO Bookings (booking_id, user_id, hotel_id, status, total_price) VALUES
    (1001, 1, 101, 'COMPLETED', 30000000),
    (1002, 1, 102, 'COMPLETED', 25000000),
    (1003, 1, 103, 'COMPLETED', 60000000),
    (1004, 2, 101, 'COMPLETED', 90000000),
    (1005, 2, 101, 'COMPLETED', -5000000),   -- dữ liệu rác: giá âm
    (1006, 2, 101, 'PENDING',   20000000),
    (1007, 3, 102, 'COMPLETED', 10000000),
    (1008, 3, 102, 'CANCELLED', 50000000),
    (1009, 4, 103, 'COMPLETED', 49000000);

-- 3. Index hỗ trợ lọc và JOIN
CREATE INDEX idx_bookings_status_price ON Bookings (status, total_price, user_id, hotel_id);

-- -----------------------------------------------------
-- 4. CÁCH GOM NHÓM SAI (KHÔNG DÙNG)
-- Chỉ GROUP BY theo khách hàng -> gộp chi tiêu 4 sao và 5 sao vào chung 1 dòng
-- -----------------------------------------------------
-- SELECT u.full_name, SUM(b.total_price) AS total_spent
-- FROM Bookings b
-- JOIN Users u  ON u.user_id  = b.user_id
-- JOIN Hotels h ON h.hotel_id = b.hotel_id
-- WHERE b.status = 'COMPLETED'
-- GROUP BY u.user_id, u.full_name;
-- => Nguyen Van A bị gộp thành 115.000.000 (55 triệu ở 5 sao + 60 triệu ở 4 sao)

-- -----------------------------------------------------
-- 5. SIÊU CÂU LỆNH HOÀN CHỈNH
-- -----------------------------------------------------
SELECT u.full_name          AS customer_name,
       h.star_rating        AS star_rating,
       SUM(b.total_price)   AS total_spent
FROM Bookings b
JOIN Users  u ON u.user_id  = b.user_id
JOIN Hotels h ON h.hotel_id = b.hotel_id
WHERE b.status = 'COMPLETED'            -- chỉ tính đơn thành công
  AND b.total_price > 0                 -- loại dữ liệu rác giá âm TRƯỚC khi gom nhóm
GROUP BY u.user_id, u.full_name, h.star_rating
HAVING SUM(b.total_price) > 50000000    -- VIP: chi tiêu cho 1 hạng sao > 50 triệu
ORDER BY h.star_rating DESC,            -- 5 sao lên đầu
         total_spent DESC;              -- cùng hạng: chi nhiều hơn đứng trên

-- Kết quả mong đợi:
--   Tran Thi B    5  90000000
--   Nguyen Van A  5  55000000
--   Nguyen Van A  4  60000000
