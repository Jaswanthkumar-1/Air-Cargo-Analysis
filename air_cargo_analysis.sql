-- ============================================================
-- AIR CARGO ANALYSIS - COURSE END PROJECT
-- All 20 SQL Queries with Solutions
-- ============================================================

-- ============================================================
-- Q1: ER Diagram (described below - use MySQL Workbench to visualize)
-- Tables: customer, passengers_on_flights, ticket_details, routes
-- Relationships:
--   customer.customer_id -> passengers_on_flights.customer_id
--   customer.customer_id -> ticket_details.customer_id
--   routes.route_id      -> passengers_on_flights.route_id
--   routes.aircraft_id   -> ticket_details.aircraft_id
-- ============================================================

-- ============================================================
-- Q2: Create route_details table with constraints
-- ============================================================
CREATE TABLE route_details (
    route_id        INT          NOT NULL,
    flight_num      INT          NOT NULL,
    origin_airport  VARCHAR(50)  NOT NULL,
    destination_airport VARCHAR(50) NOT NULL,
    aircraft_id     VARCHAR(20)  NOT NULL,
    distance_miles  INT          NOT NULL,
    CONSTRAINT uq_route_id   UNIQUE (route_id),
    CONSTRAINT chk_flight_num CHECK (flight_num > 0),
    CONSTRAINT chk_distance   CHECK (distance_miles > 0)
);

-- ============================================================
-- Q3: Passengers who travelled on routes 01 to 25
-- ============================================================
SELECT *
FROM passengers_on_flights
WHERE route_id BETWEEN 1 AND 25;

-- Output: 26 rows
-- Passengers travelling JFK-LAX, DEN-LAX, ABI-ADK etc.

-- ============================================================
-- Q4: Number of passengers and total revenue in Business class
-- ============================================================
SELECT
    COUNT(*)                              AS num_passengers,
    SUM(no_of_tickets * price_per_ticket) AS total_revenue
FROM ticket_details
WHERE class_id = 'Bussiness';

-- Output: num_passengers=13, total_revenue=6034

-- ============================================================
-- Q5: Full name of customers (first_name + last_name)
-- ============================================================
SELECT
    customer_id,
    CONCAT(first_name, ' ', last_name) AS full_name
FROM customer;

-- Output: 50 rows e.g. "Julie Sam", "Steve Ryan"

-- ============================================================
-- Q6: Customers who have registered AND booked a ticket
-- ============================================================
SELECT DISTINCT
    c.customer_id,
    c.first_name,
    c.last_name
FROM customer c
INNER JOIN ticket_details t
    ON c.customer_id = t.customer_id;

-- Output: 33 customers have both registered and booked

-- ============================================================
-- Q7: Customer first/last name filtered by Emirates brand
-- ============================================================
SELECT DISTINCT
    c.first_name,
    c.last_name
FROM customer c
JOIN ticket_details t
    ON c.customer_id = t.customer_id
WHERE t.brand = 'Emirates';

-- Output: 14 customers flew with Emirates

-- ============================================================
-- Q8: Customers who travelled Economy Plus (GROUP BY + HAVING)
-- ============================================================
SELECT
    customer_id,
    COUNT(*) AS trips
FROM passengers_on_flights
WHERE class_id = 'Economy Plus'
GROUP BY customer_id
HAVING COUNT(*) >= 1;

-- Output: 9 customers travelled in Economy Plus

-- ============================================================
-- Q9: Check if total revenue has crossed 10000 (IF clause)
-- ============================================================
SELECT
    SUM(no_of_tickets * price_per_ticket) AS total_revenue,
    IF(SUM(no_of_tickets * price_per_ticket) > 10000, 'Yes', 'No') AS crossed_10000
FROM ticket_details;

-- Output: total_revenue=15369, crossed_10000='Yes'

-- ============================================================
-- Q10: Create new user and grant access
-- ============================================================
CREATE USER 'air_cargo_user'@'localhost' IDENTIFIED BY 'Password@123';
GRANT SELECT, INSERT, UPDATE, DELETE ON air_cargo.* TO 'air_cargo_user'@'localhost';
FLUSH PRIVILEGES;

-- ============================================================
-- Q11: Maximum ticket price per class (Window Function)
-- ============================================================
SELECT DISTINCT
    class_id,
    MAX(price_per_ticket) OVER (PARTITION BY class_id) AS max_price
FROM ticket_details;

-- Output:
-- Bussiness    510
-- Economy      190
-- Economy Plus 295
-- First Class  395

-- ============================================================
-- Q12: Passengers with route_id = 4 (with Index for performance)
-- ============================================================
CREATE INDEX idx_route_id ON passengers_on_flights(route_id);

SELECT *
FROM passengers_on_flights
WHERE route_id = 4;

-- Output: 3 passengers (JFK -> LAX, flight 1114)

-- ============================================================
-- Q13: Execution plan for route_id = 4
-- ============================================================
EXPLAIN SELECT *
FROM passengers_on_flights
WHERE route_id = 4;

-- ============================================================
-- Q14: Total price per customer across aircraft (ROLLUP)
-- ============================================================
SELECT
    customer_id,
    aircraft_id,
    SUM(no_of_tickets * price_per_ticket) AS total_price
FROM ticket_details
GROUP BY customer_id, aircraft_id WITH ROLLUP;

-- ============================================================
-- Q15: View - Business class customers with brand
-- ============================================================
CREATE VIEW business_class_customers AS
SELECT
    t.customer_id,
    c.first_name,
    c.last_name,
    t.class_id,
    t.brand
FROM ticket_details t
JOIN customer c ON t.customer_id = c.customer_id
WHERE t.class_id = 'Bussiness';

SELECT * FROM business_class_customers;

-- Output: 13 Business class customers across Emirates, Qatar Airways etc.

-- ============================================================
-- Q16: Stored Procedure - Passengers between a range of routes
-- ============================================================
DELIMITER $$
CREATE PROCEDURE get_passengers_by_route_range(
    IN p_start INT,
    IN p_end   INT
)
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        SELECT 'Error: Table does not exist or query failed' AS error_message;

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_name = 'passengers_on_flights') THEN
        SELECT 'Error: passengers_on_flights table does not exist' AS error_message;
    ELSE
        SELECT *
        FROM passengers_on_flights
        WHERE route_id BETWEEN p_start AND p_end;
    END IF;
END $$
DELIMITER ;

-- Usage:
CALL get_passengers_by_route_range(1, 25);

-- ============================================================
-- Q17: Stored Procedure - Routes with distance > 2000 miles
-- ============================================================
DELIMITER $$
CREATE PROCEDURE get_long_routes()
BEGIN
    SELECT *
    FROM routes
    WHERE distance_miles > 2000;
END $$
DELIMITER ;

CALL get_long_routes();

-- ============================================================
-- Q18: Stored Procedure - Categorize distance into SDT/IDT/LDT
-- ============================================================
DELIMITER $$
CREATE PROCEDURE categorize_distance()
BEGIN
    SELECT
        route_id,
        flight_num,
        origin_airport,
        destination_airport,
        distance_miles,
        CASE
            WHEN distance_miles >= 0    AND distance_miles <= 2000 THEN 'SDT'
            WHEN distance_miles >  2000 AND distance_miles <= 6500 THEN 'IDT'
            WHEN distance_miles >  6500                            THEN 'LDT'
        END AS distance_category
    FROM routes;
END $$
DELIMITER ;

CALL categorize_distance();

-- ============================================================
-- Q19: Stored Function in Procedure - Complimentary Services
-- ============================================================
DELIMITER $$
CREATE FUNCTION get_complimentary(class VARCHAR(50))
RETURNS VARCHAR(3)
DETERMINISTIC
BEGIN
    IF class IN ('Bussiness', 'Economy Plus') THEN
        RETURN 'Yes';
    ELSE
        RETURN 'No';
    END IF;
END $$

CREATE PROCEDURE get_ticket_with_complimentary()
BEGIN
    SELECT
        p_date,
        customer_id,
        class_id,
        get_complimentary(class_id) AS complimentary_services
    FROM ticket_details;
END $$
DELIMITER ;

CALL get_ticket_with_complimentary();

-- ============================================================
-- Q20: Cursor - First customer whose last name ends with 'Scott'
-- ============================================================
DELIMITER $$
CREATE PROCEDURE get_first_scott()
BEGIN
    DECLARE v_customer_id   INT;
    DECLARE v_first_name    VARCHAR(50);
    DECLARE v_last_name     VARCHAR(50);
    DECLARE v_dob           VARCHAR(20);
    DECLARE v_gender        VARCHAR(1);
    DECLARE done            INT DEFAULT 0;

    DECLARE scott_cursor CURSOR FOR
        SELECT customer_id, first_name, last_name, date_of_birth, gender
        FROM customer
        WHERE last_name LIKE '%Scott';

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN scott_cursor;

    FETCH scott_cursor INTO v_customer_id, v_first_name, v_last_name, v_dob, v_gender;

    IF NOT done THEN
        SELECT v_customer_id AS customer_id,
               v_first_name  AS first_name,
               v_last_name   AS last_name,
               v_dob         AS date_of_birth,
               v_gender      AS gender;
    END IF;

    CLOSE scott_cursor;
END $$
DELIMITER ;

CALL get_first_scott();

-- Output: customer_id=37, Samuel Scott, 28-01-2000, M
