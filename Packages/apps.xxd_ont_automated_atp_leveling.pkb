--
-- XXD_ONT_AUTOMATED_ATP_LEVELING  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_AUTOMATED_ATP_LEVELING"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_AUTOMATED_ATP_LEVELING
    -- Design       : This package will be used to find Negative ATP items and then Identify the
    --                corresponding sales order lines and try to reschedule safe move and at risk move and unschedule if needed.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 07-Jun-2021    Shivanshu Talwar       1.0    Initial Version
    -- 14-Dec-2021    Shivanshu Talwar       1.1    Modified w.r.t CCR CCR0009753
    -- #########################################################################################################################

    --Global Variables declaration
    gv_package_name      VARCHAR2 (200) := 'XXDO_NEG_ATP_ORD_RESCHED_PKG';
    gn_created_by        NUMBER := apps.fnd_global.user_id;
    gn_last_updated_by   NUMBER := apps.fnd_global.user_id;
    gn_conc_request_id   NUMBER := apps.fnd_global.conc_request_id;
    gn_user_id           NUMBER := apps.fnd_global.user_id;
    gn_resp_appl_id      NUMBER := apps.fnd_global.resp_appl_id;
    gn_resp_id           NUMBER := apps.fnd_global.resp_id;
    gv_debug_flag        VARCHAR2 (20) := 'N';
    gv_op_name           VARCHAR2 (1000);
    gv_op_key            VARCHAR2 (1000);

    --Procedure to write messages to Log
    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (32000);
    BEGIN
        lv_msg   := pv_msg;

        IF gv_debug_flag = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, lv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (
                -20020,
                'Error in Procedure write_log -> ' || SQLERRM);
    END write_log;

    --This function returns the source order date
    FUNCTION get_source_order_line_date (pn_order_header_id IN NUMBER, pn_order_line_id IN NUMBER, pv_date_type IN VARCHAR2)
        RETURN DATE
    IS
        ld_creation_date   DATE;
        ld_request_date    DATE;
        ld_order_date      DATE;
        ld_date            DATE;
    BEGIN
        SELECT ool.creation_date, ool.request_date, ordered_date
          INTO ld_creation_date, ld_request_date, ld_order_date
          FROM oe_order_headers_all ooh, oe_order_lines_all ool
         WHERE     ooh.header_id = ool.header_id
               -- AND ool.header_id = pn_order_header_id
               AND ool.line_id = pn_order_line_id;

        IF pv_date_type = 'CREATION_DATE'
        THEN
            ld_date   := ld_creation_date;
        ELSIF pv_date_type = 'ORDERED_DATE'
        THEN
            ld_date   := ld_order_date;
        ELSIF pv_date_type = 'REQUEST_DATE'
        THEN
            ld_date   := ld_request_date;
        END IF;

        RETURN ld_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                   'Exception in get_source_order_line_date proc for Header id :'
                || pn_order_header_id
                || ' solurce Line '
                || pn_order_line_id
                || ' Type '
                || pv_date_type
                || ' Error '
                || SQLERRM);
            ld_date   := NULL;
            RETURN ld_date;
    END get_source_order_line_date;

    --This function returns the email ID's listed for the given parameters
    FUNCTION email_recipients (pv_lookup_type   IN VARCHAR2,
                               pv_inv_org       IN VARCHAR2)
        RETURN apps.do_mail_utils.tbl_recips
    IS
        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;            --Added for 1.7

        CURSOR recipients_cur IS
            SELECT lookup_code, meaning, description email_id,
                   tag
              FROM apps.fnd_lookup_values
             WHERE     lookup_type = pv_lookup_type
                   AND tag = pv_inv_org
                   AND enabled_flag = 'Y'
                   AND language = USERENV ('LANG')
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);
    BEGIN
        lv_def_mail_recips.delete;

        SELECT applications_system_name
          INTO lv_appl_inst_name
          FROM apps.fnd_product_groups;

        IF lv_appl_inst_name IN ('EBSPROD', 'EBSDEV1')
        THEN
            FOR recipients_rec IN recipients_cur
            LOOP
                lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                    recipients_rec.email_id;
            END LOOP;
        ELSE
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'Batch.OM@deckers.com';
        END IF;

        RETURN lv_def_mail_recips;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'Batch.OM@deckers.com';
            RETURN lv_def_mail_recips;
    END email_recipients;

    PROCEDURE email_output (pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2)
    IS
        CURSOR report_cur IS
              SELECT hou.name operating_unit,
                     mp.organization_code ship_from_org,
                     itm.brand,
                     itm.division,
                     itm.department,
                     itm.style_number style,
                     itm.style_desc,
                     itm.color_code color,
                     itm.color_desc,
                     xna.item_number,
                     itm.item_description,
                     ooha.order_number,
                     ooha.ordered_date,
                     oola.creation_date,
                     oota.name order_type,
                     xna.line_num,
                     hp.party_name customer_name,
                     hca.account_number,
                     (SELECT jrre.resource_name
                        FROM oe_order_lines_all ol, jtf_rs_salesreps jrs, jtf_rs_resource_extns_tl jrre
                       WHERE     jrs.resource_id = jrre.resource_id
                             AND jrre.language = 'US'
                             AND jrs.salesrep_id = ol.salesrep_id
                             AND ol.line_id = xna.line_id
                             AND jrs.org_id = ol.org_id) salesrep_name,
                     xna.request_date,
                     xna.schedule_ship_date,
                     CASE
                         WHEN xna.process_status IN ('S', 'SCH-S', 'BUL-SCH-S')
                         THEN
                             oola.schedule_ship_date
                     END new_schedule_ship_date_der,
                     xna.latest_acceptable_date,
                     xna.new_lad,
                     xna.override_atp_flag,
                     xna.cancel_date,
                     oola.ordered_quantity,
                     CASE
                         WHEN sf_ex_flag = 'Y' THEN 'SAFE MOVE'
                         WHEN ar_ex_flag = 'Y' THEN 'AT RISK MOVE'
                         WHEN un_ex_flag = 'Y' THEN 'UNSCHEDULE'
                     END processing_move,
                     xna.split_case,
                     xna.split_qty,
                     DECODE (xna.process_status,
                             'S', 'Rescheduled',
                             'E', 'Rescheduling Failed',
                             'X', 'Unscheduling Failed',
                             'Z', 'Unscheduled',
                             'U', 'API Unhandled Exception',
                             'BUL-SCH-S', 'Bulk Scheduled',
                             'BUL-ATP-F', 'Bulk ATP Check Failed',
                             'BUL-SPL-F', 'Bulk Split Failed',
                             'BUL-SCH-F', 'Bulk Schedule Failed',
                             'SCH-S', 'Scheduled',
                             'ATP-F', 'ATP Check Failed',
                             'SPL-F', 'Split Failed',
                             'SCH-F', 'Schedule Failed',
                             'N', 'Not Processed',
                             'Error') status_desc,
                     xna.error_message,
                     LTRIM (SUBSTR (xna.error_message,
                                      INSTR (xna.error_message, ':', 1,
                                             2)
                                    + 1)) next_supply_date,
                     ooha.cust_po_number
                /*  NVL2 (xobot.bulk_order_number, 'Yes', 'No')
                      calloff_order,
                  xobot.bulk_order_number,
                  xobot.bulk_cust_po_number
                      bulk_po,
                  NVL2 (
                      xobot.bulk_order_number,
                         xobot.bulk_line_number
                      || '.'
                      || xobot.bulk_shipment_number,
                      NULL)
                      bulk_line_num,
                  (SELECT request_date
                     FROM oe_order_lines_all
                    WHERE line_id = xobot.bulk_line_id)
                      bulk_rsd,
                  (SELECT schedule_ship_date
                     FROM oe_order_lines_all
                    WHERE line_id = xobot.bulk_line_id)
                      bulk_ssd,
                  (SELECT latest_acceptable_date
                     FROM oe_order_lines_all
                    WHERE line_id = xobot.bulk_line_id)
                      bulk_lad*/
                FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T xna, apps.hz_cust_accounts hca, apps.hz_parties hp,
                     apps.xxd_common_items_v itm, apps.hr_operating_units hou, apps.mtl_parameters mp,
                     apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, -- apps.xxd_ont_bulk_orders_t        xobot,
                                                                                   apps.oe_transaction_types_tl oota
               WHERE     1 = 1
                     AND ooha.order_type_id = oota.transaction_type_id
                     AND oota.language = USERENV ('LANG')
                     AND xna.batch_id = pn_batch_id
                     AND xna.ship_from_org_id = pn_organization_id
                     AND xna.brand = NVL (pv_brand, xna.brand)
                     AND (sf_ex_flag = 'Y' OR ar_ex_flag = 'Y' OR un_ex_flag = 'Y')
                     AND xna.SOLD_TO_ORG_ID = hca.cust_account_id
                     AND hca.status = 'A'
                     AND hca.party_id = hp.party_id
                     AND hp.status = 'A'
                     AND xna.inventory_item_id = itm.inventory_item_id
                     AND xna.ship_from_org_id = itm.organization_id
                     AND xna.org_id = hou.organization_id
                     AND xna.ship_from_org_id = mp.organization_id
                     AND xna.header_id = ooha.header_id
                     AND xna.header_id = oola.header_id
                     AND xna.line_id = oola.line_id
            --   AND oola.header_id = xobot.calloff_header_id(+)
            --   AND oola.line_id = xobot.calloff_line_id(+)
            --   AND xobot.link_type(+) = 'BULK_LINK'
            ORDER BY xna.last_update_date, xna.ship_from_org_id, xna.item_number,
                     xna.request_date, xna.schedule_ship_date;


        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;
        lv_email_lkp_type    VARCHAR2 (50) := 'XXD_NEG_ATP_RESCHEDULE_EMAIL';
        lv_inv_org_code      VARCHAR2 (3) := NULL;
        ln_ret_val           NUMBER := 0;
        lv_out_line          VARCHAR2 (1000);
        ln_counter           NUMBER := 0;
        ln_rec_cnt           NUMBER := 0;

        ex_no_sender         EXCEPTION;
        ex_no_recips         EXCEPTION;
    BEGIN
        SELECT COUNT (*)
          INTO ln_rec_cnt
          FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T stg
         WHERE     1 = 1
               AND stg.batch_id = pn_batch_id
               AND stg.ship_from_org_id = pn_organization_id
               AND stg.brand = NVL (pv_brand, stg.brand);

        IF apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
        THEN
            RAISE ex_no_sender;
        END IF;

        write_log ('Record counts : ' || ln_rec_cnt);

        --Getting the inventory organization code
        BEGIN
            SELECT organization_code
              INTO lv_inv_org_code
              FROM apps.mtl_parameters
             WHERE organization_id = pn_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                    'Unable to fetch inv_org_code in email_output procedure');
        END;

        --Getting the email recipients and assigning them to a table type variable
        lv_def_mail_recips   :=
            email_recipients (lv_email_lkp_type, lv_inv_org_code);

        IF lv_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        ELSE
            --Getting the instance name
            BEGIN
                SELECT applications_system_name
                  INTO lv_appl_inst_name
                  FROM apps.fnd_product_groups;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                        'Unable to fetch the File server name in email_output procedure');
            END;

            --CCR0009753
            apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), lv_def_mail_recips, 'Deckers Automatic Levelling Program output for ' || lv_inv_org_code || ' and ' || pv_brand || ' on ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24MISS') || ' from ' || lv_appl_inst_name || ' instance'
                                                 , ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                   'Total number of records for '
                || lv_inv_org_code
                || ' and '
                || pv_brand
                || ' = '
                || ln_rec_cnt,
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);

            --Attach the file if there are any records

            write_log ('Attach counts : ' || ln_rec_cnt);

            IF ln_rec_cnt > 0
            THEN
                apps.do_mail_utils.send_mail_line ('', ln_ret_val);
                apps.do_mail_utils.send_mail_line (
                    'See attachment for report details.',
                    ln_ret_val);
                apps.do_mail_utils.send_mail_line ('', ln_ret_val);
                apps.do_mail_utils.send_mail_line ('--boundarystring',
                                                   ln_ret_val);
                apps.do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                                   ln_ret_val);
                apps.do_mail_utils.send_mail_line (
                       'Content-Disposition: attachment; filename="Deckers Automatic Levelling Report output for '
                    || lv_inv_org_code
                    || ' and '
                    || pv_brand
                    || ' on '
                    || TO_CHAR (SYSDATE, 'MMDDYYYY HH24MISS')
                    || '.xls"',
                    ln_ret_val);
                apps.do_mail_utils.send_mail_line ('', ln_ret_val);

                write_log ('ln_ret_val : ' || ln_ret_val);

                apps.do_mail_utils.send_mail_line (
                       'Operating Unit'
                    || CHR (9)
                    || 'Ship From Org'
                    || CHR (9)
                    || 'Brand'
                    || CHR (9)
                    || 'Division'
                    || CHR (9)
                    || 'Department'
                    || CHR (9)
                    || 'Style'
                    || CHR (9)
                    || 'Style Description'
                    || CHR (9)
                    || 'Color'
                    || CHR (9)
                    || 'Color Description'
                    || CHR (9)
                    || 'SKU'
                    || CHR (9)
                    || 'Item Description'
                    || CHR (9)
                    || 'SO#'
                    || CHR (9)
                    || 'Customer PO#'
                    || CHR (9)
                    || 'Order Type'
                    || CHR (9)
                    || 'SO Line#'
                    || CHR (9)
                    || 'Customer Name'
                    || CHR (9)
                    || 'Account Number'
                    || CHR (9)
                    || 'Salesrep Name'
                    || CHR (9)
                    || 'Ordered Date'
                    || CHR (9)
                    || 'Request Date'
                    || CHR (9)
                    || 'Schedule Ship Date'
                    || CHR (9)
                    || 'New Schedule Ship Date'
                    || CHR (9)
                    || 'Latest Acceptable Date'
                    || CHR (9)
                    || 'New Latest Acceptable Date'
                    || CHR (9)
                    || 'Cancel Date'
                    || CHR (9)
                    || 'Quantity'
                    || CHR (9)
                    || 'processing_move'
                    || CHR (9)
                    || 'split case'
                    || CHR (9)
                    || 'split qty'
                    || CHR (9)
                    || 'Status'
                    || CHR (9)
                    || 'Error Message'
                    || CHR (9)
                    || 'Next Supply Date'/*|| CHR (9)
                                         || 'Calloff Order (Yes/No)'
                                         || CHR (9)
                                         || 'Bulk Order#'
                                         || CHR (9)
                                         || 'Bulk Customer PO#'
                                         || CHR (9)
                                         || 'Bulk Line#'
                                         || CHR (9)
                                         || 'Bulk Request Date'
                                         || CHR (9)
                                         || 'Bulk Schedule Ship Date'
                                         || CHR (9)
                                         || 'Bulk Latest Acceptable Date'
                                         || CHR (9)                      */
                                         ,
                    ln_ret_val);

                FOR report_rec IN report_cur
                LOOP
                    lv_out_line   := NULL;
                    lv_out_line   :=
                           report_rec.operating_unit
                        || CHR (9)
                        || report_rec.ship_from_org
                        || CHR (9)
                        || report_rec.brand
                        || CHR (9)
                        || report_rec.division
                        || CHR (9)
                        || report_rec.department
                        || CHR (9)
                        || report_rec.style
                        || CHR (9)
                        || report_rec.style_desc
                        || CHR (9)
                        || report_rec.color
                        || CHR (9)
                        || report_rec.color_desc
                        || CHR (9)
                        || report_rec.item_number
                        || CHR (9)
                        || report_rec.item_description
                        || CHR (9)
                        || report_rec.order_number
                        || CHR (9)
                        || report_rec.cust_po_number
                        || CHR (9)
                        || report_rec.order_type
                        || CHR (9)
                        || report_rec.line_num
                        || CHR (9)
                        || report_rec.customer_name
                        || CHR (9)
                        || report_rec.account_number
                        || CHR (9)
                        || report_rec.salesrep_name
                        || CHR (9)
                        || report_rec.ordered_date
                        || CHR (9)
                        || report_rec.request_date
                        || CHR (9)
                        || report_rec.schedule_ship_date
                        || CHR (9)
                        || report_rec.new_schedule_ship_date_der
                        || CHR (9)
                        || report_rec.latest_acceptable_date
                        || CHR (9)
                        || report_rec.new_lad
                        || CHR (9)
                        || report_rec.cancel_date
                        || CHR (9)
                        || report_rec.ordered_quantity
                        || CHR (9)
                        || report_rec.processing_move
                        || CHR (9)
                        || report_rec.split_case
                        || CHR (9)
                        || report_rec.split_qty
                        || CHR (9)
                        || report_rec.status_desc
                        || CHR (9)
                        || report_rec.error_message
                        || CHR (9)
                        || report_rec.next_supply_date
                        || CHR (9);
                    /*
                    || report_rec.calloff_order
                    || CHR (9)
                    || report_rec.bulk_order_number
                    || CHR (9)
                    || report_rec.bulk_po
                    || CHR (9)
                    || report_rec.bulk_line_num
                    || CHR (9)
                    || report_rec.bulk_rsd
                    || CHR (9)
                    || report_rec.bulk_ssd
                    || CHR (9)
                    || report_rec.bulk_lad
                    || CHR (9)*/

                    apps.do_mail_utils.send_mail_line (lv_out_line,
                                                       ln_ret_val);
                    ln_counter    := ln_counter + 1;
                END LOOP;

                write_log ('Final ln_ret_val : ' || ln_ret_val);

                apps.do_mail_utils.send_mail_close (ln_ret_val);
            END IF;
        END IF;
    EXCEPTION
        WHEN ex_no_sender
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log (
                'ex_no_sender : There is no sender configured. Check the profile value DO: Default Alert Sender');
        WHEN ex_no_recips
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log (
                'ex_no_recips : There are no recipients configured to receive the email. Check lookup type XXD_NEG_ATP_RESCHEDULE_EMAIL');
        WHEN OTHERS
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log ('Error in Procedure email_ouput -> ' || SQLERRM);
    END email_output;


    /******************************************************************************************/
    --This procedure Prints the audit report in the concurrent program output file
    /******************************************************************************************/
    PROCEDURE audit_report (pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2)
    IS
        CURSOR output_cur IS
              SELECT hou.name operating_unit,
                     mp.organization_code ship_from_org,
                     itm.brand,
                     itm.division,
                     itm.department,
                     itm.style_number style,
                     itm.style_desc,
                     itm.color_code color,
                     itm.color_desc,
                     xna.item_number,
                     itm.item_description,
                     ooha.order_number,
                     ooha.ordered_date,
                     oola.creation_date,
                     oota.name order_type,
                     xna.line_num,
                     hp.party_name customer_name,
                     hca.account_number,
                     (SELECT jrre.resource_name
                        FROM oe_order_lines_all ol, jtf_rs_salesreps jrs, jtf_rs_resource_extns_tl jrre
                       WHERE     jrs.resource_id = jrre.resource_id
                             AND jrre.language = 'US'
                             AND jrs.salesrep_id = ol.salesrep_id
                             AND ol.line_id = xna.line_id
                             AND jrs.org_id = ol.org_id) salesrep_name,
                     xna.request_date,
                     xna.schedule_ship_date,
                     CASE
                         WHEN xna.process_status IN ('S', 'SCH-S', 'BUL-SCH-S')
                         THEN
                             oola.schedule_ship_date
                     END new_schedule_ship_date_der,
                     xna.latest_acceptable_date,
                     xna.new_lad,
                     xna.override_atp_flag,
                     xna.cancel_date,
                     oola.ordered_quantity,
                     CASE
                         WHEN sf_ex_flag = 'Y' THEN 'SAFE MOVE'
                         WHEN ar_ex_flag = 'Y' THEN 'AT RISK MOVE'
                         WHEN un_ex_flag = 'Y' THEN 'UNSCHEDULE'
                     END processing_move,
                     xna.split_case,
                     xna.split_qty,
                     DECODE (xna.process_status,
                             'S', 'Rescheduled',
                             'E', 'Rescheduling Failed',
                             'X', 'Unscheduling Failed',
                             'Z', 'Unscheduled',
                             'U', 'API Unhandled Exception',
                             'BUL-SCH-S', 'Bulk Scheduled',
                             'BUL-ATP-F', 'Bulk ATP Check Failed',
                             'BUL-SPL-F', 'Bulk Split Failed',
                             'BUL-SCH-F', 'Bulk Schedule Failed',
                             'SCH-S', 'Scheduled',
                             'ATP-F', 'ATP Check Failed',
                             'SPL-F', 'Split Failed',
                             'SCH-F', 'Schedule Failed',
                             'N', 'Not Processed',
                             'Error') status_desc,
                     xna.error_message,
                     LTRIM (SUBSTR (xna.error_message,
                                      INSTR (xna.error_message, ':', 1,
                                             2)
                                    + 1)) next_supply_date,
                     ooha.cust_po_number
                /*  NVL2 (xobot.bulk_order_number, 'Yes', 'No')
                      calloff_order,
                  xobot.bulk_order_number,
                  xobot.bulk_cust_po_number
                      bulk_po,
                  NVL2 (
                      xobot.bulk_order_number,
                         xobot.bulk_line_number
                      || '.'
                      || xobot.bulk_shipment_number,
                      NULL)
                      bulk_line_num,
                  (SELECT request_date
                     FROM oe_order_lines_all
                    WHERE line_id = xobot.bulk_line_id)
                      bulk_rsd,
                  (SELECT schedule_ship_date
                     FROM oe_order_lines_all
                    WHERE line_id = xobot.bulk_line_id)
                      bulk_ssd,
                  (SELECT latest_acceptable_date
                     FROM oe_order_lines_all
                    WHERE line_id = xobot.bulk_line_id)
                      bulk_lad*/
                FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T xna, apps.hz_cust_accounts hca, apps.hz_parties hp,
                     apps.xxd_common_items_v itm, apps.hr_operating_units hou, apps.mtl_parameters mp,
                     apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, -- apps.xxd_ont_bulk_orders_t        xobot,
                                                                                   apps.oe_transaction_types_tl oota
               WHERE     1 = 1
                     AND ooha.order_type_id = oota.transaction_type_id
                     AND oota.language = USERENV ('LANG')
                     AND xna.batch_id = pn_batch_id
                     AND xna.ship_from_org_id = pn_organization_id
                     AND xna.brand = NVL (pv_brand, xna.brand)
                     AND (sf_ex_flag = 'Y' OR ar_ex_flag = 'Y' OR un_ex_flag = 'Y')
                     AND xna.SOLD_TO_ORG_ID = hca.cust_account_id
                     AND hca.status = 'A'
                     AND hca.party_id = hp.party_id
                     AND hp.status = 'A'
                     AND xna.inventory_item_id = itm.inventory_item_id
                     AND xna.ship_from_org_id = itm.organization_id
                     AND xna.org_id = hou.organization_id
                     AND xna.ship_from_org_id = mp.organization_id
                     AND xna.header_id = ooha.header_id
                     AND xna.header_id = oola.header_id
                     AND xna.line_id = oola.line_id
            --   AND oola.header_id = xobot.calloff_header_id(+)
            --   AND oola.line_id = xobot.calloff_line_id(+)
            --   AND xobot.link_type(+) = 'BULK_LINK'
            ORDER BY xna.last_update_date, xna.ship_from_org_id, xna.item_number,
                     xna.request_date, xna.schedule_ship_date;
    BEGIN
        --Writing the program output to output file
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               'Operating Unit'
            || '|'
            || 'Ship From Org'
            || '|'
            || 'Brand'
            || '|'
            || 'Division'
            || '|'
            || 'Department'
            || '|'
            || 'Style'
            || '|'
            || 'Style Description'
            || '|'
            || 'Color'
            || '|'
            || 'Color Description'
            || '|'
            || 'SKU'
            || '|'
            || 'Item Description'
            || '|'
            || 'SO#'
            || '|'
            || 'Customer PO#'
            || '|'
            || 'Order Type'
            || '|'
            || 'SO Line#'
            || '|'
            || 'Customer Name'
            || '|'
            || 'Account Number'
            || '|'
            || 'Salesrep Name'
            || '|'
            || 'Ordered Date'
            || '|'
            || 'Creation Date'
            || '|'
            || 'Request Date'
            || '|'
            || 'Schedule Ship Date'
            || '|'
            || 'New Schedule Ship Date'
            || '|'
            || 'Latest Acceptable Date'
            || '|'
            || 'New Latest Acceptable Date'
            || '|'
            || 'Cancel Date'
            || '|'
            || 'Quantity'
            || '|'
            || 'processing_move'
            || '|'
            || 'split case'
            || '|'
            || 'split Quantity'
            || '|'
            || 'Status'
            || '|'
            || 'Error Message'
            || '|'
            || 'Next Supply Date'/*|| '|'
                                 || 'Calloff Order (Yes/No)'
                                 || '|'
                                 || 'Bulk Order#'
                                 || '|'
                                 || 'Bulk Customer PO#'
                                 || '|'
                                 || 'Bulk Line#'
                                 || '|'
                                 || 'Bulk Request Date'
                                 || '|'
                                 || 'Bulk Schedule Ship Date'
                                 || '|'
                                 || 'Bulk Latest Acceptable Date'*/
                                 );


        FOR output_rec IN output_cur
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   output_rec.operating_unit
                || '|'
                || output_rec.ship_from_org
                || '|'
                || output_rec.brand
                || '|'
                || output_rec.division
                || '|'
                || output_rec.department
                || '|'
                || output_rec.style
                || '|'
                || output_rec.style_desc
                || '|'
                || output_rec.color
                || '|'
                || output_rec.color_desc
                || '|'
                || output_rec.item_number
                || '|'
                || output_rec.item_description
                || '|'
                || output_rec.order_number
                || '|'
                || output_rec.cust_po_number
                || '|'
                || output_rec.order_type
                || '|'
                || output_rec.line_num
                || '|'
                || output_rec.customer_name
                || '|'
                || output_rec.account_number
                || '|'
                || output_rec.salesrep_name
                || '|'
                || output_rec.ordered_date
                || '|'
                || output_rec.creation_date
                || '|'
                || output_rec.request_date
                || '|'
                || output_rec.schedule_ship_date
                || '|'
                || output_rec.new_schedule_ship_date_der
                || '|'
                || output_rec.latest_acceptable_date
                || '|'
                || output_rec.new_lad
                || '|'
                || output_rec.cancel_date
                || '|'
                || output_rec.ordered_quantity
                || '|'
                || output_rec.processing_move
                || '|'
                || output_rec.split_case
                || '|'
                || output_rec.split_qty
                || '|'
                || output_rec.status_desc
                || '|'
                || output_rec.error_message
                || '|'
                || output_rec.next_supply_date/*   || '|'
                                 || output_rec.calloff_order
                                 || '|'
                                 || output_rec.bulk_order_number
                                 || '|'
                                 || output_rec.bulk_po
                                 || '|'
                                 || output_rec.bulk_line_num
                                 || '|'
                                 || output_rec.bulk_rsd
                                 || '|'
                                 || output_rec.bulk_ssd
                                 || '|'
                                 || output_rec.bulk_lad*/
                                              );
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in writing Audit Report -> ' || SQLERRM);
    END audit_report;


    /******************************************************************************************/
    --This procedure purges the data from the staging table which is before the retention days
    /******************************************************************************************/
    PROCEDURE purge_data (pn_retention_days IN NUMBER DEFAULT 30)
    IS
        ln_commit_count             NUMBER := 0;
        ln_records_deleted          NUMBER := 0;
        ln_stg_rec_cnt              NUMBER := 0;
        ln_neg_atp_item_del_cnt     NUMBER := 0;
        ln_neg_atp_soline_del_cnt   NUMBER := 0;
    BEGIN
        --Truncating the staging tables holding the negative ATP items
        --Deleting the data in the temp table holding the negative ATP items
        DELETE FROM
            xxdo.XXD_ONT_AUTO_ATP_SKU_BKP_T
              WHERE TRUNC (creation_date) <
                    TRUNC (SYSDATE - NVL (pn_retention_days, 30));

        ln_neg_atp_item_del_cnt     := SQL%ROWCOUNT;
        COMMIT;

        write_log (
               'Number of records deleted from Neg. ATP Items Temp table(XXD_ONT_AUTO_ATP_SKU_BKP_T) = '
            || ln_neg_atp_item_del_cnt);

        --Deleting the temp table data holding the negative ATP items related SO Lines
        DELETE FROM
            xxdo.XXD_ONT_AUTO_ATP_SUMRY_BKP_T
              WHERE TRUNC (creation_date) <
                    TRUNC (SYSDATE - NVL (pn_retention_days, 30));

        ln_neg_atp_soline_del_cnt   := SQL%ROWCOUNT;
        COMMIT;

        write_log (
               'Number of records deleted from Neg. ATP Items SO Lines Temp table(XXD_ONT_AUTO_ATP_SUMRY_BKP_T) = '
            || ln_neg_atp_soline_del_cnt);

        DELETE FROM
            xxdo.XXD_ONT_AUTO_ATP_SULDMD_BKP_T
              WHERE TRUNC (creation_date) <
                    TRUNC (SYSDATE - NVL (pn_retention_days, 30));

        ln_records_deleted          := SQL%ROWCOUNT;

        COMMIT;

        write_log (
               'Number of records deleted from staging table(XXD_ONT_AUTO_ATP_SULDMD_BKP_T) by purge program = '
            || ln_records_deleted);


        DELETE FROM
            xxdo.XXD_ONT_AUTO_ATP_ORDRS_BKP_T
              WHERE TRUNC (creation_date) <
                    TRUNC (SYSDATE - NVL (pn_retention_days, 30));

        ln_records_deleted          := SQL%ROWCOUNT;
        COMMIT;

        write_log (
               'Number of records deleted from staging table(XXD_ONT_AUTO_ATP_ORDRS_BKP_T) by purge program = '
            || ln_records_deleted);
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in purge_data procedure: ' || SQLERRM);
            raise_application_error (
                -20020,
                'Error in Procedure purge_data ' || SQLERRM);
    END purge_data;

    /******************************************************************************************/
    --This procedure will truncate the data from the staging table which is before the retention days
    /******************************************************************************************/

    PROCEDURE truncate_staging_data (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_purge_retention_days NUMBER)
    IS
        ln_commit_count             NUMBER := 0;
        ln_records_deleted          NUMBER := 0;
        ln_stg_rec_cnt              NUMBER := 0;
        ln_neg_atp_item_del_cnt     NUMBER := 0;
        ln_neg_atp_soline_del_cnt   NUMBER := 0;
        ln_rentention_days          NUMBER;
    BEGIN
        --Truncating the temp table holding the negative ATP items
        --Deleting the data in the temp table holding the negative ATP items

        ln_rentention_days          := NVL (pn_purge_retention_days, 30);
        purge_data (ln_rentention_days);

        ln_neg_atp_item_del_cnt     := SQL%ROWCOUNT;
        COMMIT;

        INSERT INTO XXDO.XXD_ONT_AUTO_ATP_SKU_BKP_T
            SELECT * FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_SKU_T;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.XXD_ONT_AUTO_ATP_LEVL_SKU_T';

        write_log (
               'Number of records deleted from Neg. ATP Items Temp table(XXD_ONT_AUTO_ATP_LEVL_SKU_T) = '
            || ln_neg_atp_item_del_cnt);

        --truncating table data holding the negative ATP items related SO Lines

        INSERT INTO XXDO.XXD_ONT_AUTO_ATP_SUMRY_BKP_T
            SELECT * FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_SUMRY_T;

        ln_neg_atp_soline_del_cnt   := SQL%ROWCOUNT;
        COMMIT;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.XXD_ONT_AUTO_ATP_LEVL_SUMRY_T';

        write_log (
               'Number of records deleted from Neg. ATP Items SO Lines Temp table(XXD_ONT_AUTO_ATP_LEVL_SUMRY_T) = '
            || ln_neg_atp_soline_del_cnt);

        INSERT INTO XXDO.XXD_ONT_AUTO_ATP_SULDMD_BKP_T
            SELECT * FROM xxdo.XXD_ONT_AUTO_ATP_SPLY_DMAND_T;

        ln_records_deleted          := SQL%ROWCOUNT;

        COMMIT;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.XXD_ONT_AUTO_ATP_SPLY_DMAND_T';

        write_log (
               'Number of records deleted from staging table(XXD_ONT_AUTO_ATP_SPLY_DMAND_T) by purge program = '
            || ln_records_deleted);


        INSERT INTO XXDO.XXD_ONT_AUTO_ATP_ORDRS_BKP_T
            SELECT * FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T;

        ln_records_deleted          := SQL%ROWCOUNT;
        COMMIT;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T';

        write_log (
               'Number of records deleted from staging table(XXD_ONT_AUTO_ATP_LEVL_ORDRS_T) by purge program = '
            || ln_records_deleted);
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in purge_data procedure: ' || SQLERRM);
            raise_application_error (
                -20020,
                'Error in Procedure purge_data ' || SQLERRM);
    END truncate_staging_data;

    -- *********************************************************************************
    -- This procedure calls MRP_ATP_PUB to evaluate available SKU quantity
    -- **********************************************************************************

    PROCEDURE get_atp_qty (p_line_id IN NUMBER, x_atp_current_available_qty OUT NOCOPY NUMBER, x_return_status OUT NOCOPY VARCHAR2
                           , x_error_message OUT NOCOPY VARCHAR2)
    AS
        lx_atp_rec            mrp_atp_pub.atp_rec_typ;
        l_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        l_atp_period          mrp_atp_pub.atp_period_typ;
        l_atp_details         mrp_atp_pub.atp_details_typ;
        lc_msg_data           VARCHAR2 (2000);
        lc_msg_dummy          VARCHAR2 (2000);
        lc_return_status      VARCHAR2 (2000);
        ln_msg_index_out      NUMBER;
        ln_session_id         NUMBER;
        ln_msg_count          NUMBER;
        l_line_rec            oe_order_pub.line_rec_type;
        l_atp_rec             mrp_atp_pub.atp_rec_typ;
    BEGIN
        l_line_rec                               := oe_order_pub.get_g_miss_line_rec;
        -- Query Current Order Line
        oe_line_util.query_row (p_line_id    => p_line_id,
                                x_line_rec   => l_line_rec);

        -- ATP Rec
        msc_atp_global.extend_atp (l_atp_rec, lc_return_status, 1);
        l_atp_rec.inventory_item_id (1)          := l_line_rec.inventory_item_id;
        l_atp_rec.quantity_ordered (1)           := l_line_rec.ordered_quantity;
        l_atp_rec.quantity_uom (1)               := l_line_rec.order_quantity_uom;
        -- Pass LAD to Request Date to cover future supplies
        l_atp_rec.requested_ship_date (1)        :=
            l_line_rec.latest_acceptable_date;
        l_atp_rec.latest_acceptable_date (1)     :=
            l_line_rec.latest_acceptable_date;
        l_atp_rec.source_organization_id (1)     := l_line_rec.ship_from_org_id;
        l_atp_rec.demand_class (1)               :=
            l_line_rec.demand_class_code;
        -- Set additional input values
        l_atp_rec.action (1)                     := 100;
        l_atp_rec.instance_id (1)                := 61;
        l_atp_rec.oe_flag (1)                    := 'N';
        l_atp_rec.insert_flag (1)                := 1;
        -- Hardcoded value for profile MRP:Calculate Supply Demand 0= NO
        l_atp_rec.attribute_04 (1)               := 1;
        -- With this Attribute set to 1 this will enable the Period (Horizontal Plan),
        l_atp_rec.customer_id (1)                := NULL;
        l_atp_rec.customer_site_id (1)           := NULL;
        l_atp_rec.calling_module (1)             := NULL;
        l_atp_rec.row_id (1)                     := NULL;
        l_atp_rec.source_organization_code (1)   := NULL;
        l_atp_rec.organization_id (1)            := NULL;
        l_atp_rec.order_number (1)               := NULL;
        l_atp_rec.line_number (1)                := NULL;
        l_atp_rec.override_flag (1)              := 'N';
        write_log ('Item ID=' || l_line_rec.inventory_item_id);
        write_log (
               'Checking ATP for Qty '
            || l_line_rec.ordered_quantity
            || ' with Demand Class Code as '
            || l_line_rec.demand_class_code);

        SELECT oe_order_sch_util.get_session_id INTO ln_session_id FROM DUAL;

        mrp_atp_pub.call_atp (p_session_id          => ln_session_id,
                              p_atp_rec             => l_atp_rec,
                              x_atp_rec             => lx_atp_rec,
                              x_atp_supply_demand   => l_atp_supply_demand,
                              x_atp_period          => l_atp_period,
                              x_atp_details         => l_atp_details,
                              x_return_status       => x_return_status,
                              x_msg_data            => lc_msg_data,
                              x_msg_count           => ln_msg_count);
        write_log ('ATP API Status = ' || x_return_status);

        IF NVL (lx_atp_rec.requested_date_quantity (1), 0) > 0
        THEN
            x_atp_current_available_qty   :=
                NVL (lx_atp_rec.requested_date_quantity (1), 0);
            x_return_status   := 'S';
            x_error_message   := NULL;
        ELSE
            x_return_status   := 'E';
            x_error_message   :=
                'Requested Qty is either 0 or unable to derive';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_atp_current_available_qty   := 0;
            write_log ('Others Exception in GET_ATP_QTY = ' || SQLERRM);
            x_return_status               := 'E';
            x_error_message               := SUBSTR (SQLERRM, 1, 2000);
    END get_atp_qty;


    /************************************************************************************************/
    --This procedure takes batch_id, Inv Org, Brand, processing move and exclude as parameter
    -- and calls the worker program for Safe move Atrisk move and unscheduling
    /************************************************************************************************/

    PROCEDURE launch_worker_programs (pn_batch_id NUMBER, pn_organization_id NUMBER, pv_brand VARCHAR2, pn_batch_size NUMBER, pn_threads NUMBER, pv_processing_move VARCHAR2
                                      , pv_exclude VARCHAR2)
    IS
        CURSOR submit_worker (ln_threds IN NUMBER)
        IS
                SELECT LEVEL line_seq_number
                  FROM DUAL
            CONNECT BY LEVEL <= ln_threds;

        ln_resched_req_id   NUMBER;
        ln_max_seq          NUMBER;
        ln_to_seq_num       NUMBER;
        ln_from_seq_num     NUMBER;
        ln_batch_id         NUMBER;
        ln_batches          NUMBER;
        ln_child_req        NUMBER;
        ln_threads          NUMBER;
    BEGIN
        ln_batch_id   := pn_batch_id;
        ln_batches    := 1;
        ln_threads    := TO_NUMBER (pn_threads);

        write_log (
            'Inside launch_worker_programs PM: ' || pv_processing_move);

        IF pv_processing_move = 'SAFE_MOVE'
        THEN
            ln_max_seq   := 1;

            SELECT COUNT (1)
              INTO ln_max_seq
              FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
             WHERE     1 = 1
                   AND ship_from_org_id = pn_organization_id
                   AND batch_id = ln_batch_id
                   AND sf_ex_flag = 'Y'
                   AND brand = NVL (pv_brand, brand)
                   AND process_status = 'N';

            ln_batches   := CEIL (ln_max_seq / pn_batch_size);

            MERGE INTO xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T a
                 USING (SELECT line_id, NTILE (ln_batches) OVER (ORDER BY line_id) batch
                          FROM (SELECT DISTINCT line_id
                                  FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
                                 WHERE     sf_ex_flag = 'Y'
                                       AND BATCH_ID = ln_batch_id
                                       AND process_status = 'N'
                                       AND brand = NVL (pv_brand, brand)
                                       AND ship_from_org_id =
                                           pn_organization_id)) b
                    ON (a.line_id = b.line_id)
            WHEN MATCHED
            THEN
                UPDATE SET line_seq_number   = b.batch;
        ELSIF pv_processing_move = 'ATRISK_MOVE'
        THEN
            ln_max_seq   := 1;

            SELECT COUNT (1)
              INTO ln_max_seq
              FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
             WHERE     1 = 1
                   AND ship_from_org_id = pn_organization_id
                   AND batch_id = ln_batch_id
                   AND ar_ex_flag = 'Y'
                   AND brand = NVL (pv_brand, brand)
                   AND process_status = 'N';

            ln_batches   := CEIL (ln_max_seq / pn_batch_size);

            MERGE INTO xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T a
                 USING (SELECT line_id, NTILE (ln_batches) OVER (ORDER BY line_id) batch
                          FROM (SELECT DISTINCT line_id
                                  FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
                                 WHERE     ar_ex_flag = 'Y'
                                       AND BATCH_ID = ln_batch_id
                                       AND process_status = 'N'
                                       AND brand = NVL (pv_brand, brand)
                                       AND ship_from_org_id =
                                           pn_organization_id)) b
                    ON (a.line_id = b.line_id)
            WHEN MATCHED
            THEN
                UPDATE SET line_seq_number   = b.batch;
        ELSIF pv_processing_move = 'UNSCHEDULE_MOVE'
        THEN
            ln_max_seq   := 1;

            SELECT COUNT (1)
              INTO ln_max_seq
              FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
             WHERE     1 = 1
                   AND ship_from_org_id = pn_organization_id
                   AND batch_id = ln_batch_id
                   AND un_ex_flag = 'Y'
                   AND brand = NVL (pv_brand, brand)
                   AND process_status = 'N';

            ln_batches   := CEIL (ln_max_seq / pn_batch_size);

            MERGE INTO xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T a
                 USING (SELECT line_id, NTILE (ln_batches) OVER (ORDER BY line_id) batch
                          FROM (SELECT DISTINCT line_id
                                  FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
                                 WHERE     un_ex_flag = 'Y'
                                       AND BATCH_ID = ln_batch_id
                                       AND brand = NVL (pv_brand, brand)
                                       AND process_status = 'N'
                                       AND ship_from_org_id =
                                           pn_organization_id)) b
                    ON (a.line_id = b.line_id)
            WHEN MATCHED
            THEN
                UPDATE SET line_seq_number   = b.batch;
        ELSIF pv_processing_move = 'SPLIT_CASE'
        THEN
            ln_max_seq   := 1;

            SELECT COUNT (1)
              INTO ln_max_seq
              FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
             WHERE     1 = 1
                   AND ship_from_org_id = pn_organization_id
                   AND batch_id = ln_batch_id
                   AND SPLIT_CASE = 'Y'
                   AND brand = NVL (pv_brand, brand)
                   AND process_status = 'N';

            ln_batches   := CEIL (ln_max_seq / pn_batch_size);

            MERGE INTO xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T a
                 USING (SELECT line_id, NTILE (ln_batches) OVER (ORDER BY line_id) batch
                          FROM (SELECT DISTINCT line_id
                                  FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
                                 WHERE     SPLIT_CASE = 'Y'
                                       AND BATCH_ID = ln_batch_id
                                       AND brand = NVL (pv_brand, brand)
                                       AND process_status = 'N'
                                       AND ship_from_org_id =
                                           pn_organization_id)) b
                    ON (a.line_id = b.line_id)
            WHEN MATCHED
            THEN
                UPDATE SET line_seq_number   = b.batch;
        END IF;

        COMMIT;

        FOR i IN 1 .. ln_batches
        LOOP
            LOOP
                SELECT COUNT (*)
                  INTO ln_child_req
                  FROM fnd_concurrent_programs fcp, fnd_concurrent_requests fc
                 WHERE     fcp.concurrent_program_name =
                           'XXD_ONT_AUTO_ATP_LEVL_WORKER'
                       AND fc.concurrent_program_id =
                           fcp.concurrent_program_id
                       AND fc.parent_request_id = fnd_global.conc_request_id
                       AND fc.phase_code IN ('R', 'P');

                IF ln_child_req >= ln_threads
                THEN
                    DBMS_LOCK.Sleep (10);
                ELSE
                    EXIT;
                END IF;
            END LOOP;

            ln_from_seq_num   := i;
            ln_to_seq_num     := i;

            write_log ('To Sequence Number: ' || ln_to_seq_num);
            write_log ('pv_brand: ' || pv_brand);
            write_log ('pn_organization_id: ' || pn_organization_id);
            write_log ('ln_batch_id: ' || ln_batch_id);
            --submit the concurrent program to reschedule order lines by brand
            --by spawining the request for every ln_max_rec_cnt
            ln_resched_req_id   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_ONT_AUTO_ATP_LEVL_WORKER',
                    description   => 'Deckers Processing Move Worker Program',
                    start_time    => SYSDATE,
                    sub_request   => FALSE, --TRUE, --This program will be submitted as a Child request
                    argument1     => ln_batch_id,
                    argument2     => pn_organization_id,
                    argument3     => pv_brand,
                    argument4     => ln_from_seq_num,
                    argument5     => ln_to_seq_num,
                    argument6     => pv_Processing_Move,
                    argument7     => pv_exclude);

            COMMIT;

            IF ln_resched_req_id = 0
            THEN
                write_log (
                       'Rescheduling concurrent request failed to submit for seq number from: '
                    || ln_from_seq_num
                    || ' to: '
                    || ln_to_seq_num);
                write_log (
                       'Timestamp: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            ELSE
                write_log (
                       'Successfully Submitted the Rescheduling Concurrent Request for seq number from: '
                    || ln_from_seq_num
                    || ' to: '
                    || ln_to_seq_num
                    || ' and Request Id is '
                    || ln_resched_req_id);
                write_log (
                       'Timestamp: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in purge_data procedure: ' || SQLERRM);
            raise_application_error (
                -20020,
                'Error in Procedure launch_worker_programs ' || SQLERRM);
    END launch_worker_programs;


    /************************************************************************************************/
    --This procedure takes batch_id, Inv Org, Brand, seq num from and seq num to as input parameters
    -- and picks up all the order lines for these parameters
    --and tries to reschedule them using OE_ORDER_PUB.process_order API
    /************************************************************************************************/
    PROCEDURE xxd_process_orders (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2, pn_from_seq_num IN NUMBER
                                  , pn_to_seq_num IN NUMBER, pv_order_move IN VARCHAR2, pv_exclude IN VARCHAR2)
    IS
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_header_rec_x                 oe_order_pub.header_rec_type;
        l_line_tbl_x                   oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        lv_so_line_cur                 VARCHAR2 (32000);
        lv_so_line_act_cur             VARCHAR2 (32000);
        lv_exclude_cond                VARCHAR2 (500);
        lv_process_move_cond           VARCHAR2 (500);
        ln_exclude_org                 NUMBER;
        ln_exclude_OU                  NUMBER;
        ln_exclude_brand               NUMBER;
        ln_exclude_div                 NUMBER;
        ln_exclude_dept                NUMBER;
        ln_exclude_cust                NUMBER;
        ln_exclude_ord_type            NUMBER;
        ln_exclude_sales_chnl          NUMBER;
        ln_exclude_dem_class           NUMBER;
        ln_exclude_req_from_dt         NUMBER;
        ln_exclude_req_to_dt           NUMBER;
        ln_exclude_ord_source          NUMBER;
        lv_exclude_org                 VARCHAR2 (4000);
        lv_exclude_OU                  VARCHAR2 (4000);
        lv_exclude_brand               VARCHAR2 (4000);
        lv_exclude_div                 VARCHAR2 (4000);
        lv_exclude_dept                VARCHAR2 (4000);
        lv_exclude_cust                VARCHAR2 (4000);
        lv_exclude_ord_type            VARCHAR2 (4000);
        lv_exclude_sales_chnl          VARCHAR2 (4000);
        lv_exclude_dem_class           VARCHAR2 (4000);
        lv_exclude_req_dt              VARCHAR2 (5000);
        lv_exclude_ord_source          VARCHAR2 (4000);
        ln_bulk_split_success          NUMBER := 0;
        ln_bulk_split_err              NUMBER := 0;
        ln_atp_current_available_qty   NUMBER := 0;
        ln_new_line_split_qty          NUMBER := 0;
        lc_atp_return_status           VARCHAR2 (1);
        lc_atp_error_message           VARCHAR2 (4000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := fnd_api.g_false;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_old_header_rec               oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_header_val_rec               oe_order_pub.header_val_rec_type
            := oe_order_pub.g_miss_header_val_rec;
        p_old_header_val_rec           oe_order_pub.header_val_rec_type
            := oe_order_pub.g_miss_header_val_rec;
        p_header_adj_tbl               oe_order_pub.header_adj_tbl_type
            := oe_order_pub.g_miss_header_adj_tbl;
        p_old_header_adj_tbl           oe_order_pub.header_adj_tbl_type
            := oe_order_pub.g_miss_header_adj_tbl;
        p_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type
            := oe_order_pub.g_miss_header_adj_val_tbl;
        p_old_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type
            := oe_order_pub.g_miss_header_adj_val_tbl;
        p_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_old_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_old_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_old_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_old_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_old_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_line_tbl                     oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_old_line_tbl                 oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_line_val_tbl                 oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_old_line_val_tbl             oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_line_adj_tbl                 oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_old_line_adj_tbl             oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_old_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_old_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_old_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_old_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_old_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_old_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_old_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_old_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_action_request_tbl           oe_order_pub.request_tbl_type
                                           := oe_order_pub.g_miss_request_tbl;
        x_header_val_rec               oe_order_pub.header_val_rec_type;
        x_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl                 oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl           oe_order_pub.request_tbl_type;
        x_debug_file                   VARCHAR2 (100);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);
        x_errbuf                       VARCHAR2 (200);
        x_retcode                      VARCHAR2 (200);
        l_row_num                      NUMBER := 0;
        l_row_num_err                  NUMBER := 0;
        l_message_data                 VARCHAR2 (2000);
        ln_resp_id                     NUMBER := 0;
        ln_resp_appl_id                NUMBER := 0;
        ln_conc_request_id             NUMBER
                                           := apps.fnd_global.conc_request_id;
        l_unsched_row_num              NUMBER := 0;
        l_unsched_row_num_err          NUMBER := 0;
        lv_unschedule                  VARCHAR2 (200);
        lv_brand_cond                  VARCHAR2 (200);
        lv_execution_order_cond        VARCHAR2 (200);


        TYPE so_line_rec_type
            IS RECORD
        (
            batch_id                  xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.batch_id%TYPE,
            org_id                    xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.org_id%TYPE,
            ship_from_org_id          xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.ship_from_org_id%TYPE,
            brand                     xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.brand%TYPE,
            sku                       xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.item_number%TYPE,
            inventory_item_id         xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.inventory_item_id%TYPE,
            Customer_id               xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.sold_to_org_id%TYPE,
            header_id                 xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.header_id%TYPE,
            line_id                   xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.line_id%TYPE,
            demand_class_code         xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.demand_class_code%TYPE,
            schedule_ship_date        xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.schedule_ship_date%TYPE,
            new_schedule_ship_date    xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.latest_acceptable_date%TYPE,
            latest_acceptable_date    xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.latest_acceptable_date%TYPE,
            request_date              xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.request_date%TYPE,
            override_atp_flag         xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.override_atp_flag%TYPE,
            atp_postive_date          xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.atp_postive_date%TYPE,
            style_number              xxd_common_items_v.style_number%TYPE,
            color_code                xxd_common_items_v.color_code%TYPE,
            division                  xxd_common_items_v.division%TYPE,
            department                xxd_common_items_v.department%TYPE,
            order_source_id           oe_order_headers_all.order_source_id%TYPE,
            ordered_quantity          xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T.ordered_quantity%TYPE,
            split_order               VARCHAR2 (240),
            split_case                VARCHAR2 (240),
            bulk_order_flag           VARCHAR2 (10)
        );

        TYPE so_line_type IS TABLE OF so_line_rec_type
            INDEX BY BINARY_INTEGER;

        so_line_rec                    so_line_type;

        TYPE so_line_typ IS REF CURSOR;

        so_line_cur                    so_line_typ;


        --Cursor to identify unique operating units
        CURSOR inv_org_ou_cur (cn_batch_id IN NUMBER, cn_organization_id IN NUMBER, cv_brand IN VARCHAR2)
        IS
              SELECT stg.org_id, stg.ship_from_org_id
                FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T stg
               WHERE     1 = 1
                     AND stg.batch_id = cn_batch_id
                     AND stg.ship_from_org_id = cn_organization_id
                     AND stg.brand = NVL (cv_brand, stg.brand)
                     AND stg.process_status = 'N'                --NEW records
                     AND stg.line_seq_number BETWEEN pn_from_seq_num
                                                 AND pn_to_seq_num
            GROUP BY stg.org_id, stg.ship_from_org_id
            ORDER BY stg.org_id;
    BEGIN
        --Below setting is a session specific one. No need to reset it back to Yes
        apps.fnd_profile.put ('MRP_ATP_CALC_SD', 'N'); --'MRP: Calculate Supply Demand' profile set to No

        write_log ('pv_brand: ' || pv_brand);
        write_log ('pn_batch_id: ' || pn_batch_id);
        write_log ('pn_organization_id: ' || pn_organization_id);
        write_log ('pn_from_seq_num: ' || pn_from_seq_num);
        write_log ('pn_to_seq_num: ' || pn_to_seq_num);
        write_log ('pv_order_move: ' || pv_order_move);

        FOR inv_org_ou_rec
            IN inv_org_ou_cur (pn_batch_id, pn_organization_id, pv_brand)
        LOOP
            ln_resp_id        := NULL;
            ln_resp_appl_id   := NULL;

            BEGIN
                --Getting the responsibility and application to initialize and set the context to reschedule order lines
                SELECT frv.responsibility_id, frv.application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                       apps.hr_organization_units hou
                 WHERE     1 = 1
                       AND hou.organization_id = inv_org_ou_rec.org_id
                       AND fpov.profile_option_value =
                           TO_CHAR (hou.organization_id)
                       AND fpo.profile_option_id = fpov.profile_option_id
                       AND fpo.user_profile_option_name =
                           'MO: Operating Unit'
                       AND frv.responsibility_id = fpov.level_value
                       AND frv.application_id = 660                      --ONT
                       AND frv.responsibility_name LIKE
                               'Deckers Order Management User%' --OM Responsibility
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (frv.start_date)
                                               AND TRUNC (
                                                       NVL (frv.end_date,
                                                            SYSDATE))
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                        'Error getting the responsibility ID : ' || SQLERRM);
            END;

            --fnd_global.apps_initialize (1697, 50744, 660);
            write_log ('Org ID : ' || inv_org_ou_rec.org_id);
            write_log ('Inv Org ID : ' || inv_org_ou_rec.ship_from_org_id);
            write_log ('User ID : ' || gn_user_id);
            write_log ('Resp ID : ' || ln_resp_id);
            write_log ('Resp Appl ID : ' || ln_resp_appl_id);

            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', inv_org_ou_rec.org_id);

            BEGIN
                --Passing the line ID to Process Order API to Reschedule the line.
                --It will first unschedules the line and then tries to Reschedule it. If successful, issues a commit else Rollsback the changes

                -- Start of building the SO Line Cursor
                lv_so_line_cur          :=
                       ' SELECT  stg.batch_id,
                                      stg.org_id org_id,
                                      stg.ship_from_org_id,
                                      stg.brand,
                                      stg.item_number sku,
                                      stg.inventory_item_id,
                                      stg.sold_to_org_id Customer_id,
                                      stg.header_id,
                                      stg.line_id,
                                      ''-1'' demand_class_code,
                                      stg.schedule_ship_date, 
                                      stg.new_ssd new_schedule_ship_date,
									  stg.new_lad latest_acceptable_date,
                                      stg.request_date,
                                      stg.override_atp_flag,
									  stg.atp_postive_date,
                                      xxitems.style_number,
                                      xxitems.color_code,
                                      xxitems.division,
                                      xxitems.department,
                                      ooha.order_source_id,
                                      stg.ordered_quantity,
									  NVL(stg.order_split_type,''NONE'') split_order,
									   stg.split_case,
                                       DECODE(otta.attribute5,''BO'',''Y'',''N'')
                                       bulk_order_flag
                                FROM  xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T stg,
                                      xxd_common_items_v xxitems,
                                      oe_order_headers_all ooha,
									  oe_transaction_types_all otta
                               WHERE  stg.inventory_item_id = xxitems.inventory_item_id
									AND  stg.ship_from_org_id = xxitems.organization_id
                                 AND  ooha.header_id = stg.header_id
								 AND  ooha.order_type_id=otta.transaction_type_id
                                 AND  stg.line_seq_number BETWEEN '
                    || pn_from_seq_num
                    || ' AND '
                    || pn_to_seq_num
                    || ' 
                        AND  stg.process_status=''N'' 
                        AND  stg.batch_id = '
                    || pn_batch_id
                    || ' AND  stg.org_id = '
                    || inv_org_ou_rec.org_id
                    || ' AND  stg.ship_from_org_id = '
                    || inv_org_ou_rec.ship_from_org_id
                    || '';

                IF pv_brand IS NOT NULL
                THEN
                    lv_brand_cond   :=
                        ' AND stg.brand =''' || pv_brand || '''';
                END IF;

                IF pv_order_move = 'SAFE_MOVE'
                THEN
                    lv_unschedule          := 'N';
                    lv_process_move_cond   := ' AND sf_ex_flag =''Y''';
                ELSIF pv_order_move = 'ATRISK_MOVE'
                THEN
                    lv_process_move_cond   := ' AND ar_ex_flag =''Y''';
                    lv_unschedule          := 'N';
                ELSIF pv_order_move = 'UNSCHEDULE_MOVE'
                THEN
                    lv_process_move_cond   :=
                        ' AND un_ex_flag =''Y''   AND NVL(SPLIT_CASE,''N'') =''N''';
                    lv_unschedule   := 'Y';
                ELSIF pv_order_move = 'SPLIT_CASE'
                THEN
                    lv_process_move_cond   :=
                        ' AND un_ex_flag =''Y''   AND NVL(SPLIT_CASE,''N'') =''Y''';
                    lv_unschedule   := 'Y';
                END IF;

                lv_execution_order_cond   :=
                    ' order by stg.schedule_ship_date desc ';

                --Initialization of variables to default as query built is outside the IF condition
                lv_exclude_org          := ' AND 1=1';
                lv_exclude_OU           := ' AND 1=1';
                lv_exclude_brand        := ' AND 1=1';
                lv_exclude_div          := ' AND 1=1';
                lv_exclude_dept         := ' AND 1=1';
                lv_exclude_cust         := ' AND 1=1';
                lv_exclude_ord_type     := ' AND 1=1';
                lv_exclude_sales_chnl   := ' AND 1=1';
                lv_exclude_dem_class    := ' AND 1=1';
                lv_exclude_req_dt       := ' AND 1=1';
                lv_exclude_cond         := ' AND 1=1';
                lv_exclude_ord_source   := ' AND 1=1';

                IF pv_exclude IS NOT NULL AND pv_exclude = 'LOOKUP_DRIVEN'
                THEN
                    ln_exclude_org           := 0;
                    ln_exclude_OU            := 0;
                    ln_exclude_brand         := 0;
                    ln_exclude_div           := 0;
                    ln_exclude_dept          := 0;
                    ln_exclude_cust          := 0;
                    ln_exclude_ord_type      := 0;
                    ln_exclude_sales_chnl    := 0;
                    ln_exclude_dem_class     := 0;
                    ln_exclude_req_from_dt   := 0;
                    ln_exclude_req_to_dt     := 0;
                    ln_exclude_ord_source    := 0;

                    BEGIN
                        SELECT COUNT (attribute1), COUNT (attribute2), COUNT (attribute3),
                               COUNT (attribute4), COUNT (attribute5), COUNT (attribute6),
                               COUNT (attribute7), COUNT (attribute8), COUNT (attribute9),
                               COUNT (attribute10), COUNT (attribute11), COUNT (attribute12)
                          INTO ln_exclude_org, ln_exclude_OU, ln_exclude_brand, ln_exclude_div,
                                             ln_exclude_dept, ln_exclude_cust, ln_exclude_ord_type,
                                             ln_exclude_sales_chnl, ln_exclude_dem_class, ln_exclude_req_from_dt,
                                             ln_exclude_req_to_dt, ln_exclude_ord_source
                          FROM apps.fnd_lookup_values
                         WHERE     lookup_type =
                                   'XXD_NEG_ATP_RESCH_EXCLUSIONS'
                               AND language = 'US'
                               AND enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (start_date_active,
                                                        SYSDATE)
                                               AND NVL (end_date_active,
                                                        SYSDATE + 1);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_exclude_org           := 0;
                            ln_exclude_OU            := 0;
                            ln_exclude_brand         := 0;
                            ln_exclude_div           := 0;
                            ln_exclude_dept          := 0;
                            ln_exclude_cust          := 0;
                            ln_exclude_ord_type      := 0;
                            ln_exclude_sales_chnl    := 0;
                            ln_exclude_dem_class     := 0;
                            ln_exclude_req_from_dt   := 0;
                            ln_exclude_req_to_dt     := 0;
                            ln_exclude_ord_source    := 0;
                    END;

                    IF ln_exclude_org > 0
                    THEN
                        lv_exclude_org   :=
                            ' AND stg.ship_from_org_id NOT IN (SELECT TO_NUMBER(attribute1) 
                              FROM apps.fnd_lookup_values 
                             WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                               AND enabled_flag = ''Y''
                               AND language = ''US'' 
                               AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_org   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_OU > 0
                    THEN
                        lv_exclude_OU   :=
                            ' AND stg.org_id NOT IN (SELECT TO_NUMBER(attribute2)
                            FROM apps.fnd_lookup_values 
                           WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                             AND enabled_flag = ''Y''
                             AND language = ''US'' 
                             AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_OU   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_brand > 0
                    THEN
                        lv_exclude_brand   :=
                            ' AND stg.brand NOT IN (SELECT attribute3 
                           FROM apps.fnd_lookup_values 
                          WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                            AND enabled_flag = ''Y''
                            AND language = ''US'' 
                            AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_brand   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_div > 0
                    THEN
                        lv_exclude_div   :=
                            ' AND xxitems.division NOT IN (SELECT attribute4 
                            FROM apps.fnd_lookup_values 
                           WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                             AND enabled_flag = ''Y''
                             AND language = ''US'' 
                             AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_div   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_dept > 0
                    THEN
                        lv_exclude_dept   :=
                            ' AND xxitems.department NOT IN (SELECT attribute5 
                             FROM apps.fnd_lookup_values 
                            WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                              AND enabled_flag = ''Y''
                              AND language = ''US'' 
                              AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_dept   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_cust > 0
                    THEN
                        lv_exclude_cust   :=
                            ' AND stg.customer_id NOT IN (SELECT TO_NUMBER(attribute6) 
                           FROM apps.fnd_lookup_values 
                          WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                            AND enabled_flag = ''Y''
                            AND language = ''US'' 
                            AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_cust   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_ord_type > 0
                    THEN
                        lv_exclude_ord_type   :=
                            ' AND NOT EXISTS (SELECT  1
                         FROM  apps.oe_order_headers_all ooha
                        WHERE  ooha.header_id = stg.header_id
                          AND  ooha.order_type_id IN  (SELECT  TO_NUMBER(attribute7)
                                                         FROM  apps.fnd_lookup_values flv
                                                        WHERE  flv.lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                                                          AND  flv.enabled_flag = ''Y''
                                                          AND  flv.language = ''US'' 
                                                          AND  SYSDATE BETWEEN NVL(flv.start_date_active,SYSDATE) AND nvl(flv.end_date_active,SYSDATE+1)))';
                    ELSE
                        lv_exclude_ord_type   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_sales_chnl > 0
                    THEN
                        lv_exclude_sales_chnl   :=
                            ' AND NOT EXISTS  (SELECT  1
                        FROM  apps.oe_order_headers_all ooha
                       WHERE  ooha.header_id = stg.header_id
                         AND  ooha.sales_channel_code IN (SELECT  attribute8
                                                            FROM  apps.fnd_lookup_values flv
                                                           WHERE  flv.lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                                                             AND  flv.enabled_flag = ''Y''
                                                             AND  flv.language = ''US'' 
                                                             AND  SYSDATE BETWEEN NVL(flv.start_date_active,SYSDATE) AND nvl(flv.end_date_active,SYSDATE+1)))';
                    ELSE
                        lv_exclude_sales_chnl   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_dem_class > 0
                    THEN
                        lv_exclude_dem_class   :=
                            ' AND stg.demand_class_code NOT IN  (SELECT attribute9 
                       FROM apps.fnd_lookup_values 
                      WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                        AND enabled_flag = ''Y''
                        AND language = ''US'' 
                        AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_dem_class   := ' AND 1=1';
                    END IF;

                    IF     ln_exclude_req_from_dt > 0
                       AND ln_exclude_req_to_dt > 0
                    THEN
                        lv_exclude_req_dt   :=
                            ' AND stg.request_date NOT BETWEEN (SELECT TO_DATE(attribute10, ''RRRR/MM/DD HH24:MI:SS'') 
                                   FROM apps.fnd_lookup_values 
                                  WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                                    AND enabled_flag = ''Y''
                                    AND language = ''US'' 
                                    AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) 
                            AND  (SELECT TO_DATE(attribute11, ''RRRR/MM/DD HH24:MI:SS'')+(1-1/86399) 
                                   FROM apps.fnd_lookup_values 
                                  WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                                    AND enabled_flag = ''Y''
                                    AND language = ''US'' 
                                    AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1))';

                        lv_exclude_req_dt   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_ord_source > 0
                    THEN
                        lv_exclude_ord_source   :=
                            ' AND NOT EXISTS (SELECT  1
                         FROM  apps.oe_order_headers_all ooha
                        WHERE  ooha.header_id = stg.header_id
                          AND  ooha.order_source_id IN  (SELECT  TO_NUMBER(attribute12)
                                                         FROM  apps.fnd_lookup_values flv
                                                        WHERE  flv.lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                                                          AND  flv.enabled_flag = ''Y''
                                                          AND  flv.language = ''US'' 
                                                          AND  SYSDATE BETWEEN NVL(flv.start_date_active,SYSDATE) AND nvl(flv.end_date_active,SYSDATE+1)))';
                    ELSE
                        lv_exclude_ord_source   := ' AND 1=1';
                    END IF;
                --Driven by lookup End if
                ELSIF pv_exclude IS NOT NULL AND pv_exclude = 'NONE'
                THEN
                    lv_exclude_cond   := ' AND 1=1';
                ELSIF     pv_exclude IS NOT NULL
                      AND pv_exclude = 'ALL_LINES_WITH_ATP_OVERRIDE'
                THEN
                    lv_exclude_cond   :=
                        ' AND NVL(stg.override_atp_flag, ''N'') <> ''Y''';
                ELSIF pv_exclude IS NOT NULL AND pv_exclude = 'ALL_ISO'
                THEN
                    lv_exclude_cond   := ' AND ooha.order_source_id <> 10 ';
                ELSIF     pv_exclude IS NOT NULL
                      AND pv_exclude = 'ISO_WITH_OVERRIDE_ATP'
                THEN
                    lv_exclude_cond   :=
                        ' AND (ooha.order_source_id <> 10 AND NVL(stg.override_atp_flag, ''N'') <> ''Y'')';
                ELSE
                    lv_exclude_cond   := ' AND 1=1';
                END IF;

                write_log (
                       'ln_exclude_ord_source '
                    || ln_exclude_ord_source
                    || ' ln_exclude_ord_type '
                    || ln_exclude_ord_type);

                lv_so_line_act_cur      :=
                       lv_so_line_cur
                    || lv_process_move_cond
                    || lv_exclude_org
                    || lv_exclude_ou
                    || lv_exclude_brand
                    || lv_exclude_div
                    || lv_exclude_dept
                    || lv_exclude_cust
                    || lv_exclude_ord_type
                    || lv_exclude_sales_chnl
                    || lv_exclude_dem_class
                    || lv_exclude_req_dt
                    || lv_exclude_ord_source
                    || lv_exclude_cond
                    || lv_execution_order_cond;

                write_log ('-------------------------------------------');
                write_log ('Rescheduled Orders query: ');
                write_log (
                       'Timestamp: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                write_log ('-------------------------------------------');
                write_log (lv_so_line_act_cur);
                write_log ('-------------------------------------------');


                OPEN so_line_cur FOR lv_so_line_act_cur;

                FETCH so_line_cur BULK COLLECT INTO so_line_rec;

                CLOSE so_line_cur;


                IF so_line_rec.COUNT > 0
                THEN
                    FOR i IN so_line_rec.FIRST .. so_line_rec.LAST
                    LOOP
                        l_return_status   := NULL;
                        l_msg_data        := NULL;
                        l_message_data    := NULL;


                        IF lv_unschedule = 'N'
                        THEN
                            write_log ('Inside UNSCHEDULE: N');
                            oe_msg_pub.initialize;
                            oe_debug_pub.initialize;
                            l_line_tbl.delete ();
                            l_line_tbl_index   := 1;
                            l_line_tbl (l_line_tbl_index)   :=
                                oe_order_pub.g_miss_line_rec;
                            l_line_tbl (l_line_tbl_index).operation   :=
                                oe_globals.g_opr_update;
                            l_line_tbl (l_line_tbl_index).org_id   :=
                                so_line_rec (i).org_id;
                            l_line_tbl (l_line_tbl_index).header_id   :=
                                so_line_rec (i).header_id;
                            l_line_tbl (l_line_tbl_index).line_id   :=
                                so_line_rec (i).line_id;

                            IF pv_order_move = 'ATRISK_MOVE'
                            THEN
                                l_line_tbl (l_line_tbl_index).latest_acceptable_date   :=
                                    NVL (
                                        so_line_rec (i).latest_acceptable_date,
                                        SYSDATE);
                            END IF;

                            l_line_tbl (l_line_tbl_index).schedule_action_code   :=
                                'RESCHEDULE';            --Rescheduling Action
                            --l_line_tbl (l_line_tbl_index).override_atp_date_code := 'N';

                            --To rollback to this point
                            --SAVEPOINT reschedule;
                            oe_order_pub.process_order (
                                p_api_version_number   => 1.0,
                                p_init_msg_list        => fnd_api.g_true,
                                p_return_values        => fnd_api.g_true,
                                p_action_commit        => fnd_api.g_false,
                                x_return_status        => l_return_status,
                                x_msg_count            => l_msg_count,
                                x_msg_data             => l_msg_data,
                                p_header_rec           => l_header_rec,
                                p_line_tbl             => l_line_tbl,
                                p_action_request_tbl   => l_action_request_tbl,
                                x_header_rec           => l_header_rec_x,
                                x_header_val_rec       => x_header_val_rec,
                                x_header_adj_tbl       => x_header_adj_tbl,
                                x_header_adj_val_tbl   => x_header_adj_val_tbl,
                                x_header_price_att_tbl   =>
                                    x_header_price_att_tbl,
                                x_header_adj_att_tbl   => x_header_adj_att_tbl,
                                x_header_adj_assoc_tbl   =>
                                    x_header_adj_assoc_tbl,
                                x_header_scredit_tbl   => x_header_scredit_tbl,
                                x_header_scredit_val_tbl   =>
                                    x_header_scredit_val_tbl,
                                x_line_tbl             => l_line_tbl_x,
                                x_line_val_tbl         => x_line_val_tbl,
                                x_line_adj_tbl         => x_line_adj_tbl,
                                x_line_adj_val_tbl     => x_line_adj_val_tbl,
                                x_line_price_att_tbl   => x_line_price_att_tbl,
                                x_line_adj_att_tbl     => x_line_adj_att_tbl,
                                x_line_adj_assoc_tbl   => x_line_adj_assoc_tbl,
                                x_line_scredit_tbl     => x_line_scredit_tbl,
                                x_line_scredit_val_tbl   =>
                                    x_line_scredit_val_tbl,
                                x_lot_serial_tbl       => x_lot_serial_tbl,
                                x_lot_serial_val_tbl   => x_lot_serial_val_tbl,
                                x_action_request_tbl   => l_action_request_tbl);

                            IF l_return_status = fnd_api.g_ret_sts_success
                            THEN
                                --write_log( 'Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);
                                --dbms_output.put_line ('Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);
                                --NULL;
                                --rollback to reschedule;
                                l_row_num   := l_row_num + 1;
                            --xv_schedule_ship_date := l_line_tbl_x(l_line_tbl_index).schedule_ship_date;
                            --xv_schedule_ship_date := TO_CHAR(l_line_tbl_x(l_line_tbl_index).schedule_ship_date,'DD-MON-RRRR');
                            ELSE
                                --dbms_output.put_line ('E');
                                --write_log( 'Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);
                                --dbms_output.put_line ('Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);

                                FOR i IN 1 .. l_msg_count
                                LOOP
                                    oe_msg_pub.get (
                                        p_msg_index       => i,
                                        p_encoded         => fnd_api.g_false,
                                        p_data            => l_msg_data,
                                        p_msg_index_out   => l_msg_index_out);

                                    l_message_data   :=
                                        l_message_data || l_msg_data;
                                --write_log( 'Error: ' || l_msg_data);
                                --write_log( 'Error for Line ID:'||resched_ord_line_rec.line_id||'  is :' ||l_msg_data);
                                --dbms_output.put_line ('Error: ' || l_msg_data);
                                --dbms_output.put_line ('Error for Line ID:'||resched_ord_line_rec.line_id||'  is :' ||l_msg_data);
                                END LOOP;

                                --ROLLBACK TO reschedule;
                                l_row_num_err   := l_row_num_err + 1;
                                ROLLBACK;
                            END IF;

                            write_log (
                                   'updating the staging table for line ID - '
                                || so_line_rec (i).line_id
                                || ' Batch '
                                || so_line_rec (i).batch_id);

                            --Updating the staging table with status and other relevant information
                            BEGIN
                                UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T xoa
                                   SET xoa.process_status = l_return_status, error_message = l_message_data, xoa.new_ssd = l_line_tbl_x (l_line_tbl_index).schedule_ship_date,
                                       xoa.last_update_date = SYSDATE, xoa.child_req_id = ln_conc_request_id
                                 WHERE     xoa.line_id =
                                           so_line_rec (i).line_id
                                       AND xoa.batch_id =
                                           so_line_rec (i).batch_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    write_log (
                                           'Error while updating the staging table for line ID - '
                                        || so_line_rec (i).line_id);
                            END;

                            COMMIT;
                        --unschedule the lines which are not successfully rescheduled based on user input(pv_unschedule = Yes or No)
                        -- IF (    l_return_status <> fnd_api.g_ret_sts_success
                        --If return status is not success(Failed to Reschedule)
                        ELSIF lv_unschedule = 'Y'           --Unschedule = Yes
                        THEN
                            -- xxd_ont_order_utils_pkg.gc_skip_neg_unconsumption := 'N';
                            write_log ('Inside UNSCHEDULE: Y ');

                            l_return_status    := NULL;
                            l_msg_data         := NULL;
                            l_message_data     := NULL;
                            oe_msg_pub.initialize;
                            oe_debug_pub.initialize;
                            l_line_tbl.delete ();
                            l_line_tbl_index   := 1;
                            l_line_tbl (l_line_tbl_index)   :=
                                oe_order_pub.g_miss_line_rec;
                            l_line_tbl (l_line_tbl_index).operation   :=
                                oe_globals.g_opr_update;
                            l_line_tbl (l_line_tbl_index).org_id   :=
                                so_line_rec (i).org_id;
                            l_line_tbl (l_line_tbl_index).header_id   :=
                                so_line_rec (i).header_id;
                            l_line_tbl (l_line_tbl_index).line_id   :=
                                so_line_rec (i).line_id;
                            l_line_tbl (l_line_tbl_index).schedule_action_code   :=
                                'UNSCHEDULE';            --Unscheduling Action

                            -- IF so_line_rec (i).atp_postive_date IS NULL
                            -- THEN
                            xxd_ont_order_utils_pkg.gc_skip_neg_unconsumption   :=
                                'Y';
                            --   END IF;
                            --l_line_tbl (l_line_tbl_index).override_atp_date_code := 'N';

                            oe_order_pub.process_order (
                                p_api_version_number   => 1.0,
                                p_init_msg_list        => fnd_api.g_true,
                                p_return_values        => fnd_api.g_true,
                                p_action_commit        => fnd_api.g_false,
                                x_return_status        => l_return_status,
                                x_msg_count            => l_msg_count,
                                x_msg_data             => l_msg_data,
                                p_header_rec           => l_header_rec,
                                p_line_tbl             => l_line_tbl,
                                p_action_request_tbl   => l_action_request_tbl,
                                x_header_rec           => l_header_rec_x,
                                x_header_val_rec       => x_header_val_rec,
                                x_header_adj_tbl       => x_header_adj_tbl,
                                x_header_adj_val_tbl   => x_header_adj_val_tbl,
                                x_header_price_att_tbl   =>
                                    x_header_price_att_tbl,
                                x_header_adj_att_tbl   => x_header_adj_att_tbl,
                                x_header_adj_assoc_tbl   =>
                                    x_header_adj_assoc_tbl,
                                x_header_scredit_tbl   => x_header_scredit_tbl,
                                x_header_scredit_val_tbl   =>
                                    x_header_scredit_val_tbl,
                                x_line_tbl             => l_line_tbl_x,
                                x_line_val_tbl         => x_line_val_tbl,
                                x_line_adj_tbl         => x_line_adj_tbl,
                                x_line_adj_val_tbl     => x_line_adj_val_tbl,
                                x_line_price_att_tbl   => x_line_price_att_tbl,
                                x_line_adj_att_tbl     => x_line_adj_att_tbl,
                                x_line_adj_assoc_tbl   => x_line_adj_assoc_tbl,
                                x_line_scredit_tbl     => x_line_scredit_tbl,
                                x_line_scredit_val_tbl   =>
                                    x_line_scredit_val_tbl,
                                x_lot_serial_tbl       => x_lot_serial_tbl,
                                x_lot_serial_val_tbl   => x_lot_serial_val_tbl,
                                x_action_request_tbl   => l_action_request_tbl);

                            xxd_ont_order_utils_pkg.gc_skip_neg_unconsumption   :=
                                'N';

                            IF l_return_status = fnd_api.g_ret_sts_success
                            THEN
                                write_log (
                                       'Line ID:'
                                    || so_line_rec (i).line_id
                                    || ' Status is :'
                                    || l_return_status);
                                --dbms_output.put_line ('Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);
                                --NULL;
                                --rollback to reschedule;
                                l_unsched_row_num   := l_unsched_row_num + 1;
                            --xv_schedule_ship_date := l_line_tbl_x(l_line_tbl_index).schedule_ship_date;
                            --xv_schedule_ship_date := TO_CHAR(l_line_tbl_x(l_line_tbl_index).schedule_ship_date,'DD-MON-RRRR');
                            ELSE
                                --dbms_output.put_line ('E');
                                write_log (
                                       'Line ID:'
                                    || so_line_rec (i).line_id
                                    || ' Status is :'
                                    || l_return_status);

                                --dbms_output.put_line ('Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);

                                FOR i IN 1 .. l_msg_count
                                LOOP
                                    oe_msg_pub.get (
                                        p_msg_index       => i,
                                        p_encoded         => fnd_api.g_false,
                                        p_data            => l_msg_data,
                                        p_msg_index_out   => l_msg_index_out);

                                    l_message_data   :=
                                        l_message_data || l_msg_data;
                                END LOOP;

                                --ROLLBACK TO reschedule;
                                l_unsched_row_num_err   :=
                                    l_unsched_row_num_err + 1;
                            END IF;

                            IF l_return_status <> fnd_api.g_ret_sts_success
                            THEN
                                l_return_status   := 'X'; --Unscheduling Failed
                            ELSE
                                l_return_status   := 'Z'; --Unscheduling Successful
                            END IF;

                            --Updating the staging table with unscheduling status and other relevant information
                            BEGIN
                                UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T xoa
                                   SET xoa.process_status = l_return_status, xoa.error_message = l_message_data, xoa.last_update_date = SYSDATE,
                                       xoa.child_req_id = ln_conc_request_id
                                 WHERE     xoa.line_id =
                                           so_line_rec (i).line_id
                                       AND xoa.batch_id =
                                           so_line_rec (i).batch_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    write_log (
                                           'Error while updating the Unscheduling status to staging table for line ID - '
                                        || so_line_rec (i).line_id);
                            END;

                            COMMIT;
                        END IF;

                        /****************************************************************************************
                         * If unscheduling is success, then try split and schedule for bulks
                         ****************************************************************************************/
                        IF    (l_return_status = 'Z' AND so_line_rec (i).split_case = 'Y' AND so_line_rec (i).split_order = 'ALL')
                           OR (l_return_status = 'Z' AND so_line_rec (i).split_case = 'Y' AND so_line_rec (i).bulk_order_flag = 'Y' AND so_line_rec (i).split_order = 'BULK')
                        THEN
                            write_log ('Inside Split: ');
                            ln_atp_current_available_qty   := 0;
                            ln_new_line_split_qty          := 0;
                            lc_atp_return_status           := NULL;
                            lc_atp_error_message           := NULL;

                            /****************************************************************************************
                             * ATP check and calculate the available qty
                             ****************************************************************************************/
                            get_atp_qty (
                                p_line_id         => so_line_rec (i).line_id,
                                x_atp_current_available_qty   =>
                                    ln_atp_current_available_qty,
                                x_return_status   => lc_atp_return_status,
                                x_error_message   => lc_atp_error_message);

                            IF    lc_atp_return_status <>
                                  fnd_api.g_ret_sts_success
                               OR ln_atp_current_available_qty = 0
                            THEN
                                IF so_line_rec (i).bulk_order_flag = 'Y'
                                THEN
                                    l_return_status   := 'BUL-ATP-F';
                                    l_message_data    :=
                                        'Bulk ATP Check Failed';
                                ELSE
                                    l_return_status   := 'ATP-F';
                                    l_message_data    := 'ATP Check Failed';
                                END IF;
                            ELSIF     lc_atp_return_status =
                                      fnd_api.g_ret_sts_success
                                  AND ln_atp_current_available_qty > 0
                            THEN
                                ln_new_line_split_qty              :=
                                      so_line_rec (i).ordered_quantity
                                    - ln_atp_current_available_qty;

                                /****************************************************************************************
                                 * Order line split based on available qty
                                 ****************************************************************************************/
                                l_return_status                    := NULL;
                                l_msg_data                         := NULL;
                                l_message_data                     := NULL;
                                oe_msg_pub.initialize;
                                oe_debug_pub.initialize;
                                l_line_tbl.delete ();

                                l_header_rec                       :=
                                    oe_order_pub.g_miss_header_rec;
                                l_line_tbl                         :=
                                    oe_order_pub.g_miss_line_tbl;
                                l_line_tbl (1)                     :=
                                    oe_order_pub.g_miss_line_rec;
                                l_line_tbl (1).header_id           :=
                                    so_line_rec (i).header_id;
                                l_line_tbl (1).org_id              :=
                                    so_line_rec (i).org_id;
                                l_line_tbl (1).line_id             :=
                                    so_line_rec (i).line_id;
                                l_line_tbl (1).split_action_code   := 'SPLIT';
                                l_line_tbl (1).split_by            :=
                                    gn_user_id;
                                l_line_tbl (1).ordered_quantity    :=
                                    ln_atp_current_available_qty;
                                l_line_tbl (1).operation           :=
                                    oe_globals.g_opr_update;
                                l_line_tbl (2)                     :=
                                    oe_order_pub.g_miss_line_rec;
                                l_line_tbl (2).header_id           :=
                                    so_line_rec (i).header_id;
                                l_line_tbl (2).org_id              :=
                                    so_line_rec (i).org_id;
                                l_line_tbl (2).split_action_code   := 'SPLIT';
                                l_line_tbl (2).split_by            := 'USER';
                                l_line_tbl (2).split_from_line_id   :=
                                    so_line_rec (i).line_id;
                                l_line_tbl (2).ordered_quantity    :=
                                    ln_new_line_split_qty;
                                l_line_tbl (2).request_id          :=
                                    ln_conc_request_id;
                                l_line_tbl (2).operation           :=
                                    oe_globals.g_opr_create;

                                oe_order_pub.process_order (
                                    p_api_version_number   => 1.0,
                                    p_init_msg_list        => fnd_api.g_true,
                                    p_return_values        => fnd_api.g_true,
                                    p_action_commit        => fnd_api.g_false,
                                    x_return_status        => l_return_status,
                                    x_msg_count            => l_msg_count,
                                    x_msg_data             => l_msg_data,
                                    p_header_rec           => l_header_rec,
                                    p_line_tbl             => l_line_tbl,
                                    p_action_request_tbl   =>
                                        l_action_request_tbl,
                                    x_header_rec           => l_header_rec_x,
                                    x_header_val_rec       => x_header_val_rec,
                                    x_header_adj_tbl       => x_header_adj_tbl,
                                    x_header_adj_val_tbl   =>
                                        x_header_adj_val_tbl,
                                    x_header_price_att_tbl   =>
                                        x_header_price_att_tbl,
                                    x_header_adj_att_tbl   =>
                                        x_header_adj_att_tbl,
                                    x_header_adj_assoc_tbl   =>
                                        x_header_adj_assoc_tbl,
                                    x_header_scredit_tbl   =>
                                        x_header_scredit_tbl,
                                    x_header_scredit_val_tbl   =>
                                        x_header_scredit_val_tbl,
                                    x_line_tbl             => l_line_tbl_x,
                                    x_line_val_tbl         => x_line_val_tbl,
                                    x_line_adj_tbl         => x_line_adj_tbl,
                                    x_line_adj_val_tbl     =>
                                        x_line_adj_val_tbl,
                                    x_line_price_att_tbl   =>
                                        x_line_price_att_tbl,
                                    x_line_adj_att_tbl     =>
                                        x_line_adj_att_tbl,
                                    x_line_adj_assoc_tbl   =>
                                        x_line_adj_assoc_tbl,
                                    x_line_scredit_tbl     =>
                                        x_line_scredit_tbl,
                                    x_line_scredit_val_tbl   =>
                                        x_line_scredit_val_tbl,
                                    x_lot_serial_tbl       => x_lot_serial_tbl,
                                    x_lot_serial_val_tbl   =>
                                        x_lot_serial_val_tbl,
                                    x_action_request_tbl   =>
                                        l_action_request_tbl);

                                write_log (
                                       'Bulk Split API Status :'
                                    || l_return_status);

                                IF l_return_status <>
                                   fnd_api.g_ret_sts_success
                                THEN
                                    FOR i IN 1 .. l_msg_count
                                    LOOP
                                        oe_msg_pub.get (
                                            p_msg_index   => i,
                                            p_encoded     => fnd_api.g_false,
                                            p_data        => l_msg_data,
                                            p_msg_index_out   =>
                                                l_msg_index_out);

                                        l_message_data   :=
                                            l_message_data || l_msg_data;
                                    END LOOP;

                                    write_log (
                                        'Split API Error :' || l_message_data);

                                    ln_bulk_split_err   :=
                                        ln_bulk_split_err + 1;

                                    IF so_line_rec (i).bulk_order_flag = 'Y'
                                    THEN
                                        l_return_status   := 'BUL-SPL-F';
                                        l_message_data    :=
                                            'Bulk Split Failed';
                                    ELSE
                                        l_return_status   := 'SPL-F';
                                        l_message_data    := 'Split Failed';
                                    END IF;
                                ELSE
                                    COMMIT;
                                    /****************************************************************************************
                                     * Schedule the original line
                                     ****************************************************************************************/
                                    l_return_status   := NULL;
                                    l_msg_data        := NULL;
                                    l_message_data    := NULL;
                                    oe_msg_pub.initialize;
                                    l_line_tbl.delete ();

                                    l_line_tbl        :=
                                        oe_order_pub.g_miss_line_tbl;
                                    l_line_tbl (1)    :=
                                        oe_order_pub.g_miss_line_rec;
                                    l_line_tbl (1).operation   :=
                                        oe_globals.g_opr_update;
                                    l_line_tbl (1).org_id   :=
                                        so_line_rec (i).org_id;
                                    l_line_tbl (1).header_id   :=
                                        so_line_rec (i).header_id;
                                    l_line_tbl (1).line_id   :=
                                        so_line_rec (i).line_id;
                                    l_line_tbl (1).schedule_action_code   :=
                                        'SCHEDULE';

                                    oe_order_pub.process_order (
                                        p_api_version_number   => 1.0,
                                        p_init_msg_list        =>
                                            fnd_api.g_true,
                                        p_return_values        =>
                                            fnd_api.g_true,
                                        p_action_commit        =>
                                            fnd_api.g_false,
                                        x_return_status        =>
                                            l_return_status,
                                        x_msg_count            => l_msg_count,
                                        x_msg_data             => l_msg_data,
                                        p_header_rec           => l_header_rec,
                                        p_line_tbl             => l_line_tbl,
                                        p_action_request_tbl   =>
                                            l_action_request_tbl,
                                        x_header_rec           =>
                                            l_header_rec_x,
                                        x_header_val_rec       =>
                                            x_header_val_rec,
                                        x_header_adj_tbl       =>
                                            x_header_adj_tbl,
                                        x_header_adj_val_tbl   =>
                                            x_header_adj_val_tbl,
                                        x_header_price_att_tbl   =>
                                            x_header_price_att_tbl,
                                        x_header_adj_att_tbl   =>
                                            x_header_adj_att_tbl,
                                        x_header_adj_assoc_tbl   =>
                                            x_header_adj_assoc_tbl,
                                        x_header_scredit_tbl   =>
                                            x_header_scredit_tbl,
                                        x_header_scredit_val_tbl   =>
                                            x_header_scredit_val_tbl,
                                        x_line_tbl             => l_line_tbl_x,
                                        x_line_val_tbl         =>
                                            x_line_val_tbl,
                                        x_line_adj_tbl         =>
                                            x_line_adj_tbl,
                                        x_line_adj_val_tbl     =>
                                            x_line_adj_val_tbl,
                                        x_line_price_att_tbl   =>
                                            x_line_price_att_tbl,
                                        x_line_adj_att_tbl     =>
                                            x_line_adj_att_tbl,
                                        x_line_adj_assoc_tbl   =>
                                            x_line_adj_assoc_tbl,
                                        x_line_scredit_tbl     =>
                                            x_line_scredit_tbl,
                                        x_line_scredit_val_tbl   =>
                                            x_line_scredit_val_tbl,
                                        x_lot_serial_tbl       =>
                                            x_lot_serial_tbl,
                                        x_lot_serial_val_tbl   =>
                                            x_lot_serial_val_tbl,
                                        x_action_request_tbl   =>
                                            l_action_request_tbl);
                                    write_log (
                                           'Bulk Schedule API Status :'
                                        || l_return_status);

                                    IF l_return_status =
                                       fnd_api.g_ret_sts_success
                                    THEN
                                        ln_bulk_split_success   :=
                                            ln_bulk_split_success + 1;

                                        IF so_line_rec (i).bulk_order_flag =
                                           'Y'
                                        THEN
                                            l_return_status   := 'BUL-SCH-S';
                                        ELSE
                                            l_return_status   := 'SCH-S';
                                        END IF;

                                        l_message_data   := NULL;
                                    ELSE
                                        FOR i IN 1 .. l_msg_count
                                        LOOP
                                            oe_msg_pub.get (
                                                p_msg_index   => i,
                                                p_encoded     =>
                                                    fnd_api.g_false,
                                                p_data        => l_msg_data,
                                                p_msg_index_out   =>
                                                    l_msg_index_out);

                                            l_message_data   :=
                                                l_message_data || l_msg_data;
                                        END LOOP;

                                        write_log (
                                               'Bulk Schedule API Error :'
                                            || l_message_data);
                                        ln_bulk_split_err   :=
                                            ln_bulk_split_err + 1;

                                        IF so_line_rec (i).bulk_order_flag =
                                           'Y'
                                        THEN
                                            l_return_status   := 'BUL-SCH-F';
                                            l_message_data    :=
                                                'Bulk Schedule Failed';
                                        ELSE
                                            l_return_status   := 'SCH-F';
                                            l_message_data    :=
                                                'Schedule Failed';
                                        END IF;
                                    END IF;
                                END IF;
                            END IF;

                            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T xoa
                               SET xoa.process_status = l_return_status, xoa.error_message = l_message_data, xoa.last_update_date = SYSDATE,
                                   xoa.child_req_id = ln_conc_request_id, xoa.split_qty = ln_new_line_split_qty --added as part of CCR0009753
                             WHERE     xoa.line_id = so_line_rec (i).line_id
                                   AND xoa.batch_id =
                                       so_line_rec (i).batch_id;

                            COMMIT;
                        END IF;
                    END LOOP;
                END IF;
            END;
        END LOOP;

        write_log ('Records successfully got Rescheduled = ' || l_row_num);
        write_log ('Records Errored while Rescheduling = ' || l_row_num_err);
        write_log (
               'Records successfully split and schedule for Bulk = '
            || ln_bulk_split_success);
        write_log (
               'Records errored while split and schedule for Bulk = '
            || ln_bulk_split_err);


        IF lv_unschedule = 'Y'
        THEN
            write_log (
                'Records Sucessfully Unscheduled = ' || l_unsched_row_num);
            write_log (
                   'Records Errored while Unscheduling = '
                || l_unsched_row_num_err);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                   'In when others exception in xxd_process_orders procedure. Error message is : '
                || SQLERRM);
    END xxd_process_orders;


    /************************************************************************************************/
    --This procedure does create the sorting query for order lines sorting
    /************************************************************************************************/
    PROCEDURE sorting_creteria (pv_brand VARCHAR2, pn_org_id NUMBER, pn_sf_move_days OUT NUMBER, pn_ar_move_days OUT NUMBER, pv_split_order OUT VARCHAR2, pv_sorting_criteria OUT VARCHAR2, pv_sorting_order OUT VARCHAR2, pv_scheduling_win OUT VARCHAR2, pv_cursor_sorting OUT VARCHAR2
                                , pn_scheduling_range OUT NUMBER)
    AS
        lv_cursor           VARCHAR2 (3000);
        lv_cursor_sorting   VARCHAR2 (3000);
        lv_sorting          VARCHAR2 (300);
        lv_sorting_order    VARCHAR2 (300);
    BEGIN
        SELECT attribute3, attribute4, attribute5,
               attribute6, attribute7, attribute8,
               attribute9
          INTO pn_sf_move_days, pn_ar_move_days, pv_split_order, pv_sorting_criteria,
                              pv_sorting_order, pv_scheduling_win, pn_scheduling_range
          FROM fnd_lookup_values_vl
         WHERE     lookup_type = 'XXD_ATP_LVL_DEF2'
               AND ATTRIBUTE1 = pv_brand
               AND ATTRIBUTE2 = pn_org_id
               AND ENABLED_FLAG = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE + 1);

        IF pv_sorting_criteria = 'Creation Date'
        THEN
            lv_sorting   := ' order by order_creation_date ';
        ELSIF pv_sorting_criteria = 'Request Date'
        THEN
            lv_sorting   := ' order by request_date ';
        ELSIF pv_sorting_criteria = 'Ordered Date'
        THEN
            lv_sorting   := ' order by Ordered_Date ';
        END IF;

        IF pv_sorting_order = 'DESC_ORDER'
        THEN
            lv_sorting_order   := ' desc ';
        ELSIF pv_sorting_order = 'ASC_ORDER'
        THEN
            lv_sorting_order   := ' asc ';
        END IF;

        lv_cursor_sorting   := lv_sorting || lv_sorting_order;

        pv_cursor_sorting   := lv_cursor_sorting;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_sf_move_days       := 0;
            pn_ar_move_days       := 0;
            pv_split_order        := 'NONE';
            pv_cursor_sorting     := ' order by order_creation_date desc ';
            pv_scheduling_win     := 'CANCEL DATE';
            pn_scheduling_range   := 0;
            write_log (
                   'In when others exception in sorting_creteria procedure. Error message is : '
                || SQLERRM);
    END sorting_creteria;


    /************************************************************************************************/
    --This procedure takes batch_id, Inv Org, Brand, seq num , neg qty from and seq num to as input parameters
    -- and mark the records eligible for safe move and reocrds which are safe to execute
    /************************************************************************************************/

    PROCEDURE get_safe_move_qty (pn_batch_id NUMBER, pn_item_id NUMBER, pv_brand VARCHAR2, pn_organization_id NUMBER, pn_organization_code VARCHAR2, pn_seq_number NUMBER, pn_neg_qty NUMBER, pn_safe_move_days NUMBER, pv_atrisk_flag OUT VARCHAR2
                                 , pn_safe_ex_qty OUT NUMBER)
    AS
        ln_safe_el_qty         NUMBER;
        ln_safe_ex_qty         NUMBER;
        ln_neg_qty             NUMBER;
        ln_safe_move_days      NUMBER;
        lv_cursor              VARCHAR2 (2000);
        lv_split_order         VARCHAR2 (200);
        lv_sorting_criteria    VARCHAR2 (200);
        lv_sorting_order       VARCHAR2 (200);
        lv_scheduling_win      VARCHAR2 (200);
        lv_cursor_sorting      VARCHAR2 (200);
        lv_cust_lookup         VARCHAR2 (200);
        ln_sf_move_days        NUMBER;
        ln_ar_move_days        NUMBER;
        ln_line_id             NUMBER;
        ln_header_id           NUMBER;
        ln_ordered_quantity    NUMBER;
        ln_runing_tot_qty      NUMBER;
        lv_cust_sorting        VARCHAR2 (200);
        ln_running_total_seq   NUMBER;
        lv_split_eligible      VARCHAR2 (10);
        ln_scheduling_range    NUMBER;

        TYPE l_cursor_type IS REF CURSOR;

        cur_order_criteria     l_cursor_type;
    BEGIN
        ln_safe_move_days      := pn_safe_move_days;
        ln_neg_qty             := ABS (pn_neg_qty);
        ln_runing_tot_qty      := 0;
        ln_running_total_seq   := 0;
        lv_split_eligible      := 'N';


        sorting_creteria (pv_brand => pv_brand, pn_org_id => pn_organization_id, pn_sf_move_days => ln_sf_move_days, pn_ar_move_days => ln_ar_move_days, pv_split_order => lv_split_order, pv_sorting_criteria => lv_sorting_criteria, pv_sorting_order => lv_sorting_order, pv_scheduling_win => lv_scheduling_win, pv_cursor_sorting => lv_cursor_sorting
                          , pn_scheduling_range => ln_scheduling_range);

        --************************
        -- Update safe eligible move
        --***********************

        IF lv_scheduling_win = 'CANCEL DATE'
        THEN
            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
               SET sf_el_flag = 'Y', ORDER_SPLIT_TYPE = lv_split_order
             WHERE     latest_acceptable_date > atp_postive_date
                   AND schedule_ship_date < atp_postive_date
                   AND cancel_date - NVL (safe_move_days, ln_sf_move_days) >
                       atp_postive_date
                   AND batch_id = pn_batch_id
                   AND inventory_item_id = pn_item_id
                   AND seq_number = pn_seq_number
                   AND ship_from_org_id = pn_organization_id;
        ELSE
            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
               SET sf_el_flag = 'Y', ORDER_SPLIT_TYPE = lv_split_order
             WHERE     latest_acceptable_date > atp_postive_date
                   AND schedule_ship_date < atp_postive_date
                   AND   latest_acceptable_date
                       - NVL (safe_move_days, ln_sf_move_days) >
                       atp_postive_date
                   AND batch_id = pn_batch_id
                   AND inventory_item_id = pn_item_id
                   AND seq_number = pn_seq_number
                   AND ship_from_org_id = pn_organization_id;
        END IF;

        --************************
        -- Derive the executable qty
        --************************

        SELECT NVL (SUM (ordered_quantity), 0)
          INTO ln_safe_el_qty
          FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
         WHERE     sf_el_flag = 'Y'
               AND batch_id = pn_batch_id
               AND inventory_item_id = pn_item_id
               AND seq_number = pn_seq_number
               AND ship_from_org_id = pn_organization_id;


        IF ln_safe_el_qty = ln_neg_qty
        THEN
            ln_safe_ex_qty   := ln_safe_el_qty;
            pv_atrisk_flag   := 'N';

            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
               SET sf_ex_flag = 'Y', new_lad = cancel_date - NVL (safe_move_days, ln_sf_move_days)
             WHERE     1 = 1
                   AND schedule_ship_date < atp_postive_date
                   AND cancel_date - NVL (safe_move_days, ln_sf_move_days) >
                       atp_postive_date
                   AND batch_id = pn_batch_id
                   AND inventory_item_id = pn_item_id
                   AND seq_number = pn_seq_number
                   AND sf_el_flag = 'Y'
                   AND ship_from_org_id = pn_organization_id;
        ELSIF ln_safe_el_qty > ln_neg_qty
        THEN
            lv_cust_lookup    :=
                   'XXD_ATP_LEVEL_DEF1_'
                || pv_brand
                || '_'
                || pn_organization_code;

            lv_cursor         :=
                   ' SELECT ordered_quantity,line_id FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T xoa, fnd_lookup_values_vl flv WHERE  1 = 1 
							AND enabled_flag(+) = ''Y''
							AND batch_id = '
                || pn_batch_id
                || ' AND inventory_item_id = '
                || pn_item_id
                || ' AND seq_number = '
                || pn_seq_number
                || ' AND  sf_el_flag = ''Y'' 
						AND ship_from_org_id = '
                || pn_organization_id
                || ' AND lookup_type (+) = '''
                || lv_cust_lookup
                || '''
					AND flv.ATTRIBUTE1(+) = xoa.SOLD_TO_ORG_ID 
				';

            lv_cust_sorting   := ' , NVL(attribute2,4) DESC ';

            IF lv_sorting_criteria = 'Request Date'
            THEN
                lv_cursor   :=
                    lv_cursor || lv_cursor_sorting || lv_cust_sorting;
            ELSE
                lv_cursor   := lv_cursor || lv_cursor_sorting;
            END IF;

            write_log ('lv_cursor ' || lv_cursor);

            OPEN cur_order_criteria FOR lv_cursor;

            LOOP
                FETCH cur_order_criteria INTO ln_ordered_quantity, ln_line_id;

                ln_runing_tot_qty      :=
                    ln_runing_tot_qty + ln_ordered_quantity;
                ln_running_total_seq   := ln_running_total_seq + 1;
                ln_safe_ex_qty         := ln_runing_tot_qty;

                UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
                   SET sf_ex_flag = 'Y', running_total_seq = ln_running_total_seq
                 WHERE     1 = 1
                       AND batch_id = pn_batch_id
                       AND inventory_item_id = pn_item_id
                       AND seq_number = pn_seq_number
                       AND line_id = ln_line_id
                       AND ship_from_org_id = pn_organization_id;

                IF ln_runing_tot_qty = ln_neg_qty
                THEN
                    EXIT;
                ELSIF ln_runing_tot_qty > ln_neg_qty
                THEN
                    EXIT;
                    lv_split_eligible   := 'Y';
                    EXIT;
                END IF;

                EXIT WHEN cur_order_criteria%NOTFOUND;
            END LOOP;                                              -- critetia

            pv_atrisk_flag    := 'N';
        ELSIF ln_safe_el_qty < ln_neg_qty
        THEN
            NULL;                                                  -- critetia
            ln_safe_ex_qty   := ln_safe_el_qty;
            pv_atrisk_flag   := 'Y';

            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
               SET sf_ex_flag = 'Y', new_lad = cancel_date - NVL (safe_move_days, ln_sf_move_days)
             WHERE     1 = 1
                   AND batch_id = pn_batch_id
                   AND seq_number = pn_seq_number
                   AND inventory_item_id = pn_item_id
                   AND sf_el_flag = 'Y'
                   AND ship_from_org_id = pn_organization_id;
        END IF;

        pn_safe_ex_qty         := ln_safe_ex_qty;

        --**************************
        -- Update safe executable move
        --****************************
        UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_SUMRY_T
           SET sf_el_qty = ln_safe_el_qty, sf_ex_qty = ln_safe_ex_qty
         WHERE     1 = 1
               AND batch_id = pn_batch_id
               AND inventory_item_id = pn_item_id
               AND seq_number = pn_seq_number
               AND organization_id = pn_organization_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                'Exception in get_safe_move_qty procedure is :' || SQLERRM);
            raise_application_error (
                -20020,
                'Error in Procedure get_safe_move_qty -> ' || SQLERRM);
    END get_safe_move_qty;


    /************************************************************************************************/
    --This procedure takes batch_id, Inv Org, Brand, seq num , neg qty from and seq num to as input parameters
    -- and mark the records eligible for at risk move and reocrds which can be executed for at risk
    /************************************************************************************************/

    PROCEDURE get_at_risk_move_qty (pn_batch_id                NUMBER,
                                    pn_item_id                 NUMBER,
                                    pv_brand                   VARCHAR2,
                                    pn_organization_id         NUMBER,
                                    pn_organization_code       VARCHAR2,
                                    pn_seq_number              NUMBER,
                                    pn_neg_qty                 NUMBER,
                                    pn_atrisk_move_days        NUMBER,
                                    pn_safe_ex_qty             NUMBER,
                                    pv_unschedule_flag     OUT VARCHAR2,
                                    pn_atrisk_ex_qty       OUT NUMBER)
    AS
        ln_atrisk_el_qty       NUMBER;
        ln_atrisk_ex_qty       NUMBER;
        ln_neg_qty             NUMBER;
        ln_atrisk_move_days    NUMBER;
        ln_runing_tot_qty      NUMBER;
        ln_ordered_quantity    NUMBER;
        lv_cursor              VARCHAR2 (2000);
        lv_split_order         VARCHAR2 (200);
        lv_sorting_criteria    VARCHAR2 (200);
        lv_sorting_order       VARCHAR2 (200);
        lv_scheduling_win      VARCHAR2 (200);
        lv_cursor_sorting      VARCHAR2 (200);
        lv_cust_lookup         VARCHAR2 (200);
        lv_cust_sorting        VARCHAR2 (200);
        ln_line_id             NUMBER;
        ln_running_total_seq   NUMBER := 0;
        ln_sf_move_days        NUMBER;
        ln_ar_move_days        NUMBER;
        lv_split_eligible      VARCHAR2 (10);
        ln_scheduling_range    NUMBER;

        TYPE l_cursor_type IS REF CURSOR;

        cur_order_criteria     l_cursor_type;
    BEGIN
        ln_neg_qty             := ABS (pn_neg_qty);
        ln_runing_tot_qty      := 0;
        ln_running_total_seq   := 0;
        lv_split_eligible      := 'N';

        sorting_creteria (pv_brand => pv_brand, pn_org_id => pn_organization_id, pn_sf_move_days => ln_sf_move_days, pn_ar_move_days => ln_ar_move_days, pv_split_order => lv_split_order, pv_sorting_criteria => lv_sorting_criteria, pv_sorting_order => lv_sorting_order, pv_scheduling_win => lv_scheduling_win, pv_cursor_sorting => lv_cursor_sorting
                          , pn_scheduling_range => ln_scheduling_range);


        write_log (
               'ln_ar_move_days '
            || ln_ar_move_days
            || ' pn_atrisk_move_days '
            || pn_atrisk_move_days
            || ' pn_seq_number '
            || pn_seq_number
            || ' pn_item_id '
            || pn_item_id);

        IF lv_scheduling_win = 'CANCEL DATE'
        THEN
            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
               SET ar_el_flag = 'Y', new_lad = cancel_Date + NVL (atrisk_move_days, ln_ar_move_days), order_split_type = lv_split_order
             WHERE     1 = 1
                   AND schedule_ship_date < atp_postive_date
                   AND cancel_Date + NVL (atrisk_move_days, ln_ar_move_days) >
                       atp_postive_date
                   AND batch_id = pn_batch_id
                   AND inventory_item_id = pn_item_id
                   AND seq_number = pn_seq_number
                   AND NVL (sf_el_flag, 'N') <> 'Y'
                   AND ship_from_org_id = pn_organization_id;
        ELSE
            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
               SET ar_el_flag = 'Y', new_lad = cancel_Date + NVL (atrisk_move_days, ln_ar_move_days), order_split_type = lv_split_order
             WHERE     1 = 1
                   AND schedule_ship_date < atp_postive_date
                   --  AND latest_acceptable_date + NVL (atrisk_move_days, ln_ar_move_days) > atp_postive_date
                   AND   request_date
                       + NVL (atrisk_move_days, ln_ar_move_days)
                       + NVL (ln_scheduling_range, 0) >
                       atp_postive_date
                   AND batch_id = pn_batch_id
                   AND inventory_item_id = pn_item_id
                   AND seq_number = pn_seq_number
                   AND NVL (sf_el_flag, 'N') <> 'Y'
                   AND ship_from_org_id = pn_organization_id;
        END IF;

        --************************
        -- Derive the executable qty
        --************************

        SELECT NVL (SUM (ordered_quantity), 0)
          INTO ln_atrisk_el_qty
          FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
         WHERE     ar_el_flag = 'Y'
               AND batch_id = pn_batch_id
               AND inventory_item_id = pn_item_id
               AND seq_number = pn_seq_number
               AND ship_from_org_id = pn_organization_id;

        IF ln_atrisk_el_qty = ln_neg_qty
        THEN
            ln_atrisk_ex_qty     := ln_atrisk_el_qty;
            pv_unschedule_flag   := 'N';

            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
               SET ar_ex_flag = ar_el_flag, new_lad = cancel_Date + NVL (atrisk_move_days, ln_ar_move_days)
             WHERE     1 = 1
                   AND schedule_ship_date < atp_postive_date
                   AND cancel_Date + NVL (atrisk_move_days, ln_ar_move_days) >
                       atp_postive_date
                   AND batch_id = pn_batch_id
                   AND seq_number = pn_seq_number
                   AND inventory_item_id = pn_item_id
                   AND ar_el_flag = 'Y'
                   AND NVL (sf_el_flag, 'N') <> 'Y'
                   AND ship_from_org_id = pn_organization_id;
        ELSIF ln_atrisk_el_qty > ln_neg_qty
        THEN
            lv_cust_lookup       :=
                   'XXD_ATP_LEVEL_DEF1_'
                || pv_brand
                || '_'
                || pn_organization_code;

            lv_cursor            :=
                   ' SELECT ordered_quantity,line_id FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T xoa, fnd_lookup_values_vl flv WHERE  1 = 1 
					AND enabled_flag(+) = ''Y''
					AND batch_id = '
                || pn_batch_id
                || '
					AND inventory_item_id = '
                || pn_item_id
                || '
					AND seq_number = '
                || pn_seq_number
                || '
					AND  ar_el_flag = ''Y'' 
					AND ship_from_org_id = '
                || pn_organization_id
                || '
					AND lookup_type (+) = '''
                || lv_cust_lookup
                || '''
					AND flv.ATTRIBUTE1(+) = xoa.SOLD_TO_ORG_ID 
				';

            lv_cust_sorting      := ' , NVL(attribute2,4) DESC ';

            IF lv_sorting_criteria = 'Request Date'
            THEN
                lv_cursor   :=
                    lv_cursor || lv_cursor_sorting || lv_cust_sorting;
            ELSE
                lv_cursor   := lv_cursor || lv_cursor_sorting;
            END IF;

            OPEN cur_order_criteria FOR lv_cursor;

            LOOP
                FETCH cur_order_criteria INTO ln_ordered_quantity, ln_line_id;

                ln_runing_tot_qty      :=
                    ln_runing_tot_qty + ln_ordered_quantity;
                ln_running_total_seq   := ln_running_total_seq + 1;
                ln_atrisk_ex_qty       := ln_runing_tot_qty;

                UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
                   SET ar_ex_flag = 'Y', running_total_seq = ln_running_total_seq
                 WHERE     1 = 1
                       AND batch_id = pn_batch_id
                       AND inventory_item_id = pn_item_id
                       AND seq_number = pn_seq_number
                       AND line_id = ln_line_id
                       AND ship_from_org_id = pn_organization_id;

                IF ln_runing_tot_qty = ln_neg_qty
                THEN
                    EXIT;
                ELSIF ln_runing_tot_qty > ln_neg_qty
                THEN
                    lv_split_eligible   := 'Y';
                    EXIT;
                END IF;

                EXIT WHEN cur_order_criteria%NOTFOUND;
            END LOOP;


            NULL;                                                  -- critetia
            pv_unschedule_flag   := 'N';
        ELSIF ln_atrisk_el_qty < ln_neg_qty
        THEN
            NULL;                                                  -- critetia
            ln_atrisk_ex_qty     := ln_atrisk_el_qty;
            pv_unschedule_flag   := 'Y';

            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
               SET ar_ex_flag = ar_el_flag, new_lad = cancel_Date + NVL (atrisk_move_days, ln_ar_move_days)
             WHERE     1 = 1
                   AND schedule_ship_date < atp_postive_date
                   AND cancel_Date + NVL (atrisk_move_days, ln_ar_move_days) >
                       atp_postive_date
                   AND batch_id = pn_batch_id
                   AND seq_number = pn_seq_number
                   AND ship_from_org_id = pn_organization_id
                   AND ar_el_flag = 'Y'
                   AND NVL (sf_el_flag, 'N') <> 'Y';
        END IF;

        pn_atrisk_ex_qty       := ln_atrisk_ex_qty;

        UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_SUMRY_T
           SET ar_el_qty = ln_atrisk_el_qty, ar_ex_qty = ln_atrisk_ex_qty
         WHERE     1 = 1
               AND batch_id = pn_batch_id
               AND inventory_item_id = pn_item_id
               AND seq_number = pn_seq_number
               AND organization_id = pn_organization_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                'Exception in get_at_risk_move_qty procedure is :' || SQLERRM);
            raise_application_error (
                -20020,
                'Error in Procedure get_at_risk_move_qty -> ' || SQLERRM);
    END get_at_risk_move_qty;


    /************************************************************************************************/
    --This procedure takes batch_id, Inv Org, Brand, seq num , neg qty from and seq num to as input parameters
    -- and mark the records eligible for unscheduling and reocrds which can be executed for unscheduling
    /************************************************************************************************/

    PROCEDURE get_unschedule_move_qty (pn_batch_id                NUMBER,
                                       pn_item_id                 NUMBER,
                                       pv_brand                   VARCHAR2,
                                       pn_organization_id         NUMBER,
                                       pn_organization_code       VARCHAR2,
                                       pn_seq_number              NUMBER,
                                       pn_neg_qty                 NUMBER,
                                       pn_unsch_qty           OUT NUMBER)
    AS
        ln_unsch_el_qty        NUMBER;
        ln_unsch_ex_qty        NUMBER;
        ln_neg_qty             NUMBER;
        lv_cursor              VARCHAR2 (2000);
        lv_split_order         VARCHAR2 (200);
        lv_sorting_criteria    VARCHAR2 (200);
        lv_sorting_order       VARCHAR2 (200);
        lv_scheduling_win      VARCHAR2 (200);
        lv_cursor_sorting      VARCHAR2 (200);
        lv_cust_lookup         VARCHAR2 (200);
        lv_cust_sorting        VARCHAR2 (200);
        ln_ordered_quantity    NUMBER;
        ln_line_id             NUMBER;
        ln_runing_tot_qty      NUMBER := 0;
        ln_running_total_seq   NUMBER;
        ln_sf_move_days        NUMBER;
        ln_ar_move_days        NUMBER;
        lv_split_eligible      VARCHAR2 (10);
        ln_scheduling_range    NUMBER;

        TYPE l_cursor_type IS REF CURSOR;

        cur_order_criteria     l_cursor_type;
    BEGIN
        ln_neg_qty             := ABS (pn_neg_qty);
        ln_runing_tot_qty      := 0;
        ln_running_total_seq   := 0;
        lv_split_eligible      := 'N';

        sorting_creteria (pv_brand => pv_brand, pn_org_id => pn_organization_id, pn_sf_move_days => ln_sf_move_days, pn_ar_move_days => ln_ar_move_days, pv_split_order => lv_split_order, pv_sorting_criteria => lv_sorting_criteria, pv_sorting_order => lv_sorting_order, pv_scheduling_win => lv_scheduling_win, pv_cursor_sorting => lv_cursor_sorting
                          , pn_scheduling_range => ln_scheduling_range);

        UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
           SET un_el_flag = 'Y', order_split_type = lv_split_order
         WHERE     1 = 1
               AND batch_id = pn_batch_id
               AND inventory_item_id = pn_item_id
               AND seq_number = pn_seq_number
               AND ship_from_org_id = pn_organization_id
               AND NVL (sf_ex_flag, 'N') <> 'Y'
               AND NVL (ar_ex_flag, 'N') <> 'Y';


        SELECT NVL (SUM (ordered_quantity), 0)
          INTO ln_unsch_el_qty
          FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
         WHERE     un_el_flag = 'Y'
               AND batch_id = pn_batch_id
               AND inventory_item_id = pn_item_id
               AND seq_number = pn_seq_number
               AND ship_from_org_id = pn_organization_id;

        IF ln_unsch_el_qty = ln_neg_qty
        THEN
            ln_unsch_ex_qty   := ln_unsch_el_qty;

            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
               SET un_ex_flag   = 'Y'
             WHERE     1 = 1
                   AND batch_id = pn_batch_id
                   AND seq_number = pn_seq_number
                   AND ship_from_org_id = pn_organization_id
                   AND un_el_flag = 'Y';
        ELSIF ln_unsch_el_qty > ln_neg_qty
        THEN
            lv_cust_lookup    :=
                   'XXD_ATP_LEVEL_DEF1_'
                || pv_brand
                || '_'
                || pn_organization_code;

            lv_cursor         :=
                   ' SELECT ordered_quantity,line_id FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T xoa, fnd_lookup_values_vl flv WHERE  1 = 1 
					AND enabled_flag(+) = ''Y''
					AND batch_id = '
                || pn_batch_id
                || ' AND inventory_item_id = '
                || pn_item_id
                || ' AND seq_number = '
                || pn_seq_number
                || ' AND  un_el_flag = ''Y''  
         				AND ship_from_org_id = '
                || pn_organization_id
                || ' AND lookup_type (+) = '''
                || lv_cust_lookup
                || '''
					AND flv.ATTRIBUTE1(+) = xoa.SOLD_TO_ORG_ID 
				';

            lv_cust_sorting   := ' , NVL(attribute2,4) DESC ';

            IF lv_sorting_criteria = 'Request Date'
            THEN
                lv_cursor   :=
                    lv_cursor || lv_cursor_sorting || lv_cust_sorting;
            ELSE
                lv_cursor   := lv_cursor || lv_cursor_sorting;
            END IF;

            write_log ('lv_cursor ' || lv_cursor);

            OPEN cur_order_criteria FOR lv_cursor;

            LOOP
                FETCH cur_order_criteria INTO ln_ordered_quantity, ln_line_id;

                ln_runing_tot_qty      :=
                    ln_runing_tot_qty + ln_ordered_quantity;
                ln_running_total_seq   := 1 + ln_running_total_seq;
                ln_unsch_ex_qty        := ln_runing_tot_qty;

                UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
                   SET un_ex_flag = 'Y', running_total_seq = ln_running_total_seq
                 WHERE     1 = 1
                       AND batch_id = pn_batch_id
                       AND inventory_item_id = pn_item_id
                       AND seq_number = pn_seq_number
                       AND ship_from_org_id = pn_organization_id
                       AND line_id = ln_line_id;


                IF ln_runing_tot_qty = ln_neg_qty
                THEN
                    write_log ('EXIT ' || ln_runing_tot_qty);
                    EXIT;
                ELSIF ln_runing_tot_qty > ln_neg_qty
                THEN
                    lv_split_eligible   := 'Y';

                    UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
                       SET split_case   = lv_split_eligible
                     WHERE     1 = 1
                           AND batch_id = pn_batch_id
                           AND inventory_item_id = pn_item_id
                           AND seq_number = pn_seq_number
                           AND ship_from_org_id = pn_organization_id
                           AND line_id = ln_line_id;

                    EXIT;
                END IF;

                EXIT WHEN cur_order_criteria%NOTFOUND;
            END LOOP;
        -- critetia
        ELSIF ln_unsch_el_qty < ln_neg_qty
        THEN
            ln_unsch_ex_qty   := ln_unsch_el_qty;

            UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T
               SET un_ex_flag   = 'Y'
             WHERE     1 = 1
                   AND batch_id = pn_batch_id
                   AND seq_number = pn_seq_number
                   AND inventory_item_id = pn_item_id
                   AND ship_from_org_id = pn_organization_id
                   AND un_el_flag = 'Y';
        END IF;

        UPDATE xxdo.XXD_ONT_AUTO_ATP_LEVL_SUMRY_T
           SET un_el_qty = ln_unsch_el_qty, un_ex_qty = ln_unsch_ex_qty
         WHERE     1 = 1
               AND batch_id = pn_batch_id
               AND inventory_item_id = pn_item_id
               AND seq_number = pn_seq_number
               AND organization_id = pn_organization_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                   'Exception in get_unschedule_move_qty procedure for Item :'
                || pn_item_id
                || ' Error '
                || SQLERRM);
            raise_application_error (
                -20020,
                'Error in Procedure get_unschedule_move_qty -> ' || SQLERRM);
    END get_unschedule_move_qty;


    /************************************************************************************************/
    --This the main procedure for this package which takes below input parameters
    -- This procedure populate all the staging tables and call the worker program to execute the selected records
    -- This peocedure also sends the email to recipients which are configured in lookup
    /************************************************************************************************/
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_organization_id IN NUMBER, pv_Processing_Move IN VARCHAR2, pv_exclude IN VARCHAR2, pv_customer IN VARCHAR2, pd_request_date_from IN DATE, pd_request_date_to IN DATE, pv_brand IN VARCHAR2, pv_style IN VARCHAR2, pv_color IN VARCHAR2, pv_size IN VARCHAR2, pv_execution_mode IN VARCHAR2, pn_purge_retention_days IN NUMBER, pn_batch_size IN NUMBER
                    , pn_threads IN NUMBER, pv_debug IN VARCHAR2)
    AS
        CURSOR neg_atp_order_sku (cn_batch_id NUMBER)
        IS
              SELECT DISTINCT seq_number, xoa.inventory_item_id, neg_date,
                              neg_edate, batch_id, xoa.organization_id,
                              mp.organization_code, neg_qty, brand,
                              1 safe_move_days, 1 atrisk_move_days
                FROM xxdo.XXD_ONT_AUTO_ATP_LEVL_SUMRY_T xoa, apps.xxd_common_items_v xciv, mtl_parameters mp
               WHERE     process_status = 'N'
                     AND xoa.organization_id = xciv.organization_id
                     AND xoa.organization_id = mp.organization_id
                     AND batch_id = cn_batch_id
                     AND xciv.brand = NVL (pv_brand, xciv.brand)
                     AND xoa.inventory_item_id = xciv.inventory_item_id
            ORDER BY inventory_item_id, seq_number;

        lv_neg_atp_items_cur           VARCHAR2 (32000);
        lv_neg_atp_items_fin_cur       VARCHAR2 (32000);
        lv_neg_atp_sup_demand_cur      VARCHAR2 (32000);
        lv_demand_supply_query         VARCHAR2 (4000);
        lv_demand_supply_ord_by        VARCHAR2 (500);
        lv_neg_atp_sup_demand_ord_by   VARCHAR2 (500);
        lv_neg_atp_sup_demd_grp_by     VARCHAR2 (4000);
        lv_plan_cur                    VARCHAR2 (4000);
        lv_dblink                      VARCHAR2 (100) := NULL; -- := 'BT_EBS_TO_ASCP.US.ORACLE.COM';
        ln_plan_id                     NUMBER := 0;
        lv_plan_date                   VARCHAR2 (20);
        lv_neg_atp_items_grp_by        VARCHAR2 (500);
        lv_neg_atp_items_ord_by        VARCHAR2 (500);
        lv_inventory_item_id_cond      VARCHAR2 (2000);
        lv_brand_cond                  VARCHAR2 (2000);
        lv_style_cond                  VARCHAR2 (500);
        lv_color_cond                  VARCHAR2 (500);
        lv_size_cond                   VARCHAR2 (500);
        ln_batch_id                    NUMBER;
        ln_cnt                         NUMBER;
        ln_neg_cnt                     NUMBER;
        ln_supply_cnt                  NUMBER;
        lv_atrisk_flag                 VARCHAR2 (20) := 'Y';
        lv_unschedule_flag             VARCHAR2 (20) := 'Y';
        ln_safe_ex_qty                 NUMBER;
        ln_atrisk_ex_qty               NUMBER;
        ln_remaining_qty               NUMBER;
        ln_remaining_seq_qty           NUMBER;
        ln_unsch_qty                   NUMBER;
        lv_process_further             VARCHAR2 (10);
        ln_to_seq_num                  NUMBER;
        ln_from_seq_num                NUMBER;
        ln_resched_req_id              NUMBER := 0;
        lv_processing_move             VARCHAR2 (100);
        ln_rentention_days             NUMBER;
        ln_summary_cnt                 NUMBER;
        ln_worker_req                  NUMBER := 0;
        ln_max_rec_cnt                 NUMBER := pn_batch_size;
        ex_no_negative_records         EXCEPTION;
        ex_no_summary_rec              EXCEPTION;
        ln_item_id                     NUMBER;


        TYPE item_supply_demand_rec_type IS RECORD
        (
            Inventory_item_id    NUMBER,
            organization_id      NUMBER,
            alloc_date           DATE,
            Supply               NUMBER,
            demand               NUMBER,
            net_qty              NUMBER,
            poh                  NUMBER
        );

        TYPE item_supply_demand_type IS TABLE OF item_supply_demand_rec_type
            INDEX BY BINARY_INTEGER;

        item_supply_demand_rec         item_supply_demand_type;


        TYPE neg_atp_rec_type IS RECORD
        (
            ebs_item_id        NUMBER,
            organization_id    NUMBER,
            -- alloc_date         DATE,
            negativity         NUMBER
        );

        TYPE neg_atp_items_type IS TABLE OF neg_atp_rec_type
            INDEX BY BINARY_INTEGER;

        neg_atp_items_rec              neg_atp_items_type;

        TYPE plan_cur_typ IS REF CURSOR;

        plan_cur                       plan_cur_typ;

        TYPE neg_atp_items_cur_typ IS REF CURSOR;

        neg_atp_items_cur              neg_atp_items_cur_typ;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Timestamp: ' || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        gv_debug_flag                  := pv_debug;
        fnd_file.put_line (fnd_file.LOG,
                           '*********Input Parameters START***** ');
        fnd_file.put_line (fnd_file.LOG, 'Org ID : ' || pn_organization_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Processing Move : ' || pv_Processing_Move);
        fnd_file.put_line (fnd_file.LOG, 'Exclusion : ' || pv_exclude);
        fnd_file.put_line (fnd_file.LOG, 'Customer : ' || pv_customer);
        fnd_file.put_line (fnd_file.LOG,
                           'Request Date From : ' || pd_request_date_from);
        fnd_file.put_line (fnd_file.LOG,
                           'Request Date to : ' || pd_request_date_to);
        fnd_file.put_line (fnd_file.LOG,
                           'Request Date to : ' || pd_request_date_to);
        fnd_file.put_line (fnd_file.LOG, 'Brand : ' || pv_brand);
        fnd_file.put_line (fnd_file.LOG, 'Style : ' || pv_style);
        fnd_file.put_line (fnd_file.LOG, 'Color : ' || pv_color);
        fnd_file.put_line (fnd_file.LOG, 'Size  : ' || pv_size);
        fnd_file.put_line (fnd_file.LOG,
                           'Execution Mode : ' || pv_execution_mode);
        fnd_file.put_line (fnd_file.LOG,
                           '*********Input Parameters END***** ');


        lv_processing_move             := NVL (pv_Processing_Move, 'ALL');

        gv_op_name                     := ' Fetching the dblink  ';

        BEGIN
            SELECT a2m_dblink INTO lv_dblink FROM mrp_ap_apps_instances_all;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_dblink   := NULL;
                write_log (
                       'Exception while fetching EBS to ASCP DBLINK. Error is: '
                    || SQLERRM);
                write_log (
                    'Please check A2M_DBLINK column in MRP_AP_APPS_INSTANCES_ALL table');
                write_log ('Exiting the program');
                RETURN;
        END;

        gv_op_name                     := ' Fetching the plan id ';
        --Plan cursor query
        lv_plan_cur                    := '
        SELECT mp.plan_id, 
               TO_CHAR(mp.curr_start_date, ''DD-MON-YYYY'') plan_date 
          FROM msc_plans@' || lv_dblink || ' mp
         WHERE 1 = 1
           AND mp.compile_designator = ''ATP''';

        write_log ('-------------------------------------------');
        write_log ('Plan Cursor Query : ');
        write_log ('-------------------------------------------');
        write_log (lv_plan_cur);
        write_log ('-------------------------------------------');

        --Opening the plan cursor

        --gv_op_key := 'Record ID: ' || rec_plm_data.record_id;
        gv_op_name                     := ' Opening the plan cursor ';

        OPEN plan_cur FOR lv_plan_cur;

        FETCH plan_cur INTO ln_plan_id, lv_plan_date;

        CLOSE plan_cur;


        IF pv_execution_mode = 'SIMULATE-LATEST SUPP'
        THEN
            lv_neg_atp_items_cur      :=
                   'SELECT x.inventory_item_id ,
                        x.organization_id,
                      MIN (poh) negativity
    FROM (  SELECT /*+parallel(4)*/
                  organization_id,
                   inventory_item_id,
                   supply_date,
                   SUM (quantity) quantity,
                   SUM (
                      SUM (has_supply))
                   OVER (PARTITION BY organization_id, inventory_item_id
                         ORDER BY supply_date ASC
                         RANGE UNBOUNDED PRECEDING)
                      supply_number,
                   SUM (
                      SUM (quantity))
                   OVER (PARTITION BY organization_id, inventory_item_id
                         ORDER BY supply_date ASC
                         RANGE UNBOUNDED PRECEDING)
                      poh
              FROM (SELECT /*+parallel(4) full(ms) materialize*/
                          to_organization_id organization_id,
                           item_id inventory_item_id,
                           TRUNC (
                              GREATEST (ms.expected_delivery_date,
                                        TRUNC (SYSDATE)))
                              supply_Date,
                           1 has_supply,
                           quantity quantity
                      FROM apps.mtl_supply ms 
              WHERE to_organization_id = '
                || pn_organization_id
                || '    UNION ALL
                 SELECT /*+parallel(4) full(moqd) materialize*/
                          organization_id,
                           inventory_item_id,
                           TRUNC (SYSDATE) supply_date,
                           1 has_supply,
                           primary_transaction_quantity quantity
                      FROM apps.mtl_onhand_quantities_Detail moqd
                     WHERE organization_id = '
                || pn_organization_id
                || ' UNION ALL
                    SELECT /*+parallel(4) full(ms) full(msi) materialize*/
                          ms.organization_id,
                           msi.sr_inventory_item_id inventory_item_id,
                           TRUNC (
                              GREATEST (
                                 NVL (ms.last_unit_completion_Date,
                                      NVL (ms.firm_Date, ms.new_schedule_date)),
                                 TRUNC (SYSDATE)))
                              supply_date,
                           1 has_supply,
                           ms.new_order_quantity quantity
                      FROM apps.msc_supplies@ '
                || lv_dblink
                || ' ms ,
                           apps.msc_system_items@ '
                || lv_dblink
                || ' msi
                     WHERE     ms.plan_id = '
                || ln_plan_id
                || '
                  AND msi.organization_id = '
                || pn_organization_id
                || ' AND 1=1  AND ms.order_type = 5   AND msi.plan_id = ms.plan_id
                           AND msi.organization_id = ms.organization_id
                           AND msi.inventory_item_id = ms.inventory_item_id
                    UNION ALL
                    SELECT /*+parallel(4) full(oola) materialize*/
                          ship_from_org_id organization_id,
                           inventory_item_id,
                           GREATEST (TRUNC (schedule_ship_Date), TRUNC (SYSDATE))
                              supply_date,
                           0 has_supply,
                           - (GREATEST (
                                   NVL (ordered_quantity, 0)
                                 - NVL (fulfilled_quantity, 0),
                                 0))
                              quantity
                      FROM apps.oe_order_lines_all oola
                     WHERE     line_category_code = ''ORDER''
                           AND open_flag = ''Y''
                           AND visible_demand_flag = ''Y'' 
						     AND schedule_ship_date IS NOT NULL
                           AND ship_from_org_id = '
                || pn_organization_id
                || ' ) WHERE 1=1
          GROUP BY organization_id, inventory_item_id, supply_Date ) x, 
          msc_system_items@ '
                || lv_dblink
                || ' msi
                 WHERE x.inventory_item_id = msi.sr_inventory_item_id
                  AND msi.plan_id = '
                || ln_plan_id
                || ' AND msi.organization_id = '
                || pn_organization_id
                || ' AND 1=1 ';

            lv_neg_atp_items_grp_by   := '
             GROUP BY  x.inventory_item_id, 
                       x.organization_id
              HAVING MIN (poh) < 0';

            lv_neg_atp_items_ord_by   := '
              ORDER BY x.organization_id, 
                       x.inventory_item_id
                        ';

            IF pv_style IS NOT NULL
            THEN
                lv_style_cond   :=
                       ' AND SUBSTR(msi.item_name, 1, INSTR(msi.item_name, ''-'', 1)-1) = '''
                    || pv_style
                    || '''';
            ELSE
                lv_style_cond   := ' AND 1=1';
            END IF;

            IF pv_color IS NOT NULL
            THEN
                lv_color_cond   :=
                       ' AND SUBSTR(msi.item_name, INSTR(msi.item_name, ''-'', 1)+1, INSTR(msi.item_name, ''-'',1, 2)- INSTR(msi.item_name, ''-'', 1)-1) = '''
                    || pv_color
                    || '''';
            ELSE
                lv_color_cond   := ' AND 1=1';
            END IF;

            IF pv_size IS NOT NULL
            THEN
                lv_size_cond   :=
                       ' AND SUBSTR(msi.item_name, INSTR(msi.item_name, ''-'', -1)+1) = '''
                    || pv_size
                    || '''';
            ELSE
                lv_size_cond   := ' AND 1=1';
            END IF;
        ELSE
            lv_neg_atp_items_cur      :=
                   'SELECT msi.sr_inventory_item_id ebs_item_id,
                      msi.organization_id,
                      MIN (poh) negativity
                 FROM (SELECT alloc_date alloc_date,
                              tot_supply supply_qty,
                              tot_demand demand_qty,
                              tot_supply - tot_demand net_qty,
                              SUM (tot_supply - tot_demand) OVER (PARTITION BY inventory_item_id, demand_class ORDER BY inventory_item_id, demand_class, alloc_date) poh,
                              demand_class,
                              inventory_item_id
                         FROM (  SELECT alloc_date alloc_date,
                                        SUM (supply) tot_supply,
                                        SUM (demand) tot_demand,
                                        demand_class,
                                        inventory_item_id
                                   FROM (SELECT   
								                TRUNC (new_schedule_date) alloc_date, 
                                                new_order_quantity supply,            
                                                0 demand,
                                                ''-1'' demand_class,  
                                                inventory_item_id
                                           FROM msc_supplies@'
                || lv_dblink
                || '
                                          WHERE organization_id = '
                || pn_organization_id
                || '
                                                AND plan_id = '
                || ln_plan_id
                || '
                                         UNION ALL
                                         SELECT DECODE (SIGN(TRUNC(schedule_ship_date) - TRUNC(TO_DATE ('''
                || lv_plan_date
                || ''',''DD-MON-YYYY''))), 1, TRUNC(schedule_ship_date), TRUNC(TO_DATE ('''
                || lv_plan_date
                || ''', ''DD-MON-YYYY''))) alloc_date,
                                                0 supply,
                                                using_requirement_quantity demand, 
                                                ''-1'' demand_class,               
                                                inventory_item_id
                                           FROM msc_demands@'
                || lv_dblink
                || '
                                          WHERE plan_id = '
                || ln_plan_id
                || '
                                            AND organization_id = '
                || pn_organization_id
                || '
                                            AND schedule_ship_date IS NOT NULL '
                || '
                                        )
                               GROUP BY inventory_item_id, demand_class, alloc_date)) x,
                      msc_system_items@'
                || lv_dblink
                || ' msi
                WHERE x.inventory_item_id = msi.inventory_item_id
                  AND msi.plan_id = '
                || ln_plan_id
                || '
                  AND msi.organization_id = '
                || pn_organization_id
                || ' AND 1=1 ';

            lv_neg_atp_items_grp_by   := '
             GROUP BY  x.inventory_item_id, 
                       msi.sr_inventory_item_id,
                       msi.organization_id
              HAVING MIN (poh) < 0';

            lv_neg_atp_items_ord_by   := '
              ORDER BY msi.organization_id, 
                       msi.sr_inventory_item_id
                        ';

            IF pv_style IS NOT NULL
            THEN
                lv_style_cond   :=
                       ' AND SUBSTR(msi.item_name, 1, INSTR(msi.item_name, ''-'', 1)-1) = '''
                    || pv_style
                    || '''';
            ELSE
                lv_style_cond   := ' AND 1=1';
            END IF;

            IF pv_color IS NOT NULL
            THEN
                lv_color_cond   :=
                       ' AND SUBSTR(msi.item_name, INSTR(msi.item_name, ''-'', 1)+1, INSTR(msi.item_name, ''-'',1, 2)- INSTR(msi.item_name, ''-'', 1)-1) = '''
                    || pv_color
                    || '''';
            ELSE
                lv_color_cond   := ' AND 1=1';
            END IF;

            IF pv_size IS NOT NULL
            THEN
                lv_size_cond   :=
                       ' AND SUBSTR(msi.item_name, INSTR(msi.item_name, ''-'', -1)+1) = '''
                    || pv_size
                    || '''';
            ELSE
                lv_size_cond   := ' AND 1=1';
            END IF;
        END IF;

        lv_neg_atp_items_fin_cur       :=
               lv_neg_atp_items_cur
            || lv_style_cond
            || lv_color_cond
            || lv_size_cond
            || lv_neg_atp_items_grp_by
            || lv_neg_atp_items_ord_by;

        write_log ('lv_neg_atp_items_fin_cur ' || lv_neg_atp_items_fin_cur);
        write_log ('-------------------------------------------');
        write_log ('Negative ATP Items Query: ');
        write_log (
            'Timestamp: ' || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        write_log ('-------------------------------------------');
        write_log ('-------------------------------------------');

        ----*****************************
        --Opening the Neg ATP Items Cursor by Inventory Org
        ----*****************************
        gv_op_name                     :=
            'Opening the Neg ATP Items Cursor by Inventory Org ';

        OPEN neg_atp_items_cur FOR lv_neg_atp_items_fin_cur;

        FETCH neg_atp_items_cur BULK COLLECT INTO neg_atp_items_rec;

        CLOSE neg_atp_items_cur;

        ln_batch_id                    :=
            XXDO.XXD_ONT_AUTO_ATP_LEVL_BATCH_S.NEXTVAL;

        fnd_file.put_line (fnd_file.LOG, 'Batch ID : ' || ln_batch_id);

        --*******************************
        -- Populate neg POH Staging table
        --*******************************

        gv_op_key                      := 'Batch ID: ' || ln_batch_id;
        gv_op_name                     := ' Poulate SKU table with Negative ATP ';

        IF neg_atp_items_rec.COUNT > 0
        THEN
            write_log ('Before Data is inserted into SKU TABLE');

            FORALL y IN neg_atp_items_rec.FIRST .. neg_atp_items_rec.LAST
                INSERT INTO xxdo.XXD_ONT_AUTO_ATP_LEVL_SKU_T (
                                plan_id,
                                plan_date,
                                inventory_item_id,
                                organization_id,
                                --  alloc_date,
                                poh,
                                batch_id,
                                process_status,
                                request_id,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by)
                     VALUES (ln_plan_id, TRUNC (TO_DATE (lv_plan_date, 'DD-MON-YYYY')), neg_atp_items_rec (y).ebs_item_id, neg_atp_items_rec (y).organization_id, --neg_atp_items_rec (y).alloc_date,
                                                                                                                                                                  neg_atp_items_rec (y).negativity, ln_batch_id, 'N', gn_conc_request_id, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);

            ln_neg_cnt   := SQL%ROWCOUNT;
            COMMIT;
        ELSE
            RAISE ex_no_negative_records;
            write_log ('No Order lines returned for the Item - ');
        END IF;

        neg_atp_items_rec.delete;

        write_log (
               'Number of records inserted into Neg ATP Items Temp Table:'
            || ln_cnt);
        write_log ('Start of getting Supply demand records');
        write_log (
            'Timestamp: ' || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));


        gv_op_key                      := 'Batch ID: ' || ln_batch_id;
        gv_op_name                     := ' Poulate SKU table with Negative ATP';

        lv_neg_atp_sup_demand_cur      :=
               'SELECT msi.sr_inventory_item_id Inventory_item_id,
                      msi.organization_id,
                      alloc_date,
                      supply_qty,
                      demand_qty,
					  net_qty,
					  poh
                 FROM (SELECT alloc_date alloc_date,
                              tot_supply supply_qty,
                              tot_demand demand_qty,
                              tot_supply - tot_demand net_qty,
                              SUM (tot_supply - tot_demand) OVER (PARTITION BY inventory_item_id, demand_class ORDER BY inventory_item_id, demand_class, alloc_date) poh,
                              demand_class,
                              inventory_item_id
                         FROM (  SELECT alloc_date alloc_date,
                                        SUM (supply) tot_supply,
                                        SUM (demand) tot_demand,
                                        demand_class,
                                        inventory_item_id
                                   FROM (SELECT   
								                TRUNC (new_schedule_date) alloc_date, 
                                                new_order_quantity supply,            
                                                0 demand,
                                                ''-1'' demand_class,  
                                                inventory_item_id
                                           FROM msc_supplies@'
            || lv_dblink
            || '
                                          WHERE organization_id = '
            || pn_organization_id
            || '
                                                AND plan_id = '
            || ln_plan_id
            || '
                                         UNION ALL
                                         SELECT DECODE (SIGN(TRUNC(schedule_ship_date) - TRUNC(TO_DATE ('''
            || lv_plan_date
            || ''',''DD-MON-YYYY''))), 1, TRUNC(schedule_ship_date), TRUNC(TO_DATE ('''
            || lv_plan_date
            || ''', ''DD-MON-YYYY''))) alloc_date,
                                                0 supply,
                                                using_requirement_quantity demand, 
                                                ''-1'' demand_class,               
                                                inventory_item_id
                                           FROM msc_demands@'
            || lv_dblink
            || '
                                          WHERE plan_id = '
            || ln_plan_id
            || '
                                            AND organization_id = '
            || pn_organization_id
            || '
                                            AND schedule_ship_date IS NOT NULL '
            || '
                                        )
                               GROUP BY inventory_item_id, demand_class, alloc_date)) x,
                      msc_system_items@'
            || lv_dblink
            || ' msi
                WHERE x.inventory_item_id = msi.inventory_item_id
                  AND msi.plan_id = '
            || ln_plan_id
            || '
                  AND msi.organization_id = '
            || pn_organization_id;

        lv_inventory_item_id_cond      :=
               '  AND sr_inventory_item_id IN (select distinct xoa.inventory_item_id FROM XXDO.XXD_ONT_AUTO_ATP_LEVL_SKU_T xoa,apps.xxd_common_items_v ms Where batch_id = '
            || ln_batch_id
            || ' 
			   AND xoa.inventory_item_id=ms.inventory_item_id AND ms.organization_id = xoa.organization_id ';

        IF pv_brand IS NOT NULL
        THEN
            lv_brand_cond   := ' AND ms.brand =''' || pv_brand || ''' ) ';
        ELSE
            lv_brand_cond   := ' ) ';
        END IF;


        lv_neg_atp_sup_demd_grp_by     := '
             GROUP BY  x.inventory_item_id, 
                       alloc_date, 
                       msi.sr_inventory_item_id,
                       msi.organization_id,
                       supply_qty,
                       demand_qty,
                       net_qty,
                       poh ';

        lv_neg_atp_sup_demand_ord_by   := '
              ORDER BY msi.organization_id, 
                       msi.sr_inventory_item_id
                        ';

        lv_demand_supply_query         :=
               lv_neg_atp_sup_demand_cur
            || lv_inventory_item_id_cond
            || lv_brand_cond
            || lv_neg_atp_sup_demd_grp_by
            || lv_neg_atp_sup_demand_ord_by;


        write_log ('lv_demand_supply_query ' || lv_demand_supply_query);

        ----*****************************
        --Opening the Neg ATP Items Cursor by Inventory Org
        ----*****************************
        OPEN neg_atp_items_cur FOR lv_demand_supply_query;

        FETCH neg_atp_items_cur BULK COLLECT INTO item_supply_demand_rec;

        CLOSE neg_atp_items_cur;

        write_log ('ln_batch_id ' || ln_batch_id);

        ----*****************************
        --Gather the supply demand picture
        ----*****************************
        gv_op_key                      := 'Batch ID: ' || ln_batch_id;
        gv_op_name                     :=
            ' Poulate Supply demand table for negative SKUs ';

        IF item_supply_demand_rec.COUNT > 0
        THEN
            write_log (
                'Before Data is inserted into suppy demand picture TABLE');
            write_log (
                'Timestamp: ' || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

            FORALL y
                IN item_supply_demand_rec.FIRST ..
                   item_supply_demand_rec.LAST
                INSERT INTO xxdo.XXD_ONT_AUTO_ATP_SPLY_DMAND_T (
                                Inventory_item_id,
                                organization_id,
                                alloc_date,
                                Supply,
                                demand,
                                net_qty,
                                poh,
                                batch_id,
                                process_status,
                                request_id,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by)
                     VALUES (item_supply_demand_rec (y).Inventory_item_id, item_supply_demand_rec (y).organization_id, item_supply_demand_rec (y).alloc_date, item_supply_demand_rec (y).Supply, item_supply_demand_rec (y).demand, item_supply_demand_rec (y).net_qty, item_supply_demand_rec (y).poh, ln_batch_id, 'N', gn_conc_request_id, SYSDATE, gn_user_id
                             , SYSDATE, gn_user_id);

            ln_cnt   := SQL%ROWCOUNT;

            COMMIT;
        ELSE
            write_log (
                'No Order lines returned for item_supply_demand_rec Cusrsor- ');
            RAISE ex_no_negative_records;
        END IF;

        --Delete the records that are processed from plsql table
        item_supply_demand_rec.delete;
        write_log ('Total number of negative SKUs ' || ln_cnt);

        ----*****************************
        --Popultae the summary table
        ----*****************************

        write_log ('Before Data is inserted into Summary TABLE');
        write_log (
            'Timestamp: ' || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));


        gv_op_key                      := 'Batch ID: ' || ln_batch_id;
        gv_op_name                     :=
            'Poulate ATP Summary table for negative SKUs ';

        BEGIN
            INSERT INTO xxdo.XXD_ONT_AUTO_ATP_LEVL_SUMRY_T (
                            SEQ_NUMBER,
                            inventory_item_id,
                            organization_id,
                            neg_date,
                            neg_qty,
                            neg_edate,
                            batch_id,
                            process_status,
                            request_id,
                            creation_date,
                            created_by,
                            last_update_date,
                            last_updated_by)
                SELECT ROW_NUMBER () OVER (PARTITION BY inventory_item_id ORDER BY inventory_item_id) SEQ, tab.inventory_item_id, organization_id,
                       tab.neg_date, tab.poh, tab.neg_edate,
                       ln_batch_id, 'N', gn_conc_request_id,
                       SYSDATE, gn_user_id, SYSDATE,
                       gn_user_id
                  FROM (  SELECT sd.inventory_item_id, sd.organization_id, sd.alloc_date neg_date,
                                 sd.poh, LEAD (POH, 1, 0) OVER (PARTITION BY inventory_item_id ORDER BY inventory_item_id, alloc_date) AS next_positive_poh, LEAD (alloc_date, 1, NULL) OVER (PARTITION BY inventory_item_id ORDER BY inventory_item_id, alloc_date) NEG_EDATE
                            FROM xxdo.XXD_ONT_AUTO_ATP_SPLY_DMAND_T sd
                           WHERE batch_id = ln_batch_id
                        ORDER BY inventory_item_id, alloc_date) tab
                 WHERE POH <= 0 AND next_positive_poh >= 0;

            ln_summary_cnt   := SQL%ROWCOUNT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Exception while populating XXD_ONT_AUTO_ATP_LEVL_SUMRY_T '
                    || SQLERRM);
        END;



        ----*****************************
        --Popultae the order table
        ----*****************************

        ln_item_id                     := NULL;

        IF ln_summary_cnt > 0
        THEN
            write_log ('Before Data is inserted into Order TABLE');
            write_log (
                'Timestamp: ' || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            write_log ('-------------------------------------------');


            gv_op_name   := ' Order table Populate ';

            FOR rec_neg_atp_order_sku IN neg_atp_order_sku (ln_batch_id)
            LOOP
                ln_safe_ex_qty       := 0;
                ln_atrisk_ex_qty     := 0;
                ln_remaining_qty     := 0;
                lv_process_further   := 'Y';

                gv_op_key            :=
                    'Item ID: ' || rec_neg_atp_order_sku.inventory_item_id;

                BEGIN
                    INSERT INTO XXDO.XXD_ONT_AUTO_ATP_LEVL_ORDRS_T (
                                    batch_id,
                                    seq_number,
                                    inventory_item_id,
                                    item_number,
                                    brand,
                                    header_id,
                                    line_id,
                                    line_num,
                                    atp_postive_date,
                                    sold_to_org_id,
                                    account_number,
                                    ship_from_org_id,
                                    org_id,
                                    ordered_quantity,
                                    order_creation_date,
                                    request_date,
                                    ordered_date,
                                    schedule_ship_date,
                                    latest_acceptable_date,
                                    cancel_date,
                                    safe_move_days,
                                    atrisk_move_days,
                                    bulk_identifier,
                                    override_atp_flag,
                                    order_quantity_uom,
                                    sf_el_flag,
                                    sf_ex_flag,
                                    ar_el_flag,
                                    ar_ex_flag,
                                    un_el_flag,
                                    un_ex_flag,
                                    process_status,
                                    request_id,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by)
                        SELECT ln_batch_id, rec_neg_atp_order_sku.seq_number, oola.inventory_item_id,
                               oola.ordered_item, ooha.attribute5, oola.header_id,
                               line_id, line_number || '.' || oola.shipment_number line_num, rec_neg_atp_order_sku.neg_edate,
                               oola.sold_to_org_id customer_id, hca.account_number, oola.ship_from_org_id,
                               oola.org_id, ordered_quantity, NVL (DECODE (ooha.order_source_id, 2, get_source_order_line_date (oola.header_id, oola.source_document_line_id, 'CREATION_DATE'), oola.creation_date), oola.creation_date),
                               NVL (DECODE (ooha.order_source_id, 2, get_source_order_line_date (oola.header_id, oola.source_document_line_id, 'REQUEST_DATE'), oola.request_date), oola.request_date), NVL (DECODE (ooha.order_source_id, 2, get_source_order_line_date (oola.header_id, oola.source_document_line_id, 'ORDERED_DATE'), ooha.ordered_date), ooha.ordered_date), schedule_ship_date,
                               latest_acceptable_date, TO_DATE (NVL (oola.attribute1, ooha.attribute1), 'YYYY/MM/DD HH24:MI:SS') cancel_date, flv.attribute3,
                               flv.attribute4, oola.global_attribute19, override_atp_date_code,
                               order_quantity_uom, NULL, NULL,
                               NULL, NULL, NULL,
                               NULL, 'N', gn_conc_request_id,
                               SYSDATE, gn_user_id, SYSDATE,
                               gn_user_id
                          FROM oe_order_lines_all oola, oe_order_headers_all ooha, hz_cust_accounts hca,
                               mtl_parameters mp, fnd_lookup_values_vl flv
                         WHERE     1 = 1
                               AND oola.header_id = ooha.header_id
                               AND oola.booked_flag = 'Y'
                               AND oola.sold_to_org_id = hca.cust_account_id
                               AND oola.schedule_ship_date <
                                   NVL (rec_neg_atp_order_sku.neg_edate,
                                        SYSDATE + 2000)
                               AND lookup_type(+) =
                                      'XXD_ATP_LEVEL_DEF1_'
                                   || ooha.attribute5
                                   || '_'
                                   || mp.organization_code
                               AND flv.attribute1(+) = hca.cust_account_id
                               AND mp.organization_id = oola.ship_from_org_id
                               AND enabled_flag(+) = 'Y'
                               AND oola.inventory_item_id =
                                   rec_neg_atp_order_sku.inventory_item_id
                               AND oola.ship_from_org_id = pn_organization_id
                               AND NVL (oola.open_flag, 'N') = 'Y'
                               AND oola.schedule_ship_date IS NOT NULL
                               AND oola.flow_status_code <> 'ENTERED'
                               AND oola.line_category_code = 'ORDER'
                               AND NOT EXISTS
                                       (SELECT '1'
                                          FROM wsh_delivery_details wdd
                                         WHERE     source_line_id =
                                                   oola.line_id
                                               AND wdd.source_code = 'OE'
                                               AND wdd.released_status IN
                                                       ('C', 'Y', 'D',
                                                        'S') --C=Shipped, Y=Staged/Pick Confirmed, D=Cancelled, S=Released to Warehouse
                                                            )
                               AND NOT EXISTS
                                       (SELECT '1'
                                          FROM apps.mtl_reservations
                                         WHERE     1 = 1
                                               AND demand_source_line_id =
                                                   oola.line_id -- AND org_ig = oola.org_id
                                                               );
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_process_further   := 'N';
                        write_log (
                               'Exception while populating XXD_ONT_AUTO_ATP_LEVL_ORDRS_T for Item '
                            || rec_neg_atp_order_sku.inventory_item_id
                            || ' Error '
                            || SQLERRM);
                END;

                IF lv_process_further = 'Y'
                THEN
                    lv_processing_move   := NVL (pv_Processing_Move, 'ALL');

                    IF rec_neg_atp_order_sku.neg_edate IS NULL
                    THEN
                        lv_processing_move   := 'UNSCHEDULE_MOVE';
                    END IF;

                    write_log (
                           'Before calling proc get_safe_move_qty Item '
                        || rec_neg_atp_order_sku.inventory_item_id);
                    write_log (
                           'Timestamp: '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                    write_log ('-------------------------------------------');

                    --************************************
                    --Call safe move proc get_safe_move_qty
                    --************************************

                    IF    lv_processing_move = 'SAFE_MOVE'
                       OR lv_processing_move = 'ALL'
                    THEN
                        gv_op_name   := ' Call get_safe_move_qty ';
                        get_safe_move_qty (pn_batch_id => rec_neg_atp_order_sku.batch_id, pn_item_id => rec_neg_atp_order_sku.inventory_item_id, pv_brand => rec_neg_atp_order_sku.brand, pn_seq_number => rec_neg_atp_order_sku.seq_number, pn_organization_id => rec_neg_atp_order_sku.organization_id, pn_organization_code => rec_neg_atp_order_sku.organization_code, pn_neg_qty => rec_neg_atp_order_sku.neg_qty, pn_safe_move_days => rec_neg_atp_order_sku.safe_move_days, pv_atrisk_flag => lv_atrisk_flag
                                           , pn_safe_ex_qty => ln_safe_ex_qty);
                    END IF;

                    IF    lv_processing_move = 'ATRISK_MOVE'
                       OR lv_processing_move = 'ALL'
                    THEN
                        write_log ('lv_atrisk_flag ' || lv_atrisk_flag);

                        IF NVL (lv_atrisk_flag, 'N') = 'Y'
                        THEN
                            ln_remaining_qty   :=
                                  ABS (rec_neg_atp_order_sku.neg_qty)
                                - ln_safe_ex_qty;
                            --***************************************
                            --Call at risk proc  get_at_risk_move_qty
                            --***************************************

                            write_log (
                                'Before calling proc get_at_risk_move_qty');
                            write_log (
                                   'Timestamp: '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-RRRR HH24:MI:SS'));
                            write_log (
                                '-------------------------------------------');

                            gv_op_name   := ' Call get_at_risk_move_qty ';
                            get_at_risk_move_qty (
                                pn_batch_id           =>
                                    rec_neg_atp_order_sku.batch_id,
                                pn_item_id            =>
                                    rec_neg_atp_order_sku.inventory_item_id,
                                pv_brand              => rec_neg_atp_order_sku.brand,
                                pn_seq_number         =>
                                    rec_neg_atp_order_sku.seq_number,
                                pn_organization_id    =>
                                    rec_neg_atp_order_sku.organization_id,
                                pn_organization_code   =>
                                    rec_neg_atp_order_sku.organization_code,
                                pn_neg_qty            => ln_remaining_qty,
                                pn_atrisk_move_days   =>
                                    rec_neg_atp_order_sku.atrisk_move_days,
                                pn_safe_ex_qty        => ln_safe_ex_qty,
                                pv_unschedule_flag    => lv_unschedule_flag,
                                pn_atrisk_ex_qty      => ln_atrisk_ex_qty);
                        ELSE
                            lv_unschedule_flag   := 'N';
                        END IF;


                        IF    lv_processing_move = 'UNSCHEDULE_MOVE'
                           OR lv_processing_move = 'ALL'
                        THEN
                            IF lv_unschedule_flag = 'Y'
                            THEN
                                write_log (
                                       'neg_qty '
                                    || rec_neg_atp_order_sku.neg_qty
                                    || 'ln_atrisk_ex_qty : '
                                    || ln_atrisk_ex_qty
                                    || ' ln_safe_ex_qty '
                                    || ln_safe_ex_qty);

                                IF NVL (ln_item_id, '00000') <>
                                   rec_neg_atp_order_sku.inventory_item_id
                                THEN
                                    ln_remaining_seq_qty   := 0;
                                    ln_remaining_qty       :=
                                          ABS (rec_neg_atp_order_sku.neg_qty)
                                        - (ln_atrisk_ex_qty + ln_safe_ex_qty);
                                ELSE
                                    ln_remaining_qty   :=
                                          ABS (rec_neg_atp_order_sku.neg_qty)
                                        - (ln_atrisk_ex_qty + ln_safe_ex_qty)
                                        - ABS (ln_remaining_seq_qty);
                                END IF;

                                --****************************************
                                --Call proc unshedule  get_unschedule_move_qty
                                --****************************************

                                write_log (
                                    'Before calling proc get_unschedule_move_qty');
                                write_log (
                                       'Timestamp: '
                                    || TO_CHAR (SYSDATE,
                                                'DD-MON-RRRR HH24:MI:SS'));
                                write_log (
                                    '-------------------------------------------');
                                write_log (
                                       'inventory_item_id '
                                    || rec_neg_atp_order_sku.inventory_item_id
                                    || ' Seq '
                                    || rec_neg_atp_order_sku.seq_number
                                    || 'ln_remaining_qty : '
                                    || ln_remaining_qty
                                    || ' ln_remaining_seq_qty '
                                    || ln_remaining_seq_qty);

                                IF ln_remaining_qty > 0
                                THEN
                                    gv_op_name   :=
                                        ' Call get_unschedule_move_qty ';
                                    get_unschedule_move_qty (
                                        pn_batch_id    =>
                                            rec_neg_atp_order_sku.batch_id,
                                        pn_item_id     =>
                                            rec_neg_atp_order_sku.inventory_item_id,
                                        pv_brand       =>
                                            rec_neg_atp_order_sku.brand,
                                        pn_seq_number   =>
                                            rec_neg_atp_order_sku.seq_number,
                                        pn_organization_id   =>
                                            rec_neg_atp_order_sku.organization_id,
                                        pn_organization_code   =>
                                            rec_neg_atp_order_sku.organization_code,
                                        pn_neg_qty     => ln_remaining_qty,
                                        pn_unsch_qty   => ln_unsch_qty);
                                END IF;

                                ln_remaining_seq_qty   :=
                                    ln_remaining_qty + ln_remaining_seq_qty;
                                ln_item_id   :=
                                    rec_neg_atp_order_sku.inventory_item_id;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END LOOP;

            COMMIT;

            IF pv_execution_mode = 'SIMULATE AND EXECUTE'
            THEN
                IF    lv_processing_move = 'UNSCHEDULE_MOVE'
                   OR lv_processing_move = 'ALL'
                THEN
                    --****************************************
                    --Call Unschedule execution
                    --****************************************
                    gv_op_name   :=
                        ' Call launch_worker_programs UNSCHEDULE_MOVE';
                    launch_worker_programs (pn_batch_id => ln_batch_id, pn_organization_id => pn_organization_id, pv_brand => pv_brand, pn_batch_size => ln_max_rec_cnt, pn_threads => pn_threads, pv_Processing_Move => 'UNSCHEDULE_MOVE'
                                            , pv_exclude => pv_exclude);
                END IF;

                DBMS_LOCK.Sleep (10);
                ln_worker_req   := 2;

                WHILE ln_worker_req > 0
                LOOP
                    write_log (' loop start ln_worker_req ' || ln_worker_req);

                    SELECT COUNT (1)
                      INTO ln_worker_req
                      FROM fnd_concurrent_programs fcp, fnd_concurrent_requests fc
                     WHERE     fcp.concurrent_program_name =
                               'XXD_ONT_AUTO_ATP_LEVL_WORKER'
                           AND fc.concurrent_program_id =
                               fcp.concurrent_program_id
                           AND argument6 = 'UNSCHEDULE_MOVE'
                           AND fc.parent_request_id =
                               fnd_global.conc_request_id
                           AND fc.phase_code IN ('R', 'P');

                    IF ln_worker_req > 0
                    THEN
                        DBMS_LOCK.Sleep (10);
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;

                IF    lv_processing_move = 'ATRISK_MOVE'
                   OR lv_processing_move = 'ALL'
                --****************************************
                --Call atrisk execution
                --****************************************
                THEN
                    gv_op_name   :=
                        ' Call launch_worker_programs ATRISK_MOVE';
                    launch_worker_programs (pn_batch_id => ln_batch_id, pn_organization_id => pn_organization_id, pv_brand => pv_brand, pn_batch_size => ln_max_rec_cnt, pn_threads => pn_threads, pv_Processing_Move => 'ATRISK_MOVE'
                                            , pv_exclude => pv_exclude);
                END IF;

                DBMS_LOCK.Sleep (10);
                ln_worker_req   := 2;

                WHILE ln_worker_req > 0
                LOOP
                    write_log (' loop start ln_worker_req ' || ln_worker_req);

                    SELECT COUNT (1)
                      INTO ln_worker_req
                      FROM fnd_concurrent_programs fcp, fnd_concurrent_requests fc
                     WHERE     fcp.concurrent_program_name =
                               'XXD_ONT_AUTO_ATP_LEVL_WORKER'
                           AND fc.concurrent_program_id =
                               fcp.concurrent_program_id
                           AND argument6 = 'ATRISK_MOVE'
                           AND fc.parent_request_id =
                               fnd_global.conc_request_id
                           AND fc.phase_code IN ('R', 'P');

                    IF ln_worker_req > 0
                    THEN
                        write_log ('IF ln_worker_req ' || ln_worker_req);
                        DBMS_LOCK.Sleep (10);
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;


                IF    lv_processing_move = 'SAFE_MOVE'
                   OR lv_processing_move = 'ALL'
                --****************************************
                --Call save move execution
                --****************************************
                THEN
                    gv_op_name   := ' Call launch_worker_programs SAFE_MOVE';
                    launch_worker_programs (pn_batch_id => ln_batch_id, pn_organization_id => pn_organization_id, pv_brand => pv_brand, pn_batch_size => ln_max_rec_cnt, pn_threads => pn_threads, pv_Processing_Move => 'SAFE_MOVE'
                                            , pv_exclude => pv_exclude);
                END IF;

                DBMS_LOCK.Sleep (10);

                ln_worker_req   := 2;

                WHILE ln_worker_req > 0
                LOOP
                    write_log (' loop start ln_worker_req ' || ln_worker_req);

                    SELECT COUNT (1)
                      INTO ln_worker_req
                      FROM fnd_concurrent_programs fcp, fnd_concurrent_requests fc
                     WHERE     fcp.concurrent_program_name =
                               'XXD_ONT_AUTO_ATP_LEVL_WORKER'
                           AND fc.concurrent_program_id =
                               fcp.concurrent_program_id
                           AND argument6 = 'SAFE_MOVE'
                           AND fc.parent_request_id =
                               fnd_global.conc_request_id
                           AND fc.phase_code IN ('R', 'P');

                    IF ln_worker_req > 0
                    THEN
                        DBMS_LOCK.Sleep (10);
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;

                IF    lv_processing_move = 'SPLIT_CASE'
                   OR lv_processing_move = 'ALL'
                --****************************************
                --Call atrisk execution
                --****************************************
                THEN
                    gv_op_name   := ' Call launch_worker_programs SPLIT_CASE';
                    launch_worker_programs (pn_batch_id => ln_batch_id, pn_organization_id => pn_organization_id, pv_brand => pv_brand, pn_batch_size => ln_max_rec_cnt, pn_threads => pn_threads, pv_Processing_Move => 'SPLIT_CASE'
                                            , pv_exclude => pv_exclude);
                END IF;


                DBMS_LOCK.Sleep (10);
                ln_worker_req   := 2;

                WHILE ln_worker_req > 0
                LOOP
                    write_log (' loop start ln_worker_req ' || ln_worker_req);

                    SELECT COUNT (1)
                      INTO ln_worker_req
                      FROM fnd_concurrent_programs fcp, fnd_concurrent_requests fc
                     WHERE     fcp.concurrent_program_name =
                               'XXD_ONT_AUTO_ATP_LEVL_WORKER'
                           AND fc.concurrent_program_id =
                               fcp.concurrent_program_id
                           AND argument6 = 'SPLIT_CASE'
                           AND fc.parent_request_id =
                               fnd_global.conc_request_id
                           AND fc.phase_code IN ('R', 'P');

                    IF ln_worker_req > 0
                    THEN
                        DBMS_LOCK.Sleep (10);
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;
            END IF;

            --****************************************
            --Call output procedure
            --****************************************

            write_log (
                   'Calling Report output Procedure at '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            audit_report (ln_batch_id, pn_organization_id, pv_brand);
            write_log (
                   'Audit Report output Procedure completed at '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

            --****************************************
            --Call proc email
            --****************************************

            write_log (
                   'Calling Emailing Procedure at '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            email_output (ln_batch_id, pn_organization_id, pv_brand);
            write_log (
                   'Emailing Procedure completed at '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'End of the Main program: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
    EXCEPTION
        WHEN ex_no_negative_records
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'There is no Negative record in the system for the given Inputs');
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in main proc procedure for Batch :'
                || ln_batch_id
                || '  '
                || gv_op_name
                || ' Error '
                || SQLERRM);
    END;
END XXD_ONT_AUTOMATED_ATP_LEVELING;
/
