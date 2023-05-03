--
-- XXDOEC_CP_PROCESS_INVOICES  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_CP_PROCESS_INVOICES"
AS
    PROCEDURE update_inv_dtls_stg (p_invoice_line_id IN NUMBER, p_process_flag IN VARCHAR2, p_error_msg IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxdoec_factory_inv_dtls_stg
           SET process_flag = p_process_flag, error_message = p_error_msg
         WHERE invoice_detail_id = p_invoice_line_id;

        COMMIT;
    END;

    PROCEDURE upload_invoices (x_errbuff         OUT VARCHAR2,
                               x_rtn_code        OUT NUMBER,
                               p_invoice_id   IN     NUMBER)
    IS
        CURSOR c_inv_headers IS
            SELECT *
              FROM xxdoec_factory_invoices_stg
             WHERE     NVL (process_flag, 'N') IN ('N', 'E')
                   AND invoice_id = NVL (p_invoice_id, invoice_id);

        --
        CURSOR c_inv_lines (c_invoice_id IN NUMBER)
        IS
            SELECT *
              FROM xxdoec_factory_inv_dtls_stg
             WHERE     NVL (process_flag, 'N') IN ('N', 'E')
                   AND invoice_id = c_invoice_id;

        l_inv_line_rec    c_inv_lines%ROWTYPE;

        --
        CURSOR c_po_vendor (c_order_id          IN VARCHAR2,
                            c_fluid_recipe_id   IN VARCHAR2)
        IS
            SELECT aps.vendor_id, aps.vendor_name, aps.segment1 vendor_number,
                   apss.vendor_site_id, apss.vendor_site_code, poh.segment1 po_number,
                   poh.approved_date po_date, pll.po_header_id, pll.po_line_id,
                   pll.line_location_id
              FROM xxdoec_cp_shipment_dtls_stg csd, po_line_locations_all pll, po_headers_all poh,
                   ap_suppliers aps, ap_supplier_sites_all apss
             WHERE     csd.order_id = c_order_id
                   AND csd.fluid_recipe_id = c_fluid_recipe_id
                   AND pll.line_location_id = csd.po_line_location_id
                   AND poh.po_header_id = pll.po_header_id
                   AND aps.vendor_id = poh.vendor_id
                   AND apss.vendor_site_id = poh.vendor_site_id;

        l_po_vendor_rec   c_po_vendor%ROWTYPE;

        CURSOR c_ordered_item (c_order_id          IN VARCHAR2,
                               c_fluid_recipe_id   IN VARCHAR2)
        IS
            SELECT msi.inventory_item_id, --msi.segment1          item_code,
                                          SUBSTR (msi.segment1, 1, INSTR (msi.segment1, '-') - 1) item_code, --msi.segment2          item_color,
                                                                                                             SUBSTR (msi.segment1, INSTR (msi.segment1, '-') + 1, INSTR (msi.segment1, '-', INSTR (msi.segment1, '-') + 1) - INSTR (msi.segment1, '-') - 1) item_color,
                   --msi.segment3          item_size,
                   SUBSTR (msi.segment1, INSTR (msi.segment1, '-', INSTR (msi.segment1, '-') + 1) + 1, LENGTH (msi.segment1)) item_size, msi.attribute11 item_upc, ool.org_id
              FROM xxdoec_cp_shipment_dtls_stg csd, oe_order_lines_all ool, mtl_system_items_b msi
             WHERE     csd.order_id = c_order_id
                   AND csd.fluid_recipe_id = c_fluid_recipe_id
                   AND ool.line_id = csd.so_line_id
                   AND msi.inventory_item_id = ool.inventory_item_id
                   AND msi.organization_id = ool.ship_from_org_id;

        l_item_dtl_rec    c_ordered_item%ROWTYPE;

        CURSOR c_po_price (c_order_id          IN VARCHAR2,
                           c_fluid_recipe_id   IN VARCHAR2)
        IS
            SELECT pol.unit_price
              FROM xxdoec_cp_shipment_dtls_stg csd, po_line_locations_all pll, po_lines_all pol
             WHERE     csd.order_id = c_order_id
                   AND csd.fluid_recipe_id = c_fluid_recipe_id
                   AND pll.line_location_id = csd.po_line_location_id
                   AND pol.po_line_id = pll.po_line_id;

        --
        l_inv_header_id   NUMBER;
        l_valid_invoice   VARCHAR2 (1);
        l_invoice_total   NUMBER;
        l_po_price        NUMBER;
        l_error_msg       VARCHAR2 (2000);
    BEGIN
        FOR c_hdr IN c_inv_headers
        LOOP
            BEGIN
                l_valid_invoice   := fnd_api.G_RET_STS_SUCCESS;
                l_invoice_total   := 0;

                --
                OPEN c_inv_lines (c_hdr.invoice_id);

                FETCH c_inv_lines INTO l_inv_line_rec;

                CLOSE c_inv_lines;

                --
                OPEN c_po_vendor (l_inv_line_rec.order_id,
                                  l_inv_line_rec.fluid_recipe_id);

                FETCH c_po_vendor INTO l_po_vendor_rec;

                IF c_po_vendor%NOTFOUND
                THEN
                    CLOSE c_po_vendor;

                    l_valid_invoice   := fnd_api.G_RET_STS_ERROR;
                    l_error_msg       := 'Unable to match the Invoice to PO';
                ELSE
                    CLOSE c_po_vendor;

                    l_inv_header_id   := NULL;
                    DO_EDI.GET_NEXT_VALUES ('DO_EDI810IN_HEADERS_S',
                                            1,
                                            l_inv_header_id);

                    -- populate header
                    INSERT INTO do_edi.DO_EDI810IN_HEADERS (INV_HEADER_ID, INVOICE_NUMBER, INVOICE_DATE, PERFORMA_INV_NO, PORT_ETA, SHIPPING_DATE, ARRIVAL_DATE, MANUF_NAME, SHIP_FROM_NAME, SHIP_TO_NAME, VENDOR_NAME, VENDOR_NUMBER, VENDOR_ID, VENDOR_SITE_ID, VENDOR_SITE_CODE, BILL_TO_PARTY, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY, ARCHIVE_FLAG, PROCESS_STATUS, APPROVED, APPROVED_ON, APPROVED_BY, REJECTED_ON, REJECTED_BY
                                                            , COMMENTS)
                         VALUES (l_inv_header_id, c_hdr.invoice_number, c_hdr.invoice_date, NULL, NULL, NULL, NULL, NULL, NULL, NULL, SUBSTR (l_po_vendor_rec.vendor_name, 1, 30), l_po_vendor_rec.vendor_number, l_po_vendor_rec.vendor_id, l_po_vendor_rec.vendor_site_id, l_po_vendor_rec.vendor_site_code, 'Deckers US eCommerce', SYSDATE, FND_GLOBAL.USER_ID, SYSDATE, FND_GLOBAL.USER_ID, 'N', 'R', 'N', NULL, NULL, NULL, NULL
                                 , NULL);

                    -- Populate Items
                    FOR c_item IN c_inv_lines (c_hdr.invoice_id)
                    LOOP
                        BEGIN
                            l_po_vendor_rec   := NULL;

                            OPEN c_po_vendor (c_item.order_id,
                                              c_item.fluid_recipe_id);

                            FETCH c_po_vendor INTO l_po_vendor_rec;

                            IF c_po_vendor%NOTFOUND
                            THEN
                                CLOSE c_po_vendor;

                                l_valid_invoice   := fnd_api.G_RET_STS_ERROR;
                                l_error_msg       :=
                                    'Unable to match the invoice line to PO';
                                update_inv_dtls_stg (
                                    p_invoice_line_id   =>
                                        c_item.invoice_detail_id,
                                    p_process_flag   => 'E',
                                    p_error_msg      => l_error_msg);
                            ELSE
                                CLOSE c_po_vendor;

                                -- derive item details
                                OPEN c_ordered_item (c_item.order_id,
                                                     c_item.fluid_recipe_id);

                                FETCH c_ordered_item INTO l_item_dtl_rec;

                                CLOSE c_ordered_item;

                                -- derive po price, invoice total incase of Japan
                                IF l_item_dtl_rec.org_id = 232
                                THEN
                                    l_po_price   := 0;

                                    OPEN c_po_price (c_item.order_id,
                                                     c_item.fluid_recipe_id);

                                    FETCH c_po_price INTO l_po_price;

                                    CLOSE c_po_price;

                                    l_invoice_total   :=
                                        l_invoice_total + l_po_price;
                                ELSE
                                    l_po_price   := c_item.unit_cost;
                                    l_invoice_total   :=
                                        c_hdr.total_invoice_amount;
                                END IF;

                                --
                                INSERT INTO do_edi.DO_EDI810IN_ITEMS (
                                                INV_HEADER_ID,
                                                INVOICE_NUMBER,
                                                PO_NUMBER,
                                                PO_HEADER_ID,
                                                PO_LINE_ID,
                                                PO_LINE_LOCATION_ID,
                                                INVENTORY_ITEM_ID,
                                                QUANTITY,
                                                UNIT_PRICE,
                                                STYLE_CODE,
                                                COLOR_CODE,
                                                SIZE_CODE,
                                                UPC_CODE,
                                                COUNTRY_OF_ORIGIN,
                                                ARCHIVE_FLAG)
                                         VALUES (
                                                    l_inv_header_id,
                                                    c_hdr.invoice_number,
                                                    l_po_vendor_rec.po_number,
                                                    l_po_vendor_rec.po_header_id,
                                                    l_po_vendor_rec.po_line_id,
                                                    l_po_vendor_rec.line_location_id,
                                                    l_item_dtl_rec.inventory_item_id,
                                                    c_item.quantity,
                                                    l_po_price,
                                                    l_item_dtl_rec.item_code,
                                                    l_item_dtl_rec.item_color,
                                                    l_item_dtl_rec.item_size,
                                                    l_item_dtl_rec.item_upc,
                                                    'CN',
                                                    'N');

                                --
                                UPDATE xxdoec_factory_inv_dtls_stg
                                   SET po_line_location_id = l_po_vendor_rec.line_location_id, process_flag = 'S', error_message = NULL
                                 WHERE invoice_detail_id =
                                       c_item.invoice_detail_id;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_valid_invoice   := fnd_api.G_RET_STS_ERROR;
                                update_inv_dtls_stg (
                                    p_invoice_line_id   =>
                                        c_item.invoice_detail_id,
                                    p_process_flag   => 'E',
                                    p_error_msg      => SQLERRM);
                        END;
                    END LOOP;                                       -- c_items

                    -- populate footer
                    INSERT INTO do_edi.DO_EDI810IN_FOOTERS (INV_HEADER_ID,
                                                            INVOICE_NUMBER,
                                                            CARRIER_SCAC,
                                                            CARRIER_NAME,
                                                            VESSEL_NAME,
                                                            BOL_NUMBER,
                                                            INVOICE_TOTAL,
                                                            ARCHIVE_FLAG)
                         VALUES (l_inv_header_id, c_hdr.invoice_number, 'FXFE', 'FedEX', 'DROPSHIP', 'XXXX' || c_hdr.invoice_number
                                 , l_invoice_total, 'N');

                    -- populate edi PO table
                    INSERT INTO do_edi.do_edi810in_purchaseorders (
                                    INV_HEADER_ID,
                                    INVOICE_NUMBER,
                                    PO_NUMBER,
                                    PO_HEADER_ID,
                                    PO_DATE,
                                    ARCHIVE_FLAG)
                             VALUES (l_inv_header_id,
                                     c_hdr.invoice_number,
                                     l_po_vendor_rec.po_number,
                                     l_po_vendor_rec.po_header_id,
                                     l_po_vendor_rec.po_date,
                                     'N');
                END IF;

                --
                IF l_valid_invoice = fnd_api.G_RET_STS_SUCCESS
                THEN
                    UPDATE xxdoec_factory_invoices_stg
                       SET process_flag = 'S', error_message = NULL
                     WHERE invoice_id = c_hdr.invoice_id;

                    COMMIT;
                ELSE
                    ROLLBACK;

                    UPDATE xxdoec_factory_invoices_stg
                       SET process_flag = 'E', error_message = l_error_msg
                     WHERE invoice_id = c_hdr.invoice_id;

                    COMMIT;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_rtn_code   := -1;
                    x_errbuff    := SQLERRM;
                    ROLLBACK;

                    UPDATE xxdoec_factory_invoices_stg
                       SET process_flag = 'E', error_message = SUBSTR (x_errbuff, 1, 2000)
                     WHERE invoice_id = c_hdr.invoice_id;

                    COMMIT;
            END;
        END LOOP;                                                 -- c_headers
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_code   := -2;
            x_errbuff    := SQLERRM;
    END upload_invoices;
END xxdoec_cp_process_invoices;
/
