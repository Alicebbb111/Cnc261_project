package com.smartmart.db;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Date;
import java.sql.DriverManager;
import java.sql.Timestamp;

/**
 * ไฟล์ Main กลางสำหรับเรียกใช้งาน Transaction ทั้ง 4 คลาส และ ConcurrencyTest
 * กดรันทดสอบที่ไฟล์นี้ไฟล์เดียว (Run As -> Java Application)
 */
public class TestTransactions_Main {

    private static final String URL = "jdbc:sqlserver://localhost:1433;databaseName=SmartMartDB;encrypt=true;trustServerCertificate=true;";

    public static void main(String[] args) {
        try {
            System.out.println("--- 1. ทดสอบรัน Transactions ทั้ง 4 คลาส ---");

            // 1. [Dream] ค้นหาสินค้าพร้อมจำหน่าย (Login_Staff)
            try (Connection conn = DriverManager.getConnection(URL, "Login_Staff", "Password_Stf_2026!")) {
                Tx3_CheckAvailableStock_Dream.checkAvailableStock(conn, "UPC000000000001");
            }

            // 2. [Bam] สั่งซื้อสินค้าด้วยบัตรเครดิต (Login_InStore_Sale_App)
            try (Connection conn = DriverManager.getConnection(URL, "Login_InStore_Sale_App", "Password_InStoreApp_2026!")) {
                Tx2_PurchaseCreditCard_Bam.purchaseWithCreditCardInStore(
                        conn, 5002, new Date(System.currentTimeMillis()),
                        "SKU-STORE-00001", 1, new BigDecimal("200.00"), new BigDecimal("14.50"),
                        2, "4111222233339999", Date.valueOf("2029-12-31"), "SOMCHAI JAIDEE"
                );
            }

            // 3. [Art] คืนสินค้าที่ซื้อภายใน 15 วัน (Login_Supervisor)
            try (Connection conn = DriverManager.getConnection(URL, "Login_Supervisor", "Password_Sup_2026!")) {
                Tx1_ReturnMerchandise_Art.returnMerchandiseWithin15Days(conn, 5001, "SKU-STORE-00001", 1);
            }

            // 4. [Path] อัปเดตสถานะจัดส่งและซ่อนที่อยู่ลูกค้า (Login_Manager)
            try (Connection conn = DriverManager.getConnection(URL, "Login_Manager", "Password_Mgr_2026!")) {
                Tx4_UpdateShippingAndMask_Path.updateShippingStatusAndMaskAddress(
                        conn, 6001, "SKU-WHSE-000001", 4001,
                        new Timestamp(System.currentTimeMillis()),
                        new BigDecimal("200.00"), new BigDecimal("14.50"), new BigDecimal("15.00")
                );
            }

            System.out.println("\n--- 2. ทดสอบการทำงานหลังตั้งค่า Isolation Level ---");
            ConcurrencyTest_Bam_Dream.testDirtyRead(URL);

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
