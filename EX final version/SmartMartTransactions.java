package com.smartmart.db;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;

public class SmartMartTransactions {

    // 1. คืนสินค้าที่ซื้อภายใน 15 วัน
    public static void returnMerchandiseWithin15Days(
            Connection conn, int transactionNumb, String returnSku, int returnQty) throws SQLException {

        String checkSaleSql = "SELECT s.in_store_transaction_date, "
                + "DATEDIFF(DAY, s.in_store_transaction_date, CAST(GETDATE() AS DATE)) AS days_diff, "
                + "i.in_store_quantity, i.in_store_price "
                + "FROM dbo.in_store_sale s "
                + "JOIN dbo.in_store_sale_item i ON s.in_store_transaction_numb = i.in_store_transaction_numb "
                + "WHERE s.in_store_transaction_numb = ? AND i.in_store_SKU = ?";
        String restoreStockSql = "UPDATE dbo.product_stocked SET number_on_hand = number_on_hand + ? WHERE SKU = ? AND in_store = 1";
        String updateItemSql = "UPDATE dbo.in_store_sale_item SET in_store_quantity = in_store_quantity - ? WHERE in_store_transaction_numb = ? AND in_store_SKU = ?";
        String deleteItemSql = "DELETE FROM dbo.in_store_sale_item WHERE in_store_transaction_numb = ? AND in_store_SKU = ?";
        String updateHeaderSql = "UPDATE dbo.in_store_sale SET in_store_sale_product_total = in_store_sale_product_total - ?, "
                + "in_store_sale_total = in_store_sale_total - ? WHERE in_store_transaction_numb = ?";

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);

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

            conn.commit();
            System.out.println("คืนสินค้าใบเสร็จ " + transactionNumb + " สำเร็จ");
        } catch (SQLException ex) {
            conn.rollback();
            throw ex;
        }
    }

    // 2. สั่งซื้อสินค้าหน้าร้านด้วยบัตรเครดิต
    public static void purchaseWithCreditCardInStore(
            Connection conn, int transactionNumb, Date transactionDate,
            String sku, int quantity, BigDecimal unitPrice, BigDecimal salesTax,
            int creditCardPaymentTypeCode, String creditCardNumb,
            Date cardExpDate, String nameOnCard) throws SQLException {

        String deductStockSql = "UPDATE dbo.product_stocked SET number_on_hand = number_on_hand - ? WHERE SKU = ? AND in_store = 1 AND number_on_hand >= ?";
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

                psStock.setInt(1, quantity);
                psStock.setString(2, sku);
                psStock.setInt(3, quantity);
                if (psStock.executeUpdate() == 0) {
                    throw new SQLException("สต็อกสินค้าไม่เพียงพอสำหรับ SKU: " + sku);
                }

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

                psCard.setInt(1, transactionNumb);
                psCard.setString(2, creditCardNumb);
                psCard.setDate(3, cardExpDate);
                psCard.setString(4, nameOnCard);
                psCard.executeUpdate();

                conn.commit();
                System.out.println("สั่งซื้อสินค้าด้วยบัตรเครดิต ใบเสร็จ " + transactionNumb + " สำเร็จ");
            }
        } catch (SQLException ex) {
            conn.rollback();
            throw ex;
        }
    }

    // 3. ค้นหาสินค้าที่พร้อมจำหน่ายตามสาขาและคลังสินค้า
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
                        String location;
                        if (rs.getBoolean("in_store")) {
                            location = "Store " + rs.getInt("store_numb") + " (Dept " + rs.getInt("dept_numb") + ")";
                        } else {
                            location = "Warehouse " + rs.getInt("warehouse_numb");
                        }
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

    // 4. อัปเดตสถานะการจัดส่งและซ่อนที่อยู่ลูกค้า
    public static void updateShippingStatusAndMaskAddress(
            Connection conn, int webSaleNumb, String webSku, int shippingAddressNumb,
            Timestamp shippedTimestamp, BigDecimal merchTotal,
            BigDecimal taxAmount, BigDecimal shippingFee) throws SQLException {

        String insertShipmentSql = "INSERT INTO dbo.web_sale_shipment (web_sale_numb, web_sale_date_shipped, "
                + "web_shipment_merchandise_total, web_shipment_tax, web_shipment_shipping, web_shipment_total_charged) VALUES (?, ?, ?, ?, ?, ?)";
        String updateItemStatusSql = "UPDATE dbo.web_sale_item SET web_sale_shipped = 1, web_sale_date_shipped = ? WHERE web_sale_numb = ? AND web_sale_SKU = ?";
        String maskShippingAddressSql = "UPDATE dbo.web_sale_shipping_address SET web_shipping_street = '*** MASKED ***' WHERE web_shipping_address_numb = ?";

        try {
            conn.setAutoCommit(false);
            conn.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);

            try (PreparedStatement psShipment = conn.prepareStatement(insertShipmentSql);
                 PreparedStatement psItem = conn.prepareStatement(updateItemStatusSql);
                 PreparedStatement psMaskAddr = conn.prepareStatement(maskShippingAddressSql)) {

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
                if (psItem.executeUpdate() == 0) {
                    throw new SQLException("ไม่พบรายการสินค้าในคำสั่งซื้อเว็บที่ต้องการอัปเดตสถานะจัดส่ง");
                }

                psMaskAddr.setInt(1, shippingAddressNumb);
                if (psMaskAddr.executeUpdate() == 0) {
                    throw new SQLException("ไม่พบที่อยู่จัดส่งที่ต้องการซ่อนข้อมูลส่วนบุคคล");
                }

                conn.commit();
                System.out.println("อัปเดตสถานะจัดส่งใบสั่งซื้อเว็บ " + webSaleNumb + " และซ่อนที่อยู่ลูกค้าสำเร็จ");
            }
        } catch (SQLException ex) {
            conn.rollback();
            throw ex;
        }
    }
}
