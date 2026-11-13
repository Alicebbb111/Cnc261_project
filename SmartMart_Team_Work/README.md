# SmartMart Team Work (พื้นที่ทำงานสำหรับทีม 4 คน)

> **คำแนะนำก่อนเริ่ม:** สามารถเปิดดูแนวทางฉบับสมบูรณ์ได้ที่โฟลเดอร์ `EX final version/` และดูโจทย์/โครงสร้างตารางได้ที่ `โจทย์/` และ `ER/`

---

## 1. โครงสร้างโฟลเดอร์ในส่วนที่ต้องทำ

* **`01_SQL/`**
  * `01_SmartMart_Main_Core_และ_8Transactions.sql` — ไฟล์ SQL หลัก (ส่วนบนมี DB + 18 ตาราง + Sample Data + 3 Views + 3 Indexes + 7 Roles/Logins ครบแล้ว ส่วนล่างเว้นช่อง 8 Transactions ให้แต่ละคนเติม)
  * `02_Test_Privileges_และ_CheckResult.sql` — สคริปต์ทดสอบสิทธิ์ `EXECUTE AS USER` (Bam, Dream, Path) และตรวจผล Mask ที่อยู่หลังรัน Java
* **`02_Java_Eclipse/`**
  * `lib/mssql-jdbc-12.8.1.jre11.jar` — ไดรเวอร์ JDBC สำหรับ SQL Server
  * `src/com/smartmart/db/` — โค้ด Java แยกตามชื่อคน:
    * `TestTransactions_Main.java` (**ไฟล์ Main กลาง — กดรันที่ไฟล์นี้**)
    * `Tx1_ReturnMerchandise_Art.java` (ของ **Art**)
    * `Tx2_PurchaseCreditCard_Bam.java` (ของ **Bam**)
    * `Tx3_CheckAvailableStock_Dream.java` (ของ **Dream**)
    * `Tx4_UpdateShippingAndMask_Path.java` (ของ **Path**)
    * `ConcurrencyTest_Bam_Dream.java` (ทดสอบ Dirty Read ของ **Bam + Dream**)

---

## 2. รายการ 8 Transactions (เรียงตามลำดับ 1–8) และผู้รับผิดชอบ

| ลำดับ | Transaction | ผู้รับผิดชอบ | ไฟล์ SQL (`01_SmartMart...sql`) | ไฟล์ Java / เทสต์สิทธิ์ |
| :---: | :--- | :---: | :--- | :--- |
| **1** | การคืนสินค้าที่ซื้อภายใน 15 วัน | **Art** | `1.4.3`, `1.4.11`, `1.4.15` | `Tx1_ReturnMerchandise_Art.java` (`returnMerchandiseWithin15Days`) |
| **2** | การสั่งซื้อสินค้าแบบจ่ายด้วยเครดิตการ์ด | **Bam** | `1.4.6`, `1.4.10` | `Tx2_PurchaseCreditCard_Bam.java` (`purchaseWithCreditCardInStore`) |
| **3** | การค้นหาสินค้าที่พร้อมจำหน่ายว่าอยู่ที่ Stores หรือ Warehouses ไหน | **Dream** | `1.4.1` | `Tx3_CheckAvailableStock_Dream.java` (`checkAvailableStock`) |
| **4** | การอัปเดตสถานะการจัดส่งพร้อมซ่อนที่อยู่จัดส่งของลูกค้า | **Path** | `1.4.7`, `1.4.12` | `Tx4_UpdateShippingAndMask_Path.java` (`updateShippingStatusAndMaskAddress`) |
| **5** | การดึงข้อมูลสินค้าและโปรโมชั่นลดราคาสำหรับแสดงผลบนระบบขายออนไลน์ | **Dream** | `1.4.2` + `vw_Web_Product_Promo` | เทสต์สิทธิ์ `User_Web_Sale_App` ใน `02_Test_Privileges...sql` |
| **6** | การสั่งซื้อสินค้าออนไลน์ผ่านเว็บไซต์ด้วยบัตรเครดิต | **Art** | `1.4.8`, `1.4.13` | — *(มีใน SQL & รายงาน)* |
| **7** | การตรวจสอบรายการสั่งซื้อออนไลน์และสถานะจัดส่งแบบปกป้องข้อมูลบัตรและที่อยู่ | **Path** | `1.4.4` + `vw_Safe_Web_Shipping_Address` | เทสต์สิทธิ์ `User_Manager` + ตรวจผล `*** MASKED ***` ใน `02_Test_Privileges...sql` |
| **8** | การจัดการและตรวจสอบข้อมูลประวัติและอัตราค่าจ้างของพนักงานฝ่าย HR | **Bam** | `1.4.5`, `1.4.9`, `1.4.14` + `Role_HR` | เทสต์สิทธิ์ `User_HR` ใน `02_Test_Privileges...sql` |

*(ส่วน `ConcurrencyTest_Bam_Dream.java` ใช้ `Login_InStore_Sale_App` ของ **Bam** กับ `Login_Staff` ของ **Dream** ทดสอบป้องกัน Dirty Read ร่วมกัน)*

---

## 3. ลำดับการรันทดสอบ
1. รันไฟล์ `01_SQL/01_SmartMart_Main_Core_และ_8Transactions.sql` ใน **SSMS** เพื่อสร้างฐานข้อมูล `SmartMartDB`
2. รันทดสอบสิทธิ์ใน `01_SQL/02_Test_Privileges_และ_CheckResult.sql` (ส่วนที่ 1–3)
3. เปิด Eclipse (เลือก Workspace เป็นโฟลเดอร์ว่างที่ใดก็ได้ เช่น `eclipse-workspace`) แล้วกด **File** $\rightarrow$ **Open Projects from File System...** $\rightarrow$ เลือกโฟลเดอร์ `SmartMart_Team_Work/02_Java_Eclipse` (ตั้งค่า `.project` และ Build Path `mssql-jdbc-12.8.1.jre11.jar` ไว้ให้แล้ว) จากนั้นคลิกขวาที่ **`TestTransactions_Main.java`** $\rightarrow$ **Run As** $\rightarrow$ **Java Application**
4. กลับมารันส่วนที่ 4 ของ `02_Test_Privileges_และ_CheckResult.sql` ใน SSMS เพื่อตรวจว่าที่อยู่ลูกค้าถูก Mask เป็น `'*** MASKED ***'` แล้ว
