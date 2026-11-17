# SmartMart Project 3

> สามารถดูไฟล์ฉบับสมบูรณ์เพิ่มเติมได้ที่โฟลเดอร์ `EX final version/` และดูโจทย์/แผนภาพได้ที่ `Assignment/` และ `ER/`

---

## 1. โครงสร้างโฟลเดอร์

* **`01_SQL/`**
  * `01_SmartMart_Main_Core_และ_8Transactions.sql` — ไฟล์ SQL หลัก (DB + Snapshot Isolation + 18 ตาราง + Sample Data + 3 Non-Materialized Views + 3 Materialized Views ที่ Isolate ข้อมูลแยกตามช่องทาง/สิทธิ์ + 3 Clustered Indexes + 3 Non-Clustered Covering Indexes + 7 Roles/Logins + 8 Transactions แบบ Atomic `BEGIN TRY ... BEGIN TRANSACTION ... COMMIT / ROLLBACK`)
  * `02_Test_Privileges_และ_CheckResult.sql` — สคริปต์ทดสอบสิทธิ์ `EXECUTE AS USER` (ตรวจการเข้าถึง `employee`, การ Isolate ข้อมูลใน Materialized Views, และตรวจผล Mask ที่อยู่หลังรัน Transaction)
* **`02_Java_Eclipse/`**
  * `lib/mssql-jdbc-12.8.1.jre11.jar` — ไดรเวอร์ JDBC สำหรับ SQL Server
  * `src/com/smartmart/db/` — โค้ด Java (รวมทั้งหมดไว้ด้วยกัน):
    * `TestTransactions.java` (**ไฟล์ Main กลาง — กดรันที่ไฟล์นี้**, รวมการทดสอบ Transactions และ `testDirtyRead()` บน Materialized View)
    * `SmartMartTransactions.java` (รวมเมธอด Transactions 1, 2, 3, 4, 5, 8)

---

## 2. รายการ 8 Transactions (เรียงตามลำดับ 1–8)

| ลำดับ | Transaction | ไฟล์ SQL (`01_SmartMart...sql`) | ไฟล์ Java / เทสต์สิทธิ์ |
| :---: | :--- | :--- | :--- |
| **1** | การคืนสินค้าที่ซื้อภายใน 15 วัน | `1.4.3`, `1.4.11`, `1.4.15` (`REPEATABLE READ`) | `SmartMartTransactions.java` (`returnMerchandiseWithin15Days`) |
| **2** | การสั่งซื้อสินค้าแบบจ่ายด้วยเครดิตการ์ด | `1.4.6`, `1.4.10` (`READ COMMITTED`) | `SmartMartTransactions.java` (`purchaseWithCreditCardInStore`) |
| **3** | การค้นหาสินค้าที่พร้อมจำหน่ายว่าอยู่ที่ Stores หรือ Warehouses ไหน | `1.4.1` + `vw_Materialized_Available_Inventory WITH (NOEXPAND)` | `SmartMartTransactions.java` (`checkAvailableStock`) |
| **4** | การอัปเดตสถานะการจัดส่งพร้อมซ่อนที่อยู่จัดส่งของลูกค้า | `1.4.7`, `1.4.12` (`REPEATABLE READ`) | `SmartMartTransactions.java` (`updateShippingStatusAndMaskAddress`) |
| **5** | การเปิดแคมเปญโปรโมชั่น ปรับราคาขายออนไลน์ และดึงข้อมูลสินค้าขึ้นแสดงผลบนเว็บ | `UPDATE sales_promotion / product / product_stocked` + `1.4.2` (`REPEATABLE READ`) | `SmartMartTransactions.java` (`launchWebPromotionAndFetchCatalog`) + เทสต์สิทธิ์ `User_Web_Sale_App` |
| **6** | การสั่งซื้อสินค้าออนไลน์ผ่านเว็บไซต์ด้วยบัตรเครดิต | `1.4.8`, `1.4.13` (`READ COMMITTED`) | มีใน SQL Transaction Block |
| **7** | การตรวจสอบรายการสั่งซื้อออนไลน์และสต็อกคลังเว็บแบบปกป้องข้อมูลบัตรและที่อยู่ | `1.4.4` (`vw_Safe_Web_Shipping_Address`) + `vw_Materialized_Web_Available_Inventory` | เทสต์สิทธิ์ `User_Manager` |
| **8** | การบรรจุพนักงานใหม่ทดแทน และเลื่อนตำแหน่งพนักงานเดิมเป็นผู้จัดการแผนกพร้อมปรับฐานเงินเดือนฝ่าย HR | `1.4.5`, `1.4.9`, `1.4.14` + `UPDATE department` (`REPEATABLE READ`) | `SmartMartTransactions.java` (`promoteEmployeeAndAssignDeptManager`) + เทสต์สิทธิ์ `User_HR` |

---

## 3. ลำดับการรันทดสอบ
1. รันไฟล์ `01_SQL/01_SmartMart_Main_Core_และ_8Transactions.sql` ใน **SSMS** เพื่อสร้างฐานข้อมูล `SmartMartDB`
2. รันทดสอบสิทธิ์ใน `01_SQL/02_Test_Privileges_และ_CheckResult.sql` (ส่วนที่ 1–4)
3. เปิด Eclipse แล้วกด **File** $\rightarrow$ **Open Projects from File System...** $\rightarrow$ เลือกโฟลเดอร์ `SmartMart_Team_Work/02_Java_Eclipse` จากนั้นคลิกขวาที่ **`TestTransactions.java`** $\rightarrow$ **Run As** $\rightarrow$ **Java Application**
4. กลับมารันส่วนที่ 5 ของ `02_Test_Privileges_และ_CheckResult.sql` ใน SSMS เพื่อตรวจว่าที่อยู่ลูกค้าถูก Mask เป็น `'*** MASKED ***'` แล้ว
