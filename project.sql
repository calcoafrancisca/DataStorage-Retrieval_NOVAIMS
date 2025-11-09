-- ============================================
-- Gym & Classes DB — base schema (tables only)
-- ============================================

DROP DATABASE IF EXISTS gym_mgmt;
CREATE DATABASE gym_mgmt CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE gym_mgmt;

-- ----------------------
-- 1) Reference: plans
-- ----------------------
CREATE TABLE plans (
  plan_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  plan_name     VARCHAR(100) NOT NULL,
  monthly_fee   DECIMAL(10,2) NOT NULL CHECK (monthly_fee >= 0),
  description   VARCHAR(255),
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------
-- 2) Core: members
-- ----------------------
CREATE TABLE members (
  member_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  plan_id       INT UNSIGNED,
  first_name    VARCHAR(80)  NOT NULL,
  last_name     VARCHAR(80)  NOT NULL,
  email         VARCHAR(160) NOT NULL,
  phone         VARCHAR(40),
  start_date    DATE,
  status        ENUM('active','on_hold','cancelled') NOT NULL DEFAULT 'active',
  visit_count   INT UNSIGNED NOT NULL DEFAULT 0,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_members_email (email),
  CONSTRAINT fk_members_plan
    FOREIGN KEY (plan_id) REFERENCES plans(plan_id)
      ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------
-- 3) Staff: trainers
-- ----------------------
CREATE TABLE trainers (
  trainer_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  first_name    VARCHAR(80) NOT NULL,
  last_name     VARCHAR(80) NOT NULL,
  email         VARCHAR(160),
  phone         VARCHAR(40),
  hire_date     DATE,
  hourly_rate   DECIMAL(10,2) CHECK (hourly_rate >= 0),
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------
-- 4) Classes: gym_classes
-- ----------------------
CREATE TABLE gym_classes (
  class_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  class_name    VARCHAR(120) NOT NULL,
  trainer_id    INT UNSIGNED NOT NULL,
  room          VARCHAR(60),
  capacity      INT UNSIGNED NOT NULL DEFAULT 20,
  start_time    DATETIME NOT NULL,
  end_time      DATETIME NOT NULL,
  difficulty    ENUM('beginner','intermediate','advanced') DEFAULT 'beginner',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_class_time (start_time),
  CONSTRAINT fk_class_trainer
    FOREIGN KEY (trainer_id) REFERENCES trainers(trainer_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CHECK (end_time > start_time)
) ENGINE=InnoDB;

-- ----------------------
-- 5) Bookings: class_bookings
-- ----------------------
CREATE TABLE class_bookings (
  booking_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  class_id      INT UNSIGNED NOT NULL,
  member_id     INT UNSIGNED NOT NULL,
  booked_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status        ENUM('booked','cancelled','attended','no_show') NOT NULL DEFAULT 'booked',
  UNIQUE KEY uq_booking_unique (class_id, member_id),
  KEY ix_booking_member (member_id),
  CONSTRAINT fk_booking_class
    FOREIGN KEY (class_id) REFERENCES gym_classes(class_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_booking_member
    FOREIGN KEY (member_id) REFERENCES members(member_id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------
-- 6) Check-ins: check_ins
-- ----------------------
CREATE TABLE check_ins (
  check_in_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  member_id     INT UNSIGNED NOT NULL,
  check_in_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  location      VARCHAR(100),
  KEY ix_checkins_member_time (member_id, check_in_time),
  CONSTRAINT fk_checkins_member
    FOREIGN KEY (member_id) REFERENCES members(member_id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------
-- 7) Catalog: products
-- ----------------------
CREATE TABLE products (
  product_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sku           VARCHAR(64)  NOT NULL,
  product_name  VARCHAR(160) NOT NULL,
  category      ENUM('Merch','Membership','Class') NOT NULL,
  unit_price    DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
  unit_cost     DECIMAL(10,2) CHECK (unit_cost >= 0),
  stock_qty     INT NOT NULL DEFAULT 0,
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_products_sku (sku)
) ENGINE=InnoDB;

-- ----------------------
-- 8) Orders (invoice header)
-- ----------------------
CREATE TABLE orders (
  order_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  member_id     INT UNSIGNED NOT NULL,
  order_date    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status        ENUM('new','paid','cancelled') NOT NULL DEFAULT 'new',
  payment_method ENUM('cash','card','online') DEFAULT 'card',
  subtotal      DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  tax_amount    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_amount  DECIMAL(12,2) GENERATED ALWAYS AS (subtotal + tax_amount) STORED,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_orders_member_date (member_id, order_date),
  CONSTRAINT fk_orders_member
    FOREIGN KEY (member_id) REFERENCES members(member_id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ----------------------
-- 9) Order lines (invoice details)
-- ----------------------
CREATE TABLE order_items (
  order_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id      INT UNSIGNED NOT NULL,
  product_id    INT UNSIGNED NOT NULL,
  description   VARCHAR(200),
  qty           INT UNSIGNED NOT NULL DEFAULT 1,
  unit_price    DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
  line_total    DECIMAL(12,2) GENERATED ALWAYS AS (qty * unit_price) STORED,
  CONSTRAINT fk_items_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_items_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ----------------------
-- 10) Reviews (classes or trainers)
-- ----------------------
CREATE TABLE reviews (
  review_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  member_id     INT UNSIGNED NOT NULL,
  target_type   ENUM('class','trainer') NOT NULL,
  class_id      INT UNSIGNED NULL,
  trainer_id    INT UNSIGNED NULL,
  rating        TINYINT UNSIGNED NOT NULL,
  comment       VARCHAR(400),
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  -- Uniqueness per target type; NULLs are allowed on the other FK
  UNIQUE KEY uq_review_unique_class   (member_id, target_type, class_id),
  UNIQUE KEY uq_review_unique_trainer (member_id, target_type, trainer_id),

  CONSTRAINT fk_review_member
    FOREIGN KEY (member_id) REFERENCES members(member_id)
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_review_class
    FOREIGN KEY (class_id) REFERENCES gym_classes(class_id)
      ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_review_trainer
    FOREIGN KEY (trainer_id) REFERENCES trainers(trainer_id)
      ON UPDATE CASCADE ON DELETE SET NULL,

  CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;


-- ----------------------
-- 11) Audit log: log_events
-- ----------------------
CREATE TABLE log_events (
  log_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_time    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actor         VARCHAR(120),           -- user/employee/system
  action        VARCHAR(60)  NOT NULL,  -- e.g., 'STOCK_DECREMENT', 'ORDER_CREATED'
  table_name    VARCHAR(60)  NOT NULL,
  record_id     VARCHAR(60)  NOT NULL,  -- affected PK value
  details       JSON
) ENGINE=InnoDB;

-- Handy indexes
CREATE INDEX ix_products_active ON products(is_active);
CREATE INDEX ix_reviews_member_time ON reviews(member_id, created_at);
-- date-only index helps monthly revenue query
CREATE INDEX ix_orders_date ON orders(order_date);

-- trainer/class rating summaries
CREATE INDEX ix_reviews_trainer_type ON reviews(target_type, trainer_id);
CREATE INDEX ix_reviews_class_type   ON reviews(target_type, class_id);

-- booking conversion by class + status
CREATE INDEX ix_bookings_class_status ON class_bookings(class_id, status);





/* ===========================================================
   TRIGGERS (2 required by brief)
   - T1: After check-in => increment members.visit_count
   - T2: After order_items insert => if Merch, decrement stock and log event
   =========================================================== */

-- T1: Increment visit_count on member check-in
DROP TRIGGER IF EXISTS trg_checkins_after_insert;
DELIMITER //
CREATE TRIGGER trg_checkins_after_insert
AFTER INSERT ON check_ins
FOR EACH ROW
BEGIN
  UPDATE members
     SET visit_count = visit_count + 1
   WHERE member_id = NEW.member_id;
END//
DELIMITER ;

-- T2: Decrement stock for Merch lines; write log entry
DROP TRIGGER IF EXISTS trg_order_items_after_insert;
DELIMITER //
CREATE TRIGGER trg_order_items_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  DECLARE v_category ENUM('Merch','Membership','Class');
  SELECT category INTO v_category
    FROM products WHERE product_id = NEW.product_id;

  IF v_category = 'Merch' THEN
    UPDATE products
       SET stock_qty = stock_qty - NEW.qty
     WHERE product_id = NEW.product_id;

    INSERT INTO log_events(actor, action, table_name, record_id, details)
    VALUES (CURRENT_USER(), 'STOCK_DECREMENT', 'products', NEW.product_id,
            JSON_OBJECT('order_id', NEW.order_id, 'qty', NEW.qty, 'order_item_id', NEW.order_item_id));
  END IF;
END//
DELIMITER ;


/* ===========================================================
   SEED DATA (covers 2024–2025)
   =========================================================== */

-- Plans
INSERT INTO plans (plan_name, monthly_fee, description) VALUES
('Basic',    30.00, 'Access gym floor'),
('Standard', 45.00, 'Gym + 2 classes/month'),
('Premium',  60.00, 'All access + unlimited classes');

-- Trainers
INSERT INTO trainers (first_name, last_name, email, hire_date, hourly_rate) VALUES
('Lara','Ng','lara.ng@gym.local','2023-06-01',22.50),
('Marco','Silva','marco.silva@gym.local','2022-09-14',25.00),
('Aisha','Khan','aisha.khan@gym.local','2024-02-10',24.00);

-- Members
INSERT INTO members (plan_id, first_name, last_name, email, phone, start_date) VALUES
(1,'Ana','Costa','ana.costa@example.com','+351-910000001','2024-01-10'),
(2,'João','Pereira','joao.pereira@example.com','+351-910000002','2024-05-02'),
(2,'Marta','Oliveira','marta.oliveira@example.com','+351-910000003','2024-07-21'),
(3,'Tiago','Santos','tiago.santos@example.com','+351-910000004','2025-02-11'),
(1,'Inês','Ribeiro','ines.ribeiro@example.com','+351-910000005','2024-11-08'),
(3,'Ricardo','Ferreira','ricardo.ferreira@example.com','+351-910000006','2025-04-18');

-- Products (Merch + Membership + Class)
INSERT INTO products (sku, product_name, category, unit_price, unit_cost, stock_qty) VALUES
('M-TEE',       'Gym T-Shirt',        'Merch',       20.00,  8.00, 100),
('M-BOT',       'Water Bottle',       'Merch',       12.00,  4.00,  50),
('MEM-BASIC',   'Monthly Basic Plan', 'Membership',  30.00,  0.00,   0),
('MEM-PREM',    'Monthly Premium',    'Membership',  60.00,  0.00,   0),
('CLS-DROPIN',  'Drop-in Class',      'Class',       10.00,  0.00,   0);

-- Classes across two years (2024 & 2025)
INSERT INTO gym_classes (class_name, trainer_id, room, capacity, start_time, end_time, difficulty) VALUES
('HIIT',        1,'Room A',25,'2024-03-10 18:00:00','2024-03-10 19:00:00','intermediate'),
('Yoga',        2,'Room B',20,'2024-12-05 07:30:00','2024-12-05 08:30:00','beginner'),
('Strength',    3,'Room C',18,'2025-01-15 18:00:00','2025-01-15 19:15:00','advanced'),
('Pilates',     2,'Room B',20,'2025-05-03 09:00:00','2025-05-03 10:00:00','beginner'),
('Spin',        1,'Room D',22,'2025-09-12 18:30:00','2025-09-12 19:15:00','intermediate'),
('Bootcamp',    3,'Room A',24,'2025-10-20 07:00:00','2025-10-20 08:00:00','advanced');

-- Bookings
INSERT INTO class_bookings (class_id, member_id, status) VALUES
(1,1,'attended'), (1,2,'attended'),
(2,3,'booked'),
(3,4,'attended'),
(4,2,'no_show'),
(5,5,'booked'),
(6,6,'booked');

-- Check-ins (will increment visit_count via trigger)
INSERT INTO check_ins (member_id, check_in_time, location) VALUES
(1,'2024-06-15 17:55:00','Front Desk'),
(1,'2024-11-02 07:10:00','Front Desk'),
(2,'2024-11-02 07:05:00','Front Desk'),
(2,'2025-03-22 10:01:00','Front Desk'),
(3,'2025-09-01 18:03:00','Front Desk'),
(4,'2025-10-10 08:55:00','Front Desk');

-- Orders (header only; amounts will be set after lines)
INSERT INTO orders (member_id, order_date, status, payment_method) VALUES
(1,'2024-06-15 18:10:00','paid','card'),
(2,'2024-11-02 07:40:00','paid','card'),
(1,'2025-03-22 10:15:00','paid','online'),
(3,'2025-09-01 18:20:00','paid','card'),
(4,'2025-10-10 09:10:00','paid','cash');




-- Order lines
-- O1: membership + T-shirt
INSERT INTO order_items (order_id, product_id, description, qty, unit_price) VALUES
(1,3,'Basic monthly plan',1,30.00),
(1,1,'Gym T-Shirt',1,20.00);

-- O2: drop-in class
INSERT INTO order_items (order_id, product_id, description, qty, unit_price) VALUES
(2,5,'Drop-in class',1,10.00);

-- O3: bottle + drop-in class
INSERT INTO order_items (order_id, product_id, description, qty, unit_price) VALUES
(3,2,'Water Bottle',1,12.00),
(3,5,'Drop-in class',1,10.00);

-- O4: premium membership
INSERT INTO order_items (order_id, product_id, description, qty, unit_price) VALUES
(4,4,'Premium monthly plan',1,60.00);

-- O5: two T-shirts
INSERT INTO order_items (order_id, product_id, description, qty, unit_price) VALUES
(5,1,'Gym T-Shirt',2,20.00);

-- Compute order subtotals & tax (e.g., 23% VAT), total is generated column
UPDATE orders o
JOIN (
  SELECT order_id, SUM(line_total) AS subtotal
  FROM order_items GROUP BY order_id
) s ON s.order_id = o.order_id
SET o.subtotal = s.subtotal,
    o.tax_amount = ROUND(s.subtotal * 0.23, 2);

/* ===========================================================
   EXTRA TRANSACTIONS to reach ~30 order_items rows
   =========================================================== */

-- Resolve product IDs & prices once (safe to SELECT here)
SET @pid_tee   := (SELECT product_id FROM products WHERE sku='M-TEE');
SET @pid_bot   := (SELECT product_id FROM products WHERE sku='M-BOT');
SET @pid_basic := (SELECT product_id FROM products WHERE sku='MEM-BASIC');
SET @pid_prem  := (SELECT product_id FROM products WHERE sku='MEM-PREM');
SET @pid_class := (SELECT product_id FROM products WHERE sku='CLS-DROPIN');

SET @p_tee   := (SELECT unit_price FROM products WHERE product_id=@pid_tee);
SET @p_bot   := (SELECT unit_price FROM products WHERE product_id=@pid_bot);
SET @p_basic := (SELECT unit_price FROM products WHERE product_id=@pid_basic);
SET @p_prem  := (SELECT unit_price FROM products WHERE product_id=@pid_prem);
SET @p_class := (SELECT unit_price FROM products WHERE product_id=@pid_class);

-- O6: 2024-12-15 (João) T-shirt + drop-in
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (2,'2024-12-15 12:00:00','paid','card');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price)
VALUES 
(@oid, @pid_tee,   'Gym T-Shirt',   1, @p_tee),
(@oid, @pid_class, 'Drop-in Class', 1, @p_class);

-- O7: 2025-01-05 (Ana) Basic plan + bottle
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (1,'2025-01-05 09:00:00','paid','online');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price)
VALUES 
(@oid, @pid_basic, 'Monthly Basic Plan', 1, @p_basic),
(@oid, @pid_bot,   'Water Bottle',       1, @p_bot);

-- O8: 2025-02-14 (Marta) bottle x2 + class
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (3,'2025-02-14 18:30:00','paid','card');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price)
VALUES 
(@oid, @pid_bot,   'Water Bottle', 2, @p_bot),
(@oid, @pid_class, 'Drop-in Class', 1, @p_class);

-- O9: 2025-03-10 (Inês) T-shirt + class
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (5,'2025-03-10 07:45:00','paid','card');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price)
VALUES 
(@oid, @pid_tee,   'Gym T-Shirt',   1, @p_tee),
(@oid, @pid_class, 'Drop-in Class', 1, @p_class);

-- O10: 2025-04-22 (Ricardo) Premium plan
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (6,'2025-04-22 17:10:00','paid','card');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price)
VALUES 
(@oid, @pid_prem,  'Premium monthly plan', 1, @p_prem);

-- O11: 2025-05-15 (João) T-shirt + bottle
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (2,'2025-05-15 10:00:00','paid','card');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price)
VALUES 
(@oid, @pid_tee, 'Gym T-Shirt', 1, @p_tee),
(@oid, @pid_bot, 'Water Bottle', 1, @p_bot);

-- O12: 2025-06-30 (Tiago) Premium + class
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (4,'2025-06-30 19:20:00','paid','online');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price)
VALUES 
(@oid, @pid_prem,  'Premium monthly plan', 1, @p_prem),
(@oid, @pid_class, 'Drop-in Class',        1, @p_class);

-- O13: 2025-07-12 (Ana) T-shirt x2
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (1,'2025-07-12 11:00:00','paid','card');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price)
VALUES 
(@oid, @pid_tee, 'Gym T-Shirt', 2, @p_tee);

-- O14: 2025-08-25 (Marta) bottle + class
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (3,'2025-08-25 08:15:00','paid','card');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price)
VALUES 
(@oid, @pid_bot,   'Water Bottle',   1, @p_bot),
(@oid, @pid_class, 'Drop-in Class',  1, @p_class);

-- O15: 2025-11-03 (Tiago) T-shirt + bottle + class
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (4,'2025-11-03 12:34:00','paid','card');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price)
VALUES 
(@oid, @pid_tee,   'Gym T-Shirt',   1, @p_tee),
(@oid, @pid_bot,   'Water Bottle',  1, @p_bot),
(@oid, @pid_class, 'Drop-in Class', 1, @p_class);

-- O16: 2025-11-20 (Ana) T-shirt + Bottle + Class
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (1,'2025-11-20 10:05:00','paid','card');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price) VALUES
(@oid, @pid_tee,   'Gym T-Shirt',   1, @p_tee),
(@oid, @pid_bot,   'Water Bottle',  1, @p_bot),
(@oid, @pid_class, 'Drop-in Class', 1, @p_class);

-- O17: 2025-11-25 (Ricardo) Premium + T-shirt
INSERT INTO orders (member_id, order_date, status, payment_method)
VALUES (6,'2025-11-25 18:45:00','paid','online');
SET @oid := LAST_INSERT_ID();
INSERT INTO order_items (order_id, product_id, description, qty, unit_price) VALUES
(@oid, @pid_prem, 'Premium monthly plan', 1, @p_prem),
(@oid, @pid_tee,  'Gym T-Shirt',          1, @p_tee);

-- Recompute order totals (covers all orders)
UPDATE orders o
JOIN (
  SELECT order_id, SUM(line_total) AS subtotal
  FROM order_items GROUP BY order_id
) s ON s.order_id = o.order_id
SET o.subtotal = s.subtotal,
    o.tax_amount = ROUND(s.subtotal * 0.23, 2);


-- Reviews consistency validation triggers
DROP TRIGGER IF EXISTS trg_reviews_bi_validate;
DROP TRIGGER IF EXISTS trg_reviews_bu_validate;
DELIMITER //
CREATE TRIGGER trg_reviews_bi_validate
BEFORE INSERT ON reviews
FOR EACH ROW
BEGIN
  IF (NEW.target_type='class'   AND (NEW.class_id IS NULL OR NEW.trainer_id IS NOT NULL)) OR
     (NEW.target_type='trainer' AND (NEW.trainer_id IS NULL OR NEW.class_id IS NOT NULL)) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'reviews: target_type must match exactly one FK (class_id XOR trainer_id).';
  END IF;
END//
CREATE TRIGGER trg_reviews_bu_validate
BEFORE UPDATE ON reviews
FOR EACH ROW
BEGIN
  IF (NEW.target_type='class'   AND (NEW.class_id IS NULL OR NEW.trainer_id IS NOT NULL)) OR
     (NEW.target_type='trainer' AND (NEW.trainer_id IS NULL OR NEW.class_id IS NOT NULL)) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'reviews: target_type must match exactly one FK (class_id XOR trainer_id).';
  END IF;
END//
DELIMITER ;


-- Reviews (class + trainer)
INSERT INTO reviews (member_id, target_type, class_id, rating, comment) VALUES
(1,'class',1,5,'Loved the HIIT format'),
(2,'class',1,4,'Great energy'),
(4,'class',3,5,'Tough but good');

INSERT INTO reviews (member_id, target_type, trainer_id, rating, comment) VALUES
(3,'trainer',2,5,'Marco explains very clearly'),
(5,'trainer',1,4,'Challenging sessions');


 /* ===========================================================
    INVOICE VIEWS (2 views: head and lines)
    =========================================================== */

DROP VIEW IF EXISTS invoice_head_v;
CREATE VIEW invoice_head_v AS
SELECT
  o.order_id,
  o.order_date,
  m.member_id,
  CONCAT(m.first_name,' ',m.last_name) AS member_name,
  m.email AS member_email,
  o.subtotal,
  o.tax_amount,
  o.total_amount
FROM orders o
JOIN members m ON m.member_id = o.member_id;

DROP VIEW IF EXISTS invoice_lines_v;
CREATE VIEW invoice_lines_v AS
SELECT
  oi.order_id,
  ROW_NUMBER() OVER (PARTITION BY oi.order_id ORDER BY oi.order_item_id) AS line_no,
  p.sku,
  p.product_name,
  p.category,
  oi.qty,
  oi.unit_price,
  oi.line_total
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id;


/* ===========================================================
   CEO QUERIES (samples; ≥3 require JOIN + GROUP BY)
   =========================================================== */

-- 1) Top 5 customers by total revenue (JOIN + GROUP)
SELECT m.member_id, CONCAT(m.first_name,' ',m.last_name) AS member,
       SUM(o.total_amount) AS total_revenue
FROM orders o
JOIN members m ON m.member_id = o.member_id
GROUP BY m.member_id, member
ORDER BY total_revenue DESC
LIMIT 5;

-- 2) Monthly revenue trend (two years)
SELECT DATE_FORMAT(order_date, '%Y-%m') AS ym, SUM(total_amount) AS revenue
FROM orders
GROUP BY ym ORDER BY ym;

-- 3) Product mix: revenue share by category
SELECT p.category, SUM(oi.line_total) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;

-- 4) Trainer ratings (avg stars)
SELECT t.trainer_id, CONCAT(t.first_name,' ',t.last_name) AS trainer,
       ROUND(AVG(r.rating),2) AS avg_rating, COUNT(*) AS n
FROM reviews r
JOIN trainers t ON t.trainer_id = r.trainer_id
WHERE r.target_type='trainer'
GROUP BY t.trainer_id, trainer
ORDER BY avg_rating DESC, n DESC;

-- 5) Class attendance conversion (booked→attended rate)
SELECT gc.class_id, gc.class_name,
       SUM(cb.status='booked')    AS booked,
       SUM(cb.status='attended')  AS attended,
       ROUND(100*SUM(cb.status='attended')/NULLIF(SUM(cb.status IN ('booked','attended','no_show')),0),1) AS attend_rate_pct
FROM gym_classes gc
LEFT JOIN class_bookings cb ON cb.class_id = gc.class_id
GROUP BY gc.class_id, gc.class_name
ORDER BY attend_rate_pct DESC;
