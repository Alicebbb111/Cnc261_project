package com.smartmart.db;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Timestamp;

/**
 * [คนที่ 4: Path] Transaction 4 — อัปเดตสถานะจัดส่งเว็บและซ่อนที่อยู่ลูกค้า (Privacy Masking)
 * Login ที่ใช้เชื่อมต่อ: Login_Manager
 * Isolation Level: TRANSACTION_REPEATABLE_READ
 *   (ป้องกัน Non-Repeatable Read และล็อกแถวที่อยู่/รายการสินค้าจนกว่าจะอัปเดตสถานะและ Mask เสร็จสมบูรณ์พร้อมกัน)
 */
public class Tx4_UpdateShippingAndMask_Path {

    public static void updateShippingStatusAndMaskAddress(
            Connection conn, int webSaleNumb, String webSku, int shippingAddressNumb,
            Timestamp shippedTimestamp, BigDecimal merchTotal,
            BigDecimal taxAmount, BigDecimal shippingFee) throws SQLException {

        // TODO (Path) — เตรียมคำสั่ง SQL ทั้ง 3 คำสั่งด้วย PreparedStatement:
        // 1. insertShipmentSql: INSERT INTO dbo.web_sale_shipment (...) VALUES (?, ?, ?, ?, ?, ?)
        // 2. updateItemStatusSql: UPDATE dbo.web_sale_item SET web_sale_shipped = 1, web_sale_date_shipped = ?
        //                         WHERE web_sale_numb = ? AND web_sale_SKU = ?
        // 3. maskShippingAddressSql: UPDATE dbo.web_sale_shipping_address SET web_shipping_street = '*** MASKED ***'
        //                            WHERE web_shipping_address_numb = ?

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);

            // TODO (Path) — ขั้นตอนการทำงานใน try-with-resources:
            // Step 1: คำนวณ totalCharged = merchTotal.add(taxAmount).add(shippingFee)
            //         แล้วรัน insertShipmentSql เพื่อบันทึกรอบการจัดส่งลง web_sale_shipment
            // Step 2: รัน updateItemStatusSql อัปเดต web_sale_shipped = 1 และ web_sale_date_shipped
            //         (ถ้า executeUpdate() == 0 ให้ throw new SQLException(...))
            // Step 3: รัน maskShippingAddressSql เปลี่ยน web_shipping_street เป็น '*** MASKED ***'
            //         (ถ้า executeUpdate() == 0 ให้ throw new SQLException(...))

            conn.commit();
            System.out.println("อัปเดตสถานะจัดส่งใบสั่งซื้อเว็บ " + webSaleNumb + " และซ่อนที่อยู่ลูกค้าสำเร็จ");
        } catch (SQLException ex) {
            conn.rollback();
            throw ex;
        }
    }
}
