package com.smartmart.db;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.SQLException;

/**
 * [คนที่ 2: Bam] Transaction 2 — สั่งซื้อสินค้าหน้าร้านด้วยบัตรเครดิต
 * Login ที่ใช้เชื่อมต่อ: Login_InStore_Sale_App
 * Isolation Level: TRANSACTION_READ_COMMITTED
 *   (ป้องกัน Dirty Read เพื่อไม่ให้การขายอ่าน/ตัดสต็อกที่ยังไม่ถูก commit จาก Transaction อื่น)
 */
public class Tx2_PurchaseCreditCard_Bam {

    public static void purchaseWithCreditCardInStore(
            Connection conn, int transactionNumb, Date transactionDate,
            String sku, int quantity, BigDecimal unitPrice, BigDecimal salesTax,
            int creditCardPaymentTypeCode, String creditCardNumb,
            Date cardExpDate, String nameOnCard) throws SQLException {

        // TODO (Bam) — เตรียมคำสั่ง SQL ทั้ง 4 คำสั่งด้วย PreparedStatement:
        // 1. deductStockSql: UPDATE dbo.product_stocked SET number_on_hand = number_on_hand - ?
        //                    WHERE SKU = ? AND in_store = 1 AND number_on_hand >= ?
        // 2. insertSaleSql: INSERT INTO dbo.in_store_sale (...) VALUES (?, ?, ?, ?, ?, ?)
        // 3. insertItemSql: INSERT INTO dbo.in_store_sale_item (...) VALUES (?, ?, ?, ?)
        // 4. insertCardSql: INSERT INTO dbo.credit_sale_details (...) VALUES (?, ?, ?, ?)

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);

            // TODO (Bam) — ขั้นตอนการทำงานใน try-with-resources:
            // Step 1: รัน deductStockSql ตัดสต็อกหน้าร้าน (ถ้า executeUpdate() == 0 แสดงว่าสต็อกไม่พอ ให้ throw new SQLException(...))
            // Step 2: คำนวณ productTotal = unitPrice * quantity และ saleTotal = productTotal + salesTax
            //         แล้วรัน insertSaleSql บันทึกหัวใบเสร็จ
            // Step 3: รัน insertItemSql บันทึกรายการสินค้าในบิล
            // Step 4: รัน insertCardSql บันทึกข้อมูลบัตรเครดิตลง credit_sale_details

            conn.commit();
            System.out.println("สั่งซื้อสินค้าด้วยบัตรเครดิต ใบเสร็จ " + transactionNumb + " สำเร็จ");
        } catch (SQLException ex) {
            conn.rollback();
            throw ex;
        }
    }
}
