-- ไฟล์ SQL สำหรับ Project 3 : Smart Mart

USE master;
GO
IF DB_ID('SmartMartDB') IS NOT NULL
BEGIN
    ALTER DATABASE SmartMartDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SmartMartDB;
END
GO
CREATE DATABASE SmartMartDB;
GO
USE SmartMartDB;
GO

-- 1. สร้างตาราง (18 ตาราง)

CREATE TABLE state (
    state_code CHAR(2) NOT NULL,
    state_name CHAR(15) NOT NULL,
    CONSTRAINT PK_state PRIMARY KEY (state_code)
);

CREATE TABLE in_store_payment_type (
    in_store_payment_type_code INT NOT NULL,
    in_store_payment_type_text CHAR(10) NOT NULL,
    CONSTRAINT PK_in_store_payment_type PRIMARY KEY (in_store_payment_type_code)
);

CREATE TABLE store (
    store_numb INT NOT NULL,
    store_street CHAR(50) NOT NULL,
    store_city CHAR(50) NOT NULL,
    store_state_code CHAR(2) NOT NULL,
    store_zip CHAR(10) NOT NULL,
    store_main_phone CHAR(12) NOT NULL,
    store_manager_id INT NULL,
    CONSTRAINT PK_store PRIMARY KEY (store_numb),
    CONSTRAINT FK_store_state FOREIGN KEY (store_state_code) REFERENCES state (state_code)
);

CREATE TABLE department (
    dept_numb INT NOT NULL,
    store_numb INT NOT NULL,
    dept_manager_id INT NULL,
    CONSTRAINT PK_department PRIMARY KEY (dept_numb, store_numb),
    CONSTRAINT FK_department_store FOREIGN KEY (store_numb) REFERENCES store (store_numb)
);

CREATE TABLE employee (
    employee_id INT NOT NULL,
    employee_first_name VARCHAR(15) NOT NULL,
    employee_last_name VARCHAR(50) NOT NULL,
    employee_street VARCHAR(50) NOT NULL,
    employee_city VARCHAR(50) NOT NULL,
    employee_state_code CHAR(2) NOT NULL,
    employee_zip CHAR(10) NOT NULL,
    employee_phone CHAR(12) NOT NULL,
    employee_ssn CHAR(11) NOT NULL,
    employee_birth_date DATE NOT NULL,
    dept_numb INT NULL,
    store_numb INT NULL,
    supervisor_id INT NULL,
    pay_type_code INT NOT NULL,
    pay_rate DECIMAL(10, 2) NOT NULL,
    CONSTRAINT PK_employee PRIMARY KEY (employee_id),
    CONSTRAINT FK_employee_department FOREIGN KEY (dept_numb, store_numb) REFERENCES department (dept_numb, store_numb),
    CONSTRAINT FK_employee_supervisor FOREIGN KEY (supervisor_id) REFERENCES employee (employee_id),
    CONSTRAINT FK_employee_state FOREIGN KEY (employee_state_code) REFERENCES state (state_code)
);

ALTER TABLE store ADD CONSTRAINT FK_store_manager FOREIGN KEY (store_manager_id) REFERENCES employee (employee_id);
ALTER TABLE department ADD CONSTRAINT FK_department_manager FOREIGN KEY (dept_manager_id) REFERENCES employee (employee_id);

CREATE TABLE warehouse (
    warehouse_numb INT NOT NULL,
    warehouse_street CHAR(50) NOT NULL,
    warehouse_city CHAR(50) NOT NULL,
    warehouse_state_code CHAR(2) NOT NULL,
    warehouse_zip CHAR(10) NOT NULL,
    warehouse_phone CHAR(12) NOT NULL,
    warehouse_manager_id INT NULL,
    CONSTRAINT PK_warehouse PRIMARY KEY (warehouse_numb),
    CONSTRAINT FK_warehouse_state FOREIGN KEY (warehouse_state_code) REFERENCES state (state_code),
    CONSTRAINT FK_warehouse_manager FOREIGN KEY (warehouse_manager_id) REFERENCES employee (employee_id)
);

CREATE TABLE product (
    UPC CHAR(15) NOT NULL,
    product_name VARCHAR(256) NOT NULL,
    product_unit CHAR(10) NOT NULL,
    shipping_weight INT NOT NULL,
    product_image VARBINARY(MAX) NULL,
    web_orderable BIT NOT NULL,
    CONSTRAINT PK_product PRIMARY KEY (UPC)
);

CREATE TABLE sales_promotion (
    UPC CHAR(15) NOT NULL,
    promotion_start_date DATE NOT NULL,
    promotion_end_date DATE NOT NULL,
    promotion_type_code INT NOT NULL,
    promotion_details CHAR(50) NULL,
    CONSTRAINT PK_sales_promotion PRIMARY KEY (UPC, promotion_start_date),
    CONSTRAINT FK_sales_promotion_product FOREIGN KEY (UPC) REFERENCES product (UPC)
);

CREATE TABLE product_stocked (
    SKU CHAR(15) NOT NULL,
    UPC CHAR(15) NOT NULL,
    in_store BIT NOT NULL,
    store_numb INT NULL,
    dept_numb INT NULL,
    warehouse_numb INT NULL,
    size CHAR(10) NULL,
    color CHAR(15) NULL,
    number_on_hand INT NOT NULL,
    retail_price DECIMAL(7, 2) NOT NULL,
    CONSTRAINT PK_product_stocked PRIMARY KEY (SKU),
    CONSTRAINT FK_product_stocked_product FOREIGN KEY (UPC) REFERENCES product (UPC),
    CONSTRAINT FK_product_stocked_department FOREIGN KEY (dept_numb, store_numb) REFERENCES department (dept_numb, store_numb),
    CONSTRAINT FK_product_stocked_warehouse FOREIGN KEY (warehouse_numb) REFERENCES warehouse (warehouse_numb),
    CONSTRAINT CHK_product_stocked_xor_location CHECK (
        (in_store = 1 AND store_numb IS NOT NULL AND dept_numb IS NOT NULL AND warehouse_numb IS NULL)
        OR
        (in_store = 0 AND warehouse_numb IS NOT NULL AND store_numb IS NULL AND dept_numb IS NULL)
    )
);

CREATE TABLE in_store_sale (
    in_store_transaction_numb INT NOT NULL,
    in_store_transaction_date DATE NOT NULL,
    in_store_sale_product_total DECIMAL(8, 2) NOT NULL,
    in_store_sales_tax DECIMAL(6, 2) NOT NULL,
    in_store_sale_total DECIMAL(9, 2) NOT NULL,
    in_store_sale_payment_type_code INT NOT NULL,
    CONSTRAINT PK_in_store_sale PRIMARY KEY (in_store_transaction_numb),
    CONSTRAINT FK_in_store_sale_payment_type FOREIGN KEY (in_store_sale_payment_type_code)
        REFERENCES in_store_payment_type (in_store_payment_type_code)
);

CREATE TABLE credit_sale_details (
    in_store_transaction_numb INT NOT NULL,
    in_store_sale_credit_card_numb CHAR(16) NOT NULL,
    in_store_sale_credit_card_exp_date DATE NOT NULL,
    in_store_sale_name_on_credit_card VARCHAR(50) NOT NULL,
    CONSTRAINT PK_credit_sale_details PRIMARY KEY (in_store_transaction_numb),
    CONSTRAINT FK_credit_sale_details_sale FOREIGN KEY (in_store_transaction_numb)
        REFERENCES in_store_sale (in_store_transaction_numb)
);

CREATE TABLE in_store_sale_item (
    in_store_transaction_numb INT NOT NULL,
    in_store_SKU CHAR(15) NOT NULL,
    in_store_quantity INT NOT NULL,
    in_store_price DECIMAL(7, 2) NOT NULL,
    CONSTRAINT PK_in_store_sale_item PRIMARY KEY (in_store_transaction_numb, in_store_SKU),
    CONSTRAINT FK_in_store_item_sale FOREIGN KEY (in_store_transaction_numb)
        REFERENCES in_store_sale (in_store_transaction_numb),
    CONSTRAINT FK_in_store_item_sku FOREIGN KEY (in_store_SKU)
        REFERENCES product_stocked (SKU)
);

CREATE TABLE web_customer (
    web_customer_numb INT NOT NULL,
    web_customer_first_name CHAR(15) NOT NULL,
    web_customer_last_name VARCHAR(50) NOT NULL,
    web_customer_phone CHAR(12) NOT NULL,
    web_customer_password CHAR(15) NOT NULL,
    web_customer_user_id CHAR(15) NOT NULL,
    CONSTRAINT PK_web_customer PRIMARY KEY (web_customer_numb)
);

CREATE TABLE web_customer_credit_card (
    web_customer_numb INT NOT NULL,
    web_credit_card_numb CHAR(16) NOT NULL,
    web_credit_card_exp_date DATE NOT NULL,
    web_sale_name_on_credit_card VARCHAR(50) NOT NULL,
    CONSTRAINT PK_web_customer_credit_card PRIMARY KEY (web_customer_numb, web_credit_card_numb),
    CONSTRAINT FK_web_cc_customer FOREIGN KEY (web_customer_numb) REFERENCES web_customer (web_customer_numb)
);

CREATE TABLE web_sale_shipping_address (
    web_shipping_address_numb INT NOT NULL,
    web_customer_numb INT NOT NULL,
    web_shipping_street CHAR(50) NOT NULL,
    web_customer_shipping_city CHAR(50) NOT NULL,
    web_customer_shipping_state_code CHAR(2) NOT NULL,
    web_customer_shipping_zip CHAR(10) NOT NULL,
    web_customer_shipping_first_name CHAR(15) NOT NULL,
    web_customer_shipping_last_name CHAR(15) NOT NULL,
    CONSTRAINT PK_web_sale_shipping_address PRIMARY KEY (web_shipping_address_numb),
    CONSTRAINT FK_web_addr_customer FOREIGN KEY (web_customer_numb) REFERENCES web_customer (web_customer_numb),
    CONSTRAINT FK_web_addr_state FOREIGN KEY (web_customer_shipping_state_code) REFERENCES state (state_code)
);

CREATE TABLE web_sale (
    web_sale_numb INT NOT NULL,
    web_sale_date DATE NOT NULL,
    web_customer_numb INT NOT NULL,
    web_credit_card_numb CHAR(16) NOT NULL,
    web_sale_total DECIMAL(8, 2) NOT NULL,
    web_sale_merchandise_total DECIMAL(7, 2) NOT NULL,
    web_sale_shipping DECIMAL(6, 2) NOT NULL,
    web_sale_tax DECIMAL(6, 2) NOT NULL,
    CONSTRAINT PK_web_sale PRIMARY KEY (web_sale_numb),
    CONSTRAINT FK_web_sale_customer FOREIGN KEY (web_customer_numb) REFERENCES web_customer (web_customer_numb),
    CONSTRAINT FK_web_sale_credit_card FOREIGN KEY (web_customer_numb, web_credit_card_numb)
        REFERENCES web_customer_credit_card (web_customer_numb, web_credit_card_numb)
);

CREATE TABLE web_sale_shipment (
    web_sale_numb INT NOT NULL,
    web_sale_date_shipped DATETIME2 NOT NULL,
    web_shipment_merchandise_total DECIMAL(7, 2) NOT NULL,
    web_shipment_tax DECIMAL(6, 2) NOT NULL,
    web_shipment_shipping DECIMAL(6, 2) NOT NULL,
    web_shipment_total_charged DECIMAL(8, 2) NOT NULL,
    CONSTRAINT PK_web_sale_shipment PRIMARY KEY (web_sale_numb, web_sale_date_shipped),
    CONSTRAINT FK_web_shipment_sale FOREIGN KEY (web_sale_numb) REFERENCES web_sale (web_sale_numb)
);

CREATE TABLE web_sale_item (
    web_sale_numb INT NOT NULL,
    web_sale_SKU CHAR(15) NOT NULL,
    web_sale_quantity INT NOT NULL,
    web_sale_shipped BIT NOT NULL DEFAULT 0,
    web_sale_price DECIMAL(6, 2) NOT NULL,
    web_shipping_address_numb INT NULL,
    web_sale_date_shipped DATETIME2 NULL,
    CONSTRAINT PK_web_sale_item PRIMARY KEY (web_sale_numb, web_sale_SKU),
    CONSTRAINT FK_web_item_sku FOREIGN KEY (web_sale_SKU) REFERENCES product_stocked (SKU),
    CONSTRAINT FK_web_item_sale FOREIGN KEY (web_sale_numb) REFERENCES web_sale (web_sale_numb),
    CONSTRAINT FK_web_item_address FOREIGN KEY (web_shipping_address_numb)
        REFERENCES web_sale_shipping_address (web_shipping_address_numb),
    CONSTRAINT FK_web_item_shipment FOREIGN KEY (web_sale_numb, web_sale_date_shipped)
        REFERENCES web_sale_shipment (web_sale_numb, web_sale_date_shipped)
);
GO

-- 2. ข้อมูลตัวอย่าง (Sample Data)

INSERT INTO state VALUES ('CA', 'California'), ('NY', 'New York');
INSERT INTO in_store_payment_type VALUES (1, 'Cash'), (2, 'CreditCard');

INSERT INTO store VALUES (101, '100 Market St', 'San Francisco', 'CA', '94103', '415-555-0101', NULL);
INSERT INTO department VALUES (10, 101, NULL);
INSERT INTO warehouse VALUES (201, '500 Logistics Way', 'Oakland', 'CA', '94607', '510-555-0201', NULL);

INSERT INTO employee VALUES
(1001, 'Alice', 'Walker', '12 Pine St', 'San Francisco', 'CA', '94101', '415-555-1001', '111-11-1111', '1985-05-14', 10, 101, NULL, 1, 60000.00),
(1002, 'Bob', 'Miller', '45 Oak Rd', 'San Francisco', 'CA', '94102', '415-555-1002', '222-22-2222', '1995-08-20', 10, 101, 1001, 2, 20.00);

UPDATE store SET store_manager_id = 1001 WHERE store_numb = 101;
UPDATE department SET dept_manager_id = 1001 WHERE dept_numb = 10 AND store_numb = 101;

INSERT INTO product VALUES ('UPC000000000001', 'Smart Watch', 'Piece', 1, NULL, 1);
INSERT INTO sales_promotion VALUES ('UPC000000000001', '2026-01-01', '2026-12-31', 10, 'Discount 20%');

INSERT INTO product_stocked VALUES
('SKU-STORE-00001', 'UPC000000000001', 1, 101, 10, NULL, 'M', 'Black', 50, 200.00),
('SKU-WHSE-000001', 'UPC000000000001', 0, NULL, NULL, 201, 'M', 'Black', 100, 200.00);

INSERT INTO in_store_sale VALUES (5001, DATEADD(DAY, -5, CAST(GETDATE() AS DATE)), 400.00, 0.00, 400.00, 2);
INSERT INTO credit_sale_details VALUES (5001, '4111222233334444', '2028-12-31', 'JOHN DOE');
INSERT INTO in_store_sale_item VALUES (5001, 'SKU-STORE-00001', 2, 200.00);

INSERT INTO web_customer VALUES (3001, 'Michael', 'Johnson', '415-555-3001', 'pass1234', 'mjohnson');
INSERT INTO web_customer_credit_card VALUES (3001, '4999888877776666', '2029-09-30', 'MICHAEL JOHNSON');
INSERT INTO web_sale_shipping_address VALUES (4001, 3001, '742 Evergreen St', 'San Francisco', 'CA', '94107', 'Michael', 'Johnson');
INSERT INTO web_sale VALUES (6001, CAST(GETDATE() AS DATE), 3001, '4999888877776666', 229.50, 200.00, 15.00, 14.50);
INSERT INTO web_sale_item VALUES (6001, 'SKU-WHSE-000001', 1, 0, 200.00, 4001, NULL);
GO

-- 3. สร้าง Views (ข้อ 2.3)

CREATE VIEW dbo.vw_Web_Product_Promo
AS
SELECT 
    p.UPC, p.product_name, p.product_unit, p.shipping_weight,
    ps.SKU, ps.size, ps.color, ps.retail_price, ps.number_on_hand,
    sp.promotion_start_date, sp.promotion_end_date, sp.promotion_details
FROM dbo.product p
JOIN dbo.product_stocked ps ON p.UPC = ps.UPC
LEFT JOIN dbo.sales_promotion sp ON p.UPC = sp.UPC
WHERE p.web_orderable = 1 AND ps.in_store = 0;
GO

CREATE VIEW dbo.vw_Safe_Web_Shipping_Address
AS
SELECT 
    ws.web_sale_numb, ws.web_sale_date, ws.web_customer_numb,
    'XXXX-XXXX-XXXX-' + RIGHT(ws.web_credit_card_numb, 4) AS masked_credit_card_numb,
    ws.web_sale_total, wsi.web_sale_SKU, wsi.web_sale_quantity,
    wsi.web_sale_shipped, wsi.web_sale_date_shipped,
    wsa.web_customer_shipping_state_code, wsa.web_customer_shipping_zip
FROM dbo.web_sale ws
JOIN dbo.web_sale_item wsi ON ws.web_sale_numb = wsi.web_sale_numb
LEFT JOIN dbo.web_sale_shipping_address wsa
    ON wsi.web_shipping_address_numb = wsa.web_shipping_address_numb;
GO

SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
GO

CREATE VIEW dbo.vw_Materialized_Available_Inventory
WITH SCHEMABINDING
AS
SELECT 
    ps.UPC, p.product_name, ps.in_store,
    SUM(ISNULL(ps.number_on_hand, 0)) AS total_available_qty,
    COUNT_BIG(*) AS stocked_sku_count
FROM dbo.product_stocked ps
JOIN dbo.product p ON ps.UPC = p.UPC
GROUP BY ps.UPC, p.product_name, ps.in_store;
GO

CREATE UNIQUE CLUSTERED INDEX IDX_Materialized_Available_Inventory
ON dbo.vw_Materialized_Available_Inventory (UPC, in_store);
GO

-- 4. สร้าง Non-Clustered Indexes (ข้อ 2.4)

CREATE NONCLUSTERED INDEX IX_ProductStocked_UPC_Location
ON dbo.product_stocked (UPC, in_store, number_on_hand)
INCLUDE (SKU, store_numb, dept_numb, warehouse_numb, retail_price);

CREATE NONCLUSTERED INDEX IX_InStoreSale_TransactionDate
ON dbo.in_store_sale (in_store_transaction_date)
INCLUDE (in_store_sale_total, in_store_sale_payment_type_code);

CREATE NONCLUSTERED INDEX IX_WebSaleItem_ShippedStatus
ON dbo.web_sale_item (web_sale_numb, web_sale_shipped)
INCLUDE (web_sale_SKU, web_shipping_address_numb, web_sale_date_shipped);
GO

-- 5. สร้าง Logins, Users, Roles และกำหนดสิทธิ์ (ข้อ 2.2)

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'Login_Supervisor')
    CREATE LOGIN Login_Supervisor WITH PASSWORD = 'Password_Sup_2026!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'Login_Manager')
    CREATE LOGIN Login_Manager WITH PASSWORD = 'Password_Mgr_2026!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'Login_Staff')
    CREATE LOGIN Login_Staff WITH PASSWORD = 'Password_Stf_2026!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'Login_HR')
    CREATE LOGIN Login_HR WITH PASSWORD = 'Password_HR_2026!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'Login_Admin')
    CREATE LOGIN Login_Admin WITH PASSWORD = 'Password_Adm_2026!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'Login_InStore_Sale_App')
    CREATE LOGIN Login_InStore_Sale_App WITH PASSWORD = 'Password_InStoreApp_2026!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'Login_Web_Sale_App')
    CREATE LOGIN Login_Web_Sale_App WITH PASSWORD = 'Password_WebSaleApp_2026!', CHECK_POLICY = OFF;
GO

CREATE USER User_Supervisor FOR LOGIN Login_Supervisor;
CREATE USER User_Manager FOR LOGIN Login_Manager;
CREATE USER User_Staff FOR LOGIN Login_Staff;
CREATE USER User_HR FOR LOGIN Login_HR;
CREATE USER User_Admin FOR LOGIN Login_Admin;
CREATE USER User_InStore_Sale_App FOR LOGIN Login_InStore_Sale_App;
CREATE USER User_Web_Sale_App FOR LOGIN Login_Web_Sale_App;
GO

CREATE ROLE Role_Supervisor;
CREATE ROLE Role_Manager;
CREATE ROLE Role_Staff;
CREATE ROLE Role_HR;
CREATE ROLE Role_Admin;
CREATE ROLE Role_InStore_Sale_App;
CREATE ROLE Role_Web_Sale_App;
GO

ALTER ROLE Role_Supervisor ADD MEMBER User_Supervisor;
ALTER ROLE Role_Manager ADD MEMBER User_Manager;
ALTER ROLE Role_Staff ADD MEMBER User_Staff;
ALTER ROLE Role_HR ADD MEMBER User_HR;
ALTER ROLE Role_Admin ADD MEMBER User_Admin;
ALTER ROLE Role_InStore_Sale_App ADD MEMBER User_InStore_Sale_App;
ALTER ROLE Role_Web_Sale_App ADD MEMBER User_Web_Sale_App;
GO

-- HR: ดูและแก้ไขได้เฉพาะตาราง employee
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.employee TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.product TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.product_stocked TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.in_store_sale TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.web_sale TO Role_HR;

-- Admin: จัดการโครงสร้างตารางและสำรองข้อมูล
ALTER ROLE db_ddladmin ADD MEMBER User_Admin;
ALTER ROLE db_backupoperator ADD MEMBER User_Admin;
GRANT BACKUP DATABASE TO Role_Admin;

-- Supervisor, Manager, Staff
GRANT SELECT ON dbo.product TO Role_Supervisor;
GRANT SELECT, UPDATE ON dbo.product_stocked TO Role_Supervisor;
GRANT SELECT, INSERT, UPDATE ON dbo.in_store_sale TO Role_Supervisor;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.in_store_sale_item TO Role_Supervisor;
GRANT SELECT ON dbo.vw_Safe_Web_Shipping_Address TO Role_Supervisor;
GRANT SELECT ON dbo.vw_Materialized_Available_Inventory TO Role_Supervisor;
DENY SELECT ON dbo.employee TO Role_Supervisor;

GRANT SELECT ON dbo.store TO Role_Manager;
GRANT SELECT ON dbo.department TO Role_Manager;
GRANT SELECT ON dbo.warehouse TO Role_Manager;
GRANT SELECT, INSERT, UPDATE ON dbo.product TO Role_Manager;
GRANT SELECT, INSERT, UPDATE ON dbo.product_stocked TO Role_Manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.sales_promotion TO Role_Manager;
GRANT SELECT, INSERT, UPDATE ON dbo.web_sale_shipment TO Role_Manager;
GRANT SELECT, UPDATE ON dbo.web_sale_item TO Role_Manager;
GRANT SELECT, UPDATE ON dbo.web_sale_shipping_address TO Role_Manager;
GRANT SELECT ON dbo.vw_Safe_Web_Shipping_Address TO Role_Manager;
GRANT SELECT ON dbo.vw_Materialized_Available_Inventory TO Role_Manager;
DENY SELECT ON dbo.employee TO Role_Manager;
DENY SELECT ON dbo.credit_sale_details TO Role_Manager;
DENY SELECT ON dbo.web_customer_credit_card TO Role_Manager;

GRANT SELECT ON dbo.product TO Role_Staff;
GRANT SELECT ON dbo.sales_promotion TO Role_Staff;
GRANT SELECT ON dbo.store TO Role_Staff;
GRANT SELECT ON dbo.warehouse TO Role_Staff;
GRANT SELECT, UPDATE ON dbo.product_stocked TO Role_Staff;
GRANT SELECT, INSERT ON dbo.in_store_sale TO Role_Staff;
GRANT SELECT, INSERT ON dbo.in_store_sale_item TO Role_Staff;
GRANT SELECT ON dbo.vw_Materialized_Available_Inventory TO Role_Staff;
DENY SELECT ON dbo.employee TO Role_Staff;
DENY SELECT ON dbo.credit_sale_details TO Role_Staff;

-- In-store Sale App & Web Sale App
GRANT SELECT ON dbo.product TO Role_InStore_Sale_App;
GRANT SELECT ON dbo.sales_promotion TO Role_InStore_Sale_App;
GRANT SELECT ON dbo.in_store_payment_type TO Role_InStore_Sale_App;
GRANT SELECT, UPDATE ON dbo.product_stocked TO Role_InStore_Sale_App;
GRANT SELECT, INSERT, UPDATE ON dbo.in_store_sale TO Role_InStore_Sale_App;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.in_store_sale_item TO Role_InStore_Sale_App;
GRANT INSERT ON dbo.credit_sale_details TO Role_InStore_Sale_App;
GRANT SELECT ON dbo.vw_Materialized_Available_Inventory TO Role_InStore_Sale_App;
DENY SELECT ON dbo.employee TO Role_InStore_Sale_App;
DENY SELECT ON dbo.web_sale TO Role_InStore_Sale_App;

GRANT SELECT ON dbo.product TO Role_Web_Sale_App;
GRANT SELECT ON dbo.sales_promotion TO Role_Web_Sale_App;
GRANT SELECT, UPDATE ON dbo.product_stocked TO Role_Web_Sale_App;
GRANT SELECT, INSERT, UPDATE ON dbo.web_customer TO Role_Web_Sale_App;
GRANT SELECT, INSERT ON dbo.web_customer_credit_card TO Role_Web_Sale_App;
GRANT SELECT, INSERT, UPDATE ON dbo.web_sale_shipping_address TO Role_Web_Sale_App;
GRANT SELECT, INSERT, UPDATE ON dbo.web_sale TO Role_Web_Sale_App;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.web_sale_item TO Role_Web_Sale_App;
GRANT SELECT ON dbo.vw_Web_Product_Promo TO Role_Web_Sale_App;
GRANT SELECT ON dbo.vw_Materialized_Available_Inventory TO Role_Web_Sale_App;
DENY SELECT ON dbo.employee TO Role_Web_Sale_App;
DENY SELECT ON dbo.store TO Role_Web_Sale_App;
DENY SELECT ON dbo.department TO Role_Web_Sale_App;
DENY SELECT ON dbo.in_store_sale TO Role_Web_Sale_App;
DENY SELECT ON dbo.credit_sale_details TO Role_Web_Sale_App;
GO

-- ============================================================================
-- 6. คำสั่ง SQL Queries (ข้อ 1.4) — เรียงตาม Transaction 1 ถึง 8
-- คำชี้แจง: ส่วนบน (ข้อ 1–5) คือ Main Core ที่สร้างตาราง ข้อมูล Views Indexes
--           และ Roles/Logins ไว้ให้ครบแล้ว ให้แต่ละคนเขียน SQL ของตัวเองลงในช่องด้านล่าง
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Transaction 1 [Art]: การคืนสินค้าที่ซื้อภายใน 15 วัน (SQL + Java)
-- Login: Login_Supervisor | Index: IX_InStoreSale_TransactionDate
-- ----------------------------------------------------------------------------
-- [1.4.3] ตรวจสอบประวัติการซื้อสินค้าภายใน 15 วัน (SELECT)
--   • ตารางที่ใช้: dbo.in_store_sale (s) JOIN dbo.in_store_sale_item (i)
--   • เงื่อนไข: ค้นหาใบเสร็จหมายเลข 5001 และสินค้า SKU = 'SKU-STORE-00001'
--   • กฎธุรกิจ: DATEDIFF(DAY, s.in_store_transaction_date, CAST(GETDATE() AS DATE)) <= 15
-- TODO (Art): เขียนคำสั่ง SELECT 1.4.3 ด้านล่างนี้


-- [1.4.11] คืนสต็อกหน้าร้านและลดยอดบิล (UPDATE 3 ขั้นตอน)
--   • ขั้นที่ 1: UPDATE dbo.product_stocked เพิ่ม number_on_hand + 1 (SKU = 'SKU-STORE-00001', in_store = 1)
--   • ขั้นที่ 2: UPDATE dbo.in_store_sale_item ลด in_store_quantity - 1 (บิล 5001, SKU = 'SKU-STORE-00001')
--   • ขั้นที่ 3: UPDATE dbo.in_store_sale หักยอด in_store_sale_product_total และ in_store_sale_total ลง 200.00 (บิล 5001)
-- TODO (Art): เขียนคำสั่ง UPDATE 1.4.11 ด้านล่างนี้


-- [1.4.15] ลบรายการสินค้าในบิลเมื่อคืนครบจำนวน (DELETE)
--   • ตารางที่ใช้: dbo.in_store_sale_item
--   • เงื่อนไข: ลบแถวของ in_store_transaction_numb = 5001 และ in_store_SKU = 'SKU-STORE-00001'
-- TODO (Art): เขียนคำสั่ง DELETE 1.4.15 ด้านล่างนี้


-- ----------------------------------------------------------------------------
-- Transaction 2 [Bam]: การสั่งซื้อสินค้าแบบจ่ายด้วยเครดิตการ์ด (SQL + Java)
-- Login: Login_InStore_Sale_App
-- ----------------------------------------------------------------------------
-- [1.4.6] เพิ่มใบเสร็จขายหน้าร้าน รายการสินค้า และข้อมูลบัตรเครดิต (INSERT 3 ตาราง)
--   • ขั้นที่ 1: INSERT ลง dbo.in_store_sale (บิล 5002, วันที่วันนี้, ค่าสินค้า 200.00, ภาษี 14.50, ยอดรวม 214.50, payment_type = 2)
--   • ขั้นที่ 2: INSERT ลง dbo.in_store_sale_item (บิล 5002, 'SKU-STORE-00001', จำนวน 1, ราคา 200.00)
--   • ขั้นที่ 3: INSERT ลง dbo.credit_sale_details (บิล 5002, เลขบัตร '4111222233339999', หมดอายุ '2029-12-31', ชื่อ 'SOMCHAI JAIDEE')
-- TODO (Bam): เขียนคำสั่ง INSERT 1.4.6 ด้านล่างนี้


-- [1.4.10] ตัดสต็อกหน้าร้าน (UPDATE)
--   • ตารางที่ใช้: dbo.product_stocked
--   • เงื่อนไข: ลด number_on_hand - 1 เฉพาะ SKU = 'SKU-STORE-00001' ที่อยู่หน้าร้าน (in_store = 1) และ number_on_hand >= 1
-- TODO (Bam): เขียนคำสั่ง UPDATE 1.4.10 ด้านล่างนี้


-- ----------------------------------------------------------------------------
-- Transaction 3 [Dream]: การค้นหาสินค้าที่พร้อมจำหน่ายว่าอยู่ที่ Stores หรือ Warehouses ไหน (SQL + Java)
-- Login: Login_Staff | Index: IX_ProductStocked_UPC_Location
-- ----------------------------------------------------------------------------
-- [1.4.1] ค้นหาสินค้าที่พร้อมจำหน่ายตามสาขาและคลังสินค้า (SELECT)
--   • ตารางที่ใช้: dbo.product (p) JOIN dbo.product_stocked (ps)
--                 LEFT JOIN dbo.store (s) และ LEFT JOIN dbo.warehouse (w)
--   • เงื่อนไข: ps.number_on_hand > 0 AND p.UPC = 'UPC000000000001'
--   • ข้อมูลที่ต้องดึง: UPC, ชื่อสินค้า, SKU, in_store, รหัส/เมือง/รัฐของสาขาและคลัง, number_on_hand, retail_price
-- TODO (Dream): เขียนคำสั่ง SELECT 1.4.1 ด้านล่างนี้


-- ----------------------------------------------------------------------------
-- Transaction 4 [Path]: การอัปเดตสถานะการจัดส่งพร้อมซ่อนที่อยู่จัดส่งของลูกค้า (SQL + Java)
-- Login: Login_Manager | Index: IX_WebSaleItem_ShippedStatus
-- ----------------------------------------------------------------------------
-- [1.4.7] เพิ่มรอบจัดส่งสินค้าเว็บ (INSERT)
--   • ตารางที่ใช้: dbo.web_sale_shipment
--   • ตัวอย่าง: บิล 6001, เวลาจัดส่ง SYSDATETIME(), ค่าสินค้า 200.00, ภาษี 14.50, ค่าส่ง 15.00, ยอดชาร์จรวม 229.50
-- TODO (Path): เขียนคำสั่ง INSERT 1.4.7 ด้านล่างนี้


-- [1.4.12] อัปเดตสถานะส่งของเว็บและซ่อนที่อยู่ลูกค้า (UPDATE 2 ตาราง)
--   • ขั้นที่ 1: UPDATE dbo.web_sale_item ตั้ง web_sale_shipped = 1, web_sale_date_shipped = SYSDATETIME()
--              ของ web_sale_numb = 6001 และ web_sale_SKU = 'SKU-WHSE-000001'
--   • ขั้นที่ 2: UPDATE dbo.web_sale_shipping_address เปลี่ยน web_shipping_street = '*** MASKED ***'
--              ของ web_shipping_address_numb = 4001 (คง city, state_code, zip ไว้)
-- TODO (Path): เขียนคำสั่ง UPDATE 1.4.12 ด้านล่างนี้


-- ----------------------------------------------------------------------------
-- Transaction 5 [Dream]: การดึงข้อมูลสินค้าและโปรโมชั่นลดราคาสำหรับแสดงผลบนระบบขายออนไลน์ (SQL + View)
-- Login: Login_Web_Sale_App | View: dbo.vw_Web_Product_Promo
-- ----------------------------------------------------------------------------
-- [1.4.2] ดึงข้อมูลสินค้าและโปรโมชั่นสำหรับระบบขายออนไลน์ (SELECT)
--   • ตารางที่ใช้: dbo.product (p) JOIN dbo.product_stocked (ps)
--                 LEFT JOIN dbo.sales_promotion (sp) โดยเช็กช่วงวันที่โปรโมชั่นที่ยังมีผลวันนี้ (CAST(GETDATE() AS DATE) BETWEEN ...)
--   • เงื่อนไข: p.web_orderable = 1 AND ps.in_store = 0 AND ps.number_on_hand > 0
--   • หมายเหตุ: สามารถเรียกดูผ่าน View dbo.vw_Web_Product_Promo ได้ด้วย
-- TODO (Dream): เขียนคำสั่ง SELECT 1.4.2 ด้านล่างนี้


-- ----------------------------------------------------------------------------
-- Transaction 6 [Art]: การสั่งซื้อสินค้าออนไลน์ผ่านเว็บไซต์ด้วยบัตรเครดิต (SQL)
-- Login: Login_Web_Sale_App
-- ----------------------------------------------------------------------------
-- [1.4.8] เพิ่มคำสั่งซื้อออนไลน์ผ่านเว็บ (INSERT 2 ตาราง)
--   • ขั้นที่ 1: INSERT ลง dbo.web_sale (บิล 6002, วันที่วันนี้, ลูกค้า 3001, บัตร '4999888877776666',
--              ยอดรวม 229.50, ค่าสินค้า 200.00, ค่าส่ง 15.00, ภาษี 14.50)
--   • ขั้นที่ 2: INSERT ลง dbo.web_sale_item (บิล 6002, SKU 'SKU-WHSE-000001', จำนวน 1,
--              web_sale_shipped = 0, ราคา 200.00, ที่อยู่ 4001, web_sale_date_shipped = NULL)
-- TODO (Art): เขียนคำสั่ง INSERT 1.4.8 ด้านล่างนี้


-- [1.4.13] ตัดสต็อกคลังออนไลน์ (UPDATE)
--   • ตารางที่ใช้: dbo.product_stocked
--   • เงื่อนไข: ลด number_on_hand - 1 เฉพาะ SKU = 'SKU-WHSE-000001' ที่อยู่ในคลัง (in_store = 0) และมีสต็อก >= 1
-- TODO (Art): เขียนคำสั่ง UPDATE 1.4.13 ด้านล่างนี้


-- ----------------------------------------------------------------------------
-- Transaction 7 [Path]: การตรวจสอบรายการสั่งซื้อออนไลน์และสถานะจัดส่งแบบปกป้องข้อมูลบัตรและที่อยู่ (SQL + View)
-- Login: Login_Manager | View: dbo.vw_Safe_Web_Shipping_Address
-- ----------------------------------------------------------------------------
-- [1.4.4] ดูรายการสั่งซื้อเว็บผ่าน View ที่ซ่อนเลขบัตรเครดิตและที่อยู่ (SELECT จาก View)
--   • View ที่ใช้: dbo.vw_Safe_Web_Shipping_Address
--   • เงื่อนไข: WHERE web_sale_numb = 6001
--   • จุดสังเกต: ต้องเห็น masked_credit_card_numb เป็น 'XXXX-XXXX-XXXX-6666' และเห็นเฉพาะ state/zip
-- TODO (Path): เขียนคำสั่ง SELECT 1.4.4 ด้านล่างนี้


-- ----------------------------------------------------------------------------
-- Transaction 8 [Bam]: การจัดการและตรวจสอบข้อมูลประวัติและอัตราค่าจ้างของพนักงานฝ่าย HR (SQL + Role)
-- Login: Login_HR | Role: Role_HR (ดู/จัดการได้เฉพาะตาราง employee เท่านั้น)
-- ----------------------------------------------------------------------------
-- [1.4.5] ดูข้อมูลพนักงานฝ่าย HR (SELECT)
--   • ตารางที่ใช้: dbo.employee
--   • ข้อมูลที่ต้องดึง: employee_id, ชื่อ-นามสกุล, dept_numb, store_numb, supervisor_id, pay_type_code, pay_rate
-- TODO (Bam): เขียนคำสั่ง SELECT 1.4.5 ด้านล่างนี้


-- [1.4.9] เพิ่มพนักงานใหม่ฝ่าย HR (INSERT)
--   • ตารางที่ใช้: dbo.employee
--   • ตัวอย่าง: เพิ่มพนักงานรหัส 1003 (Charlie Davis, แผนก 10, สาขา 101, หัวหน้า 1001, pay_type 2, pay_rate 22.00)
-- TODO (Bam): เขียนคำสั่ง INSERT 1.4.9 ด้านล่างนี้


-- [1.4.14] อัปเดตแผนกและเงินเดือนพนักงานฝ่าย HR (UPDATE)
--   • ตารางที่ใช้: dbo.employee
--   • เงื่อนไข: อัปเดต dept_numb, store_numb และ pay_rate ของพนักงานรหัส 1002
-- TODO (Bam): เขียนคำสั่ง UPDATE 1.4.14 ด้านล่างนี้
