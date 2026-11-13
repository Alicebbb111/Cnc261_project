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
-- 6. คำสั่ง SQL Queries (ข้อ 1.4) — เรียงตาม Transaction 1 ถึง 8 (ตรงกับไฟล์ของทีม)
-- หมายเหตุ: คำสั่ง INSERT / UPDATE / DELETE ถูกคอมเมนต์ (/* ... */) ไว้เพื่อไม่ให้กระทบข้อมูลตัวอย่างเมื่อรันไฟล์ทั้งหมด
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Transaction 1 [Art]: การคืนสินค้าที่ซื้อภายใน 15 วัน [มีใน Java]
-- ----------------------------------------------------------------------------
-- 1.4.3 ตรวจสอบประวัติการซื้อสินค้าภายใน 15 วัน
SELECT 
    s.in_store_transaction_numb, s.in_store_transaction_date,
    DATEDIFF(DAY, s.in_store_transaction_date, CAST(GETDATE() AS DATE)) AS days_since_purchase,
    i.in_store_SKU, i.in_store_quantity, i.in_store_price
FROM dbo.in_store_sale s
JOIN dbo.in_store_sale_item i ON s.in_store_transaction_numb = i.in_store_transaction_numb
WHERE s.in_store_transaction_numb = 5001
  AND i.in_store_SKU = 'SKU-STORE-00001'
  AND DATEDIFF(DAY, s.in_store_transaction_date, CAST(GETDATE() AS DATE)) <= 15;

/*
-- 1.4.11 คืนสต็อกหน้าร้านและลดยอดบิล
UPDATE dbo.product_stocked
SET number_on_hand = number_on_hand + 1
WHERE SKU = 'SKU-STORE-00001' AND in_store = 1;

UPDATE dbo.in_store_sale_item
SET in_store_quantity = in_store_quantity - 1
WHERE in_store_transaction_numb = 5001 AND in_store_SKU = 'SKU-STORE-00001';

UPDATE dbo.in_store_sale
SET in_store_sale_product_total = in_store_sale_product_total - 200.00,
    in_store_sale_total = in_store_sale_total - 200.00
WHERE in_store_transaction_numb = 5001;

-- 1.4.15 ลบรายการสินค้าในบิลเมื่อคืนครบจำนวน
DELETE FROM dbo.in_store_sale_item
WHERE in_store_transaction_numb = 5001 AND in_store_SKU = 'SKU-STORE-00001';
*/

-- ----------------------------------------------------------------------------
-- Transaction 2 [Bam]: การสั่งซื้อสินค้าแบบจ่ายด้วยเครดิตการ์ด [มีใน Java]
-- ----------------------------------------------------------------------------
/*
-- 1.4.6 เพิ่มใบเสร็จขายหน้าร้าน รายการสินค้า และบัตรเครดิต
INSERT INTO dbo.in_store_sale (
    in_store_transaction_numb, in_store_transaction_date,
    in_store_sale_product_total, in_store_sales_tax, in_store_sale_total, in_store_sale_payment_type_code
) VALUES (5002, CAST(GETDATE() AS DATE), 200.00, 14.50, 214.50, 2);

INSERT INTO dbo.in_store_sale_item (
    in_store_transaction_numb, in_store_SKU, in_store_quantity, in_store_price
) VALUES (5002, 'SKU-STORE-00001', 1, 200.00);

INSERT INTO dbo.credit_sale_details (
    in_store_transaction_numb, in_store_sale_credit_card_numb,
    in_store_sale_credit_card_exp_date, in_store_sale_name_on_credit_card
) VALUES (5002, '4111222233339999', '2029-12-31', 'SOMCHAI JAIDEE');

-- 1.4.10 ตัดสต็อกหน้าร้าน
UPDATE dbo.product_stocked
SET number_on_hand = number_on_hand - 1
WHERE SKU = 'SKU-STORE-00001' AND in_store = 1 AND number_on_hand >= 1;
*/

-- ----------------------------------------------------------------------------
-- Transaction 3 [Dream]: การค้นหาสินค้าที่พร้อมจำหน่ายว่าอยู่ที่ Stores หรือ Warehouses ไหน [มีใน Java]
-- ----------------------------------------------------------------------------
-- 1.4.1 ค้นหาสินค้าที่พร้อมจำหน่ายตามสาขาและคลังสินค้า
SELECT 
    p.UPC, p.product_name, ps.SKU, ps.in_store,
    ps.store_numb, ps.dept_numb, s.store_city, s.store_state_code,
    ps.warehouse_numb, w.warehouse_city, w.warehouse_state_code,
    ps.number_on_hand, ps.retail_price
FROM dbo.product p
JOIN dbo.product_stocked ps ON p.UPC = ps.UPC
LEFT JOIN dbo.store s ON ps.store_numb = s.store_numb
LEFT JOIN dbo.warehouse w ON ps.warehouse_numb = w.warehouse_numb
WHERE ps.number_on_hand > 0 AND p.UPC = 'UPC000000000001';

-- ----------------------------------------------------------------------------
-- Transaction 4 [Path]: การอัปเดตสถานะการจัดส่งพร้อมซ่อนที่อยู่จัดส่งของลูกค้า [มีใน Java]
-- ----------------------------------------------------------------------------
/*
-- 1.4.7 เพิ่มรอบจัดส่งสินค้าเว็บ
INSERT INTO dbo.web_sale_shipment (
    web_sale_numb, web_sale_date_shipped,
    web_shipment_merchandise_total, web_shipment_tax, web_shipment_shipping, web_shipment_total_charged
) VALUES (6001, SYSDATETIME(), 200.00, 14.50, 15.00, 229.50);

-- 1.4.12 อัปเดตสถานะส่งของเว็บและซ่อนที่อยู่เป็น '*** MASKED ***'
UPDATE dbo.web_sale_item
SET web_sale_shipped = 1, web_sale_date_shipped = SYSDATETIME()
WHERE web_sale_numb = 6001 AND web_sale_SKU = 'SKU-WHSE-000001';

UPDATE dbo.web_sale_shipping_address
SET web_shipping_street = '*** MASKED ***'
WHERE web_shipping_address_numb = 4001;
*/

-- ----------------------------------------------------------------------------
-- Transaction 5 [Dream]: การดึงข้อมูลสินค้าและโปรโมชั่นลดราคาสำหรับแสดงผลบนระบบขายออนไลน์
-- ----------------------------------------------------------------------------
-- 1.4.2 ดึงข้อมูลสินค้าและโปรโมชั่นสำหรับระบบขายออนไลน์
SELECT 
    p.UPC, p.product_name, ps.SKU, ps.retail_price, ps.number_on_hand,
    sp.promotion_start_date, sp.promotion_end_date, sp.promotion_details
FROM dbo.product p
JOIN dbo.product_stocked ps ON p.UPC = ps.UPC
LEFT JOIN dbo.sales_promotion sp ON p.UPC = sp.UPC
    AND CAST(GETDATE() AS DATE) BETWEEN sp.promotion_start_date AND sp.promotion_end_date
WHERE p.web_orderable = 1 AND ps.in_store = 0 AND ps.number_on_hand > 0;

-- ----------------------------------------------------------------------------
-- Transaction 6 [Art]: การสั่งซื้อสินค้าออนไลน์ผ่านเว็บไซต์ด้วยบัตรเครดิต
-- ----------------------------------------------------------------------------
/*
-- 1.4.8 เพิ่มคำสั่งซื้อออนไลน์ผ่านเว็บ
INSERT INTO dbo.web_sale (
    web_sale_numb, web_sale_date, web_customer_numb, web_credit_card_numb,
    web_sale_total, web_sale_merchandise_total, web_sale_shipping, web_sale_tax
) VALUES (6002, CAST(GETDATE() AS DATE), 3001, '4999888877776666', 229.50, 200.00, 15.00, 14.50);

INSERT INTO dbo.web_sale_item (
    web_sale_numb, web_sale_SKU, web_sale_quantity, web_sale_shipped,
    web_sale_price, web_shipping_address_numb, web_sale_date_shipped
) VALUES (6002, 'SKU-WHSE-000001', 1, 0, 200.00, 4001, NULL);

-- 1.4.13 ตัดสต็อกคลังออนไลน์
UPDATE dbo.product_stocked
SET number_on_hand = number_on_hand - 1
WHERE SKU = 'SKU-WHSE-000001' AND in_store = 0 AND number_on_hand >= 1;
*/

-- ----------------------------------------------------------------------------
-- Transaction 7 [Path]: การตรวจสอบรายการสั่งซื้อออนไลน์และสถานะจัดส่งแบบปกป้องข้อมูลบัตรและที่อยู่
-- ----------------------------------------------------------------------------
-- 1.4.4 ดูรายการสั่งซื้อเว็บผ่าน View ที่ซ่อนเลขบัตรและที่อยู่
SELECT 
    web_sale_numb, web_sale_date, web_customer_numb, masked_credit_card_numb,
    web_sale_total, web_sale_SKU, web_sale_quantity, web_sale_shipped,
    web_sale_date_shipped, web_customer_shipping_state_code, web_customer_shipping_zip
FROM dbo.vw_Safe_Web_Shipping_Address
WHERE web_sale_numb = 6001;

-- ----------------------------------------------------------------------------
-- Transaction 8 [Bam]: การจัดการและตรวจสอบข้อมูลประวัติและอัตราค่าจ้างของพนักงานฝ่าย HR
-- ----------------------------------------------------------------------------
-- 1.4.5 ดูข้อมูลพนักงานฝ่าย HR
SELECT 
    employee_id, employee_first_name, employee_last_name,
    dept_numb, store_numb, supervisor_id, pay_type_code, pay_rate
FROM dbo.employee;

/*
-- 1.4.9 เพิ่มพนักงานใหม่ฝ่าย HR
INSERT INTO dbo.employee (
    employee_id, employee_first_name, employee_last_name, employee_street,
    employee_city, employee_state_code, employee_zip, employee_phone,
    employee_ssn, employee_birth_date, dept_numb, store_numb, supervisor_id,
    pay_type_code, pay_rate
) VALUES (
    1003, 'Charlie', 'Davis', '88 Pine St', 'San Francisco', 'CA', '94103',
    '415-555-1003', '333-33-3333', '1998-03-15', 10, 101, 1001, 2, 22.00
);

-- 1.4.14 อัปเดตแผนกและเงินเดือนพนักงานฝ่าย HR
UPDATE dbo.employee
SET dept_numb = 10, store_numb = 101, pay_rate = 25.00
WHERE employee_id = 1002;
*/
