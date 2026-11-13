USE SmartMartDB;
GO

-- ============================================================================
-- สคริปต์ทดสอบสิทธิ์ (EXECUTE AS USER) และตรวจสอบผลลัพธ์หลังรัน Java
-- แบ่งตามผู้รับผิดชอบ (รันใน SSMS หลังสร้างฐานข้อมูลจากไฟล์ 01 เสร็จแล้ว)
-- ============================================================================

-- [1. Bam] ทดสอบสิทธิ์ HR (ต้องดู employee ได้ แต่ดูตารางขายไม่ได้)
EXECUTE AS USER = 'User_HR';
    SELECT * FROM dbo.employee;
    SELECT * FROM dbo.in_store_sale; -- คาดหวัง: ถูกปฏิเสธสิทธิ์ (Permission Denied)
REVERT;
GO

-- [2. Dream] ทดสอบสิทธิ์ Web Sale App (ต้องดู View สินค้าเว็บได้ แต่ดูข้อมูลพนักงานไม่ได้)
EXECUTE AS USER = 'User_Web_Sale_App';
    SELECT * FROM dbo.vw_Web_Product_Promo;
    SELECT * FROM dbo.employee;      -- คาดหวัง: ถูกปฏิเสธสิทธิ์ (Permission Denied)
REVERT;
GO

-- [3. Path] ทดสอบสิทธิ์ Manager (ดู View ที่ซ่อนเลขบัตรและที่อยู่ได้ แต่ดูตารางบัตรเครดิตตรงๆ ไม่ได้)
EXECUTE AS USER = 'User_Manager';
    SELECT * FROM dbo.vw_Safe_Web_Shipping_Address;
    SELECT * FROM dbo.web_customer_credit_card; -- คาดหวัง: ถูกปฏิเสธสิทธิ์ (Permission Denied)
REVERT;
GO

-- [4. Path] ตรวจสอบที่อยู่ลูกค้าหลังรันโค้ด Java (Tx4_UpdateShippingAndMask_Path)
-- คาดหวัง: web_shipping_street ของ address 4001 ต้องเปลี่ยนเป็น '*** MASKED ***'
SELECT web_shipping_address_numb, web_customer_numb, web_shipping_street,
       web_customer_shipping_city, web_customer_shipping_state_code, web_customer_shipping_zip
FROM dbo.web_sale_shipping_address;
GO
