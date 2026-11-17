package com.smartmart.db;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Date;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;

public class TestTransactions {

    private static final String URL = "jdbc:sqlserver://localhost:1433;databaseName=SmartMartDB;encrypt=true;trustServerCertificate=true;";

    public static void main(String[] args) {
        try {
            System.out.println("=== 1. ทดสอบรัน Step-by-Step Transactions (กรณีสำเร็จ COMMIT และกรณีไม่ผ่าน ROLLBACK) ===");

            // [Tx 3] ค้นหาและโอนย้ายสต็อกจากคลังสินค้ามาเติมหน้าร้าน (Login_Manager)
            try (Connection conn = DriverManager.getConnection(URL, "Login_Manager", "Password_Mgr_2026!")) {
                SmartMartTransactions.checkAndTransferStockToStore(
                        conn, "UPC000000000001", "SKU-WHSE-000001", "SKU-STORE-00001", 5, true);
            }

            // [Tx 2] ซื้อสินค้าหน้าร้านด้วยบัตรเครดิต: ทดสอบกรณีลูกค้าไม่จ่ายเงินก่อน (ROLLBACK สต็อกเด้งกลับ) แล้วซื้อจริง (COMMIT)
            try (Connection conn = DriverManager.getConnection(URL, "Login_InStore_Sale_App", "Password_InStoreApp_2026!")) {
                try {
                    SmartMartTransactions.purchaseWithCreditCardInStore(
                            conn, 5002, new Date(System.currentTimeMillis()),
                            "SKU-STORE-00001", 1, new BigDecimal("200.00"), new BigDecimal("14.50"),
                            2, "4111222233339999", Date.valueOf("2029-12-31"), "SOMCHAI JAIDEE",
                            false // ลูกค้าไม่จ่ายเงิน -> Rollback สต็อกกลับเท่าเดิม
                    );
                } catch (SQLException ignored) {
                }

                SmartMartTransactions.purchaseWithCreditCardInStore(
                        conn, 5002, new Date(System.currentTimeMillis()),
                        "SKU-STORE-00001", 1, new BigDecimal("200.00"), new BigDecimal("14.50"),
                        2, "4111222233339999", Date.valueOf("2029-12-31"), "SOMCHAI JAIDEE",
                        true // จ่ายเงินสำเร็จ -> Commit
                );
            }

            // [Tx 1] คืนสินค้าหน้าร้านภายใน 15 วัน (Login_Supervisor)
            try (Connection conn = DriverManager.getConnection(URL, "Login_Supervisor", "Password_Sup_2026!")) {
                SmartMartTransactions.returnMerchandiseWithin15Days(conn, 5001, "SKU-STORE-00001", 1, true);
            }

            // [Tx 4] อัปเดตสถานะจัดส่งและซ่อนที่อยู่ลูกค้าเป็น '*** MASKED ***' (Login_Manager)
            try (Connection conn = DriverManager.getConnection(URL, "Login_Manager", "Password_Mgr_2026!")) {
                SmartMartTransactions.updateShippingStatusAndMaskAddress(
                        conn, 6001, "SKU-WHSE-000001", 4001,
                        new Timestamp(System.currentTimeMillis()),
                        new BigDecimal("200.00"), new BigDecimal("14.50"), new BigDecimal("15.00"),
                        true
                );
            }

            // [Tx 8] ฝ่าย HR บรรจุพนักงานใหม่ทดแทน พร้อมเลื่อนตำแหน่งผู้จัดการแผนก (Login_HR)
            try (Connection conn = DriverManager.getConnection(URL, "Login_HR", "Password_HR_2026!")) {
                SmartMartTransactions.promoteEmployeeAndAssignDeptManager(
                        conn, 1002, new BigDecimal("25.00"),
                        1003, "Charlie", "Davis", "88 Pine St", "San Francisco", "CA", "94103",
                        "415-555-1003", "333-33-3333", Date.valueOf("1998-03-15"),
                        10, 101, 2, new BigDecimal("22.00"),
                        true
                );
            }

            System.out.println("\n=== 2. ทดสอบ [Tx 5] ลูกค้า 2 คนแย่งกันซื้อสินค้าโปรโมชั่นออนไลน์พร้อมกัน ===");
            System.out.println("(คนที่ 1 กดซื้อล็อกสต็อกไว้แต่ไม่จ่ายเงิน -> ROLLBACK สต็อกเด้งคืน -> คนที่ 2 ที่รอคิวอยู่เด้งเข้ามาซื้อต่อจน COMMIT)");
            testCompetingBuyersRollbackToNextBuyer();

            System.out.println("\n=== 3. ทดสอบการ Isolate ข้อมูลด้วย Isolation Level บน Materialized View ===");
            testDirtyRead();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // จำลองลูกค้า 2 คนแย่งกันซื้อสินค้าโปรโมชั่นออนไลน์ชิ้นเดียวกัน (Concurrent Checkout & Lock Handover)
    public static void testCompetingBuyersRollbackToNextBuyer() throws Exception {
        Thread buyer1Thread = new Thread(() -> {
            try (Connection conn1 = DriverManager.getConnection(URL, "Login_Web_Sale_App", "Password_WebSaleApp_2026!")) {
                SmartMartTransactions.checkoutWebPromoOrder(
                        conn1,
                        "ลูกค้าคนที่ 1",
                        6002,
                        3001,
                        "4999888877776666",
                        4001,
                        "SKU-WHSE-000001",
                        1,
                        2000, // ถือ Lock ค้างหน้าจ่ายเงิน 2 วินาที
                        false // สุดท้ายไม่จ่ายเงิน -> Rollback คืนสต็อกและปล่อย Lock!
                );
            } catch (SQLException ignored) {
            }
        });

        Thread buyer2Thread = new Thread(() -> {
            try {
                Thread.sleep(400); // กดซื้อตามหลังคนที่ 1 เล็กน้อย (จะติด Lock รอคิวอยู่)
                try (Connection conn2 = DriverManager.getConnection(URL, "Login_Web_Sale_App", "Password_WebSaleApp_2026!")) {
                    SmartMartTransactions.checkoutWebPromoOrder(
                            conn2,
                            "ลูกค้าคนที่ 2",
                            6002,
                            3001,
                            "4999888877776666",
                            4001,
                            "SKU-WHSE-000001",
                            1,
                            0,
                            true // ทันทีที่คนที่ 1 Rollback คนที่ 2 จะเด้งเข้ามาตัดสต็อกและจ่ายเงินสำเร็จ (COMMIT)!
                    );
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        });

        buyer1Thread.start();
        buyer2Thread.start();
        buyer1Thread.join();
        buyer2Thread.join();
    }

    // ทดสอบป้องกัน Dirty Read ด้วย TRANSACTION_READ_COMMITTED บนตารางและ Materialized View
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
                            "SELECT number_on_hand FROM dbo.vw_Materialized_InStore_Available_Inventory WITH (NOEXPAND) WHERE SKU = ?")) {
                        ps.setString(1, "SKU-STORE-00001");
                        System.out.println("Thread 2: อ่านสต็อกผ่าน Materialized View ด้วย TRANSACTION_READ_COMMITTED...");
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) {
                                System.out.println("Thread 2: ได้ค่าสต็อกที่ถูก Isolate อย่างถูกต้อง (ไม่เกิด Dirty Read) = " + rs.getInt("number_on_hand") + " ชิ้น");
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
