USE SmartMartDB;
GO

-- 1. ทดสอบสิทธิ์ HR (ดู employee ได้ แต่ดูตารางขายไม่ได้)
EXECUTE AS USER = 'User_HR';
    SELECT * FROM dbo.employee;
    SELECT * FROM dbo.in_store_sale;
REVERT;
GO

-- 2. ทดสอบสิทธิ์ Web Sale App (ดู View สินค้าเว็บได้ แต่ดูข้อมูลพนักงานไม่ได้)
EXECUTE AS USER = 'User_Web_Sale_App';
    SELECT * FROM dbo.vw_Web_Product_Promo;
    SELECT * FROM dbo.employee;
REVERT;
GO

-- 3. ทดสอบสิทธิ์ Manager (ดู View ที่ซ่อนเลขบัตรและที่อยู่ได้ แต่ดูตารางบัตรเครดิตตรงๆ ไม่ได้)
EXECUTE AS USER = 'User_Manager';
    SELECT * FROM dbo.vw_Safe_Web_Shipping_Address;
    SELECT * FROM dbo.web_customer_credit_card;
REVERT;
GO

-- 4. ตรวจสอบที่อยู่ลูกค้าหลังรันโค้ด Java ซ่อนบ้านเลขที่ (*** MASKED ***)
SELECT web_shipping_address_numb, web_customer_numb, web_shipping_street,
       web_customer_shipping_city, web_customer_shipping_state_code, web_customer_shipping_zip
FROM dbo.web_sale_shipping_address;
GO
