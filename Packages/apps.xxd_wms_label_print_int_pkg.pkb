--
-- XXD_WMS_LABEL_PRINT_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_LABEL_PRINT_INT_PKG"
AS
    /******************************************************************************************
    -- Modification History:
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 03-MAR-2019  1.0        Krishna Lavu            Initial Version
    ******************************************************************************************/
    gv_package_name   CONSTANT VARCHAR2 (200)
                                   := 'APPS.XXD_WMS_LABEL_PRINT_INT_PKG' ;
    gn_num_user_id             NUMBER := fnd_global.user_id;
    gn_delay_time     CONSTANT NUMBER
        := NVL (
               fnd_profile.value_specific (
                   name      => 'XXD_LABEL_PRINT_TCPIP_DELAY',
                   user_id   => gn_num_user_id)             --User Level Value
                                               ,
               fnd_profile.VALUE ('XXD_LABEL_PRINT_TCPIP_DELAY') --Site Level Value
                                                                ) ;

    FUNCTION get_lpn_sequence (p_delivery_id   IN NUMBER,
                               p_lpn           IN VARCHAR2 := NULL)
        RETURN VARCHAR2
    IS
        idx   NUMBER;

        CURSOR c_lpns IS
              SELECT DISTINCT TRIM (lpn_child.license_plate_number) AS lpn
                FROM wms_license_plate_numbers lpn_name, wms_license_plate_numbers lpn_child, wms_license_plate_numbers lpn_parent,
                     wsh_delivery_details wdd_cont, wsh_delivery_assignments wda_cont
               WHERE     lpn_child.license_plate_number =
                         wdd_cont.container_name
                     AND lpn_child.outermost_lpn_id =
                         lpn_parent.outermost_lpn_id
                     AND wdd_cont.container_flag = 'Y'
                     AND wdd_cont.delivery_detail_id =
                         wda_cont.delivery_detail_id
                     AND wda_cont.delivery_id = p_delivery_id
                     AND lpn_name.lpn_id = lpn_child.outermost_lpn_id
                     AND EXISTS
                             (SELECT NULL
                                FROM wsh_delivery_assignments
                               WHERE parent_delivery_detail_id =
                                     wdd_cont.delivery_detail_id)
            ORDER BY 1;
    BEGIN
        idx   := 0;

        FOR c_lpn IN c_lpns
        LOOP
            idx   := idx + 1;
            EXIT WHEN NVL (p_lpn, '--none--') = c_lpn.lpn;
        END LOOP;

        RETURN TO_CHAR (idx);
    END;


    FUNCTION fix_value (pv_value IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_return_value   VARCHAR2 (1000);
    BEGIN
        lv_return_value   := REPLACE (pv_value, '''', NULL);

        RETURN TO_CHAR (lv_return_value);
    END;


    FUNCTION get_cc_zpl_file (pv_lpn IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR c_label_info IS
              SELECT DISTINCT msib.segment1 sku, msib.description sku_desc, SUM (wlc.primary_quantity) qty
                FROM apps.wms_license_plate_numbers wlpn, apps.wms_lpn_contents wlc, apps.mtl_system_items_b msib
               WHERE     wlpn.license_plate_number = pv_lpn
                     AND wlpn.lpn_id = wlc.parent_lpn_id
                     AND wlc.inventory_item_id = msib.inventory_item_id
                     AND wlc.organization_id = msib.organization_id
            GROUP BY msib.segment1, msib.description;

        lv_customer      VARCHAR2 (100);
        ln_delivery_id   NUMBER;
        lv_po_number     VARCHAR2 (100);
        lv_lpn           VARCHAR2 (100);
        lv_message       VARCHAR2 (4000);
        ln_item_count    NUMBER;
        ln_total_qty     NUMBER;
        i                NUMBER;
    BEGIN
        SELECT COUNT (DISTINCT (wlc.inventory_item_id)), SUM (wlc.quantity)
          INTO ln_item_count, ln_total_qty
          FROM apps.wms_license_plate_numbers wlpn, apps.wms_lpn_contents wlc
         WHERE     wlpn.license_plate_number = pv_lpn
               AND wlpn.lpn_id = wlc.parent_lpn_id;

        IF ln_item_count > 26
        THEN
            lv_message   := NULL;
        ELSE
            BEGIN
                SELECT DISTINCT addr_st.customer_name, wda.delivery_id, ooha.cust_po_number po_number,
                                apps.do_wms_interface.fix_container (wdd.container_name)
                  INTO lv_customer, ln_delivery_id, lv_po_number, lv_lpn
                  FROM apps.wsh_delivery_details wdd, apps.do_addresses_mv addr_st, apps.wsh_delivery_assignments wda,
                       apps.wsh_delivery_details wdd1, apps.oe_order_headers_all ooha
                 WHERE     wdd.container_name = pv_lpn
                       AND wdd.source_code = 'WSH'
                       AND wdd.customer_id = addr_st.customer_id
                       AND wdd.delivery_detail_id =
                           wda.parent_delivery_detail_id
                       AND wda.delivery_detail_id = wdd1.delivery_detail_id
                       AND wdd1.source_code = 'OE'
                       AND wdd1.source_header_id = ooha.header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_customer      := NULL;
                    ln_delivery_id   := NULL;
                    lv_po_number     := NULL;
                    lv_lpn           := NULL;
                    lv_message       := NULL;
            END;

            IF lv_customer IS NOT NULL
            THEN
                SELECT zpl_data
                  INTO lv_message
                  FROM do_custom.do_wms_pna_zpl_info
                 WHERE UPPER (label_format_name) = 'CC.ZPL';

                lv_message   := REPLACE (lv_message, 'LPN_NAME', lv_lpn);
                lv_message   :=
                    REPLACE (lv_message, 'CUST_NAME', lv_customer);
                lv_message   :=
                    REPLACE (lv_message, 'DELIVERY_ID', ln_delivery_id);
                lv_message   := REPLACE (lv_message, 'PO_NUM', lv_po_number);
                lv_message   := REPLACE (lv_message, 'SKU_QTY', ln_total_qty);
                lv_message   :=
                    REPLACE (
                        lv_message,
                        'CC_VERIFY',
                           'VC'
                        || SUBSTR (
                               apps.do_wms_interface.fix_container (lv_lpn),
                               -2,
                               2));

                --fnd_file.put_line (fnd_file.LOG,'lv_customer: ' || lv_customer);
                /* In the Base CC template we have field name like _A to _Z whose ASCII value is
                from 65 to 90 */
                i            := 65;

                FOR rec_label_info IN c_label_info
                LOOP
                    lv_message   :=
                        REPLACE (lv_message,
                                 'QTY_' || CHR (i),
                                 rec_label_info.qty);
                    lv_message   :=
                        REPLACE (lv_message,
                                 'SKU_' || CHR (i),
                                 rec_label_info.sku);
                    lv_message   :=
                        REPLACE (lv_message,
                                 'SKUDESC_' || CHR (i),
                                 rec_label_info.sku_desc);
                    --fnd_file.put_line (fnd_file.LOG,'rec_label_info.qty: ' || rec_label_info.qty);
                    i   := i + 1;
                END LOOP;

                /* The below loop is to null the fields for which we dont have any data */
                FOR j IN i .. 90
                LOOP
                    lv_message   :=
                        REPLACE (lv_message, 'QTY_' || CHR (j), NULL);
                    lv_message   :=
                        REPLACE (lv_message, '- SKU_' || CHR (j), NULL);
                    lv_message   :=
                        REPLACE (lv_message, '- SKUDESC_' || CHR (j), NULL);
                END LOOP;
            END IF;
        END IF;

        RETURN lv_message;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_cc_zpl_file;

    FUNCTION get_zpl_file (pv_lpn IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_message             VARCHAR2 (4000);
        lv_field_attributes    VARCHAR2 (4000);
        lv_field_name          VARCHAR2 (200);
        lv_field_value         VARCHAR2 (200);
        lv_label_format_name   VARCHAR2 (100);
        lv_sql                 VARCHAR2 (10000);

        TYPE field_rec_type IS RECORD
        (
            field_name     VARCHAR2 (100),
            field_value    VARCHAR2 (100)
        );

        TYPE field_table_type IS TABLE OF field_rec_type;

        field_data_tab         field_table_type;

        TYPE fields_type IS TABLE OF VARCHAR2 (10000);

        lt_field_name          fields_type;
    BEGIN
        BEGIN
            SELECT NVL (SUBSTR (rac.attribute2, 1, INSTR (rac.attribute2, '.') - 1), 'DefaultUCC128Label') || '.zpl'
              INTO lv_label_format_name
              FROM apps.wsh_delivery_details wdd, apps.xxd_ra_customers_v rac
             WHERE     wdd.container_name = pv_lpn
                   AND wdd.source_code = 'WSH'
                   AND wdd.customer_id = rac.customer_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_label_format_name   := 'DefaultUCC128Label.zpl';
        END;

        --fnd_file.put_line (fnd_file.LOG,'lv_label_format_name: ' || lv_label_format_name);

        IF lv_label_format_name IS NOT NULL
        THEN
            BEGIN
                SELECT zpl_data
                  INTO lv_message
                  FROM DO_CUSTOM.DO_WMS_PNA_ZPL_INFO
                 WHERE UPPER (label_format_name) LIKE
                           UPPER (lv_label_format_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_message   := NULL;
            END;

            BEGIN
                SELECT non_item_field_attributes
                  INTO lv_field_attributes
                  FROM DO_CUSTOM.DO_WMS_CUST_LABEL_FIELDS
                 WHERE UPPER (label_format_name) LIKE
                           UPPER (lv_label_format_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_field_attributes   := NULL;
            END;

            --fnd_file.put_line (fnd_file.LOG,lv_field_attributes: ' || lv_field_attributes);

            lt_field_name   :=
                fields_type ('SKU_QTY', 'UPC_CODE', 'SKU_DESC',
                             'SKU_STYLE', 'SKU_COLOR', 'SKU_SIZE',
                             'SKU_SEGMENT1', 'CUST_ITEM_NUM', 'CUST_ITEM_ID',
                             'CUST_STYLE_DESC', 'CUST_COLOR_DESC', 'CUST_SIZE_DESC'
                             , 'CUST_DIM_DESC');

            FOR i IN 1 .. lt_field_name.COUNT
            LOOP
                lv_field_name   := lt_field_name (i);

                IF UPPER (lv_field_name) = 'SKU_QTY'
                THEN
                    SELECT SUM (wlc.quantity)
                      INTO lv_field_value
                      FROM apps.wms_license_plate_numbers wlpn, apps.wms_lpn_contents wlc
                     WHERE     wlpn.license_plate_number = pv_lpn
                           AND wlpn.lpn_id = wlc.parent_lpn_id;
                ELSIF UPPER (lv_field_name) IN
                          ('UPC_CODE', 'SKU_DESC', 'SKU_STYLE',
                           'SKU_COLOR', 'SKU_SIZE', 'SKU_SEGMENT1')
                THEN
                    BEGIN
                        SELECT DECODE (lv_field_name,  'UPC_CODE', DECODE (MAX (itm.upc_code), MIN (itm.upc_code), MAX (itm.upc_code), 'MIXED'),  'SKU_STYLE', DECODE (MAX (itm.style), MIN (itm.style), MAX (itm.style), 'MIXED'),  'SKU_COLOR', DECODE (MAX (itm.color), MIN (itm.color), MAX (itm.color), 'MIXED'),  'SKU_SIZE', DECODE (MAX (itm.sze), MIN (itm.sze), MAX (itm.sze), 'MIXED'),  'SKU_DESC', DECODE (MAX (itm.description), MIN (itm.description), MAX (itm.description), 'MIXED'),  'SKU_SEGMENT1', DECODE (MAX (itm.sku), MIN (itm.sku), MAX (itm.sku), 'MIXED'))
                          INTO lv_field_value
                          FROM apps.wms_license_plate_numbers wlpn, apps.wms_lpn_contents wlc, do_custom.do_ora_items_v itm,
                               apps.mtl_parameters mp
                         WHERE     wlpn.license_plate_number = pv_lpn
                               AND wlpn.lpn_id = wlc.parent_lpn_id
                               AND wlc.inventory_item_id =
                                   itm.inventory_item_id
                               AND mp.organization_id = itm.organization_id
                               AND mp.organization_code = 'MST';
                    EXCEPTION
                        WHEN TOO_MANY_ROWS
                        THEN
                            lv_field_value   := 'MIXED';
                        WHEN OTHERS
                        THEN
                            lv_field_value   := NULL;
                    END;
                ELSIF UPPER (lv_field_name) IN
                          ('CUST_ITEM_NUM', 'CUST_ITEM_ID', 'CUST_STYLE_DESC',
                           'CUST_COLOR_DESC', 'CUST_SIZE_DESC', 'CUST_DIM_DESC')
                THEN
                    BEGIN
                        SELECT DECODE (lv_field_name,  'CUST_ITEM_NUM', DECODE (MAX (NVL (oola.attribute7, cust_itm.customer_item_number)), MIN (NVL (oola.attribute7, cust_itm.customer_item_number)), MAX (NVL (oola.attribute7, cust_itm.customer_item_number)), 'MIXED'),  'CUST_ITEM_ID', DECODE (MAX (custom.parse_attributes (oola.attribute8, 'item_id')), MIN (custom.parse_attributes (oola.attribute8, 'item_id')), MAX (custom.parse_attributes (oola.attribute8, 'item_id')), 'MIXED'),  'CUST_STYLE_DESC', DECODE (MAX (custom.parse_attributes (oola.attribute8, 'style_desc')), MIN (custom.parse_attributes (oola.attribute8, 'style_desc')), MAX (custom.parse_attributes (oola.attribute8, 'style_desc')), 'MIXED'),  'CUST_COLOR_DESC', DECODE (MAX (custom.parse_attributes (oola.attribute8, 'color_desc')), MIN (custom.parse_attributes (oola.attribute8, 'color_desc')), MAX (custom.parse_attributes (oola.attribute8, 'color_desc')), 'MIXED'),  'CUST_SIZE_DESC', DECODE (MAX (custom.parse_attributes (oola.attribute8, 'size_desc')), MIN (custom.parse_attributes (oola.attribute8, 'size_desc')), MAX (custom.parse_attributes (oola.attribute8, 'size_desc')), 'MIXED'),  'CUST_DIM_DESC', DECODE (MAX (custom.parse_attributes (oola.attribute8, 'dim_desc')), MIN (custom.parse_attributes (oola.attribute8, 'dim_desc')), MAX (custom.parse_attributes (oola.attribute8, 'dim_desc')), 'MIXED'),  NULL)
                          INTO lv_field_value
                          FROM apps.oe_order_lines_all oola, apps.wsh_delivery_details wdd_items, apps.wsh_delivery_details wdd_lpn,
                               apps.wsh_delivery_assignments wda, do_custom.cust_item_v cust_itm
                         WHERE     wdd_lpn.container_name = pv_lpn
                               AND wda.parent_delivery_detail_id =
                                   wdd_lpn.delivery_detail_id
                               AND wdd_items.delivery_detail_id =
                                   wda.delivery_detail_id
                               AND oola.line_id = wdd_items.source_line_id
                               AND cust_itm.customer_id(+) =
                                   wdd_items.customer_id
                               AND cust_itm.inventory_item_id(+) =
                                   wdd_items.inventory_item_id;
                    EXCEPTION
                        WHEN TOO_MANY_ROWS
                        THEN
                            lv_field_value   := 'MIXED';
                        WHEN OTHERS
                        THEN
                            lv_field_value   := NULL;
                    END;
                END IF;

                lv_message      :=
                    REPLACE (lv_message, lv_field_name, lv_field_value);
            END LOOP;


            lv_sql   :=
                   'SELECT field_name, field_VALUE
  FROM (SELECT DISTINCT
       apps.do_wms_interface.fix_container (wlpn.license_plate_number)
          lpn_name,
       NVL( wc.carrier_name, '' '') ship_method_name,
       NVL(  apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(oracle_s_name), '' '') AS shipto_name,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(oracle_b_name), '' '') AS billto_name,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(order_info.oracle_s_address1), '' '') shipto_address_1,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(order_info.oracle_s_address2), '' '') shipto_address_2,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(order_info.oracle_s_address3), '' '') shipto_address_3,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(order_info.oracle_s_city)
       || '', ''
       || order_info.oracle_s_state
       || '' ''
       || SUBSTR (order_info.oracle_s_zip, 1, 5)
          , '' '') shipto_city_state_zip,
       NVL( SUBSTR (order_info.oracle_s_zip, 1, 5), '' '') shipto_zip_code,
          apps.XXD_WMS_LABEL_PRINT_INT_PKG.get_lpn_sequence (wda.delivery_id,
                                                  wlpn.license_plate_number)
       || '' of ''
       || apps.XXD_WMS_LABEL_PRINT_INT_PKG.get_lpn_sequence (wda.delivery_id)
          x_of_y,
       NVL( order_info.cust_po_number, '' '') po_num,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(NVL (xdsa.customer_name, haou.name)), '' '') shipfrom_name,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(NVL (xdsa.ship_address1, hl.address_line_1)), '' '') shipfrom_address_line_1,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(NVL (xdsa.ship_address2, hl.address_line_2)), '' '') shipfrom_address_line_2,
          NVL( NVL (xdsa.ship_city, hl.town_or_city)
       || '', ''
       || NVL (xdsa.ship_state, hl.region_2)
       || '' ''
       || SUBSTR (NVL (xdsa.ship_zip, hl.postal_code), 1, 5)
          , '' '') shipfrom_city_state_zip,
       '' '' bol_num,
       '' '' pro_num,
       NVL( order_info.edi_ship_to_dc_number, '' '') dc_num,
       NVL( NVL (order_info.edi_b_store_number, order_info.edi_store_number)
          , '' '') store_num,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(NVL(acct_site_b.attribute1, acct_site_s.attribute1)), '' '') distro_cust_name,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(order_info.edi_s_name), '' '') store_name,
       NVL( custom.parse_attributes (ooha.attribute3, ''depart_number''), '' '') AS dept_num,
       NVL( NVL (custom.parse_attributes (ooha.attribute3, ''company_div''),
            custom.parse_attributes (ooha.attribute4, ''depart_name''))
          , '' '') dept_name,
       NVL( custom.parse_attributes (ooha.attribute3, ''company_div''), '' '') AS division_name,
       NVL( custom.parse_attributes (ooha.attribute3, ''company_div''), '' '') AS product_class,
       NVL( order_info.oracle_vendor_number, '' '') vendor_num,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(order_info.edi_vendor_name), '' '') vendor_name,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(custom.parse_attributes (ooha.attribute4, ''ship_to_loc'')), '' '') AS shipto_loc,
       NVL( apps.XXD_WMS_LABEL_PRINT_INT_PKG.fix_value(order_info.oracle_customer_name), '' '') customer_name,
       apps.XXD_WMS_LABEL_PRINT_INT_PKG.get_lpn_sequence (wda.delivery_id,
                                               wlpn.license_plate_number)
          seq_x,
       apps.XXD_WMS_LABEL_PRINT_INT_PKG.get_lpn_sequence (wda.delivery_id) seq_y,
       TO_CHAR (SYSDATE, ''MM-DD-YYYY HH24:MI:SS'') print_date,
       TO_CHAR (SYSDATE, ''MM-DD-YYYY HH24:MI:SS'') ship_date
  FROM apps.wms_license_plate_numbers wlpn,
       do_iface.do_label_oracle_info order_info,
       apps.wsh_delivery_details wdd_container,
       apps.wsh_delivery_assignments wda,
       apps.wsh_delivery_details wdd_items,
       apps.oe_order_lines_all oola,
       apps.oe_order_headers_all ooha,
       apps.hr_locations_all hl,
       apps.hr_all_organization_units haou2,
       apps.hr_all_organization_units haou,
       apps.wsh_carriers_v wc,
       apps.hz_cust_site_uses_all site_b,
       apps.hz_cust_site_uses_all site_s,
       hz_cust_acct_sites_all acct_site_b,
       hz_cust_acct_sites_all acct_site_s,
       xxdo.xxdo_drop_ship_addr_v xdsa
 WHERE     wlpn.license_plate_number = :lpn_name
       AND wlpn.license_plate_number = wdd_container.container_name
       AND wdd_container.delivery_detail_id = wda.parent_delivery_detail_id
       AND wdd_container.carrier_id = wc.carrier_id
       AND wdd_container.source_code = ''WSH''
       AND wda.delivery_detail_id = wdd_items.delivery_detail_id
       AND wdd_items.source_code = ''OE''
       AND wdd_items.released_status = ''Y''
       AND wdd_container.released_status = ''X''
       AND wdd_items.source_line_id = oola.line_id
       AND oola.header_id = ooha.header_id
       AND haou.organization_id = ooha.org_id
       AND order_info.oracle_header_id = wdd_items.source_header_id
       AND order_info.oracle_line_id = wdd_items.source_line_id
       AND haou2.organization_id =
              DECODE (
                 oola.ship_from_org_id,
                 (SELECT organization_id
                    FROM apps.mtl_parameters
                   WHERE organization_code = ''US2''), (SELECT DECODE (
                                                                OOHA.ATTRIBUTE5,
                                                                ''KOOLABURRA'', (SELECT organization_id
                                                                                 FROM apps.mtl_parameters
                                                                                WHERE organization_code =
                                                                                         ''US1''),
                                                                ''TEVA'', (SELECT organization_id
                                                                           FROM apps.mtl_parameters
                                                                          WHERE organization_code =
                                                                                   ''US2''))
                                                        FROM DUAL),
                 oola.ship_from_org_id)
       AND hl.location_id = haou2.location_id
       AND xdsa.customer_id(+) = ooha.sold_to_org_id
       AND site_b.site_use_id = ooha.invoice_to_org_id
       AND acct_site_b.cust_acct_site_id = site_b.cust_acct_site_id
       AND site_s.site_use_id =
                 NVL (oola.deliver_to_org_id, oola.ship_to_org_id)
          AND acct_site_s.cust_acct_site_id = site_s.cust_acct_site_id) UNPIVOT (field_VALUE
                                                       FOR FIELD_NAME
                                                       IN ('
                || lv_field_attributes
                || '))';

            BEGIN
                EXECUTE IMMEDIATE lv_sql
                    BULK COLLECT INTO field_data_tab
                    USING pv_lpn;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            FOR i IN 1 .. field_data_tab.COUNT
            LOOP
                lv_message   :=
                    REPLACE (lv_message,
                             field_data_tab (i).field_name,
                             field_data_tab (i).field_value);
            END LOOP;

            RETURN lv_message;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Exception: ' || SQLERRM);
            RETURN NULL;
    END get_zpl_file;

    PROCEDURE label_main (errbuf          OUT VARCHAR2,
                          retcode         OUT VARCHAR2,
                          pv_label_type       VARCHAR2,
                          pv_printer          VARCHAR2,
                          pv_print_type       VARCHAR2,
                          pv_value            VARCHAR2)
    IS
        lv_printer_status       VARCHAR2 (100);
        lv_return_msg           VARCHAR2 (100);
        lv_zpl_message          VARCHAR2 (4000);
        ln_return_value         NUMBER;
        lv_ip_address           VARCHAR2 (50);
        ln_port_number          NUMBER;
        lv_status               VARCHAR2 (1);
        lv_lpn_context          NUMBER;
        lv_delivery             VARCHAR2 (20);
        lv_sales_channel_code   VARCHAR2 (100);

        TYPE lpn_rec_type IS RECORD
        (
            lpn    WMS_LICENSE_PLATE_NUMBERS.LICENSE_PLATE_NUMBER%TYPE
        );

        TYPE lpn_table_type IS TABLE OF lpn_rec_type
            INDEX BY BINARY_INTEGER;

        lpn_list                lpn_table_type;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'pv_label_type:  ' || pv_label_type);
        fnd_file.put_line (fnd_file.LOG, 'pv_print_type:  ' || pv_print_type);
        fnd_file.put_line (fnd_file.LOG, 'pv_value:  ' || pv_value);

        lv_status   := 'S';

        BEGIN
            SELECT ip_address, port_number
              INTO lv_ip_address, ln_port_number
              FROM apps.WMS_PRINTER_IP_DEF
             WHERE printer_name = pv_printer;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_status   := 'E';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Can not find IP address and port number for printer '
                    || pv_printer);
            WHEN OTHERS
            THEN
                lv_status   := 'E';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Other error when getting IP address and port number for printer '
                    || pv_printer);
        END;

        fnd_file.put_line (fnd_file.LOG, 'IP Address: ' || lv_ip_address);

        fnd_file.put_line (fnd_file.LOG, 'Port:  ' || ln_port_number);

        /* Validate the Data */

        IF pv_print_type = 'LPN'
        THEN
            BEGIN
                SELECT DISTINCT ooha.sales_channel_code
                  INTO lv_sales_channel_code
                  FROM apps.oe_order_headers_all ooha, apps.wsh_delivery_details wdd, apps.wsh_delivery_details wdd1,
                       apps.wsh_delivery_assignments wda, apps.wms_license_plate_numbers wlpn, apps.oe_order_lines_all oola,
                       apps.wsh_new_deliveries wnd, apps.fnd_lookup_values flv
                 WHERE     1 = 1
                       AND ooha.header_id = oola.header_id
                       AND wlpn.license_plate_number = pv_value
                       AND ooha.header_id = wdd.source_header_id
                       AND wdd.source_line_id = oola.line_id
                       AND wdd.source_code = 'OE'
                       AND wda.delivery_id = wnd.delivery_id
                       AND wdd.delivery_detail_id = wda.delivery_detail_id
                       AND wdd1.container_name = wlpn.license_plate_number
                       AND wda.parent_delivery_detail_id =
                           wdd1.delivery_detail_id
                       AND ooha.sales_channel_code = flv.lookup_code
                       AND flv.lookup_type = 'XXD_WMS_LABEL_SALES_CHANNELS'
                       AND flv.language = 'US';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_status   := 'E';
                    fnd_file.put_line (fnd_file.LOG,
                                       'LPN is Not valid Sales Channel');
            END;


            BEGIN
                SELECT lpn_context
                  INTO lv_lpn_context
                  FROM apps.wms_license_plate_numbers
                 WHERE     license_plate_number = pv_value
                       AND lpn_context IN (11, 9);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_status   := 'E';
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'LPN is not in valid Context:  ' || pv_value);
            END;

            BEGIN
                SELECT lpn_context
                  INTO lv_lpn_context
                  FROM apps.wms_license_plate_numbers
                 WHERE license_plate_number = pv_value;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_status   := 'E';
                    fnd_file.put_line (fnd_file.LOG,
                                       'No LPN found:  ' || pv_value);
            END;
        ELSIF pv_print_type = 'DELIVERY'
        THEN
            BEGIN
                SELECT DISTINCT ooha.sales_channel_code
                  INTO lv_sales_channel_code
                  FROM apps.oe_order_headers_all ooha, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda,
                       apps.fnd_lookup_values flv
                 WHERE     1 = 1
                       AND ooha.header_id = wdd.source_header_id
                       AND wdd.source_code = 'OE'
                       AND wda.delivery_id = pv_value
                       AND wdd.delivery_detail_id = wda.delivery_detail_id
                       AND ooha.sales_channel_code = flv.lookup_code
                       AND flv.lookup_type = 'XXD_WMS_LABEL_SALES_CHANNELS'
                       AND flv.language = 'US';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_status   := 'E';
                    fnd_file.put_line (fnd_file.LOG,
                                       'Delviery is Not valid Sales Channel');
            END;

            BEGIN
                SELECT name
                  INTO lv_delivery
                  FROM apps.wsh_new_deliveries
                 WHERE name = pv_value;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_status   := 'E';
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Delivery doesnt exists:  ' || pv_value);
            END;

            FOR rec
                IN (SELECT DISTINCT wdd.container_name lpn
                      FROM apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda, apps.wms_license_plate_numbers wlpn
                     WHERE     1 = 1
                           AND wdd.container_name = wlpn.license_plate_number
                           AND wdd.source_code = 'WSH'
                           AND wda.parent_delivery_detail_id =
                               wdd.delivery_detail_id
                           AND wda.delivery_id = pv_value
                           AND wlpn.lpn_context NOT IN (11, 9))
            LOOP
                lv_status   := 'E';
                fnd_file.put_line (
                    fnd_file.LOG,
                    'LPN is in Invalid Context :  ' || rec.lpn);
            END LOOP;
        END IF;



        IF lv_status = 'S'
        THEN
            lpn_list.DELETE;

            IF pv_print_type = 'LPN'
            THEN
                lpn_list (1).lpn   := pv_value;
            ELSIF pv_print_type = 'DELIVERY'
            THEN
                  SELECT DISTINCT wdd.container_name lpn
                    BULK COLLECT INTO lpn_list
                    FROM apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda
                   WHERE     wdd.source_code = 'WSH'
                         AND wda.parent_delivery_detail_id =
                             wdd.delivery_detail_id
                         AND wda.delivery_id = pv_value
                ORDER BY wdd.container_name;
            END IF;

            IF pv_label_type IN ('BOTH', 'UCC128')
            THEN
                FOR i IN lpn_list.FIRST .. lpn_list.LAST
                LOOP
                    lv_zpl_message   := NULL;
                    lv_zpl_message   :=
                        XXD_WMS_LABEL_PRINT_INT_PKG.get_zpl_file (
                            lpn_list (i).lpn);

                    IF lv_zpl_message IS NOT NULL
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Printing UCC for LPN: ' || lpn_list (i).lpn);
                        ln_return_value   :=
                            INV_PRINT_REQUEST.SEND_XML_TCPIP (
                                p_ip_address       => lv_ip_address,
                                p_port             => TO_CHAR (ln_port_number),
                                p_xml_content      => TO_CLOB (lv_zpl_message),
                                x_return_msg       => lv_return_msg,
                                x_printer_status   => lv_printer_status);
                    END IF;


                    IF ln_return_value = -1
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error in SYNC_PRINT_TCPIP with message '
                            || SQLERRM);
                    END IF;

                    DBMS_LOCK.sleep (gn_delay_time);
                END LOOP;
            END IF;

            IF pv_label_type IN ('BOTH', 'CARTON')
            THEN
                FOR i IN lpn_list.FIRST .. lpn_list.LAST
                LOOP
                    lv_zpl_message   := NULL;
                    lv_zpl_message   :=
                        XXD_WMS_LABEL_PRINT_INT_PKG.get_cc_zpl_file (
                            lpn_list (i).lpn);

                    IF lv_zpl_message IS NOT NULL
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Printing CC for LPN: ' || lpn_list (i).lpn);
                        ln_return_value   :=
                            INV_PRINT_REQUEST.SEND_XML_TCPIP (
                                p_ip_address       => lv_ip_address,
                                p_port             => TO_CHAR (ln_port_number),
                                p_xml_content      => TO_CLOB (lv_zpl_message),
                                x_return_msg       => lv_return_msg,
                                x_printer_status   => lv_printer_status);
                    END IF;

                    IF ln_return_value = -1
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error in SYNC_PRINT_TCPIP with message '
                            || SQLERRM);
                    END IF;

                    DBMS_LOCK.sleep (gn_delay_time);
                END LOOP;
            END IF;
        END IF;

        IF lv_status = 'E'
        THEN
            retcode   := 2;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Inside Main Exception' || SQLERRM);

            fnd_file.put_line (
                fnd_file.LOG,
                'Error in SYNC_PRINT_TCPIP with message ' || SQLERRM);
    END label_main;
END XXD_WMS_LABEL_PRINT_INT_PKG;
/
