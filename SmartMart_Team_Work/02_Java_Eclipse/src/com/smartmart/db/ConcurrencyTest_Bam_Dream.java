package com.smartmart.db;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

/**
 * [Bam + Dream] คลาสทดสอบ Concurrency (ป้องกัน Dirty Read ด้วย TRANSACTION_READ_COMMITTED)
 * จำลอง 2 Threads ทำงานพร้อมกันระหว่าง Login_InStore_Sale_App (Bam) และ Login_Staff (Dream)
 */
public class ConcurrencyTest_Bam_Dream {

    public static void testDirtyRead(String url) throws Exception {
        Thread t1 = new Thread(() -> {
            try (Connection conn1 = DriverManager.getConnection(url, "Login_InStore_Sale_App", "Password_InStoreApp_2026!")) {
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
                try (Connection conn2 = DriverManager.getConnection(url, "Login_Staff", "Password_Stf_2026!")) {
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
