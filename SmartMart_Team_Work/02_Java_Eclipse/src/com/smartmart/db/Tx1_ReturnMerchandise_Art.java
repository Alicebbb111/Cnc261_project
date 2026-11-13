package com.smartmart.db;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * [คนที่ 1: Art] Transaction 1 — คืนสินค้าที่ซื้อหน้าร้านภายใน 15 วัน
 * Login ที่ใช้เชื่อมต่อ: Login_Supervisor
 * Isolation Level: TRANSACTION_REPEATABLE_READ
 *   (ป้องกัน Non-Repeatable Read ระหว่างอ่านตรวจยอดซื้อ/ราคา กับการคำนวณคืนเงินและปรับยอดบิล)
 */
public class Tx1_ReturnMerchandise_Art {

    public static void returnMerchandiseWithin15Days(
            Connection conn, int transactionNumb, String returnSku, int returnQty) throws SQLException {

        // TODO (Art) — เตรียมคำสั่ง SQL ทั้ง 5 คำสั่งด้วย PreparedStatement:
        // 1. checkSaleSql: SELECT วันที่ซื้อ, DATEDIFF(DAY, วันที่ซื้อ, GETDATE()) AS days_diff,
        //                  in_store_quantity, in_store_price จาก dbo.in_store_sale JOIN dbo.in_store_sale_item
        //                  WHERE in_store_transaction_numb = ? AND in_store_SKU = ?
        // 2. restoreStockSql: UPDATE dbo.product_stocked SET number_on_hand = number_on_hand + ?
        //                     WHERE SKU = ? AND in_store = 1
        // 3. updateItemSql: UPDATE dbo.in_store_sale_item SET in_store_quantity = in_store_quantity - ?
        //                   WHERE in_store_transaction_numb = ? AND in_store_SKU = ?
        // 4. deleteItemSql: DELETE FROM dbo.in_store_sale_item
        //                   WHERE in_store_transaction_numb = ? AND in_store_SKU = ?
        // 5. updateHeaderSql: UPDATE dbo.in_store_sale SET in_store_sale_product_total = in_store_sale_product_total - ?,
        //                     in_store_sale_total = in_store_sale_total - ? WHERE in_store_transaction_numb = ?

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);

            // TODO (Art) — ขั้นตอนการทำงานใน try-with-resources:
            // Step 1: รัน checkSaleSql ตรวจว่าพบรายการหรือไม่, days_diff <= 15 หรือไม่,
            //         และ returnQty > 0 && returnQty <= purchasedQty หรือไม่ (ถ้าไม่ผ่านให้ throw new SQLException(...))
            // Step 2: รัน restoreStockSql บวกสต็อกหน้าร้านคืน (+returnQty)
            // Step 3: ถ้า returnQty == purchasedQty ให้รัน deleteItemSql ลบแถวรายการทิ้ง
            //         ถ้าคืนบางส่วน (returnQty < purchasedQty) ให้รัน updateItemSql ลดจำนวนลง
            // Step 4: คำนวณ refundAmount = unitPrice.multiply(BigDecimal.valueOf(returnQty))
            //         แล้วรัน updateHeaderSql หักยอดรวมออกจากตาราง in_store_sale

            conn.commit();
            System.out.println("คืนสินค้าใบเสร็จ " + transactionNumb + " สำเร็จ");
        } catch (SQLException ex) {
            conn.rollback();
            throw ex;
        }
    }
}
