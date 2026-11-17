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

-- เปิดใช้งาน Snapshot Isolation เพื่อช่วย Isolate ข้อมูลระหว่างอ่าน/เขียนพร้อมกัน (ป้องกัน Dirty Read บนตารางและ Materialized Views)
ALTER DATABASE SmartMartDB SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

USE SmartMartDB;
GO

-- ============================================================================
-- 1. สร้างตาราง (18 ตาราง)
-- หมายเหตุ: ตาราง employee, in_store_sale และ web_sale กำหนด PRIMARY KEY เป็น NONCLUSTERED
-- เพื่อสร้าง Clustered Index ตามคอลัมน์ที่ใช้ค้นหาตามกลุ่มสาขา/ช่วงวันที่จริงในหัวข้อที่ 4
-- ============================================================================

CREATE TABLE state (
    state_code CHAR(2) NOT NULL,
    state_name CHAR(15) NOT NULL,
    CONSTRAINT PK_state PRIMARY KEY CLUSTERED (state_code)
);

CREATE TABLE in_store_payment_type (
    in_store_payment_type_code INT NOT NULL,
    in_store_payment_type_text CHAR(10) NOT NULL,
    CONSTRAINT PK_in_store_payment_type PRIMARY KEY CLUSTERED (in_store_payment_type_code)
);

CREATE TABLE store (
    store_numb INT NOT NULL,
    store_street CHAR(50) NOT NULL,
    store_city CHAR(50) NOT NULL,
    store_state_code CHAR(2) NOT NULL,
    store_zip CHAR(10) NOT NULL,
    store_main_phone CHAR(12) NOT NULL,
    store_manager_id INT NULL,
    CONSTRAINT PK_store PRIMARY KEY CLUSTERED (store_numb),
    CONSTRAINT FK_store_state FOREIGN KEY (store_state_code) REFERENCES state (state_code)
);

CREATE TABLE department (
    dept_numb INT NOT NULL,
    store_numb INT NOT NULL,
    dept_manager_id INT NULL,
    CONSTRAINT PK_department PRIMARY KEY CLUSTERED (dept_numb, store_numb),
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
    employee_ssn CHAR(11) MASKED WITH (FUNCTION = 'partial(0,"XXX-XX-",4)') NOT NULL,
    employee_birth_date DATE NOT NULL,
    dept_numb INT NULL,
    store_numb INT NULL,
    supervisor_id INT NULL,
    pay_type_code INT NOT NULL,
    pay_rate DECIMAL(10, 2) MASKED WITH (FUNCTION = 'default()') NOT NULL,
    CONSTRAINT PK_employee PRIMARY KEY NONCLUSTERED (employee_id),
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
    CONSTRAINT PK_warehouse PRIMARY KEY CLUSTERED (warehouse_numb),
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
    CONSTRAINT PK_product PRIMARY KEY CLUSTERED (UPC)
);

CREATE TABLE sales_promotion (
    UPC CHAR(15) NOT NULL,
    promotion_start_date DATE NOT NULL,
    promotion_end_date DATE NOT NULL,
    promotion_type_code INT NOT NULL,
    promotion_details CHAR(50) NULL,
    CONSTRAINT PK_sales_promotion PRIMARY KEY CLUSTERED (UPC, promotion_start_date),
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
    CONSTRAINT PK_product_stocked PRIMARY KEY CLUSTERED (SKU),
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
    CONSTRAINT PK_in_store_sale PRIMARY KEY NONCLUSTERED (in_store_transaction_numb),
    CONSTRAINT FK_in_store_sale_payment_type FOREIGN KEY (in_store_sale_payment_type_code)
        REFERENCES in_store_payment_type (in_store_payment_type_code)
);

CREATE TABLE credit_sale_details (
    in_store_transaction_numb INT NOT NULL,
    in_store_sale_credit_card_numb CHAR(16) NOT NULL,
    in_store_sale_credit_card_exp_date DATE NOT NULL,
    in_store_sale_name_on_credit_card VARCHAR(50) NOT NULL,
    CONSTRAINT PK_credit_sale_details PRIMARY KEY CLUSTERED (in_store_transaction_numb),
    CONSTRAINT FK_credit_sale_details_sale FOREIGN KEY (in_store_transaction_numb)
        REFERENCES in_store_sale (in_store_transaction_numb)
);

CREATE TABLE in_store_sale_item (
    in_store_transaction_numb INT NOT NULL,
    in_store_SKU CHAR(15) NOT NULL,
    in_store_quantity INT NOT NULL,
    in_store_price DECIMAL(7, 2) NOT NULL,
    CONSTRAINT PK_in_store_sale_item PRIMARY KEY CLUSTERED (in_store_transaction_numb, in_store_SKU),
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
    CONSTRAINT PK_web_customer PRIMARY KEY CLUSTERED (web_customer_numb)
);

CREATE TABLE web_customer_credit_card (
    web_customer_numb INT NOT NULL,
    web_credit_card_numb CHAR(16) NOT NULL,
    web_credit_card_exp_date DATE NOT NULL,
    web_sale_name_on_credit_card VARCHAR(50) NOT NULL,
    CONSTRAINT PK_web_customer_credit_card PRIMARY KEY CLUSTERED (web_customer_numb, web_credit_card_numb),
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
    CONSTRAINT PK_web_sale_shipping_address PRIMARY KEY CLUSTERED (web_shipping_address_numb),
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
    CONSTRAINT PK_web_sale PRIMARY KEY NONCLUSTERED (web_sale_numb),
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
    CONSTRAINT PK_web_sale_shipment PRIMARY KEY CLUSTERED (web_sale_numb, web_sale_date_shipped),
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
    CONSTRAINT PK_web_sale_item PRIMARY KEY CLUSTERED (web_sale_numb, web_sale_SKU),
    CONSTRAINT FK_web_item_sku FOREIGN KEY (web_sale_SKU) REFERENCES product_stocked (SKU),
    CONSTRAINT FK_web_item_sale FOREIGN KEY (web_sale_numb) REFERENCES web_sale (web_sale_numb),
    CONSTRAINT FK_web_item_address FOREIGN KEY (web_shipping_address_numb)
        REFERENCES web_sale_shipping_address (web_shipping_address_numb),
    CONSTRAINT FK_web_item_shipment FOREIGN KEY (web_sale_numb, web_sale_date_shipped)
        REFERENCES web_sale_shipment (web_sale_numb, web_sale_date_shipped)
);
GO

-- ============================================================================
-- 2. ข้อมูลตัวอย่าง (Sample Data)
-- ============================================================================

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
UPDATE warehouse SET warehouse_manager_id = 1001 WHERE warehouse_numb = 201;

INSERT INTO product VALUES ('UPC000000000001', 'Smart Watch', 'Piece', 1, NULL, 1);
INSERT INTO sales_promotion VALUES ('UPC000000000001', '2026-01-01', '2029-12-31', 10, 'Discount 20%');

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

-- ============================================================================
-- 3. สร้าง Views และ Materialized Views พร้อมการ Isolate ข้อมูลตามสิทธิ์/ช่องทาง (ข้อ 2.3)
-- ============================================================================

-- 3.1 Non-Materialized View: สมุดรายชื่อพนักงาน (ปกป้องข้อมูล SSN, วันเกิด, ที่อยู่บ้าน และเงินเดือน)
-- เพื่อให้พนักงานทั่วไปและหัวหน้างานเข้าถึงข้อมูลพนักงานและสายบังคับบัญชาได้ตามการทำงานจริง
CREATE VIEW dbo.vw_Employee_Directory
AS
SELECT 
    e.employee_id,
    e.employee_first_name,
    e.employee_last_name,
    e.employee_phone,
    e.store_numb,
    e.dept_numb,
    e.supervisor_id,
    s.employee_first_name + ' ' + s.employee_last_name AS supervisor_name
FROM dbo.employee e
LEFT JOIN dbo.employee s ON e.supervisor_id = s.employee_id;
GO

-- 3.2 Non-Materialized View: สินค้าและโปรโมชั่นสำหรับระบบขายออนไลน์ (Isolate เฉพาะคลังออนไลน์ in_store = 0 ที่มีของพร้อมขาย)
CREATE VIEW dbo.vw_Web_Product_Promo
AS
SELECT 
    p.UPC, p.product_name, p.product_unit, p.shipping_weight,
    ps.SKU, ps.size, ps.color, ps.retail_price, ps.number_on_hand,
    sp.promotion_start_date, sp.promotion_end_date, sp.promotion_details
FROM dbo.product p
JOIN dbo.product_stocked ps ON p.UPC = ps.UPC
LEFT JOIN dbo.sales_promotion sp ON p.UPC = sp.UPC
    AND CAST(GETDATE() AS DATE) BETWEEN sp.promotion_start_date AND sp.promotion_end_date
WHERE p.web_orderable = 1 AND ps.in_store = 0 AND ps.number_on_hand > 0;
GO

-- 3.3 Non-Materialized View: ปกป้องเลขบัตรเครดิต (แสดงแค่ 4 ตัวท้าย) และซ่อนบ้านเลขที่ลูกค้า
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

-- ตั้งค่า Session Options สำหรับสร้าง Materialized Views (Indexed Views)
SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
GO

-- 3.4 Materialized View ตัวที่ 1 (สำหรับ Manager / Supervisor):
-- สรุปยอดสต็อกคงเหลือแยกตามช่องทาง (in_store = 1 หน้าร้าน vs in_store = 0 คลังออนไลน์)
-- ช่วย Isolate ข้อมูลระดับสรุป และรองรับการอ่านด้วย WITH (NOEXPAND) ภายใต้ Snapshot/Read Committed Isolation
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

-- 3.5 Materialized View ตัวที่ 2 (Isolate ข้อมูลเฉพาะระบบขายออนไลน์ - Role_Web_Sale_App):
-- แยกกั้น (Isolate) เฉพาะสต็อกคลังออนไลน์ (in_store = 0) ที่สั่งผ่านเว็บได้ (web_orderable = 1)
-- และซ่อนรหัสคลังสินค้าหลังบ้าน (warehouse_numb) รวมถึงซ่อนสต็อกหน้าร้านทั้งหมดไม่ให้แอปเว็บเข้าถึง
CREATE VIEW dbo.vw_Materialized_Web_Available_Inventory
WITH SCHEMABINDING
AS
SELECT 
    ps.UPC, p.product_name, p.product_unit, p.shipping_weight,
    ps.SKU, ps.size, ps.color, ps.retail_price, ps.number_on_hand
FROM dbo.product_stocked ps
JOIN dbo.product p ON ps.UPC = p.UPC
WHERE ps.in_store = 0 AND p.web_orderable = 1;
GO

CREATE UNIQUE CLUSTERED INDEX IDX_Materialized_Web_Available_Inventory
ON dbo.vw_Materialized_Web_Available_Inventory (UPC, SKU);
GO

-- 3.6 Materialized View ตัวที่ 3 (Isolate ข้อมูลเฉพาะระบบขายหน้าร้าน - Role_InStore_Sale_App & Role_Staff):
-- แยกกั้น (Isolate) เฉพาะสต็อกหน้าร้าน (in_store = 1) แยกตามสาขาและแผนก โดยไม่ให้ปะปนกับสต็อกคลังสินค้าออนไลน์
CREATE VIEW dbo.vw_Materialized_InStore_Available_Inventory
WITH SCHEMABINDING
AS
SELECT 
    ps.store_numb, ps.dept_numb, ps.UPC, p.product_name,
    ps.SKU, ps.size, ps.color, ps.retail_price, ps.number_on_hand
FROM dbo.product_stocked ps
JOIN dbo.product p ON ps.UPC = p.UPC
WHERE ps.in_store = 1;
GO

CREATE UNIQUE CLUSTERED INDEX IDX_Materialized_InStore_Available_Inventory
ON dbo.vw_Materialized_InStore_Available_Inventory (store_numb, dept_numb, UPC, SKU);
GO

-- ============================================================================
-- 4. สร้าง Clustered Indexes และ Non-Clustered Indexes (ข้อ 2.4)
-- ============================================================================

-- 4.1 Clustered Indexes (จัดเรียงข้อมูลจริงบนดิสก์ตามคอลัมน์ที่ใช้ค้นหาแบบกลุ่มและช่วงวันที่)
-- (1) จัดเรียงพนักงานบนดิสก์ตามสาขาและแผนก เพื่อให้ HR / ผู้จัดการดึงรายชื่อพนักงานรายสาขาได้ทันที
CREATE CLUSTERED INDEX CIX_Employee_Store_Dept
ON dbo.employee (store_numb, dept_numb, employee_id);

-- (2) จัดเรียงใบเสร็จหน้าร้านตามวันที่ซื้อ เพื่อเร่งความเร็ว Range Scan ตรวจสอบการคืนสินค้าภายใน 15 วัน (Tx 1)
CREATE CLUSTERED INDEX CIX_InStoreSale_TransactionDate
ON dbo.in_store_sale (in_store_transaction_date, in_store_transaction_numb);

-- (3) จัดเรียงคำสั่งซื้อออนไลน์ตามวันที่สั่งซื้อและรหัสลูกค้า
CREATE CLUSTERED INDEX CIX_WebSale_SaleDate_Customer
ON dbo.web_sale (web_sale_date, web_customer_numb, web_sale_numb);
GO

-- 4.2 Non-Clustered Covering Indexes (ใช้ INCLUDE เพื่อทำ Index Seek จบในตัวโดยไม่ต้องทำ Key Lookup)
-- (1) เร่งความเร็วให้การค้นหาสต็อกสินค้าตามรหัส UPC และดึงสินค้าขึ้นหน้าเว็บ (ข้อ 1.4.1 และ 1.4.2)
CREATE NONCLUSTERED INDEX IX_ProductStocked_UPC_Location
ON dbo.product_stocked (UPC, in_store, number_on_hand)
INCLUDE (SKU, store_numb, dept_numb, warehouse_numb, retail_price);

-- (2) เร่งความเร็วให้การตรวจสอบใบเสร็จและยอดขายหน้าร้านตามวันที่ซื้อ (ข้อ 1.4.3)
CREATE NONCLUSTERED INDEX IX_InStoreSale_TransactionDate
ON dbo.in_store_sale (in_store_transaction_date)
INCLUDE (in_store_sale_total, in_store_sale_payment_type_code);

-- (3) เร่งความเร็วให้การตรวจสอบและอัปเดตสถานะจัดส่งสินค้าออนไลน์ (ข้อ 1.4.4 และ 1.4.12)
CREATE NONCLUSTERED INDEX IX_WebSaleItem_ShippedStatus
ON dbo.web_sale_item (web_sale_numb, web_sale_shipped)
INCLUDE (web_sale_SKU, web_shipping_address_numb, web_sale_date_shipped);
GO

-- ============================================================================
-- 5. สร้าง Logins, Users, Roles และกำหนดสิทธิ์ตามหลักการทำงานจริง (ข้อ 2.1 - 2.2)
-- ============================================================================

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

-- ----------------------------------------------------------------------------
-- 5.1 Role_HR (ฝ่ายทรัพยากรบุคคล):
-- • จัดการข้อมูลพนักงาน (dbo.employee) ได้เต็มรูปแบบทุกคอลัมน์ และมีสิทธิ์ UNMASK เห็น SSN และเงินเดือนจริง
-- • ดูข้อมูลรัฐ สาขา แผนก คลังสินค้า และอัปเดตรหัสผู้จัดการสาขา/แผนก/คลัง เมื่อมีการเลื่อนตำแหน่งได้
-- • ห้ามเข้าถึงข้อมูลการขายและข้อมูลบัตรเครดิตลูกค้า
-- ----------------------------------------------------------------------------
GRANT UNMASK TO Role_HR;
GRANT SELECT, INSERT, UPDATE ON dbo.employee TO Role_HR;
GRANT SELECT ON dbo.vw_Employee_Directory TO Role_HR;
GRANT SELECT ON dbo.state TO Role_HR;
GRANT SELECT ON dbo.store TO Role_HR;
GRANT SELECT ON dbo.department TO Role_HR;
GRANT SELECT ON dbo.warehouse TO Role_HR;
GRANT UPDATE (store_manager_id) ON dbo.store TO Role_HR;
GRANT UPDATE (dept_manager_id) ON dbo.department TO Role_HR;
GRANT UPDATE (warehouse_manager_id) ON dbo.warehouse TO Role_HR;

DENY SELECT, INSERT, UPDATE, DELETE ON dbo.product TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.product_stocked TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.in_store_sale TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.in_store_sale_item TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.credit_sale_details TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.web_sale TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.web_sale_item TO Role_HR;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.web_customer_credit_card TO Role_HR;

-- ----------------------------------------------------------------------------
-- 5.2 Role_Admin (ผู้ดูแลระบบฐานข้อมูล - DBA):
-- • ดูแลโครงสร้างตาราง (DDL) และสำรองข้อมูล (Backup)
-- • แยกหน้าที่ (Separation of Duties) โดยบล็อกไม่ให้ดูเลขบัตรเครดิตลูกค้าและตารางการขาย
-- ----------------------------------------------------------------------------
ALTER ROLE db_ddladmin ADD MEMBER User_Admin;
ALTER ROLE db_backupoperator ADD MEMBER User_Admin;
GRANT BACKUP DATABASE TO Role_Admin;
DENY SELECT ON dbo.credit_sale_details TO Role_Admin;
DENY SELECT ON dbo.web_customer_credit_card TO Role_Admin;
DENY SELECT ON dbo.in_store_sale TO Role_Admin;
DENY SELECT ON dbo.web_sale TO Role_Admin;

-- ----------------------------------------------------------------------------
-- 5.3 Role_Manager (ผู้จัดการสาขาและคลังสินค้า):
-- • เข้าถึงตารางพนักงาน (SELECT * FROM dbo.employee และ vw_Employee_Directory) ได้เพื่อบริหารทีม
--   โดย Dynamic Data Masking จะบังเลข SSN เป็น 'XXX-XX-XXXX' อัตโนมัติ และห้ามแก้ไขข้อมูลพนักงาน/เงินเดือนเองโดยไม่ผ่าน HR
-- • บริหารสินค้า สต็อก โปรโมชั่น ดูรายงานยอดขาย และจัดการการจัดส่งสินค้าออนไลน์
-- • บล็อกการเข้าถึงตารางบัตรเครดิตจริง (ให้ตรวจสอบออเดอร์ผ่าน vw_Safe_Web_Shipping_Address แทน)
-- ----------------------------------------------------------------------------
GRANT SELECT ON dbo.employee TO Role_Manager;
GRANT SELECT ON dbo.vw_Employee_Directory TO Role_Manager;
DENY INSERT, UPDATE, DELETE ON dbo.employee TO Role_Manager;

GRANT SELECT ON dbo.state TO Role_Manager;
GRANT SELECT ON dbo.store TO Role_Manager;
GRANT SELECT ON dbo.department TO Role_Manager;
GRANT SELECT ON dbo.warehouse TO Role_Manager;
GRANT SELECT, INSERT, UPDATE ON dbo.product TO Role_Manager;
GRANT SELECT, INSERT, UPDATE ON dbo.product_stocked TO Role_Manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.sales_promotion TO Role_Manager;
GRANT SELECT ON dbo.in_store_sale TO Role_Manager;
GRANT SELECT ON dbo.in_store_sale_item TO Role_Manager;
GRANT SELECT ON dbo.web_sale TO Role_Manager;
GRANT SELECT, INSERT, UPDATE ON dbo.web_sale_shipment TO Role_Manager;
GRANT SELECT, UPDATE ON dbo.web_sale_item TO Role_Manager;
GRANT SELECT, UPDATE ON dbo.web_sale_shipping_address TO Role_Manager;
GRANT SELECT ON dbo.vw_Web_Product_Promo TO Role_Manager;
GRANT SELECT ON dbo.vw_Safe_Web_Shipping_Address TO Role_Manager;
GRANT SELECT ON dbo.vw_Materialized_Available_Inventory TO Role_Manager;
GRANT SELECT ON dbo.vw_Materialized_Web_Available_Inventory TO Role_Manager;
GRANT SELECT ON dbo.vw_Materialized_InStore_Available_Inventory TO Role_Manager;

DENY SELECT, INSERT, UPDATE, DELETE ON dbo.credit_sale_details TO Role_Manager;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.web_customer_credit_card TO Role_Manager;

-- ----------------------------------------------------------------------------
-- 5.4 Role_Supervisor (หัวหน้างานหน้าร้าน):
-- • เข้าถึงตารางพนักงาน (SELECT * FROM dbo.employee และ vw_Employee_Directory) เพื่อดูลูกน้องในแผนกได้
--   โดย Dynamic Data Masking จะบังเลข SSN ('XXX-XX-XXXX') และบังเงินเดือน (0.00) อัตโนมัติ และห้ามแก้ไขข้อมูลพนักงาน
-- • ตรวจสอบใบเสร็จ ปรับสต็อก และอนุมัติการคืนสินค้าหน้าร้านภายใน 15 วัน (Tx 1)
-- ----------------------------------------------------------------------------
GRANT SELECT ON dbo.employee TO Role_Supervisor;
GRANT SELECT ON dbo.vw_Employee_Directory TO Role_Supervisor;
DENY INSERT, UPDATE, DELETE ON dbo.employee TO Role_Supervisor;

GRANT SELECT ON dbo.store TO Role_Supervisor;
GRANT SELECT ON dbo.department TO Role_Supervisor;
GRANT SELECT ON dbo.product TO Role_Supervisor;
GRANT SELECT ON dbo.sales_promotion TO Role_Supervisor;
GRANT SELECT ON dbo.in_store_payment_type TO Role_Supervisor;
GRANT SELECT, UPDATE ON dbo.product_stocked TO Role_Supervisor;
GRANT SELECT, INSERT, UPDATE ON dbo.in_store_sale TO Role_Supervisor;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.in_store_sale_item TO Role_Supervisor;
GRANT SELECT ON dbo.vw_Materialized_Available_Inventory TO Role_Supervisor;
GRANT SELECT ON dbo.vw_Materialized_InStore_Available_Inventory TO Role_Supervisor;

DENY SELECT ON dbo.vw_Materialized_Web_Available_Inventory TO Role_Supervisor;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.credit_sale_details TO Role_Supervisor;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.web_customer_credit_card TO Role_Supervisor;

-- ----------------------------------------------------------------------------
-- 5.5 Role_Staff (พนักงานขายทั่วไป / Employee):
-- • เข้าถึงตารางพนักงาน (SELECT * FROM dbo.employee และ vw_Employee_Directory) เพื่อดูรายชื่อพนักงานและหัวหน้างานได้
--   โดย Dynamic Data Masking จะบังเลข SSN ('XXX-XX-XXXX') และบังเงินเดือน (0.00) อัตโนมัติ และห้ามแก้ไขข้อมูลพนักงาน
-- • ค้นหาสินค้า เช็กสต็อกหน้าร้านผ่าน Materialized View ที่ Isolate เฉพาะหน้าร้าน ตัดสต็อก และเปิดบิลขายหน้าร้าน (ห้ามแก้ไขหรือลบบิลย้อนหลัง)
-- ----------------------------------------------------------------------------
GRANT SELECT ON dbo.employee TO Role_Staff;
GRANT SELECT ON dbo.vw_Employee_Directory TO Role_Staff;
DENY INSERT, UPDATE, DELETE ON dbo.employee TO Role_Staff;

GRANT SELECT ON dbo.store TO Role_Staff;
GRANT SELECT ON dbo.department TO Role_Staff;
GRANT SELECT ON dbo.warehouse TO Role_Staff;
GRANT SELECT ON dbo.product TO Role_Staff;
GRANT SELECT ON dbo.sales_promotion TO Role_Staff;
GRANT SELECT ON dbo.in_store_payment_type TO Role_Staff;
GRANT SELECT, UPDATE ON dbo.product_stocked TO Role_Staff;
GRANT SELECT, INSERT ON dbo.in_store_sale TO Role_Staff;
GRANT SELECT, INSERT ON dbo.in_store_sale_item TO Role_Staff;
GRANT SELECT ON dbo.vw_Materialized_InStore_Available_Inventory TO Role_Staff;

DENY SELECT ON dbo.vw_Materialized_Web_Available_Inventory TO Role_Staff;
DENY UPDATE, DELETE ON dbo.in_store_sale TO Role_Staff;
DENY UPDATE, DELETE ON dbo.in_store_sale_item TO Role_Staff;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.credit_sale_details TO Role_Staff;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.web_customer_credit_card TO Role_Staff;

-- ----------------------------------------------------------------------------
-- 5.6 Role_InStore_Sale_App (แอปพลิเคชัน POS ขายหน้าร้าน):
-- • ทำงานเฉพาะส่วนการขายหน้าร้าน และดูสต็อกหน้าร้านที่ถูก Isolate ไว้ใน vw_Materialized_InStore_Available_Inventory
-- • บันทึกข้อมูลบัตรเครดิตตอนชำระเงินได้ (GRANT INSERT ON credit_sale_details) แต่ดึงเลขบัตรออกมาดูไม่ได้ (DENY SELECT)
-- • บล็อกการเข้าถึงตารางพนักงาน (employee) และระบบขายออนไลน์ทั้งหมด
-- ----------------------------------------------------------------------------
GRANT SELECT ON dbo.product TO Role_InStore_Sale_App;
GRANT SELECT ON dbo.sales_promotion TO Role_InStore_Sale_App;
GRANT SELECT ON dbo.in_store_payment_type TO Role_InStore_Sale_App;
GRANT SELECT, UPDATE ON dbo.product_stocked TO Role_InStore_Sale_App;
GRANT SELECT, INSERT, UPDATE ON dbo.in_store_sale TO Role_InStore_Sale_App;
GRANT SELECT, INSERT, UPDATE ON dbo.in_store_sale_item TO Role_InStore_Sale_App;
GRANT INSERT ON dbo.credit_sale_details TO Role_InStore_Sale_App;
GRANT SELECT ON dbo.vw_Materialized_InStore_Available_Inventory TO Role_InStore_Sale_App;

DENY SELECT ON dbo.vw_Materialized_Web_Available_Inventory TO Role_InStore_Sale_App;
DENY SELECT, UPDATE, DELETE ON dbo.credit_sale_details TO Role_InStore_Sale_App;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.employee TO Role_InStore_Sale_App;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.web_sale TO Role_InStore_Sale_App;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.web_customer_credit_card TO Role_InStore_Sale_App;

-- ----------------------------------------------------------------------------
-- 5.7 Role_Web_Sale_App (แอปพลิเคชันเว็บไซต์ขายออนไลน์):
-- • ดึงข้อมูลสินค้าและสต็อกคลังออนไลน์ที่ถูก Isolate ไว้ผ่าน vw_Web_Product_Promo และ vw_Materialized_Web_Available_Inventory
-- • จัดการคำสั่งซื้อออนไลน์และตัดสต็อกเฉพาะคลังออนไลน์
-- • บล็อกการเข้าถึงข้อมูลพนักงาน (employee), สาขาหน้าร้าน (store, department), สต็อกหน้าร้าน และบิลหน้าร้านทั้งหมด
-- ----------------------------------------------------------------------------
GRANT SELECT ON dbo.product TO Role_Web_Sale_App;
GRANT SELECT ON dbo.sales_promotion TO Role_Web_Sale_App;
GRANT SELECT, UPDATE ON dbo.product_stocked TO Role_Web_Sale_App;
GRANT SELECT, INSERT, UPDATE ON dbo.web_customer TO Role_Web_Sale_App;
GRANT SELECT, INSERT ON dbo.web_customer_credit_card TO Role_Web_Sale_App;
GRANT SELECT, INSERT, UPDATE ON dbo.web_sale_shipping_address TO Role_Web_Sale_App;
GRANT SELECT, INSERT, UPDATE ON dbo.web_sale TO Role_Web_Sale_App;
GRANT SELECT, INSERT, UPDATE ON dbo.web_sale_item TO Role_Web_Sale_App;
GRANT SELECT ON dbo.vw_Web_Product_Promo TO Role_Web_Sale_App;
GRANT SELECT ON dbo.vw_Materialized_Web_Available_Inventory TO Role_Web_Sale_App;

DENY SELECT ON dbo.vw_Materialized_InStore_Available_Inventory TO Role_Web_Sale_App;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.employee TO Role_Web_Sale_App;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.store TO Role_Web_Sale_App;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.department TO Role_Web_Sale_App;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.in_store_sale TO Role_Web_Sale_App;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.credit_sale_details TO Role_Web_Sale_App;
GO

-- ============================================================================
-- 6. คำสั่ง SQL Transactions ทั้ง 8 รายการ (ข้อ 1.4)
-- ออกแบบตามหลัก Step-by-Step Transaction & Concurrency Locking (UPDLOCK, ROWLOCK):
--   • Step 1: ล็อกแถวข้อมูล (Lock/Hold) ป้องกันคนอื่นแย่งทำรายการซ้ำพร้อมกัน
--   • Step 2: ตัดสต็อก / บันทึกรายการชั่วคราวภายใน Transaction
--   • Step 3: ตรวจสอบการชำระเงินหรือเงื่อนไขอนุมัติ
--   • Step 4: ถ้าจ่ายเงิน/อนุมัติสำเร็จ -> COMMIT (จบงาน)
--             ถ้าไม่จ่ายเงิน/ยกเลิก/ไม่ผ่าน -> ROLLBACK (สต็อกและข้อมูลเด้งกลับค่าเดิม
--             และปลดล็อกให้คนที่ 2 ที่รอคิวอยู่เด้งเข้ามาทำ Transaction ต่อได้ทันที)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Transaction 1: การรับคืนสินค้าหน้าร้านภายใน 15 วัน และคืนเงิน/คืนสต็อกแบบ Step-by-Step [มีใน Java]
-- (Step 1: ล็อกบิลกันกดคืนซ้ำ -> Step 2: คืนสต็อก + หักยอดบิล -> Step 3: ตรวจอนุมัติคืนเงิน
--  -> ถ้าอนุมัติ COMMIT / ถ้าไม่อนุมัติหรือเกิน 15 วัน ROLLBACK สต็อกและบิลกลับเหมือนเดิม)
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
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @RefundApproved BIT = 1; -- 1 = อนุมัติคืนเงินสำเร็จ, 0 = ยกเลิก/ไม่อนุมัติ (จะ Rollback คืนค่าเดิม)

    -- Step 1 (1.4.3): ล็อกแถวใบเสร็จและรายการสินค้า (UPDLOCK, ROWLOCK) ป้องกันพนักงาน 2 เครื่องกดคืนซ้ำพร้อมกัน
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.in_store_sale s WITH (UPDLOCK, ROWLOCK)
        JOIN dbo.in_store_sale_item i WITH (UPDLOCK, ROWLOCK)
            ON s.in_store_transaction_numb = i.in_store_transaction_numb
        WHERE s.in_store_transaction_numb = 5001
          AND i.in_store_SKU = 'SKU-STORE-00001'
          AND i.in_store_quantity >= 1
          AND DATEDIFF(DAY, s.in_store_transaction_date, CAST(GETDATE() AS DATE)) <= 15
    )
    BEGIN
        THROW 50001, 'ไม่พบรายการซื้อ หรือเกินกำหนดคืนสินค้า 15 วัน', 1;
    END

    -- Step 2 (1.4.11 & 1.4.15): คืนสต็อกหน้าร้าน +1 และหักจำนวน/ยอดเงินในใบเสร็จชั่วคราว
    UPDATE dbo.product_stocked WITH (ROWLOCK)
    SET number_on_hand = number_on_hand + 1
    WHERE SKU = 'SKU-STORE-00001' AND in_store = 1;

    UPDATE dbo.in_store_sale_item
    SET in_store_quantity = in_store_quantity - 1
    WHERE in_store_transaction_numb = 5001 AND in_store_SKU = 'SKU-STORE-00001';

    DELETE FROM dbo.in_store_sale_item
    WHERE in_store_transaction_numb = 5001
      AND in_store_SKU = 'SKU-STORE-00001'
      AND in_store_quantity <= 0;

    UPDATE dbo.in_store_sale
    SET in_store_sale_product_total = in_store_sale_product_total - 200.00,
        in_store_sale_total = in_store_sale_total - 200.00
    WHERE in_store_transaction_numb = 5001;

    -- Step 3: ตรวจสอบการอนุมัติคืนเงินให้ลูกค้า (ถ้าไม่อนุมัติหรือเครื่องรูดคืนเงินไม่ผ่าน ให้ Rollback ทั้งหมด)
    IF @RefundApproved = 0
        THROW 50009, 'การคืนเงินไม่สำเร็จ ระบบยกเลิกรายการและคืนค่าบิล/สต็อกกลับสู่สถานะเดิม', 1;

    -- Step 4: ยืนยันจบ Transaction
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
*/

-- ----------------------------------------------------------------------------
-- Transaction 2: การซื้อสินค้าหน้าร้านด้วยบัตรเครดิตแบบ Step-by-Step [มีใน Java]
-- (Step 1: ล็อกและลดสต็อกหน้าร้าน -> Step 2: เปิดบิลรอชำระ -> Step 3: ตัดบัตรเครดิต
--  -> ถ้าลูกค้าไม่จ่าย/บัตรไม่ผ่าน ระบบจะ ROLLBACK ให้สต็อกเด้งกลับมาเท่าเดิม และคนที่ 2 ซื้อต่อได้ทันที)
-- ----------------------------------------------------------------------------
/*
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @IsPaymentSuccess BIT = 1; -- 1 = จ่ายเงินผ่าน (COMMIT), 0 = ไม่จ่าย/บัตรไม่ผ่าน (ROLLBACK สต็อกเด้งกลับ)

    -- Step 1 (1.4.10): ล็อกแถวสต็อก (ROWLOCK, UPDLOCK) และตัดสต็อกหน้าร้านชั่วคราว
    -- (ระหว่างขั้นตอนนี้ ถ้าลูกค้าคนที่ 2 กดซื้อ SKU เดียวกัน จะติด Lock ต้องรอคิว)
    UPDATE dbo.product_stocked WITH (UPDLOCK, ROWLOCK)
    SET number_on_hand = number_on_hand - 1
    WHERE SKU = 'SKU-STORE-00001' AND in_store = 1 AND number_on_hand >= 1;

    IF @@ROWCOUNT = 0
        THROW 50002, 'สต็อกสินค้าหน้าร้านไม่เพียงพอ', 1;

    -- Step 2 (1.4.6): สร้างหัวใบเสร็จและรายการสินค้าเพื่อรอรับชำระเงิน
    INSERT INTO dbo.in_store_sale (
        in_store_transaction_numb, in_store_transaction_date,
        in_store_sale_product_total, in_store_sales_tax, in_store_sale_total, in_store_sale_payment_type_code
    ) VALUES (5002, CAST(GETDATE() AS DATE), 200.00, 14.50, 214.50, 2);

    INSERT INTO dbo.in_store_sale_item (
        in_store_transaction_numb, in_store_SKU, in_store_quantity, in_store_price
    ) VALUES (5002, 'SKU-STORE-00001', 1, 200.00);

    -- Step 3 (1.4.6): ตรวจสอบผลการรูดบัตรเครดิต
    IF @IsPaymentSuccess = 0
        THROW 50010, 'ลูกค้าไม่ชำระเงินหรือบัตรเครดิตไม่ผ่าน ระบบ Rollback คืนสต็อกกลับเท่าเดิม', 1;

    INSERT INTO dbo.credit_sale_details (
        in_store_transaction_numb, in_store_sale_credit_card_numb,
        in_store_sale_credit_card_exp_date, in_store_sale_name_on_credit_card
    ) VALUES (5002, '4111222233339999', '2029-12-31', 'SOMCHAI JAIDEE');

    -- Step 4: ชำระเงินสำเร็จ ยืนยันการตัดสต็อกและบันทึกบิล
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION; -- สต็อกเด้งกลับเท่าเดิม และปลดล็อกให้ลูกค้าคิวถัดไปทำรายการต่อได้ทันที
    THROW;
END CATCH;
*/

-- ----------------------------------------------------------------------------
-- Transaction 3: การค้นหาและโอนย้ายสต็อกสินค้าจากคลังสินค้ามาเติมหน้าร้านแบบ Step-by-Step [มีใน Java]
-- (Step 1: เช็กและล็อกสต็อกคลัง & หน้าร้าน -> Step 2: หักสต็อกคลังออนไลน์ -> Step 3: เติมสต็อกหน้าร้าน
--  -> ถ้ายืนยันรับของเข้าสาขาไม่ผ่าน จะ ROLLBACK คืนสต็อกคลังกลับเท่าเดิม)
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

/*
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @TransferQty INT = 5;
    DECLARE @StoreReceiveConfirmed BIT = 1; -- 1 = สาขายืนยันรับของสำเร็จ, 0 = ยกเลิกการโอน (Rollback)

    -- Step 1 (1.4.1): ล็อกแถวสต็อกคลังสินค้า (UPDLOCK, ROWLOCK) และหักสต็อกจากคลัง (in_store = 0)
    UPDATE dbo.product_stocked WITH (UPDLOCK, ROWLOCK)
    SET number_on_hand = number_on_hand - @TransferQty
    WHERE SKU = 'SKU-WHSE-000001' AND in_store = 0 AND number_on_hand >= @TransferQty;

    IF @@ROWCOUNT = 0
        THROW 50003, 'สต็อกในคลังสินค้าไม่เพียงพอสำหรับโอนย้ายไปหน้าร้าน', 1;

    -- Step 2: เพิ่มสต็อกเข้าสาขาหน้าร้าน (in_store = 1)
    UPDATE dbo.product_stocked WITH (UPDLOCK, ROWLOCK)
    SET number_on_hand = number_on_hand + @TransferQty
    WHERE SKU = 'SKU-STORE-00001' AND in_store = 1;

    IF @@ROWCOUNT = 0
        THROW 50011, 'ไม่พบรหัส SKU ปลายทางของสาขาหน้าร้าน', 1;

    -- Step 3: ตรวจสอบการยืนยันรับสินค้าปลายทาง
    IF @StoreReceiveConfirmed = 0
        THROW 50012, 'สาขาปลายทางปฏิเสธการรับสินค้า ระบบ Rollback คืนสต็อกกลับเข้าคลังเดิม', 1;

    -- Step 4: ยืนยันการโอนสต็อกสำเร็จ
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
*/

-- ----------------------------------------------------------------------------
-- Transaction 4: การตัดรอบจัดส่งสินค้าเว็บ เรียกเก็บเงิน และซ่อนที่อยู่ลูกค้าแบบ Step-by-Step [มีใน Java]
-- (Step 1: ล็อกรายการออเดอร์ที่รอส่ง -> Step 2: บันทึกรอบจัดส่ง -> Step 3: อัปเดตสถานะเป็นส่งแล้ว
--  -> Step 4: ซ่อนบ้านเลขที่ลูกค้าเป็น '*** MASKED ***' -> ถ้าขั้นใดไม่ผ่านจะ ROLLBACK ไม่ซ่อนที่อยู่ก่อนส่งจริง)
-- ----------------------------------------------------------------------------
/*
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ShippedTime DATETIME2 = SYSDATETIME();
    DECLARE @CarrierAccepted BIT = 1; -- 1 = ขนส่งรับพัสดุสำเร็จ, 0 = ขนส่งตีกลับ/ไม่สำเร็จ (Rollback)

    -- Step 1: ล็อกแถวรายการสั่งซื้อเว็บ (UPDLOCK, ROWLOCK) ป้องกันพนักงานคลัง 2 คนกดส่งออเดอร์เดียวกันซ้ำ
    IF NOT EXISTS (
        SELECT 1 FROM dbo.web_sale_item WITH (UPDLOCK, ROWLOCK)
        WHERE web_sale_numb = 6001 AND web_sale_SKU = 'SKU-WHSE-000001' AND web_sale_shipped = 0
    )
    BEGIN
        THROW 50004, 'ไม่พบรายการสินค้าที่รอจัดส่ง หรือรายการนี้ถูกจัดส่งไปแล้ว', 1;
    END

    -- Step 2 (1.4.7): เพิ่มรอบจัดส่งสินค้าเว็บและยอดเรียกเก็บ
    INSERT INTO dbo.web_sale_shipment (
        web_sale_numb, web_sale_date_shipped,
        web_shipment_merchandise_total, web_shipment_tax, web_shipment_shipping, web_shipment_total_charged
    ) VALUES (6001, @ShippedTime, 200.00, 14.50, 15.00, 229.50);

    -- Step 3 (1.4.12): อัปเดตสถานะรายการสินค้าเป็นจัดส่งแล้ว (web_sale_shipped = 1)
    UPDATE dbo.web_sale_item
    SET web_sale_shipped = 1, web_sale_date_shipped = @ShippedTime
    WHERE web_sale_numb = 6001 AND web_sale_SKU = 'SKU-WHSE-000001';

    -- Step 4 (1.4.12): ซ่อนบ้านเลขที่และถนนของลูกค้าเป็น '*** MASKED ***' ทันทีที่ส่งเสร็จ
    UPDATE dbo.web_sale_shipping_address
    SET web_shipping_street = '*** MASKED ***'
    WHERE web_shipping_address_numb = 4001;

    -- Step 5: ตรวจสอบการยืนยันรับพัสดุจากบริษัทขนส่ง
    IF @CarrierAccepted = 0
        THROW 50014, 'การส่งมอบพัสดุให้ขนส่งไม่สำเร็จ ระบบ Rollback คืนสถานะยังไม่ส่งและคงที่อยู่เดิมไว้', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
*/

-- ----------------------------------------------------------------------------
-- Transaction 5: การแย่งซื้อสินค้าโปรโมชั่นหน้าเว็บแบบ Step-by-Step (Flash Sale Checkout) [มีใน Java]
-- (แก้ไขตามคอมเมนต์อาจารย์:
--   • คนที่ 1 กดสั่งซื้อสินค้าโปรโมชั่น -> ระบบล็อกแถวสต็อก (UPDLOCK, ROWLOCK) และตัดสต็อกลงชั่วคราว
--     ระหว่างที่คนที่ 1 กำลังจ่ายเงิน คนที่ 2 ที่กดซื้อเข้ามาพร้อมกันจะติด Lock ซื้อตัดหน้าไม่ได้
--   • ถ้าคนที่ 1 ไม่จ่ายเงิน (@Buyer1Paid = 0) -> ระบบสั่ง ROLLBACK สต็อกเด้งกลับมาเท่าเดิมอัตโนมัติ
--   • ทันทีที่คนที่ 1 Rollback คลาย Lock -> คนที่ 2 เด้งเข้ามาทำ Transaction ตัดสต็อกและจ่ายเงิน (@Buyer2Paid = 1) จน COMMIT จบ!)
-- ----------------------------------------------------------------------------
-- 1.4.2 ดึงข้อมูลสินค้าและโปรโมชั่นลดราคาสำหรับแสดงผลบนระบบขายออนไลน์
SELECT 
    p.UPC, p.product_name, ps.SKU, ps.retail_price, ps.number_on_hand,
    sp.promotion_start_date, sp.promotion_end_date, sp.promotion_details
FROM dbo.product p
JOIN dbo.product_stocked ps ON p.UPC = ps.UPC
LEFT JOIN dbo.sales_promotion sp ON p.UPC = sp.UPC
    AND CAST(GETDATE() AS DATE) BETWEEN sp.promotion_start_date AND sp.promotion_end_date
WHERE p.web_orderable = 1 AND ps.in_store = 0 AND ps.number_on_hand > 0;

/*
-- [ส่วนที่ 5A: ลูกค้าคนที่ 1 กดซื้อสินค้าโปรโมชั่น ล็อกสต็อกไว้ แต่สุดท้าย "ไม่จ่ายเงิน" -> ROLLBACK สต็อกเด้งกลับเท่าเดิม]
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Buyer1Paid BIT = 0; -- จำลองว่าคนที่ 1 กดซื้อค้างไว้แล้วไม่จ่ายเงิน (0 = ไม่จ่าย -> Rollback)
    DECLARE @PromoPrice DECIMAL(7, 2);

    -- Step 1 (1.4.2): ล็อกแถวสต็อกคลังเว็บ (UPDLOCK, ROWLOCK) พร้อมดึงราคาที่หักส่วนลดโปรโมชั่น 20%
    -- (ขณะขั้นตอนนี้ทำงานอยู่ ลูกค้าคนที่ 2 จะไม่สามารถแย่งตัดสต็อก SKU นี้ได้ ต้องรอคิว)
    SELECT @PromoPrice = CASE
            WHEN sp.UPC IS NOT NULL THEN ROUND(ps.retail_price * 0.80, 2)
            ELSE ps.retail_price
        END
    FROM dbo.product p
    JOIN dbo.product_stocked ps WITH (UPDLOCK, ROWLOCK) ON p.UPC = ps.UPC
    LEFT JOIN dbo.sales_promotion sp ON p.UPC = sp.UPC
        AND CAST(GETDATE() AS DATE) BETWEEN sp.promotion_start_date AND sp.promotion_end_date
    WHERE ps.SKU = 'SKU-WHSE-000001' AND p.web_orderable = 1 AND ps.in_store = 0 AND ps.number_on_hand >= 1;

    IF @PromoPrice IS NULL
        THROW 50005, 'สินค้าหมดหรือไม่อยู่ในเงื่อนไขสั่งซื้อออนไลน์', 1;

    -- Step 2: ตัดสต็อกคลังออนไลน์ลง 1 ชิ้นระหว่างรอคนที่ 1 ชำระเงิน
    UPDATE dbo.product_stocked
    SET number_on_hand = number_on_hand - 1
    WHERE SKU = 'SKU-WHSE-000001' AND in_store = 0;

    -- Step 3: สร้างรายการจองคำสั่งซื้อของคนที่ 1 ตามราคาโปรโมชั่น
    INSERT INTO dbo.web_sale (
        web_sale_numb, web_sale_date, web_customer_numb, web_credit_card_numb,
        web_sale_total, web_sale_merchandise_total, web_sale_shipping, web_sale_tax
    ) VALUES (6002, CAST(GETDATE() AS DATE), 3001, '4999888877776666', @PromoPrice + 26.60, @PromoPrice, 15.00, 11.60);

    INSERT INTO dbo.web_sale_item (
        web_sale_numb, web_sale_SKU, web_sale_quantity, web_sale_shipped,
        web_sale_price, web_shipping_address_numb, web_sale_date_shipped
    ) VALUES (6002, 'SKU-WHSE-000001', 1, 0, @PromoPrice, 4001, NULL);

    -- Step 4: ตรวจสอบการชำระเงินของคนที่ 1 -> ไม่จ่ายเงิน! โยนเข้า CATCH เพื่อ ROLLBACK
    IF @Buyer1Paid = 0
        THROW 50015, 'ลูกค้าคนที่ 1 ไม่ชำระเงินภายในเวลาที่กำหนด -> ระบบ ROLLBACK คืนสต็อกกลับเท่าเดิม และส่งคิวให้คนที่ 2 ทันที!', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION; -- สต็อกเด้งกลับเป็น 100 ชิ้นเหมือนเดิม และคลาย Lock ให้คนที่ 2 ทันที
    PRINT ERROR_MESSAGE();
END CATCH;

-- [ส่วนที่ 5B: ลูกค้าคนที่ 2 ที่รอคิวอยู่ เด้งเข้ามาทำ Transaction ต่อทันที ตัดสต็อกและจ่ายเงินสำเร็จ -> COMMIT]
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Buyer2Paid BIT = 1; -- คนที่ 2 จ่ายเงินสำเร็จ (1 = จ่ายผ่าน -> Commit)
    DECLARE @PromoPrice2 DECIMAL(7, 2);

    -- Step 1: คนที่ 2 เข้าล็อกแถวสต็อกต่อทันทีหลังจากคนที่ 1 Rollback
    SELECT @PromoPrice2 = CASE
            WHEN sp.UPC IS NOT NULL THEN ROUND(ps.retail_price * 0.80, 2)
            ELSE ps.retail_price
        END
    FROM dbo.product p
    JOIN dbo.product_stocked ps WITH (UPDLOCK, ROWLOCK) ON p.UPC = ps.UPC
    LEFT JOIN dbo.sales_promotion sp ON p.UPC = sp.UPC
        AND CAST(GETDATE() AS DATE) BETWEEN sp.promotion_start_date AND sp.promotion_end_date
    WHERE ps.SKU = 'SKU-WHSE-000001' AND p.web_orderable = 1 AND ps.in_store = 0 AND ps.number_on_hand >= 1;

    -- Step 2: ตัดสต็อกคลังออนไลน์ลง 1 ชิ้น
    UPDATE dbo.product_stocked
    SET number_on_hand = number_on_hand - 1
    WHERE SKU = 'SKU-WHSE-000001' AND in_store = 0;

    -- Step 3: บันทึกคำสั่งซื้อของคนที่ 2
    INSERT INTO dbo.web_sale (
        web_sale_numb, web_sale_date, web_customer_numb, web_credit_card_numb,
        web_sale_total, web_sale_merchandise_total, web_sale_shipping, web_sale_tax
    ) VALUES (6002, CAST(GETDATE() AS DATE), 3001, '4999888877776666', @PromoPrice2 + 26.60, @PromoPrice2, 15.00, 11.60);

    INSERT INTO dbo.web_sale_item (
        web_sale_numb, web_sale_SKU, web_sale_quantity, web_sale_shipped,
        web_sale_price, web_shipping_address_numb, web_sale_date_shipped
    ) VALUES (6002, 'SKU-WHSE-000001', 1, 0, @PromoPrice2, 4001, NULL);

    -- Step 4: คนที่ 2 ชำระเงินสำเร็จ -> COMMIT จบ Transaction สต็อกลดจริง!
    IF @Buyer2Paid = 0
        THROW 50016, 'ลูกค้าคนที่ 2 ไม่ชำระเงิน', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
*/

-- ----------------------------------------------------------------------------
-- Transaction 6: การสั่งซื้อสินค้าออนไลน์ผ่านเว็บไซต์ด้วยบัตรเครดิตแบบ Step-by-Step
-- (Step 1: ล็อกและตัดสต็อกคลังเว็บ -> Step 2: สร้างหัวบิลและรายการสั่งซื้อ -> Step 3: ตรวจสอบวันหมดอายุบัตรและการตัดเงิน
--  -> ถ้าบัตรไม่ผ่านหรือไม่จ่ายเงิน จะ ROLLBACK คืนสต็อกคลังออนไลน์กลับเท่าเดิม)
-- ----------------------------------------------------------------------------
/*
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRY
    BEGIN TRANSACTION;

    -- Step 1 (1.4.13): ล็อกแถวสต็อกคลังออนไลน์ (UPDLOCK, ROWLOCK) และตัดสต็อกลง 1 ชิ้น
    UPDATE dbo.product_stocked WITH (UPDLOCK, ROWLOCK)
    SET number_on_hand = number_on_hand - 1
    WHERE SKU = 'SKU-WHSE-000001' AND in_store = 0 AND number_on_hand >= 1;

    IF @@ROWCOUNT = 0
        THROW 50006, 'สต็อกสินค้าในคลังออนไลน์ไม่เพียงพอ', 1;

    -- Step 2 (1.4.8): เพิ่มหัวคำสั่งซื้อออนไลน์และรายการสินค้า
    INSERT INTO dbo.web_sale (
        web_sale_numb, web_sale_date, web_customer_numb, web_credit_card_numb,
        web_sale_total, web_sale_merchandise_total, web_sale_shipping, web_sale_tax
    ) VALUES (6003, CAST(GETDATE() AS DATE), 3001, '4999888877776666', 229.50, 200.00, 15.00, 14.50);

    INSERT INTO dbo.web_sale_item (
        web_sale_numb, web_sale_SKU, web_sale_quantity, web_sale_shipped,
        web_sale_price, web_shipping_address_numb, web_sale_date_shipped
    ) VALUES (6003, 'SKU-WHSE-000001', 1, 0, 200.00, 4001, NULL);

    -- Step 3: ตรวจสอบว่าบัตรเครดิตที่ผูกไว้ยังไม่หมดอายุ
    IF NOT EXISTS (
        SELECT 1 FROM dbo.web_customer_credit_card
        WHERE web_customer_numb = 3001
          AND web_credit_card_numb = '4999888877776666'
          AND web_credit_card_exp_date >= CAST(GETDATE() AS DATE)
    )
    BEGIN
        THROW 50017, 'บัตรเครดิตหมดอายุหรือไม่ถูกต้อง ระบบ Rollback คืนสต็อกคลังออนไลน์กลับเท่าเดิม', 1;
    END

    -- Step 4: ยืนยันคำสั่งซื้อสำเร็จ
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
*/

-- ----------------------------------------------------------------------------
-- Transaction 7: การตรวจสอบออเดอร์เว็บผ่าน View ปกป้องข้อมูลบัตร และยกเลิกออเดอร์ที่ยังไม่จัดส่งพร้อมคืนสต็อกแบบ Step-by-Step
-- (Step 1: ตรวจสอบออเดอร์ผ่าน vw_Safe_Web_Shipping_Address และล็อกแถวรายการสั่งซื้อด้วย UPDLOCK
--  -> Step 2: คืนสต็อกกลับเข้าคลังออนไลน์ -> Step 3: ลบรายการและปรับยอดบิล
--  -> ถ้าคลังสินค้ากดส่งของไปแล้ว (web_sale_shipped = 1) จะ ROLLBACK ไม่ให้ยกเลิกและไม่คืนสต็อกซ้ำ!)
-- ----------------------------------------------------------------------------
-- 1.4.4 ดูรายการสั่งซื้อเว็บผ่าน View ที่บังเลขบัตร 12 หลักแรกและซ่อนบ้านเลขที่
SELECT 
    web_sale_numb, web_sale_date, web_customer_numb, masked_credit_card_numb,
    web_sale_total, web_sale_SKU, web_sale_quantity, web_sale_shipped,
    web_sale_date_shipped, web_customer_shipping_state_code, web_customer_shipping_zip
FROM dbo.vw_Safe_Web_Shipping_Address
WHERE web_sale_numb = 6001;

/*
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @CancelQty INT;
    DECLARE @ShippedFlag BIT;

    -- Step 1 (1.4.4): ล็อกแถวรายการสั่งซื้อเว็บ (UPDLOCK, ROWLOCK) ป้องกันคลังสินค้ากดส่งของสวนทางขณะกำลังยกเลิก
    SELECT @CancelQty = web_sale_quantity,
           @ShippedFlag = web_sale_shipped
    FROM dbo.web_sale_item WITH (UPDLOCK, ROWLOCK)
    WHERE web_sale_numb = 6001 AND web_sale_SKU = 'SKU-WHSE-000001';

    IF @CancelQty IS NULL
        THROW 50007, 'ไม่พบรายการสั่งซื้อที่ต้องการยกเลิก', 1;

    -- Step 2: คืนสต็อกกลับเข้าคลังออนไลน์ชั่วคราว
    UPDATE dbo.product_stocked WITH (ROWLOCK)
    SET number_on_hand = number_on_hand + @CancelQty
    WHERE SKU = 'SKU-WHSE-000001' AND in_store = 0;

    -- Step 3: ตรวจสอบสถานะการจัดส่ง (ถ้าส่งออกไปแล้ว ห้ามยกเลิก -> Rollback ดึงสต็อกกลับทันที!)
    IF @ShippedFlag = 1
        THROW 50018, 'ไม่สามารถยกเลิกออเดอร์ได้เนื่องจากสินค้าถูกจัดส่งออกไปแล้ว -> ระบบ Rollback คืนค่าสต็อกเดิม', 1;

    DELETE FROM dbo.web_sale_item
    WHERE web_sale_numb = 6001 AND web_sale_SKU = 'SKU-WHSE-000001';

    UPDATE dbo.web_sale
    SET web_sale_merchandise_total = 0.00,
        web_sale_shipping = 0.00,
        web_sale_tax = 0.00,
        web_sale_total = 0.00
    WHERE web_sale_numb = 6001;

    -- Step 4: ยืนยันการยกเลิกและคืนสต็อกสำเร็จ
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
*/

-- ----------------------------------------------------------------------------
-- Transaction 8: การบรรจุพนักงานใหม่ทดแทน เลื่อนตำแหน่งผู้จัดการแผนก และตรวจสอบเพดานงบประมาณแบบ Step-by-Step [มีใน Java]
-- (แก้ไขตามคอมเมนต์อาจารย์:
--   • Step 1: ล็อกแถวแผนกและพนักงาน (UPDLOCK, ROWLOCK) ป้องกัน HR อีกคนแก้ไขแผนกเดียวกันชนกัน
--   • Step 2 (1.4.9): บรรจุพนักงานใหม่รหัส 1003 เข้าแผนกเพื่อรับช่วงงานต่อ
--   • Step 3 (1.4.14): ปรับอัตราค่าจ้างพนักงานรหัส 1002 และเปลี่ยนรหัสผู้จัดการแผนกในตาราง department
--   • Step 4: ตรวจสอบเพดานงบประมาณและการอนุมัติคำสั่งแต่งตั้ง
--             ถ้าผ่าน -> COMMIT / ถ้าไม่ผ่านหรือเกินงบ -> ROLLBACK กลับสู่สถานะเดิมทั้งหมด!)
-- ----------------------------------------------------------------------------
-- 1.4.5 ดูข้อมูลพนักงานและผู้จัดการแผนกปัจจุบัน
SELECT 
    e.employee_id, e.employee_first_name, e.employee_last_name,
    e.dept_numb, e.store_numb, e.supervisor_id, e.pay_type_code, e.pay_rate,
    d.dept_manager_id
FROM dbo.employee e
LEFT JOIN dbo.department d ON e.dept_numb = d.dept_numb AND e.store_numb = d.store_numb;

/*
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @IsHRDirectorApproved BIT = 1; -- 1 = อนุมัติคำสั่งแต่งตั้ง (COMMIT), 0 = ไม่อนุมัติ (ROLLBACK ทุกขั้นตอน)

    -- Step 1 (1.4.5): ล็อกแถวแผนก 10 สาขา 101 และพนักงานรหัส 1002 (UPDLOCK, ROWLOCK)
    -- ป้องกันเจ้าหน้าที่ HR อีกเครื่องกดเปลี่ยนผู้จัดการแผนกหรือปรับเงินเดือนซ้ำซ้อนในเวลาเดียวกัน
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.department d WITH (UPDLOCK, ROWLOCK)
        JOIN dbo.employee e WITH (UPDLOCK, ROWLOCK)
            ON d.dept_numb = e.dept_numb AND d.store_numb = e.store_numb
        WHERE d.dept_numb = 10 AND d.store_numb = 101 AND e.employee_id = 1002
    )
    BEGIN
        THROW 50008, 'ไม่พบพนักงานรหัส 1002 ในแผนก 10 สาขา 101', 1;
    END

    -- Step 2 (1.4.9): บรรจุพนักงานใหม่รหัส 1003 (Charlie Davis) เข้ามาทดแทนในแผนก 10 สาขา 101
    INSERT INTO dbo.employee (
        employee_id, employee_first_name, employee_last_name, employee_street,
        employee_city, employee_state_code, employee_zip, employee_phone,
        employee_ssn, employee_birth_date, dept_numb, store_numb, supervisor_id,
        pay_type_code, pay_rate
    ) VALUES (
        1003, 'Charlie', 'Davis', '88 Pine St', 'San Francisco', 'CA', '94103',
        '415-555-1003', '333-33-3333', '1998-03-15', 10, 101, 1002, 2, 22.00
    );

    -- Step 3 (1.4.14): ปรับอัตราค่าจ้างให้พนักงานรหัส 1002 และแต่งตั้งเป็นผู้จัดการแผนกในตาราง department
    UPDATE dbo.employee
    SET dept_numb = 10,
        store_numb = 101,
        pay_rate = 25.00
    WHERE employee_id = 1002;

    UPDATE dbo.department
    SET dept_manager_id = 1002
    WHERE dept_numb = 10 AND store_numb = 101;

    -- Step 4: ตรวจสอบการอนุมัติคำสั่งและเพดานอัตราค่าจ้างรายชั่วโมงของแผนก (ต้องไม่เกิน 100.00 ต่อชั่วโมง)
    IF @IsHRDirectorApproved = 0 OR EXISTS (
        SELECT 1 FROM dbo.employee
        WHERE dept_numb = 10 AND store_numb = 101 AND pay_type_code = 2
        GROUP BY dept_numb, store_numb
        HAVING SUM(pay_rate) > 100.00
    )
    BEGIN
        THROW 50019, 'ไม่อนุมัติคำสั่งหรือเกินเพดานงบประมาณแผนก -> ระบบ ROLLBACK ยกเลิกทั้งพนักงานใหม่ การปรับเงินเดือน และผู้จัดการแผนกกลับสู่ค่าเดิม!', 1;
    END

    -- Step 5: ยืนยันคำสั่งบรรจุและแต่งตั้งผู้จัดการแผนกสำเร็จ
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
*/
