--
-- XXD_ONT_FREE_ATP_BLK_OM_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_FREE_ATP_BLK_OM_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_FREE_ATP_BLK_OM_PKG
    -- Design       : This package will be called by the Deckers Free ATP Bulk Order Management Program.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name               Ver    Description
    -- ----------      --------------    -----  ------------------
    -- 02-May-2022     Jayarajan A K      1.0    Initial Version (CCR0009893)
    -- 16-Jun-2022     Jayarajan A K      1.1    Modified for changing ouput dir
    -- 16-Jun-2022     Jayarajan A K      1.2    Modified for addititional sales channel codes
    -- 14-Jul-2022     Jayarajan A K      1.3    Modified to fix UAT issue
    -- 26-Oct-2022     Shivanshu          1.4    Exclude split lines - CCR0010180
    -- 02-Dec-2022     Jayarajan A K      1.5    Handled the scenario where the total cancel qty > first line qty
    -- #########################################################################################################################
    gn_request_id   NUMBER := fnd_global.conc_request_id;

    --  insert_message procedure
    PROCEDURE insrt_msg (pv_message_type   IN VARCHAR2,
                         pv_message        IN VARCHAR2,
                         pv_debug          IN VARCHAR2 := 'N')
    AS
    BEGIN
        IF UPPER (pv_message_type) IN ('LOG', 'BOTH') AND pv_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, pv_message);
        END IF;

        IF UPPER (pv_message_type) IN ('OUTPUT', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.OUTPUT, pv_message);
        END IF;

        IF UPPER (pv_message_type) = 'DATABASE'
        THEN
            DBMS_OUTPUT.put_line (pv_message);
        END IF;
    END insrt_msg;

    --Start changes v1.1
    FUNCTION email_recipients (p_org_id IN NUMBER)
        RETURN apps.do_mail_utils.tbl_recips
    IS
        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;

        CURSOR recipients_cur IS
            SELECT description email_id
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_OM_FATP_BO_MGT_RPT_USERS'
                   AND flv.language = USERENV ('LANG')
                   AND flv.tag = p_org_id
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE));
    BEGIN
        lv_def_mail_recips.delete;

        FOR recipients_rec IN recipients_cur
        LOOP
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                recipients_rec.email_id;
        END LOOP;

        RETURN lv_def_mail_recips;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'Batch.OM@deckers.com';
            RETURN lv_def_mail_recips;
    END email_recipients;

    --End changes v1.1

    PROCEDURE generate_output (p_org_id IN NUMBER, p_debug IN VARCHAR2:= 'N')
    AS
        lv_line              VARCHAR2 (32767) := NULL;
        lv_message           VARCHAR2 (32000);
        lv_file_delimiter    VARCHAR2 (1) := CHR (9);
        ln_count             NUMBER := 0;
        lv_blk_ordr          VARCHAR2 (100);
        lv_blk_ord_typ       VARCHAR2 (100);
        lv_blk_acc_num       VARCHAR2 (100);
        lv_blk_lne_num       VARCHAR2 (100);
        lv_blk_rqst_dt       VARCHAR2 (100);

        --Start changes v1.1
        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;
        ln_ret_val           NUMBER := 0;

        --End changes v1.1

        CURSOR output_cur IS
            SELECT org_id,
                   (SELECT name
                      FROM hr_operating_units
                     WHERE organization_id = stg.org_id) op_unit,
                   ship_from_org_id,
                   (SELECT organization_code
                      FROM mtl_parameters
                     WHERE organization_id = stg.ship_from_org_id) ship_from,
                   brand,
                   co_hdr_id,
                   (SELECT order_number
                      FROM oe_order_headers_all
                     WHERE header_id = stg.co_hdr_id) co_order,
                   order_type_id,
                   (SELECT name
                      FROM oe_transaction_types_tl
                     WHERE     transaction_type_id = stg.order_type_id
                           AND language = USERENV ('LANG')) order_type,
                   sold_to_org_id,
                   (SELECT account_number
                      FROM hz_cust_accounts
                     WHERE cust_account_id = stg.sold_to_org_id) account_num,
                   co_lne_id,
                   (SELECT line_number || '.' || shipment_number
                      FROM oe_order_lines_all
                     WHERE line_id = stg.co_lne_id) line_num,
                   inventory_item_id,
                   (SELECT segment1
                      FROM mtl_system_items_b
                     WHERE     inventory_item_id = stg.inventory_item_id
                           AND organization_id = 106) sku,
                   quantity,
                   request_date,
                   free_atp_qty,
                   old_glb_attr19,
                   (SELECT global_attribute19
                      FROM oe_order_lines_all
                     WHERE line_id = stg.co_lne_id) new_glb_attr19,
                   process_mode,
                   NVL (blk_lne_id, 0) blk_lne_id,
                   reduce_qty,
                   MESSAGE
              FROM xxdo.xxd_ont_free_atp_blk_stg_t stg
             WHERE stg.request_id = gn_request_id;
    BEGIN
        insrt_msg ('LOG', 'Inside generate_output Procedure', 'Y');

        --Start changes v1.1
        --Getting the email recipients and assigning them to a table type variable
        lv_def_mail_recips   := email_recipients (p_org_id);

        IF lv_def_mail_recips.COUNT < 1
        THEN
            insrt_msg (
                'LOG',
                'No recipients configured to receive email. Please check the lookup',
                'Y');
        ELSE
            --Getting the instance name
            BEGIN
                SELECT applications_system_name
                  INTO lv_appl_inst_name
                  FROM apps.fnd_product_groups;
            EXCEPTION
                WHEN OTHERS
                THEN
                    insrt_msg ('LOG',
                               'Unable to fetch the File server name',
                               'Y');
            END;

            apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), lv_def_mail_recips, 'Call off Free ATP Consumption detailed report ' || TO_CHAR (SYSDATE, 'RRRR-MON-DD') || '_' || TO_CHAR (SYSDATE, 'HH24MISS') || ' from ' || lv_appl_inst_name || ' instance'
                                                 , ln_ret_val);

            lv_message   :=
                   'Dear Recipient,'
                || CHR (10)
                || CHR (10)
                || 'Please find attached the Call-off orders that were processed by the Deckers Free ATP Bulk Order Management Program'
                || CHR (10)
                || 'Request Id: '
                || gn_request_id
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'IT Operation'
                || CHR (10)
                || 'Deckers Outdoor'
                || CHR (10)
                || CHR (10)
                || 'Note: This is an auto generated email, please donot reply';

            apps.do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line (lv_message, ln_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring',
                                               ln_ret_val);

            apps.do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="CO_FREEATP_CONSUMPTION_REPORT_'
                || TO_CHAR (SYSDATE, 'RRRR-MON-DD')
                || '_'
                || TO_CHAR (SYSDATE, 'HH24MISS')
                || '.xls"',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            --End changes v1.1

            lv_line   :=
                   'Operating Unit'
                || lv_file_delimiter
                || 'Ship From Org'
                || lv_file_delimiter
                || 'Brand'
                || lv_file_delimiter
                || 'CO#'
                || lv_file_delimiter
                || 'Order Type'
                || lv_file_delimiter
                || 'Account Number'
                || lv_file_delimiter
                || 'SO Line#'
                || lv_file_delimiter
                || 'SKU'
                || lv_file_delimiter
                || 'Order Qty'
                || lv_file_delimiter
                || 'Request Date'
                || lv_file_delimiter
                || 'Qty consumed from free ATP'
                || lv_file_delimiter
                || 'Global_Attribute19 (Old)'
                || lv_file_delimiter
                || 'Global_Attribute19 (New)'
                || lv_file_delimiter
                || 'Processing mode'
                || lv_file_delimiter
                || 'BO#'
                || lv_file_delimiter
                || 'Bulk Order Type'
                || lv_file_delimiter
                || 'BO Account Number'
                || lv_file_delimiter
                || 'BO Line#'
                || lv_file_delimiter
                || 'BO Request Date'
                || lv_file_delimiter
                || 'Reduced Qty'
                || lv_file_delimiter
                || 'Error Message';

            insrt_msg ('OUTPUT', lv_line);
            apps.do_mail_utils.send_mail_line (lv_line, ln_ret_val);    --v1.1

            FOR output_rec IN output_cur
            LOOP
                ln_count         := ln_count + 1;
                lv_blk_ordr      := NULL;
                lv_blk_ord_typ   := NULL;
                lv_blk_acc_num   := NULL;
                lv_blk_lne_num   := NULL;
                lv_blk_rqst_dt   := NULL;

                IF output_rec.blk_lne_id = 0
                THEN
                    insrt_msg ('LOG',
                               'lv_blk_ordr: ' || lv_blk_ordr,
                               p_debug);
                ELSIF output_rec.blk_lne_id = 5
                THEN
                    lv_blk_ordr   := 'MULTIPLE';
                ELSE
                    BEGIN
                        SELECT oola.line_number || '.' || oola.shipment_number, oola.request_date, ooha.order_number,
                               ott.name, hca.account_number
                          INTO lv_blk_lne_num, lv_blk_rqst_dt, lv_blk_ordr, lv_blk_ord_typ,
                                             lv_blk_acc_num
                          FROM oe_order_lines_all oola, oe_order_headers_all ooha, oe_transaction_types_tl ott,
                               hz_cust_accounts hca
                         WHERE     oola.line_id = output_rec.blk_lne_id
                               AND ooha.header_id = oola.header_id
                               AND ott.transaction_type_id =
                                   ooha.order_type_id
                               AND ott.language = USERENV ('LANG')
                               AND hca.cust_account_id = ooha.sold_to_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            insrt_msg (
                                'LOG',
                                   'Error while fetching Bulk Order Details: '
                                || SQLERRM,
                                p_debug);
                    END;
                END IF;

                lv_line          :=
                       output_rec.op_unit
                    || lv_file_delimiter
                    || output_rec.ship_from
                    || lv_file_delimiter
                    || output_rec.brand
                    || lv_file_delimiter
                    || output_rec.co_order
                    || lv_file_delimiter
                    || output_rec.order_type
                    || lv_file_delimiter
                    || output_rec.account_num
                    || lv_file_delimiter
                    || output_rec.line_num
                    || lv_file_delimiter
                    || output_rec.sku
                    || lv_file_delimiter
                    || output_rec.quantity
                    || lv_file_delimiter
                    || output_rec.request_date
                    || lv_file_delimiter
                    || output_rec.free_atp_qty
                    || lv_file_delimiter
                    || output_rec.old_glb_attr19
                    || lv_file_delimiter
                    || output_rec.new_glb_attr19
                    || lv_file_delimiter
                    || output_rec.process_mode
                    || lv_file_delimiter
                    || lv_blk_ordr
                    || lv_file_delimiter
                    || lv_blk_ord_typ
                    || lv_file_delimiter
                    || lv_blk_acc_num
                    || lv_file_delimiter
                    || lv_blk_lne_num
                    || lv_file_delimiter
                    || lv_blk_rqst_dt
                    || lv_file_delimiter
                    || output_rec.reduce_qty
                    || lv_file_delimiter
                    || output_rec.MESSAGE;

                insrt_msg ('OUTPUT', lv_line);
                apps.do_mail_utils.send_mail_line (lv_line, ln_ret_val); --v1.1
            END LOOP;

            insrt_msg ('LOG', 'ln_count: ' || ln_count, p_debug);
            apps.do_mail_utils.send_mail_close (ln_ret_val);          ----v1.1
        END IF;

        insrt_msg ('LOG', 'Completed generate_output Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);            --v1.1
            insrt_msg ('LOG',
                       'Error while generating output: ' || SQLERRM,
                       'Y');
    END generate_output;

    --free_atp_blk_main procedure
    PROCEDURE free_atp_blk_main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER
                                 , p_req_date_from IN VARCHAR2, p_req_date_to IN VARCHAR2, p_debug IN VARCHAR2:= 'N')
    IS
        CURSOR free_atp_cur IS
            SELECT ooha.org_id,
                   ooha.header_id co_header_id,
                   ooha.order_number co_order_number,
                   ooha.sold_to_org_id cust_account_id,
                   ooha.attribute5 brand,
                   ooha.order_type_id,
                   --Start changes v1.5
                   --oola.line_number || '.' || oola.shipment_number co_line_number,
                   oola.line_number co_line_number,
                   --End changes v1.5
                   oola.line_id co_line_id,
                   oola.ship_from_org_id,
                   oola.inventory_item_id,
                   oola.ordered_quantity,
                   oola.request_date,
                   oola.global_attribute19,
                   (SELECT sales_channel_code
                      FROM hz_cust_accounts
                     WHERE cust_account_id = ooha.sold_to_org_id) channel, --start changes v1.2
                   (SELECT customer_class_code
                      FROM hz_cust_accounts
                     WHERE cust_account_id = ooha.sold_to_org_id) cust_class --End changes v1.2
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, oe_transaction_types_all otta,
                   fnd_lookup_values flv
             WHERE     ooha.header_id = oola.header_id
                   AND otta.transaction_type_id = ooha.order_type_id
                   AND ooha.open_flag = 'Y'
                   AND oola.open_flag = 'Y'
                   AND otta.attribute5 = 'CO'
                   AND oola.shipment_number = 1           -- w.r.t version 1.4
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.lookup_type = 'XXD_FREEATP_CO_CRITERIA'
                   AND ooha.org_id = TO_NUMBER (flv.attribute1)
                   AND ooha.sold_to_org_id = TO_NUMBER (flv.attribute2)
                   --AND ooha.order_type_id = TO_NUMBER (flv.attribute3)
                   AND oola.schedule_ship_date IS NOT NULL
                   AND (oola.global_attribute19 LIKE '0-%' -- Consumed only from Free ATP
                                                           OR oola.global_attribute19 LIKE '%;0-%' -- Consumed from Bulk and Free ATP
                                                                                                   OR oola.global_attribute19 IS NULL) -- Consumed line not populated
                   -- Operating Unit
                   AND ooha.org_id = p_org_id
                   -- Request Date From
                   AND ((p_req_date_from IS NOT NULL AND oola.request_date >= fnd_date.canonical_to_date (p_req_date_from)) OR (p_req_date_from IS NULL AND 1 = 1))
                   -- Request Date To
                   AND ((p_req_date_to IS NOT NULL AND oola.request_date <= fnd_date.canonical_to_date (p_req_date_to)) OR (p_req_date_to IS NULL AND 1 = 1))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE mr.demand_source_line_id = oola.line_id)
            --Start changes v1.5
            UNION
            SELECT ooha.org_id,
                   ooha.header_id co_header_id,
                   ooha.order_number co_order_number,
                   ooha.sold_to_org_id cust_account_id,
                   ooha.attribute5 brand,
                   ooha.order_type_id,
                   oola.line_number co_line_number,
                   oola.line_id co_line_id,
                   oola.ship_from_org_id,
                   oola.inventory_item_id,
                   oola.ordered_quantity,
                   oola.request_date,
                   oola.global_attribute19,
                   (SELECT sales_channel_code
                      FROM hz_cust_accounts
                     WHERE cust_account_id = ooha.sold_to_org_id) channel,
                   (SELECT customer_class_code
                      FROM hz_cust_accounts
                     WHERE cust_account_id = ooha.sold_to_org_id) cust_class
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, oe_transaction_types_all otta,
                   fnd_lookup_values flv
             WHERE     ooha.header_id = oola.header_id
                   AND otta.transaction_type_id = ooha.order_type_id
                   AND ooha.open_flag = 'Y'
                   AND oola.cancelled_flag = 'Y'
                   AND EXISTS
                           (SELECT 1
                              FROM oe_order_lines_all oola2
                             WHERE     oola2.header_id = oola.header_id
                                   AND oola2.line_number = oola.line_number
                                   AND oola2.open_flag = 'Y'
                                   AND oola2.schedule_ship_date IS NOT NULL)
                   AND otta.attribute5 = 'CO'
                   AND oola.shipment_number = 1           -- w.r.t version 1.4
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND flv.lookup_type = 'XXD_FREEATP_CO_CRITERIA'
                   AND ooha.org_id = TO_NUMBER (flv.attribute1)
                   AND ooha.sold_to_org_id = TO_NUMBER (flv.attribute2)
                   AND (oola.global_attribute19 LIKE '0-%' -- Consumed only from Free ATP
                                                           OR oola.global_attribute19 LIKE '%;0-%' -- Consumed from Bulk and Free ATP
                                                                                                   OR oola.global_attribute19 IS NULL) -- Consumed line not populated
                   -- Operating Unit
                   AND ooha.org_id = p_org_id
                   -- Request Date From
                   AND ((p_req_date_from IS NOT NULL AND oola.request_date >= fnd_date.canonical_to_date (p_req_date_from)) OR (p_req_date_from IS NULL AND 1 = 1))
                   -- Request Date To
                   AND ((p_req_date_to IS NOT NULL AND oola.request_date <= fnd_date.canonical_to_date (p_req_date_to)) OR (p_req_date_to IS NULL AND 1 = 1))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE mr.demand_source_line_id = oola.line_id)--End changes v1.5
                                                                           ;

        --Start changes v1.5
        CURSOR split_line_cur (p_hdr_id NUMBER, p_lne_num NUMBER)
        IS
              SELECT oola.line_id, oola.shipment_number, oola.ordered_quantity
                FROM oe_order_lines_all oola
               WHERE     oola.header_id = p_hdr_id
                     AND oola.line_number = p_lne_num
                     AND oola.open_flag = 'Y'
                     AND oola.schedule_ship_date IS NOT NULL
            ORDER BY oola.shipment_number;

        CURSOR unsch_line_cur (p_hdr_id NUMBER, p_lne_num NUMBER)
        IS
              SELECT oola.line_id, oola.shipment_number, oola.ordered_quantity
                FROM oe_order_lines_all oola
               WHERE     oola.header_id = p_hdr_id
                     AND oola.line_number = p_lne_num
                     AND oola.open_flag = 'Y'
                     AND oola.schedule_ship_date IS NULL
            ORDER BY oola.shipment_number;

        ln_new_qty                 NUMBER;
        lv_cncl_all                VARCHAR2 (1);
        lv_schdl_all               VARCHAR2 (1);
        --End changes v1.5

        l_header_rec               oe_order_pub.header_rec_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_cncl_ln_tbl              oe_order_pub.line_tbl_type;
        l_header_rec_x             oe_order_pub.header_rec_type;
        l_line_tbl_x               oe_order_pub.line_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        l_return_status            VARCHAR2 (1000);
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (1000);
        l_line_tbl_index           NUMBER;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        l_msg_index_out            NUMBER (10);
        l_message_data             VARCHAR2 (2000);
        ln_resp_id                 NUMBER := 0;
        ln_resp_appl_id            NUMBER := 0;
        lv_exception               EXCEPTION;
        lv_api_exception           EXCEPTION;
        lv_user_exception          EXCEPTION;

        ln_free_atp                NUMBER;
        lt_consumption             xxd_ont_consumption_line_t_obj;
        ln_user_id                 NUMBER := NVL (fnd_global.user_id, -1);

        ln_cancel_qty              NUMBER;
        ln_line_qty                NUMBER;
        lv_lne_attr19              VARCHAR2 (240);
        lt_attr19_tbl              xxd_ont_consumption_line_t_obj;
        lv_free_atp_ok             VARCHAR2 (1) := 'N';                 --v1.2
    BEGIN
        insrt_msg (
            'LOG',
               'Inside free_atp_blk_main: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'Y');
        insrt_msg ('LOG', 'p_org_id: ' || p_org_id, 'Y');
        ln_resp_id        := NULL;
        ln_resp_appl_id   := NULL;

        BEGIN
            --Getting the responsibility and application to initialize and set the context
            --Making sure that the initialization is set for proper OM responsibility
            SELECT frv.responsibility_id, frv.application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                   apps.hr_organization_units hou
             WHERE     1 = 1
                   AND hou.organization_id = p_org_id
                   AND fpov.profile_option_value =
                       TO_CHAR (hou.organization_id)
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpo.user_profile_option_name = 'MO: Operating Unit'
                   AND frv.responsibility_id = fpov.level_value
                   AND frv.application_id = 660                          --ONT
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
                RAISE lv_exception;
        END;

        --Start changes v1.3
        fnd_global.apps_initialize (user_id        => ln_user_id,
                                    resp_id        => ln_resp_id,
                                    resp_appl_id   => ln_resp_appl_id);

        --End changes v1.3

        --XXD_ONT_BULK_RULES_PKG.gn_log_level := 1;  --jak
        --XXD_ONT_BULK_CALLOFF_PKG.gn_log_level := 1;  --jak

        FOR free_atp_rec IN free_atp_cur
        LOOP
            insrt_msg ('LOG',
                       'order_number: ' || free_atp_rec.co_order_number,
                       p_debug);
            insrt_msg ('LOG',
                       'line_number: ' || free_atp_rec.co_line_number,
                       p_debug);
            insrt_msg ('LOG',
                       'line_id: ' || free_atp_rec.co_line_id,
                       p_debug);
            lt_consumption     := xxd_ont_consumption_line_t_obj (NULL);
            --Start changes v1.5
            lv_schdl_all       := 'N';
            lv_cncl_all        := 'N';
            l_line_tbl         := oe_order_pub.g_miss_line_tbl;

            --End changes v1.5

            IF free_atp_rec.global_attribute19 IS NULL
            THEN
                ln_free_atp    := free_atp_rec.ordered_quantity;
                --Start changes v1.5
                lv_schdl_all   := 'Y';
            --End changes v1.5
            ELSE
                lt_consumption   :=
                    xxd_ont_bulk_calloff_pkg.string_to_consumption (
                        free_atp_rec.global_attribute19);

                SELECT SUM (quantity)
                  INTO ln_free_atp
                  FROM TABLE (lt_consumption)
                 WHERE line_id = 0;
            END IF;

            insrt_msg ('LOG', 'ln_free_atp: ' || ln_free_atp, p_debug);

            INSERT INTO xxdo.xxd_ont_free_atp_blk_stg_t (org_id, ship_from_org_id, co_hdr_id, co_lne_id, request_id, brand, order_type_id, sold_to_org_id, sku, inventory_item_id, quantity, request_date, free_atp_qty, old_glb_attr19, new_glb_attr19, process_mode, blk_hdr_id, blk_ordr_type_id, blk_sold_to_id, blk_lne_id, blk_rqst_date, reduce_qty, status, MESSAGE, creation_date, created_by, last_update_date
                                                         , last_updated_by)
                 VALUES (free_atp_rec.org_id, free_atp_rec.ship_from_org_id, free_atp_rec.co_header_id, free_atp_rec.co_line_id, gn_request_id, free_atp_rec.brand, free_atp_rec.order_type_id, free_atp_rec.cust_account_id, --sold_to_org_id
                                                                                                                                                                                                                              NULL, --sku
                                                                                                                                                                                                                                    free_atp_rec.inventory_item_id, free_atp_rec.ordered_quantity, free_atp_rec.request_date, ln_free_atp, --free_atp_qty
                                                                                                                                                                                                                                                                                                                                           free_atp_rec.global_attribute19, --old_glb_attr19
                                                                                                                                                                                                                                                                                                                                                                            NULL, --new_glb_attr19
                                                                                                                                                                                                                                                                                                                                                                                  'INSERT', --process_mode
                                                                                                                                                                                                                                                                                                                                                                                            NULL, --blk_hdr_id
                                                                                                                                                                                                                                                                                                                                                                                                  NULL, --blk_ordr_type_id
                                                                                                                                                                                                                                                                                                                                                                                                        NULL, --blk_sold_to_id
                                                                                                                                                                                                                                                                                                                                                                                                              NULL, --blk_lne_id
                                                                                                                                                                                                                                                                                                                                                                                                                    NULL, --blk_rqst_date
                                                                                                                                                                                                                                                                                                                                                                                                                          NULL, --reduce_qty
                                                                                                                                                                                                                                                                                                                                                                                                                                NULL, --status
                                                                                                                                                                                                                                                                                                                                                                                                                                      NULL, --message
                                                                                                                                                                                                                                                                                                                                                                                                                                            SYSDATE, --creation_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                     ln_user_id, --created_by
                                                                                                                                                                                                                                                                                                                                                                                                                                                                 SYSDATE
                         ,                                  --last_update_date
                           ln_user_id                        --last_updated_by
                                     );

            COMMIT;

            --Start changes v1.3
            /*
      fnd_global.apps_initialize (user_id        => ln_user_id,
             resp_id        => ln_resp_id,
             resp_appl_id   => ln_resp_appl_id);
      */
            --End changes v1.3

            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', free_atp_rec.org_id);

            --fnd_profile.put ('ONT_ATP_CALL_AUTONOMOUS', 'N');
            --fnd_profile.put ('MRP_ATP_CALC_SD', 'N');
            --XXD_ONT_BULK_CALLOFF_PKG.gc_no_unconsumption := 'N';

            --Unscheduling

            l_return_status    := NULL;
            l_msg_data         := NULL;
            l_message_data     := NULL;

            l_line_tbl_index   := 1;

            --Start changes v1.5
            FOR split_rec
                IN split_line_cur (free_atp_rec.co_header_id,
                                   free_atp_rec.co_line_number)
            LOOP
                insrt_msg ('LOG',
                           'shipment_number: ' || split_rec.shipment_number,
                           p_debug);

                l_line_tbl (l_line_tbl_index)          :=
                    oe_order_pub.g_miss_line_rec;
                l_line_tbl (l_line_tbl_index).operation   :=
                    oe_globals.g_opr_update;
                l_line_tbl (l_line_tbl_index).org_id   := free_atp_rec.org_id;
                l_line_tbl (l_line_tbl_index).header_id   :=
                    free_atp_rec.co_header_id;
                l_line_tbl (l_line_tbl_index).line_id   :=
                    split_rec.line_id;
                l_line_tbl (l_line_tbl_index).schedule_action_code   :=
                    'UNSCHEDULE';                        --unscheduling Action

                IF    lv_schdl_all = 'Y'
                   OR free_atp_rec.ordered_quantity < ln_free_atp
                THEN
                    l_line_tbl_index   := l_line_tbl_index + 1;
                ELSE
                    EXIT;
                END IF;
            END LOOP;

            /*
     l_line_tbl (l_line_tbl_index) := oe_order_pub.g_miss_line_rec;
     l_line_tbl (l_line_tbl_index).operation := oe_globals.g_opr_update;
     l_line_tbl (l_line_tbl_index).org_id := free_atp_rec.org_id;
     l_line_tbl (l_line_tbl_index).header_id := free_atp_rec.co_header_id;
     l_line_tbl (l_line_tbl_index).line_id := free_atp_rec.co_line_id;
     l_line_tbl (l_line_tbl_index).schedule_action_code := 'UNSCHEDULE'; --unscheduling Action
      */
            --End changes v1.5

            insrt_msg ('LOG',
                       'Calling process_order API to Unschedule',
                       p_debug);

            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_true,
                p_return_values            => fnd_api.g_true,
                p_action_commit            => fnd_api.g_true,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => l_header_rec_x,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => l_line_tbl_x,
                x_line_val_tbl             => x_line_val_tbl,
                x_line_adj_tbl             => x_line_adj_tbl,
                x_line_adj_val_tbl         => x_line_adj_val_tbl,
                x_line_price_att_tbl       => x_line_price_att_tbl,
                x_line_adj_att_tbl         => x_line_adj_att_tbl,
                x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                x_line_scredit_tbl         => x_line_scredit_tbl,
                x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                x_lot_serial_tbl           => x_lot_serial_tbl,
                x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                x_action_request_tbl       => l_action_request_tbl);

            insrt_msg (
                'LOG',
                   'process_order API status after unschedule: '
                || l_return_status,
                p_debug);

            IF l_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
            ELSE
                ROLLBACK;

                FOR i IN 1 .. l_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                    , p_msg_index_out => l_msg_index_out);

                    l_message_data   :=
                        SUBSTR (l_message_data || l_msg_data, 1, 2000);
                END LOOP;

                insrt_msg ('LOG',
                           'Unschedule Error: ' || l_message_data,
                           p_debug);

                UPDATE xxdo.xxd_ont_free_atp_blk_stg_t
                   SET sch_status = 'E', sch_message = SUBSTR ('Unscheduling Failed: ' || l_message_data, 1, 240), process_mode = 'UNSCHEDULE',
                       last_update_date = SYSDATE
                 WHERE     request_id = gn_request_id
                       AND co_lne_id = free_atp_rec.co_line_id;

                COMMIT;
            END IF;

            --Scheduling
            l_return_status    := NULL;
            l_msg_data         := NULL;
            l_message_data     := NULL;

            l_line_tbl_index   := 1;

            --Start changes v1.5
            l_line_tbl         := oe_order_pub.g_miss_line_tbl;

            FOR split_rec
                IN unsch_line_cur (free_atp_rec.co_header_id,
                                   free_atp_rec.co_line_number)
            LOOP
                insrt_msg ('LOG',
                           'shipment_number: ' || split_rec.shipment_number,
                           p_debug);

                l_line_tbl (l_line_tbl_index)          :=
                    oe_order_pub.g_miss_line_rec;
                l_line_tbl (l_line_tbl_index).operation   :=
                    oe_globals.g_opr_update;
                l_line_tbl (l_line_tbl_index).org_id   := free_atp_rec.org_id;
                l_line_tbl (l_line_tbl_index).header_id   :=
                    free_atp_rec.co_header_id;
                l_line_tbl (l_line_tbl_index).line_id   :=
                    split_rec.line_id;
                l_line_tbl (l_line_tbl_index).schedule_action_code   :=
                    'SCHEDULE';                          --unscheduling Action

                IF    lv_schdl_all = 'Y'
                   OR free_atp_rec.ordered_quantity < ln_free_atp
                THEN
                    l_line_tbl_index   := l_line_tbl_index + 1;
                ELSE
                    EXIT;
                END IF;
            END LOOP;

            /*
         l_line_tbl (l_line_tbl_index) := oe_order_pub.g_miss_line_rec;
         l_line_tbl (l_line_tbl_index).operation := oe_globals.g_opr_update;
         l_line_tbl (l_line_tbl_index).org_id := free_atp_rec.org_id;
         l_line_tbl (l_line_tbl_index).header_id := free_atp_rec.co_header_id;
         l_line_tbl (l_line_tbl_index).line_id := free_atp_rec.co_line_id;
         l_line_tbl (l_line_tbl_index).schedule_action_code := 'SCHEDULE'; --scheduling Action
         */
            --End changes v1.5

            insrt_msg ('LOG',
                       'Calling process_order API to schedule',
                       p_debug);

            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_true,
                p_return_values            => fnd_api.g_true,
                p_action_commit            => fnd_api.g_true,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => l_header_rec_x,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => l_line_tbl_x,
                x_line_val_tbl             => x_line_val_tbl,
                x_line_adj_tbl             => x_line_adj_tbl,
                x_line_adj_val_tbl         => x_line_adj_val_tbl,
                x_line_price_att_tbl       => x_line_price_att_tbl,
                x_line_adj_att_tbl         => x_line_adj_att_tbl,
                x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                x_line_scredit_tbl         => x_line_scredit_tbl,
                x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                x_lot_serial_tbl           => x_lot_serial_tbl,
                x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                x_action_request_tbl       => l_action_request_tbl);

            insrt_msg (
                'LOG',
                   'process_order API status after schedule: '
                || l_return_status,
                p_debug);

            IF l_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
            ELSE
                ROLLBACK;

                FOR i IN 1 .. l_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                    , p_msg_index_out => l_msg_index_out);

                    l_message_data   :=
                        SUBSTR (l_message_data || l_msg_data, 1, 2000);
                END LOOP;

                insrt_msg (
                    'LOG',
                       'process_order API Error after schedule: '
                    || l_message_data,
                    p_debug);

                UPDATE xxdo.xxd_ont_free_atp_blk_stg_t
                   SET sch_status = 'E', sch_message = SUBSTR ('Scheduling Failed: ' || l_message_data, 1, 240), process_mode = 'SCHEDULE',
                       last_update_date = SYSDATE
                 WHERE     request_id = gn_request_id
                       AND co_lne_id = free_atp_rec.co_line_id;

                COMMIT;
            END IF;

            --Start changes v1.2
            BEGIN
                SELECT 'Y'
                  INTO lv_free_atp_ok
                  FROM fnd_lookup_values flv
                 WHERE     flv.lookup_type = 'XXD_OM_FATP_BO_SALES_CHANNEL'
                       AND flv.enabled_flag = 'Y'
                       AND flv.tag = free_atp_rec.cust_class
                       AND flv.meaning = free_atp_rec.channel
                       AND flv.LANGUAGE = USERENV ('LANG');
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_free_atp_ok   := 'N';
            END;

            --IF free_atp_rec.channel = 'RETAIL' THEN
            IF lv_free_atp_ok = 'Y'
            THEN
                --End changes v1.2
                insrt_msg (
                    'LOG',
                    'Free ATP will not be released for a Retail Customer',
                    p_debug);
            ELSE
                BEGIN
                    lt_attr19_tbl      := xxd_ont_consumption_line_t_obj (NULL);
                    ln_cancel_qty      := 0;

                    --Start changes v1.5
                    BEGIN
                        --End changes v1.5

                        SELECT oola.ordered_quantity, oola.global_attribute19
                          INTO ln_line_qty, lv_lne_attr19
                          FROM oe_order_lines_all oola
                         WHERE     oola.line_id = free_atp_rec.co_line_id
                               AND oola.open_flag = 'Y'
                               AND oola.schedule_ship_date IS NOT NULL
                               AND (oola.global_attribute19 LIKE '0-%' -- Consumed only from Free ATP
                                                                       OR oola.global_attribute19 LIKE '%;0-%' -- Consumed from Bulk and Free ATP
                                                                                                               OR oola.global_attribute19 IS NULL) -- Consumed line not populated
                                                                                                                                                  ;
                    --Start changes v1.5
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            SELECT SUM (oola.ordered_quantity)
                              INTO ln_line_qty
                              FROM oe_order_lines_all oola
                             WHERE     oola.header_id =
                                       free_atp_rec.co_header_id
                                   AND oola.line_number =
                                       free_atp_rec.co_line_number
                                   AND oola.open_flag = 'Y'
                                   AND oola.schedule_ship_date IS NOT NULL
                                   AND EXISTS
                                           (SELECT 1
                                              FROM oe_order_lines_all oola1
                                             WHERE     oola1.line_id =
                                                       free_atp_rec.co_line_id
                                                   AND oola1.header_id =
                                                       oola.header_id
                                                   AND oola1.cancelled_flag =
                                                       'Y'
                                                   AND (oola1.global_attribute19 LIKE '0-%' -- Consumed only from Free ATP
                                                                                            OR oola1.global_attribute19 LIKE '%;0-%' -- Consumed from Bulk and Free ATP
                                                                                                                                     OR oola1.global_attribute19 IS NULL) -- Consumed line not populated
                                                                                                                                                                         );

                            SELECT oola.global_attribute19
                              INTO lv_lne_attr19
                              FROM oe_order_lines_all oola
                             WHERE     oola.line_id = free_atp_rec.co_line_id
                                   AND oola.cancelled_flag = 'Y'
                                   AND (oola.global_attribute19 LIKE '0-%' -- Consumed only from Free ATP
                                                                           OR oola.global_attribute19 LIKE '%;0-%' -- Consumed from Bulk and Free ATP
                                                                                                                   OR oola.global_attribute19 IS NULL) -- Consumed line not populated
                                                                                                                                                      ;
                    END;

                    --End changes v1.5


                    IF lv_lne_attr19 IS NULL
                    THEN
                        ln_cancel_qty   := ln_line_qty;
                        --Start changes v1.5
                        lv_cncl_all     := 'Y';
                    --End changes v1.5
                    ELSE
                        lt_attr19_tbl   :=
                            xxd_ont_bulk_calloff_pkg.string_to_consumption (
                                lv_lne_attr19);

                        SELECT SUM (quantity)
                          INTO ln_cancel_qty
                          FROM TABLE (lt_attr19_tbl)
                         WHERE line_id = 0;
                    END IF;

                    insrt_msg ('LOG',
                               'ln_cancel_qty: ' || ln_cancel_qty,
                               p_debug);

                    l_return_status    := NULL;
                    l_msg_data         := NULL;
                    l_message_data     := NULL;

                    l_line_tbl_index   := 1;

                    --Start changes v1.5
                    l_cncl_ln_tbl      := oe_order_pub.g_miss_line_tbl;

                    FOR split_rec
                        IN split_line_cur (free_atp_rec.co_header_id,
                                           free_atp_rec.co_line_number)
                    LOOP
                        insrt_msg (
                            'LOG',
                            'shipment_number: ' || split_rec.shipment_number,
                            p_debug);
                        ln_new_qty   :=
                            split_rec.ordered_quantity - ln_cancel_qty;

                        IF lv_cncl_all = 'Y' OR ln_new_qty < 0
                        THEN
                            ln_new_qty   := 0;
                        END IF;

                        l_cncl_ln_tbl (l_line_tbl_index)   :=
                            oe_order_pub.g_miss_line_rec;
                        l_cncl_ln_tbl (l_line_tbl_index).operation   :=
                            oe_globals.g_opr_update;
                        l_cncl_ln_tbl (l_line_tbl_index).org_id   :=
                            free_atp_rec.org_id;
                        l_cncl_ln_tbl (l_line_tbl_index).header_id   :=
                            free_atp_rec.co_header_id;
                        l_cncl_ln_tbl (l_line_tbl_index).line_id   :=
                            split_rec.line_id;
                        l_cncl_ln_tbl (l_line_tbl_index).ordered_quantity   :=
                            ln_new_qty;
                        l_cncl_ln_tbl (l_line_tbl_index).change_reason   :=
                            'BLK_ADJ_PGM'; --'OM - Bulk Call Off Order Consumption'
                        l_cncl_ln_tbl (l_line_tbl_index).change_comments   :=
                            'Released Free ATP Units by Deckers Free ATP Bulk Order Management Program';

                        IF ln_new_qty = 0
                        THEN
                            l_cncl_ln_tbl (l_line_tbl_index).cancelled_flag   :=
                                'Y';
                        END IF;

                        IF    lv_cncl_all = 'Y'
                           OR ln_cancel_qty > split_rec.ordered_quantity
                        THEN
                            ln_cancel_qty      :=
                                ln_cancel_qty - split_rec.ordered_quantity;
                            l_line_tbl_index   := l_line_tbl_index + 1;
                        ELSE
                            EXIT;
                        END IF;
                    END LOOP;

                    /*
              l_cncl_ln_tbl (l_line_tbl_index) := oe_order_pub.g_miss_line_rec;
              l_cncl_ln_tbl (l_line_tbl_index).operation := oe_globals.g_opr_update;
              l_cncl_ln_tbl (l_line_tbl_index).org_id := free_atp_rec.org_id;
              l_cncl_ln_tbl (l_line_tbl_index).header_id := free_atp_rec.co_header_id;
              l_cncl_ln_tbl (l_line_tbl_index).line_id := free_atp_rec.co_line_id;

              l_cncl_ln_tbl (l_line_tbl_index).ordered_quantity := ln_line_qty - ln_cancel_qty;
              l_cncl_ln_tbl (l_line_tbl_index).change_reason := 'BLK_ADJ_PGM'; --'OM - Bulk Call Off Order Consumption'
              l_cncl_ln_tbl (l_line_tbl_index).change_comments := 'Released Free ATP Units by Deckers Free ATP Bulk Order Management Program';
              IF ln_line_qty = ln_cancel_qty THEN
             l_cncl_ln_tbl (l_line_tbl_index).cancelled_flag := 'Y';
              END IF;
              */
                    --End changes v1.5

                    insrt_msg ('LOG', 'Calling process_order API', p_debug);

                    --Start changes v1.3
                    --fnd_profile.put ('ONT_ATP_CALL_AUTONOMOUS', 'N');
                    --fnd_profile.put ('MRP_ATP_CALC_SD', 'N');
                    --End changes v1.3

                    oe_order_pub.process_order (
                        p_api_version_number       => 1.0,
                        p_init_msg_list            => fnd_api.g_true,
                        p_return_values            => fnd_api.g_true,
                        p_action_commit            => fnd_api.g_false,
                        x_return_status            => l_return_status,
                        x_msg_count                => l_msg_count,
                        x_msg_data                 => l_msg_data,
                        p_header_rec               => l_header_rec,
                        p_line_tbl                 => l_cncl_ln_tbl,
                        p_action_request_tbl       => l_action_request_tbl,
                        x_header_rec               => l_header_rec_x,
                        x_header_val_rec           => x_header_val_rec,
                        x_header_adj_tbl           => x_header_adj_tbl,
                        x_header_adj_val_tbl       => x_header_adj_val_tbl,
                        x_header_price_att_tbl     => x_header_price_att_tbl,
                        x_header_adj_att_tbl       => x_header_adj_att_tbl,
                        x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                        x_header_scredit_tbl       => x_header_scredit_tbl,
                        x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                        x_line_tbl                 => l_line_tbl_x,
                        x_line_val_tbl             => x_line_val_tbl,
                        x_line_adj_tbl             => x_line_adj_tbl,
                        x_line_adj_val_tbl         => x_line_adj_val_tbl,
                        x_line_price_att_tbl       => x_line_price_att_tbl,
                        x_line_adj_att_tbl         => x_line_adj_att_tbl,
                        x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                        x_line_scredit_tbl         => x_line_scredit_tbl,
                        x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                        x_lot_serial_tbl           => x_lot_serial_tbl,
                        x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                        x_action_request_tbl       => l_action_request_tbl);


                    insrt_msg (
                        'LOG',
                           'process_order API (Cancel) status: '
                        || l_return_status,
                        p_debug);

                    IF l_return_status = fnd_api.g_ret_sts_success
                    THEN
                        UPDATE xxdo.xxd_ont_free_atp_blk_stg_t
                           SET cancel_status = 'S', process_mode = 'CANCEL', reduce_qty = ln_cancel_qty,
                               last_update_date = SYSDATE
                         WHERE     request_id = gn_request_id
                               AND co_lne_id = free_atp_rec.co_line_id;

                        COMMIT;
                    ELSE
                        ROLLBACK;

                        FOR i IN 1 .. l_msg_count
                        LOOP
                            oe_msg_pub.get (
                                p_msg_index       => i,
                                p_encoded         => fnd_api.g_false,
                                p_data            => l_msg_data,
                                p_msg_index_out   => l_msg_index_out);

                            l_message_data   :=
                                SUBSTR (l_message_data || l_msg_data,
                                        1,
                                        2000);
                        END LOOP;

                        insrt_msg (
                            'LOG',
                               'process_order API (Cancel) Error: '
                            || l_message_data,
                            p_debug);

                        UPDATE xxdo.xxd_ont_free_atp_blk_stg_t
                           SET cancel_status = 'E', cancel_message = SUBSTR ('Cancelling Failed: ' || l_message_data, 1, 240), process_mode = 'CANCEL',
                               last_update_date = SYSDATE
                         WHERE     request_id = gn_request_id
                               AND co_lne_id = free_atp_rec.co_line_id;

                        COMMIT;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        insrt_msg ('LOG', 'No qty to Cancel', p_debug);

                        UPDATE xxdo.xxd_ont_free_atp_blk_stg_t
                           SET status = 'S', process_mode = 'COMPLETE', last_update_date = SYSDATE
                         WHERE     request_id = gn_request_id
                               AND co_lne_id = free_atp_rec.co_line_id;

                        COMMIT;
                END;
            END IF;                                   -- Retail customer check
        END LOOP;

        --get_bulk_line_id function
        UPDATE xxdo.xxd_ont_free_atp_blk_stg_t
           SET MESSAGE = SUBSTR (sch_message || cancel_message, 1, 240), process_mode = 'COMPLETE', blk_lne_id = get_bulk_line_id (co_lne_id),
               last_update_date = SYSDATE
         WHERE request_id = gn_request_id;

        COMMIT;

        --Call generate_output procedure
        generate_output (p_org_id, p_debug);
    EXCEPTION
        WHEN lv_exception
        THEN
            insrt_msg (
                'LOG',
                'Unexpected Error while fetching responsibility: ' || SQLERRM,
                'Y');
        WHEN OTHERS
        THEN
            insrt_msg ('LOG',
                       'Unexpected Error in free_atp_blk_main: ' || SQLERRM,
                       'Y');
    END free_atp_blk_main;

    --This function returns the bulk line id for the given call off order line id
    FUNCTION get_bulk_line_id (pn_line_id IN NUMBER)
        RETURN NUMBER
    IS
        lv_blk_strng   oe_order_lines_all.global_attribute19%TYPE;
        lv_blk_buf     oe_order_lines_all.global_attribute19%TYPE;
        ln_line_id     NUMBER;
        ln_count       NUMBER := 0;
        lb_error       BOOLEAN := FALSE;
    BEGIN
        SELECT oola.global_attribute19
          INTO lv_blk_strng
          FROM oe_order_lines_all oola
         WHERE line_id = pn_line_id;

        IF lv_blk_strng IS NOT NULL
        THEN
            WHILE INSTR (lv_blk_strng, ';') > 0
            LOOP
                lv_blk_buf   :=
                    SUBSTR (lv_blk_strng, 1, INSTR (lv_blk_strng, ';') - 1);
                lv_blk_strng   :=
                    SUBSTR (lv_blk_strng, INSTR (lv_blk_strng, ';') + 1);

                BEGIN
                    ln_line_id   :=
                        TO_NUMBER (
                            SUBSTR (lv_blk_buf,
                                    1,
                                    INSTR (lv_blk_buf, '-') - 1));
                    ln_count   := ln_count + 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lb_error   := TRUE;
                END;
            END LOOP;                                         --end while loop

            IF NOT lb_error
            THEN
                IF ln_count = 1
                THEN
                    RETURN ln_line_id;
                ELSE
                    RETURN 5;
                END IF;                                         --end ln_count
            END IF;                                                 --lb_error
        END IF;                                                 --lv_blk_strng

        RETURN ln_line_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            insrt_msg ('LOG',
                       'Error in get_bulk_line_id function: ' || SQLERRM,
                       'Y');
            RETURN ln_line_id;
    END get_bulk_line_id;
--End get_bulk_line_id

END xxd_ont_free_atp_blk_om_pkg;
/
