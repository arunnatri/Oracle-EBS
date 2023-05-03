--
-- XXD_AR_ADV_CUST_MASTER_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_ADV_CUST_MASTER_INT_PKG"
AS
    /****************************************************************************************
    * Package      : xxd_ar_adv_cust_master_int_pkg
    * Design       : This package will be used as Customer Outbound Interface
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 29-Apr-2021  1.0        Balavenu Rao        Initial Version (CCR0009135)
    ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================

    gn_user_id                    NUMBER := fnd_global.user_id;
    gn_login_id                   NUMBER := fnd_global.login_id;
    gn_request_id                 NUMBER := fnd_global.conc_request_id;
    gc_debug_enable               VARCHAR2 (1);
    gc_delimiter                  VARCHAR2 (100);
    gc_ecom_customer_num          VARCHAR2 (100) := NULL;
    gc_ecom_customer              VARCHAR2 (200) := NULL;
    gc_ecom_brand_partner_group   VARCHAR2 (200) := NULL;

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

    PROCEDURE set_status (p_status     IN VARCHAR2,
                          p_err_msg    IN VARCHAR2,
                          p_filename   IN VARCHAR2)
    AS
    BEGIN
        BEGIN
            UPDATE xxdo.xxd_ar_adv_cust_master_int_t
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
            DELETE FROM xxdo.xxd_ar_adv_cust_master_int_t
                  WHERE request_id = gn_request_id;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_msg ('Error While Deleting From Table: ' || SQLERRM);
        END;
    END delete_records;

    PROCEDURE get_last_extract_date (p_interface_name IN VARCHAR2, p_last_update_date OUT VARCHAR2, p_latest_update_date OUT VARCHAR2
                                     , p_file_path OUT VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        --Retrive Last Update Date
        SELECT tag
          INTO p_last_update_date
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_PO_O9_INTERFACES_LKP'
               AND lookup_code = p_interface_name
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE
               AND NVL (enabled_flag, 'N') = 'Y'
               AND language = USERENV ('LANG');

        -- Retrive File Path Location
        SELECT meaning
          INTO p_file_path
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_PO_O9_INTERFACES_LKP'
               AND lookup_code = 'FILE_PATH_MASTER_DATA'
               AND NVL (start_date_active, SYSDATE) <= SYSDATE
               AND NVL (end_date_active, SYSDATE) >= SYSDATE
               AND NVL (enabled_flag, 'N') = 'Y'
               AND language = USERENV ('LANG');

        p_latest_update_date   := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS');
        x_status               := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status               := 'E';
            x_message              := SUBSTR (SQLERRM, 1, 2000);
            p_last_update_date     := NULL;
            p_latest_update_date   := NULL;
    END get_last_extract_date;

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

        BEGIN
            SELECT attribute19
              INTO gc_ecom_brand_partner_group
              FROM hz_cust_accounts
             WHERE account_number = gc_ecom_customer_num;
        EXCEPTION
            WHEN OTHERS
            THEN
                gc_ecom_brand_partner_group   := NULL;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END get_ecom_customer_values;

    PROCEDURE update_last_extract_date (p_interface_name IN VARCHAR2, p_latest_update_date IN VARCHAR2, x_status OUT NOCOPY VARCHAR2
                                        , x_message OUT NOCOPY VARCHAR2)
    IS
        CURSOR c1 IS
            SELECT lookup_type, lookup_code, enabled_flag,
                   security_group_id, view_application_id, tag,
                   meaning
              FROM fnd_lookup_values_vl
             WHERE     lookup_type = 'XXD_PO_O9_INTERFACES_LKP'
                   AND lookup_code = p_interface_name
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
                    x_attribute_category    => NULL,
                    x_attribute1            => NULL,
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
                    x_last_update_date      => SYSDATE,
                    x_last_updated_by       => fnd_global.user_id,
                    x_last_update_login     => fnd_global.user_id);

                COMMIT;
                x_status   := 'S';
                debug_msg (i.lookup_code || ' Lookup has been Updated');
                debug_msg (' stard_date(description) :' || i.tag);
                debug_msg (
                    ' end_date(tag)           :' || p_latest_update_date);
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
            debug_msg (' Exception While Updating Lookup  ' || x_message);
    END update_last_extract_date;

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
            debug_msg (
                'Others Exception in get_country_values_fnc = ' || SQLERRM);
            NULL;
    END get_country_values_fnc;

    FUNCTION get_sales_region_values_fnc
        RETURN sales_region_record_tbl
        PIPELINED
    IS
        l_sales_region_record_tbl   sales_region_record_rec;
    BEGIN
        FOR l_sales_region_record_tbl
            IN (SELECT tag, attribute1, attribute2,
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
                       AND lookup_type = 'XXD_PO_O9_COUNTR_SALES_RGN_MAP')
        LOOP
            PIPE ROW (l_sales_region_record_tbl);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg (
                   'Others Exception in get_sales_region_values_fnc = '
                || SQLERRM);
    END get_sales_region_values_fnc;

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
            debug_msg (
                'Others Exception in get_sale_channel_code_fnc = ' || SQLERRM);
            NULL;
    END get_sale_channel_code_fnc;

    FUNCTION get_parent_act_record_fnc
        RETURN parent_act_record_tbl
        PIPELINED
    IS
        l_parent_act_record_tbl   parent_act_record_rec;
    BEGIN
        FOR l_parent_act_record_tbl
            IN (SELECT meaning, description, tag
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
                       AND lookup_type = 'XXD_O9_DROPSHIP_PARENT_ACT_LKP')
        LOOP
            PIPE ROW (l_parent_act_record_tbl);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg (
                'Others Exception in get_parent_act_record_fnc = ' || SQLERRM);
            NULL;
    END get_parent_act_record_fnc;

    FUNCTION get_brand_val_fnc
        RETURN brand_tbl
        PIPELINED
    IS
        l_brand_tbl   brand_rec;
    BEGIN
        FOR l_brand_tbl
            IN (SELECT meaning
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
                       AND lookup_type = 'XXD_ONT_O9_BRANDS_LKP')
        LOOP
            PIPE ROW (l_brand_tbl);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in get_brand_val_fnc = ' || SQLERRM);
            NULL;
    END get_brand_val_fnc;

    -- ======================================================================================
    -- This Main procedure to collect the data and generate the .CSV file
    -- ======================================================================================

    PROCEDURE customer_master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_create_file IN VARCHAR2, p_send_mail IN VARCHAR2, p_dummy_email IN VARCHAR2, p_email_id IN VARCHAR2, p_number_days_purg IN NUMBER, p_enter_dates IN VARCHAR2, p_dummy_val IN VARCHAR2
                                   , p_start_date IN VARCHAR2, p_end_date IN VARCHAR2, p_debug_flag IN VARCHAR2)
    AS
        CURSOR c_inst1 (p_start_date DATE, p_end_date DATE)
        IS
              SELECT account_number, account_name, country,
                     sub_region, region, sales_channel_code,
                     state_province, brand_partner_group, forecast_region,
                     accountnumber_country_state, add_country || '-' || DECODE (sales_channel_code, 'E-COMMERCE', gc_ecom_brand_partner_group, NVL (brand_partner_group, 'NONE')) country_brand_partner_group, parent_account_number,
                     parent_account_name
                FROM (  SELECT account_number,
                               NVL (
                                   (SELECT account_name
                                      FROM hz_cust_accounts
                                     WHERE account_number = main_q.account_number),
                                   main_q.account_number)
                                   account_name,
                               UPPER (
                                   DECODE (
                                       include_brand_in_country,
                                       'Y',    main_q.country
                                            || '-'
                                            || mst_account_brand,
                                       main_q.country))
                                   country,
                               main_q.country
                                   add_country,
                               xoalmit.sub_region,
                               xoalmit.region,
                               INITCAP (
                                   NVL (main_q.sales_channel_code, 'Wholesale'))
                                   sales_channel_code,
                               UPPER (state_province)
                                   state_province,
                               NVL (
                                   (SELECT attribute19
                                      FROM hz_cust_accounts
                                     WHERE account_number = main_q.account_number),
                                   'NONE')
                                   brand_partner_group,
                               xoalmit.forecast_region,
                               UPPER (accountnumber_country_state)
                                   accountnumber_country_state,
                               xpa.parent_account_number,
                               xpa.parent_account_name,
                               main_q.mst_account_brand
                          FROM (  SELECT /*+ use_nl leading (hcaa) parallel(4) */
                                         hcaa.account_number, NVL (hcaa.account_name, hp.party_name) account_name, NVL (xoalm.forecast_country, hl.country) country,
                                         xoalm.sub_region, xoalm.region, NVL (slcnl.sales_channel_code, hcaa.sales_channel_code) sales_channel_code,
                                         DECODE (NVL (xoalm.forecast_country, hl.country), 'USO', 'ZZ', DECODE (xoalm.include_state_province, 'Y', NVL (NVL (hl.state, hl.province), 'ZZ'), 'ZZ')) state_province, hcaa.attribute19 brand_partner_group, hcaa.attribute1 mst_account_brand,
                                         hcaa.account_number || '-' || NVL (xoalm.forecast_country, hl.country) || '-' || DECODE (NVL (xoalm.forecast_country, hl.country), 'USO', 'ZZ', DECODE (xoalm.include_state_province, 'Y', NVL (NVL (hl.state, hl.province), 'ZZ'), 'ZZ')) accountnumber_country_state
                                    FROM hz_cust_accounts hcaa,
                                         hz_cust_acct_sites_all hcass,
                                         hz_cust_site_uses_all hcsuas,
                                         hz_parties hp,
                                         hz_party_sites hps,
                                         hz_locations hl,
                                         (SELECT DISTINCT country, sub_region, region,
                                                          include_state_province, forecast_country, sales_channel_code
                                            FROM xxd_ont_adv_loc_master_int_t)
                                         xoalm,
                                         TABLE (
                                             xxd_ar_adv_cust_master_int_pkg.get_sale_channel_code_fnc)
                                         slcnl
                                   WHERE     1 = 1
                                         AND hcaa.attribute18 IS NULL
                                         AND hcaa.cust_account_id =
                                             hcass.cust_account_id
                                         AND hcass.cust_acct_site_id =
                                             hcsuas.cust_acct_site_id
                                         --                          AND hcsuas.site_use_code = 'SHIP_TO'
                                         AND hcaa.party_id = hp.party_id
                                         AND hp.party_id = hps.party_id
                                         AND hcass.party_site_id =
                                             hps.party_site_id
                                         AND hps.location_id = hl.location_id
                                         AND hl.country = xoalm.country
                                         AND hcaa.sales_channel_code =
                                             slcnl.SALES_CHANNEL(+)
                                         AND NVL (slcnl.SALES_CHANNEL_CODE,
                                                  hcaa.sales_channel_code) =
                                             UPPER (xoalm.sales_channel_code)
                                         AND ((hcaa.last_update_date BETWEEN p_start_date AND p_end_date) OR (hcass.last_update_date BETWEEN p_start_date AND p_end_date))
                                         AND NVL (hcaa.attribute1, 'ALL BRAND') <>
                                             'ALL BRAND'
                                         AND hcaa.status = 'A'
                                         AND hcass.status = 'A'
                                         AND hcsuas.status = 'A'
                                         AND NVL (hcaa.attribute1, 'ALL BRAND') IN
                                                 (SELECT BRAND FROM TABLE (xxd_ar_adv_cust_master_int_pkg.get_brand_val_fnc))
                                GROUP BY hcaa.account_number, NVL (hcaa.account_name, hp.party_name), NVL (xoalm.forecast_country, hl.country),
                                         xoalm.sub_region, xoalm.region, hcaa.attribute1,
                                         NVL (slcnl.sales_channel_code, hcaa.sales_channel_code), DECODE (NVL (xoalm.forecast_country, hl.country), 'USO', 'ZZ', DECODE (xoalm.include_state_province, 'Y', NVL (NVL (hl.state, hl.province), 'ZZ'), 'ZZ')), hcaa.attribute19
                                UNION
                                  SELECT /*+ use_nl leading (hcaa) parallel(4) */
                                         hcaa.account_number, NVL (hcaa.account_name, hp.party_name) account_name, NVL (xoalm.forecast_country, hl.country) country,
                                         xoalm.sub_region, xoalm.region, NVL (slcnl.sales_channel_code, hcaa.sales_channel_code) sales_channel_code,
                                         DECODE (NVL (xoalm.forecast_country, hl.country), 'USO', 'ZZ', DECODE (xoalm.include_state_province, 'Y', NVL (NVL (hl.state, hl.province), 'ZZ'), 'ZZ')) state_province, hcaa.attribute19 brand_partner_group, hcaa.attribute1 mst_account_brand,
                                         hcaa.account_number || '-' || NVL (xoalm.forecast_country, hl.country) || '-' || DECODE (NVL (xoalm.forecast_country, hl.country), 'USO', 'ZZ', DECODE (xoalm.include_state_province, 'Y', NVL (NVL (hl.state, hl.province), 'ZZ'), 'ZZ')) accountnumber_country_state
                                    FROM hz_cust_accounts hcaa,
                                         hz_cust_acct_sites_all hcasb,
                                         hz_cust_site_uses_all hcsuab,
                                         hz_cust_acct_sites_all hcass,
                                         hz_cust_site_uses_all hcsuas,
                                         hz_cust_acct_relate_all hcara,
                                         hz_parties hp,
                                         hz_party_sites hps,
                                         hz_locations hl,
                                         (SELECT DISTINCT country, sub_region, region,
                                                          include_state_province, forecast_country, sales_channel_code
                                            FROM xxdo.xxd_ont_adv_loc_master_int_t)
                                         xoalm,
                                         TABLE (
                                             xxd_ar_adv_cust_master_int_pkg.get_sale_channel_code_fnc)
                                         slcnl
                                   WHERE     1 = 1
                                         AND hcaa.cust_account_id =
                                             hcasb.cust_account_id
                                         AND hcsuab.cust_acct_site_id =
                                             hcasb.cust_acct_site_id
                                         AND hcaa.attribute18 IS NULL
                                         AND hcsuab.site_use_code = 'BILL_TO'
                                         AND hcaa.cust_account_id =
                                             hcara.cust_account_id
                                         AND hcara.related_cust_account_id =
                                             hcass.cust_account_id
                                         AND hcass.cust_acct_site_id =
                                             hcsuas.cust_acct_site_id
                                         AND hcsuas.site_use_code = 'SHIP_TO'
                                         AND hcaa.party_id = hp.party_id
                                         AND hp.party_id = hps.party_id
                                         AND hcass.party_site_id =
                                             hps.party_site_id
                                         AND hps.location_id = hl.location_id
                                         AND hl.country = xoalm.country
                                         AND hcaa.status = 'A'
                                         AND hcass.status = 'A'
                                         AND hcsuas.status = 'A'
                                         AND NVL (hcaa.attribute1, 'ALL BRAND') IN
                                                 (SELECT BRAND FROM TABLE (xxd_ar_adv_cust_master_int_pkg.get_brand_val_fnc))
                                         AND hcaa.sales_channel_code =
                                             slcnl.sales_channel(+)
                                         AND NVL (slcnl.SALES_CHANNEL_CODE,
                                                  hcaa.sales_channel_code) =
                                             UPPER (xoalm.sales_channel_code)
                                         AND ((hcaa.last_update_date BETWEEN p_start_date AND p_end_date) OR (hcasb.last_update_date BETWEEN p_start_date AND p_end_date))
                                GROUP BY hcaa.account_number, NVL (hcaa.account_name, hp.party_name), NVL (xoalm.forecast_country, hl.country),
                                         xoalm.sub_region, xoalm.region, hcaa.attribute1,
                                         NVL (slcnl.sales_channel_code, hcaa.sales_channel_code), DECODE (NVL (xoalm.forecast_country, hl.country), 'USO', 'ZZ', DECODE (xoalm.include_state_province, 'Y', NVL (NVL (hl.state, hl.province), 'ZZ'), 'ZZ')), hcaa.attribute19
                                UNION
                                  SELECT /*+ use_nl leading (ool) parallel(4) */
                                         DECODE (hca.sales_channel_code, 'E-COMMERCE', gc_ecom_customer_num || '-' || mc.segment1, DECODE (NVL (hca.attribute1, 'ALL BRAND'), 'ALL BRAND', hca.account_number || '-' || mc.segment1, hca.account_number)) account_number, DECODE (hca.sales_channel_code, 'E-COMMERCE', gc_ecom_customer, hca.account_name) account_name, NVL (xoalm.forecast_country, hl.country) country,
                                         xoalm.sub_region, xoalm.region, DECODE (hca.sales_channel_code, 'E-COMMERCE', 'E-COMMERCE', NVL (slcnl.sales_channel_code, hca.sales_channel_code)) sales_channel_code,
                                         DECODE (NVL (xoalm.forecast_country, hl.country), 'USO', 'ZZ', DECODE (xoalm.include_state_province, 'Y', NVL (NVL (hl.state, hl.province), 'ZZ'), 'ZZ')) state_province, DECODE (hca.sales_channel_code, 'E-COMMERCE', gc_ecom_brand_partner_group, NVL (hca.attribute19, 'NONE')) brand_partner_group, mc.segment1 mst_account_brand,
                                         DECODE (hca.sales_channel_code, 'E-COMMERCE', gc_ecom_customer_num || '-' || mc.segment1, DECODE (NVL (hca.attribute1, 'ALL BRAND'), 'ALL BRAND', hca.account_number || '-' || mc.segment1, hca.account_number)) || '-' || NVL (xoalm.forecast_country, hl.country) || '-' || DECODE (NVL (xoalm.forecast_country, hl.country), 'USO', 'ZZ', DECODE (xoalm.include_state_province, 'Y', NVL (NVL (hl.state, hl.province), 'ZZ'), 'ZZ')) accountnumber_country_state
                                    FROM apps.oe_order_headers_all ooh,
                                         apps.oe_order_lines_all ool,
                                         apps.hz_cust_accounts hca,
                                         apps.hz_cust_site_uses_all hcsu,
                                         apps.hz_cust_acct_sites_all hcas,
                                         apps.hz_party_sites hps,
                                         apps.hz_locations hl,
                                         (SELECT DISTINCT country, sub_region, region,
                                                          include_state_province, forecast_country, sales_channel_code
                                            FROM xxd_ont_adv_loc_master_int_t)
                                         xoalm,
                                         mtl_item_categories mic,
                                         mtl_category_sets mcs,
                                         mtl_categories_b mc,
                                         TABLE (
                                             xxd_ar_adv_cust_master_int_pkg.get_sale_channel_code_fnc)
                                         slcnl
                                   WHERE     ooh.header_id = ool.header_id
                                         AND ool.ship_to_org_id = hcsu.site_use_id
                                         AND hcsu.cust_acct_site_id =
                                             hcas.cust_acct_site_id
                                         --                                       AND hcas.cust_account_id =
                                         --                                           hca.cust_account_id
                                         AND ooh.sold_to_org_id =
                                             hca.cust_account_id
                                         AND hcas.party_site_id = hps.party_site_id
                                         AND hps.location_id = hl.location_id
                                         AND (   ooh.sales_channel_code =
                                                 'E-COMMERCE'
                                              OR NVL (hca.attribute1, 'ALL BRAND') IN
                                                     (SELECT brand
                                                        FROM TABLE (xxd_ar_adv_cust_master_int_pkg.get_brand_val_fnc)
                                                      UNION
                                                      SELECT 'ALL BRAND' brand
                                                        FROM DUAL))
                                         AND ool.flow_status_code NOT IN
                                                 ('ENTERED', 'CANCELLED')
                                         AND ool.last_update_date BETWEEN p_start_date
                                                                      AND p_end_date
                                         AND hl.country = xoalm.country
                                         AND ool.inventory_item_id =
                                             mic.inventory_item_id
                                         AND ool.ship_from_org_id =
                                             mic.organization_id
                                         AND mic.category_set_id =
                                             mcs.category_set_id
                                         AND mic.category_id = mc.category_id
                                         AND mc.structure_id = mcs.structure_id
                                         AND mcs.category_set_name = 'Inventory'
                                         AND hca.sales_channel_code =
                                             slcnl.SALES_CHANNEL(+)
                                         AND NVL (slcnl.SALES_CHANNEL_CODE,
                                                  hca.sales_channel_code) =
                                             UPPER (xoalm.sales_channel_code)
                                GROUP BY DECODE (hca.sales_channel_code, 'E-COMMERCE', gc_ecom_customer_num || '-' || mc.segment1, DECODE (NVL (hca.attribute1, 'ALL BRAND'), 'ALL BRAND', hca.account_number || '-' || mc.segment1, hca.account_number)), DECODE (hca.sales_channel_code, 'E-COMMERCE', gc_ecom_customer, hca.account_name), DECODE (hca.sales_channel_code, 'E-COMMERCE', 'E-COMMERCE', NVL (slcnl.sales_channel_code, hca.sales_channel_code)),
                                         NVL (xoalm.forecast_country, hl.country), DECODE (NVL (xoalm.forecast_country, hl.country), 'USO', 'ZZ', DECODE (xoalm.include_state_province, 'Y', NVL (NVL (hl.state, hl.province), 'ZZ'), 'ZZ')), DECODE (hca.sales_channel_code, 'E-COMMERCE', gc_ecom_brand_partner_group, NVL (hca.attribute19, 'NONE')),
                                         xoalm.sub_region, xoalm.region, mc.segment1)
                               main_q,
                               xxd_ont_adv_loc_master_int_t xoalmit,
                               TABLE (
                                   xxd_ar_adv_cust_master_int_pkg.get_parent_act_record_fnc)
                               xpa
                         WHERE     1 = 1
                               AND main_q.country = xoalmit.country
                               AND main_q.mst_account_brand =
                                   NVL (xoalmit.brand(+),
                                        main_q.mst_account_brand)
                               AND NVL (main_q.sales_channel_code, 'WHOLESALE') =
                                   UPPER (
                                       NVL (xoalmit.sales_channel_code(+),
                                            main_q.sales_channel_code))
                               AND main_q.account_number = xpa.customer_number(+)
                      GROUP BY account_number, UPPER (DECODE (include_brand_in_country, 'Y', main_q.country || '-' || mst_account_brand, main_q.country)), main_q.country,
                               xoalmit.sub_region, xoalmit.region, INITCAP (NVL (main_q.sales_channel_code, 'Wholesale')),
                               UPPER (state_province), xoalmit.forecast_region, UPPER (accountnumber_country_state),
                               xpa.parent_account_number, xpa.parent_account_name, main_q.mst_account_brand)
            GROUP BY account_number, account_name, country,
                     sub_region, region, sales_channel_code,
                     state_province, brand_partner_group, forecast_region,
                     accountnumber_country_state, add_country || '-' || DECODE (sales_channel_code, 'E-COMMERCE', gc_ecom_brand_partner_group, NVL (brand_partner_group, 'NONE')), parent_account_number,
                     parent_account_name;



        CURSOR c_write IS
            SELECT *
              FROM xxdo.xxd_ar_adv_cust_master_int_t
             WHERE status = 'N' AND request_id = gn_request_id;

        TYPE xxd_ins_type IS TABLE OF c_inst1%ROWTYPE;

        TYPE xxd_write_type IS TABLE OF c_write%ROWTYPE;

        v_ins_type                 xxd_ins_type := xxd_ins_type ();
        v_write_type               xxd_write_type := xxd_write_type ();
        lv_write_file              UTL_FILE.file_type;
        lv_filename                VARCHAR2 (100);
        lv_error_code              VARCHAR2 (4000) := NULL;
        ln_error_num               NUMBER;
        lv_error_msg               VARCHAR2 (4000) := NULL;
        lv_last_update_date        VARCHAR2 (200) := NULL;
        lv_latest_update_date      VARCHAR2 (200) := NULL;
        lv_status                  VARCHAR2 (10) := 'S';
        lv_msg                     VARCHAR2 (4000) := NULL;
        le_bulk_inst_exe           EXCEPTION;
        lv_err_msg                 VARCHAR2 (4000) := NULL;
        lv_start_date              DATE := NULL;
        lv_end_date                DATE := NULL;
        lv_mail_status             VARCHAR2 (200) := NULL;
        lv_mail_msg                VARCHAR2 (4000) := NULL;
        lv_instance_name           VARCHAR2 (200) := NULL;
        lv_create_file_flag        VARCHAR2 (10) := 'N';
        lv_file_path               VARCHAR2 (360) := NULL;
        lv_forecast_region_val     VARCHAR2 (10) := 'S';
        ln_forecast_region_count   NUMBER;
        lv_brand                   VARCHAR2 (100) := NULL;
    BEGIN
        debug_msg (
               ' Parameters Are.....'
            || CHR (10)
            || '    p_create_file    :'
            || p_create_file
            || CHR (10)
            || '    p_send_mail      :'
            || p_send_mail
            || CHR (10));

        BEGIN
            SELECT name INTO lv_instance_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_instance_name   := NULL;
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

        get_last_extract_date ('CUSTOMER', lv_last_update_date, lv_latest_update_date
                               , lv_file_path, lv_status, lv_msg);
        get_ecom_customer_values;

        debug_msg (
               ' Start Interface '
            || ' at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        -------------------------------
        -- Insert Logic
        -------------------------------
        v_ins_type.DELETE;
        v_write_type.DELETE;

        IF (lv_status = 'S')
        THEN
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

            BEGIN
                gc_delimiter   := CHR (9);
                debug_msg (
                       ' Start Insert At'
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                OPEN c_inst1 (lv_start_date, lv_end_date);

                LOOP
                    FETCH c_inst1 BULK COLLECT INTO v_ins_type LIMIT 10000;

                    BEGIN
                        IF (p_debug_flag = 'Y')
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
                                INSERT INTO xxdo.xxd_ar_adv_cust_master_int_t (
                                                file_name,
                                                account_number,
                                                account_name,
                                                country,
                                                sub_region,
                                                region,
                                                sales_channel_code,
                                                state_province,
                                                brand_partner_group,
                                                forecast_region,
                                                accountnumber_country_state,
                                                parent_account_number,
                                                parent_account_name,
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
                                                country_brand_partner_group)
                                         VALUES (
                                                    NULL,
                                                    v_ins_type (i).account_number,
                                                    v_ins_type (i).account_name,
                                                    v_ins_type (i).country,
                                                    v_ins_type (i).sub_region,
                                                    v_ins_type (i).region,
                                                    v_ins_type (i).sales_channel_code,
                                                    v_ins_type (i).state_province,
                                                    v_ins_type (i).brand_partner_group,
                                                    v_ins_type (i).forecast_region,
                                                    v_ins_type (i).accountnumber_country_state,
                                                    v_ins_type (i).parent_account_number,
                                                    v_ins_type (i).parent_account_name,
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
                                                    v_ins_type (i).country_brand_partner_group);

                            COMMIT;
                        END IF;

                        IF (p_debug_flag = 'Y')
                        THEN
                            gc_delimiter   := CHR (9) || CHR (9);
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
                                        (lv_error_msg || ' Error While Insert into Table ' || v_ins_type (ln_error_num).account_number || ' ' || lv_error_code || CHR (10)),
                                        1,
                                        4000);
                                debug_msg (lv_error_msg);
                            END LOOP;

                            IF (p_debug_flag = 'Y')
                            THEN
                                gc_delimiter   := CHR (9) || CHR (9);
                                debug_msg (
                                       ' End Insert Record Count '
                                    || v_ins_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            RAISE le_bulk_inst_exe;
                    END;

                    v_ins_type.DELETE;
                    EXIT WHEN c_inst1%NOTFOUND;
                END LOOP;

                CLOSE c_inst1;

                gc_delimiter   := CHR (9);
                debug_msg (
                       ' End Inserting at '
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
                        lv_filename);

                    x_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    x_retcode      := 1;
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
                        lv_filename);

                    x_errbuf       :=
                        SUBSTR (
                            'Error While Inserting Into Table ' || SQLERRM,
                            1,
                            2000);
                    x_retcode      := 2;
                    gc_delimiter   := CHR (9);
                    debug_msg (' Error While Inserting ' || SQLERRM);
                    debug_msg (
                           ' End OF Inserting '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            END;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_forecast_region_count
                  FROM xxd_ar_adv_cust_master_int_t
                 WHERE     status = 'N'
                       AND request_id = gn_request_id
                       AND forecast_region IS NULL;

                IF (ln_forecast_region_count > 0)
                THEN
                    UPDATE xxdo.xxd_ar_adv_cust_master_int_t
                       SET status = 'E', error_message = 'Forecast Region not Exists in Location Master'
                     WHERE     status = 'N'
                           AND request_id = gn_request_id
                           AND forecast_region IS NULL;

                    lv_forecast_region_val   := 'E';
                    x_retcode                := 1;
                END IF;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg (
                        'Error While Updating Record Status ' || SQLERRM);
                    lv_forecast_region_val   := NULL;
            END;

            --    --------------------------
            --     Writing to .CSV Logic
            --    --------------------------
            IF (p_create_file = 'Y' AND lv_status = 'S')
            THEN
                IF (lv_create_file_flag = 'Y')
                THEN
                    BEGIN
                        debug_msg (RPAD ('=', 100, '='));
                        debug_msg (
                               ' Start Writing into File At '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                        lv_filename    :=
                               'DECKERS_CUSTOMER_MASTER_'
                            || TO_CHAR (SYSDATE, 'DDMONYY_HH24MISS')
                            || '.txt';

                        EXECUTE IMMEDIATE 'alter session set nls_date_format=''YYYY/MM/DD''';

                        lv_write_file   :=
                            UTL_FILE.fopen (lv_file_path, lv_filename, 'W');
                        UTL_FILE.put_line (
                            lv_write_file,
                            'ACCOUNT_NUMBER|ACCOUNT_NAME|COUNTRY|SUBREGION|REGION|SALES_CHANNEL_CODE|STATE/PROVINCE|BRAND_PARTNER_GROUP|FORECAST_REGION|ACCOUNTNUMBER_COUNTRY_STATE|COUNTRY_BRAND_PARTNER_GROUP|PARENT_ACCOUNT_NUMBER|PARENT_ACCOUNT_NAME');


                        OPEN c_write;

                        LOOP
                            FETCH c_write
                                BULK COLLECT INTO v_write_type
                                LIMIT 10000;

                            --BEGIN
                            IF (p_debug_flag = 'Y')
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
                                           v_write_type (i).account_number
                                        || '|'
                                        || v_write_type (i).account_name
                                        || '|'
                                        || v_write_type (i).country
                                        || '|'
                                        || v_write_type (i).sub_region
                                        || '|'
                                        || v_write_type (i).region
                                        || '|'
                                        || v_write_type (i).sales_channel_code
                                        || '|'
                                        || v_write_type (i).state_province
                                        || '|'
                                        || v_write_type (i).brand_partner_group
                                        || '|'
                                        || v_write_type (i).forecast_region
                                        || '|'
                                        || v_write_type (i).accountnumber_country_state
                                        || '|'
                                        || v_write_type (i).country_brand_partner_group
                                        || '|'
                                        || v_write_type (i).parent_account_number
                                        || '|'
                                        || v_write_type (i).parent_account_name);
                                END LOOP;
                            END IF;

                            IF (p_debug_flag = 'Y')
                            THEN
                                debug_msg (
                                       ' End Writing into file  Record Count '
                                    || v_write_type.COUNT
                                    || ' at '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-YYYY HH24:MI:SS AM'));
                            END IF;

                            v_write_type.DELETE;
                            EXIT WHEN c_write%NOTFOUND;
                        END LOOP;

                        CLOSE c_write;

                        UTL_FILE.fclose (lv_write_file);
                        gc_delimiter   := CHR (9);
                        debug_msg (
                               ' End Writing into File At '
                            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                        debug_msg (' File Name Generated :  ' || lv_filename);
                    EXCEPTION
                        WHEN UTL_FILE.invalid_path
                        THEN
                            IF UTL_FILE.is_open (lv_write_file)
                            THEN
                                UTL_FILE.fclose (lv_write_file);
                            END IF;

                            lv_err_msg     :=
                                ' INVALID_PATH: File location or filename was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
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
                                ' INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
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
                                ' INVALID_FILEHANDLE: The file handle was invalid.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
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
                                ' INVALID_OPERATION: The file could not be opened or operated on as requested.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
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
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
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
                                'WRITE_ERROR: An operating system error occurred during the write operation.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
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
                                ' INTERNAL_ERROR: An unspecified error in PL/SQL.';
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
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
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
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
                                       ' Error while creating or writing the data into the file.'
                                    || SQLERRM,
                                    1,
                                    2000);
                            debug_msg (lv_err_msg);
                            lv_status      := 'E';
                            x_retcode      := 1;
                            x_errbuf       := lv_err_msg;
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
            x_retcode   := 1;
            x_errbuf    :=
                SUBSTR ('Error While updating the Latest Date ' || lv_msg,
                        1,
                        2000);
        END IF;

        debug_msg (' Before lookup update ' || lv_status);

        IF (lv_status = 'S' AND p_create_file = 'Y' AND p_enter_dates = 'N')
        THEN
            update_last_extract_date ('CUSTOMER', lv_latest_update_date, lv_status
                                      , lv_msg);
            COMMIT;
        END IF;

        IF (lv_status = 'S')
        THEN
            debug_msg (
                   ' start set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            set_status ('P', NULL, lv_filename);
            debug_msg (
                   ' End set_status TO P '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        END IF;

        debug_msg (' after lookup update ' || lv_status);

        IF (p_create_file = 'Y' AND lv_create_file_flag = 'Y')
        THEN
            IF (lv_status = 'S')
            THEN
                IF (p_send_mail = 'Y')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL, lv_instance_name || ' - Deckers O9 Customer Master Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 Customer Master File is generated. ' || CHR (10) || CHR (10) || '  ' || ' File Name: ' || lv_filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            ELSE
                delete_records;

                IF (p_send_mail = 'Y')
                THEN
                    XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL, lv_instance_name || ' - Deckers O9 Customer Master Interface Completed in Warning ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 Customer Master Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                             , lv_mail_status, lv_mail_msg);
                    debug_msg (
                           ' Mail Status '
                        || lv_mail_status
                        || ' Mail Message '
                        || lv_mail_msg);
                END IF;
            END IF;
        END IF;

        IF (lv_forecast_region_val = 'E')
        THEN
            XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL,
                                     lv_instance_name || ' - Deckers O9 Customer Master Interface Completed in Warning ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 Customer Master Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                     , lv_mail_status, lv_mail_msg);
            debug_msg (
                   ' Mail Status '
                || lv_mail_status
                || ' Mail Message '
                || lv_mail_msg);
        END IF;

        IF (p_send_mail = 'Y' AND lv_create_file_flag = 'N')
        THEN
            IF (lv_status = 'S')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 Customer Master Interface Completed at ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' No data updates to send to O9 for Customer Master. ' || CHR (10) || CHR (10) || '  ' || lv_filename || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            ELSE
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 Customer Master Interface Completed in Warning ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 Customer Master Interface complete in Warning Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;
        END IF;

        IF p_number_days_purg IS NOT NULL
        THEN
            BEGIN
                DELETE FROM xxdo.xxd_ar_adv_cust_master_int_t
                      WHERE creation_date < SYSDATE - p_number_days_purg;

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

            IF (p_send_mail = 'Y')
            THEN
                XXDO_MAIL_PKG.send_mail ('Erp@deckers.com', p_email_id, NULL,
                                         lv_instance_name || ' - Deckers O9 Customer Master Interface Completed in Error ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'), ' Hi,' || CHR (10) || CHR (10) || ' Deckers O9 Customer Master Interface complete in Error Please check log file of request id: ' || gn_request_id || ' for details ' || CHR (10) || CHR (10) || ' Sincerely,' || CHR (10) || ' Planning IT Team', NULL
                                         , lv_mail_status, lv_mail_msg);
                debug_msg (
                       ' Mail Status '
                    || lv_mail_status
                    || ' Mail Message '
                    || lv_mail_msg);
            END IF;

            x_errbuf       :=
                SUBSTR ('Error While Processing The file ' || SQLERRM,
                        1,
                        2000);
            x_retcode      := 2;
            gc_delimiter   := '';
            debug_msg (
                   ' End Interface '
                || ' at '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
    END customer_master_prc;
END xxd_ar_adv_cust_master_int_pkg;
/
