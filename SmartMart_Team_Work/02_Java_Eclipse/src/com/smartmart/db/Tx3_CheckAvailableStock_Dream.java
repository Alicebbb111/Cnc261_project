package com.smartmart.db;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * [คนที่ 3: Dream] Transaction 3 — ค้นหาสินค้าที่พร้อมจำหน่ายตามสาขาและคลังสินค้า
 * Login ที่ใช้เชื่อมต่อ: Login_Staff
 * Isolation Level: TRANSACTION_READ_COMMITTED
 *   (ป้องกัน Dirty Read เพื่อไม่ให้พนักงานอ่านจำนวนสต็อกชั่วคราวที่ยังไม่ commit และอาจถูก rollback)
 */
public class Tx3_CheckAvailableStock_Dream {

    public static void checkAvailableStock(Connection conn, String targetUpc) throws SQLException {

        // TODO (Dream) — เตรียมคำสั่ง SQL:
        // SELECT p.UPC, p.product_name, ps.SKU, ps.in_store,
        //        ps.store_numb, ps.dept_numb, s.store_city,
        //        ps.warehouse_numb, w.warehouse_city, ps.number_on_hand, ps.retail_price
        // FROM dbo.product p
        // JOIN dbo.product_stocked ps ON p.UPC = ps.UPC
        // LEFT JOIN dbo.store s ON ps.store_numb = s.store_numb
        // LEFT JOIN dbo.warehouse w ON ps.warehouse_numb = w.warehouse_numb
        // WHERE ps.number_on_hand > 0 AND p.UPC = ?

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);

            // TODO (Dream) — ขั้นตอนการทำงานใน try-with-resources:
            // Step 1: สร้าง PreparedStatement และ setString(1, targetUpc)
            // Step 2: executeQuery() แล้ววน while (rs.next())
            // Step 3: ตรวจ rs.getBoolean("in_store") เพื่อแยกว่าสินค้าอยู่ที่ Store (store_numb, dept_numb)
            //         หรืออยู่ที่ Warehouse (warehouse_numb) แล้วพิมพ์รายละเอียดสินค้าและ number_on_hand ออกทางหน้าจอ

            conn.commit();
        } catch (SQLException ex) {
            conn.rollback();
            throw ex;
        }
    }
}
