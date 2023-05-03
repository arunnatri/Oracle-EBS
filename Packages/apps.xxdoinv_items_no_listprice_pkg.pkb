--
-- XXDOINV_ITEMS_NO_LISTPRICE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoinv_items_no_listprice_pkg
AS
    -- ###################################################################################
    --
    -- System : Oracle Applications
    -- Subsystem : SCP
    -- Project : ENHC0011892
    -- Description : Package to send the emails to recipients if the Items do not have list price
    -- Module : Inventory
    -- File : XXDOINV_ITEMS_NO_LISTPRICE_PKG.pkb
    -- Schema : XXDO
    -- Date : 18-Mar-2014
    -- Version : 1.0
    -- Author(s) : Rakkesh Kurupathi[Suneratech Consulting]
    -- Purpose : Package used to send the email with EXCEL attachment for the items do not have list price.
    -- dependency :
    -- Change History
    -- --------------
    -- Date Name Ver Change Description
    -- ---------- -------------- ----- -------------------- ------------------
    -- 18-Mar-2014 Rakkesh Kurupaathi 1.0 Initial Version
    -- 05-DEC-2014 BT Technology Team 1.1 Retrofit for BT project
    --
    -- ###################################################################################
    ex_no_recips                              EXCEPTION;
    v_def_mail_recips                         apps.do_mail_utils.tbl_recips;
    gn_conc_req_success              CONSTANT NUMBER := 0;
    gn_conc_req_warning              CONSTANT NUMBER := 1;
    gn_conc_req_error                CONSTANT NUMBER := 2;
    gv_items_no_listprice_lkp_type   CONSTANT VARCHAR2 (100)
        := 'XXDOINV_ITEMS_NO_LISTPRICE_DL' ;

    FUNCTION get_email_recips (pv_lookup_type VARCHAR2)
        RETURN apps.do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   apps.do_mail_utils.tbl_recips;

        CURSOR recips_cur IS
            SELECT lookup_code, meaning, description
              FROM apps.fnd_lookup_values
             WHERE     lookup_type = pv_lookup_type
                   AND enabled_flag = 'Y'
                   AND LANGUAGE = USERENV ('LANG')
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);
    BEGIN
        v_def_mail_recips.DELETE;

        FOR recips_rec IN recips_cur
        LOOP
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                recips_rec.meaning;
        END LOOP;

        RETURN v_def_mail_recips;
    END;

    -----------------------------------------------------------------------
    --Procedure to send the email if Items do not have price lists
    -----------------------------------------------------------------------
    PROCEDURE items_main (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2)
    IS
        lv_out_line         VARCHAR2 (2000);
        ln_counter          NUMBER := 0;
        ln_ret_val          NUMBER := 0;
        lv_database_name    VARCHAR2 (10);

        --------------------------------------------------------------------------
        --Commented by BT Team on 05-DEC-2014
        --------------------------------------------------------------------------
        /*
        CURSOR details_cur
         IS
         SELECT RPAD (SUBSTR (ood.organization_code, 1, 5), 7, ' ')
         orgcode,
         RPAD (SUBSTR (ood.organization_name, 1, 25),
         25,
         ' '
         ) organization_name,
         RPAD (SUBSTR (msib.segment1, 1, 15), 17, ' ') item_style,
         RPAD (SUBSTR (msib.segment2, 1, 7), 10, ' ') item_color,
         RPAD (SUBSTR (msib.segment3, 1, 7), 10, ' ') item_size,
         RPAD (SUBSTR (msib.description, 1, 30), 35,
         ' ') description,
         RPAD (SUBSTR (mcb.segment1, 1, 10), 11, ' ') brand,
         RPAD (SUBSTR (mcb.segment2, 1, 10), 11, ' ') CATEGORY,
         RPAD (SUBSTR (msib.attribute1, 1, 18), 20, ' ') season
         FROM apps.mtl_system_items_b msib,
         apps.mtl_item_categories mic,
         apps.mtl_categories_b mcb,
         apps.org_organization_definitions ood
         WHERE msib.list_price_per_unit IS NULL
         AND msib.segment3 != 'ALL'
         -- AND mcb.segment1 = 'TEVA'
         AND ood.organization_code NOT IN
         ('VNT', 'CA1', 'CH1', 'CH2', 'EU2', 'JP3', 'JP4', 'UK2')
         AND msib.inventory_item_status_code = 'Active'
         AND mcb.segment2 NOT IN ('SAMPLE', 'POP', 'PAPERWORK', 'MISC')
         AND mcb.segment3 NOT IN ('SAMPLE', 'POP', 'PAPERWORK', 'MISC')
         AND mcb.segment4 NOT IN ('SAMPLE', 'POP', 'PAPERWORK', 'MISC')
         AND mcb.segment1 NOT IN ('TSUBO', 'HOKA', 'AHNU')
         AND mic.organization_id = msib.organization_id
         AND mic.inventory_item_id = msib.inventory_item_id
         AND mic.category_set_id = 1
         AND mcb.category_id = mic.category_id
         AND msib.organization_id = ood.organization_id
         AND NVL (ood.disable_date, SYSDATE + 1) > SYSDATE
         -- and msib.attribute1 is null
         --and msib.segment1 = 'SBF10460'
         -- ORDER BY Brand,OrgCode,Item_Style,Item_Color,Item_Size
         UNION ALL
         SELECT RPAD (SUBSTR (ood.organization_code, 1, 5), 7, ' ') orgcode,
         RPAD (SUBSTR (ood.organization_name, 1, 25),
         25,
         ' '
         ) organization_name,
         RPAD (SUBSTR (msib.segment1, 1, 15), 17, ' ') item_style,
         RPAD (SUBSTR (msib.segment2, 1, 7), 10, ' ') item_color,
         RPAD (SUBSTR (msib.segment3, 1, 7), 10, ' ') item_size,
         RPAD (SUBSTR (msib.description, 1, 30), 35,
         ' ') description,
         RPAD (SUBSTR (mcb.segment1, 1, 10), 11, ' ') brand,
         RPAD (SUBSTR (mcb.segment2, 1, 10), 11, ' ') CATEGORY,
         RPAD (SUBSTR (msib.attribute1, 1, 18), 20, ' ') season
         FROM apps.mtl_system_items_b msib,
         apps.mtl_item_categories mic,
         apps.mtl_categories_b mcb,
         apps.org_organization_definitions ood
         WHERE msib.list_price_per_unit IS NULL
         AND msib.segment3 != 'ALL'
         -- AND mcb.segment1 = 'TEVA'
         AND ood.organization_code NOT IN
         ('VNT', 'CA1', 'CH1', 'CH2', 'EU2', 'JP3', 'JP4', 'UK2')
         AND ood.organization_code IN ('DC2', 'IMC')
         AND msib.inventory_item_status_code = 'Active'
         AND mcb.segment2 NOT IN ('SAMPLE', 'POP', 'PAPERWORK', 'MISC')
         AND mcb.segment3 NOT IN ('SAMPLE', 'POP', 'PAPERWORK', 'MISC')
         AND mcb.segment4 NOT IN ('SAMPLE', 'POP', 'PAPERWORK', 'MISC')
         AND mcb.segment1 IN ('TSUBO', 'HOKA')
         AND mic.organization_id = msib.organization_id
         AND mic.inventory_item_id = msib.inventory_item_id
         AND mic.category_set_id = 1
         AND mcb.category_id = mic.category_id
         AND msib.organization_id = ood.organization_id
         AND NVL (ood.disable_date, SYSDATE + 1) > SYSDATE
         -- and msib.attribute1 is null
         --and msib.segment1 = 'SBF10460'
         -- ORDER BY Brand,OrgCode,Item_Style,Item_Color,Item_Size;
         UNION ALL
         SELECT RPAD (SUBSTR (ood.organization_code, 1, 5), 7, ' ') orgcode,
         RPAD (SUBSTR (ood.organization_name, 1, 25),
         25,
         ' '
         ) organization_name,
         RPAD (SUBSTR (msib.segment1, 1, 15), 17, ' ') item_style,
         RPAD (SUBSTR (msib.segment2, 1, 7), 10, ' ') item_color,
         RPAD (SUBSTR (msib.segment3, 1, 7), 10, ' ') item_size,
         RPAD (SUBSTR (msib.description, 1, 30), 35,
         ' ') description,
         RPAD (SUBSTR (mcb.segment1, 1, 10), 11, ' ') brand,
         RPAD (SUBSTR (mcb.segment2, 1, 10), 11, ' ') CATEGORY,
         RPAD (SUBSTR (msib.attribute1, 1, 18), 20, ' ') season
         FROM apps.mtl_system_items_b msib,
         apps.mtl_item_categories mic,
         apps.mtl_categories_b mcb,
         apps.org_organization_definitions ood
         WHERE msib.list_price_per_unit IS NULL
         AND msib.segment3 != 'ALL'
         -- AND mcb.segment1 = 'TEVA'
         AND ood.organization_code NOT IN
         ('VNT', 'CA1', 'CH1', 'CH2', 'EU2', 'JP3', 'JP4', 'UK2')
         AND ood.organization_code IN ('DC1', 'IMC')
         AND msib.inventory_item_status_code = 'Active'
         AND mcb.segment2 NOT IN ('SAMPLE', 'POP', 'PAPERWORK', 'MISC')
         AND mcb.segment3 NOT IN ('SAMPLE', 'POP', 'PAPERWORK', 'MISC')
         AND mcb.segment4 NOT IN ('SAMPLE', 'POP', 'PAPERWORK', 'MISC')
         AND mcb.segment1 IN ('AHNU')
         AND mic.organization_id = msib.organization_id
         AND mic.inventory_item_id = msib.inventory_item_id
         AND mic.category_set_id = 1
         AND mcb.category_id = mic.category_id
         AND msib.organization_id = ood.organization_id
         AND NVL (ood.disable_date, SYSDATE + 1) > SYSDATE
         -- and msib.attribute1 is null
         --and msib.segment1 = 'SBF10460'
         ORDER BY brand, orgcode, item_style, item_color, item_size;
        */
        ----------------------------------------------------------------------------------------------------------------------------
        --Instead of MTL Tables "MTL_SYSTEM_ITEMS_B,MTL_ITEM_CATEGORIES AND MTL_CATEGORIES" We used Custom view "XXD_COMMON_ITEMS_V"
        ----------------------------------------------------------------------------------------------------------------------------

        -----------------------------------------------------------------------------Added the changes by BT Team on 05-DEC-2014------------------------------------------
        CURSOR details_cur IS
            SELECT RPAD (SUBSTR (ood.organization_code, 1, 5), 7, ' ') orgcode, RPAD (SUBSTR (ood.organization_name, 1, 25), 25, ' ') organization_name, xci.style_number item_style,
                   xci.color_code item_color, xci.item_size item_size, xci.item_description description,
                   xci.brand brand, xci.division category, xci.curr_active_season Season
              FROM xxd_common_items_v xci, org_organization_definitions ood
             WHERE     ood.ORGANIZATION_ID = xci.ORGANIZATION_ID
                   AND xci.list_price_per_unit IS NULL
                   AND xci.item_type != 'GENERIC'
                   AND ood.organization_code NOT IN ('MST')
                   AND inventory_item_status_code = 'Active'
                   AND xci.division NOT IN ('SAMPLE', 'POP', 'PAPERWORK',
                                            'MISC')
                   AND xci.department NOT IN ('SAMPLE', 'POP', 'PAPERWORK',
                                              'MISC')
                   AND xci.master_class NOT IN ('SAMPLE', 'POP', 'PAPERWORK',
                                                'MISC')
                   AND xci.brand NOT IN ('TSUBO', 'HOKA', 'AHNU')
                   AND NVL (ood.disable_date, SYSDATE + 1) > SYSDATE
            UNION ALL
            SELECT RPAD (SUBSTR (ood.organization_code, 1, 5), 7, ' ') orgcode, RPAD (SUBSTR (ood.organization_name, 1, 25), 25, ' ') organization_name, xci.style_number item_style,
                   xci.color_code item_color, xci.item_size item_size, xci.item_description description,
                   xci.brand brand, xci.division category, xci.curr_active_season Season
              FROM xxd_common_items_v xci, org_organization_definitions ood
             WHERE     ood.ORGANIZATION_ID = xci.ORGANIZATION_ID
                   AND xci.list_price_per_unit IS NULL
                   AND ood.organization_code NOT IN ('MST')
                   AND xci.item_type != 'GENERIC'
                   AND inventory_item_status_code = 'Active'
                   AND ood.organization_code IN ('US2', 'MC1')
                   AND xci.division NOT IN ('SAMPLE', 'POP', 'PAPERWORK',
                                            'MISC')
                   AND xci.department NOT IN ('SAMPLE', 'POP', 'PAPERWORK',
                                              'MISC')
                   AND xci.master_class NOT IN ('SAMPLE', 'POP', 'PAPERWORK',
                                                'MISC')
                   AND xci.brand NOT IN ('TSUBO', 'HOKA')
                   AND NVL (ood.disable_date, SYSDATE + 1) > SYSDATE
            UNION ALL
            SELECT RPAD (SUBSTR (ood.organization_code, 1, 5), 7, ' ') orgcode, RPAD (SUBSTR (ood.organization_name, 1, 25), 25, ' ') organization_name, xci.style_number item_style,
                   xci.color_code item_color, xci.item_size item_size, xci.item_description description,
                   xci.brand brand, xci.division category, xci.curr_active_season season
              FROM xxd_common_items_v xci, org_organization_definitions ood
             WHERE     ood.ORGANIZATION_ID = xci.ORGANIZATION_ID
                   AND xci.list_price_per_unit IS NULL
                   AND xci.item_type != 'GENERIC'
                   AND ood.organization_code NOT IN ('MST')
                   AND inventory_item_status_code = 'Active'
                   AND ood.organization_code IN ('US1', 'MC1')
                   AND xci.division NOT IN ('SAMPLE', 'POP', 'PAPERWORK',
                                            'MISC')
                   AND xci.department NOT IN ('SAMPLE', 'POP', 'PAPERWORK',
                                              'MISC')
                   AND xci.master_class NOT IN ('SAMPLE', 'POP', 'PAPERWORK',
                                                'MISC')
                   AND xci.brand NOT IN ('AHNU')
                   AND NVL (ood.disable_date, SYSDATE + 1) > SYSDATE
            ORDER BY
                brand, orgcode, item_style,
                item_color, item_size;

        -----------------------------------------------------------------------Changes Ended by BT Team--------------------------------------------------------------

        ex_no_recips        EXCEPTION;
        ex_no_sender        EXCEPTION;
        ex_no_data_found    EXCEPTION;
        v_def_mail_recips   apps.do_mail_utils.tbl_recips;
    BEGIN
        apps.do_debug_utils.set_level (1);

        BEGIN
            SELECT ora_database_name INTO lv_database_name FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        IF apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
        THEN
            RAISE ex_no_sender;
        END IF;

        apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'xxdoinv_items_no_listprice_pkg.items_main', v_debug_text => 'Recipients...'
                                   , l_debug_level => 1);
        v_def_mail_recips   :=
            get_email_recips (gv_items_no_listprice_lkp_type);

        FOR i IN 1 .. v_def_mail_recips.COUNT
        LOOP
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'xxdoinv_items_no_listprice_pkg.items_main', v_debug_text => v_def_mail_recips (i)
                                       , l_debug_level => 1);
        END LOOP;

        IF v_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;

        apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'Items Not Having List Price -' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                             , ln_ret_val);
        apps.do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            ln_ret_val);
        apps.do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                           ln_ret_val);
        apps.do_mail_utils.send_mail_line ('', ln_ret_val);
        apps.do_mail_utils.send_mail_line (
               'Please find the attached items with out listprice in '
            || lv_database_name
            || 'Instance',
            ln_ret_val);
        apps.do_mail_utils.send_mail_line (' ', ln_ret_val);
        apps.do_mail_utils.send_mail_line (' ', ln_ret_val);
        apps.do_mail_utils.send_mail_line (
            '_____________________________________________________________________',
            ln_ret_val);
        apps.do_mail_utils.send_mail_line ('Oracle Applications', ln_ret_val);
        apps.do_mail_utils.send_mail_line ('Deckers Outdoor Corp.',
                                           ln_ret_val);
        apps.do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                           ln_ret_val);
        apps.do_mail_utils.send_mail_line (
               'Content-Disposition: attachment; filename="Items Not Having Listprice'
            || TO_CHAR (SYSDATE, 'YYYYMMDD')
            || '.xls"',
            ln_ret_val);
        apps.do_mail_utils.send_mail_line ('', ln_ret_val);
        apps.do_mail_utils.send_mail_line (
               'OrgCode'
            || CHR (9)
            || 'Organization Name'
            || CHR (9)
            || 'Item Style'
            || CHR (9)
            || 'Item Color'
            || CHR (9)
            || 'Item Size'
            || CHR (9)
            || 'Description'
            || CHR (9)
            || 'Brand'
            || CHR (9)
            || 'Category'
            || CHR (9)
            || 'Season'
            || CHR (9),
            ln_ret_val);

        FOR details_rec IN details_cur
        LOOP
            lv_out_line   := NULL;
            lv_out_line   :=
                   details_rec.orgcode
                || CHR (9)
                || details_rec.organization_name
                || CHR (9)
                || details_rec.item_style
                || CHR (9)
                || details_rec.item_color
                || CHR (9)
                || details_rec.item_size
                || CHR (9)
                || details_rec.description
                || CHR (9)
                || details_rec.brand
                || CHR (9)
                || details_rec.category
                || CHR (9)
                || details_rec.Season
                || CHR (9);
            apps.do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
            ln_counter    := ln_counter + 1;
        END LOOP;

        IF ln_counter = 0
        THEN
            RAISE ex_no_data_found;
        END IF;

        apps.do_mail_utils.send_mail_close (ln_ret_val);
        pv_retcode   := gn_conc_req_success;
        pv_errbuf    := NULL;
    EXCEPTION
        WHEN ex_no_data_found
        THEN
            ROLLBACK;
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'xxdoinv_items_no_listprice_pkg.items_main', v_debug_text => CHR (10) || 'There are no items with null list price'
                                       , l_debug_level => 1);
            apps.do_mail_utils.send_mail_line (
                'There are no Items with null list Price',
                ln_ret_val);
            apps.do_mail_utils.send_mail_close (ln_ret_val);
            pv_retcode   := gn_conc_req_success;
            pv_errbuf    := NULL;
        WHEN ex_no_recips
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_table, v_application_id => 'xxdoinv_items_no_listprice_pkg.items_main', v_debug_text => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , l_debug_level => 1);
            apps.do_mail_utils.send_mail_close (ln_ret_val);
            pv_retcode   := gn_conc_req_error;
            pv_errbuf    :=
                'There were no recipients configured to receive the alert';
        WHEN ex_no_sender
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_table, v_application_id => 'xxdoinv_items_no_listprice_pkg.items_main', v_debug_text => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , l_debug_level => 1);
            apps.do_mail_utils.send_mail_close (ln_ret_val);
            pv_retcode   := gn_conc_req_error;
            pv_errbuf    :=
                'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER';
        WHEN OTHERS
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_table, v_application_id => 'xxdoinv_items_no_listprice_pkg.items_main', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , l_debug_level => 1);
            apps.do_mail_utils.send_mail_close (ln_ret_val);
            pv_retcode   := gn_conc_req_error;
            pv_errbuf    := SQLERRM;
    END;
END xxdoinv_items_no_listprice_pkg;
/
