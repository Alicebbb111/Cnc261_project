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

        String sql = "SELECT p.UPC, p.product_name, ps.SKU, ps.in_store, "
                + "ps.store_numb, ps.dept_numb, s.store_city, "
                + "ps.warehouse_numb, w.warehouse_city, ps.number_on_hand, ps.retail_price "
                + "FROM dbo.product p "
                + "JOIN dbo.product_stocked ps ON p.UPC = ps.UPC "
                + "LEFT JOIN dbo.store s ON ps.store_numb = s.store_numb "
                + "LEFT JOIN dbo.warehouse w ON ps.warehouse_numb = w.warehouse_numb "
                + "WHERE ps.number_on_hand > 0 AND p.UPC = ?";

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);

            try (PreparedStatement ps = conn.prepareStatement(sql)) {
                ps.setString(1, targetUpc);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        boolean inStore = rs.getBoolean("in_store");
                        String location = inStore
                                ? "Store " + rs.getInt("store_numb") + " (Dept " + rs.getInt("dept_numb") + ")"
                                : "Warehouse " + rs.getInt("warehouse_numb");
                        System.out.println("สินค้า: " + rs.getString("product_name")
                                + " | SKU: " + rs.getString("SKU")
                                + " | อยู่ที่: " + location
                                + " | จำนวนคงเหลือ: " + rs.getInt("number_on_hand") + " ชิ้น");
                    }
                }
            }

            conn.commit();
        } catch (SQLException ex) {
            conn.rollback();
            throw ex;
        }
    }
}
