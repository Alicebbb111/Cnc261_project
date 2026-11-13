package com.smartmart.db;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Date;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;

public class TestTransactions {

    private static final String URL = "jdbc:sqlserver://localhost:1433;databaseName=SmartMartDB;encrypt=true;trustServerCertificate=true;";

    public static void main(String[] args) {
        try {
            System.out.println("--- 1. ทดสอบรัน Transactions ทั้ง 4 แบบ ---");

            // 1. ค้นหาสินค้าพร้อมจำหน่าย (Login_Staff)
            try (Connection conn = DriverManager.getConnection(URL, "Login_Staff", "Password_Stf_2026!")) {
                SmartMartTransactions.checkAvailableStock(conn, "UPC000000000001");
            }

            // 2. สั่งซื้อสินค้าด้วยบัตรเครดิต (Login_InStore_Sale_App)
            try (Connection conn = DriverManager.getConnection(URL, "Login_InStore_Sale_App", "Password_InStoreApp_2026!")) {
                SmartMartTransactions.purchaseWithCreditCardInStore(
                        conn,
                        5002,
                        new Date(System.currentTimeMillis()),
                        "SKU-STORE-00001",
                        1,
                        new BigDecimal("200.00"),
                        new BigDecimal("14.50"),
                        2,
                        "4111222233339999",
                        Date.valueOf("2029-12-31"),
                        "SOMCHAI JAIDEE"
                );
            }

            // 3. คืนสินค้าที่ซื้อภายใน 15 วัน (Login_Supervisor)
            try (Connection conn = DriverManager.getConnection(URL, "Login_Supervisor", "Password_Sup_2026!")) {
                SmartMartTransactions.returnMerchandiseWithin15Days(conn, 5001, "SKU-STORE-00001", 1);
            }

            // 4. อัปเดตสถานะจัดส่งและซ่อนที่อยู่ลูกค้า (Login_Manager)
            try (Connection conn = DriverManager.getConnection(URL, "Login_Manager", "Password_Mgr_2026!")) {
                SmartMartTransactions.updateShippingStatusAndMaskAddress(
                        conn,
                        6001,
                        "SKU-WHSE-000001",
                        4001,
                        new Timestamp(System.currentTimeMillis()),
                        new BigDecimal("200.00"),
                        new BigDecimal("14.50"),
                        new BigDecimal("15.00")
                );
            }

            System.out.println("\n--- 2. ทดสอบการทำงานหลังตั้งค่า Isolation Level ---");
            testDirtyRead();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // ทดสอบป้องกัน Dirty Read ด้วย TRANSACTION_READ_COMMITTED
    public static void testDirtyRead() throws Exception {
        Thread t1 = new Thread(() -> {
            try (Connection conn1 = DriverManager.getConnection(URL, "Login_InStore_Sale_App", "Password_InStoreApp_2026!")) {
                conn1.setAutoCommit(false);
                conn1.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);
                try (PreparedStatement ps = conn1.prepareStatement(
                        "UPDATE dbo.product_stocked SET number_on_hand = number_on_hand - ? WHERE SKU = ?")) {
                    ps.setInt(1, 10);
                    ps.setString(2, "SKU-STORE-00001");
                    ps.executeUpdate();
                    System.out.println("Thread 1: ลดสต็อก 10 ชิ้น (แต่ยังไม่ commit)");

                    Thread.sleep(2000);
                    conn1.rollback();
                    System.out.println("Thread 1: สั่ง rollback คืนค่าสต็อกเดิมแล้ว");
                } catch (Exception ex) {
                    conn1.rollback();
                    throw ex;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        });

        Thread t2 = new Thread(() -> {
            try {
                Thread.sleep(500);
                try (Connection conn2 = DriverManager.getConnection(URL, "Login_Staff", "Password_Stf_2026!")) {
                    conn2.setAutoCommit(false);
                    conn2.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);
                    try (PreparedStatement ps = conn2.prepareStatement(
                            "SELECT number_on_hand FROM dbo.product_stocked WHERE SKU = ?")) {
                        ps.setString(1, "SKU-STORE-00001");
                        System.out.println("Thread 2: อ่านสต็อกด้วย TRANSACTION_READ_COMMITTED...");
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) {
                                System.out.println("Thread 2: ได้ค่าสต็อกที่ถูกต้องหลัง Thread 1 rollback = " + rs.getInt("number_on_hand") + " ชิ้น");
                            }
                        }
                        conn2.commit();
                    } catch (Exception ex) {
                        conn2.rollback();
                        throw ex;
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        });

        t1.start();
        t2.start();
        t1.join();
        t2.join();
    }
}
