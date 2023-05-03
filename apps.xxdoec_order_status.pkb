--
-- XXDOEC_ORDER_STATUS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_ORDER_STATUS"
AS
    FUNCTION get_token (the_list    VARCHAR2,
                        the_index   NUMBER,
                        delim       VARCHAR2:= '-')
        RETURN VARCHAR2
    IS
        start_pos   NUMBER;
        end_pos     NUMBER;
    BEGIN
        IF the_index = 1
        THEN
            start_pos   := 1;
        ELSE
            start_pos   :=
                INSTR (the_list, delim, 1,
                       the_index - 1);

            IF start_pos = 0
            THEN
                RETURN NULL;
            ELSE
                start_pos   := start_pos + LENGTH (delim);
            END IF;
        END IF;

        end_pos   :=
            INSTR (the_list, delim, start_pos,
                   1);

        IF end_pos = 0
        THEN
            RETURN SUBSTR (the_list, start_pos);
        ELSE
            RETURN SUBSTR (the_list, start_pos, end_pos - start_pos);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            INSERT INTO xxdo.xxdoec_order_status_log (order_number,
                                                      called_with,
                                                      createdate)
                     VALUES (
                                '',
                                   'Error in get_token function for '
                                || the_list
                                || '.',
                                SYSDATE);

            RETURN '';
    END get_token;

    PROCEDURE get_order_list (p_customer_number   IN     VARCHAR2,
                              o_orders               OUT t_order_list_cursor)
    IS
    BEGIN
        -----------------------------------------------------------------------
        -- Start of Changes by BT Technology Team V1.1 12/03/2015
        -----------------------------------------------------------------------
        /*INSERT INTO xxdo.xxdoec_order_status_log
                    (customer_number,
                     called_with,
                     createdate
                    )
             VALUES (p_customer_number,
                     'Called with customer number:  ' || p_customer_number
                     || '.',
                     CURRENT_TIMESTAMP
                    );

        COMMIT;*/
        -----------------------------------------------------------------------
        -- End of Changes by BT Technology Team V1.1 12/03/2015
        -----------------------------------------------------------------------

        OPEN o_orders FOR
            SELECT CASE                              -- un-prefix order number
                       WHEN SUBSTR (ooh.orig_sys_document_ref,
                                    1,
                                    2) =
                            'DW'
                       THEN
                           SUBSTR (ooh.orig_sys_document_ref,
                                   3)
                       WHEN SUBSTR (ooh.orig_sys_document_ref,
                                    1,
                                    2) =
                            '90'
                       THEN
                           SUBSTR (ooh.orig_sys_document_ref,
                                   3)
                       WHEN SUBSTR (ooh.orig_sys_document_ref,
                                    1,
                                    2) =
                            '99'
                       THEN
                           SUBSTR (ooh.orig_sys_document_ref,
                                   3)
                       ELSE
                           ooh.orig_sys_document_ref
                   END order_number,
                   hca.attribute17 locale_id,
                   ooh.ordered_date,
                   CASE                           -- un-prefix customer number
                       WHEN SUBSTR (hca.account_number, 1, 2) =
                            'DW'
                       THEN
                           SUBSTR (hca.account_number, 3)
                       WHEN SUBSTR (hca.account_number, 1, 2) =
                            '90'
                       THEN
                           SUBSTR (hca.account_number, 3)
                       WHEN SUBSTR (hca.account_number, 1, 2) =
                            '99'
                       THEN
                           SUBSTR (hca.account_number, 3)
                       ELSE
                           hca.account_number
                   END customer_number,
                   hca.account_name,
                   (SELECT SUM (ool.unit_list_price * ool.ordered_quantity)
                      FROM oe_order_lines_all ool
                     WHERE ool.header_id = ooh.header_id) total_order_amount,
                   ooh.flow_status_code order_status,
                   /* msi.segment1 model_number,
                    msi.segment2 color_code,
                    msi.segment3 product_size,
                    msi.description product_name,    */
                   --commented by BT Technology Team on 12/11/2014
                   msi.style_number model_number, --Added by BT Technology Team on 12/11/2014  BEGIN
                   msi.color_code color_code,
                   msi.item_size product_size,
                   msi.item_description product_name, --Added by BT Technology Team on 12/11/2014  END
                   ool.ordered_quantity,
                   ool.unit_selling_price,
                   ool.ordered_quantity * ool.unit_selling_price subtotal,
                   ool.flow_status_code line_status
              FROM oe_order_headers_all ooh
                   LEFT JOIN oe_order_lines_all ool
                       ON ool.header_id = ooh.header_id
                   LEFT JOIN hz_cust_accounts hca
                       ON hca.cust_account_id = ooh.sold_to_org_id
                   --LEFT JOIN mtl_system_items_b msi                                          --commented by BT Technology Team on 12/11/2014
                   LEFT JOIN xxd_common_items_v msi --Added by BT Technology Team on 12/11/2014
                       ON     msi.inventory_item_id = ool.inventory_item_id
                          AND msi.organization_id = ool.ship_from_org_id
                   LEFT JOIN oe_order_lines_all ool_r
                       ON ool_r.reference_line_id = ool.line_id
                   LEFT JOIN oe_order_headers_all ooh_r
                       ON ooh_r.header_id = ool_r.header_id
             WHERE     ool.line_category_code != 'RETURN'
                   AND hca.account_number = p_customer_number
                   --AND ooh.order_source_id = 1044  -- commented by BT Technology team on 2014/11/05
                   AND ooh.order_source_id IN (SELECT ORDER_SOURCE_ID
                                                 FROM oe_order_sources
                                                WHERE name = 'Flagstaff') --Added by BT Technology Team on 2014/11/05
            UNION ALL
            SELECT rhs.order_id order_number,
                   hca.attribute17 locale_id,
                   rhs.order_date ordered_date,
                   CASE                           -- un-prefix customer number
                       WHEN SUBSTR (hca.account_number, 1, 2) = 'DW'
                       THEN
                           SUBSTR (hca.account_number, 3)
                       WHEN SUBSTR (hca.account_number, 1, 2) = '90'
                       THEN
                           SUBSTR (hca.account_number, 3)
                       WHEN SUBSTR (hca.account_number, 1, 2) = '99'
                       THEN
                           SUBSTR (hca.account_number, 3)
                       ELSE
                           hca.account_number
                   END customer_number,
                   hca.account_name,
                   rhs.order_total total_order_amount,
                   'AWAITING_RETURN' flow_status_code,
                   /* msi.segment1 model_number,
                   msi.segment2 color_code,
                   msi.segment3 product_size,
                   msi.description product_name,    */
                   --commented by BT Technology Team on 12/11/2014
                   msi.style_number model_number, --Added by BT Technology Team on 12/11/2014  BEGIN
                   msi.color_code color_code,
                   msi.item_size product_size,
                   msi.item_description product_name, --Added by BT Technology Team on 12/11/2014  END
                   rhl.quantity ordered_quantity,
                   NULL unit_selling_price,
                   NULL subtotal,
                   'AWAITING_RETURN' line_status
              FROM xxdo.xxdoec_return_header_staging rhs
                   LEFT JOIN hz_cust_accounts hca
                       ON hca.account_number = rhs.dw_customer_id
                   LEFT JOIN xxdo.xxdoec_return_lines_staging rhl
                       ON rhs.order_id = rhl.order_id
                   --LEFT JOIN inv.mtl_system_items_b msi                                --commented by BT Technology team on 12/11/2014
                   LEFT JOIN xxd_common_items_v msi --Added by BT Technology Team on 12/11/2014
                       --ON msi.attribute11 = rhl.upc                                        --commented By BT Technology Team on 12/11/2014
                       ON     msi.upc_code = rhl.upc --Added by BT Technology Team on 12/11/2014
                          --AND msi.organization_id =7                                             -- commented by BT Technology team on  2014/11/05
                          AND msi.organization_id IN
                                  (SELECT ood.ORGANIZATION_ID
                                     FROM fnd_lookup_values flv, org_organization_definitions ood
                                    WHERE     lookup_type =
                                              'XXD_1206_INV_ORG_MAPPING'
                                          AND lookup_code = 7
                                          AND flv.attribute1 =
                                              ood.ORGANIZATION_CODE
                                          AND language = USERENV ('LANG')) ---Added by BT Technology Team on 2014/11/05
                   LEFT JOIN apps.oe_order_headers_all ooh
                       ON ooh.cust_po_number = rhs.dw_customer_id
             WHERE     rhs.dw_customer_id = p_customer_number
                   AND ooh.cust_po_number IS NULL
            ORDER BY order_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            INSERT INTO xxdo.xxdoec_order_status_log (customer_number,
                                                      called_with,
                                                      createdate)
                     VALUES (
                                p_customer_number,
                                   'ERROR calling with customer number:  '
                                || p_customer_number
                                || '.',
                                CURRENT_TIMESTAMP);

            COMMIT;
    END;

    PROCEDURE get_order_detail (p_order_number IN VARCHAR2, p_invoice_data_flag IN VARCHAR2, -- CCR0008713
                                                                                             p_invoice_data_OUs IN VARCHAR2, -- CCR0008713
                                                                                                                             o_order_detail OUT t_order_detail_cursor, o_order_frttax OUT t_order_frttax_cursor, o_order_address OUT t_order_address_cursor
                                , o_order_staging_lines OUT t_order_staging_lines_cursor, o_order_attribute_detail OUT t_order_note_detail_cursor)
    IS
        order_total                    NUMBER := 0;
        return_total                   NUMBER := 0;
        final_total                    NUMBER := 0;
        l_source_line_id               NUMBER := 0;
        l_source_line_id_save          NUMBER := -1;
        l_tracking_number              VARCHAR2 (30) := '';
        l_tracking_number_save         VARCHAR2 (30) := '';
        l_freight_code                 VARCHAR2 (30) := '';
        l_freight_code_save            VARCHAR2 (30) := '';
        l_desc                         VARCHAR2 (80) := '';
        l_desc_save                    VARCHAR2 (80) := '';
        l_build_tracking_number        VARCHAR2 (2000) := '';
        l_latest_tracking_number       VARCHAR2 (30) := 'NONE';
        l_detl_count                   NUMBER := 0;
        l_oracle_customer_id           NUMBER := 0;
        l_model                        VARCHAR2 (100) := '';
        l_color                        VARCHAR2 (100) := '';
        l_size                         VARCHAR2 (100) := '';
        l_lineid                       NUMBER := 0;
        l_return_qty                   NUMBER := 0;
        l_original_order_number        VARCHAR (30) := '0';
        l_header_id                    NUMBER := 0;
        l_has_bling                    VARCHAR2 (3) := 'NO';
        l_bling_amount                 NUMBER := 0;
        l_bling_product_id             VARCHAR2 (50) := '';
        l_bling_line_id                NUMBER := -1;
        l_cod_charge_total             NUMBER := 0;
        l_rtn_status                   VARCHAR2 (3) := '';
        l_rtn_message                  VARCHAR2 (4000) := '';
        l_eligible_for_cancel_reason   VARCHAR2 (50) := '';
        l_org_id                       NUMBER;                   -- CCR0008713

        CURSOR c_sku (p_order_id VARCHAR2)
        IS
            SELECT sku, line_id
              FROM xxdo.xxdoec_return_lines_staging
             WHERE order_id = p_order_id AND UPPER (line_type) = 'RETURN';

        CURSOR c_bling_lines (p_cust_po_number VARCHAR2)
        IS
            SELECT opa.adjusted_amount, opa.attribute2, ool.line_id
              FROM oe_price_adjustments opa
                   INNER JOIN oe_order_lines_all ool
                       ON     opa.header_id = ool.header_id
                          AND opa.line_id = ool.line_id
             WHERE     opa.charge_type_code = 'BLING'
                   AND ool.cust_po_number = p_cust_po_number;

        CURSOR c_delivery_line (p_cust_po_number VARCHAR2)
        IS
            SELECT DISTINCT wdd.source_line_id, wdd.tracking_number, wc.freight_code,
                            flv_smc.description
              FROM wsh_delivery_details wdd
                   JOIN wsh_carriers wc ON wc.carrier_id = wdd.carrier_id
                   JOIN fnd_lookup_values flv_smc
                       ON flv_smc.lookup_code = wdd.ship_method_code
                   JOIN apps.oe_order_lines_all ool
                       ON wdd.source_line_id = ool.line_id
             WHERE     wdd.source_code = 'OE'
                   AND flv_smc.lookup_type = 'SHIP_METHOD'
                   AND flv_smc.LANGUAGE = 'US'
                   AND flv_smc.lookup_code = wdd.ship_method_code
                   AND ool.cust_po_number = p_cust_po_number      --'06502291'
                   --AND ool.order_source_id IN (1044)                                                             --commented by BT Technology Team on 2014/11/05
                   AND ool.order_source_id IN (SELECT ORDER_SOURCE_ID
                                                 FROM oe_order_sources
                                                WHERE name = 'Flagstaff') --Added by BT Technology Team on 2014/11/05
                   AND wdd.source_line_id = ool.line_id
            UNION
            SELECT ssd.line_id,
                   ssd.tracking_number,
                   (SELECT freight_code
                      FROM wsh_carrier_services wcs, wsh_carriers wc
                     WHERE     wcs.ship_method_code = ssd.ship_method_code
                           AND wc.carrier_id = wcs.carrier_id
                           AND ROWNUM = 1) freight_code,
                   flv.description
              FROM apps.xxdoec_sfs_shipment_dtls_stg ssd, fnd_lookup_values flv
             WHERE     ssd.web_order_number = p_cust_po_number
                   AND flv.lookup_type = 'SHIP_METHOD'
                   AND flv.LANGUAGE = 'US'
                   AND flv.lookup_code = ssd.ship_method_code
                   AND ssd.status = 'SUCCESS'
            ORDER BY 1;
    BEGIN
        -----------------------------------------------------------------------
        -- Start of Changes by BT Technology Team V1.1 12/03/2015
        -----------------------------------------------------------------------
        /*INSERT INTO xxdo.xxdoec_order_status_log
                    (order_number,
                     called_with,
                     createdate
                    )
             VALUES (p_order_number,
                     'NEW:  Called with order number:  ' || p_order_number
                     || '.',
                     SYSDATE
                    );

        COMMIT;*/

        -----------------------------------------------------------------------
        -- End of Changes by BT Technology Team V1.1 12/03/2015
        -----------------------------------------------------------------------

        DELETE FROM gtt_order_detail;

        DELETE FROM gtt_order_frttax;

        DELETE FROM gtt_order_address;

        DELETE FROM gtt_return_lines_staging;

        DELETE FROM gtt_order_attributes;

        -- Put initial data into the global table by...
        INSERT INTO gtt_order_detail (header_id, line_grp_id, line_id,
                                      shipping_date, inventory_item_id, fluid_recipe_id, ordered_quantity, shipped_quantity, cancelled_quantity, unit_selling_price, subtotal, taxamount, line_status, org_id, eligible_to_cancel
                                      , ship_from_org_id) -- Modified on 16-SEP-2015
            SELECT header_id,
                   attribute18,
                   line_id,
                   actual_shipment_date,
                   inventory_item_id,
                   customer_job,
                   ordered_quantity,
                   shipped_quantity,
                   cancelled_quantity,
                   unit_selling_price,
                   CASE
                       WHEN (line_category_code = 'RETURN')
                       THEN
                           ((unit_selling_price * -1) * ordered_quantity)
                       ELSE
                           (unit_selling_price * ordered_quantity)
                   END,
                   CASE
                       WHEN (line_category_code = 'RETURN')
                       THEN
                           tax_value * -1
                       ELSE
                           tax_value
                   END,
                   flow_status_code,
                   org_id,
                   get_eligible_to_cancel (line_id),
                   ship_from_org_id                 -- Modified on 16-SEP-2015
              FROM apps.oe_order_lines_all
             WHERE     cust_po_number = p_order_number
                   --AND order_source_id = 1044;                                                                 --commented by BT Technology team on 2014/11/05
                   AND order_source_id IN (SELECT ORDER_SOURCE_ID
                                             FROM oe_order_sources
                                            WHERE name = 'Flagstaff'); --Added by BT Technology Team on 2014/11/05

        SELECT COUNT (*) INTO l_detl_count FROM gtt_order_detail;

        IF (l_detl_count = 0)
        THEN
            BEGIN
                -- There is nothing in the oe_order_headers_all or oe_order_lines_all for this order number.
                -- See if maybe it is in the return header/lines staging tables.
                --dbms_output.put_line('marker aa');
                INSERT INTO gtt_order_detail (header_id,
                                              order_number,
                                              ordered_date,
                                              line_status,
                                              currency,
                                              site_id,
                                              attribute18,
                                              line_id,
                                              ordered_quantity,
                                              order_line_status,
                                              order_status,
                                              return_processed,
                                              return_type,
                                              original_dw_order_id)
                    SELECT a.ID, a.order_id, a.order_date,
                           'RETURN_STAGED', a.currency, a.site_id,
                           a.site_id, b.line_id, b.quantity,
                           'STAGED FOR RETURN', 'RETURN_STAGED', 'NO',
                           a.return_type, a.original_dw_order_id
                      FROM xxdo.xxdoec_return_header_staging a
                           JOIN xxdo.xxdoec_return_lines_staging b
                               ON a.ID = b.ID
                     WHERE     a.order_id = p_order_number
                           AND UPPER (b.line_type) = 'RETURN'; --'07060143_RT';\

                -- break out the sku.
                FOR c_product IN c_sku (p_order_number)
                LOOP
                    --dbms_output.put_line('marker ab');
                    --dbms_output.put_line(c_product.sku);
                    --dbms_output.put_line(c_product.line_id);
                    l_model    := '';
                    l_color    := '';
                    l_size     := '';
                    l_lineid   := 0;

                    SELECT xxdoec_order_status.get_token (c_product.sku, 2, '-')
                      INTO l_color
                      FROM DUAL;

                    SELECT xxdoec_order_status.get_token (c_product.sku, 1, '-')
                      INTO l_model
                      FROM DUAL;

                    SELECT xxdoec_order_status.get_token (c_product.sku, 3, '-')
                      INTO l_size
                      FROM DUAL;

                    l_lineid   := TO_NUMBER (c_product.line_id);

                    --dbms_output.put_line(l_model);
                    --dbms_output.put_line(l_color);
                    --dbms_output.put_line(l_size);
                    --dbms_output.put_line(l_lineid);
                    --dbms_output.put_line(p_order_number);
                    UPDATE gtt_order_detail
                       SET model_number   = l_model
                     WHERE     order_number = TRIM (p_order_number)
                           AND line_id = l_lineid;

                    UPDATE gtt_order_detail
                       SET color_code   = l_color
                     WHERE     order_number = TRIM (p_order_number)
                           AND line_id = l_lineid;

                    UPDATE gtt_order_detail
                       SET product_size   = l_size
                     WHERE     order_number = TRIM (p_order_number)
                           AND line_id = l_lineid;

                    UPDATE gtt_order_detail
                       SET (staged_return_quantity)   =
                               (SELECT SUM (quantity)
                                  FROM xxdo.xxdoec_return_lines_staging
                                 WHERE     order_id = p_order_number
                                       AND line_id = l_lineid
                                       AND UPPER (line_type) = 'RETURN');

                    --Get returned quantity based on original order
                    SELECT original_dw_order_id
                      INTO l_original_order_number
                      FROM xxdo.xxdoec_return_header_staging
                     WHERE order_id = p_order_number AND ROWNUM = 1;

                    UPDATE gtt_order_detail
                       SET (returned_quantity)   =
                               (SELECT CASE
                                           WHEN (ool.line_category_code = 'RETURN')
                                           THEN
                                               ool.ordered_quantity
                                           ELSE
                                               (SELECT SUM (ordered_quantity)
                                                  FROM apps.oe_order_lines_all
                                                 WHERE reference_line_id =
                                                       ool.line_id)
                                       END returned_quantity
                                  FROM apps.oe_order_lines_all ool
                                 WHERE     ool.cust_po_number =
                                           l_original_order_number
                                       AND l_lineid = ool.line_id);

                    --put this into a common method so it can be used by other packages

                    --Get any refund amount for the line
                    UPDATE gtt_order_detail
                       SET (refund_line_total)   =
                               (SELECT NVL (SUM (refund_quantity * refund_unit_amount), 0)
                                  FROM apps.xxdoec_order_manual_refunds omr
                                       JOIN apps.oe_order_lines_all ool
                                           ON     omr.header_id =
                                                  ool.header_id
                                              AND omr.line_id = ool.line_id
                                 WHERE     ool.cust_po_number =
                                           l_original_order_number
                                       AND l_lineid = ool.line_id
                                       AND omr.pg_status = 'S');
                --put this into a common method so it can be used by other packages
                END LOOP;

                -- get customer information.
                SELECT NVL (oracle_customer_id, 0)
                  INTO l_oracle_customer_id
                  FROM xxdo.xxdoec_return_header_staging
                 WHERE order_id = p_order_number AND ROWNUM = 1;

                --dbms_output.put_line('customer id:  '||l_oracle_customer_id);
                IF (l_oracle_customer_id) <> 0
                THEN
                    BEGIN
                        UPDATE gtt_order_detail
                           SET (customer_number,
                                locale_id,
                                account_name,
                                site_id,
                                email_address,
                                attribute18,
                                bill_to_address1,
                                bill_to_address2,
                                bill_to_city,
                                bill_to_state,
                                bill_to_postal_code,
                                bill_to_country)   =
                                   (SELECT DISTINCT CASE
                                                        -- un-prefix customer number
                                                        WHEN SUBSTR (
                                                                 hca.account_number,
                                                                 1,
                                                                 2) =
                                                             'DW'
                                                        THEN
                                                            SUBSTR (
                                                                hca.account_number,
                                                                3)
                                                        WHEN SUBSTR (
                                                                 hca.account_number,
                                                                 1,
                                                                 2) =
                                                             '90'
                                                        THEN
                                                            SUBSTR (
                                                                hca.account_number,
                                                                3)
                                                        WHEN SUBSTR (
                                                                 hca.account_number,
                                                                 1,
                                                                 2) =
                                                             '99'
                                                        THEN
                                                            SUBSTR (
                                                                hca.account_number,
                                                                3)
                                                        ELSE
                                                            hca.account_number
                                                    END customer_number,
                                                    hca.attribute17,
                                                    hca.account_name,
                                                    hca.attribute18,
                                                    hp.email_address,
                                                    hca.attribute18,
                                                    hp.address1,
                                                    hp.address2,
                                                    hp.city,
                                                    CASE
                                                        WHEN hp.state IS NULL
                                                        THEN
                                                            hp.province
                                                        ELSE
                                                            hp.state
                                                    END state,
                                                    hp.postal_code,
                                                    hp.country
                                      FROM apps.hz_cust_accounts hca
                                           JOIN
                                           xxdo.xxdoec_return_header_staging
                                           rh
                                               ON hca.cust_account_id =
                                                  rh.oracle_customer_id
                                           JOIN apps.hz_parties hp
                                               ON hp.party_id = hca.party_id
                                     WHERE rh.order_id = p_order_number);
                    END;

                    INSERT INTO gtt_order_address
                        SELECT hcsu_b.site_use_code,
                               hl_b.address1,
                               hl_b.address2,
                               hl_b.city,
                               CASE
                                   WHEN hl_b.state IS NULL THEN hl_b.province
                                   ELSE hl_b.state
                               END state,
                               hl_b.postal_code,
                               hl_b.country,
                               TRIM (SUBSTR (hcsu_b.LOCATION, 0, 30)) NAME,
                               hcp_b.phone_number,
                               '',
                               NULL,
                               NULL
                          FROM xxdo.xxdoec_return_header_staging rh
                               JOIN XXDO.XXDOEC_RETURN_LINES_STAGING rl
                                   ON rl.order_id = rh.order_id
                               JOIN apps.hz_cust_accounts hca
                                   ON hca.cust_account_id =
                                      l_oracle_customer_id
                               JOIN apps.hz_party_sites hps_b
                                   ON hps_b.party_id = hca.party_id
                               JOIN apps.hz_cust_acct_sites_all hcas_b
                                   ON     hcas_b.cust_account_id =
                                          hca.cust_account_id
                                      AND hcas_b.party_site_id =
                                          hps_b.party_site_id
                               JOIN apps.hz_cust_site_uses_all hcsu_b
                                   ON     hcsu_b.cust_acct_site_id =
                                          hcas_b.cust_acct_site_id
                                      AND (hcsu_b.site_use_code = 'SHIP_TO' OR hcsu_b.site_use_code = 'BILL_TO')
                               JOIN apps.hz_locations hl_b
                                   ON hps_b.location_id = hl_b.location_id
                               LEFT JOIN apps.hz_contact_points hcp_b
                                   ON (hcas_b.party_site_id = hcp_b.owner_table_id AND hcp_b.owner_table_name = 'HZ_PARTY_SITES' AND hcp_b.contact_point_type = 'PHONE')
                         WHERE     rh.order_id = p_order_number
                               AND (hcsu_b.site_use_id = rh.bill_to_addr_id OR hcsu_b.site_use_id = rh.ship_to_addr_id)
                               AND NVL (hps_b.status, 'A') = 'A'
                               AND NVL (hcas_b.status, 'A') = 'A'
                               AND NVL (hcsu_b.status, 'A') = 'A';
                ELSE
                    UPDATE gtt_order_detail
                       SET (customer_number, locale_id, account_name,
                            email_address)   =
                               (SELECT rh.xmlpayload.EXTRACT ('//CustomerID/text()').getstringval () "CustomerID", rh.xmlpayload.EXTRACT ('//LanguageCode/text()').getstringval () "LanguageCode", CONCAT (CONCAT (rh.xmlpayload.EXTRACT ('/DCDCustomer/FirstName/text()').getstringval (), ' '), rh.xmlpayload.EXTRACT ('/DCDCustomer/LastName/text()').getstringval ()),
                                       rh.xmlpayload.EXTRACT ('//EmailAddress/text()').getstringval () "EmailAddress"
                                  FROM xxdo.xxdoec_return_header_staging rh
                                 WHERE     order_id = p_order_number
                                       AND ROWNUM = 1);

                    --Get billing address details
                    INSERT INTO gtt_order_address
                        SELECT 'BILL_TO', rh.xmlpayload.EXTRACT ('//BillToAddress/AddressLine1/text()').getstringval (), rh.xmlpayload.EXTRACT ('//BillToAddress/AddressLine2/text()').getstringval (),
                               rh.xmlpayload.EXTRACT ('//BillToAddress/City/text()').getstringval (), rh.xmlpayload.EXTRACT ('//BillToAddress/State/text()').getstringval (), rh.xmlpayload.EXTRACT ('//BillToAddress/PostalCode/text()').getstringval (),
                               rh.xmlpayload.EXTRACT ('//BillToAddress/Country/text()').getstringval (), CONCAT (CONCAT (rh.xmlpayload.EXTRACT ('//BillToAddress/FirstName/text()').getstringval (), ' '), rh.xmlpayload.EXTRACT ('//BillToAddress/LastName/text()').getstringval ()), rh.xmlpayload.EXTRACT ('//BillToAddress/Phone/text()').getstringval (),
                               '', NULL, NULL
                          FROM xxdo.xxdoec_return_header_staging rh
                         WHERE rh.order_id = p_order_number;

                    --Get shipping address details
                    INSERT INTO gtt_order_address
                        SELECT 'SHIP_TO', rh.xmlpayload.EXTRACT ('//ShipToAddress/AddressLine1/text()').getstringval (), rh.xmlpayload.EXTRACT ('//ShipToAddress/AddressLine2/text()').getstringval (),
                               rh.xmlpayload.EXTRACT ('//ShipToAddress/City/text()').getstringval (), rh.xmlpayload.EXTRACT ('//ShipToAddress/State/text()').getstringval (), rh.xmlpayload.EXTRACT ('//ShipToAddress/PostalCode/text()').getstringval (),
                               rh.xmlpayload.EXTRACT ('//ShipToAddress/Country/text()').getstringval (), CONCAT (CONCAT (rh.xmlpayload.EXTRACT ('//ShipToAddress/FirstName/text()').getstringval (), ' '), rh.xmlpayload.EXTRACT ('//ShipToAddress/LastName/text()').getstringval ()), rh.xmlpayload.EXTRACT ('//ShipToAddress/Phone/text()').getstringval (),
                               '', NULL, NULL
                          FROM xxdo.xxdoec_return_header_staging rh
                         WHERE rh.order_id = p_order_number;
                END IF;
            END;
        END IF;

        -- Now update those lines with data from oe_order_headers_all
        IF (l_detl_count > 0)
        THEN
            UPDATE gtt_order_detail
               SET (order_number, ordered_date, order_status,
                    currency, transactional_curr_code)   =
                       (SELECT cust_po_number, ordered_date, flow_status_code,
                               transactional_curr_code, transactional_curr_code
                          FROM apps.oe_order_headers_all
                         WHERE     header_id = gtt_order_detail.header_id
                               -- AND order_source_id IN (1044)); --commented by BT Technology Team    on 2014/11/05
                               AND order_source_id IN
                                       (SELECT ORDER_SOURCE_ID
                                          FROM oe_order_sources
                                         WHERE name = 'Flagstaff')); --Added by BT Technology Team on 2014/11/05

            -- update with data from hz_cust_accounts
            UPDATE gtt_order_detail
               SET (customer_number, locale_id, account_name,
                    site_id, email_address, attribute18)   =
                       (SELECT DISTINCT CASE
                                            -- un-prefix customer number
                                            WHEN SUBSTR (hca.account_number,
                                                         1,
                                                         2) =
                                                 'DW'
                                            THEN
                                                SUBSTR (hca.account_number,
                                                        3)
                                            WHEN SUBSTR (hca.account_number,
                                                         1,
                                                         2) =
                                                 '90'
                                            THEN
                                                SUBSTR (hca.account_number,
                                                        3)
                                            WHEN SUBSTR (hca.account_number,
                                                         1,
                                                         2) =
                                                 '99'
                                            THEN
                                                SUBSTR (hca.account_number,
                                                        3)
                                            ELSE
                                                hca.account_number
                                        END customer_number,
                                        hca.attribute17,
                                        hca.account_name,
                                        hca.attribute18,
                                        hp.email_address,
                                        hca.attribute18
                          FROM apps.hz_cust_accounts hca
                               JOIN apps.oe_order_headers_all ooh
                                   ON hca.cust_account_id =
                                      ooh.sold_to_org_id
                               JOIN apps.hz_parties hp
                                   ON hp.party_id = hca.party_id
                         WHERE     ooh.cust_po_number = p_order_number
                               -- AND ooh.order_source_id IN (1044)); --commented by BT Technology team on 2014/11/05
                               AND ooh.order_source_id IN
                                       (SELECT ORDER_SOURCE_ID
                                          FROM oe_order_sources
                                         WHERE name = 'Flagstaff')); --Added by BT Technology team on 2014/11/05

            -- Now get address information
            UPDATE gtt_order_detail
               SET (bill_to_address1, bill_to_address2, bill_to_city,
                    bill_to_state, bill_to_postal_code, bill_to_country)   =
                       (SELECT DISTINCT hl_b.address1,
                                        hl_b.address2,
                                        hl_b.city,
                                        CASE
                                            WHEN hl_b.state IS NULL
                                            THEN
                                                hl_b.province
                                            ELSE
                                                hl_b.state
                                        END state,
                                        hl_b.postal_code,
                                        hl_b.country
                          FROM apps.oe_order_headers_all ooh
                               JOIN apps.hz_cust_site_uses_all hcsu_b
                                   ON hcsu_b.site_use_id =
                                      ooh.invoice_to_org_id
                               JOIN apps.hz_cust_acct_sites_all hcas_b
                                   ON hcas_b.cust_acct_site_id =
                                      hcsu_b.cust_acct_site_id
                               JOIN apps.hz_party_sites hps_b
                                   ON hps_b.party_site_id =
                                      hcas_b.party_site_id
                               JOIN apps.hz_locations hl_b
                                   ON hl_b.location_id = hps_b.location_id
                         WHERE     ooh.cust_po_number = p_order_number
                               -- AND ooh.order_source_id IN (1044)); --commented by BT Technology Team on 2014/11/05
                               AND ooh.order_source_id IN
                                       (SELECT ORDER_SOURCE_ID
                                          FROM oe_order_sources
                                         WHERE name = 'Flagstaff')); -- Added by BT Technology Team on 2014/11/05

            -- Now get delivery tracking information
            FOR c_del IN c_delivery_line (p_order_number)
            LOOP
                l_source_line_id    := c_del.source_line_id;
                l_tracking_number   := c_del.tracking_number;
                l_freight_code      := c_del.freight_code;
                l_desc              := c_del.description;

                --DBMS_OUTPUT.PUT_LINE('READ:  '||l_source_line_id||'~'||l_tracking_number||'~'||l_freight_code
                --||'~'||l_desc||'.');
                IF (l_source_line_id_save = -1)
                THEN
                    --dbms_output.put_line('SAVING:  l_source_line_id_save:  '||l_source_line_id||' l_freight_code_save:  '||
                    --l_freight_code||' l_desc_save:  '||l_desc||'.');
                    l_source_line_id_save   := l_source_line_id;
                    l_freight_code_save     := l_freight_code;
                    l_desc_save             := l_desc;
                END IF;

                IF (l_source_line_id_save <> l_source_line_id)
                THEN
                    --DBMS_OUTPUT.PUT_LINE('LINE ID HAS CHANGED!');
                    --DBMS_OUTPUT.PUT_LINE('      l_build_tracking_number:  '||l_build_tracking_number||
                    --' l_latest_tracking_number:  '||l_latest_tracking_number||
                    --' l_source_line_id_save:  '||l_source_line_id_save||' l_desc_save:  '||l_desc_save||'.');

                    --UPDATE THE TEMP TABLE WITH THIS DATA
                    UPDATE gtt_order_detail
                       SET tracking_number = l_build_tracking_number, carrier = l_freight_code_save, shipping_method = l_desc_save
                     WHERE gtt_order_detail.line_id = l_source_line_id_save;

                    --dbms_output.put_line('updating line id:  '||l_source_line_id_save
                    --||' l_build_tracking_number '||l_build_tracking_number||' l_freight_code '
                    --|| l_freight_code_save||' l_desc '||l_desc_save||'.');
                    l_source_line_id_save      := l_source_line_id;
                    l_build_tracking_number    := '';
                    l_freight_code_save        := l_freight_code;
                    l_desc_save                := l_desc;
                    l_latest_tracking_number   := 'NONE';
                END IF;

                IF (l_latest_tracking_number <> 'NONE')
                THEN
                    l_build_tracking_number    :=
                        l_build_tracking_number || ',' || l_tracking_number;
                    l_latest_tracking_number   := l_tracking_number;
                --DBMS_OUTPUT.PUT_LINE('1 latest tracking number build ongoing');
                END IF;

                IF (l_latest_tracking_number = 'NONE')
                THEN
                    l_latest_tracking_number   := l_tracking_number;
                    l_build_tracking_number    := l_tracking_number;
                --DBMS_OUTPUT.PUT_LINE('2 latest tracking number starts anew');
                END IF;
            END LOOP;

            -- do the last one.
            --dbms_output.put_line('updating line id:  '||l_source_line_id_save||' l_build_tracking_number:  '||
            --l_build_tracking_number||' l_freight_code:  '|| l_freight_code||' l_desc:  '||l_desc||'.');
            UPDATE gtt_order_detail
               SET tracking_number = l_build_tracking_number, carrier = l_freight_code, shipping_method = l_desc
             WHERE gtt_order_detail.line_id = l_source_line_id_save;

            --Get bling information
            FOR c_bling IN c_bling_lines (p_order_number)
            LOOP
                l_bling_amount       := c_bling.adjusted_amount;
                l_bling_product_id   := c_bling.attribute2;
                l_bling_line_id      := c_bling.line_id;

                IF (l_bling_line_id > 0)
                THEN
                    UPDATE gtt_order_detail
                       SET has_bling_applied = 'YES', bling_product_id = l_bling_product_id, bling_line_amount = l_bling_amount
                     WHERE gtt_order_detail.line_id = l_bling_line_id;
                END IF;
            END LOOP;

            --DBMS_OUTPUT.put_line('Has Bling: '||l_has_bling||' product_id: '||l_bling_product_id||' amount: '||l_bling_amount||' Line ID: '||l_bling_line_id);

            -- get product information
            ----dbms_output.put_line('marker a');
            UPDATE gtt_order_detail
               SET (model_number, color_code, product_size,
                    product_name)   =
                       /* -- (SELECT msi.segment1,                                                        ----commented by BT Technology Team on 12/11/2014  BEGIN
                     --       msi.segment2,
              --       msi.segment3,
                          --       msi.description
              --FROM inv.mtl_system_items_b msi*/
                       --commented by BT Technology Team on 12/11/2014 END
                        (SELECT msi.style_number, --Added by BT Technology Team on 12/11/2014  BEGIN
                                                  msi.color_code, msi.item_size,
                                msi.item_description
                           FROM xxd_common_items_v msi --Added by BT Technology Team on 12/11/2014  END
                                JOIN apps.oe_order_lines_all ool
                                    ON     msi.inventory_item_id =
                                           ool.inventory_item_id
                                       AND msi.organization_id =
                                           ool.ship_from_org_id
                          WHERE     ool.cust_po_number = p_order_number
                                AND ool.line_id = gtt_order_detail.line_id);

            -- update total order amount
            --dbms_output.put_line('marker b');
            SELECT NVL (SUM (ool.unit_selling_price * ool.ordered_quantity), 0)
              INTO order_total
              FROM apps.oe_order_lines_all ool
             WHERE     ool.cust_po_number = p_order_number
                   -- AND ool.order_source_id IN (1044)-- commented by BT Technology Team on 2014/11/05
                   AND ool.order_source_id IN (SELECT ORDER_SOURCE_ID
                                                 FROM oe_order_sources
                                                WHERE name = 'Flagstaff') --Added by BT Technology Team on 2014/11/05
                   AND ool.line_category_code != 'RETURN';

            --dbms_output.put_line('marker c');
            SELECT NVL (SUM (ool.unit_selling_price * ool.ordered_quantity), 0)
              INTO return_total
              FROM apps.oe_order_lines_all ool
             WHERE     ool.cust_po_number = p_order_number
                   -- AND ool.order_source_id IN (1044) --commented by BT Technology Team on 2014/11/05
                   AND ool.order_source_id IN (SELECT ORDER_SOURCE_ID
                                                 FROM oe_order_sources
                                                WHERE name = 'Flagstaff') -- Added by BT Technology Team on 2014/11/05
                   AND ool.line_category_code = 'RETURN';

            SELECT order_total - return_total INTO final_total FROM DUAL;

            -- returned_quantity        --************ check this again *************
            --dbms_output.put_line('marker e');
            UPDATE gtt_order_detail
               SET (returned_quantity)   =
                       (SELECT CASE
                                   WHEN (ool.line_category_code = 'RETURN')
                                   THEN
                                       ool.ordered_quantity
                                   ELSE
                                       (SELECT SUM (ordered_quantity)
                                          FROM apps.oe_order_lines_all
                                         WHERE reference_line_id =
                                               ool.line_id)
                               END returned_quantity
                          FROM apps.oe_order_lines_all ool
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id);

            -- discount_amount
            --dbms_output.put_line('marker f');
            UPDATE gtt_order_detail
               SET (discount_amount)   =
                       (SELECT ROUND (
                                   CASE
                                       WHEN (ool.attribute2 NOT LIKE 'GCARD%' AND ool.attribute2 NOT LIKE 'ECARD%')
                                       THEN
                                             (ool.unit_list_price * ool.ordered_quantity)
                                           - (ool.unit_selling_price * ool.ordered_quantity)
                                       ELSE
                                           0
                                   END,
                                   2)
                          FROM apps.oe_order_lines_all ool
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id);

            -- gift_wrap_total
            --dbms_output.put_line('marker g');
            UPDATE gtt_order_detail
               SET (gift_wrap_total)   =
                       (SELECT NVL (SUM (adjusted_amount), 0)
                          FROM apps.oe_price_adjustments opa
                               JOIN apps.oe_order_lines_all ool
                                   ON     opa.header_id = ool.header_id
                                      AND opa.line_id = ool.line_id
                                      AND opa.charge_type_code = 'GIFTWRAP'
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id);

            -- cod_charge_total_total
            UPDATE gtt_order_detail
               SET (cod_charge_total)   =
                       (SELECT NVL (SUM (adjusted_amount), 0)
                          FROM apps.oe_price_adjustments opa
                               JOIN apps.oe_order_lines_all ool
                                   ON     opa.header_id = ool.header_id
                                      AND opa.line_id = ool.line_id
                                      AND opa.charge_type_code = 'CODCHARGE'
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id);

            -- refund_line_total
            --dbms_output.put_line('marker h');
            UPDATE gtt_order_detail
               SET (refund_line_total)   =
                       (SELECT NVL (ROUND (SUM (refund_quantity * refund_unit_amount), 5), 0)
                          FROM apps.xxdoec_order_manual_refunds omr
                               JOIN apps.oe_order_lines_all ool
                                   ON     omr.header_id = ool.header_id
                                      AND omr.line_id = ool.line_id
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id
                               AND omr.pg_status = 'S');

            --dbms_output.put_line('marker i');
            -- refund_order_total
            UPDATE gtt_order_detail
               SET (refund_order_total)   =
                       (SELECT NVL (ROUND (SUM (refund_quantity * refund_unit_amount), 5), 0)
                          FROM apps.xxdoec_order_manual_refunds omr
                               JOIN apps.oe_order_lines_all ool
                                   ON omr.header_id = ool.header_id
                         WHERE     ool.cust_po_number = p_order_number
                               -- AND ool.order_source_id IN (1044) -- commented by BT Technology team on 2014/11/05
                               AND ool.order_source_id IN
                                       (SELECT ORDER_SOURCE_ID
                                          FROM oe_order_sources
                                         WHERE name = 'Flagstaff') -- Added by BT Technology Team On 2014/11/05
                               AND omr.pg_status = 'S');

            -- shipping_total
            --dbms_output.put_line('marker j');
            UPDATE gtt_order_detail
               SET (shipping_total)   =
                       (SELECT NVL (SUM (adjusted_amount), 0)
                          FROM apps.oe_price_adjustments opa
                               JOIN apps.oe_order_lines_all ool
                                   ON     opa.header_id = ool.header_id
                                      AND opa.line_id = ool.line_id
                                      AND opa.charge_type_code = 'FTECHARGE'
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id);

            -- shipping_discount
            --dbms_output.put_line('marker k');
            UPDATE gtt_order_detail
               SET (shipping_discount)   =
                       (SELECT NVL (SUM (adjusted_amount), 0)
                          FROM apps.oe_price_adjustments opa
                               JOIN apps.oe_order_lines_all ool
                                   ON     opa.header_id = ool.header_id
                                      AND opa.line_id = ool.line_id
                                      AND opa.charge_type_code =
                                          'FTEDISCOUNT'
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id);

            -- order_line_status
            --dbms_output.put_line('marker l');
            UPDATE gtt_order_detail
               SET (order_line_status)   =
                       (SELECT meaning
                          FROM apps.fnd_lookup_values flv_ols
                               JOIN apps.oe_order_lines_all ool
                                   ON     flv_ols.lookup_code =
                                          ool.flow_status_code
                                      AND flv_ols.lookup_type =
                                          'LINE_FLOW_STATUS'
                                      AND flv_ols.LANGUAGE = 'US'
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id);

            -- delivery_status
            --dbms_output.put_line('marker m');
            UPDATE gtt_order_detail
               SET (delivery_status)   =
                       (SELECT flv.meaning
                          FROM apps.oe_order_lines_all ool
                               LEFT JOIN wsh_delivery_details wdd
                                   ON     ool.line_id = wdd.source_line_id
                                      AND wdd.source_code = 'OE'
                               JOIN apps.fnd_lookup_values flv
                                   ON     flv.lookup_code =
                                          wdd.released_status
                                      AND flv.lookup_type = 'PICK_STATUS'
                                      AND flv.LANGUAGE = 'US'
                                      AND ROWNUM = 1
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id
                        UNION
                        SELECT DECODE (ssd.status, 'SUCCESS', 'Shipped')
                          FROM xxdoec_sfs_shipment_dtls_stg ssd
                         WHERE     ssd.line_id = gtt_order_detail.line_id
                               AND ssd.status = 'SUCCESS');

            --  pg_line_status
            --dbms_output.put_line('marker n');
            UPDATE gtt_order_detail
               SET (pg_line_status)   =
                       (SELECT flv_cls.meaning
                          FROM apps.oe_order_lines_all ool
                               JOIN apps.fnd_lookup_values flv_cls
                                   ON     flv_cls.lookup_code(+) =
                                          ool.attribute20
                                      AND flv_cls.lookup_type(+) =
                                          'DOEC_OEOL_CUSTOM_STATUSES'
                                      AND flv_cls.LANGUAGE(+) = 'US'
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id);

            -- pre back order date
            --dbms_output.put_line('marker o');
            UPDATE gtt_order_detail
               SET (backorderdate)   =
                       (SELECT NVL (inv.pre_back_order_date, TO_DATE ('1-JAN-1951'))
                          FROM apps.oe_order_lines_all ool
                               LEFT JOIN xxdo.xxdoec_inventory inv
                                   ON     inv.erp_org_id = ool.org_id
                                      AND inv.inv_org_id =
                                          ool.ship_from_org_id
                                      AND inv.inventory_item_id =
                                          ool.inventory_item_id
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id
                               AND ROWNUM < 2);

            --                select * from gtt_order_detail;
            --           (select inv.*, nvl(inv.pre_back_order_date, to_date('1-JAN-1951'))
            --                from apps.oe_order_lines_all ool
            --                left join xxdo.xxdoec_inventory inv
            --                on inv.erp_org_id = ool.org_id
            --                AND inv.inv_org_id = ool.ship_from_org_id
            --                AND inv.inventory_item_id = ool.inventory_item_id
            --                where ool.cust_po_number = '08016094' and 59422757=ool.line_id and rownum < 2);
            -- cancel info - reason_code, meaning, user_name, cancel_date
            --dbms_output.put_line('marker p');
            UPDATE gtt_order_detail
               SET (reason_code, meaning, user_name,
                    cancel_date)   =
                       (SELECT NVL (ors.reason_code, 'none'), NVL (flv.meaning, 'none'), NVL (fu.user_name, 'none'),
                               NVL (ors.creation_date, TO_DATE ('1-JAN-1951'))
                          FROM apps.oe_order_lines_all ool
                               LEFT JOIN apps.oe_reasons ors
                                   ON     ors.entity_code = 'LINE'
                                      AND ors.reason_type = 'CANCEL_CODE'
                                      AND ors.entity_id = ool.line_id
                               LEFT JOIN apps.fnd_user fu
                                   ON fu.user_id = ors.created_by
                               LEFT JOIN apps.fnd_lookup_values flv
                                   ON     flv.lookup_type = 'CANCEL_CODE'
                                      AND flv.lookup_code = ors.reason_code
                                      AND LANGUAGE = 'US'
                         WHERE     ool.cust_po_number = p_order_number
                               AND gtt_order_detail.line_id = ool.line_id
                               AND ROWNUM = 1);

            --Set the return_process property
            UPDATE gtt_order_detail
               SET (return_processed)   = 'YES';

            --Get the Return type
            UPDATE gtt_order_detail
               SET (return_type)   =
                       (SELECT DISTINCT oott.attribute13
                          FROM apps.oe_order_lines_all oola
                               JOIN apps.oe_order_headers_all ooha
                                   ON oola.header_id = ooha.header_id
                               JOIN apps.oe_transaction_types_all oott
                                   ON ooha.order_type_id =
                                      oott.transaction_type_id
                         WHERE     oola.cust_po_number = p_order_number
                               --   AND oola.order_source_id IN (1044)); --commented by BT Technology Team on 2014/11/05
                               AND oola.order_source_id IN
                                       (SELECT ORDER_SOURCE_ID
                                          FROM oe_order_sources
                                         WHERE name = 'Flagstaff')); --Added by BT Technology Team on 2014/11/05

            --Get the original order number
            SELECT header_id, org_id
              INTO l_header_id, l_org_id
              FROM oe_order_headers_all
             WHERE     cust_po_number = p_order_number
                   -- AND order_source_id IN (1044) -- commented by BT Technology team on 2014/11/05
                   AND order_source_id IN (SELECT ORDER_SOURCE_ID
                                             FROM oe_order_sources
                                            WHERE name = 'Flagstaff') --Added by BT Technology Team on 2014/11/05
                   AND ROWNUM = 1;

            --        update gtt_order_detail
            --        set original_dw_order_id = (APPS.XXDOEC_ORDER_UTILS_PKG.GET_ORIG_ORDER(l_header_id, l_rtn_status, l_rtn_message));
            l_original_order_number   :=
                apps.xxdoec_order_utils_pkg.get_orig_order (l_header_id,
                                                            l_rtn_status,
                                                            l_rtn_message);

            UPDATE gtt_order_detail
               SET original_dw_order_id   = l_original_order_number;

            -- get Invoice information .... start CCR0008713 related changes
            IF NVL (p_invoice_data_flag, 'N') = 'Y'
            THEN
                IF (p_invoice_data_OUs IS NULL OR INSTR (p_invoice_data_OUs, l_org_id) > 0)
                THEN
                    UPDATE gtt_order_detail dtl
                       SET (invoice_number, invoice_date, tax_rate)   =
                               (SELECT rct.trx_number, rct.trx_date, rctl_tax.tax_rate
                                  FROM apps.ra_customer_trx_all rct, apps.ra_customer_trx_lines_all rctl, apps.ra_customer_trx_lines_all rctl_tax,
                                       apps.oe_order_headers_all ooh
                                 WHERE     rct.customer_trx_id =
                                           rctl.customer_trx_id
                                       AND ooh.header_id = dtl.header_id
                                       AND rctl.interface_line_attribute1 =
                                           TO_CHAR (ooh.order_number)
                                       AND rctl.interface_line_attribute6 =
                                           TO_CHAR (dtl.line_id)
                                       AND rctl.line_type = 'LINE'
                                       AND rctl.interface_line_attribute11 =
                                           '0'
                                       AND rctl_tax.line_type = 'TAX'
                                       AND rctl_tax.link_to_cust_trx_line_id =
                                           rctl.customer_trx_line_id);
                END IF;
            END IF;                          -- end CCR0008713 related changes

            -- end get order detail o_order_detail record information

            -- get order frttax information
            --dbms_output.put_line('marker q');
            INSERT INTO gtt_order_frttax
                SELECT ooh.header_id, xooftt.freight_charge_total, xooftt.tax_total_no_vat,
                       xooftt.vat_total
                  FROM apps.oe_order_headers_all ooh
                       JOIN apps.oe_order_lines_all ool
                           ON ooh.header_id = ool.header_id
                       JOIN apps.xxdoec_oe_order_status_frt_tax xooftt
                           ON xooftt.header_id = ooh.header_id
                 WHERE     ooh.cust_po_number = p_order_number
                       --AND ooh.order_source_id IN (1044) -- commented By BT Technology team on 2014/11/05
                       AND ooh.order_source_id IN (SELECT ORDER_SOURCE_ID
                                                     FROM oe_order_sources
                                                    WHERE name = 'Flagstaff') -- Added by BT Technology Team on 2014/11/05
                       AND ooh.org_id IN
                               (SELECT DISTINCT erp_org_id
                                  FROM xxdo.xxdoec_country_brand_params);

            -- get order address information
            --dbms_output.put_line('marker r');
            INSERT INTO gtt_order_address
                SELECT DISTINCT hcsu_b.site_use_code,
                                hl_b.address1,
                                hl_b.address2,
                                hl_b.city,
                                CASE
                                    WHEN hl_b.state IS NULL
                                    THEN
                                        hl_b.province
                                    ELSE
                                        hl_b.state
                                END state,
                                hl_b.postal_code,
                                hl_b.country,
                                TRIM (SUBSTR (hcsu_b.LOCATION, 0, 30)) NAME,
                                hcp_b.phone_number,
                                hcp_b.phone_number,
                                ool.line_id,
                                hcsu_b.site_use_id
                  FROM apps.oe_order_headers_all ooh
                       JOIN apps.oe_order_lines_all ool
                           ON ool.header_id = ooh.header_id
                       JOIN apps.hz_cust_accounts hca
                           ON hca.cust_account_id = ooh.sold_to_org_id
                       JOIN apps.hz_party_sites hps_b
                           ON hps_b.party_id = hca.party_id
                       JOIN apps.hz_cust_acct_sites_all hcas_b
                           ON     hcas_b.cust_account_id =
                                  hca.cust_account_id
                              AND hcas_b.party_site_id = hps_b.party_site_id
                       JOIN apps.hz_cust_site_uses_all hcsu_b
                           ON     hcsu_b.cust_acct_site_id =
                                  hcas_b.cust_acct_site_id
                              AND (hcsu_b.site_use_code = 'SHIP_TO' OR hcsu_b.site_use_code = 'BILL_TO')
                       JOIN apps.hz_locations hl_b
                           ON hps_b.location_id = hl_b.location_id
                       LEFT JOIN apps.hz_contact_points hcp_b
                           ON (hcas_b.party_site_id = hcp_b.owner_table_id AND hcp_b.owner_table_name = 'HZ_PARTY_SITES' AND hcp_b.contact_point_type = 'PHONE')
                 WHERE     ooh.cust_po_number = p_order_number
                       AND ooh.order_source_id IN (SELECT ORDER_SOURCE_ID
                                                     FROM oe_order_sources
                                                    WHERE name = 'Flagstaff') -- Added by BT Technology Team on 2014/11/05
                       AND ooh.org_id IN
                               (SELECT DISTINCT erp_org_id
                                  FROM xxdo.xxdoec_country_brand_params)
                       AND (ool.ship_to_org_id = hcsu_b.site_use_id OR ooh.invoice_to_org_id = hcsu_b.site_use_id)
                       AND NVL (hps_b.status, 'A') = 'A'
                       AND NVL (hcas_b.status, 'A') = 'A'
                       AND NVL (hcsu_b.status, 'A') = 'A';
        END IF;

        BEGIN
            INSERT INTO gtt_return_lines_staging
                SELECT sku, upc, quantity,
                       line_type, order_id, line_id,
                       exchange_preference, return_reason, ID
                  FROM xxdo.xxdoec_return_lines_staging
                 WHERE order_id = p_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_rtn_status   := 'GOOD';
        END;

        BEGIN
            INSERT INTO gtt_order_attributes
                SELECT attribute_id, attribute_type, attribute_value,
                       user_name, order_header_id, line_id,
                       creation_date
                  FROM xxdo.xxdoec_order_attribute
                 WHERE order_header_id = l_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_rtn_status   := 'GOOD';
        END;

        --dbms_output.put_line('marker s');
        OPEN o_order_detail FOR SELECT HEADER_ID,
                                       LINE_GRP_ID,
                                       LINE_ID,
                                       ORDER_NUMBER,
                                       ORDERED_DATE,
                                       TOTAL_ORDER_AMOUNT,
                                       CUSTOMER_NUMBER,
                                       LOCALE_ID,
                                       ACCOUNT_NAME,
                                       EMAIL_ADDRESS,
                                       SITE_ID,
                                       ORDER_STATUS,
                                       BILL_TO_ADDRESS1,
                                       BILL_TO_ADDRESS2,
                                       BILL_TO_CITY,
                                       BILL_TO_STATE,
                                       BILL_TO_POSTAL_CODE,
                                       BILL_TO_COUNTRY,
                                       CARRIER,
                                       SHIPPING_METHOD,
                                       TRACKING_NUMBER,
                                       SHIPPING_DATE,
                                       MODEL_NUMBER,
                                       COLOR_CODE,
                                       PRODUCT_SIZE,
                                       PRODUCT_NAME,
                                       FLUID_RECIPE_ID,
                                       INVENTORY_ITEM_ID,
                                       ORDERED_QUANTITY,
                                       SHIPPED_QUANTITY,
                                       CANCELLED_QUANTITY,
                                       UNIT_SELLING_PRICE,
                                       SUBTOTAL,
                                       TAXAMOUNT,
                                       LINE_STATUS,
                                       CURRENCY,
                                       RETURNED_QUANTITY,
                                       DISCOUNT_AMOUNT,
                                       GIFT_WRAP_TOTAL,
                                       REFUND_LINE_TOTAL,
                                       REFUND_ORDER_TOTAL,
                                       SHIPPING_TOTAL,
                                       SHIPPING_DISCOUNT,
                                       ORDER_LINE_STATUS,
                                       DELIVERY_STATUS,
                                       PG_LINE_STATUS,
                                       ORG_ID,
                                       BACKORDERDATE,
                                       REASON_CODE,
                                       MEANING,
                                       USER_NAME,
                                       CANCEL_DATE,
                                       ATTRIBUTE18,
                                       TRANSACTIONAL_CURR_CODE,
                                       STAGED_RETURN_QUANTITY,
                                       RETURN_PROCESSED,
                                       RETURN_TYPE,
                                       ORIGINAL_DW_ORDER_ID,
                                       HAS_BLING_APPLIED,
                                       BLING_PRODUCT_ID,
                                       BLING_LINE_AMOUNT,
                                       ELIGIBLE_TO_CANCEL,
                                       SHIP_FROM_ORG_ID,
                                       (SELECT CASE
                                                   WHEN EXISTS
                                                            (SELECT 1
                                                               FROM XXDO.XXDOEC_ORDER_ATTRIBUTE
                                                              WHERE     ORDER_HEADER_ID =
                                                                        gtt_order_detail.HEADER_ID
                                                                    AND ATTRIBUTE_TYPE =
                                                                        'CLOSETORDER')
                                                   THEN
                                                       'True'
                                                   ELSE
                                                       'FALSE'
                                               END
                                          FROM DUAL) is_closet_order,
                                       (SELECT CASE
                                                   WHEN EXISTS
                                                            (SELECT 1
                                                               FROM XXDO.XXDOEC_ORDER_ATTRIBUTE
                                                              WHERE     ORDER_HEADER_ID =
                                                                        gtt_order_detail.HEADER_ID
                                                                    AND ATTRIBUTE_TYPE =
                                                                        'FINALSALE'
                                                                    AND LINE_ID =
                                                                        gtt_order_detail.LINE_ID)
                                                   THEN
                                                       'True'
                                                   ELSE
                                                       'FALSE'
                                               END
                                          FROM DUAL) is_final_sale_item,
                                       COD_CHARGE_TOTAL,
                                       INVOICE_NUMBER,          --  CCR0008713
                                       TAX_RATE,                --  CCR0008713
                                       INVOICE_DATE             --  CCR0008713
                                  FROM gtt_order_detail;

        --dbms_output.put_line('marker t');
        OPEN o_order_frttax FOR SELECT * FROM gtt_order_frttax;

        --dbms_output.put_line('marker u');
        OPEN o_order_address FOR SELECT * FROM gtt_order_address;

        BEGIN
            OPEN o_order_staging_lines FOR
                SELECT * FROM gtt_return_lines_staging;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_rtn_status   := 'GOOD';
        END;

        BEGIN
            OPEN o_order_attribute_detail FOR
                SELECT * FROM gtt_order_attributes;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_rtn_status   := 'GOOD';
        END;

        --      INSERT INTO xxdo.xxdoec_ORDER_STATUS_DETAIL_NEW
        --            SELECT * FROM GTT_ORDER_DETAIL;
        --dbms_output.put_line('marker v');
        INSERT INTO xxdo.xxdoec_order_status_log (order_number,
                                                  called_with,
                                                  createdate)
                 VALUES (
                            p_order_number,
                               'NEW Finished calling with order number:  '
                            || p_order_number
                            || '.',
                            SYSDATE);

        COMMIT;
    -- *********** TESTING ONLY
    --  INSERT INTO xxdo.xxdoec_ORDER_STATUS_DETAIL_NEW
    --    SELECT * FROM GTT_ORDER_DETAIL;
    -- *********** TESTING ONLY
    EXCEPTION
        WHEN OTHERS
        THEN
            INSERT INTO xxdo.xxdoec_order_status_log (order_number,
                                                      called_with,
                                                      createdate)
                     VALUES (
                                p_order_number,
                                   'ERROR calling with order number:  '
                                || p_order_number
                                || '.',
                                SYSDATE);

            COMMIT;
    END;

    FUNCTION get_eligible_to_cancel_reason (p_line_id   IN     NUMBER,
                                            p_reason       OUT VARCHAR2)
        RETURN NUMBER
    IS
        l_eligible_to_cancel   NUMBER := 0;
        l_flow_status_code     VARCHAR2 (30) := '';
        l_creation_date        DATE := NULL;
        l_customer_job         VARCHAR2 (50) := '';
        l_order_type_id        NUMBER := NULL;
        l_bff_status           VARCHAR (240) := '';
    BEGIN
        -- get line and order data needed to evaluate eligible to cancel status
        SELECT ol.flow_status_code, ol.creation_date, ol.customer_job,
               oh.order_type_id, ol.attribute17
          INTO l_flow_status_code, l_creation_date, l_customer_job, l_order_type_id,
                                 l_bff_status
          FROM apps.oe_order_lines_all ol
               JOIN apps.oe_order_headers_all oh
                   ON ol.header_id = oh.header_id
         WHERE ol.line_id = p_line_id;

        -- evaluate status: only BOOKED lines are eligible for cancel,
        -- provided item is NOT a customized product and the line is NOT on the middleware Todo list
        IF (l_creation_date >= c_mindate_prepaid_order_type AND l_order_type_id = c_prepaid_order_type_id AND l_customer_job IS NOT NULL)
        THEN
            -- customized product is ineligible
            l_eligible_to_cancel   := 0;
            p_reason               :=
                   'OMS Line '
                || p_line_id
                || ' is ineligible for cancel as a customized item';
        ELSIF l_bff_status = 'M'
        THEN
            -- Item on Todo list (e.g. BFF processing status is 'Manual') is ineligible
            l_eligible_to_cancel   := 0;
            p_reason               :=
                   'OMS Line '
                || p_line_id
                || ' is ineligible for cancel as item is queued for manual processing';
        ELSIF l_flow_status_code = c_cancel_eligible_flow_status
        THEN
            -- only BOOKED line for non-customized product are eligible for cancel
            l_eligible_to_cancel   := 1;
            p_reason               :=
                'OMS Line ' || p_line_id || ' is eligible for cancel';
        ELSE
            -- default is ineligible
            l_eligible_to_cancel   := 0;
            p_reason               :=
                   'OMS Line '
                || p_line_id
                || ' is ineligible for cancel as item flow status is not BOOKED';
        END IF;

        RETURN l_eligible_to_cancel;
    END get_eligible_to_cancel_reason;

    FUNCTION get_eligible_to_cancel (p_line_id IN NUMBER)
        RETURN NUMBER
    IS
        l_reason   VARCHAR2 (102) := '';
    BEGIN
        RETURN get_eligible_to_cancel_reason (p_line_id, l_reason);
    END get_eligible_to_cancel;
END xxdoec_order_status;
/
