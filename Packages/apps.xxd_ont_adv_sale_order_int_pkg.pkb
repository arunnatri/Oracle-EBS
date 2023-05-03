--
-- XXD_ONT_ADV_SALE_ORDER_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_ADV_SALE_ORDER_INT_PKG"
AS
    /***************************************************************************************************************************
    * Package      : xxd_ont_sales_order_int_pkg
    * Design       : This package will be used for Sales Orders and Shipments Interface to O9
    * Notes        :
    * Modification :
    -- =========================================================================================================================
    -- Date         Version#   Name                     Comments
    -- =========================================================================================================================
    -- 10-May-2021  1.0         Balavenu Rao             Initial Version  (CCR0009135)
    -- 30-Jun-2022  1.1         Gaurav Joshi             Include Cancelled order also CCR0009135
    -- 03-Aug-2022  1.2         Gowrishankar Chakrapani  Include Uuscheduled lines CCR0010146
    -- 18-AUG-2022  1.3         Gowrishankar Chakrapani  CCR0010166 - O9 Demand Planning - Sprint 13 Enhancements
    ***************************************************************************************************************************/
    -- =========================================================================================================================
    -- Set values for Global Variables
    -- =========================================================================================================================
    -- Modifed to init G variable from input params

    gn_user_id             NUMBER := fnd_global.user_id;
    gn_login_id            NUMBER := fnd_global.login_id;
    gn_request_id          NUMBER := fnd_global.conc_request_id;
    gc_debug_enable        VARCHAR2 (1);
    gc_delimiter           VARCHAR2 (100);
    gc_ecom_customer_num   VARCHAR2 (100) := NULL;
    gc_ecom_customer       VARCHAR2 (200) := NULL;
    g_order_type           VARCHAR2 (100);
    g_create_file          VARCHAR2 (100);
    g_send_mail            VARCHAR2 (10);
    g_errbuf               VARCHAR2 (100);
    g_retcode              VARCHAR2 (2000);
    g_email_id             VARCHAR2 (2000);
    g_sales_channel_code   VARCHAR2 (100) := 'E-COMMERCE';
    g_number_days_purg     NUMBER;
    g_inv_org_code         VARCHAR2 (100);
    g_debug_flag           VARCHAR2 (10);

    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log Or File
    -- ======================================================================================

    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, gc_delimiter || p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    PROCEDURE get_last_extract_date (p_interface_name IN VARCHAR2, p_region IN VARCHAR2, p_last_update_date OUT VARCHAR2, p_latest_update_date OUT VARCHAR2, p_file_path OUT VARCHAR2, x_status OUT NOCOPY VARCHAR2
                                     , x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        --Retrive Last Update Date

        SELECT tag
          INTO p_last_update_date
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_PO_O9_INTERFACES_LKP'
               AND lookup_code =
                   DECODE (
                       p_interface_name || '-' || p_region,
                       'Gross Orders-APAC', 'GROSSORDERSAPAC',
                       'Gross Orders-NA_LATAM', 'GROSSORDERNALATAM',
                       'Gross Orders-EMEA', 'GROSSORDERSAPACEMEA',
                       'Gross Orders-ALL', 'GROSSORDERSALL',
                       'Shipment Orders-APAC', 'SHIPMENTORDERSAPAC',
                       'Shipment Orders-NA_LATAM', 'SHIPMENTORDERSNALATAM',
                       'Shipment Orders-EMEA', 'SHIPMENTORDERSEMEA',
                       'Shipment Orders-ALL', 'SHIPMENTORDERSALL',
                       'Open Orders-APAC', 'OPENORDERSAPAC',
                       'Open Orders-NA_LATAM', 'OPENORDERSNALATAM',
                       'Open Orders-EMEA', 'OPENORDERSEMEA',
                       'Open Orders-ALL', 'OPENORDERSALL',
                       'Unscheduled Orders-APAC', 'UNSCHEDULEDORDERSAPAC',
                       'Unscheduled Orders-NA_LATAM', 'UNSCHEDULEDORDERSNALATAM',
                       'Unscheduled Orders-EMEA', 'UNSCHEDULEDORDERSEMEA',
                       'Unscheduled Orders-ALL', 'UNSCHEDULEDORDERSALL')
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE
               AND NVL (enabled_flag, 'N') = 'Y'
               AND language = USERENV ('LANG');

        -- Retrive File Path Location
        SELECT meaning
          INTO p_file_path
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_PO_O9_INTERFACES_LKP'
               AND lookup_code = 'FILE_PATH_TRANSACTIONAL_DATA'
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE
               AND NVL (enabled_flag, 'N') = 'Y'
               AND language = USERENV ('LANG');

        p_latest_update_date   := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'); -- Added for CCR0010146 on 03AUG2022 Ver 1.2
        x_status               := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status               := 'E';
            x_message              := SUBSTR (SQLERRM, 1, 2000);
            p_last_update_date     := NULL;
            p_latest_update_date   := NULL;
    END get_last_extract_date;

    PROCEDURE update_last_extract_date (
        p_interface_name       IN            VARCHAR2,
        p_region               IN            VARCHAR2,
        p_latest_update_date   IN            VARCHAR2,
        x_status                  OUT NOCOPY VARCHAR2,
        x_message                 OUT NOCOPY VARCHAR2)
    IS
        CURSOR c1 IS
            SELECT lookup_type, lookup_code, enabled_flag,
                   security_group_id, view_application_id, tag,
                   meaning
              FROM fnd_lookup_values_vl
             WHERE     lookup_type = 'XXD_PO_O9_INTERFACES_LKP'
                   AND lookup_code =
                       DECODE (
                           p_interface_name || '-' || p_region,
                           'Gross Orders-APAC', 'GROSSORDERSAPAC',
                           'Gross Orders-NA_LATAM', 'GROSSORDERNALATAM',
                           'Gross Orders-EMEA', 'GROSSORDERSAPACEMEA',
                           'Gross Orders-ALL', 'GROSSORDERSALL',
                           'Shipment Orders-APAC', 'SHIPMENTORDERSAPAC',
                           'Shipment Orders-NA_LATAM', 'SHIPMENTORDERSNALATAM',
                           'Shipment Orders-EMEA', 'SHIPMENTORDERSEMEA',
                           'Shipment Orders-ALL', 'SHIPMENTORDERSALL',
                           'Open Orders-APAC', 'OPENORDERSAPAC',
                           'Open Orders-NA_LATAM', 'OPENORDERSNALATAM',
                           'Open Orders-EMEA', 'OPENORDERSEMEA',
                           'Open Orders-ALL', 'OPENORDERSALL',
                           'Unscheduled Orders-APAC', 'UNSCHEDULEDORDERSAPAC',
                           'Unscheduled Orders-NA_LATAM', 'UNSCHEDULEDORDERSNALATAM',
                           'Unscheduled Orders-EMEA', 'UNSCHEDULEDORDERSEMEA',
                           'Unscheduled Orders-ALL', 'UNSCHEDULEDORDERSALL')
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE) >= SYSDATE
                   AND NVL (enabled_flag, 'N') = 'Y';
    BEGIN
        FOR i IN c1
        LOOP
            BEGIN
                fnd_lookup_values_pkg.update_row (
                    x_lookup_type           => i.lookup_type,
                    x_security_group_id     => i.security_group_id,
                    x_view_application_id   => i.view_application_id,
                    x_lookup_code           => i.lookup_code,
                    x_tag                   => p_latest_update_date,
                    x_attribute_category    => 'XXD_PO_O9_INTERFACES_LKP_CONT', --NULL,
                    x_attribute1            => p_region,               --NULL,
                    x_attribute2            => NULL,
                    x_attribute3            => NULL,
                    x_attribute4            => NULL,
                    x_enabled_flag          => 'Y',
                    x_start_date_active     => NULL,
                    x_end_date_active       => NULL,
                    x_territory_code        => NULL,
                    x_attribute5            => NULL,
                    x_attribute6            => NULL,
                    x_attribute7            => NULL,
                    x_attribute8            => NULL,
                    x_attribute9            => NULL,
                    x_attribute10           => NULL,
                    x_attribute11           => NULL,
                    x_attribute12           => NULL,
                    x_attribute13           => NULL,
                    x_attribute14           => NULL,
                    x_attribute15           => NULL,
                    x_meaning               => i.meaning,
                    x_description           => i.tag,
                    x_last_update_date      => TRUNC (SYSDATE),
                    x_last_updated_by       => fnd_global.user_id,
                    x_last_update_login     => fnd_global.user_id);

                COMMIT;
                x_status   := 'S';
                debug_msg (i.lookup_code || ' Lookup has been Updated');
                debug_msg (' start_date(description) :' || i.tag);
                debug_msg (
                    ' end_date(tag)           :' || p_latest_update_date);
                debug_msg (i.lookup_code || ' has been Updated  !!!!');
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg (
                        i.lookup_code || ' - Inner Exception - ' || SQLERRM);
                    x_status   := 'E';
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END update_last_extract_date;

    PROCEDURE get_ecom_customer_values
    AS
    BEGIN
        SELECT meaning, description
          INTO gc_ecom_customer_num, gc_ecom_customer
          FROM fnd_lookup_values a
         WHERE     lookup_type = 'XXD_O9_ECOM_CUSTOMER_LKP'
               AND LOOKUP_CODE = 'ECOM'
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE
               AND NVL (enabled_flag, 'N') = 'Y'
               AND language = USERENV ('LANG');
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END get_ecom_customer_values;


    PROCEDURE set_status (p_status     IN VARCHAR2,
                          p_err_msg    IN VARCHAR2,
                          p_filename   IN VARCHAR2)
    AS
    BEGIN
        BEGIN
            UPDATE xxd_ont_adv_sales_order_int_t
               SET status = p_status, file_name = p_filename, error_message = p_err_msg
             WHERE status = 'N' AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_msg (
                       'Error While Updating Record Status and File Name: '
                    || SQLERRM);
        END;
    END set_status;

    PROCEDURE delete_records
    AS
    BEGIN
        BEGIN
            DELETE FROM xxd_ont_adv_sales_order_int_t
                  WHERE request_id = gn_request_id;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_msg ('Error While Deleting From Table: ' || SQLERRM);
        END;
    END delete_records;

    FUNCTION get_sale_channel_code_fnc
        RETURN sales_channel_code_record_tbl
        PIPELINED
    IS
        l_sales_chnel_code_recrd_rec   sales_channel_code_record_rec;
    BEGIN
        FOR l_sales_chnel_code_recrd_rec
            IN (SELECT meaning, DESCRIPTION
                  FROM fnd_lookup_values
                 WHERE     1 = 1
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND lookup_type = 'XXD_ONT_O9_SALES_CHANNEL_CODE')
        LOOP
            PIPE ROW (l_sales_chnel_code_recrd_rec);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Others Exception in get_sale_channel_code_fnc = ' || SQLERRM);
            NULL;
    END get_sale_channel_code_fnc;

    FUNCTION get_invetory_org_record_fun
        RETURN invetory_org_record_tbl
        PIPELINED
    IS
        l_invetory_org_record_rec   invetory_org_record_rec;
    BEGIN
        FOR l_invetory_org_record_rec
            IN (SELECT meaning, tag
                  FROM fnd_lookup_values
                 WHERE     1 = 1
                       AND tag <> 'ALL'
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND lookup_type = 'XXD_INV_O9_INCLUDE_INV_ORGS'
                UNION ALL
                SELECT DISTINCT 'MC2' meaning, tag
                  FROM fnd_lookup_values
                 WHERE     1 = 1
                       AND tag <> 'ALL'
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND lookup_type = 'XXD_INV_O9_INCLUDE_INV_ORGS')
        LOOP
            PIPE ROW (l_invetory_org_record_rec);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                   'Others Exception in get_invetory_org_record_fun = '
                || SQLERRM);
            NULL;
    END get_invetory_org_record_fun;

    FUNCTION get_order_typs_record_fun
        RETURN order_typs_record_tbl
        PIPELINED
    IS
        l_order_typs_record_rec   order_typs_record_rec;
    BEGIN
        FOR l_order_typs_record_rec
            IN (SELECT description
                  FROM fnd_lookup_values
                 WHERE     1 = 1
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND lookup_type = 'XXD_ONT_O9_EXCLUDE_ORDER_TYPES')
        LOOP
            PIPE ROW (l_order_typs_record_rec);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Others Exception in get_order_typs_record_fun = ' || SQLERRM);
            NULL;
    END get_order_typs_record_fun;

    FUNCTION get_country_values_fnc
        RETURN country_record_tble
        PIPELINED
    IS
        l_country_record_tble   country_record_rec;
    BEGIN
        FOR l_country_record_tble
            IN (SELECT meaning, attribute2, attribute1,
                       attribute3
                  FROM fnd_lookup_values
                 WHERE     1 = 1
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND lookup_type = 'XXD_PO_O9_CNTRY_RGN_SUB_RGN_MP')
        LOOP
            PIPE ROW (l_country_record_tble);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Others Exception in get_country_values_fnc = ' || SQLERRM);
            NULL;
    END get_country_values_fnc;

    PROCEDURE gross_order_prc (p_enter_dates IN VARCHAR2, p_start_date IN VARCHAR2, p_end_date IN VARCHAR2
                               , p_region IN VARCHAR2)
    AS
        CURSOR c_inst (p_start_date   DATE,
                       p_end_date     DATE,
                       p_region_vl    VARCHAR2)
        IS
            SELECT DISTINCT             -- Added for CCR0010166 on 18-AUG-2022
                   order_number,
                   line_number,
                   item,
                   (SELECT res.resource_name
                      FROM apps.jtf_rs_salesreps rs, apps.jtf_rs_resource_extns_vl res
                     WHERE     1 = 1
                           AND rs.resource_id = res.resource_id
                           AND rs.salesrep_id = mainq.salesrep_id
                           AND rs.org_id = mainq.org_id)
                       sales_rep_name,
                   INITCAP (NVL (sales_channel_code, 'Wholesale'))
                       sales_channel_code,
                   order_type,
                   UPPER (account_number_country_state)
                       account_number_country_state,
                   account_number,
                   UPPER (loct.country)
                       country,
                   UPPER (state_province)
                       state_province,
                   loct.region,
                   loct.sub_region,
                   order_quantity,
                   unit_selling_price,
                   order_amount,
                   request_date
                       sales_date,
                   organization_code,
                   transactional_curr_code,
                   ROUND (unit_selling_price * exchange_rate, 2)
                       unit_selling_price_usd,
                   ROUND (order_amount * exchange_rate, 2)
                       amount_usd
              FROM (SELECT /*+ use_nl leading (ool) parallel(4) */
                           ooh.header_id,
                           ooh.org_id,
                           ooh.order_number,
                           ool.line_number || '.' || ool.shipment_number
                               line_number,
                           ool.ordered_item
                               item,
                           NVL (slcnl.sales_channel_code,
                                ooh.sales_channel_code)
                               sales_channel_code,
                           TRUNC (ool.request_date)
                               request_date,
                           DECODE (
                               ooh.sales_channel_code,
                               g_sales_channel_code,    gc_ecom_customer_num
                                                     || '-'
                                                     || mc.segment1,
                               DECODE (
                                   NVL (hca.attribute1, 'XXX'),
                                   'ALL BRAND',    hca.account_number
                                                || '-'
                                                || mc.segment1,
                                   'XXX',    hca.account_number
                                          || '-'
                                          || mc.segment1,
                                   hca.account_number))
                               account_number,
                           DECODE (
                               NVL (xoalm.forecast_country, hl.country),
                               'USO', 'ZZ',
                               DECODE (
                                   xoalm.include_state_province,
                                   'Y', NVL (NVL (hl.state, hl.province),
                                             'ZZ'),
                                   'ZZ'))
                               state_province,
                           ott.name || '-' || ool.line_category_code
                               order_type,
                           /*ver 1.1 begin new logic for qty and order amount considering cancelled_quantity **/
                           CASE
                               WHEN ool.flow_Status_code = 'CANCELLED' THEN 0
                               WHEN ool.schedule_ship_date IS NULL -- Added for CCR0010146 on 03AUG2022 Ver 1.2
                                                                   THEN 0
                               ELSE ool.ordered_quantity
                           END
                               order_quantity,
                           CASE
                               WHEN ool.flow_Status_code = 'CANCELLED'
                               THEN
                                   0
                               WHEN ool.schedule_ship_date IS NULL -- Added for CCR0010146 on 03AUG2022 Ver 1.2
                               THEN
                                   0
                               ELSE
                                     ool.ordered_quantity
                                   * ool.unit_selling_price
                           END
                               order_amount, /* end ver 1.1 new logic for qty and order amount considering cancelled_quantity */
                           --   (ool.ordered_quantity)   order_quantity,  -- ver 1.1 commented
                           --  ( (ool.ordered_quantity  ) * ool.unit_selling_price) -- ver 1.1 commented order_amount,
                           ool.unit_selling_price,
                           ooh.salesrep_id,
                           NVL (xoalm.forecast_country, hl.country)
                               country,
                           xoalm.region,
                           xoalm.sub_region,
                              DECODE (
                                  ooh.sales_channel_code,
                                  g_sales_channel_code,    gc_ecom_customer_num
                                                        || '-'
                                                        || mc.segment1,
                                  DECODE (
                                      NVL (hca.attribute1, 'XXX'),
                                      'ALL BRAND',    hca.account_number
                                                   || '-'
                                                   || mc.segment1,
                                      'XXX',    hca.account_number
                                             || '-'
                                             || mc.segment1,
                                      hca.account_number))
                           || '-'
                           || NVL (xoalm.forecast_country, hl.country)
                           || '-'
                           || DECODE (
                                  xoalm.include_state_province,
                                  'Y', NVL (NVL (hl.state, hl.province),
                                            'ZZ'),
                                  'ZZ')
                               account_number_country_state,
                           hca.cust_account_id,
                           mp.organization_code,
                           ooh.transactional_curr_code,
                           NVL (
                               (SELECT conversion_rate
                                  FROM apps.gl_daily_rates gdr
                                 WHERE     1 = 1
                                       AND gdr.from_currency =
                                           ooh.transactional_curr_code
                                       AND conversion_type =
                                           NVL (ooh.conversion_type_code,
                                                'Corporate')
                                       AND conversion_date =
                                           CASE
                                               WHEN ool.request_date <
                                                    SYSDATE
                                               THEN
                                                   TRUNC (ool.request_date)
                                               ELSE
                                                   TRUNC (SYSDATE)
                                           END
                                       AND gdr.from_currency <> 'USD'
                                       AND gdr.to_currency = 'USD'),
                               1)
                               exchange_rate
                      FROM apps.oe_order_headers_all ooh,
                           apps.oe_order_lines_all ool,
                           apps.hz_cust_site_uses_all hcsu,
                           apps.hz_cust_acct_sites_all hcas,
                           apps.hz_party_sites hps,
                           apps.hz_locations hl,
                           apps.oe_transaction_types_tl ott,
                           apps.hz_cust_accounts hca,
                           mtl_parameters mp,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_sale_channel_code_fnc)
                           slcnl,
                           (SELECT DISTINCT country, sub_region, region,
                                            include_state_province, forecast_country, sales_channel_code
                              FROM xxd_ont_adv_loc_master_int_t) xoalm,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_invetory_org_record_fun)
                           invorg, -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           mtl_item_categories mic,
                           mtl_category_sets mcs,
                           mtl_categories_b mc
                     WHERE     1 = 1
                           AND ooh.header_id = ool.header_id
                           AND ool.line_category_code = 'ORDER'
                           AND ool.last_update_date BETWEEN p_start_date
                                                        AND p_end_date
                           AND ool.ship_to_org_id = hcsu.site_use_id
                           AND hcsu.site_use_code = 'SHIP_TO'
                           AND hcsu.cust_acct_site_id =
                               hcas.cust_acct_site_id
                           AND hcas.party_site_id = hps.party_site_id
                           AND hps.location_id = hl.location_id
                           AND hl.country = xoalm.country
                           AND ooh.order_type_id = ott.transaction_type_id
                           AND ott.language = USERENV ('LANG')
                           AND ooh.sold_to_org_id = hca.cust_account_id
                           --AND ool.schedule_ship_date IS NOT NULL -- ver 1.1
                           -- AND decode(ool.flow_status_code, 'CANCELLED', 'X', ool.schedule_ship_date) is not null  --VER 1.1  -- Commented for CCR0010146 on 02AUG2022
                           AND ool.flow_Status_code NOT IN ('ENTERED') -- VER 1.1 REMOVED CANCELLED FROM IN CLUASE
                           AND ooh.sales_channel_code =
                               slcnl.sales_channel(+)
                           AND NVL (slcnl.SALES_CHANNEL_CODE,
                                    ooh.sales_channel_code) =
                               UPPER (xoalm.sales_channel_code)
                           AND ott.name NOT IN
                                   (SELECT order_type FROM TABLE (xxd_ont_adv_sale_order_int_pkg.get_order_typs_record_fun))
                           AND ool.ship_from_org_id = mp.organization_id
                           AND xoalm.region =
                               DECODE (p_region_vl,
                                       'ALL', xoalm.region,
                                       p_region_vl)
                           --AND xoalm.region = invorg.region
                           AND mp.organization_code =
                               invorg.inv_organization_code -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           AND ool.inventory_item_id = mic.inventory_item_id
                           AND ool.ship_from_org_id = mic.organization_id
                           AND mic.category_set_id = mcs.category_set_id
                           AND mic.category_id = mc.category_id
                           AND mc.structure_id = mcs.structure_id
                           AND mcs.category_set_name = 'Inventory'
                           AND NVL (hca.attribute1, 'ALL BRAND') IN
                                   (SELECT brand
                                      FROM TABLE (xxd_ar_adv_cust_master_int_pkg.get_brand_val_fnc)
                                    UNION
                                    SELECT 'ALL BRAND' brand FROM DUAL)
                    UNION ALL
                    -- RETURN ORDERS
                    SELECT /*+ use_nl leading (ool) parallel(4) */
                           ooh.header_id,
                           ooh.org_id,
                           ooh.order_number,
                           ool.line_number || '.' || ool.shipment_number
                               line_number,
                           ool.ordered_item
                               item,
                           NVL (slcnl.sales_channel_code,
                                ooh.sales_channel_code)
                               sales_channel_code,
                           TRUNC (ool.request_date)
                               request_date,
                           DECODE (
                               ooh.sales_channel_code,
                               g_sales_channel_code,    gc_ecom_customer_num
                                                     || '-'
                                                     || mc.segment1,
                               DECODE (
                                   NVL (hca.attribute1, 'XXX'),
                                   'ALL BRAND',    hca.account_number
                                                || '-'
                                                || mc.segment1,
                                   'XXX',    hca.account_number
                                          || '-'
                                          || mc.segment1,
                                   hca.account_number))
                               account_number,
                           DECODE (
                               NVL (xoalm.forecast_country, hl.country),
                               'USO', 'ZZ',
                               DECODE (
                                   xoalm.include_state_province,
                                   'Y', NVL (NVL (hl.state, hl.province),
                                             'ZZ'),
                                   'ZZ'))
                               state_province,
                           ott.name || '-' || ool.line_category_code
                               order_type,
                           /*ver 1.1 begin new logic for qty and order amount considering cancelled_quantity **/
                           CASE
                               WHEN ool.flow_Status_code = 'CANCELLED' THEN 0
                               ELSE (ool.ordered_quantity * -1)
                           END
                               order_quantity,
                           CASE
                               WHEN ool.flow_Status_code = 'CANCELLED'
                               THEN
                                   0
                               ELSE
                                     (ool.ordered_quantity * -1)
                                   * ool.unit_selling_price
                           END
                               order_amount, /* VER 1.1 COMMENTED
                           (ool.ordered_quantity * -1) order_quantity,
                                             (  (ool.ordered_quantity * -1)
                                              * ool.unit_selling_price)
                                                 order_amount,
                            */
                           ool.unit_selling_price,
                           ooh.salesrep_id,
                           NVL (xoalm.forecast_country, hl.country)
                               country,
                           xoalm.region,
                           xoalm.sub_region,
                              DECODE (
                                  ooh.sales_channel_code,
                                  g_sales_channel_code,    gc_ecom_customer_num
                                                        || '-'
                                                        || mc.segment1,
                                  DECODE (
                                      NVL (hca.attribute1, 'XXX'),
                                      'ALL BRAND',    hca.account_number
                                                   || '-'
                                                   || mc.segment1,
                                      'XXX',    hca.account_number
                                             || '-'
                                             || mc.segment1,
                                      hca.account_number))
                           || '-'
                           || NVL (xoalm.forecast_country, hl.country)
                           || '-'
                           || DECODE (
                                  xoalm.include_state_province,
                                  'Y', NVL (NVL (hl.state, hl.province),
                                            'ZZ'),
                                  'ZZ')
                               account_number_country_state,
                           hca.cust_account_id,
                           mp.organization_code,
                           ooh.transactional_curr_code,
                           NVL (
                               (SELECT conversion_rate
                                  FROM apps.gl_daily_rates gdr
                                 WHERE     1 = 1
                                       AND gdr.from_currency =
                                           ooh.transactional_curr_code
                                       AND conversion_type =
                                           NVL (ooh.conversion_type_code,
                                                'Corporate')
                                       AND conversion_date =
                                           CASE
                                               WHEN ool.request_date <
                                                    SYSDATE
                                               THEN
                                                   TRUNC (ool.request_date)
                                               ELSE
                                                   TRUNC (SYSDATE)
                                           END
                                       AND gdr.from_currency <> 'USD'
                                       AND gdr.to_currency = 'USD'),
                               1)
                               exchange_rate
                      FROM apps.oe_order_headers_all ooh,
                           apps.oe_order_lines_all ool,
                           apps.hz_cust_site_uses_all hcsu,
                           apps.hz_cust_acct_sites_all hcas,
                           apps.hz_party_sites hps,
                           apps.hz_locations hl,
                           apps.oe_transaction_types_tl ott,
                           apps.hz_cust_accounts hca,
                           apps.mtl_parameters mp,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_sale_channel_code_fnc)
                           slcnl,
                           (SELECT DISTINCT country, sub_region, region,
                                            include_state_province, forecast_country, sales_channel_code
                              FROM xxd_ont_adv_loc_master_int_t) xoalm,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_invetory_org_record_fun)
                           invorg, -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           mtl_item_categories mic,
                           mtl_category_sets mcs,
                           mtl_categories_b mc
                     WHERE     ooh.header_id = ool.header_id
                           AND ool.line_category_code = 'RETURN'
                           AND ool.last_update_date BETWEEN p_start_date
                                                        AND p_end_date
                           AND ool.ship_to_org_id = hcsu.site_use_id
                           AND hcsu.site_use_code = 'SHIP_TO'
                           AND hcsu.cust_acct_site_id =
                               hcas.cust_acct_site_id
                           AND hcas.party_site_id = hps.party_site_id
                           AND hps.location_id = hl.location_id
                           AND hl.country = xoalm.country
                           AND ooh.order_type_id = ott.transaction_type_id
                           AND ott.language = USERENV ('LANG')
                           AND ooh.sold_to_org_id = hca.cust_account_id
                           AND ool.flow_Status_code NOT IN ('ENTERED') -- ver 1.1 removed cancelled from the not in condition
                           AND ooh.sales_channel_code =
                               slcnl.sales_channel(+)
                           AND NVL (slcnl.SALES_CHANNEL_CODE,
                                    ooh.sales_channel_code) =
                               UPPER (xoalm.sales_channel_code)
                           AND ott.name NOT IN
                                   (SELECT order_type FROM TABLE (xxd_ont_adv_sale_order_int_pkg.get_order_typs_record_fun))
                           AND ool.ship_from_org_id = mp.organization_id
                           AND xoalm.region =
                               DECODE (p_region_vl,
                                       'ALL', xoalm.region,
                                       p_region_vl)
                           --AND xoalm.region = invorg.region
                           AND mp.organization_code =
                               invorg.inv_organization_code -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           AND ool.inventory_item_id = mic.inventory_item_id
                           AND ool.ship_from_org_id = mic.organization_id
                           AND mic.category_set_id = mcs.category_set_id
                           AND mic.category_id = mc.category_id
                           AND mc.structure_id = mcs.structure_id
                           AND mcs.category_set_name = 'Inventory'
                           AND NVL (hca.attribute1, 'ALL BRAND') IN
                                   (SELECT brand
                                      FROM TABLE (xxd_ar_adv_cust_master_int_pkg.get_brand_val_fnc)
                                    UNION
                                    SELECT 'ALL BRAND' brand FROM DUAL))
                   mainq,
                   (SELECT DISTINCT country, sub_region, region
                      FROM xxd_ont_adv_loc_master_int_t) loct
             WHERE mainq.country = loct.country;

        CURSOR c_write IS
              SELECT *
                FROM xxd_ont_adv_sales_order_int_t
               WHERE status = 'N' AND request_id = gn_request_id
            ORDER BY order_number, TO_NUMBER (line_number);

        TYPE xxd_ins_type IS TABLE OF c_inst%ROWTYPE;

        TYPE xxd_write_type IS TABLE OF c_write%ROWTYPE;

        v_ins_type              xxd_ins_type := xxd_ins_type ();
        v_write_type            xxd_write_type := xxd_write_type ();
        lv_write_file           UTL_FILE.file_type;
        filename                VARCHAR2 (100);
        lv_error_code           VARCHAR2 (4000) := NULL;
        ln_error_num            NUMBER;
        lv_error_msg            VARCHAR2 (4000) := NULL;
        lv_last_update_date     VARCHAR2 (200) := NULL;
        lv_latest_update_date   VARCHAR2 (200) := NULL;
        lv_status               VARCHAR2 (10) := 'S';
        lv_msg                  VARCHAR2 (4000) := NULL;
        le_bulk_inst_exe        EXCEPTION;
        lv_err_msg              VARCHAR2 (4000) := NULL;
        lv_start_date           DATE := NULL;
        lv_end_date             DATE := NULL;
        lv_param_start_date     DATE := NULL;
        lv_param_end_date       DATE := NULL;
        lv_mail_status          VARCHAR2 (200) := NULL;
        lv_mail_msg             VARCHAR2 (4000) := NULL;
        lv_instance_name        VARCHAR2 (200) := NULL;
        lv_create_file_flag     VARCHAR2 (10) := 'N';
        lv_file_path            VARCHAR2 (360) := NULL;
        lv_region               VARCHAR2 (100) := NULL;
    BEGIN
        debug_msg (
               ' Parameters Are.....'
            || CHR (10)
            || '	g_order_type	:'
            || g_order_type
            || CHR (10)
            || '	g_create_file	:'
            || g_create_file
            || CHR (10)
            || '	g_send_mail  	:'
            || g_send_mail
            || CHR (10));

        get_ecom_customer_values;
        lv_region      :=
            REGEXP_SUBSTR (p_region, '[^_]+', 1,
                           1);
        get_last_extract_date (g_order_type, p_region, lv_last_update_date,
                               lv_latest_update_date, lv_file_path, lv_status
                               , lv_msg);



        debug_msg (
               ' Start Interface '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        IF (lv_status = 'S')
        THEN
            v_ins_type.delete;
            v_write_type.delete;

            IF (p_enter_dates = 'N')
            THEN
                lv_start_date   :=
                    TO_DATE (lv_last_update_date, 'DD-MON-YYYY HH24:MI:SS');
                lv_end_date   :=
                    TO_DATE (lv_latest_update_date, 'DD-MON-YYYY HH24:MI:SS');
            ELSE
                lv_start_date   :=
                    TO_DATE (p_start_date, 'DD-MON-YYYY HH24:MI:SS');
                lv_end_date   :=
                    TO_DATE (p_end_date, 'DD-MON-YYYY HH24:MI:SS');
            END IF;

            debug_msg (' START_DATE :' || lv_start_date);
            debug_msg (' END_DATE :' || lv_end_date);

            -------------------------------
            -- Insert Logic
            -------------------------------
            BEGIN
                gc_delimiter   := CHR (9);
                debug_msg (
                       ' Start Insert At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                OPEN c_inst (lv_start_date, lv_end_date, lv_region);

                LOOP
                    FETCH c_inst BULK COLLECT INTO v_ins_type LIMIT 10000;

                    BEGIN
                        IF (g_debug_flag = 'Y')
                        THEN
                            gc_delimiter   := CHR (9) || CHR (9);
                            debug_msg (
                                   ' Start Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        END IF;

                        IF (v_ins_type.COUNT > 0)
                        THEN
                            lv_create_file_flag   := 'Y';

                            FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                              SAVE EXCEPTIONS
                                INSERT INTO xxd_ont_adv_sales_order_int_t (
                                                file_name,
                                                order_number,
                                                line_number,
                                                item,
                                                sales_rep_name,
                                                sales_channel_code,
                                                order_type,
                                                account_number_country_state,
                                                account_number,
                                                country,
                                                state_province,
                                                region,
                                                sub_region,
                                                order_quantity,
                                                unit_selling_price,
                                                order_amount,
                                                sales_date,
                                                interface_type,
                                                status,
                                                error_message,
                                                attribute1,
                                                attribute2,
                                                attribute3,
                                                attribute4,
                                                attribute5,
                                                attribute6,
                                                attribute7,
                                                attribute8,
                                                attribute9,
                                                attribute10,
                                                attribute11,
                                                attribute12,
                                                attribute13,
                                                attribute14,
                                                attribute15,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_updated_by,
                                                last_update_date,
                                                last_update_login,
                                                organization_code,
                                                unit_selling_price_usd,
                                                amount_usd,
                                                currency)
                                         VALUES (
                                                    NULL,
                                                    v_ins_type (i).order_number,
                                                    v_ins_type (i).line_number,
                                                    v_ins_type (i).item,
                                                    v_ins_type (i).sales_rep_name,
                                                    v_ins_type (i).sales_channel_code,
                                                    v_ins_type (i).order_type,
                                                    v_ins_type (i).account_number_country_state,
                                                    v_ins_type (i).account_number,
                                                    v_ins_type (i).country,
                                                    v_ins_type (i).state_province,
                                                    v_ins_type (i).region,
                                                    v_ins_type (i).sub_region,
                                                    v_ins_type (i).order_quantity,
                                                    v_ins_type (i).unit_selling_price,
                                                    v_ins_type (i).order_amount,
                                                    v_ins_type (i).sales_date,
                                                       g_order_type
                                                    || '-'
                                                    || p_region,
                                                    'N',
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    gn_request_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    gn_user_id,
                                                    SYSDATE,
                                                    gn_login_id,
                                                    v_ins_type (i).organization_code,
                                                    v_ins_type (i).unit_selling_price_usd,
                                                    v_ins_type (i).amount_usd,
                                                    v_ins_type (i).transactional_curr_code);

                            COMMIT;
                        END IF;

                        IF (g_debug_flag = 'Y')
                        THEN
                            debug_msg (
                                   ' End Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Insert into Table Item' || v_ins_type (ln_error_num).item || ' ' || lv_error_code || CHR (10)),
                                        1,
                                        4000);

                                debug_msg (lv_error_msg);
                                lv_status   := 'E';
                            END LOOP;

                            IF (g_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Insert Record Count '
                                    || v_ins_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            RAISE le_bulk_inst_exe;
                    END;

                    v_ins_type.delete;
                    EXIT WHEN c_inst%NOTFOUND;
                END LOOP;

                CLOSE c_inst;

                gc_delimiter   := CHR (9);
                debug_msg (
                       ' End Inserting At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            EXCEPTION
                WHEN le_bulk_inst_exe
                THEN
                    lv_status      := 'E';
                    set_status (
                        'E',
                        SUBSTR (
                               'Error While Bulk Inserting Into Table '
                            || SQLERRM,
                            1,
                            2000),
                        filename);

                    g_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    g_retcode      := 1;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End Inserting at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                WHEN OTHERS
                THEN
                    lv_status      := 'E';
                    set_status (
                        'E',
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000),
                        filename);

                    g_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    g_retcode      := 1;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End Inserting at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            END;

            -- --------------------------
            --  Writing to .TXT File Logic
            -- --------------------------
            IF (g_create_file = 'Y')
            THEN
                IF (lv_create_file_flag = 'Y' AND lv_status = 'S')
                THEN
                    BEGIN
                        debug_msg (RPAD ('=', 100, '='));
                        debug_msg (
                               ' Start Writing into File at '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                        IF (g_order_type = 'Gross Orders')
                        THEN
                            filename   :=
                                   'DECKERS_GROSS_ORDERS_'
                                || p_region
                                || '_'
                                || TO_CHAR (SYSDATE, 'DDMONYYYY_HH24MISS')
                                || '.txt';
                        END IF;

                        EXECUTE IMMEDIATE 'alter session set nls_date_format=''YYYY/MM/DD''';

                        lv_write_file   :=
                            UTL_FILE.fopen (lv_file_path, filename, 'W');
                        UTL_FILE.put_line (
                            lv_write_file,
                            'ORDER_NUMBER|LINE_NUMBER|SKU|SALES_REP_NAME|SALES_CHANNEL|ORDER_TYPE|ACCOUNT_COUNTRY_STATE|ACCOUNT_NUMBER|COUNTRY|STATE_PROVINCE|REGION|SUB_REGION|QUANTITY|CURRENCY|UNIT_SELLING_PRICE|AMOUNT|SALES DATE|UNIT_SELLING_PRICE_USD|AMOUNT_USD');

                        OPEN c_write;

                        LOOP
                            FETCH c_write
                                BULK COLLECT INTO v_write_type
                                LIMIT 10000;

                            IF (g_debug_flag = 'Y')
                            THEN
                                gc_delimiter   := CHR (9) || CHR (9);
                                debug_msg (
                                       ' Start Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            IF (v_write_type.COUNT > 0)
                            THEN
                                FOR i IN v_write_type.FIRST ..
                                         v_write_type.LAST
                                LOOP
                                    UTL_FILE.put_line (
                                        lv_write_file,
                                           v_write_type (i).order_number
                                        || '|'
                                        || v_write_type (i).line_number
                                        || '|'
                                        || v_write_type (i).item
                                        || '|'
                                        || v_write_type (i).sales_rep_name
                                        || '|'
                                        || v_write_type (i).sales_channel_code
                                        || '|'
                                        || v_write_type (i).order_type
                                        || '|'
                                        || v_write_type (i).account_number_country_state
                                        || '|'
                                        || v_write_type (i).account_number
                                        || '|'
                                        || v_write_type (i).country
                                        || '|'
                                        || v_write_type (i).state_province
                                        || '|'
                                        || v_write_type (i).region
                                        || '|'
                                        || v_write_type (i).sub_region
                                        || '|'
                                        || v_write_type (i).order_quantity
                                        || '|'
                                        || v_write_type (i).currency
                                        || '|'
                                        || v_write_type (i).unit_selling_price
                                        || '|'
                                        || v_write_type (i).order_amount
                                        || '|'
                                        || v_write_type (i).sales_date
                                        || '|'
                                        || v_write_type (i).unit_selling_price_usd
                                        || '|'
                                        || v_write_type (i).amount_usd);
                                END LOOP;
                            END IF;

                            IF (g_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            v_write_type.delete;
                            EXIT WHEN c_write%NOTFOUND;
                        END LOOP;

                        CLOSE c_write;

                        UTL_FILE.fclose (lv_write_file);
                        gc_delimiter   := CHR (9);
                        debug_msg (
                               ' End Writing into File At '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                        debug_msg (' File Name Generated :  ' || filename);
                    EXCEPTION
                        WHEN UTL_FILE.invalid_path
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_PATH: File location or filename was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_mode
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_filehandle
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_FILEHANDLE: The file handle was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_operation
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.read_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' READ_ERROR: An operating system error occurred during the read operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.write_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' WRITE_ERROR: An operating system error occurred during the write operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.internal_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INTERNAL_ERROR: An unspecified error in PL/SQL.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_filename
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' INVALID_FILENAME: The filename parameter is invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN OTHERS
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                SUBSTR (
                                       'Error while creating or writing the data into the file.'
                                    || SQLERRM,
                                    1,
                                    2000);
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                    END;
                END IF;
            END IF;
        ELSE
            lv_status   := 'E';
            g_retcode   := 1;
            g_errbuf    :=
                SUBSTR ('Error While updating the Latest Date ' || lv_msg,
                        1,
                        2000);
        END IF;


        BEGIN
            SELECT name INTO lv_instance_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_instance_name   := NULL;
        END;

        IF (lv_status = 'S' AND g_create_file = 'Y' AND p_enter_dates = 'N')
        THEN
            update_last_extract_date (g_order_type, p_region, lv_latest_update_date
                                      , lv_status, lv_msg);
            COMMIT;
        END IF;

        IF (lv_status = 'S')
        THEN
            debug_msg (
                   ' start set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            set_status ('P', NULL, filename);
            debug_msg (
                   ' End set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            COMMIT;
        END IF;

        IF (g_create_file = 'Y' AND lv_create_file_flag = 'Y')
        THEN
            IF (lv_status = 'S')
            THEN
                IF (g_send_mail = 'Y')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL, lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || ' File is generated. ' || CHR (10) || CHR (10) || '  ' || ' File Name: ' || filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            ELSE
                delete_records;

                IF (g_send_mail = 'Y')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL, lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Warning at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || '  Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);

                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            END IF;
        END IF;

        IF (g_send_mail = 'Y' AND lv_create_file_flag = 'N')
        THEN
            IF (lv_status = 'S')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' No data updates to send to O9 for ' || g_order_type || '. ' || CHR (10) || CHR (10) || '  ' || filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            ELSE
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Warning at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || '  Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);

                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;
        END IF;

        IF g_number_days_purg IS NOT NULL
        THEN
            BEGIN
                DELETE FROM
                    xxd_ont_adv_sales_order_int_t
                      WHERE     creation_date < SYSDATE - g_number_days_purg
                            AND interface_type = g_order_type;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg (
                        ' Error While Deleting The Records ' || SQLERRM);
            END;
        END IF;

        gc_delimiter   := '';
        debug_msg (
               ' End Interface '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN OTHERS
        THEN
            delete_records;
            g_errbuf       :=
                SUBSTR ('Error While Processing The file ' || SQLERRM,
                        1,
                        2000);

            IF (g_send_mail = 'Y')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Error at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || ' Interface complete in Error Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;

            g_retcode      := 2;
            gc_delimiter   := '';
            debug_msg (
                   ' End Interface '
                || ' at '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    END gross_order_prc;

    PROCEDURE open_order_prc (p_enter_dates IN VARCHAR2, p_start_date IN VARCHAR2, p_end_date IN VARCHAR2
                              , p_region IN VARCHAR2)
    AS
        CURSOR c_inst (p_open_order_start_date DATE, p_region_vl VARCHAR2)
        IS
            SELECT DISTINCT             -- Added for CCR0010166 on 18-AUG-2022
                   order_number,
                   line_number,
                   item,
                   (SELECT res.resource_name
                      FROM apps.jtf_rs_salesreps rs, apps.jtf_rs_resource_extns_vl res
                     WHERE     1 = 1
                           AND rs.resource_id = res.resource_id
                           AND rs.salesrep_id = mainq.salesrep_id
                           AND rs.org_id = mainq.org_id)
                       sales_rep_name,
                   INITCAP (NVL (sales_channel_code, 'Wholesale'))
                       sales_channel_code,
                   order_type,
                   UPPER (account_number_country_state)
                       account_number_country_state,
                   account_number,
                   UPPER (loct.country)
                       country,
                   UPPER (state_province)
                       state_province,
                   loct.region,
                   loct.sub_region,
                   order_quantity,
                   unit_selling_price,
                   order_amount,
                   request_date
                       sales_date,
                   organization_code,
                   transactional_curr_code,
                   ROUND (unit_selling_price * exchange_rate, 2)
                       unit_selling_price_usd,
                   ROUND (order_amount * exchange_rate, 2)
                       amount_usd,
                   schedule_ship_date
              FROM (SELECT /*+ use_nl leading (ool) parallel(4) */
                           ooh.header_id,
                           ooh.org_id,
                           ooh.order_number,
                           ool.line_number || '.' || ool.shipment_number
                               line_number,
                           ool.ordered_item
                               item,
                           NVL (slcnl.sales_channel_code,
                                ooh.sales_channel_code)
                               sales_channel_code,
                           TRUNC (ool.request_date)
                               request_date,
                           DECODE (
                               ooh.sales_channel_code,
                               g_sales_channel_code,    gc_ecom_customer_num
                                                     || '-'
                                                     || mc.segment1,
                               DECODE (
                                   NVL (hca.attribute1, 'XXX'),
                                   'ALL BRAND',    hca.account_number
                                                || '-'
                                                || mc.segment1,
                                   'XXX',    hca.account_number
                                          || '-'
                                          || mc.segment1,
                                   hca.account_number))
                               account_number,
                           DECODE (
                               NVL (xoalm.forecast_country, hl.country),
                               'USO', 'ZZ',
                               DECODE (
                                   xoalm.include_state_province,
                                   'Y', NVL (NVL (hl.state, hl.province),
                                             'ZZ'),
                                   'ZZ'))
                               state_province,
                           ott.name || '-' || ool.line_category_code
                               order_type,
                           (ool.ordered_quantity - NVL (ool.shipped_quantity, 0))
                               order_quantity,
                           ((ool.ordered_quantity - NVL (ool.shipped_quantity, 0)) * ool.unit_selling_price)
                               order_amount,
                           ool.unit_selling_price,
                           ooh.salesrep_id,
                           NVL (xoalm.forecast_country, hl.country)
                               country,
                           xoalm.region,
                           xoalm.sub_region,
                              DECODE (
                                  ooh.sales_channel_code,
                                  g_sales_channel_code,    gc_ecom_customer_num
                                                        || '-'
                                                        || mc.segment1,
                                  DECODE (
                                      NVL (hca.attribute1, 'XXX'),
                                      'ALL BRAND',    hca.account_number
                                                   || '-'
                                                   || mc.segment1,
                                      'XXX',    hca.account_number
                                             || '-'
                                             || mc.segment1,
                                      hca.account_number))
                           || '-'
                           || NVL (xoalm.forecast_country, hl.country)
                           || '-'
                           || DECODE (
                                  xoalm.include_state_province,
                                  'Y', NVL (NVL (hl.state, hl.province),
                                            'ZZ'),
                                  'ZZ')
                               account_number_country_state,
                           hca.cust_account_id,
                           mp.organization_code,
                           ooh.transactional_curr_code,
                           NVL (
                               (SELECT conversion_rate
                                  FROM apps.gl_daily_rates gdr
                                 WHERE     1 = 1
                                       AND gdr.from_currency =
                                           ooh.transactional_curr_code
                                       AND conversion_type =
                                           NVL (ooh.conversion_type_code,
                                                'Corporate')
                                       AND conversion_date =
                                           CASE
                                               WHEN ool.request_date <
                                                    SYSDATE
                                               THEN
                                                   TRUNC (ool.request_date)
                                               ELSE
                                                   TRUNC (SYSDATE)
                                           END
                                       AND gdr.from_currency <> 'USD'
                                       AND gdr.to_currency = 'USD'),
                               1)
                               exchange_rate,
                           TRUNC (ool.schedule_ship_date)
                               schedule_ship_date
                      FROM apps.oe_order_headers_all ooh,
                           apps.oe_order_lines_all ool,
                           apps.hz_cust_site_uses_all hcsu,
                           apps.hz_cust_acct_sites_all hcas,
                           apps.hz_party_sites hps,
                           apps.hz_locations hl,
                           apps.oe_transaction_types_tl ott,
                           apps.hz_cust_accounts hca,
                           mtl_parameters mp,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_sale_channel_code_fnc)
                           slcnl,
                           (SELECT DISTINCT country, sub_region, region,
                                            include_state_province, forecast_country, sales_channel_code
                              FROM xxd_ont_adv_loc_master_int_t) xoalm,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_invetory_org_record_fun)
                           invorg, -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           mtl_item_categories mic,
                           mtl_category_sets mcs,
                           mtl_categories_b mc
                     WHERE     1 = 1
                           AND ooh.open_flag = 'Y'
                           AND ool.open_flag = 'Y'
                           AND ooh.header_id = ool.header_id
                           AND ool.schedule_ship_date IS NOT NULL
                           AND ool.flow_Status_code NOT IN
                                   ('ENTERED', 'CANCELLED', 'INVOICED',
                                    'FULFILLED', 'CLOSED', 'SHIPPED')
                           AND ool.line_category_code = 'ORDER'
                           AND ool.request_date >= p_open_order_start_date
                           AND ool.ship_to_org_id = hcsu.site_use_id
                           AND hcsu.site_use_code = 'SHIP_TO'
                           AND hcsu.cust_acct_site_id =
                               hcas.cust_acct_site_id
                           AND hcas.party_site_id = hps.party_site_id
                           AND hps.location_id = hl.location_id
                           AND hl.country = xoalm.country
                           AND ooh.order_type_id = ott.transaction_type_id
                           AND ott.language = USERENV ('LANG')
                           AND ooh.sold_to_org_id = hca.cust_account_id
                           AND ooh.sales_channel_code =
                               slcnl.sales_channel(+)
                           AND NVL (slcnl.SALES_CHANNEL_CODE,
                                    ooh.sales_channel_code) =
                               UPPER (xoalm.sales_channel_code)
                           AND ott.name NOT IN
                                   (SELECT order_type FROM TABLE (xxd_ont_adv_sale_order_int_pkg.get_order_typs_record_fun))
                           AND ool.ship_from_org_id = mp.organization_id
                           AND xoalm.region =
                               DECODE (p_region_vl,
                                       'ALL', xoalm.region,
                                       p_region_vl)
                           --AND xoalm.region = invorg.region
                           AND mp.organization_code =
                               invorg.inv_organization_code -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           AND ool.inventory_item_id = mic.inventory_item_id
                           AND ool.ship_from_org_id = mic.organization_id
                           AND mic.category_set_id = mcs.category_set_id
                           AND mic.category_id = mc.category_id
                           AND mc.structure_id = mcs.structure_id
                           AND mcs.category_set_name = 'Inventory'
                           AND NVL (hca.attribute1, 'ALL BRAND') IN
                                   (SELECT brand
                                      FROM TABLE (xxd_ar_adv_cust_master_int_pkg.get_brand_val_fnc)
                                    UNION
                                    SELECT 'ALL BRAND' brand FROM DUAL)
                    UNION
                    SELECT /*+ use_nl leading (ool) parallel(4) */
                           ooh.header_id,
                           ooh.org_id,
                           ooh.order_number,
                           ool.line_number || '.' || ool.shipment_number
                               line_number,
                           ool.ordered_item
                               item,
                           NVL (slcnl.sales_channel_code,
                                ooh.sales_channel_code)
                               sales_channel_code,
                           TRUNC (ool.request_date)
                               request_date,
                           DECODE (
                               ooh.sales_channel_code,
                               g_sales_channel_code,    gc_ecom_customer_num
                                                     || '-'
                                                     || mc.segment1,
                               DECODE (
                                   NVL (hca.attribute1, 'XXX'),
                                   'ALL BRAND',    hca.account_number
                                                || '-'
                                                || mc.segment1,
                                   'XXX',    hca.account_number
                                          || '-'
                                          || mc.segment1,
                                   hca.account_number))
                               account_number,
                           DECODE (
                               NVL (xoalm.forecast_country, hl.country),
                               'USO', 'ZZ',
                               DECODE (
                                   xoalm.include_state_province,
                                   'Y', NVL (NVL (hl.state, hl.province),
                                             'ZZ'),
                                   'ZZ'))
                               state_province,
                           ott.name || '-' || ool.line_category_code
                               order_type,
                           (ool.ordered_quantity * -1)
                               order_quantity,
                           ((ool.ordered_quantity * -1) * ool.unit_selling_price)
                               order_amount,
                           ool.unit_selling_price,
                           ooh.salesrep_id,
                           NVL (xoalm.forecast_country, hl.country)
                               country,
                           xoalm.region,
                           xoalm.sub_region,
                              DECODE (
                                  ooh.sales_channel_code,
                                  g_sales_channel_code,    gc_ecom_customer_num
                                                        || '-'
                                                        || mc.segment1,
                                  DECODE (
                                      NVL (hca.attribute1, 'XXX'),
                                      'ALL BRAND',    hca.account_number
                                                   || '-'
                                                   || mc.segment1,
                                      'XXX',    hca.account_number
                                             || '-'
                                             || mc.segment1,
                                      hca.account_number))
                           || '-'
                           || NVL (xoalm.forecast_country, hl.country)
                           || '-'
                           || DECODE (
                                  xoalm.include_state_province,
                                  'Y', NVL (NVL (hl.state, hl.province),
                                            'ZZ'),
                                  'ZZ')
                               account_number_country_state,
                           hca.cust_account_id,
                           mp.organization_code,
                           ooh.transactional_curr_code,
                           NVL (
                               (SELECT conversion_rate
                                  FROM apps.gl_daily_rates gdr
                                 WHERE     1 = 1
                                       AND gdr.from_currency =
                                           ooh.transactional_curr_code
                                       AND conversion_type =
                                           NVL (ooh.conversion_type_code,
                                                'Corporate')
                                       AND conversion_date =
                                           CASE
                                               WHEN ool.request_date <
                                                    SYSDATE
                                               THEN
                                                   TRUNC (ool.request_date)
                                               ELSE
                                                   TRUNC (SYSDATE)
                                           END
                                       AND gdr.from_currency <> 'USD'
                                       AND gdr.to_currency = 'USD'),
                               1)
                               exchange_rate,
                           TRUNC (ool.schedule_ship_date)
                               schedule_ship_date
                      FROM apps.oe_order_headers_all ooh,
                           apps.oe_order_lines_all ool,
                           apps.hz_cust_site_uses_all hcsu,
                           apps.hz_cust_acct_sites_all hcas,
                           apps.hz_party_sites hps,
                           apps.hz_locations hl,
                           apps.oe_transaction_types_tl ott,
                           apps.hz_cust_accounts hca,
                           apps.mtl_parameters mp,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_sale_channel_code_fnc)
                           slcnl,
                           (SELECT DISTINCT country, sub_region, region,
                                            include_state_province, forecast_country, sales_channel_code
                              FROM xxd_ont_adv_loc_master_int_t) xoalm,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_invetory_org_record_fun)
                           invorg, -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           mtl_item_categories mic,
                           mtl_category_sets mcs,
                           mtl_categories_b mc
                     WHERE     1 = 1
                           AND ool.open_flag = 'Y'
                           AND ooh.open_flag = 'Y'
                           AND ooh.header_id = ool.header_id
                           AND ool.flow_Status_code NOT IN
                                   ('ENTERED', 'CANCELLED', 'INVOICED',
                                    'FULFILLED', 'CLOSED', 'SHIPPED')
                           AND ool.line_category_code = 'RETURN'
                           AND ool.request_date > p_open_order_start_date
                           AND ool.ship_to_org_id = hcsu.site_use_id
                           AND hcsu.site_use_code = 'SHIP_TO'
                           AND hcsu.cust_acct_site_id =
                               hcas.cust_acct_site_id
                           AND hcas.party_site_id = hps.party_site_id
                           AND hps.location_id = hl.location_id
                           AND hl.country = xoalm.country
                           AND ooh.order_type_id = ott.transaction_type_id
                           AND ott.language = USERENV ('LANG')
                           AND ooh.sold_to_org_id = hca.cust_account_id
                           AND ooh.sales_channel_code =
                               slcnl.sales_channel(+)
                           AND NVL (slcnl.SALES_CHANNEL_CODE,
                                    ooh.sales_channel_code) =
                               UPPER (xoalm.sales_channel_code)
                           AND ott.name NOT IN
                                   (SELECT order_type FROM TABLE (xxd_ont_adv_sale_order_int_pkg.get_order_typs_record_fun))
                           AND ool.ship_from_org_id = mp.organization_id
                           AND xoalm.region =
                               DECODE (p_region_vl,
                                       'ALL', xoalm.region,
                                       p_region_vl)
                           --AND xoalm.region = invorg.region
                           AND mp.organization_code =
                               invorg.inv_organization_code -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           AND ool.inventory_item_id = mic.inventory_item_id
                           AND ool.ship_from_org_id = mic.organization_id
                           AND mic.category_set_id = mcs.category_set_id
                           AND mic.category_id = mc.category_id
                           AND mc.structure_id = mcs.structure_id
                           AND mcs.category_set_name = 'Inventory'
                           AND NVL (hca.attribute1, 'ALL BRAND') IN
                                   (SELECT brand
                                      FROM TABLE (xxd_ar_adv_cust_master_int_pkg.get_brand_val_fnc)
                                    UNION
                                    SELECT 'ALL BRAND' brand FROM DUAL))
                   mainq,
                   (SELECT DISTINCT country, sub_region, region
                      FROM xxd_ont_adv_loc_master_int_t) loct
             WHERE mainq.country = loct.country;

        CURSOR c_write IS
              SELECT *
                FROM xxd_ont_adv_sales_order_int_t
               WHERE status = 'N' AND request_id = gn_request_id
            ORDER BY order_number, TO_NUMBER (line_number);

        TYPE xxd_ins_type IS TABLE OF c_inst%ROWTYPE;

        TYPE xxd_write_type IS TABLE OF c_write%ROWTYPE;

        v_ins_type              xxd_ins_type := xxd_ins_type ();
        v_write_type            xxd_write_type := xxd_write_type ();
        lv_write_file           UTL_FILE.file_type;
        filename                VARCHAR2 (100);
        lv_error_code           VARCHAR2 (4000) := NULL;
        ln_error_num            NUMBER;
        lv_error_msg            VARCHAR2 (4000) := NULL;
        lv_last_update_date     VARCHAR2 (200) := NULL;
        lv_latest_update_date   VARCHAR2 (200) := NULL;
        lv_status               VARCHAR2 (10) := 'S';
        lv_msg                  VARCHAR2 (4000) := NULL;
        le_bulk_inst_exe        EXCEPTION;
        lv_err_msg              VARCHAR2 (4000) := NULL;
        lv_start_date           DATE := NULL;
        lv_end_date             DATE := NULL;
        lv_param_start_date     DATE := NULL;
        lv_param_end_date       DATE := NULL;
        lv_mail_status          VARCHAR2 (200) := NULL;
        lv_mail_msg             VARCHAR2 (4000) := NULL;
        lv_instance_name        VARCHAR2 (200) := NULL;
        lv_create_file_flag     VARCHAR2 (10) := 'N';
        lv_file_path            VARCHAR2 (360) := NULL;
        lv_region               VARCHAR2 (100) := NULL;
    BEGIN
        debug_msg (
               ' Parameters Are.....'
            || CHR (10)
            || '	g_order_type	:'
            || g_order_type
            || CHR (10)
            || '	g_create_file	:'
            || g_create_file
            || CHR (10)
            || '	g_send_mail  	:'
            || g_send_mail
            || CHR (10));

        get_ecom_customer_values;
        lv_region      :=
            REGEXP_SUBSTR (p_region, '[^_]+', 1,
                           1);
        get_last_extract_date (g_order_type, p_region, lv_last_update_date,
                               lv_latest_update_date, lv_file_path, lv_status
                               , lv_msg);

        debug_msg (' request_date(TAG) :' || lv_last_update_date);

        debug_msg (
               ' Start Interface '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        IF (lv_status = 'S')
        THEN
            v_ins_type.delete;
            v_write_type.delete;
            lv_start_date   :=
                TO_DATE (lv_last_update_date, 'DD-MON-YYYY HH24:MI:SS');

            -------------------------------
            -- Insert Logic
            -------------------------------
            BEGIN
                gc_delimiter   := CHR (9);
                debug_msg (
                       ' Start Insert At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                OPEN c_inst (lv_start_date, lv_region);

                LOOP
                    FETCH c_inst BULK COLLECT INTO v_ins_type LIMIT 10000;

                    BEGIN
                        IF (g_debug_flag = 'Y')
                        THEN
                            gc_delimiter   := CHR (9) || CHR (9);
                            debug_msg (
                                   ' Start Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        END IF;

                        IF (v_ins_type.COUNT > 0)
                        THEN
                            lv_create_file_flag   := 'Y';

                            FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                              SAVE EXCEPTIONS
                                INSERT INTO xxd_ont_adv_sales_order_int_t (
                                                file_name,
                                                order_number,
                                                line_number,
                                                item,
                                                sales_rep_name,
                                                sales_channel_code,
                                                order_type,
                                                account_number_country_state,
                                                account_number,
                                                country,
                                                state_province,
                                                region,
                                                sub_region,
                                                order_quantity,
                                                unit_selling_price,
                                                order_amount,
                                                sales_date,
                                                interface_type,
                                                status,
                                                error_message,
                                                attribute1,
                                                attribute2,
                                                attribute3,
                                                attribute4,
                                                attribute5,
                                                attribute6,
                                                attribute7,
                                                attribute8,
                                                attribute9,
                                                attribute10,
                                                attribute11,
                                                attribute12,
                                                attribute13,
                                                attribute14,
                                                attribute15,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_updated_by,
                                                last_update_date,
                                                last_update_login,
                                                organization_code,
                                                unit_selling_price_usd,
                                                amount_usd,
                                                currency,
                                                schedule_ship_date)
                                         VALUES (
                                                    NULL,
                                                    v_ins_type (i).order_number,
                                                    v_ins_type (i).line_number,
                                                    v_ins_type (i).item,
                                                    v_ins_type (i).sales_rep_name,
                                                    v_ins_type (i).sales_channel_code,
                                                    v_ins_type (i).order_type,
                                                    v_ins_type (i).account_number_country_state,
                                                    v_ins_type (i).account_number,
                                                    v_ins_type (i).country,
                                                    v_ins_type (i).state_province,
                                                    v_ins_type (i).region,
                                                    v_ins_type (i).sub_region,
                                                    v_ins_type (i).order_quantity,
                                                    v_ins_type (i).unit_selling_price,
                                                    v_ins_type (i).order_amount,
                                                    v_ins_type (i).sales_date,
                                                       g_order_type
                                                    || '-'
                                                    || p_region,
                                                    'N',
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    gn_request_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    gn_user_id,
                                                    SYSDATE,
                                                    gn_login_id,
                                                    v_ins_type (i).organization_code,
                                                    v_ins_type (i).unit_selling_price_usd,
                                                    v_ins_type (i).amount_usd,
                                                    v_ins_type (i).transactional_curr_code,
                                                    v_ins_type (i).schedule_ship_date);

                            COMMIT;
                        END IF;

                        IF (g_debug_flag = 'Y')
                        THEN
                            debug_msg (
                                   ' End Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Insert into Table Item' || v_ins_type (ln_error_num).item || ' ' || lv_error_code || CHR (10)),
                                        1,
                                        4000);

                                debug_msg (lv_error_msg);
                                lv_status   := 'E';
                            END LOOP;

                            IF (g_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Insert Record Count '
                                    || v_ins_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            RAISE le_bulk_inst_exe;
                    END;

                    v_ins_type.delete;
                    EXIT WHEN c_inst%NOTFOUND;
                END LOOP;

                CLOSE c_inst;

                gc_delimiter   := CHR (9);
                debug_msg (
                       ' End Inserting At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            EXCEPTION
                WHEN le_bulk_inst_exe
                THEN
                    lv_status      := 'E';
                    set_status (
                        'E',
                        SUBSTR (
                               'Error While Bulk Inserting Into Table '
                            || SQLERRM,
                            1,
                            2000),
                        filename);

                    g_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    g_retcode      := 1;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End Inserting at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                WHEN OTHERS
                THEN
                    lv_status      := 'E';
                    set_status (
                        'E',
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000),
                        filename);

                    g_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    g_retcode      := 1;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End Inserting at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            END;

            -- --------------------------
            --  Writing to .TXT File Logic
            -- --------------------------
            IF (g_create_file = 'Y')
            THEN
                IF (lv_create_file_flag = 'Y' AND lv_status = 'S')
                THEN
                    BEGIN
                        debug_msg (RPAD ('=', 100, '='));
                        debug_msg (
                               ' Start Writing into File at '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                        IF (g_order_type = 'Open Orders')
                        THEN
                            filename   :=
                                   'DECKERS_OPEN_ORDERS_'
                                || p_region
                                || '_'
                                || TO_CHAR (SYSDATE, 'DDMONYYYY_HH24MISS')
                                || '.txt';
                        END IF;

                        EXECUTE IMMEDIATE 'alter session set nls_date_format=''YYYY/MM/DD''';

                        lv_write_file   :=
                            UTL_FILE.fopen (lv_file_path, filename, 'W');
                        UTL_FILE.put_line (
                            lv_write_file,
                            'ORDER_NUMBER|LINE_NUMBER|SKU|SALES_REP_NAME|SALES_CHANNEL|ORDER_TYPE|ACCOUNT_COUNTRY_STATE|ACCOUNT_NUMBER|COUNTRY|STATE_PROVINCE|REGION|SUB_REGION|QUANTITY|CURRENCY|UNIT_SELLING_PRICE|AMOUNT|SALES DATE|UNIT_SELLING_PRICE_USD|AMOUNT_USD|SCHEDULE_SHIP_DATE');

                        OPEN c_write;

                        LOOP
                            FETCH c_write
                                BULK COLLECT INTO v_write_type
                                LIMIT 10000;

                            IF (g_debug_flag = 'Y')
                            THEN
                                gc_delimiter   := CHR (9) || CHR (9);
                                debug_msg (
                                       ' Start Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            IF (v_write_type.COUNT > 0)
                            THEN
                                FOR i IN v_write_type.FIRST ..
                                         v_write_type.LAST
                                LOOP
                                    UTL_FILE.put_line (
                                        lv_write_file,
                                           v_write_type (i).order_number
                                        || '|'
                                        || v_write_type (i).line_number
                                        || '|'
                                        || v_write_type (i).item
                                        || '|'
                                        || v_write_type (i).sales_rep_name
                                        || '|'
                                        || v_write_type (i).sales_channel_code
                                        || '|'
                                        || v_write_type (i).order_type
                                        || '|'
                                        || v_write_type (i).account_number_country_state
                                        || '|'
                                        || v_write_type (i).account_number
                                        || '|'
                                        || v_write_type (i).country
                                        || '|'
                                        || v_write_type (i).state_province
                                        || '|'
                                        || v_write_type (i).region
                                        || '|'
                                        || v_write_type (i).sub_region
                                        || '|'
                                        || v_write_type (i).order_quantity
                                        || '|'
                                        || v_write_type (i).currency
                                        || '|'
                                        || v_write_type (i).unit_selling_price
                                        || '|'
                                        || v_write_type (i).order_amount
                                        || '|'
                                        || v_write_type (i).sales_date
                                        || '|'
                                        || v_write_type (i).unit_selling_price_usd
                                        || '|'
                                        || v_write_type (i).amount_usd
                                        || '|'
                                        || v_write_type (i).schedule_ship_date);
                                END LOOP;
                            END IF;

                            IF (g_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            v_write_type.delete;
                            EXIT WHEN c_write%NOTFOUND;
                        END LOOP;

                        CLOSE c_write;

                        UTL_FILE.fclose (lv_write_file);
                        gc_delimiter   := CHR (9);
                        debug_msg (
                               ' End Writing into File At '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                        debug_msg (' File Name Generated :  ' || filename);
                    EXCEPTION
                        WHEN UTL_FILE.invalid_path
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_PATH: File location or filename was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_mode
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_filehandle
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_FILEHANDLE: The file handle was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_operation
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.read_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' READ_ERROR: An operating system error occurred during the read operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.write_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' WRITE_ERROR: An operating system error occurred during the write operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.internal_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INTERNAL_ERROR: An unspecified error in PL/SQL.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_filename
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' INVALID_FILENAME: The filename parameter is invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN OTHERS
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                SUBSTR (
                                       'Error while creating or writing the data into the file.'
                                    || SQLERRM,
                                    1,
                                    2000);
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                    END;
                END IF;
            END IF;
        ELSE
            lv_status   := 'E';
            g_retcode   := 1;
            g_errbuf    :=
                SUBSTR ('Error While updating the Latest Date ' || lv_msg,
                        1,
                        2000);
        END IF;

        IF (lv_status = 'S')
        THEN
            debug_msg (
                   ' start set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            set_status ('P', NULL, filename);
            debug_msg (
                   ' End set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            COMMIT;
        END IF;

        BEGIN
            SELECT name INTO lv_instance_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_instance_name   := NULL;
        END;

        IF (g_create_file = 'Y' AND lv_create_file_flag = 'Y')
        THEN
            IF (lv_status = 'S')
            THEN
                IF (g_send_mail = 'Y')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL, lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || ' File is generated. ' || CHR (10) || CHR (10) || '  ' || ' File Name: ' || filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            ELSE
                delete_records;

                IF (g_send_mail = 'Y')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL, lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Warning at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || '  Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);

                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            END IF;
        END IF;

        IF (g_send_mail = 'Y' AND lv_create_file_flag = 'N')
        THEN
            IF (lv_status = 'S')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' No data updates to send to O9 for ' || g_order_type || '. ' || CHR (10) || CHR (10) || '  ' || filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            ELSE
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Warning at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || '  Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);

                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;
        END IF;

        IF g_number_days_purg IS NOT NULL
        THEN
            BEGIN
                DELETE FROM
                    xxd_ont_adv_sales_order_int_t
                      WHERE     creation_date < SYSDATE - g_number_days_purg
                            AND interface_type = g_order_type;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg (
                        ' Error While Deleting The Records ' || SQLERRM);
            END;
        END IF;

        gc_delimiter   := '';
        debug_msg (
               ' End Interface '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN OTHERS
        THEN
            delete_records;
            g_errbuf       :=
                SUBSTR ('Error While Processing The file ' || SQLERRM,
                        1,
                        2000);

            IF (g_send_mail = 'Y')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Error at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || ' Interface complete in Error Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;

            g_retcode      := 2;
            gc_delimiter   := '';
            debug_msg (
                   ' End Interface '
                || ' at '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    END open_order_prc;

    PROCEDURE shipped_order_prc (p_enter_dates IN VARCHAR2, p_start_date IN VARCHAR2, p_end_date IN VARCHAR2
                                 , p_region IN VARCHAR2)
    AS
        CURSOR c_inst (p_start_date   DATE,
                       p_end_date     DATE,
                       p_region_vl    VARCHAR2)
        IS
            SELECT DISTINCT             -- Added for CCR0010166 on 18-AUG-2022
                   order_number,
                   line_number,
                   item,
                   (SELECT res.resource_name
                      FROM apps.jtf_rs_salesreps rs, apps.jtf_rs_resource_extns_vl res
                     WHERE     1 = 1
                           AND rs.resource_id = res.resource_id
                           AND rs.salesrep_id = mainq.salesrep_id
                           AND rs.org_id = mainq.org_id)
                       sales_rep_name,
                   INITCAP (NVL (sales_channel_code, 'Wholesale'))
                       sales_channel_code,
                   org_id,
                   mainq.salesrep_id,
                   order_type,
                   UPPER (account_number_country_state)
                       account_number_country_state,
                   account_number,
                   UPPER (loct.country)
                       country,
                   UPPER (state_province)
                       state_province,
                   loct.region,
                   loct.sub_region,
                   order_quantity,
                   unit_selling_price,
                   order_amount,
                   request_date
                       sales_date,
                   organization_code,
                   transactional_curr_code,
                   ROUND (unit_selling_price * exchange_rate, 2)
                       unit_selling_price_usd,
                   ROUND (order_amount * exchange_rate, 2)
                       amount_usd
              FROM (SELECT /*+ use_nl leading (ool) parallel(4) */
                           ooh.header_id,
                           ooh.org_id,
                           ooh.order_number,
                           ool.line_number || '.' || ool.shipment_number
                               line_number,
                           ool.ordered_item
                               item,
                           NVL (slcnl.sales_channel_code,
                                ooh.sales_channel_code)
                               sales_channel_code,
                           TRUNC (ool.actual_shipment_date)
                               request_date,
                           DECODE (
                               ooh.sales_channel_code,
                               g_sales_channel_code,    gc_ecom_customer_num
                                                     || '-'
                                                     || mc.segment1,
                               DECODE (
                                   NVL (hca.attribute1, 'XXX'),
                                   'ALL BRAND',    hca.account_number
                                                || '-'
                                                || mc.segment1,
                                   'XXX',    hca.account_number
                                          || '-'
                                          || mc.segment1,
                                   hca.account_number))
                               account_number,
                           DECODE (
                               NVL (xoalm.forecast_country, hl.country),
                               'USO', 'ZZ',
                               DECODE (
                                   xoalm.include_state_province,
                                   'Y', NVL (NVL (hl.state, hl.province),
                                             'ZZ'),
                                   'ZZ'))
                               state_province,
                           ott.name || '-' || ool.line_category_code
                               order_type,
                           ool.shipped_quantity
                               order_quantity,
                           (ool.shipped_quantity * ool.unit_selling_price)
                               order_amount,
                           ool.unit_selling_price,
                           ooh.salesrep_id,
                           NVL (xoalm.forecast_country, hl.country)
                               country,
                           xoalm.region,
                           xoalm.sub_region,
                              DECODE (
                                  ooh.sales_channel_code,
                                  g_sales_channel_code,    gc_ecom_customer_num
                                                        || '-'
                                                        || mc.segment1,
                                  DECODE (
                                      NVL (hca.attribute1, 'XXX'),
                                      'ALL BRAND',    hca.account_number
                                                   || '-'
                                                   || mc.segment1,
                                      'XXX',    hca.account_number
                                             || '-'
                                             || mc.segment1,
                                      hca.account_number))
                           || '-'
                           || NVL (xoalm.forecast_country, hl.country)
                           || '-'
                           || DECODE (
                                  xoalm.include_state_province,
                                  'Y', NVL (NVL (hl.state, hl.province),
                                            'ZZ'),
                                  'ZZ')
                               account_number_country_state,
                           hca.cust_account_id,
                           mp.organization_code,
                           ooh.transactional_curr_code,
                           NVL (
                               (SELECT conversion_rate
                                  FROM apps.gl_daily_rates gdr
                                 WHERE     1 = 1
                                       AND gdr.from_currency =
                                           ooh.transactional_curr_code
                                       AND conversion_type =
                                           NVL (ooh.conversion_type_code,
                                                'Corporate')
                                       AND conversion_date =
                                           TRUNC (ool.actual_shipment_date)
                                       AND gdr.from_currency <> 'USD'
                                       AND gdr.to_currency = 'USD'),
                               1)
                               exchange_rate
                      FROM apps.oe_order_headers_all ooh,
                           apps.oe_order_lines_all ool,
                           apps.hz_cust_site_uses_all hcsu,
                           apps.hz_cust_acct_sites_all hcas,
                           apps.hz_party_sites hps,
                           apps.hz_locations hl,
                           apps.oe_transaction_types_tl ott,
                           apps.hz_cust_accounts hca,
                           apps.mtl_parameters mp,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_sale_channel_code_fnc)
                           slcnl,
                           (SELECT DISTINCT country, sub_region, region,
                                            include_state_province, forecast_country, sales_channel_code
                              FROM xxd_ont_adv_loc_master_int_t) xoalm,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_invetory_org_record_fun)
                           invorg, -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           mtl_item_categories mic,
                           mtl_category_sets mcs,
                           mtl_categories_b mc
                     WHERE     ooh.header_id = ool.header_id
                           AND ool.line_category_code = 'ORDER'
                           AND ool.last_update_date BETWEEN p_start_date
                                                        AND p_end_date
                           AND ool.ship_to_org_id = hcsu.site_use_id
                           AND hcsu.site_use_code = 'SHIP_TO'
                           AND hcsu.cust_acct_site_id =
                               hcas.cust_acct_site_id
                           AND hcas.party_site_id = hps.party_site_id
                           AND hps.location_id = hl.location_id
                           AND hl.country = xoalm.country
                           AND ooh.order_type_id = ott.transaction_type_id
                           AND ott.language = USERENV ('LANG')
                           AND ooh.sold_to_org_id = hca.cust_account_id
                           AND ool.actual_shipment_date IS NOT NULL
                           AND ool.flow_Status_code NOT IN
                                   ('ENTERED', 'CANCELLED')
                           AND ooh.sales_channel_code =
                               slcnl.sales_channel(+)
                           AND NVL (slcnl.SALES_CHANNEL_CODE,
                                    ooh.sales_channel_code) =
                               UPPER (xoalm.sales_channel_code)
                           AND ott.name NOT IN
                                   (SELECT order_type FROM TABLE (xxd_ont_adv_sale_order_int_pkg.get_order_typs_record_fun))
                           AND ool.ship_from_org_id = mp.organization_id
                           AND xoalm.region =
                               DECODE (p_region_vl,
                                       'ALL', xoalm.region,
                                       p_region_vl)
                           --AND xoalm.region = invorg.region
                           AND mp.organization_code =
                               invorg.inv_organization_code -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           AND ool.inventory_item_id = mic.inventory_item_id
                           AND ool.ship_from_org_id = mic.organization_id
                           AND mic.category_set_id = mcs.category_set_id
                           AND mic.category_id = mc.category_id
                           AND mc.structure_id = mcs.structure_id
                           AND mcs.category_set_name = 'Inventory'
                           AND NVL (hca.attribute1, 'ALL BRAND') IN
                                   (SELECT brand
                                      FROM TABLE (xxd_ar_adv_cust_master_int_pkg.get_brand_val_fnc)
                                    UNION
                                    SELECT 'ALL BRAND' brand FROM DUAL))
                   mainq,
                   (SELECT DISTINCT country, sub_region, region
                      FROM xxd_ont_adv_loc_master_int_t) loct
             WHERE mainq.country = loct.country;

        CURSOR c_write IS
              SELECT *
                FROM xxd_ont_adv_sales_order_int_t
               WHERE status = 'N' AND request_id = gn_request_id
            ORDER BY order_number, TO_NUMBER (line_number);

        TYPE xxd_ins_type IS TABLE OF c_inst%ROWTYPE;

        TYPE xxd_write_type IS TABLE OF c_write%ROWTYPE;

        v_ins_type              xxd_ins_type := xxd_ins_type ();
        v_write_type            xxd_write_type := xxd_write_type ();
        lv_write_file           UTL_FILE.file_type;
        filename                VARCHAR2 (100);
        lv_error_code           VARCHAR2 (4000) := NULL;
        ln_error_num            NUMBER;
        lv_error_msg            VARCHAR2 (4000) := NULL;
        lv_last_update_date     VARCHAR2 (200) := NULL;
        lv_latest_update_date   VARCHAR2 (200) := NULL;
        lv_status               VARCHAR2 (10) := 'S';
        lv_msg                  VARCHAR2 (4000) := NULL;
        le_bulk_inst_exe        EXCEPTION;
        lv_err_msg              VARCHAR2 (4000) := NULL;
        lv_start_date           DATE := NULL;
        lv_end_date             DATE := NULL;
        lv_param_start_date     DATE := NULL;
        lv_param_end_date       DATE := NULL;
        lv_mail_status          VARCHAR2 (200) := NULL;
        lv_mail_msg             VARCHAR2 (4000) := NULL;
        lv_instance_name        VARCHAR2 (200) := NULL;
        lv_create_file_flag     VARCHAR2 (10) := 'N';
        lv_file_path            VARCHAR2 (360) := NULL;
        lv_region               VARCHAR2 (100) := NULL;
    BEGIN
        debug_msg (
               ' Parameters Are.....'
            || CHR (10)
            || '	g_order_type	:'
            || g_order_type
            || CHR (10)
            || '	g_create_file	:'
            || g_create_file
            || CHR (10)
            || '	g_send_mail  	:'
            || g_send_mail
            || CHR (10));
        get_ecom_customer_values;
        lv_region      :=
            REGEXP_SUBSTR (p_region, '[^_]+', 1,
                           1);
        get_last_extract_date (g_order_type, p_region, lv_last_update_date,
                               lv_latest_update_date, lv_file_path, lv_status
                               , lv_msg);


        debug_msg (
               ' Start Interface '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        IF (lv_status = 'S')
        THEN
            v_ins_type.delete;
            v_write_type.delete;

            IF (p_enter_dates = 'N')
            THEN
                lv_start_date   :=
                    TO_DATE (lv_last_update_date, 'DD-MON-YYYY HH24:MI:SS');
                lv_end_date   :=
                    TO_DATE (lv_latest_update_date, 'DD-MON-YYYY HH24:MI:SS');
            ELSE
                lv_start_date   :=
                    TO_DATE (p_start_date, 'DD-MON-YYYY HH24:MI:SS');
                lv_end_date   :=
                    TO_DATE (p_end_date, 'DD-MON-YYYY HH24:MI:SS');
            END IF;

            debug_msg (' START_DATE :' || lv_start_date);
            debug_msg (' END_DATE :' || lv_end_date);

            -------------------------------
            -- Insert Logic
            -------------------------------
            BEGIN
                gc_delimiter   := CHR (9);
                debug_msg (
                       ' Start Insert At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                OPEN c_inst (lv_start_date, lv_end_date, lv_region);

                LOOP
                    FETCH c_inst BULK COLLECT INTO v_ins_type LIMIT 10000;

                    BEGIN
                        IF (g_debug_flag = 'Y')
                        THEN
                            gc_delimiter   := CHR (9) || CHR (9);
                            debug_msg (
                                   ' Start Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        END IF;

                        IF (v_ins_type.COUNT > 0)
                        THEN
                            lv_create_file_flag   := 'Y';

                            FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                              SAVE EXCEPTIONS
                                INSERT INTO xxd_ont_adv_sales_order_int_t (
                                                file_name,
                                                order_number,
                                                line_number,
                                                item,
                                                sales_rep_name,
                                                sales_channel_code,
                                                order_type,
                                                account_number_country_state,
                                                account_number,
                                                country,
                                                state_province,
                                                region,
                                                sub_region,
                                                order_quantity,
                                                unit_selling_price,
                                                order_amount,
                                                sales_date,
                                                interface_type,
                                                status,
                                                error_message,
                                                attribute1,
                                                attribute2,
                                                attribute3,
                                                attribute4,
                                                attribute5,
                                                attribute6,
                                                attribute7,
                                                attribute8,
                                                attribute9,
                                                attribute10,
                                                attribute11,
                                                attribute12,
                                                attribute13,
                                                attribute14,
                                                attribute15,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_updated_by,
                                                last_update_date,
                                                last_update_login,
                                                organization_code,
                                                unit_selling_price_usd,
                                                amount_usd,
                                                currency)
                                         VALUES (
                                                    NULL,
                                                    v_ins_type (i).order_number,
                                                    v_ins_type (i).line_number,
                                                    v_ins_type (i).item,
                                                    v_ins_type (i).sales_rep_name,
                                                    v_ins_type (i).sales_channel_code,
                                                    v_ins_type (i).order_type,
                                                    v_ins_type (i).account_number_country_state,
                                                    v_ins_type (i).account_number,
                                                    v_ins_type (i).country,
                                                    v_ins_type (i).state_province,
                                                    v_ins_type (i).region,
                                                    v_ins_type (i).sub_region,
                                                    v_ins_type (i).order_quantity,
                                                    v_ins_type (i).unit_selling_price,
                                                    v_ins_type (i).order_amount,
                                                    v_ins_type (i).sales_date,
                                                       g_order_type
                                                    || '-'
                                                    || p_region,
                                                    'N',
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    gn_request_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    gn_user_id,
                                                    SYSDATE,
                                                    gn_login_id,
                                                    v_ins_type (i).organization_code,
                                                    v_ins_type (i).unit_selling_price_usd,
                                                    v_ins_type (i).amount_usd,
                                                    v_ins_type (i).transactional_curr_code);

                            COMMIT;
                        END IF;

                        IF (g_debug_flag = 'Y')
                        THEN
                            debug_msg (
                                   ' End Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Insert into Table Item' || v_ins_type (ln_error_num).item || ' ' || lv_error_code || CHR (10)),
                                        1,
                                        4000);

                                debug_msg (lv_error_msg);
                                lv_status   := 'E';
                            END LOOP;

                            IF (g_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Insert Record Count '
                                    || v_ins_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            RAISE le_bulk_inst_exe;
                    END;

                    v_ins_type.delete;
                    EXIT WHEN c_inst%NOTFOUND;
                END LOOP;

                CLOSE c_inst;

                gc_delimiter   := CHR (9);
                debug_msg (
                       ' End Inserting At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            EXCEPTION
                WHEN le_bulk_inst_exe
                THEN
                    lv_status      := 'E';
                    set_status (
                        'E',
                        SUBSTR (
                               'Error While Bulk Inserting Into Table '
                            || SQLERRM,
                            1,
                            2000),
                        filename);

                    g_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    g_retcode      := 1;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End Inserting at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                WHEN OTHERS
                THEN
                    lv_status      := 'E';
                    set_status (
                        'E',
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000),
                        filename);

                    g_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    g_retcode      := 1;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End Inserting at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            END;

            -- --------------------------
            --  Writing to .TXT File Logic
            -- --------------------------
            IF (g_create_file = 'Y')
            THEN
                IF (lv_create_file_flag = 'Y' AND lv_status = 'S')
                THEN
                    BEGIN
                        debug_msg (RPAD ('=', 100, '='));
                        debug_msg (
                               ' Start Writing into File at '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                        IF (g_order_type = 'Shipment Orders')
                        THEN
                            filename   :=
                                   'DECKERS_SHIPMENT_ORDERS_'
                                || p_region
                                || '_'
                                || TO_CHAR (SYSDATE, 'DDMONYYYY_HH24MISS')
                                || '.txt';
                        END IF;

                        EXECUTE IMMEDIATE 'alter session set nls_date_format=''YYYY/MM/DD''';

                        lv_write_file   :=
                            UTL_FILE.fopen (lv_file_path, filename, 'W');
                        UTL_FILE.put_line (
                            lv_write_file,
                            'ORDER_NUMBER|LINE_NUMBER|SKU|SALES_REP_NAME|SALES_CHANNEL|ORDER_TYPE|ACCOUNT_COUNTRY_STATE|ACCOUNT_NUMBER|COUNTRY|STATE_PROVINCE|REGION|SUB_REGION|QUANTITY|CURRENCY|UNIT_SELLING_PRICE|AMOUNT|SALES DATE|UNIT_SELLING_PRICE_USD|AMOUNT_USD');

                        OPEN c_write;

                        LOOP
                            FETCH c_write
                                BULK COLLECT INTO v_write_type
                                LIMIT 10000;

                            IF (g_debug_flag = 'Y')
                            THEN
                                gc_delimiter   := CHR (9) || CHR (9);
                                debug_msg (
                                       ' Start Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            IF (v_write_type.COUNT > 0)
                            THEN
                                FOR i IN v_write_type.FIRST ..
                                         v_write_type.LAST
                                LOOP
                                    UTL_FILE.put_line (
                                        lv_write_file,
                                           v_write_type (i).order_number
                                        || '|'
                                        || v_write_type (i).line_number
                                        || '|'
                                        || v_write_type (i).item
                                        || '|'
                                        || v_write_type (i).sales_rep_name
                                        || '|'
                                        || v_write_type (i).sales_channel_code
                                        || '|'
                                        || v_write_type (i).order_type
                                        || '|'
                                        || v_write_type (i).account_number_country_state
                                        || '|'
                                        || v_write_type (i).account_number
                                        || '|'
                                        || v_write_type (i).country
                                        || '|'
                                        || v_write_type (i).state_province
                                        || '|'
                                        || v_write_type (i).region
                                        || '|'
                                        || v_write_type (i).sub_region
                                        || '|'
                                        || v_write_type (i).order_quantity
                                        || '|'
                                        || v_write_type (i).currency
                                        || '|'
                                        || v_write_type (i).unit_selling_price
                                        || '|'
                                        || v_write_type (i).order_amount
                                        || '|'
                                        || v_write_type (i).sales_date
                                        || '|'
                                        || v_write_type (i).unit_selling_price_usd
                                        || '|'
                                        || v_write_type (i).amount_usd);
                                END LOOP;
                            END IF;

                            IF (g_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            v_write_type.delete;
                            EXIT WHEN c_write%NOTFOUND;
                        END LOOP;

                        CLOSE c_write;

                        UTL_FILE.fclose (lv_write_file);
                        gc_delimiter   := CHR (9);
                        debug_msg (
                               ' End Writing into File At '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                        debug_msg (' File Name Generated :  ' || filename);
                    EXCEPTION
                        WHEN UTL_FILE.invalid_path
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_PATH: File location or filename was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_mode
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_filehandle
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_FILEHANDLE: The file handle was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_operation
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.read_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' READ_ERROR: An operating system error occurred during the read operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.write_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' WRITE_ERROR: An operating system error occurred during the write operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.internal_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INTERNAL_ERROR: An unspecified error in PL/SQL.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_filename
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' INVALID_FILENAME: The filename parameter is invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN OTHERS
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                SUBSTR (
                                       'Error while creating or writing the data into the file.'
                                    || SQLERRM,
                                    1,
                                    2000);
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                    END;
                END IF;
            END IF;
        ELSE
            lv_status   := 'E';
            g_retcode   := 1;
            g_errbuf    :=
                SUBSTR ('Error While updating the Latest Date ' || lv_msg,
                        1,
                        2000);
        END IF;


        BEGIN
            SELECT name INTO lv_instance_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_instance_name   := NULL;
        END;

        IF (lv_status = 'S' AND g_create_file = 'Y' AND p_enter_dates = 'N')
        THEN
            update_last_extract_date (g_order_type, p_region, lv_latest_update_date
                                      , lv_status, lv_msg);
            COMMIT;
        END IF;

        IF (lv_status = 'S')
        THEN
            debug_msg (
                   ' start set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            set_status ('P', NULL, filename);
            debug_msg (
                   ' End set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            COMMIT;
        END IF;

        BEGIN
            IF (g_create_file = 'Y' AND lv_create_file_flag = 'Y')
            THEN
                IF (lv_status = 'S')
                THEN
                    IF (g_send_mail = 'Y')
                    THEN
                        XXDO_MAIL_PKG.send_mail (
                            'Erp@deckers.com',
                            g_email_id,
                            NULL,
                               lv_instance_name
                            || ' - Deckers O9 '
                            || g_order_type
                            || ' Interface Completed at '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'),
                               ' Hi,'
                            || CHR (10)
                            || CHR (10)
                            || ' Deckers O9 '
                            || g_order_type
                            || ' File is generated. '
                            || CHR (10)
                            || CHR (10)
                            || '  '
                            || ' File Name: '
                            || filename
                            || CHR (10)
                            || CHR (10)
                            || ' Sincerely,'
                            || CHR (10)
                            || ' Planning IT Team',
                            NULL,
                            lv_mail_status,
                            lv_mail_msg);
                        debug_msg (
                               ' Mail Status '
                            || lv_mail_status
                            || ' Mail Message '
                            || lv_mail_msg);
                    END IF;
                ELSE
                    delete_records;

                    IF (g_send_mail = 'Y')
                    THEN
                        XXDO_MAIL_PKG.send_mail (
                            'Erp@deckers.com',
                            g_email_id,
                            NULL,
                               lv_instance_name
                            || ' - Deckers O9 '
                            || g_order_type
                            || ' Interface Completed in Warning at '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'),
                               ' Hi,'
                            || CHR (10)
                            || CHR (10)
                            || ' Deckers O9 '
                            || g_order_type
                            || '  Interface complete in Warning Please check log file of request id: '
                            || gn_request_id
                            || ' for details '
                            || CHR (10)
                            || CHR (10)
                            || ' Sincerely,'
                            || CHR (10)
                            || ' Planning IT Team',
                            NULL,
                            lv_mail_status,
                            lv_mail_msg);
                        debug_msg (
                               ' Mail Status '
                            || lv_mail_status
                            || ' Mail Message '
                            || lv_mail_msg);
                    END IF;
                END IF;
            END IF;

            IF (g_send_mail = 'Y' AND lv_create_file_flag = 'N')
            THEN
                IF (lv_status = 'S')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL, lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' No data updates to send to O9 for ' || g_order_type || '. ' || CHR (10) || CHR (10) || '  ' || filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                ELSE
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL, lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Warning at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || '  Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_msg ('Mail issue ' || SQLERRM);
        END;

        IF g_number_days_purg IS NOT NULL
        THEN
            BEGIN
                DELETE FROM
                    xxd_ont_adv_sales_order_int_t
                      WHERE     creation_date < SYSDATE - g_number_days_purg
                            AND interface_type = g_order_type;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg (
                        ' Error While Deleting The Records ' || SQLERRM);
            END;
        END IF;

        gc_delimiter   := '';
        debug_msg (
               ' End Interface '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN OTHERS
        THEN
            delete_records;
            g_errbuf       :=
                SUBSTR ('Error While Processing The file ' || SQLERRM,
                        1,
                        2000);

            IF (g_send_mail = 'Y')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Error at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || ' Interface complete in Error Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;

            g_retcode      := 2;
            gc_delimiter   := '';
            debug_msg (
                   ' End Interface '
                || ' at '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    END shipped_order_prc;

    PROCEDURE unscheduled_order_prc (p_enter_dates IN VARCHAR2, p_start_date IN VARCHAR2, p_end_date IN VARCHAR2
                                     , p_region IN VARCHAR2)
    AS
        CURSOR c_inst (p_unsch_request_date DATE, p_region_vl VARCHAR2)
        IS
            SELECT DISTINCT             -- Added for CCR0010166 on 18-AUG-2022
                   order_number,
                   line_number,
                   item,
                   (SELECT res.resource_name
                      FROM apps.jtf_rs_salesreps rs, apps.jtf_rs_resource_extns_vl res
                     WHERE     1 = 1
                           AND rs.resource_id = res.resource_id
                           AND rs.salesrep_id = mainq.salesrep_id
                           AND rs.org_id = mainq.org_id)
                       sales_rep_name,
                   INITCAP (NVL (sales_channel_code, 'Wholesale'))
                       sales_channel_code,
                   org_id,
                   mainq.salesrep_id,
                   order_type,
                   UPPER (account_number_country_state)
                       account_number_country_state,
                   account_number,
                   UPPER (loct.country)
                       country,
                   UPPER (state_province)
                       state_province,
                   loct.region,
                   loct.sub_region,
                   order_quantity,
                   unit_selling_price,
                   order_amount,
                   request_date
                       sales_date,
                   organization_code,
                   transactional_curr_code,
                   ROUND (unit_selling_price * exchange_rate, 2)
                       unit_selling_price_usd,
                   ROUND (order_amount * exchange_rate, 2)
                       amount_usd
              FROM (SELECT /*+ use_nl leading (ool) parallel(4) */
                           ooh.header_id,
                           ooh.org_id,
                           ooh.order_number,
                           ool.line_number || '.' || ool.shipment_number
                               line_number,
                           ool.ordered_item
                               item,
                           NVL (slcnl.sales_channel_code,
                                ooh.sales_channel_code)
                               sales_channel_code,
                           TRUNC (ool.request_date)
                               request_date,
                           DECODE (
                               ooh.sales_channel_code,
                               g_sales_channel_code,    gc_ecom_customer_num
                                                     || '-'
                                                     || mc.segment1,
                               DECODE (
                                   NVL (hca.attribute1, 'XXX'),
                                   'ALL BRAND',    hca.account_number
                                                || '-'
                                                || mc.segment1,
                                   'XXX',    hca.account_number
                                          || '-'
                                          || mc.segment1,
                                   hca.account_number))
                               account_number,
                           DECODE (
                               NVL (xoalm.forecast_country, hl.country),
                               'USO', 'ZZ',
                               DECODE (
                                   xoalm.include_state_province,
                                   'Y', NVL (NVL (hl.state, hl.province),
                                             'ZZ'),
                                   'ZZ'))
                               state_province,
                           ott.name || '-' || ool.line_category_code
                               order_type,
                           ool.ordered_quantity
                               order_quantity,
                           (ool.ordered_quantity * ool.unit_selling_price)
                               order_amount,
                           ool.unit_selling_price,
                           ooh.salesrep_id,
                           NVL (xoalm.forecast_country, hl.country)
                               country,
                           xoalm.region,
                           xoalm.sub_region,
                              DECODE (
                                  ooh.sales_channel_code,
                                  g_sales_channel_code,    gc_ecom_customer_num
                                                        || '-'
                                                        || mc.segment1,
                                  DECODE (
                                      NVL (hca.attribute1, 'XXX'),
                                      'ALL BRAND',    hca.account_number
                                                   || '-'
                                                   || mc.segment1,
                                      'XXX',    hca.account_number
                                             || '-'
                                             || mc.segment1,
                                      hca.account_number))
                           || '-'
                           || NVL (xoalm.forecast_country, hl.country)
                           || '-'
                           || DECODE (
                                  xoalm.include_state_province,
                                  'Y', NVL (NVL (hl.state, hl.province),
                                            'ZZ'),
                                  'ZZ')
                               account_number_country_state,
                           hca.cust_account_id,
                           mp.organization_code,
                           ooh.transactional_curr_code,
                           NVL (
                               (SELECT conversion_rate
                                  FROM apps.gl_daily_rates gdr
                                 WHERE     1 = 1
                                       AND gdr.from_currency =
                                           ooh.transactional_curr_code
                                       AND conversion_type =
                                           NVL (ooh.conversion_type_code,
                                                'Corporate')
                                       AND conversion_date =
                                           CASE
                                               WHEN ool.request_date <
                                                    SYSDATE
                                               THEN
                                                   TRUNC (ool.request_date)
                                               ELSE
                                                   TRUNC (SYSDATE)
                                           END
                                       AND gdr.from_currency <> 'USD'
                                       AND gdr.to_currency = 'USD'),
                               1)
                               exchange_rate
                      FROM apps.oe_order_headers_all ooh,
                           apps.oe_order_lines_all ool,
                           apps.hz_cust_site_uses_all hcsu,
                           apps.hz_cust_acct_sites_all hcas,
                           apps.hz_party_sites hps,
                           apps.hz_locations hl,
                           apps.oe_transaction_types_tl ott,
                           apps.hz_cust_accounts hca,
                           apps.mtl_parameters mp,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_sale_channel_code_fnc)
                           slcnl,
                           (SELECT DISTINCT country, sub_region, region,
                                            include_state_province, forecast_country, sales_channel_code
                              FROM xxd_ont_adv_loc_master_int_t) xoalm,
                           TABLE (
                               xxd_ont_adv_sale_order_int_pkg.get_invetory_org_record_fun)
                           invorg, -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           mtl_item_categories mic,
                           mtl_category_sets mcs,
                           mtl_categories_b mc
                     WHERE     ooh.header_id = ool.header_id
                           AND ool.line_category_code = 'ORDER'
                           AND ool.open_flag = 'Y'
                           AND ooh.open_flag = 'Y'
                           AND ool.request_date > p_unsch_request_date
                           AND ool.ship_to_org_id = hcsu.site_use_id
                           AND hcsu.site_use_code = 'SHIP_TO'
                           AND hcsu.cust_acct_site_id =
                               hcas.cust_acct_site_id
                           AND hcas.party_site_id = hps.party_site_id
                           AND hps.location_id = hl.location_id
                           AND hl.country = xoalm.country
                           AND ooh.order_type_id = ott.transaction_type_id
                           AND ott.language = USERENV ('LANG')
                           AND ooh.sold_to_org_id = hca.cust_account_id
                           AND ool.schedule_ship_date IS NULL
                           AND ool.flow_Status_code NOT IN
                                   ('ENTERED', 'CANCELLED', 'INVOICED',
                                    'FULFILLED', 'CLOSED', 'SHIPPED')
                           AND ooh.sales_channel_code =
                               slcnl.sales_channel(+)
                           AND NVL (slcnl.SALES_CHANNEL_CODE,
                                    ooh.sales_channel_code) =
                               UPPER (xoalm.sales_channel_code)
                           AND ott.name NOT IN
                                   (SELECT order_type FROM TABLE (xxd_ont_adv_sale_order_int_pkg.get_order_typs_record_fun))
                           AND ool.ship_from_org_id = mp.organization_id
                           AND xoalm.region =
                               DECODE (p_region_vl,
                                       'ALL', xoalm.region,
                                       p_region_vl)
                           --AND xoalm.region = invorg.region
                           AND mp.organization_code =
                               invorg.inv_organization_code -- Uncommented for CCR0010146 on 03AUG2022 Ver 1.2
                           AND ool.inventory_item_id = mic.inventory_item_id
                           AND ool.ship_from_org_id = mic.organization_id
                           AND mic.category_set_id = mcs.category_set_id
                           AND mic.category_id = mc.category_id
                           AND mc.structure_id = mcs.structure_id
                           AND mcs.category_set_name = 'Inventory'
                           AND NVL (hca.attribute1, 'ALL BRAND') IN
                                   (SELECT brand
                                      FROM TABLE (xxd_ar_adv_cust_master_int_pkg.get_brand_val_fnc)
                                    UNION
                                    SELECT 'ALL BRAND' brand FROM DUAL))
                   mainq,
                   (SELECT DISTINCT country, sub_region, region
                      FROM xxd_ont_adv_loc_master_int_t) loct
             WHERE mainq.country = loct.country;

        CURSOR c_write IS
              SELECT *
                FROM xxdo.xxd_ont_adv_sales_order_int_t
               WHERE status = 'N' AND request_id = gn_request_id
            ORDER BY order_number, TO_NUMBER (line_number);

        TYPE xxd_ins_type IS TABLE OF c_inst%ROWTYPE;

        TYPE xxd_write_type IS TABLE OF c_write%ROWTYPE;

        v_ins_type              xxd_ins_type := xxd_ins_type ();
        v_write_type            xxd_write_type := xxd_write_type ();
        lv_write_file           UTL_FILE.file_type;
        filename                VARCHAR2 (100);
        lv_error_code           VARCHAR2 (4000) := NULL;
        ln_error_num            NUMBER;
        lv_error_msg            VARCHAR2 (4000) := NULL;
        lv_last_update_date     VARCHAR2 (200) := NULL;
        lv_latest_update_date   VARCHAR2 (200) := NULL;
        lv_status               VARCHAR2 (10) := 'S';
        lv_msg                  VARCHAR2 (4000) := NULL;
        le_bulk_inst_exe        EXCEPTION;
        lv_err_msg              VARCHAR2 (4000) := NULL;
        lv_start_date           DATE := NULL;
        lv_end_date             DATE := NULL;
        lv_param_start_date     DATE := NULL;
        lv_param_end_date       DATE := NULL;
        lv_mail_status          VARCHAR2 (200) := NULL;
        lv_mail_msg             VARCHAR2 (4000) := NULL;
        lv_instance_name        VARCHAR2 (200) := NULL;
        lv_create_file_flag     VARCHAR2 (10) := 'N';
        lv_file_path            VARCHAR2 (360) := NULL;
        lv_region               VARCHAR2 (100) := NULL;
    BEGIN
        debug_msg (
               ' Parameters Are.....'
            || CHR (10)
            || '	g_order_type	:'
            || g_order_type
            || CHR (10)
            || '	g_create_file	:'
            || g_create_file
            || CHR (10)
            || '	g_send_mail  	:'
            || g_send_mail
            || CHR (10));
        get_ecom_customer_values;
        lv_region      :=
            REGEXP_SUBSTR (p_region, '[^_]+', 1,
                           1);
        get_last_extract_date (g_order_type, p_region, lv_last_update_date,
                               lv_latest_update_date, lv_file_path, lv_status
                               , lv_msg);

        debug_msg (' REQUEST_DATE (TAG) :' || lv_last_update_date);

        debug_msg (
               ' Start Interface '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        IF (lv_status = 'S')
        THEN
            v_ins_type.delete;
            v_write_type.delete;
            lv_start_date   :=
                TO_DATE (lv_last_update_date, 'DD-MON-YYYY HH24:MI:SS');
            lv_end_date   :=
                TO_DATE (lv_latest_update_date, 'DD-MON-YYYY HH24:MI:SS');

            -------------------------------
            -- Insert Logic
            -------------------------------
            BEGIN
                gc_delimiter   := CHR (9);
                debug_msg (
                       ' Start Insert At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                OPEN c_inst (lv_start_date, lv_region);

                LOOP
                    FETCH c_inst BULK COLLECT INTO v_ins_type LIMIT 10000;

                    BEGIN
                        IF (g_debug_flag = 'Y')
                        THEN
                            gc_delimiter   := CHR (9) || CHR (9);
                            debug_msg (
                                   ' Start Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        END IF;

                        IF (v_ins_type.COUNT > 0)
                        THEN
                            lv_create_file_flag   := 'Y';

                            FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                              SAVE EXCEPTIONS
                                INSERT INTO xxd_ont_adv_sales_order_int_t (
                                                file_name,
                                                order_number,
                                                line_number,
                                                item,
                                                sales_rep_name,
                                                sales_channel_code,
                                                order_type,
                                                account_number_country_state,
                                                account_number,
                                                country,
                                                state_province,
                                                region,
                                                sub_region,
                                                order_quantity,
                                                unit_selling_price,
                                                order_amount,
                                                sales_date,
                                                interface_type,
                                                status,
                                                error_message,
                                                attribute1,
                                                attribute2,
                                                attribute3,
                                                attribute4,
                                                attribute5,
                                                attribute6,
                                                attribute7,
                                                attribute8,
                                                attribute9,
                                                attribute10,
                                                attribute11,
                                                attribute12,
                                                attribute13,
                                                attribute14,
                                                attribute15,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_updated_by,
                                                last_update_date,
                                                last_update_login,
                                                organization_code,
                                                unit_selling_price_usd,
                                                amount_usd,
                                                currency)
                                         VALUES (
                                                    NULL,
                                                    v_ins_type (i).order_number,
                                                    v_ins_type (i).line_number,
                                                    v_ins_type (i).item,
                                                    v_ins_type (i).sales_rep_name,
                                                    v_ins_type (i).sales_channel_code,
                                                    v_ins_type (i).order_type,
                                                    v_ins_type (i).account_number_country_state,
                                                    v_ins_type (i).account_number,
                                                    v_ins_type (i).country,
                                                    v_ins_type (i).state_province,
                                                    v_ins_type (i).region,
                                                    v_ins_type (i).sub_region,
                                                    v_ins_type (i).order_quantity,
                                                    v_ins_type (i).unit_selling_price,
                                                    v_ins_type (i).order_amount,
                                                    v_ins_type (i).sales_date,
                                                       g_order_type
                                                    || '-'
                                                    || p_region,
                                                    'N',
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    gn_request_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    gn_user_id,
                                                    SYSDATE,
                                                    gn_login_id,
                                                    v_ins_type (i).organization_code,
                                                    v_ins_type (i).unit_selling_price_usd,
                                                    v_ins_type (i).amount_usd,
                                                    v_ins_type (i).transactional_curr_code);

                            COMMIT;
                        END IF;

                        IF (g_debug_flag = 'Y')
                        THEN
                            debug_msg (
                                   ' End Insert Record Count '
                                || v_ins_type.COUNT
                                || ' at '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Insert into Table Item' || v_ins_type (ln_error_num).item || ' ' || lv_error_code || CHR (10)),
                                        1,
                                        4000);

                                debug_msg (lv_error_msg);
                                lv_status   := 'E';
                            END LOOP;

                            IF (g_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Insert Record Count '
                                    || v_ins_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            RAISE le_bulk_inst_exe;
                    END;

                    v_ins_type.delete;
                    EXIT WHEN c_inst%NOTFOUND;
                END LOOP;

                CLOSE c_inst;

                gc_delimiter   := CHR (9);
                debug_msg (
                       ' End Inserting At '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            EXCEPTION
                WHEN le_bulk_inst_exe
                THEN
                    lv_status      := 'E';
                    set_status (
                        'E',
                        SUBSTR (
                               'Error While Bulk Inserting Into Table '
                            || SQLERRM,
                            1,
                            2000),
                        filename);

                    g_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    g_retcode      := 1;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End Inserting at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                WHEN OTHERS
                THEN
                    lv_status      := 'E';
                    set_status (
                        'E',
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000),
                        filename);

                    g_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    g_retcode      := 1;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End Inserting at '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            END;

            -- --------------------------
            --  Writing to .TXT File Logic
            -- --------------------------
            IF (g_create_file = 'Y')
            THEN
                IF (lv_create_file_flag = 'Y' AND lv_status = 'S')
                THEN
                    BEGIN
                        debug_msg (RPAD ('=', 100, '='));
                        debug_msg (
                               ' Start Writing into File at '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                        IF (g_order_type = 'Unscheduled Orders')
                        THEN
                            filename   :=
                                   'DECKERS_UNSCHEDULED_ORDERS_'
                                || p_region
                                || '_'
                                || TO_CHAR (SYSDATE, 'DDMONYYYY_HH24MISS')
                                || '.txt';
                        END IF;

                        EXECUTE IMMEDIATE 'alter session set nls_date_format=''YYYY/MM/DD''';

                        lv_write_file   :=
                            UTL_FILE.fopen (lv_file_path, filename, 'W');
                        UTL_FILE.put_line (
                            lv_write_file,
                            'ORDER_NUMBER|LINE_NUMBER|SKU|SALES_REP_NAME|SALES_CHANNEL|ORDER_TYPE|ACCOUNT_COUNTRY_STATE|ACCOUNT_NUMBER|COUNTRY|STATE_PROVINCE|REGION|SUB_REGION|QUANTITY|CURRENCY|UNIT_SELLING_PRICE|AMOUNT|SALES DATE|UNIT_SELLING_PRICE_USD|AMOUNT_USD');

                        OPEN c_write;

                        LOOP
                            FETCH c_write
                                BULK COLLECT INTO v_write_type
                                LIMIT 10000;

                            IF (g_debug_flag = 'Y')
                            THEN
                                gc_delimiter   := CHR (9) || CHR (9);
                                debug_msg (
                                       ' Start Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            IF (v_write_type.COUNT > 0)
                            THEN
                                FOR i IN v_write_type.FIRST ..
                                         v_write_type.LAST
                                LOOP
                                    UTL_FILE.put_line (
                                        lv_write_file,
                                           v_write_type (i).order_number
                                        || '|'
                                        || v_write_type (i).line_number
                                        || '|'
                                        || v_write_type (i).item
                                        || '|'
                                        || v_write_type (i).sales_rep_name
                                        || '|'
                                        || v_write_type (i).sales_channel_code
                                        || '|'
                                        || v_write_type (i).order_type
                                        || '|'
                                        || v_write_type (i).account_number_country_state
                                        || '|'
                                        || v_write_type (i).account_number
                                        || '|'
                                        || v_write_type (i).country
                                        || '|'
                                        || v_write_type (i).state_province
                                        || '|'
                                        || v_write_type (i).region
                                        || '|'
                                        || v_write_type (i).sub_region
                                        || '|'
                                        || v_write_type (i).order_quantity
                                        || '|'
                                        || v_write_type (i).currency
                                        || '|'
                                        || v_write_type (i).unit_selling_price
                                        || '|'
                                        || v_write_type (i).order_amount
                                        || '|'
                                        || v_write_type (i).sales_date
                                        || '|'
                                        || v_write_type (i).unit_selling_price_usd
                                        || '|'
                                        || v_write_type (i).amount_usd);
                                END LOOP;
                            END IF;

                            IF (g_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            v_write_type.delete;
                            EXIT WHEN c_write%NOTFOUND;
                        END LOOP;

                        CLOSE c_write;

                        UTL_FILE.fclose (lv_write_file);
                        gc_delimiter   := CHR (9);
                        debug_msg (
                               ' End Writing into File At '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                        debug_msg (' File Name Generated :  ' || filename);
                    EXCEPTION
                        WHEN UTL_FILE.invalid_path
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_PATH: File location or filename was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_mode
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_filehandle
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_FILEHANDLE: The file handle was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_operation
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.read_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' READ_ERROR: An operating system error occurred during the read operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.write_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' WRITE_ERROR: An operating system error occurred during the write operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.internal_error
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                'INTERNAL_ERROR: An unspecified error in PL/SQL.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN UTL_FILE.invalid_filename
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' INVALID_FILENAME: The filename parameter is invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                        WHEN OTHERS
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                SUBSTR (
                                       'Error while creating or writing the data into the file.'
                                    || SQLERRM,
                                    1,
                                    2000);
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            g_retcode      := 1;
                            g_errbuf       := lv_err_msg;
                            gc_delimiter   := CHR (9);
                            debug_msg (
                                   ' End Writing into File At '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-YYYY HH24:MI:SS AM'));
                    END;
                END IF;
            END IF;
        ELSE
            lv_status   := 'E';
            g_retcode   := 1;
            g_errbuf    :=
                SUBSTR ('Error While updating the Latest Date ' || lv_msg,
                        1,
                        2000);
        END IF;


        BEGIN
            SELECT name INTO lv_instance_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_instance_name   := NULL;
        END;

        IF (lv_status = 'S')
        THEN
            debug_msg (
                   ' start set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            set_status ('P', NULL, filename);
            debug_msg (
                   ' End set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            COMMIT;
        END IF;

        IF (g_create_file = 'Y' AND lv_create_file_flag = 'Y')
        THEN
            IF (lv_status = 'S')
            THEN
                IF (g_send_mail = 'Y')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL, lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || ' File is generated. ' || CHR (10) || CHR (10) || '  ' || ' File Name: ' || filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            ELSE
                delete_records;

                IF (g_send_mail = 'Y')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL, lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Warning at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || '  Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);

                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            END IF;
        END IF;

        IF (g_send_mail = 'Y' AND lv_create_file_flag = 'N')
        THEN
            IF (lv_status = 'S')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' No data updates to send to O9 for ' || g_order_type || '. ' || CHR (10) || CHR (10) || '  ' || filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            ELSE
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Warning at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || '  Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);

                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;
        END IF;

        IF g_number_days_purg IS NOT NULL
        THEN
            BEGIN
                DELETE FROM
                    xxd_ont_adv_sales_order_int_t
                      WHERE     creation_date < SYSDATE - g_number_days_purg
                            AND interface_type = g_order_type;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg (
                        ' Error While Deleting The Records ' || SQLERRM);
            END;
        END IF;

        gc_delimiter   := '';
        debug_msg (
               ' End Interface '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    EXCEPTION
        WHEN OTHERS
        THEN
            delete_records;
            g_errbuf       :=
                SUBSTR ('Error While Processing The file ' || SQLERRM,
                        1,
                        2000);

            IF (g_send_mail = 'Y')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', g_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 ' || g_order_type || ' Interface Completed in Error at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 ' || g_order_type || ' Interface complete in Error Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;

            g_retcode      := 2;
            gc_delimiter   := '';
            debug_msg (
                   ' End Interface '
                || ' at '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    END unscheduled_order_prc;

    -- ======================================================================================
    -- This Main procedure to collect the data and generate the .CSV file
    -- ======================================================================================

    PROCEDURE xxd_ont_sales_order_int_prc (
        x_errbuf                OUT NOCOPY VARCHAR2,
        x_retcode               OUT NOCOPY VARCHAR2,
        p_order_type         IN            VARCHAR2,
        p_region             IN            VARCHAR2,
        p_create_file        IN            VARCHAR2,
        p_send_mail          IN            VARCHAR2,
        p_dummy_email        IN            VARCHAR2,
        p_email_id           IN            VARCHAR2,
        p_number_days_purg   IN            NUMBER,
        p_enter_dates        IN            VARCHAR2,
        p_dummy_val          IN            VARCHAR2,
        p_start_date         IN            VARCHAR2,
        p_end_date           IN            VARCHAR2,
        p_debug_flag         IN            VARCHAR2)
    AS
    BEGIN
        g_order_type         := p_order_type;
        g_create_file        := p_create_file;
        g_send_mail          := p_send_mail;
        g_email_id           := p_email_id;
        g_debug_flag         := p_debug_flag;

        BEGIN
            SELECT inv_organization_code
              INTO g_inv_org_code
              FROM TABLE (xxd_ont_adv_sale_order_int_pkg.get_invetory_org_record_fun)
             WHERE region = 'ALL';
        EXCEPTION
            WHEN OTHERS
            THEN
                g_inv_org_code   := NULL;
        END;

        BEGIN
            SELECT MEANING
              INTO XXDO_MAIL_PKG.pv_smtp_host
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_COMMON_MAIL_DTLS_LKP'
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE) >= SYSDATE
                   AND NVL (enabled_flag, 'N') = 'Y'
                   AND language = USERENV ('LANG')
                   AND LOOKUP_CODE = 'SMTP_HOST';

            SELECT MEANING
              INTO XXDO_MAIL_PKG.pv_smtp_port
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_COMMON_MAIL_DTLS_LKP'
                   AND NVL (start_date_active, SYSDATE) <= SYSDATE
                   AND NVL (end_date_active, SYSDATE) >= SYSDATE
                   AND NVL (enabled_flag, 'N') = 'Y'
                   AND language = USERENV ('LANG')
                   AND LOOKUP_CODE = 'SMTP_PORT';

            XXDO_MAIL_PKG.pv_smtp_domain   := NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        g_number_days_purg   := p_number_days_purg;
        gc_delimiter         := '';

        debug_msg (
               ' Main Procedure Start '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        IF (p_order_type = 'Gross Orders')
        THEN
            gross_order_prc (p_enter_dates, p_start_date, p_end_date,
                             p_region);
        ELSIF (p_order_type = 'Open Orders')
        THEN
            open_order_prc (p_enter_dates, p_start_date, p_end_date,
                            p_region);
        ELSIF (p_order_type = 'Shipment Orders')
        THEN
            shipped_order_prc (p_enter_dates, p_start_date, p_end_date,
                               p_region);
        ELSIF (p_order_type = 'Unscheduled Orders')
        THEN
            Unscheduled_order_prc (p_enter_dates, p_start_date, p_end_date,
                                   p_region);
        END IF;

        gc_delimiter         := '';
        debug_msg (
               ' Main Procedure End '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        x_errbuf             := g_errbuf;
        x_retcode            := g_retcode;
    EXCEPTION
        WHEN OTHERS
        THEN
            g_retcode      := 2;
            gc_delimiter   := '';
            debug_msg (' Final Exception  ' || SQLERRM);
    END xxd_ont_sales_order_int_prc;
END xxd_ont_adv_sale_order_int_pkg;
/
