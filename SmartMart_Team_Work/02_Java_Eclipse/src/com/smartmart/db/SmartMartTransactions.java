package com.smartmart.db;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;

public class SmartMartTransactions {

    // =========================================================================
    // Transaction 1: การรับคืนสินค้าหน้าร้านภายใน 15 วัน แบบ Step-by-Step
    // Step 1: ล็อกใบเสร็จและรายการสินค้า (UPDLOCK, ROWLOCK) ป้องกันกดคืนซ้ำพร้อมกัน
    // Step 2: คืนสต็อกหน้าร้าน + ลดจำนวนในบิล + หักยอดรวมใบเสร็จชั่วคราว
    // Step 3: ตรวจสอบการอนุมัติคืนเงิน (refundApproved)
    // Step 4: ถ้าอนุมัติ -> commit() / ถ้าไม่อนุมัติหรือยกเลิก -> rollback() บิลและสต็อกกลับเท่าเดิม
    // =========================================================================
    public static void returnMerchandiseWithin15Days(
            Connection conn, int transactionNumb, String returnSku, int returnQty, boolean refundApproved) throws SQLException {

        String checkSaleSql = "SELECT s.in_store_transaction_date, "
                + "DATEDIFF(DAY, s.in_store_transaction_date, CAST(GETDATE() AS DATE)) AS days_diff, "
                + "i.in_store_quantity, i.in_store_price "
                + "FROM dbo.in_store_sale s WITH (UPDLOCK, ROWLOCK) "
                + "JOIN dbo.in_store_sale_item i WITH (UPDLOCK, ROWLOCK) ON s.in_store_transaction_numb = i.in_store_transaction_numb "
                + "WHERE s.in_store_transaction_numb = ? AND i.in_store_SKU = ?";
        String restoreStockSql = "UPDATE dbo.product_stocked WITH (ROWLOCK) SET number_on_hand = number_on_hand + ? WHERE SKU = ? AND in_store = 1";
        String updateItemSql = "UPDATE dbo.in_store_sale_item SET in_store_quantity = in_store_quantity - ? WHERE in_store_transaction_numb = ? AND in_store_SKU = ?";
        String deleteItemSql = "DELETE FROM dbo.in_store_sale_item WHERE in_store_transaction_numb = ? AND in_store_SKU = ?";
        String updateHeaderSql = "UPDATE dbo.in_store_sale SET in_store_sale_product_total = in_store_sale_product_total - ?, "
                + "in_store_sale_total = in_store_sale_total - ? WHERE in_store_transaction_numb = ?";

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);

            // Step 1: ล็อกแถวใบเสร็จและตรวจสอบเงื่อนไข 15 วัน
            BigDecimal unitPrice;
            int purchasedQty;
            try (PreparedStatement psCheck = conn.prepareStatement(checkSaleSql)) {
                psCheck.setInt(1, transactionNumb);
                psCheck.setString(2, returnSku);
                try (ResultSet rs = psCheck.executeQuery()) {
                    if (!rs.next()) {
                        throw new SQLException("ไม่พบรายการสินค้าในใบเสร็จที่ระบุ");
                    }
                    if (rs.getInt("days_diff") > 15) {
                        throw new SQLException("เกินกำหนดคืนสินค้า 15 วัน");
                    }
                    purchasedQty = rs.getInt("in_store_quantity");
                    unitPrice = rs.getBigDecimal("in_store_price");
                    if (returnQty <= 0 || returnQty > purchasedQty) {
                        throw new SQLException("จำนวนที่ขอคืนไม่ถูกต้อง");
                    }
                }
            }

            // Step 2: คืนสต็อกหน้าร้านและปรับยอดในใบเสร็จชั่วคราว
            try (PreparedStatement psRestore = conn.prepareStatement(restoreStockSql)) {
                psRestore.setInt(1, returnQty);
                psRestore.setString(2, returnSku);
                if (psRestore.executeUpdate() == 0) {
                    throw new SQLException("ไม่พบ SKU สำหรับรับคืนสต็อกหน้าร้าน");
                }
            }

            if (returnQty == purchasedQty) {
                try (PreparedStatement psDel = conn.prepareStatement(deleteItemSql)) {
                    psDel.setInt(1, transactionNumb);
                    psDel.setString(2, returnSku);
                    psDel.executeUpdate();
                }
            } else {
                try (PreparedStatement psUpd = conn.prepareStatement(updateItemSql)) {
                    psUpd.setInt(1, returnQty);
                    psUpd.setInt(2, transactionNumb);
                    psUpd.setString(3, returnSku);
                    psUpd.executeUpdate();
                }
            }

            BigDecimal refundAmount = unitPrice.multiply(BigDecimal.valueOf(returnQty));
            try (PreparedStatement psHdr = conn.prepareStatement(updateHeaderSql)) {
                psHdr.setBigDecimal(1, refundAmount);
                psHdr.setBigDecimal(2, refundAmount);
                psHdr.setInt(3, transactionNumb);
                psHdr.executeUpdate();
            }

            // Step 3: ตรวจสอบการอนุมัติคืนเงิน
            if (!refundApproved) {
                throw new SQLException("ไม่อนุมัติการคืนเงิน -> ระบบ Rollback คืนค่าบิลและสต็อกกลับเท่าเดิม");
            }

            // Step 4: Commit จบ Transaction
            conn.commit();
            System.out.println("[Tx 1] คืนสินค้าใบเสร็จ " + transactionNumb + " สำเร็จ (COMMIT)");
        } catch (SQLException ex) {
            conn.rollback();
            System.out.println("[Tx 1] ยกเลิกรายการ (ROLLBACK): " + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // Transaction 2: การซื้อสินค้าหน้าร้านด้วยบัตรเครดิตแบบ Step-by-Step
    // Step 1: ล็อกแถวสต็อก (UPDLOCK, ROWLOCK) และตัดสต็อกหน้าร้านชั่วคราว (คนอื่นแย่งซื้อตัดหน้าไม่ได้)
    // Step 2: เปิดหัวบิลและบันทึกรายการสินค้ารอชำระเงิน
    // Step 3: ตรวจสอบการจ่ายเงิน (paymentConfirmed)
    // Step 4: ถ้าจ่ายเงินผ่าน -> บันทึกบัตรเครดิตและ commit()
    //         ถ้าไม่จ่ายเงิน/บัตรไม่ผ่าน -> rollback() สต็อกเด้งกลับมาเท่าเดิม และคนที่ 2 ทำรายการต่อได้ทันที
    // =========================================================================
    public static void purchaseWithCreditCardInStore(
            Connection conn, int transactionNumb, Date transactionDate,
            String sku, int quantity, BigDecimal unitPrice, BigDecimal salesTax,
            int creditCardPaymentTypeCode, String creditCardNumb,
            Date cardExpDate, String nameOnCard, boolean paymentConfirmed) throws SQLException {

        String deductStockSql = "UPDATE dbo.product_stocked WITH (UPDLOCK, ROWLOCK) "
                + "SET number_on_hand = number_on_hand - ? WHERE SKU = ? AND in_store = 1 AND number_on_hand >= ?";
        String insertSaleSql = "INSERT INTO dbo.in_store_sale (in_store_transaction_numb, in_store_transaction_date, "
                + "in_store_sale_product_total, in_store_sales_tax, in_store_sale_total, in_store_sale_payment_type_code) VALUES (?, ?, ?, ?, ?, ?)";
        String insertItemSql = "INSERT INTO dbo.in_store_sale_item (in_store_transaction_numb, in_store_SKU, in_store_quantity, in_store_price) VALUES (?, ?, ?, ?)";
        String insertCardSql = "INSERT INTO dbo.credit_sale_details (in_store_transaction_numb, in_store_sale_credit_card_numb, "
                + "in_store_sale_credit_card_exp_date, in_store_sale_name_on_credit_card) VALUES (?, ?, ?, ?)";

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);

            try (PreparedStatement psStock = conn.prepareStatement(deductStockSql);
                 PreparedStatement psSale = conn.prepareStatement(insertSaleSql);
                 PreparedStatement psItem = conn.prepareStatement(insertItemSql);
                 PreparedStatement psCard = conn.prepareStatement(insertCardSql)) {

                // Step 1: ล็อกและลดสต็อกหน้าร้านชั่วคราว
                psStock.setInt(1, quantity);
                psStock.setString(2, sku);
                psStock.setInt(3, quantity);
                if (psStock.executeUpdate() == 0) {
                    throw new SQLException("สต็อกสินค้าไม่เพียงพอสำหรับ SKU: " + sku);
                }

                // Step 2: สร้างหัวบิลและรายการสินค้า
                BigDecimal productTotal = unitPrice.multiply(BigDecimal.valueOf(quantity));
                BigDecimal saleTotal = productTotal.add(salesTax);
                psSale.setInt(1, transactionNumb);
                psSale.setDate(2, transactionDate);
                psSale.setBigDecimal(3, productTotal);
                psSale.setBigDecimal(4, salesTax);
                psSale.setBigDecimal(5, saleTotal);
                psSale.setInt(6, creditCardPaymentTypeCode);
                psSale.executeUpdate();

                psItem.setInt(1, transactionNumb);
                psItem.setString(2, sku);
                psItem.setInt(3, quantity);
                psItem.setBigDecimal(4, unitPrice);
                psItem.executeUpdate();

                // Step 3: ตรวจสอบการชำระเงินด้วยบัตรเครดิต
                if (!paymentConfirmed) {
                    throw new SQLException("ลูกค้าไม่ชำระเงินหรือบัตรเครดิตไม่ผ่าน -> ระบบ Rollback คืนสต็อกกลับเท่าเดิม");
                }

                psCard.setInt(1, transactionNumb);
                psCard.setString(2, creditCardNumb);
                psCard.setDate(3, cardExpDate);
                psCard.setString(4, nameOnCard);
                psCard.executeUpdate();

                // Step 4: จ่ายเงินสำเร็จ Commit
                conn.commit();
                System.out.println("[Tx 2] สั่งซื้อสินค้าด้วยบัตรเครดิต ใบเสร็จ " + transactionNumb + " สำเร็จ (COMMIT)");
            }
        } catch (SQLException ex) {
            conn.rollback();
            System.out.println("[Tx 2] ยกเลิกรายการ (ROLLBACK - สต็อกกลับเท่าเดิม): " + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // Transaction 3: การค้นหาและโอนย้ายสต็อกสินค้าจากคลังสินค้ามาเติมหน้าร้านแบบ Step-by-Step
    // Step 1: ค้นหาและล็อกสต็อกคลังสินค้าด้วย UPDLOCK, ROWLOCK
    // Step 2: หักสต็อกคลังสินค้า (in_store = 0) และเพิ่มสต็อกเข้าหน้าร้าน (in_store = 1)
    // Step 3: ตรวจสอบการยืนยันรับของเข้าสาขา (storeReceiveConfirmed)
    // Step 4: ถ้ายืนยัน -> commit() / ถ้าสาขาไม่รับของ -> rollback() คืนสต็อกคลังเท่าเดิม
    // =========================================================================
    public static void checkAndTransferStockToStore(
            Connection conn, String targetUpc, String warehouseSku, String storeSku,
            int transferQty, boolean storeReceiveConfirmed) throws SQLException {

        String checkSql = "SELECT p.UPC, p.product_name, ps.SKU, ps.in_store, "
                + "ps.store_numb, ps.dept_numb, ps.warehouse_numb, ps.number_on_hand, ps.retail_price "
                + "FROM dbo.product p "
                + "JOIN dbo.product_stocked ps WITH (UPDLOCK, ROWLOCK) ON p.UPC = ps.UPC "
                + "WHERE ps.number_on_hand > 0 AND p.UPC = ?";
        String deductWarehouseSql = "UPDATE dbo.product_stocked WITH (UPDLOCK, ROWLOCK) "
                + "SET number_on_hand = number_on_hand - ? WHERE SKU = ? AND in_store = 0 AND number_on_hand >= ?";
        String addStoreSql = "UPDATE dbo.product_stocked WITH (UPDLOCK, ROWLOCK) "
                + "SET number_on_hand = number_on_hand + ? WHERE SKU = ? AND in_store = 1";

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);

            // Step 1: ตรวจสอบและล็อกสต็อกต้นทาง-ปลายทาง
            try (PreparedStatement psCheck = conn.prepareStatement(checkSql)) {
                psCheck.setString(1, targetUpc);
                try (ResultSet rs = psCheck.executeQuery()) {
                    while (rs.next()) {
                        String loc = rs.getBoolean("in_store")
                                ? "Store " + rs.getInt("store_numb") + " (Dept " + rs.getInt("dept_numb") + ")"
                                : "Warehouse " + rs.getInt("warehouse_numb");
                        System.out.println("[Tx 3 ก่อนโอน] SKU: " + rs.getString("SKU")
                                + " | อยู่ที่: " + loc + " | คงเหลือ: " + rs.getInt("number_on_hand"));
                    }
                }
            }

            // Step 2: หักสต็อกจากคลังสินค้าและเติมเข้าหน้าร้าน
            try (PreparedStatement psDeduct = conn.prepareStatement(deductWarehouseSql);
                 PreparedStatement psAdd = conn.prepareStatement(addStoreSql)) {

                psDeduct.setInt(1, transferQty);
                psDeduct.setString(2, warehouseSku);
                psDeduct.setInt(3, transferQty);
                if (psDeduct.executeUpdate() == 0) {
                    throw new SQLException("สต็อกคลังสินค้าไม่เพียงพอสำหรับโอนย้าย");
                }

                psAdd.setInt(1, transferQty);
                psAdd.setString(2, storeSku);
                if (psAdd.executeUpdate() == 0) {
                    throw new SQLException("ไม่พบ SKU หน้าร้านปลายทาง");
                }
            }

            // Step 3: ตรวจสอบการรับสินค้าเข้าสาขาหน้าร้าน
            if (!storeReceiveConfirmed) {
                throw new SQLException("สาขาปลายทางปฏิเสธการรับสินค้า -> ระบบ Rollback คืนสต็อกคลังกลับเท่าเดิม");
            }

            // Step 4: ยืนยันการโอนย้ายสต็อก
            conn.commit();
            System.out.println("[Tx 3] โอนสต็อกจำนวน " + transferQty + " ชิ้น จากคลังมาเติมหน้าร้านสำเร็จ (COMMIT)");
        } catch (SQLException ex) {
            conn.rollback();
            System.out.println("[Tx 3] ยกเลิกการโอนสต็อก (ROLLBACK): " + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // Transaction 4: การตัดรอบจัดส่งสินค้าเว็บและซ่อนที่อยู่ลูกค้าแบบ Step-by-Step
    // Step 1: ล็อกรายการออเดอร์ที่รอจัดส่ง (UPDLOCK, ROWLOCK) กันกดส่งซ้ำ
    // Step 2: บันทึกรอบจัดส่ง (web_sale_shipment) + อัปเดตสถานะเป็นส่งแล้ว (web_sale_shipped = 1)
    // Step 3: ซ่อนบ้านเลขที่ลูกค้าเป็น '*** MASKED ***'
    // Step 4: ถ้ายืนยันส่งมอบขนส่งสำเร็จ -> commit() / ถ้าขนส่งไม่รับพัสดุ -> rollback() คืนสถานะยังไม่ส่งและคงที่อยู่เดิมไว้
    // =========================================================================
    public static void updateShippingStatusAndMaskAddress(
            Connection conn, int webSaleNumb, String webSku, int shippingAddressNumb,
            Timestamp shippedTimestamp, BigDecimal merchTotal,
            BigDecimal taxAmount, BigDecimal shippingFee, boolean carrierAccepted) throws SQLException {

        String lockItemSql = "SELECT web_sale_shipped FROM dbo.web_sale_item WITH (UPDLOCK, ROWLOCK) "
                + "WHERE web_sale_numb = ? AND web_sale_SKU = ? AND web_sale_shipped = 0";
        String insertShipmentSql = "INSERT INTO dbo.web_sale_shipment (web_sale_numb, web_sale_date_shipped, "
                + "web_shipment_merchandise_total, web_shipment_tax, web_shipment_shipping, web_shipment_total_charged) VALUES (?, ?, ?, ?, ?, ?)";
        String updateItemStatusSql = "UPDATE dbo.web_sale_item SET web_sale_shipped = 1, web_sale_date_shipped = ? WHERE web_sale_numb = ? AND web_sale_SKU = ?";
        String maskShippingAddressSql = "UPDATE dbo.web_sale_shipping_address SET web_shipping_street = '*** MASKED ***' WHERE web_shipping_address_numb = ?";

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);

            try (PreparedStatement psLock = conn.prepareStatement(lockItemSql);
                 PreparedStatement psShipment = conn.prepareStatement(insertShipmentSql);
                 PreparedStatement psItem = conn.prepareStatement(updateItemStatusSql);
                 PreparedStatement psMaskAddr = conn.prepareStatement(maskShippingAddressSql)) {

                // Step 1: ล็อกแถวรายการสั่งซื้อเว็บที่ยังไม่ได้จัดส่ง
                psLock.setInt(1, webSaleNumb);
                psLock.setString(2, webSku);
                try (ResultSet rs = psLock.executeQuery()) {
                    if (!rs.next()) {
                        throw new SQLException("ไม่พบรายการสินค้าที่รอจัดส่ง หรือรายการนี้ถูกจัดส่งไปแล้ว");
                    }
                }

                // Step 2: บันทึกรอบจัดส่งและอัปเดตสถานะสินค้า
                BigDecimal totalCharged = merchTotal.add(taxAmount).add(shippingFee);
                psShipment.setInt(1, webSaleNumb);
                psShipment.setTimestamp(2, shippedTimestamp);
                psShipment.setBigDecimal(3, merchTotal);
                psShipment.setBigDecimal(4, taxAmount);
                psShipment.setBigDecimal(5, shippingFee);
                psShipment.setBigDecimal(6, totalCharged);
                psShipment.executeUpdate();

                psItem.setTimestamp(1, shippedTimestamp);
                psItem.setInt(2, webSaleNumb);
                psItem.setString(3, webSku);
                psItem.executeUpdate();

                // Step 3: ซ่อนบ้านเลขที่ลูกค้าเป็น '*** MASKED ***'
                psMaskAddr.setInt(1, shippingAddressNumb);
                psMaskAddr.executeUpdate();

                // Step 4: ตรวจสอบการยืนยันรับพัสดุจากขนส่ง
                if (!carrierAccepted) {
                    throw new SQLException("บริษัทขนส่งปฏิเสธพัสดุ -> ระบบ Rollback คืนสถานะยังไม่ส่งและคงที่อยู่ลูกค้าไว้");
                }

                conn.commit();
                System.out.println("[Tx 4] อัปเดตสถานะจัดส่งใบสั่งซื้อเว็บ " + webSaleNumb + " และซ่อนที่อยู่ลูกค้าสำเร็จ (COMMIT)");
            }
        } catch (SQLException ex) {
            conn.rollback();
            System.out.println("[Tx 4] ยกเลิกการจัดส่ง (ROLLBACK): " + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // Transaction 5: การแย่งซื้อสินค้าโปรโมชั่นหน้าเว็บแบบ Step-by-Step (Flash Sale Checkout)
    // • คนที่กดซื้อก่อนจะล็อกแถวสต็อก (UPDLOCK, ROWLOCK) และตัดสต็อกคลังออนไลน์ลงชั่วคราว
    // • ระหว่างรอคนแรกจ่ายเงิน คนที่ 2 ที่กดซื้อเข้ามาพร้อมกันจะติด Lock ซื้อตัดหน้าไม่ได้
    // • ถ้าคนแรกไม่จ่ายเงิน (paymentConfirmed = false) -> rollback() สต็อกเด้งกลับเท่าเดิม
    //   และปลดล็อกให้คนที่ 2 ที่รอคิวอยู่เด้งเข้ามาตัดสต็อกและจ่ายเงินต่อจน commit() ทันที!
    // =========================================================================
    public static void checkoutWebPromoOrder(
            Connection conn, String buyerLabel, int webSaleNumb, int customerNumb,
            String creditCardNumb, int shippingAddressNumb, String webSku,
            int orderQty, long holdMillisBeforeDecision, boolean paymentConfirmed) throws SQLException {

        String lockAndGetPromoSql = "SELECT p.UPC, p.product_name, ps.SKU, ps.retail_price, ps.number_on_hand, "
                + "sp.promotion_details, "
                + "CASE WHEN sp.UPC IS NOT NULL THEN ROUND(ps.retail_price * 0.80, 2) ELSE ps.retail_price END AS promo_price "
                + "FROM dbo.product p "
                + "JOIN dbo.product_stocked ps WITH (UPDLOCK, ROWLOCK) ON p.UPC = ps.UPC "
                + "LEFT JOIN dbo.sales_promotion sp ON p.UPC = sp.UPC "
                + "AND CAST(GETDATE() AS DATE) BETWEEN sp.promotion_start_date AND sp.promotion_end_date "
                + "WHERE ps.SKU = ? AND p.web_orderable = 1 AND ps.in_store = 0 AND ps.number_on_hand >= ?";
        String deductWebStockSql = "UPDATE dbo.product_stocked SET number_on_hand = number_on_hand - ? WHERE SKU = ? AND in_store = 0";
        String insertWebSaleSql = "INSERT INTO dbo.web_sale (web_sale_numb, web_sale_date, web_customer_numb, web_credit_card_numb, "
                + "web_sale_total, web_sale_merchandise_total, web_sale_shipping, web_sale_tax) VALUES (?, CAST(GETDATE() AS DATE), ?, ?, ?, ?, ?, ?)";
        String insertWebItemSql = "INSERT INTO dbo.web_sale_item (web_sale_numb, web_sale_SKU, web_sale_quantity, web_sale_shipped, "
                + "web_sale_price, web_shipping_address_numb, web_sale_date_shipped) VALUES (?, ?, ?, 0, ?, ?, NULL)";

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);

            try (PreparedStatement psLock = conn.prepareStatement(lockAndGetPromoSql);
                 PreparedStatement psDeduct = conn.prepareStatement(deductWebStockSql);
                 PreparedStatement psSale = conn.prepareStatement(insertWebSaleSql);
                 PreparedStatement psItem = conn.prepareStatement(insertWebItemSql)) {

                // Step 1: ล็อกแถวสต็อกคลังออนไลน์และดึงราคาโปรโมชั่น
                System.out.println("[" + buyerLabel + "] กดสั่งซื้อ กำลังขอ Lock สต็อก SKU: " + webSku + " ...");
                psLock.setString(1, webSku);
                psLock.setInt(2, orderQty);

                BigDecimal promoPrice;
                int stockBefore;
                try (ResultSet rs = psLock.executeQuery()) {
                    if (!rs.next()) {
                        throw new SQLException("สต็อกคลังออนไลน์ไม่เพียงพอสำหรับ " + buyerLabel);
                    }
                    promoPrice = rs.getBigDecimal("promo_price");
                    stockBefore = rs.getInt("number_on_hand");
                }

                // Step 2: ตัดสต็อกลงชั่วคราวและสร้างใบสั่งซื้อรอชำระเงิน
                psDeduct.setInt(1, orderQty);
                psDeduct.setString(2, webSku);
                psDeduct.executeUpdate();
                System.out.println("[" + buyerLabel + "] ล็อกและตัดสต็อกชั่วคราวแล้ว (จาก " + stockBefore + " เหลือ " + (stockBefore - orderQty) + " ชิ้น) กำลังอยู่ในหน้าชำระเงิน...");

                BigDecimal merchTotal = promoPrice.multiply(BigDecimal.valueOf(orderQty));
                BigDecimal shippingFee = new BigDecimal("15.00");
                BigDecimal taxAmount = new BigDecimal("11.60");
                BigDecimal saleTotal = merchTotal.add(shippingFee).add(taxAmount);

                psSale.setInt(1, webSaleNumb);
                psSale.setInt(2, customerNumb);
                psSale.setString(3, creditCardNumb);
                psSale.setBigDecimal(4, saleTotal);
                psSale.setBigDecimal(5, merchTotal);
                psSale.setBigDecimal(6, shippingFee);
                psSale.setBigDecimal(7, taxAmount);
                psSale.executeUpdate();

                psItem.setInt(1, webSaleNumb);
                psItem.setString(2, webSku);
                psItem.setInt(3, orderQty);
                psItem.setBigDecimal(4, promoPrice);
                psItem.setInt(5, shippingAddressNumb);
                psItem.executeUpdate();

                if (holdMillisBeforeDecision > 0) {
                    try {
                        Thread.sleep(holdMillisBeforeDecision);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                    }
                }

                // Step 3: ตรวจสอบการชำระเงิน
                if (!paymentConfirmed) {
                    throw new SQLException(buyerLabel + " ไม่จ่ายเงินภายในเวลาที่กำหนด -> ROLLBACK คืนสต็อกกลับเป็น " + stockBefore + " ชิ้น และปล่อยคิวให้คนถัดไป!");
                }

                // Step 4: จ่ายเงินสำเร็จ Commit
                conn.commit();
                System.out.println("[" + buyerLabel + "] ชำระเงินสำเร็จ! ยืนยันคำสั่งซื้อ #" + webSaleNumb + " ที่ราคาโปรโมชั่น " + promoPrice + " (COMMIT)");
            }
        } catch (SQLException ex) {
            conn.rollback();
            System.out.println("[" + buyerLabel + "] ยกเลิกรายการ: " + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // Transaction 8: ฝ่าย HR บรรจุพนักงานใหม่ทดแทน เลื่อนตำแหน่งผู้จัดการแผนก และตรวจสอบเพดานงบประมาณแบบ Step-by-Step
    // Step 1: ล็อกแถวแผนกและพนักงาน (UPDLOCK, ROWLOCK) กัน HR อีกคนแก้ชนกัน
    // Step 2: บรรจุพนักงานใหม่เข้าแผนกเพื่อรับงานต่อ
    // Step 3: ปรับอัตราค่าจ้างพนักงานเดิม และแต่งตั้งเป็นผู้จัดการแผนกในตาราง department
    // Step 4: ตรวจสอบการอนุมัติคำสั่งและเพดานงบประมาณ (hrDirectorApproved)
    //         ถ้าอนุมัติ -> commit() / ถ้าไม่อนุมัติ -> rollback() ยกเลิกทั้งพนักงานใหม่ การขึ้นเงินเดือน และผู้จัดการแผนกกลับสู่ค่าเดิม!
    // =========================================================================
    public static void promoteEmployeeAndAssignDeptManager(
            Connection conn, int promotedEmpId, BigDecimal newPayRate,
            int newEmpId, String newFirstName, String newLastName,
            String newStreet, String newCity, String newStateCode, String newZip,
            String newPhone, String newSsn, Date newBirthDate,
            int deptNumb, int storeNumb, int newPayTypeCode, BigDecimal newEmpPayRate,
            boolean hrDirectorApproved) throws SQLException {

        String lockDeptAndEmpSql = "SELECT e.employee_id FROM dbo.department d WITH (UPDLOCK, ROWLOCK) "
                + "JOIN dbo.employee e WITH (UPDLOCK, ROWLOCK) ON d.dept_numb = e.dept_numb AND d.store_numb = e.store_numb "
                + "WHERE d.dept_numb = ? AND d.store_numb = ? AND e.employee_id = ?";
        String insertNewEmpSql = "INSERT INTO dbo.employee ("
                + "employee_id, employee_first_name, employee_last_name, employee_street, "
                + "employee_city, employee_state_code, employee_zip, employee_phone, "
                + "employee_ssn, employee_birth_date, dept_numb, store_numb, supervisor_id, "
                + "pay_type_code, pay_rate) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        String updatePromotedEmpSql = "UPDATE dbo.employee SET dept_numb = ?, store_numb = ?, pay_rate = ? WHERE employee_id = ?";
        String assignDeptManagerSql = "UPDATE dbo.department SET dept_manager_id = ? WHERE dept_numb = ? AND store_numb = ?";

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);

            try (PreparedStatement psLock = conn.prepareStatement(lockDeptAndEmpSql);
                 PreparedStatement psInsert = conn.prepareStatement(insertNewEmpSql);
                 PreparedStatement psUpdateEmp = conn.prepareStatement(updatePromotedEmpSql);
                 PreparedStatement psUpdateDept = conn.prepareStatement(assignDeptManagerSql)) {

                // Step 1: ล็อกแผนกและพนักงานที่จะเลื่อนตำแหน่ง
                psLock.setInt(1, deptNumb);
                psLock.setInt(2, storeNumb);
                psLock.setInt(3, promotedEmpId);
                try (ResultSet rs = psLock.executeQuery()) {
                    if (!rs.next()) {
                        throw new SQLException("ไม่พบพนักงานรหัส " + promotedEmpId + " ในแผนก " + deptNumb + " สาขา " + storeNumb);
                    }
                }

                // Step 2: บรรจุพนักงานใหม่ทดแทน
                psInsert.setInt(1, newEmpId);
                psInsert.setString(2, newFirstName);
                psInsert.setString(3, newLastName);
                psInsert.setString(4, newStreet);
                psInsert.setString(5, newCity);
                psInsert.setString(6, newStateCode);
                psInsert.setString(7, newZip);
                psInsert.setString(8, newPhone);
                psInsert.setString(9, newSsn);
                psInsert.setDate(10, newBirthDate);
                psInsert.setInt(11, deptNumb);
                psInsert.setInt(12, storeNumb);
                psInsert.setInt(13, promotedEmpId);
                psInsert.setInt(14, newPayTypeCode);
                psInsert.setBigDecimal(15, newEmpPayRate);
                psInsert.executeUpdate();

                // Step 3: ปรับอัตราค่าจ้างพนักงานเดิมและแต่งตั้งเป็นผู้จัดการแผนกในตาราง department
                psUpdateEmp.setInt(1, deptNumb);
                psUpdateEmp.setInt(2, storeNumb);
                psUpdateEmp.setBigDecimal(3, newPayRate);
                psUpdateEmp.setInt(4, promotedEmpId);
                psUpdateEmp.executeUpdate();

                psUpdateDept.setInt(1, promotedEmpId);
                psUpdateDept.setInt(2, deptNumb);
                psUpdateDept.setInt(3, storeNumb);
                psUpdateDept.executeUpdate();

                // Step 4: ตรวจสอบการอนุมัติคำสั่งแต่งตั้ง
                if (!hrDirectorApproved) {
                    throw new SQLException("ไม่อนุมัติคำสั่งแต่งตั้ง -> ระบบ Rollback ยกเลิกทั้งพนักงานใหม่ การปรับเงินเดือน และผู้จัดการแผนกกลับสู่ค่าเดิม!");
                }

                conn.commit();
                System.out.println("[Tx 8] ฝ่าย HR บรรจุพนักงานใหม่ " + newEmpId + " และเลื่อนตำแหน่งพนักงาน " + promotedEmpId + " เป็นผู้จัดการแผนกสำเร็จ (COMMIT)");
            }
        } catch (SQLException ex) {
            conn.rollback();
            System.out.println("[Tx 8] ยกเลิกคำสั่งฝ่าย HR (ROLLBACK): " + ex.getMessage());
            throw ex;
        }
    }
}
