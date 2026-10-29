-- ============================================================
-- TRAINING COURSE: Environment Setup
-- Run this as ACCOUNTADMIN to provision the full environment.
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- -------------------------------------------------------
-- 1. WAREHOUSE
-- -------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS TRAINING_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for dbt training course';

-- -------------------------------------------------------
-- 2. DATABASES
-- -------------------------------------------------------

-- Source database (simulates the raw transactional system)
CREATE DATABASE IF NOT EXISTS RAW
    COMMENT = 'Raw source data for training course';

-- Target database (where dbt models will be built)
CREATE DATABASE IF NOT EXISTS ANALYTICS
    COMMENT = 'dbt models and transformed data';

-- -------------------------------------------------------
-- 3. SCHEMAS
-- -------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS RAW.PUBLIC;

CREATE SCHEMA IF NOT EXISTS ANALYTICS.STAGING;
CREATE SCHEMA IF NOT EXISTS ANALYTICS.INTERMEDIATE;
CREATE SCHEMA IF NOT EXISTS ANALYTICS.MARTS;

-- -------------------------------------------------------
-- 4. ROLE & PERMISSIONS
-- -------------------------------------------------------
CREATE ROLE IF NOT EXISTS TRAINING_ROLE
    COMMENT = 'Role for dbt training course students';

-- Warehouse access
GRANT USAGE ON WAREHOUSE TRAINING_WH TO ROLE TRAINING_ROLE;

-- Source database: read-only
GRANT USAGE ON DATABASE RAW TO ROLE TRAINING_ROLE;
GRANT USAGE ON SCHEMA RAW.PUBLIC TO ROLE TRAINING_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA RAW.PUBLIC TO ROLE TRAINING_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RAW.PUBLIC TO ROLE TRAINING_ROLE;

-- Target database: full build permissions
GRANT USAGE ON DATABASE ANALYTICS TO ROLE TRAINING_ROLE;
GRANT ALL ON SCHEMA ANALYTICS.STAGING TO ROLE TRAINING_ROLE;
GRANT ALL ON SCHEMA ANALYTICS.INTERMEDIATE TO ROLE TRAINING_ROLE;
GRANT ALL ON SCHEMA ANALYTICS.MARTS TO ROLE TRAINING_ROLE;

-- Allow dbt to create objects in target schemas
GRANT CREATE TABLE ON SCHEMA ANALYTICS.STAGING TO ROLE TRAINING_ROLE;
GRANT CREATE VIEW ON SCHEMA ANALYTICS.STAGING TO ROLE TRAINING_ROLE;
GRANT CREATE TABLE ON SCHEMA ANALYTICS.INTERMEDIATE TO ROLE TRAINING_ROLE;
GRANT CREATE VIEW ON SCHEMA ANALYTICS.INTERMEDIATE TO ROLE TRAINING_ROLE;
GRANT CREATE TABLE ON SCHEMA ANALYTICS.MARTS TO ROLE TRAINING_ROLE;
GRANT CREATE VIEW ON SCHEMA ANALYTICS.MARTS TO ROLE TRAINING_ROLE;

-- Grant role to SYSADMIN (best practice) and to the current user
GRANT ROLE TRAINING_ROLE TO ROLE SYSADMIN;

-- -------------------------------------------------------
-- 5. SEED DATA: RAW TABLES
-- -------------------------------------------------------
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE TRAINING_WH;
USE DATABASE RAW;
USE SCHEMA PUBLIC;

-- CUSTOMERS
CREATE OR REPLACE TABLE RAW.PUBLIC.CUSTOMERS (
    customer_id   INTEGER,
    first_name    VARCHAR(100),
    last_name     VARCHAR(100),
    email         VARCHAR(255),
    phone         VARCHAR(50),
    country       VARCHAR(100),
    created_at    TIMESTAMP_NTZ
);

INSERT INTO RAW.PUBLIC.CUSTOMERS VALUES
    (1,  'Alice',   'Johnson',  'alice@example.com',       '555-0101', 'US',             '2020-01-15 08:30:00'),
    (2,  'Bob',     'Smith',    'bob.smith@example.com',   '555-0102', 'United States',  '2020-02-20 14:15:00'),
    (3,  'Charlie', 'Brown',    'charlie@example.com',     NULL,       'UK',             '2020-03-10 09:00:00'),
    (4,  'Diana',   'Prince',   'diana@example.com',       '555-0104', 'Great Britain',  '2020-04-05 11:30:00'),
    (5,  'Eve',     'Wilson',   'eve.w@example.com',       '555-0105', 'CA',             '2020-05-12 16:45:00'),
    (6,  'Frank',   'Miller',   'frank@example.com',       '555-0106', 'Canada',         '2020-06-01 10:00:00'),
    (7,  'Grace',   'Lee',      'grace@example.com',       '555-0107', 'DE',             '2020-06-15 13:20:00'),
    (8,  'Hank',    'Garcia',   'hank@example.com',        '555-0108', 'Germany',        '2020-07-20 07:50:00'),
    (9,  'Ivy',     'Chen',     'ivy.chen@example.com',    '555-0109', 'FR',             '2020-08-08 15:10:00'),
    (10, 'Jack',    'Taylor',   'jack@example.com',        '555-0110', 'france',         '2020-09-01 12:00:00'),
    (11, 'Kate',    'Brown',    'kate@example.com',        '555-0111', '',               '2020-10-10 09:30:00'),
    (12, 'Leo',     'Adams',    'leo@example.com',         NULL,       NULL,             '2020-11-05 14:00:00'),
    -- Duplicate email (should be deduped — older record)
    (13, ' alice ', 'Johnson',  ' Alice@Example.com ',     '555-0101', 'USA',            '2019-06-01 08:30:00'),
    -- Bad email (should be filtered)
    (14, 'Mike',    'Ross',     'not-an-email',            '555-0114', 'US',             '2020-12-01 10:00:00'),
    -- Null created_at (should be filtered)
    (15, 'Nancy',   'Drew',     'nancy@example.com',       '555-0115', 'US',             NULL);

-- PRODUCTS
CREATE OR REPLACE TABLE RAW.PUBLIC.PRODUCTS (
    product_id    INTEGER,
    product_name  VARCHAR(200),
    category      VARCHAR(100),
    subcategory   VARCHAR(100)
);

INSERT INTO RAW.PUBLIC.PRODUCTS VALUES
    (101, 'Laptop Pro 15',      'Electronics',  'Laptops'),
    (102, 'Wireless Mouse',     'Electronics',  'Peripherals'),
    (103, 'Running Shoes X',    'Shoes',        'Athletic'),
    (104, 'Cotton T-Shirt',     'Clothing',     'Tops'),
    (105, 'Organic Coffee',     'Beverages',    'Coffee'),
    (106, 'Standing Desk',      'Furniture',    'Desks'),
    (107, 'Smartphone Ultra',   'Phones',       'Smartphones'),
    (108, 'Winter Jacket',      'Clothing',     'Outerwear'),
    (109, 'Desk Lamp',          'Home Decor',   'Lighting'),
    (110, 'Garden Hose 50ft',   'Garden',       'Watering');

-- ORDERS
CREATE OR REPLACE TABLE RAW.PUBLIC.ORDERS (
    order_id        INTEGER,
    customer_id     INTEGER,
    order_date      DATE,
    status          VARCHAR(50),
    shipping_method VARCHAR(50)
);

INSERT INTO RAW.PUBLIC.ORDERS VALUES
    -- 2023 orders
    (1001, 1,  '2023-01-10', 'completed',  'standard'),
    (1002, 2,  '2023-01-15', 'completed',  'express'),
    (1003, 3,  '2023-02-01', 'completed',  'standard'),
    (1004, 1,  '2023-02-14', 'completed',  'overnight'),
    (1005, 4,  '2023-03-05', 'shipped',    'express'),
    (1006, 5,  '2023-03-20', 'completed',  'standard'),
    (1007, 6,  '2023-04-10', 'completed',  'standard'),
    (1008, 7,  '2023-04-22', 'cancelled',  'express'),
    (1009, 8,  '2023-05-01', 'completed',  'standard'),
    (1010, 9,  '2023-05-15', 'completed',  'overnight'),
    (1011, 10, '2023-06-01', 'completed',  'standard'),
    (1012, 1,  '2023-06-20', 'completed',  'express'),
    (1013, 2,  '2023-07-04', 'completed',  'standard'),
    (1014, 3,  '2023-07-18', 'refunded',   'standard'),
    (1015, 5,  '2023-08-01', 'completed',  'express'),
    (1016, 11, '2023-08-15', 'pending',    'standard'),
    (1017, 12, '2023-09-01', 'processing', 'standard'),
    (1018, 1,  '2023-09-10', 'completed',  'standard'),
    (1019, 6,  '2023-10-01', 'completed',  'overnight'),
    (1020, 7,  '2023-10-20', 'completed',  'standard'),
    -- 2024 orders
    (1021, 1,  '2024-01-05', 'completed',  'standard'),
    (1022, 2,  '2024-01-20', 'completed',  'express'),
    (1023, 3,  '2024-02-10', 'completed',  'standard'),
    (1024, 5,  '2024-03-01', 'completed',  'standard'),
    (1025, 8,  '2024-03-15', 'canceled',   'express'),
    (1026, 9,  '2024-04-01', 'completed',  'overnight'),
    (1027, 10, '2024-04-20', 'completed',  'standard'),
    (1028, 1,  '2024-05-01', 'completed',  'express'),
    (1029, 4,  '2024-05-15', 'completed',  'standard'),
    (1030, 6,  '2024-06-01', 'completed',  'standard');

-- PAYMENTS
CREATE OR REPLACE TABLE RAW.PUBLIC.PAYMENTS (
    payment_id     INTEGER,
    order_id       INTEGER,
    payment_method VARCHAR(50),
    amount         DECIMAL(10,2),
    status         VARCHAR(50)
);

INSERT INTO RAW.PUBLIC.PAYMENTS VALUES
    (2001, 1001, 'visa',          1299.99, 'success'),
    (2002, 1002, 'credit_card',    249.50, 'success'),
    (2003, 1003, 'paypal',         189.00, 'success'),
    (2004, 1004, 'amex',           450.00, 'success'),
    (2005, 1004, 'gift_card',      100.00, 'success'),
    (2006, 1005, 'mastercard',     320.00, 'success'),
    (2007, 1006, 'bank_transfer',  175.50, 'success'),
    (2008, 1007, 'cc',              89.99, 'success'),
    (2009, 1008, 'visa',           275.00, 'success'),
    (2010, 1008, 'visa',          -275.00, 'refund'),
    (2011, 1009, 'wire',           599.99, 'success'),
    (2012, 1010, 'venmo',          125.00, 'success'),
    (2013, 1011, 'ach',            340.00, 'success'),
    (2014, 1012, 'credit_card',    899.99, 'success'),
    (2015, 1013, 'paypal',         210.00, 'success'),
    (2016, 1014, 'visa',           189.00, 'success'),
    (2017, 1014, 'visa',          -189.00, 'refund'),
    (2018, 1015, 'mastercard',     450.75, 'success'),
    (2019, 1016, 'credit_card',     65.00, 'success'),
    (2020, 1017, 'bank_transfer',  120.00, 'success'),
    (2021, 1018, 'amex',           785.00, 'success'),
    (2022, 1019, 'visa',           210.50, 'success'),
    (2023, 1020, 'paypal',         150.00, 'success'),
    (2024, 1021, 'credit_card',    525.00, 'success'),
    (2025, 1022, 'visa',           310.00, 'success'),
    (2026, 1023, 'venmo',          189.00, 'success'),
    (2027, 1024, 'mastercard',     275.00, 'success'),
    (2028, 1025, 'cc',             199.99, 'success'),
    (2029, 1025, 'cc',            -199.99, 'refund'),
    (2030, 1026, 'wire',           425.00, 'success'),
    (2031, 1027, 'ach',            180.00, 'success'),
    (2032, 1028, 'gift_card',      150.00, 'success'),
    (2033, 1028, 'visa',           600.00, 'success'),
    (2034, 1029, 'paypal',         320.00, 'success'),
    (2035, 1030, 'bank_transfer',   95.00, 'success');

-- LINE ITEMS
CREATE OR REPLACE TABLE RAW.PUBLIC.LINE_ITEMS (
    line_item_id  INTEGER,
    order_id      INTEGER,
    product_id    INTEGER,
    quantity      INTEGER,
    unit_price    DECIMAL(10,2),
    discount_pct  DECIMAL(5,2)
);

INSERT INTO RAW.PUBLIC.LINE_ITEMS VALUES
    (3001, 1001, 101, 1, 1299.99, NULL),
    (3002, 1002, 102, 2,   49.99, 10.00),
    (3003, 1002, 104, 3,   29.99, NULL),
    (3004, 1003, 105, 5,   18.99, 5.00),
    (3005, 1003, 109, 1,   89.99, NULL),
    (3006, 1004, 107, 1,  449.99, NULL),
    (3007, 1004, 102, 1,   49.99, NULL),
    (3008, 1005, 108, 2,  159.99, NULL),
    (3009, 1006, 103, 1,  129.99, 15.00),
    (3010, 1006, 104, 2,   29.99, NULL),
    (3011, 1007, 105, 3,   18.99, NULL),
    (3012, 1007, 110, 1,   34.99, NULL),
    (3013, 1008, 106, 1,  274.99, NULL),
    (3014, 1009, 101, 1,  599.99, NULL),
    (3015, 1010, 105, 4,   18.99, 20.00),
    (3016, 1010, 109, 1,   49.99, NULL),
    (3017, 1011, 106, 1,  339.99, NULL),
    (3018, 1012, 107, 1,  449.99, NULL),
    (3019, 1012, 101, 1,  449.99, NULL),
    (3020, 1013, 103, 1,  129.99, NULL),
    (3021, 1013, 104, 3,   24.99, 5.00),
    (3022, 1014, 105, 10,  18.99, NULL),
    (3023, 1015, 101, 1,  449.99, NULL),
    (3024, 1016, 104, 2,   29.99, NULL),
    (3025, 1017, 110, 2,   34.99, NULL),
    (3026, 1017, 105, 3,   18.99, 10.00),
    (3027, 1018, 107, 1,  699.99, NULL),
    (3028, 1018, 102, 1,   49.99, NULL),
    (3029, 1019, 106, 1,  209.99, NULL),
    (3030, 1020, 103, 1,  149.99, NULL),
    (3031, 1021, 101, 1,  524.99, NULL),
    (3032, 1022, 107, 1,  309.99, NULL),
    (3033, 1023, 105, 10,  18.99, NULL),
    (3034, 1024, 103, 1,  149.99, NULL),
    (3035, 1024, 104, 5,   24.99, NULL),
    (3036, 1025, 108, 1,  199.99, NULL),
    (3037, 1026, 106, 1,  424.99, NULL),
    (3038, 1027, 110, 3,   34.99, NULL),
    (3039, 1027, 105, 2,   18.99, 15.00),
    (3040, 1028, 101, 1,  599.99, NULL),
    (3041, 1028, 102, 3,   49.99, NULL),
    (3042, 1029, 108, 2,  159.99, NULL),
    (3043, 1030, 105, 5,   18.99, NULL);

-- -------------------------------------------------------
-- 6. SEMI-STRUCTURED DATA (Module 2: VARIANT + FLATTEN)
--    Raw JSON events from a web analytics system.
-- -------------------------------------------------------
CREATE OR REPLACE TABLE RAW.PUBLIC.WEB_EVENTS (
    event_id      INTEGER,
    received_at   TIMESTAMP_NTZ,
    payload       VARIANT
);

INSERT INTO RAW.PUBLIC.WEB_EVENTS
SELECT 4001, '2023-06-01 10:15:00', PARSE_JSON('{
    "event_type": "page_view",
    "user_id": 1,
    "page": "/products/101",
    "device": {"type": "desktop", "browser": "Chrome", "os": "Windows"},
    "utm": {"source": "google", "medium": "cpc", "campaign": "summer_sale"}
}')
UNION ALL SELECT 4002, '2023-06-01 10:16:30', PARSE_JSON('{
    "event_type": "add_to_cart",
    "user_id": 1,
    "product_id": 101,
    "quantity": 1,
    "device": {"type": "desktop", "browser": "Chrome", "os": "Windows"},
    "utm": {"source": "google", "medium": "cpc", "campaign": "summer_sale"}
}')
UNION ALL SELECT 4003, '2023-06-01 10:20:00', PARSE_JSON('{
    "event_type": "purchase",
    "user_id": 1,
    "order_id": 1021,
    "total": 524.99,
    "items": [{"product_id": 101, "qty": 1, "price": 524.99}],
    "device": {"type": "desktop", "browser": "Chrome", "os": "Windows"},
    "utm": {"source": "google", "medium": "cpc", "campaign": "summer_sale"}
}')
UNION ALL SELECT 4004, '2023-06-01 11:00:00', PARSE_JSON('{
    "event_type": "page_view",
    "user_id": 2,
    "page": "/products/107",
    "device": {"type": "mobile", "browser": "Safari", "os": "iOS"},
    "utm": {"source": "facebook", "medium": "social", "campaign": "winter_launch"}
}')
UNION ALL SELECT 4005, '2023-06-02 09:30:00', PARSE_JSON('{
    "event_type": "page_view",
    "user_id": 5,
    "page": "/category/shoes",
    "device": {"type": "tablet", "browser": "Safari", "os": "iPadOS"},
    "utm": null
}')
UNION ALL SELECT 4006, '2023-06-02 09:35:00', PARSE_JSON('{
    "event_type": "add_to_cart",
    "user_id": 5,
    "product_id": 103,
    "quantity": 1,
    "device": {"type": "tablet", "browser": "Safari", "os": "iPadOS"},
    "utm": null
}')
UNION ALL SELECT 4007, '2023-06-02 14:00:00', PARSE_JSON('{
    "event_type": "purchase",
    "user_id": 3,
    "order_id": 1023,
    "total": 189.90,
    "items": [{"product_id": 105, "qty": 10, "price": 18.99}],
    "device": {"type": "desktop", "browser": "Firefox", "os": "macOS"},
    "utm": {"source": "email", "medium": "newsletter", "campaign": "monthly_digest"}
}')
UNION ALL SELECT 4008, '2023-06-03 16:45:00', PARSE_JSON('{
    "event_type": "page_view",
    "user_id": 8,
    "page": "/products/106",
    "device": {"type": "mobile", "browser": "Chrome", "os": "Android"},
    "utm": {"source": "google", "medium": "organic", "campaign": null}
}')
UNION ALL SELECT 4009, '2023-06-03 16:50:00', PARSE_JSON('{
    "event_type": "add_to_cart",
    "user_id": 8,
    "product_id": 106,
    "quantity": 1,
    "device": {"type": "mobile", "browser": "Chrome", "os": "Android"},
    "utm": {"source": "google", "medium": "organic", "campaign": null}
}')
UNION ALL SELECT 4010, '2023-06-04 08:00:00', PARSE_JSON('{
    "event_type": "purchase",
    "user_id": 9,
    "order_id": 1026,
    "total": 425.00,
    "items": [{"product_id": 106, "qty": 1, "price": 424.99}],
    "device": {"type": "desktop", "browser": "Edge", "os": "Windows"},
    "utm": {"source": "bing", "medium": "cpc", "campaign": "spring_promo"}
}');

-- -------------------------------------------------------
-- 7. OBJECTS FOR MODULE 6 (Security & Governance)
-- -------------------------------------------------------

-- Tag for PII classification
CREATE TAG IF NOT EXISTS RAW.PUBLIC.PII_LEVEL
    ALLOWED_VALUES 'public', 'internal', 'confidential', 'restricted'
    COMMENT = 'Data classification tag for PII governance';

-- Masking policy for emails
CREATE OR REPLACE MASKING POLICY RAW.PUBLIC.MASK_EMAIL AS
    (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN') THEN val
        ELSE REGEXP_REPLACE(val, '.+@', '***@')
    END;

-- Masking policy for phone numbers
CREATE OR REPLACE MASKING POLICY RAW.PUBLIC.MASK_PHONE AS
    (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN') THEN val
        ELSE '***-****'
    END;

-- Apply tags (students will apply masking policies in Lab 6)
ALTER TABLE RAW.PUBLIC.CUSTOMERS MODIFY COLUMN email
    SET TAG RAW.PUBLIC.PII_LEVEL = 'confidential';
ALTER TABLE RAW.PUBLIC.CUSTOMERS MODIFY COLUMN phone
    SET TAG RAW.PUBLIC.PII_LEVEL = 'internal';

-- Schema for snapshots (Module 5)
CREATE SCHEMA IF NOT EXISTS ANALYTICS.SNAPSHOTS;
GRANT ALL ON SCHEMA ANALYTICS.SNAPSHOTS TO ROLE TRAINING_ROLE;
GRANT CREATE TABLE ON SCHEMA ANALYTICS.SNAPSHOTS TO ROLE TRAINING_ROLE;

-- -------------------------------------------------------
-- 8. VERIFY ROW COUNTS
-- -------------------------------------------------------
SELECT 'customers'  AS table_name, COUNT(*) AS row_count FROM RAW.PUBLIC.CUSTOMERS
UNION ALL
SELECT 'products',                 COUNT(*)              FROM RAW.PUBLIC.PRODUCTS
UNION ALL
SELECT 'orders',                   COUNT(*)              FROM RAW.PUBLIC.ORDERS
UNION ALL
SELECT 'payments',                 COUNT(*)              FROM RAW.PUBLIC.PAYMENTS
UNION ALL
SELECT 'line_items',               COUNT(*)              FROM RAW.PUBLIC.LINE_ITEMS
UNION ALL
SELECT 'web_events',              COUNT(*)              FROM RAW.PUBLIC.WEB_EVENTS
ORDER BY table_name;

-- -------------------------------------------------------
-- 7. GRANT TRAINING_ROLE TO YOUR USER
--    Replace <YOUR_USERNAME> with each student's username.
-- -------------------------------------------------------
-- GRANT ROLE TRAINING_ROLE TO USER <YOUR_USERNAME>;

-- -------------------------------------------------------
-- Done! Students can now run:
--   USE ROLE TRAINING_ROLE;
--   USE WAREHOUSE TRAINING_WH;
--   USE DATABASE ANALYTICS;
-- -------------------------------------------------------
