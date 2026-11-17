USE SmartMartDB;
GO

-- ============================================================================
-- สคริปต์ทดสอบสิทธิ์ตามหลักการทำงานจริง (EXECUTE AS USER)
-- 1) การเข้าถึงข้อมูลพนักงาน (employee) พร้อม Dynamic Data Masking (SSN & เงินเดือน)
-- 2) การ Isolate ข้อมูลใน Materialized Views แยกตามช่องทางหน้าร้าน vs ออนไลน์
-- 3) การจำลอง Step-by-Step Transaction (แย่งซื้อของ -> คนแรกไม่จ่าย Rollback -> คนที่ 2 ซื้อต่อ Commit)
-- ============================================================================

-- [1] ทดสอบสิทธิ์ HR (User_HR):
-- • มีสิทธิ์ UNMASK จึงเห็นข้อมูลพนักงาน (employee) ครบทุกคอลัมน์รวมถึง SSN จริงและเงินเดือนจริง และดูตารางแผนกได้
-- • แต่ถูกบล็อกจากตารางการขาย (in_store_sale)
EXECUTE AS USER = 'User_HR';
    SELECT * FROM dbo.employee;
    SELECT * FROM dbo.department;
    SELECT * FROM dbo.in_store_sale; -- คาดหวัง: Permission Denied
REVERT;
GO

-- [2] ทดสอบสิทธิ์ พนักงานทั่วไป (User_Staff) และ หัวหน้างาน (User_Supervisor):
-- • สามารถรัน SELECT * FROM dbo.employee และ vw_Employee_Directory เพื่อดูข้อมูลพนักงานด้วยกันได้ตามการทำงานจริง!
--   โดยระบบจะบังเลข SSN เป็น 'XXX-XX-XXXX' และบังเงินเดือน pay_rate เป็น 0.00 อัตโนมัติ (Dynamic Data Masking)
-- • ดูสต็อกหน้าร้านผ่าน Materialized View ที่ Isolate เฉพาะหน้าร้านได้
-- • แต่ถ้าพยายามแก้ไขเงินเดือนพนักงาน (UPDATE dbo.employee) หรือดูสต็อกคลังเว็บ จะถูกบล็อก!
EXECUTE AS USER = 'User_Staff';
    SELECT * FROM dbo.employee; -- สำเร็จ! เห็นข้อมูลพนักงาน แต่ employee_ssn ถูกบังเป็น XXX-XX-1111 และ pay_rate เป็น 0.00
    SELECT * FROM dbo.vw_Employee_Directory;
    SELECT * FROM dbo.vw_Materialized_InStore_Available_Inventory WITH (NOEXPAND);
    UPDATE dbo.employee SET pay_rate = 99999.00 WHERE employee_id = 1002; -- คาดหวัง: Permission Denied (ห้ามแก้เงินเดือน)
REVERT;
GO

-- [3] ทดสอบสิทธิ์ Web Sale App (User_Web_Sale_App):
-- • ดูสินค้าโปรโมชั่นเว็บ (vw_Web_Product_Promo) และสต็อกคลังเว็บที่ถูก Isolate ไว้ (vw_Materialized_Web_Available_Inventory) ได้
-- • แต่ถูกบล็อกไม่ให้ดูสต็อกหน้าร้าน (vw_Materialized_InStore_Available_Inventory) และบล็อกตารางพนักงาน (employee)
EXECUTE AS USER = 'User_Web_Sale_App';
    SELECT * FROM dbo.vw_Web_Product_Promo;
    SELECT * FROM dbo.vw_Materialized_Web_Available_Inventory WITH (NOEXPAND);
    SELECT * FROM dbo.vw_Materialized_InStore_Available_Inventory WITH (NOEXPAND); -- คาดหวัง: Permission Denied (Isolate สต็อกหน้าร้านออกจากเว็บ)
    SELECT * FROM dbo.employee; -- คาดหวัง: Permission Denied (แอปภายนอกห้ามแตะข้อมูลพนักงาน)
REVERT;
GO

-- [4] ทดสอบสิทธิ์ Manager (User_Manager):
-- • เข้าถึงตารางพนักงาน (SELECT * FROM dbo.employee) เพื่อบริหารทีมได้ (โดย SSN ถูกบังอัตโนมัติ)
-- • ดูออเดอร์เว็บผ่าน View ที่ซ่อนเลขบัตร 12 หลักแรก (vw_Safe_Web_Shipping_Address) และดูสรุปสต็อกรวมผ่าน Materialized View ได้
-- • แต่ดูตารางบัตรเครดิตจริง (web_customer_credit_card) ไม่ได้
EXECUTE AS USER = 'User_Manager';
    SELECT * FROM dbo.employee;
    SELECT * FROM dbo.vw_Safe_Web_Shipping_Address;
    SELECT * FROM dbo.vw_Materialized_Available_Inventory WITH (NOEXPAND);
    SELECT * FROM dbo.web_customer_credit_card; -- คาดหวัง: Permission Denied
REVERT;
GO

-- [5] ทดสอบ Step-by-Step Transaction (Tx 5):
-- จำลองลูกค้า 2 คนแย่งกันซื้อสินค้าโปรโมชั่นออนไลน์:
-- • คนที่ 1 กดซื้อ ล็อกสต็อก (UPDLOCK, ROWLOCK) ตัดสต็อกลงชั่วคราว และเปิดใบสั่งซื้อรอจ่ายเงิน
--   แต่สุดท้าย "ไม่จ่ายเงิน" -> ระบบ ROLLBACK ทั้งใบสั่งซื้อและสต็อกเด้งกลับมาเท่าเดิม (100 ชิ้น)
-- • คนที่ 2 ที่รอคิวอยู่ เด้งเข้ามาทำ Transaction ต่อทันที ตัดสต็อก เปิดบิล และจ่ายเงินสำเร็จ -> ระบบ COMMIT
SELECT SKU, number_on_hand AS [สต็อกก่อนเริ่ม] FROM dbo.product_stocked WHERE SKU = 'SKU-WHSE-000001';

-- 5A: คนที่ 1 กดซื้อ ล็อกของ เปิดบิลรอจ่าย แต่ไม่จ่ายเงิน -> ROLLBACK
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Buyer1Paid BIT = 0;

    -- Step 1 & 2: ล็อกและตัดสต็อกคลังออนไลน์ชั่วคราว
    UPDATE dbo.product_stocked WITH (UPDLOCK, ROWLOCK)
    SET number_on_hand = number_on_hand - 1
    WHERE SKU = 'SKU-WHSE-000001' AND in_store = 0 AND number_on_hand >= 1;

    -- Step 3: สร้างหัวบิลและรายการสินค้ารอชำระเงิน
    INSERT INTO dbo.web_sale (
        web_sale_numb, web_sale_date, web_customer_numb, web_credit_card_numb,
        web_sale_total, web_sale_merchandise_total, web_sale_shipping, web_sale_tax
    ) VALUES (6099, CAST(GETDATE() AS DATE), 3001, '4999888877776666', 186.60, 160.00, 15.00, 11.60);

    INSERT INTO dbo.web_sale_item (
        web_sale_numb, web_sale_SKU, web_sale_quantity, web_sale_shipped,
        web_sale_price, web_shipping_address_numb, web_sale_date_shipped
    ) VALUES (6099, 'SKU-WHSE-000001', 1, 0, 160.00, 4001, NULL);

    SELECT SKU, number_on_hand AS [สต็อกระหว่างรอคนที่_1_จ่ายเงิน] FROM dbo.product_stocked WHERE SKU = 'SKU-WHSE-000001';

    -- Step 4: คนที่ 1 ไม่จ่ายเงิน -> โยนเข้า CATCH เพื่อ ROLLBACK
    IF @Buyer1Paid = 0
        THROW 50015, 'คนที่ 1 ไม่ชำระเงิน -> ROLLBACK ยกเลิกบิลและคืนสต็อกกลับเท่าเดิม ส่งคิวให้คนที่ 2 ทันที!', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    SELECT ERROR_MESSAGE() AS [ผลลัพธ์คนที่_1];
END CATCH;

SELECT SKU, number_on_hand AS [สต็อกหลังคนที่_1_Rollback_เด้งกลับเท่าเดิม] FROM dbo.product_stocked WHERE SKU = 'SKU-WHSE-000001';

-- 5B: คนที่ 2 เด้งเข้ามาทำ Transaction ต่อทันทีและจ่ายเงินสำเร็จ -> COMMIT
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Buyer2Paid BIT = 1;

    UPDATE dbo.product_stocked WITH (UPDLOCK, ROWLOCK)
    SET number_on_hand = number_on_hand - 1
    WHERE SKU = 'SKU-WHSE-000001' AND in_store = 0 AND number_on_hand >= 1;

    INSERT INTO dbo.web_sale (
        web_sale_numb, web_sale_date, web_customer_numb, web_credit_card_numb,
        web_sale_total, web_sale_merchandise_total, web_sale_shipping, web_sale_tax
    ) VALUES (6099, CAST(GETDATE() AS DATE), 3001, '4999888877776666', 186.60, 160.00, 15.00, 11.60);

    INSERT INTO dbo.web_sale_item (
        web_sale_numb, web_sale_SKU, web_sale_quantity, web_sale_shipped,
        web_sale_price, web_shipping_address_numb, web_sale_date_shipped
    ) VALUES (6099, 'SKU-WHSE-000001', 1, 0, 160.00, 4001, NULL);

    IF @Buyer2Paid = 0
        THROW 50016, 'คนที่ 2 ไม่ชำระเงิน', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
END CATCH;

SELECT SKU, number_on_hand AS [สต็อกหลังคนที่_2_จ่ายเงินสำเร็จ_Commit] FROM dbo.product_stocked WHERE SKU = 'SKU-WHSE-000001';
GO

-- [6] ตรวจสอบที่อยู่ลูกค้าหลังรัน Transaction อัปเดตส่งของและซ่อนบ้านเลขที่ (*** MASKED ***)
SELECT web_shipping_address_numb, web_customer_numb, web_shipping_street,
       web_customer_shipping_city, web_customer_shipping_state_code, web_customer_shipping_zip
FROM dbo.web_sale_shipping_address;
GO
