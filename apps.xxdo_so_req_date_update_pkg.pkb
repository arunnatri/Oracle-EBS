--
-- XXDO_SO_REQ_DATE_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_SO_REQ_DATE_UPDATE_PKG"
AS
    /*******************************************************************************
    * $Header$
    * Program Name : XXDO_SO_REQ_DATE_UPDATE_PKG.pkb
    * Language     : PL/SQL
    * Description  : This package is used for updated the request date of ISO once
    *           Promise Date of open purchase orders is changed by using API
    * History      :
    * 21-APR-2015 Created as Initial
    * 10-Jun-2015 Modified as per PO header Last update date > sysdate -1
    * ------------------------------------------------------------------------
    * WHO                        WHAT                       WHEN
    * --------------         ----------------------         ---------------
    * BT Technology Team      Initial                             21-Apr-2015
    * BT Technology Team      1.1 for Defect 2740 and 2707       15-Jul-2015
    * BT Technology Team      1.2 for Japan Lead Time CR# 104    23-Jul-2015
    * BT Technology Team      1.3 modification for defect#255    29-Oct-2015
    * BT Technology Team      1.4 modification for defect#507    09-Nov-2015
    * BT Technology Team      1.4 modification for defect#255    20-Nov-2015
    * BT Technology Team      1.4 modification for defect#255    08-04-2016
    * Infosys                 1.5 Modification for Problem PRB0041059 14-12-2016 ; IDENTIFIED by PRB0041059
    * GJensen                 1.6 Enabled report mode for PO Promised date to ISO Request date
    * Bala Murugesan          1.7 Modified to consider the PO lines which are modified after P_AS_OF_DATE;
    *                             Changes identified by PO_AS_OF_DATE
    * Bala Murugesan          1.8 Modified to end the program in warning than error;
    *                             Changes identified by WARNING_END
    * Infosys                 1.9 Modification for Problem PRB0041379 09-May-2017  ; IDENTIFIED BY PRB0041379
    * Infosys                 1.10 Modification for Problem PRB0041344 22-May-2017 ; IDENTIFIED BY PRB0041344
    * Infosys     1.11 Modification for Problem PRB0041369 19-Jul-2017 ; IDENTIFIED BY CCR0006518
    * Infosys                 1.12 Modification for Problem PRB0041585 04-Oct-2017 ; IDENTIFIED BY CCR0006704
    * Kranthi Bollam          1.13 Modification for CCR0007066         23-Feb-2018 ; IDENTIFIED BY 1.13
    *******************************************************************************/

    --Global Variables
    g_user_id               CONSTANT NUMBER := fnd_global.user_id; --Added for change 1.13

    --Constant values
    pRunTypeISOReqDt        CONSTANT VARCHAR2 (50) := 'ISO Request Date Update';
    pRunTypeJapanTQ         CONSTANT VARCHAR2 (50) := 'Japan TQ PO Date Update';
    pRunTypeTQSplitSync     CONSTANT VARCHAR2 (50) := 'TQ split line sync';
    pRunUpdateRegASNDate    CONSTANT VARCHAR2 (50)
                                         := 'Update Regional ASN Date' ;
    --Constant interger values for run types
    piRunTypeISOReqDt       CONSTANT NUMBER := 1;
    piRunTypeJapanTQ        CONSTANT NUMBER := 2;
    piRunTypeTQSplitSync    CONSTANT NUMBER := 3;
    piRunUpdateRegASNDate   CONSTANT NUMBER := 4;

    --These strings and values are stored in the below value set
    pRunTypeLookupNmae               VARCHAR2 (30) := 'XXDO_DTUPD_RUN_TYPE';

    PROCEDURE WRITE_LOG (P_MESSAGE IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, p_message);
        DBMS_OUTPUT.put_line (p_message);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END write_log;

    PROCEDURE WRITE_OUTPUT (P_MESSAGE IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.output, p_message);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END write_output;

    PROCEDURE PO_APPROVAL (p_po_num IN NUMBER, P_org_id IN NUMBER, p_error_code OUT VARCHAR2
                           , P_ERROR_TEXT OUT VARCHAR2)
    IS
        l_api_errors             PO_API_ERRORS_REC_TYPE;
        v_po_header_id           NUMBER;
        v_org_id                 NUMBER;
        v_po_num                 VARCHAR2 (50);
        v_doc_type               VARCHAR2 (50);
        v_doc_sub_type           VARCHAR2 (50);
        l_return_status          VARCHAR2 (1);
        l_api_version   CONSTANT NUMBER := 2.0;
        l_api_name      CONSTANT VARCHAR2 (50) := 'UPDATE_DOCUMENT';
        l_progress               VARCHAR2 (3) := '000';
        v_agent_id               NUMBER;
        ---
        v_item_key               VARCHAR2 (100);
        v_resp_appl_id           NUMBER;
        v_resp_id                NUMBER;
        v_user_id                NUMBER;
    --
    BEGIN
        v_org_id          := p_org_id;
        v_po_num          := p_po_num;

        BEGIN
            SELECT pha.po_header_id, pha.agent_id, pdt.document_subtype,
                   pdt.document_type_code, pha.wf_item_key
              INTO v_po_header_id, v_agent_id, v_doc_sub_type, v_doc_type,
                                 v_item_key
              FROM apps.po_headers_all pha, apps.po_document_types_all pdt
             WHERE     pha.type_lookup_code = pdt.document_subtype
                   AND pha.org_id = v_org_id
                   AND pdt.document_type_code = 'PO'
                   AND segment1 = v_po_num;

            l_progress   := '001';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_code   := 1;
        END;

        v_resp_appl_id    := fnd_global.resp_appl_id;
        v_resp_id         := fnd_global.resp_id;
        v_user_id         := fnd_global.user_id;
        APPS.fnd_global.APPS_INITIALIZE (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);
        APPS.mo_global.init ('PO');
        --calling seeded procedure to launch the po approval workflow

        po_reqapproval_init1.start_wf_process (ItemType => 'POAPPRV', ItemKey => v_item_key, WorkflowProcess => 'XXDO_POAPPRV_TOP', ActionOriginatedFrom => 'PO_FORM', DocumentID => v_po_header_id -- po_header_id
                                                                                                                                                                                                   , DocumentNumber => v_po_num -- Purchase Order Number
                                                                                                                                                                                                                               , PreparerID => v_agent_id -- Buyer/Preparer_id
                                                                                                                                                                                                                                                         , DocumentTypeCode => 'PO' --'PO'
                                                                                                                                                                                                                                                                                   , DocumentSubtype => 'STANDARD' --'STANDARD'
                                                                                                                                                                                                                                                                                                                  , SubmitterAction => 'APPROVE', forwardToID => NULL, forwardFromID => NULL, DefaultApprovalPathID => NULL, Note => NULL, PrintFlag => 'N', FaxFlag => 'N', FaxNumber => NULL, EmailFlag => 'N', EmailAddress => NULL, CreateSourcingRule => 'N', ReleaseGenMethod => 'N', UpdateSourcingRule => 'N', MassUpdateReleases => 'N', RetroactivePriceChange => 'N', OrgAssignChange => 'N', CommunicatePriceChange => 'N', p_Background_Flag => 'N', p_Initiator => NULL, p_xml_flag => NULL, FpdsngFlag => 'N'
                                               , p_source_type_code => NULL);

        l_progress        := '002';
        l_return_status   := FND_API.G_RET_STS_SUCCESS;

        IF (l_return_status = 'S')
        THEN
            p_error_code   := 0;
            P_ERROR_TEXT   := 'S';
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'wf approval success');
        ELSE
            p_error_code   := 1;
            P_ERROR_TEXT   := 'F';
        END IF;

        l_progress        := '003';
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            p_error_code   := 1;
            p_error_text   := SQLERRM;
        WHEN OTHERS
        THEN
            p_error_text   := SQLERRM;
            p_error_code   := 1;
    END PO_APPROVAL;

    FUNCTION GET_TQ_LIST_PRICE (P_HEADER_ID IN NUMBER, P_UNIT_PRICE IN NUMBER, P_VENDOR_ID IN NUMBER
                                , P_ITEM_ID IN NUMBER, P_ORG_ID IN NUMBER)
        RETURN NUMBER
    IS
        lv_style            VARCHAR2 (10);
        lv_color            VARCHAR2 (10);
        lv_item_price       NUMBER;
        lv_corporate_rate   NUMBER;
        lv_from_currency    VARCHAR2 (10);
    BEGIN
        SELECT DISTINCT style_number, color_code
          INTO lv_style, lv_color
          FROM apps.XXD_COMMON_ITEMS_V
         WHERE inventory_item_id = p_item_id AND organization_id = p_org_id;

        SELECT transactional_curr_code
          INTO lv_from_currency
          FROM apps.oe_order_headers_all
         WHERE header_id = p_header_id;


        IF (lv_from_currency <> 'JPY')
        THEN
            SELECT conversion_rate
              INTO lv_corporate_rate
              FROM apps.gl_daily_rates
             WHERE     from_currency = lv_from_currency
                   AND to_currency = 'JPY'
                   AND conversion_type = 'Corporate'
                   AND TRUNC (conversion_date) = TRUNC (SYSDATE);
        ELSE
            lv_corporate_rate   := 1;
        END IF;

        BEGIN
            SELECT ROUND ((p_unit_price * lv_corporate_rate) * NVL (rate_multiplier, 0) + NVL (rate_amount, 0), 0)
              INTO lv_item_price
              FROM do_custom.xxdo_po_price_rule xppr, do_custom.xxdo_po_price_rule_assignment xppra, AP_SUPPLIERS APS,
                   HR_ORGANIZATION_UNITS HROU
             WHERE     xppr.po_price_rule = xppra.po_price_rule
                   --AND xppr.vendor_id = p_vendor_id
                   -- AND xppra.target_item_org_id = p_org_id --changed after conversion
                   AND xppr.VENDOR_NAME = APS.VENDOR_NAME
                   AND APS.VENDOR_ID = p_vendor_id
                   AND xppra.target_item_orgANIZATION = HROU.NAME
                   AND HROU.ORGANIZATION_ID = P_ORG_ID
                   AND xppra.item_segment1 = lv_style
                   AND xppra.item_segment2 = lv_color;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_item_price   := p_unit_price * lv_corporate_rate;
        END;

        RETURN lv_item_price;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            Fnd_File.PUT_LINE (
                Fnd_File.LOG,
                   'Error while calculating the list price of item '
                || p_item_id
                || ' for JP5('
                || SQLERRM
                || ')');
            RETURN NULL;
        WHEN OTHERS
        THEN
            Fnd_File.PUT_LINE (
                Fnd_File.LOG,
                   'Error while calculating the list price of item '
                || p_item_id
                || ' for JP5('
                || SQLERRM
                || ')');
            RETURN NULL;
    END;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : get_email_address_list
    -- Decription                : Get Users List to send Notifications
    --
    -- Parameters
    -- p_lookup_type      INPUT
    -- x_users_email_list OUTPUT
    -- Modification History
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    03-APR-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE GET_EMAIL_ADDRESS_LIST (
        P_LOOKUP_TYPE            VARCHAR2,
        X_USERS_EMAIL_LIST   OUT DO_MAIL_UTILS.TBL_RECIPS)
    IS
        lr_users_email_lst   do_mail_utils.tbl_recips;
    BEGIN
        write_log (
            'Step 5 ' || gv_package_name || ' : Get Users Email List ');
        lr_users_email_lst.DELETE;

        BEGIN
            SELECT meaning
              BULK COLLECT INTO lr_users_email_lst
              FROM fnd_lookup_values
             WHERE     lookup_type = p_lookup_type
                   AND enabled_flag = 'Y'
                   AND LANGUAGE = USERENV ('LANG')
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);

            x_users_email_list   := lr_users_email_lst;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lr_users_email_lst.DELETE;
                x_users_email_list   := lr_users_email_lst;
            WHEN OTHERS
            THEN
                lr_users_email_lst.DELETE;
                x_users_email_list   := lr_users_email_lst;
                write_log (
                    'Setup 99: Error in Get uesrs Email List: ' || SQLERRM);
        END;
    END get_email_address_list;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : CALL_PROCESS_ORDER
    -- Decription                : call process order procedure to update the request date
    --
    -- Parameters
    -- p_header_id   INPUT
    -- p_line_tbl     INPUT
    -- Modification History
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    21-APR-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    FUNCTION CALL_PROCESS_ORDER (P_LINE_TBL   IN OE_ORDER_PUB.LINE_TBL_TYPE,
                                 P_ORGID      IN NUMBER)
        RETURN BOOLEAN
    IS
        b_ret_val          BOOLEAN := TRUE;
        v_ret_val          VARCHAR2 (10);
        --API Variables
        l_return_status    VARCHAR2 (1) := fnd_api.g_ret_sts_success;
        l_msg_data         VARCHAR2 (2000);
        l_header_rec       oe_order_pub.header_rec_type;
        t_header_adj_tbl   oe_order_pub.header_adj_tbl_type;
        t_out_line_tbl     oe_order_pub.line_tbl_type;
        t_line_adj_tbl     oe_order_pub.line_adj_tbl_type;
    BEGIN
        write_log (gv_package_name || '.CALL_PROCESS_ORDER');
        write_log (
            'Begin CALL_PROCESS_ORDER...Line Count: ' || p_line_tbl.COUNT);


        l_header_rec   := oe_order_pub.g_miss_header_rec;
        t_header_adj_tbl.DELETE;
        t_out_line_tbl.DELETE;
        t_line_adj_tbl.DELETE;



        call_process_order (P_ORG_ID => P_ORGID, p_line_tbl => p_line_tbl, x_header_rec => l_header_rec, x_header_adj_tbl => t_header_adj_tbl, x_line_tbl => t_out_line_tbl, x_line_adj_tbl => t_line_adj_tbl, x_return_status => l_return_status, x_error_text => l_msg_data, p_debug_location => g_debug_location
                            , p_do_commit => 0);
        COMMIT;

        IF l_return_status != fnd_api.g_ret_sts_success
        THEN
            --Errors were encountered.
            write_log (gv_package_name || 'CALL_PROCESS_ORDER');
            write_log (
                   gv_package_name
                || 'PROCESS_ORDER returned an error. '
                || l_msg_data);
            b_ret_val   := FALSE;
        END IF;

        IF b_ret_val
        THEN
            v_ret_val   := 'TRUE';
        ELSE
            v_ret_val   := 'FALSE';
        END IF;

        write_log (' Done CALL_PROCESS_ORDER... Returning' || v_ret_val);
        RETURN b_ret_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                ' Global exception handler hit in CALL_PROCESS_ORDER: ');
            write_log (SQLERRM);
            RETURN FALSE;
    END;

    PROCEDURE UPDATE_IR_REQUEST_DATE (ERRBUF                 OUT VARCHAR2,
                                      RETCODE                OUT VARCHAR2,
                                      P_ORGANIZATION_ID   IN     NUMBER, --IR Destination Org -REQ
                                      P_PO_NUMBER         IN     VARCHAR2,
                                      P_AS_OF_DAYS        IN     INTEGER) --Report Mode        -OPT
    IS
        CURSOR C_IR_HEADER IS
              SELECT DISTINCT PRHA.REQUISITION_HEADER_ID, PRHA.SEGMENT1 REQ_NUMBER, MP.ORGANIZATION_CODE,
                              OOLA.HEADER_ID, OOLA.ORG_ID, OOHA.ORDER_NUMBER
                FROM PO_REQUISITION_HEADERS_ALL PRHA, PO_REQUISITION_LINES_ALL PRLA, OE_ORDER_LINES_ALL OOLA,
                     OE_ORDER_HEADERS_ALL OOHA, MTL_RESERVATIONS MR, PO_LINE_LOCATIONS_ALL PLLA,
                     PO_LINES_ALL PLA, PO_HEADERS_ALL PHA, MTL_PARAMETERS MP
               WHERE     1 = 1
                     --Parameters
                     AND PRLA.DESTINATION_ORGANIZATION_ID = P_ORGANIZATION_ID
                     AND PHA.SEGMENT1 = NVL (P_PO_NUMBER, PHA.SEGMENT1)
                     --
                     AND PRHA.REQUISITION_HEADER_ID =
                         PRLA.REQUISITION_HEADER_ID
                     AND PRLA.DESTINATION_ORGANIZATION_ID = MP.ORGANIZATION_ID
                     AND PRLA.QUANTITY - PRLA.QUANTITY_DELIVERED > 0
                     AND PRLA.REQUISITION_LINE_ID =
                         OOLA.SOURCE_DOCUMENT_LINE_ID
                     AND PRLA.REQUISITION_HEADER_ID = OOLA.SOURCE_DOCUMENT_ID
                     AND OOLA.LINE_ID = MR.DEMAND_SOURCE_LINE_ID
                     AND OOLA.INVENTORY_ITEM_ID = PLA.ITEM_ID
                     AND OOLA.HEADER_ID = OOHA.HEADER_ID
                     AND MR.SUPPLY_SOURCE_LINE_ID = PLLA.LINE_LOCATION_ID
                     AND MR.SUPPLY_SOURCE_HEADER_ID = PLLA.PO_HEADER_ID
                     AND MR.SUPPLY_SOURCE_TYPE_ID = 1
                     AND OOLA.REQUEST_DATE != PLLA.PROMISED_DATE
                     AND PLLA.PO_LINE_ID = PLA.PO_LINE_ID
                     AND PLA.PO_HEADER_ID = PHA.PO_HEADER_ID
                     AND EXISTS
                             (SELECT 1
                                FROM PO_LINE_LOCATIONS_ARCHIVE_ALL PLLA_ARCHIVE
                               WHERE     PLLA.LINE_LOCATION_ID =
                                         PLLA_ARCHIVE.LINE_LOCATION_ID
                                     AND PLLA.PROMISED_DATE !=
                                         PLLA_ARCHIVE.PROMISED_DATE)
                     AND (TRUNC (PRHA.LAST_UPDATE_DATE) > TRUNC (SYSDATE - (NVL (P_AS_OF_DAYS, 5))) OR TRUNC (PRHA.LAST_UPDATE_DATE) > TRUNC (SYSDATE - (NVL (P_AS_OF_DAYS, 5))) -- PO_AS_OF_DATE -- Start
                                                                                                                                                                                 OR TRUNC (PLLA.LAST_UPDATE_DATE) > TRUNC (SYSDATE - (NVL (P_AS_OF_DAYS, 5)))-- PO_AS_OF_DATE -- End
                                                                                                                                                                                                                                                             )
            ORDER BY OOLA.HEADER_ID;

        CURSOR C_IR_LINES (P_HEADER_ID NUMBER)
        IS
              SELECT PHA.SEGMENT1 PO_NUMBER, PLA.LINE_NUM, PLLA.PROMISED_DATE,
                     MTL.SEGMENT1 SKU, PLLA.LINE_LOCATION_ID, PLA.PO_LINE_ID,
                     PLA.ORG_ID, OOLA.REQUEST_DATE, OOLA.LINE_ID,
                     OOLA.LINE_NUMBER, OOLA.HEADER_ID, OOLA.ORG_ID SO_ORG_ID
                FROM OE_ORDER_LINES_ALL OOLA,
                     MTL_RESERVATIONS MR,
                     PO_LINE_LOCATIONS_ALL PLLA,
                     PO_LINES_ALL PLA,
                     PO_HEADERS_ALL PHA,
                     (SELECT *
                        FROM MTL_SYSTEM_ITEMS_B
                       WHERE ORGANIZATION_ID = 106) MTL
               WHERE     1 = 1
                     --Parameters
                     AND OOLA.HEADER_ID = P_HEADER_ID
                     --
                     AND OOLA.LINE_ID = MR.DEMAND_SOURCE_LINE_ID
                     AND OOLA.INVENTORY_ITEM_ID = PLA.ITEM_ID
                     AND MR.SUPPLY_SOURCE_LINE_ID = PLLA.LINE_LOCATION_ID
                     AND MR.SUPPLY_SOURCE_HEADER_ID = PLLA.PO_HEADER_ID
                     AND MR.SUPPLY_SOURCE_TYPE_ID = 1
                     AND OOLA.INVENTORY_ITEM_ID = MTL.INVENTORY_ITEM_ID
                     AND OOLA.REQUEST_DATE != PLLA.PROMISED_DATE
                     AND PLLA.PO_LINE_ID = PLA.PO_LINE_ID
                     AND PLA.PO_HEADER_ID = PHA.PO_HEADER_ID
                     AND EXISTS
                             (SELECT 1
                                FROM PO_LINE_LOCATIONS_ARCHIVE_ALL PLLA_ARCHIVE
                               WHERE     PLLA.LINE_LOCATION_ID =
                                         PLLA_ARCHIVE.LINE_LOCATION_ID
                                     AND PLLA.PROMISED_DATE !=
                                         PLLA_ARCHIVE.PROMISED_DATE)
            ORDER BY OOLA.HEADER_ID, PLA.PO_LINE_ID, PLA.LINE_NUM;

        -- send email parameters
        lt_users_email_lst   do_mail_utils.tbl_recips;
        lc_status            NUMBER := 0;
        le_mail_exception    EXCEPTION;
        lc_from_address      VARCHAR2 (50);
        lv_subject           VARCHAR2 (100)
            := 'Internal Sale Order Need by Date updates program failures';
        V_PROFILE_VALUE      VARCHAR2 (100);
        lb_ret_val           BOOLEAN;

        --Order line table
        lt_line_tbl          oe_order_pub.line_tbl_type;         -- upd orders
    BEGIN
        write_log ('Step 1: Inside ' || gv_package_name || 'Main');
        write_log (' Parameters        ');
        write_log (' p_inv_org_id   :        ' || P_ORGANIZATION_ID);
        write_log (' p_po_number    :        ' || P_PO_NUMBER);
        write_log (
            'Start Time : ' || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        --Get From Email Address
        BEGIN
            SELECT fscpv.parameter_value
              INTO lc_from_address
              FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
             WHERE     fscpt.parameter_id = fscpv.parameter_id
                   AND fscpv.component_id = fsc.component_id
                   AND fscpt.display_name = 'Reply-to Address'
                   AND fsc.component_name = 'Workflow Notification Mailer';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log ('Error deriving FROM email address:' || SQLERRM);
                RAISE le_mail_exception;
        END;

        write_log ('Step 2: Run loop through ISO records : ');

        --Loop through each order header to update the request date on the order lines
        FOR IR_HEADER_REC IN C_IR_HEADER
        LOOP
            write_log (
                   'After get record : '
                || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
            write_log (
                '--Processing ISO Number : ' || ir_header_rec.order_number);

            --loop through each elegible order line and add to the order lines table to update
            FOR IR_LINES_REC IN C_IR_LINES (IR_HEADER_REC.HEADER_ID)
            LOOP
                write_log (
                       'after get line : '
                    || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
                write_log (
                    '----Procesing order line number : ' || ir_lines_rec.line_number);
                write_log (
                       '     PO Promised Date : '
                    || TO_CHAR (ir_lines_rec.promised_date, 'MM/DD/YYYY'));
                write_log (
                       '     ISO Request Date : '
                    || TO_CHAR (ir_lines_rec.request_date, 'MM/DD/YYYY'));

                lt_line_tbl (lt_line_tbl.COUNT + 1)   :=
                    oe_order_pub.g_miss_line_rec;
                lt_line_tbl (lt_line_tbl.COUNT).line_id   :=
                    ir_lines_rec.line_id;
                lt_line_tbl (lt_line_tbl.COUNT).header_id   :=
                    ir_header_rec.header_id;
                lt_line_tbl (lt_line_tbl.COUNT).request_date   :=
                    ir_lines_rec.promised_date;
                lt_line_tbl (lt_line_tbl.COUNT).operation   :=
                    oe_globals.g_opr_update;
                lt_line_tbl (lt_line_tbl.COUNT).ORG_ID   :=
                    ir_header_rec.org_id;
            END LOOP;

            write_log (
                   'done with loops : '
                || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

            --Process the lines on the order
            write_log ('--Run oe_process_order');
            APPS.fnd_global.APPS_INITIALIZE (fnd_global.user_id,
                                             fnd_global.resp_id,
                                             fnd_global.resp_appl_id);
            APPS.mo_global.init ('ONT');
            mo_global.set_policy_context ('S', ir_header_rec.org_id);

            write_log (
                   'before process order : '
                || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
            lb_ret_val   :=
                call_process_order (lt_line_tbl, ir_header_rec.org_id);
            write_log ('Count1' || ' : ' || lt_line_tbl.COUNT);
            write_log (
                   'Header id'
                || ' : '
                || lt_line_tbl (lt_line_tbl.COUNT).header_id);
            write_log (
                   'after process order : '
                || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

            IF NOT lb_ret_val
            THEN
                -- WARNING_END - Start
                --            retcode := 2;
                retcode   := 1;
                -- WARNING_END - End
                errbuf    :=
                    'There has been some errors in Processing the Orders.. ';
                write_log (
                    'There has been some errors in Processing the Orders.. ');
            END IF;

            lt_line_tbl.delete;
        END LOOP;

        write_log ('done : ' || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
    EXCEPTION
        WHEN le_mail_exception
        THEN
            retcode   := '2';
            errbuf    := 'Program completed without sending email';
            write_log ('Program completed without sending email');
        -- do_mail_utils.send_mail_close (lc_status);
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    := SQLERRM;
            write_log (gv_package_name || 'Main: ' || errbuf);
    END;

    --Procedure toreport on mismatches between PO promised date and ISO requested XF date
    PROCEDURE PO_ISO_DATE_MISMATCH_RPT (ERRBUF            OUT VARCHAR2,
                                        RETCODE           OUT VARCHAR2,
                                        P_INV_ORG_ID   IN     VARCHAR2,
                                        P_PO_NUMBER    IN     VARCHAR2,
                                        P_AS_OF_DATE   IN     NUMBER)
    IS
        CURSOR c_recs IS
              SELECT PHA.SEGMENT1 PO_NUMBER, PLA.LINE_NUM PO_LINE_NUM, MSIB.SEGMENT1 SKU,
                     PLA.QUANTITY PO_QTY, TRUNC (PLLA.PROMISED_DATE) PROMISED_DATE, HR.NAME DESTINATION_ORG,
                     IRHA.SEGMENT1 IR_NUMBER, IRLA.LINE_NUM IR_LINE_NUM, TRUNC (IRLA.NEED_BY_DATE) IR_NEED_BY_DATE
                FROM PO_REQUISITION_HEADERS_ALL PRHA, PO_REQUISITION_LINES_ALL PRLA, OE_ORDER_LINES_ALL OOLA,
                     OE_ORDER_HEADERS_ALL OOHA, MTL_RESERVATIONS MR, PO_LINE_LOCATIONS_ALL PLLA,
                     PO_LINES_ALL PLA, PO_HEADERS_ALL PHA, MTL_PARAMETERS MP,
                     MTL_SYSTEM_ITEMS_B MSIB, PO_REQUISITION_LINES_ALL IRLA, PO_REQUISITION_HEADERS_ALL IRHA,
                     HR_ALL_ORGANIZATION_UNITS HR
               WHERE     1 = 1
                     --Parameters
                     AND PRLA.DESTINATION_ORGANIZATION_ID = P_INV_ORG_ID
                     AND PHA.SEGMENT1 = NVL (P_PO_NUMBER, PHA.SEGMENT1)
                     --
                     AND PRHA.REQUISITION_HEADER_ID =
                         PRLA.REQUISITION_HEADER_ID
                     AND PRLA.DESTINATION_ORGANIZATION_ID = MP.ORGANIZATION_ID
                     AND PRLA.QUANTITY - PRLA.QUANTITY_DELIVERED > 0
                     AND PRLA.REQUISITION_LINE_ID =
                         OOLA.SOURCE_DOCUMENT_LINE_ID
                     AND PRLA.REQUISITION_HEADER_ID = OOLA.SOURCE_DOCUMENT_ID
                     AND OOLA.LINE_ID = MR.DEMAND_SOURCE_LINE_ID
                     AND OOLA.INVENTORY_ITEM_ID = PLA.ITEM_ID
                     AND OOLA.HEADER_ID = OOHA.HEADER_ID
                     AND MR.SUPPLY_SOURCE_LINE_ID = PLLA.LINE_LOCATION_ID
                     AND MR.SUPPLY_SOURCE_HEADER_ID = PLLA.PO_HEADER_ID
                     AND MR.SUPPLY_SOURCE_TYPE_ID = 1
                     AND OOLA.REQUEST_DATE != PLLA.PROMISED_DATE
                     AND PLLA.PO_LINE_ID = PLA.PO_LINE_ID
                     AND PLA.PO_HEADER_ID = PHA.PO_HEADER_ID
                     AND PLA.ITEM_ID = MSIB.INVENTORY_ITEM_ID
                     AND PLLA.SHIP_TO_ORGANIZATION_ID = MSIB.ORGANIZATION_ID
                     AND OOLA.SOURCE_DOCUMENT_LINE_ID =
                         IRLA.REQUISITION_LINE_ID
                     AND OOLA.SOURCE_DOCUMENT_ID = IRLA.REQUISITION_HEADER_ID
                     AND IRLA.REQUISITION_HEADER_ID =
                         IRHA.REQUISITION_HEADER_ID
                     AND IRLA.DESTINATION_ORGANIZATION_ID = HR.ORGANIZATION_ID
                     AND EXISTS
                             (SELECT 1
                                FROM PO_LINE_LOCATIONS_ARCHIVE_ALL PLLA_ARCHIVE
                               WHERE     PLLA.LINE_LOCATION_ID =
                                         PLLA_ARCHIVE.LINE_LOCATION_ID
                                     AND PLLA.PROMISED_DATE !=
                                         PLLA_ARCHIVE.PROMISED_DATE)
                     AND (TRUNC (PRHA.LAST_UPDATE_DATE) > TRUNC (SYSDATE - (NVL (P_AS_OF_DATE, 5))) OR TRUNC (PRHA.LAST_UPDATE_DATE) > TRUNC (SYSDATE - (NVL (P_AS_OF_DATE, 5))) -- PO_AS_OF_DATE -- Start
                                                                                                                                                                                 OR TRUNC (PLLA.LAST_UPDATE_DATE) > TRUNC (SYSDATE - (NVL (P_AS_OF_DATE, 5)))-- PO_AS_OF_DATE -- End
                                                                                                                                                                                                                                                             )
            ORDER BY OOLA.HEADER_ID;

        lc_email_body_hdr   VARCHAR2 (2000) := NULL;
        lc_body             VARCHAR2 (32767) := NULL;
    BEGIN
        lc_email_body_hdr   :=
               '<html><body>'
            || 'Factory PO Promised Date not matching ISO Request Date Report'
            || ' <br>'
            || '<table border="1" width="105%">'
            || '<tr><b>'
            || '<td width="10%" bgcolor="#cfe0f1" align="center" valign="middle">Factory PO</td>'
            || '<td width="6%" bgcolor="#cfe0f1" align="center" valign="middle">PO Line #</td>'
            || '<td width="10%" bgcolor="#cfe0f1" align="center" valign="middle">SKU</td>'
            || '<td width="8%" bgcolor="#cfe0f1" align="center" valign="middle">Quantity</td>'
            || '<td width="12%" bgcolor="#cfe0f1" align="center" valign="middle">PO Line Promised Date</td>'
            || '<td width="20%" bgcolor="#cfe0f1" align="center" valign="middle">Dest. Org.</td>'
            || '<td width="10%" bgcolor="#cfe0f1" align="center" valign="middle">IR #</td>'
            || '<td width="6%" bgcolor="#cfe0f1" align="center" valign="middle">IR Line #</td>'
            || '<td width="12%" bgcolor="#cfe0f1" align="center" valign="middle">IR Need By Date</td>'
            || '</b></tr>';
        fnd_file.put_line (fnd_file.output, lc_email_body_hdr);

        FOR rec IN c_recs
        LOOP
            lc_body   :=
                   '<tr valign="middle">'
                || '<td width="10%"  align="right">'
                || rec.po_number
                || '</td>'
                || '<td width="6%"   align="right">'
                || rec.po_line_num
                || '</td>'
                || '<td width="10%"   align="right">'
                || rec.sku
                || '</td>'
                || '<td width="8%"   align="right">'
                || rec.po_qty
                || '</td>'
                || '<td width="12%" align="right">'
                || rec.promised_date
                || '</td>'
                || '<td width="20%" align="right">'
                || rec.destination_org
                || '</td>'
                || '<td width="10%" align="right">'
                || rec.ir_number
                || '</td>'
                || '<td width="6%"   align="right">'
                || rec.ir_line_num
                || '</td>'
                || '<td width="12%" align="right">'
                || rec.ir_need_by_date
                || '</td>'
                || '</tr>';
            fnd_file.put_line (fnd_file.output, lc_body);
        END LOOP;
    END;

    PROCEDURE UPDATE_JP_TQ_PO_PRICE (ERRBUF            OUT VARCHAR2,
                                     RETCODE           OUT VARCHAR2,
                                     P_INV_ORG_ID   IN     VARCHAR2,
                                     P_PO_NUMBER    IN     VARCHAR2,
                                     P_AS_OF_DATE   IN     NUMBER)
    IS
        --Start Modification by BT Technology Team v1.2 on 15-SEP-2015 for CR# 104
        CURSOR cur_jpn_tq_po_update IS
              SELECT mac_so.header_id,
                     mac_so.order_number,
                     mac_so_lines.line_id,
                     mac_so_lines.line_number,
                     mac_so.org_id,
                     mac_so_lines.ordered_item,
                     mac_pll.promised_date,
                     jp_po.vendor_id,
                     jp_po.org_id jp_org_id,
                     jp_po.segment1,
                     jp_po.revision_num,
                     jp_po_lines.line_num,
                     jp_pll.shipment_num,
                     jp_pll.line_location_id           --Added for change 1.13
                                            ,
                     mtl.segment1 item_number,
                     assa.vendor_site_code,
                     mac_so_lines.request_date --start modification for defect#255
                                              ,
                     jp_pll.promised_date jp_act_promised_date -- Added by BT Tech Team on 09-Nov-2015 for defect# 507
                                                              ,
                       mac_pll.promised_date
                     --Intransit From TQ SO to TQ PO
                     + NVL (
                           (SELECT --flv.attribute6 --Commented for change 1.13
                                   --START of change 1.13
                                   (CASE
                                        WHEN UPPER (flv.attribute8) = 'AIR'
                                        THEN
                                            flv.attribute5
                                        WHEN UPPER (flv.attribute8) = 'OCEAN'
                                        THEN
                                            flv.attribute6
                                        WHEN UPPER (flv.attribute8) = 'TRUCK'
                                        THEN
                                            flv.attribute7
                                        ELSE
                                            flv.attribute6
                                    END)
                              --END of change 1.13
                              FROM fnd_lookup_values flv
                             WHERE     flv.language = 'US'
                                   AND flv.lookup_type =
                                       'XXDO_SUPPLIER_INTRANSIT'
                                   AND flv.attribute1 = jp_po.vendor_id
                                   AND flv.attribute2 = assa.vendor_site_code
                                   AND flv.attribute3 = 'JP'
                                   AND flv.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN flv.start_date_active
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           SYSDATE + 1)),
                           0) jp_promised_date
                --end  modification for defect#255
                FROM po_headers_all jp_po, po_lines_all jp_po_lines, apps.po_line_locations_all jp_pll,
                     apps.mtl_parameters mp, apps.mtl_system_items_b mtl, oe_order_headers_all mac_so,
                     oe_order_lines_all mac_so_lines, oe_drop_ship_sources mac_drop_ship, po_headers_all mac_po,
                     po_lines_all mac_po_lines, apps.po_line_locations_all mac_pll, ap_supplier_sites_all assa
               WHERE     1 = 1
                     AND jp_po.po_header_id = jp_po_lines.po_header_id
                     AND jp_po_lines.po_line_id = jp_pll.po_line_id
                     --- START  modification for defect#255
                     AND mac_so_lines.flow_status_code <> 'CLOSED'
                     --end  modification for defect#255
                     AND jp_po.org_id = (SELECT organization_id
                                           FROM hr_operating_units
                                          WHERE name = 'Deckers Japan OU')
                     AND jp_po_lines.attribute_category =
                         'Intercompany PO Copy'
                     AND jp_po_lines.attribute5 = mac_so_lines.line_id
                     AND mac_so_lines.header_id = mac_so.header_id
                     AND mac_so.org_id = (SELECT organization_id
                                            FROM hr_operating_units
                                           WHERE name = 'Deckers Macau OU')
                     AND mac_drop_ship.line_id = mac_so_lines.line_id
                     AND mac_drop_ship.po_line_id = mac_po_lines.po_line_id
                     AND mac_drop_ship.po_header_id = mac_po.po_header_id
                     AND mac_po_lines.po_header_id = mac_po.po_header_id
                     AND mac_po.org_id = mac_so.org_id
                     AND mac_pll.po_line_id = mac_po_lines.po_line_id
                     AND mac_po_lines.item_id = mtl.inventory_item_id(+) -- inv org parameter
                     AND mtl.organization_id =
                         NVL (TO_NUMBER (p_inv_org_id), mtl.organization_id)
                     AND mtl.organization_id = mac_pll.ship_to_organization_id
                     AND mtl.organization_id = mp.organization_id(+)
                     AND jp_po.vendor_site_id = assa.vendor_site_id
                     AND (   mac_pll.promised_date <> mac_so_lines.request_date
                          --start modification for defect#255
                          OR jp_pll.promised_date <>
                               mac_pll.promised_date
                             --Intransit from TQ SO to TQ PO
                             + NVL (
                                   (SELECT --flv.attribute6 --Commented for change 1.13
                                           --START of change 1.13
                                           (CASE
                                                WHEN UPPER (flv.attribute8) =
                                                     'AIR'
                                                THEN
                                                    flv.attribute5
                                                WHEN UPPER (flv.attribute8) =
                                                     'OCEAN'
                                                THEN
                                                    flv.attribute6
                                                WHEN UPPER (flv.attribute8) =
                                                     'TRUCK'
                                                THEN
                                                    flv.attribute7
                                                ELSE
                                                    flv.attribute6
                                            END)
                                      --END of change 1.13
                                      FROM fnd_lookup_values flv
                                     WHERE     flv.language = 'US'
                                           AND flv.lookup_type =
                                               'XXDO_SUPPLIER_INTRANSIT'
                                           AND flv.attribute1 = jp_po.vendor_id
                                           AND flv.attribute2 =
                                               assa.vendor_site_code
                                           AND flv.attribute3 = 'JP'
                                           AND flv.enabled_flag = 'Y'
                                           AND SYSDATE BETWEEN flv.start_date_active
                                                           AND NVL (
                                                                   flv.end_date_active,
                                                                   SYSDATE + 1)),
                                   0))
                     --end  modification for defect#255
                     AND (TRUNC (mac_po_lines.last_update_date) > TRUNC (SYSDATE - (NVL (p_as_of_date, 5))) OR TRUNC (mac_pll.last_update_date) > TRUNC (SYSDATE - (NVL (p_as_of_date, 5))))
                     AND mac_po.segment1 = NVL (p_po_number, mac_po.segment1)
            ORDER BY jp_po.segment1, jp_po_lines.line_num;

        TYPE t_jpn_tq_po_update IS TABLE OF cur_jpn_tq_po_update%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_jpn_tq_po_update   t_jpn_tq_po_update;

        l_api_errors         PO_API_ERRORS_REC_TYPE;

        l_tq_po_update_err   NUMBER;
        l_po_num_approval    VARCHAR2 (100);
        ln_no_of_days        NUMBER;
        lb_ret_val           BOOLEAN;

        l_resp_appl_id       NUMBER;
        l_resp_id            NUMBER;
        p_header_id          NUMBER := 0;
        l_user_id            NUMBER;

        l_result             NUMBER;
        l_retcode            NUMBER;
        l_errbuf             VARCHAR2 (3000);

        lt_line_tbl          oe_order_pub.line_tbl_type;         -- upd orders
    BEGIN
        WRITE_LOG ('Inside Japan TQ PO Date Update');

        OPEN cur_jpn_tq_po_update;

        FETCH cur_jpn_tq_po_update BULK COLLECT INTO l_jpn_tq_po_update;

        CLOSE cur_jpn_tq_po_update;

        WRITE_LOG ('l_jpn_tq_po_update.COUNT ' || l_jpn_tq_po_update.COUNT);

        IF l_jpn_tq_po_update.COUNT = 0
        THEN
            WRITE_LOG (
                'There are no PO''s to be updated for the run type Japan TQ PO Date Update');
        ELSE
            fnd_file.put_line (
                fnd_file.OUTPUT,
                'PO Number      PO Line Num    PO Item             Order Number   Order Line Num Order Item          ');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                '-----------------------------------------------------------------------------------------------------   ');

            lt_line_tbl.DELETE;
            l_po_num_approval   := l_jpn_tq_po_update (1).segment1;

            FOR i IN 1 .. l_jpn_tq_po_update.COUNT
            LOOP
                l_tq_po_update_err   := 0;
                WRITE_LOG ('Line id is ' || l_jpn_tq_po_update (i).line_id);

                IF     l_jpn_tq_po_update (i).request_date IS NOT NULL
                   AND l_jpn_tq_po_update (i).line_id IS NOT NULL
                THEN
                    IF ((l_jpn_tq_po_update (i).request_date <> l_jpn_tq_po_update (i).promised_date) OR (l_jpn_tq_po_update (i).jp_act_promised_date <> l_jpn_tq_po_update (i).jp_promised_date)) -- Added by BT Tech Team on 09-Nov-2015 for defect# 507
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Request and promise data are not in sync so updaing SO');
                        -- saving the data to update the SO by API
                        lt_line_tbl.delete;
                        lt_line_tbl (lt_line_tbl.COUNT + 1)   :=
                            oe_order_pub.g_miss_line_rec;
                        lt_line_tbl (lt_line_tbl.COUNT).line_id   :=
                            l_jpn_tq_po_update (i).line_id;
                        lt_line_tbl (lt_line_tbl.COUNT).header_id   :=
                            l_jpn_tq_po_update (i).header_id;
                        lt_line_tbl (lt_line_tbl.COUNT).request_date   :=
                            l_jpn_tq_po_update (i).promised_date;
                        lt_line_tbl (lt_line_tbl.COUNT).operation   :=
                            oe_globals.g_opr_update;
                        lt_line_tbl (lt_line_tbl.COUNT).ORG_ID   :=
                            l_jpn_tq_po_update (i).ORG_ID;

                        IF lt_line_tbl.COUNT > 0
                        THEN
                            l_resp_appl_id   := fnd_global.resp_appl_id;
                            l_resp_id        := fnd_global.resp_id;
                            l_user_id        := fnd_global.user_id;
                            APPS.fnd_global.APPS_INITIALIZE (l_user_id,
                                                             l_resp_id,
                                                             l_resp_appl_id);
                            APPS.mo_global.init ('ONT');
                            mo_global.set_policy_context (
                                'S',
                                l_jpn_tq_po_update (i).org_id);
                            -- Invoke the API procedure to update the  SO order
                            lb_ret_val       :=
                                call_process_order (
                                    lt_line_tbl,
                                    l_jpn_tq_po_update (i).org_id);

                            IF NOT lb_ret_val
                            THEN
                                l_tq_po_update_err   := 1;
                                write_log (
                                       'There has some errors in Processing the Order '
                                    || l_jpn_tq_po_update (i).order_number);
                            END IF;
                        END IF;

                        IF l_tq_po_update_err = 0
                        THEN
                            BEGIN
                                ln_no_of_days   := 0;

                                SELECT --flv.attribute6 --Commented for change 1.13
                                       --START of change 1.13
                                       (CASE
                                            WHEN UPPER (flv.attribute8) =
                                                 'AIR'
                                            THEN
                                                flv.attribute5
                                            WHEN UPPER (flv.attribute8) =
                                                 'OCEAN'
                                            THEN
                                                flv.attribute6
                                            WHEN UPPER (flv.attribute8) =
                                                 'TRUCK'
                                            THEN
                                                flv.attribute7
                                            ELSE
                                                flv.attribute6
                                        END)
                                  --END of change 1.13
                                  INTO ln_no_of_days
                                  FROM fnd_lookup_values flv
                                 WHERE     1 = 1
                                       AND flv.language = 'US'
                                       AND flv.lookup_type =
                                           'XXDO_SUPPLIER_INTRANSIT'
                                       AND flv.attribute1 =
                                           l_jpn_tq_po_update (i).vendor_id
                                       AND flv.attribute2 =
                                           l_jpn_tq_po_update (i).vendor_site_code
                                       AND flv.attribute3 = 'JP'
                                       AND flv.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN flv.start_date_active
                                                       AND NVL (
                                                               flv.end_date_active,
                                                               SYSDATE + 1);

                                WRITE_LOG (
                                    'ln_no_of_days IS ' || ln_no_of_days);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    ln_no_of_days   := 0;
                                    WRITE_LOG (
                                           'Transit days not defined for Vendor Id: '
                                        || l_jpn_tq_po_update (i).vendor_id
                                        || ' vendor site: '
                                        || l_jpn_tq_po_update (i).vendor_site_code);
                                --Added when others exception for change 1.13
                                WHEN OTHERS
                                THEN
                                    ln_no_of_days   := 0;
                                    WRITE_LOG (
                                           'In When others while getting Intrasit days for Vendor Id: '
                                        || l_jpn_tq_po_update (i).vendor_id
                                        || ' vendor site: '
                                        || l_jpn_tq_po_update (i).vendor_site_code);
                            END;

                            BEGIN
                                l_resp_appl_id   := fnd_global.resp_appl_id;
                                l_resp_id        := fnd_global.resp_id;
                                l_user_id        := fnd_global.user_id;
                                APPS.fnd_global.APPS_INITIALIZE (
                                    l_user_id,
                                    l_resp_id,
                                    l_resp_appl_id);
                                APPS.mo_global.init ('PO');
                                WRITE_LOG ('Before Calling PO API ');

                                SELECT MAX (revision_num)
                                  INTO l_jpn_tq_po_update (i).revision_num
                                  FROM po_headers_all
                                 WHERE segment1 =
                                       l_jpn_tq_po_update (i).segment1;

                                l_result         :=
                                    po_change_api1_s.update_po (
                                        x_po_number             =>
                                            l_jpn_tq_po_update (i).segment1,
                                        x_release_number        => NULL,
                                        x_revision_number       =>
                                            l_jpn_tq_po_update (i).revision_num,
                                        x_line_number           =>
                                            l_jpn_tq_po_update (i).line_num,
                                        x_shipment_number       =>
                                            l_jpn_tq_po_update (i).shipment_num,
                                        new_quantity            => NULL,
                                        new_price               => NULL,
                                        new_promised_date       =>
                                              l_jpn_tq_po_update (i).promised_date
                                            + ln_no_of_days,
                                        --new_need_by_date        => p_new_needby_date,
                                        launch_approvals_flag   => 'N',     --
                                        update_source           => NULL,
                                        version                 => '1.0',
                                        x_override_date         => NULL,
                                        x_api_errors            =>
                                            l_api_errors,
                                        p_buyer_name            => NULL,
                                        p_secondary_quantity    => NULL,
                                        p_preferred_grade       => NULL,
                                        p_org_id                =>
                                            l_jpn_tq_po_update (i).jp_org_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    retcode   := 2;
                                    errbuf    := SQLERRM;
                                    write_log (
                                           gv_package_name
                                        || 'Update request date of PO: '
                                        || errbuf);
                                    RETURN;
                            END;

                            IF l_result <> 1
                            THEN
                                WRITE_LOG (
                                       'Error while updating PO '
                                    || l_jpn_tq_po_update (i).segment1);

                                FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                                LOOP
                                    WRITE_LOG (l_api_errors.MESSAGE_TEXT (i));
                                END LOOP;

                                EXIT;
                            ELSE
                                --Added for change 1.13 - START
                                --Moving the Confirmed Ex-Factory Date to Original Confirmed Ex-Factory Date
                                BEGIN
                                    UPDATE apps.po_line_locations_all jp_plla
                                       SET jp_plla.attribute8 = jp_plla.attribute5, last_update_date = SYSDATE, last_updated_by = g_user_id
                                     WHERE     1 = 1
                                           AND jp_plla.line_location_id =
                                               l_jpn_tq_po_update (i).line_location_id
                                           AND jp_plla.attribute8 IS NULL;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        write_log (
                                               'Error while updating Original Conf.Ex-Factory Date with Conf.Ex-factory Date for PO Line Location ID: '
                                            || l_jpn_tq_po_update (i).line_location_id);
                                END;

                                --Updating the Confirmed Ex-Factory Date with the Request Date of the TQ SO Line
                                BEGIN
                                    UPDATE apps.po_line_locations_all jp_plla
                                       SET jp_plla.attribute5 = TO_CHAR (l_jpn_tq_po_update (i).promised_date, 'YYYY/MM/DD'), jp_plla.last_update_date = SYSDATE, jp_plla.last_updated_by = g_user_id
                                     WHERE     1 = 1
                                           AND jp_plla.line_location_id =
                                               l_jpn_tq_po_update (i).line_location_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        write_log (
                                               'Error while updating Conf.Ex-Factory Date with Request Date of TQ SO Line for PO Line Location ID: '
                                            || l_jpn_tq_po_update (i).line_location_id);
                                END;

                                --Added for change 1.13 - END

                                l_retcode   := 0;
                                l_errbuf    := NULL;

                                IF l_po_num_approval <>
                                   l_jpn_tq_po_update (i).segment1
                                THEN
                                    PO_APPROVAL (l_po_num_approval, l_jpn_tq_po_update (i).jp_org_id, l_retcode
                                                 , l_errbuf);
                                    l_po_num_approval   :=
                                        l_jpn_tq_po_update (i).segment1;

                                    IF     l_retcode <> 0
                                       AND l_errbuf IS NOT NULL
                                    THEN
                                        write_log (
                                               'Error while approving for PO : '
                                            || l_jpn_tq_po_update (i).segment1
                                            || ' is '
                                            || l_errbuf);
                                    END IF;
                                ELSIF i = l_jpn_tq_po_update.COUNT
                                THEN
                                    PO_APPROVAL (l_jpn_tq_po_update (i).segment1, l_jpn_tq_po_update (i).jp_org_id, l_retcode
                                                 , l_errbuf);

                                    IF     l_retcode <> 0
                                       AND l_errbuf IS NOT NULL
                                    THEN
                                        write_log (
                                               'Error while approving for PO : '
                                            || l_jpn_tq_po_update (i).segment1
                                            || ' is '
                                            || l_errbuf);
                                    END IF;
                                END IF;

                                COMMIT;
                                fnd_file.put_line (
                                    fnd_file.OUTPUT,
                                       RPAD (l_jpn_tq_po_update (i).segment1,
                                             15,
                                             ' ')
                                    || RPAD (l_jpn_tq_po_update (i).line_num,
                                             15,
                                             ' ')
                                    || RPAD (
                                           l_jpn_tq_po_update (i).item_number,
                                           20,
                                           ' ')
                                    || RPAD (
                                           l_jpn_tq_po_update (i).order_number,
                                           15,
                                           ' ')
                                    || RPAD (
                                           l_jpn_tq_po_update (i).line_number,
                                           15,
                                           ' ')
                                    || RPAD (
                                           l_jpn_tq_po_update (i).ordered_item,
                                           20,
                                           ' '));
                            END IF;
                        END IF;
                    END IF;  -- end compare the request date and promised date
                END IF;
            END LOOP;
        END IF;
    --Added Exception as part of change 1.13 --START
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    :=
                SUBSTR (
                       'When Others Exception in '
                    || gv_package_name
                    || 'UPDATE_JP_TQ_PO_PRICE procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            retcode   := '2';
            write_log (errbuf);
    --Added Exception as part of change 1.13 --END
    END UPDATE_JP_TQ_PO_PRICE;

    PROCEDURE UPDATE_REGIONAL_ASN_DATE (ERRBUF             OUT VARCHAR2,
                                        RETCODE            OUT VARCHAR2,
                                        P_INV_ORG_ID    IN     VARCHAR2,
                                        P_PO_NUMBER     IN     VARCHAR2,
                                        P_NUM_OF_DAYS   IN     NUMBER)
    IS
        CURSOR P_ASN_LINES IS
            SELECT DISTINCT IR_ASNH.SHIPMENT_HEADER_ID, TRUNC (IR_ASNH.EXPECTED_RECEIPT_DATE) IR_ASN_DATE, TRUNC (FAC_ASNH.EXPECTED_RECEIPT_DATE) FAC_ASN_DATE,
                            TRUNC (SUP.RECEIPT_DATE) SUPPLY_DATE
              FROM RCV_SHIPMENT_LINES IR_ASNL, RCV_SHIPMENT_HEADERS IR_ASNH, PO_REQUISITION_LINES_ALL IRL,
                   PO_REQUISITION_HEADERS_ALL IRH, OE_ORDER_LINES_ALL ISOL, OE_ORDER_HEADERS_ALL ISOH,
                   PO_LINE_LOCATIONS_ALL FAC_POLL, PO_LINES_ALL FAC_POL, PO_HEADERS_ALL FAC_POH,
                   RCV_SHIPMENT_HEADERS FAC_ASNH, RCV_SHIPMENT_LINES FAC_ASNL, MTL_SUPPLY SUP
             WHERE     1 = 1
                   --  AND IR_ASNL.TO_ORGANIZATION_ID = :P_INV_ORG_ID
                   AND IR_ASNL.REQUISITION_LINE_ID = SUP.REQ_LINE_ID
                   AND IR_ASNL.SHIPMENT_HEADER_ID =
                       IR_ASNH.SHIPMENT_HEADER_ID
                   AND IR_ASNL.REQUISITION_LINE_ID = IRL.REQUISITION_LINE_ID
                   AND IRL.REQUISITION_HEADER_ID = IRH.REQUISITION_HEADER_ID
                   AND IRL.REQUISITION_HEADER_ID = ISOL.SOURCE_DOCUMENT_ID
                   AND IRL.REQUISITION_LINE_ID = ISOL.SOURCE_DOCUMENT_LINE_ID
                   AND IRH.SEGMENT1 = ISOL.ORIG_SYS_DOCUMENT_REF
                   AND ISOL.HEADER_ID = ISOH.HEADER_ID
                   AND ISOL.ATTRIBUTE16 = TO_CHAR (FAC_POLL.LINE_LOCATION_ID)
                   AND ISOL.INVENTORY_ITEM_ID = FAC_POL.ITEM_ID
                   AND FAC_POLL.PO_LINE_ID = FAC_POL.PO_LINE_ID
                   AND FAC_POL.PO_HEADER_ID = FAC_POH.PO_HEADER_ID
                   AND FAC_POLL.LINE_LOCATION_ID =
                       FAC_ASNL.PO_LINE_LOCATION_ID
                   AND FAC_ASNL.SHIPMENT_HEADER_ID =
                       FAC_ASNH.SHIPMENT_HEADER_ID
                   AND IRL.DESTINATION_ORGANIZATION_ID = P_INV_ORG_ID
                   AND FAC_POH.SEGMENT1 = NVL (P_PO_NUMBER, FAC_POH.SEGMENT1)
                   AND ISOL.ORDER_SOURCE_ID = 10
                   AND IR_ASNL.SHIPMENT_LINE_STATUS_CODE IN
                           ('EXPECTED', 'PARTIALLY RECEIVED')
                   AND FAC_POH.AUTHORIZATION_STATUS IN ('APPROVED')
                   --started commenting CCR0006518
                   /*AND TRUNC (FAC_ASNH.CREATION_DATE) =
                          TRUNC (IR_ASNH.SHIPPED_DATE)*/
                   --end commenting CCR0006518
                   -- START CCR0006704
                   /*AND TRUNC (IR_ASNH.EXPECTED_RECEIPT_DATE) =
                          TRUNC (IR_ASNH.SHIPPED_DATE)*/
                   -- END CCR0006704
                   AND TRUNC (IR_ASNH.EXPECTED_RECEIPT_DATE) !=
                       TRUNC (FAC_ASNH.EXPECTED_RECEIPT_DATE)
                   AND (TRUNC (FAC_POH.LAST_UPDATE_DATE) > --TRUNC (FAC_POL.LAST_UPDATE_DATE) > CCR0006704  Replaced POL with POH
                                                           TRUNC (SYSDATE - (NVL (P_NUM_OF_DAYS, 5))) OR TRUNC (FAC_POL.LAST_UPDATE_DATE) > TRUNC (SYSDATE - (NVL (P_NUM_OF_DAYS, 5))) -- PO_AS_OF_DATE - Start
                                                                                                                                                                                       OR TRUNC (FAC_POLL.LAST_UPDATE_DATE) > TRUNC (SYSDATE - (NVL (P_NUM_OF_DAYS, 5)))-- PO_AS_OF_DATE - End
                                                                                                                                                                                                                                                                        );

        l_fac_asn_count       NUMBER := 0;                       -- CCR0006704
        ld_exp_receipt_date   rcv_shipment_headers.expected_receipt_date%TYPE; -- CCR0006704
    BEGIN
        write_log ('UPDATE_REGIONAL_ASN_DATE - Enter');
        write_log ('INV ORG ID : ' || P_INV_ORG_ID);
        write_log ('PO Number  : ' || P_PO_NUMBER);

        FOR line_rec IN P_ASN_LINES
        LOOP
            -- START CCR0006704
            l_fac_asn_count   := 0;

            BEGIN
                SELECT COUNT (DISTINCT FAC_ASNH.SHIPMENT_NUM)
                  INTO l_fac_asn_count
                  FROM RCV_SHIPMENT_LINES IR_ASNL, RCV_SHIPMENT_HEADERS IR_ASNH, PO_REQUISITION_LINES_ALL IRL,
                       PO_REQUISITION_HEADERS_ALL IRH, OE_ORDER_LINES_ALL ISOL, OE_ORDER_HEADERS_ALL ISOH,
                       PO_LINE_LOCATIONS_ALL FAC_POLL, PO_LINES_ALL FAC_POL, PO_HEADERS_ALL FAC_POH,
                       RCV_SHIPMENT_HEADERS FAC_ASNH, RCV_SHIPMENT_LINES FAC_ASNL, MTL_SUPPLY SUP
                 WHERE     1 = 1
                       AND IR_ASNL.REQUISITION_LINE_ID = SUP.REQ_LINE_ID
                       AND IR_ASNL.SHIPMENT_HEADER_ID =
                           IR_ASNH.SHIPMENT_HEADER_ID
                       AND IR_ASNL.REQUISITION_LINE_ID =
                           IRL.REQUISITION_LINE_ID
                       AND IRL.REQUISITION_HEADER_ID =
                           IRH.REQUISITION_HEADER_ID
                       AND IRL.REQUISITION_HEADER_ID =
                           ISOL.SOURCE_DOCUMENT_ID
                       AND IRL.REQUISITION_LINE_ID =
                           ISOL.SOURCE_DOCUMENT_LINE_ID
                       AND IRH.SEGMENT1 = ISOL.ORIG_SYS_DOCUMENT_REF
                       AND ISOL.HEADER_ID = ISOH.HEADER_ID
                       AND ISOL.ATTRIBUTE16 =
                           TO_CHAR (FAC_POLL.LINE_LOCATION_ID)
                       AND ISOL.INVENTORY_ITEM_ID = FAC_POL.ITEM_ID
                       AND FAC_POLL.PO_LINE_ID = FAC_POL.PO_LINE_ID
                       AND FAC_POL.PO_HEADER_ID = FAC_POH.PO_HEADER_ID
                       AND FAC_POLL.LINE_LOCATION_ID =
                           FAC_ASNL.PO_LINE_LOCATION_ID
                       AND FAC_ASNL.SHIPMENT_HEADER_ID =
                           FAC_ASNH.SHIPMENT_HEADER_ID
                       AND ISOL.ORDER_SOURCE_ID = 10
                       AND IR_ASNL.SHIPMENT_LINE_STATUS_CODE IN
                               ('EXPECTED', 'PARTIALLY RECEIVED')
                       AND FAC_POH.AUTHORIZATION_STATUS IN ('APPROVED')
                       AND TRUNC (IR_ASNH.EXPECTED_RECEIPT_DATE) !=
                           TRUNC (FAC_ASNH.EXPECTED_RECEIPT_DATE)
                       AND IR_ASNH.SHIPMENT_HEADER_ID =
                           line_rec.SHIPMENT_HEADER_ID;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                           'Error found in fetching count of Factory ASNs for IR Shipment header id :: '
                        || line_rec.SHIPMENT_HEADER_ID
                        || ' :: '
                        || SQLERRM);
                    l_fac_asn_count   := NULL;
            END;

            IF l_fac_asn_count > 1
            THEN
                ld_exp_receipt_date   := NULL;

                BEGIN
                    SELECT MAX (TRUNC (FAC_ASNH.EXPECTED_RECEIPT_DATE))
                      INTO ld_exp_receipt_date
                      FROM RCV_SHIPMENT_LINES IR_ASNL, RCV_SHIPMENT_HEADERS IR_ASNH, PO_REQUISITION_LINES_ALL IRL,
                           PO_REQUISITION_HEADERS_ALL IRH, OE_ORDER_LINES_ALL ISOL, OE_ORDER_HEADERS_ALL ISOH,
                           PO_LINE_LOCATIONS_ALL FAC_POLL, PO_LINES_ALL FAC_POL, PO_HEADERS_ALL FAC_POH,
                           RCV_SHIPMENT_HEADERS FAC_ASNH, RCV_SHIPMENT_LINES FAC_ASNL, MTL_SUPPLY SUP
                     WHERE     1 = 1
                           AND IR_ASNL.REQUISITION_LINE_ID = SUP.REQ_LINE_ID
                           AND IR_ASNL.SHIPMENT_HEADER_ID =
                               IR_ASNH.SHIPMENT_HEADER_ID
                           AND IR_ASNL.REQUISITION_LINE_ID =
                               IRL.REQUISITION_LINE_ID
                           AND IRL.REQUISITION_HEADER_ID =
                               IRH.REQUISITION_HEADER_ID
                           AND IRL.REQUISITION_HEADER_ID =
                               ISOL.SOURCE_DOCUMENT_ID
                           AND IRL.REQUISITION_LINE_ID =
                               ISOL.SOURCE_DOCUMENT_LINE_ID
                           AND IRH.SEGMENT1 = ISOL.ORIG_SYS_DOCUMENT_REF
                           AND ISOL.HEADER_ID = ISOH.HEADER_ID
                           AND ISOL.ATTRIBUTE16 =
                               TO_CHAR (FAC_POLL.LINE_LOCATION_ID)
                           AND ISOL.INVENTORY_ITEM_ID = FAC_POL.ITEM_ID
                           AND FAC_POLL.PO_LINE_ID = FAC_POL.PO_LINE_ID
                           AND FAC_POL.PO_HEADER_ID = FAC_POH.PO_HEADER_ID
                           AND FAC_POLL.LINE_LOCATION_ID =
                               FAC_ASNL.PO_LINE_LOCATION_ID
                           AND FAC_ASNL.SHIPMENT_HEADER_ID =
                               FAC_ASNH.SHIPMENT_HEADER_ID
                           AND ISOL.ORDER_SOURCE_ID = 10
                           AND IR_ASNL.SHIPMENT_LINE_STATUS_CODE IN
                                   ('EXPECTED', 'PARTIALLY RECEIVED')
                           AND FAC_POH.AUTHORIZATION_STATUS IN ('APPROVED')
                           AND TRUNC (IR_ASNH.EXPECTED_RECEIPT_DATE) !=
                               TRUNC (FAC_ASNH.EXPECTED_RECEIPT_DATE)
                           AND IR_ASNH.SHIPMENT_HEADER_ID =
                               line_rec.SHIPMENT_HEADER_ID;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Error in Fetching Maximum Expected Receipt date for Internal Order Shipment header id :: '
                            || line_rec.SHIPMENT_HEADER_ID
                            || ' :: '
                            || SQLERRM);
                        ld_exp_receipt_date   := NULL;
                END;

                IF ld_exp_receipt_date IS NOT NULL
                THEN
                    UPDATE rcv_shipment_headers
                       SET expected_receipt_date = ld_exp_receipt_date, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
                     WHERE shipment_header_id = line_rec.SHIPMENT_HEADER_ID;

                    --Then update mtl_sypply
                    UPDATE mtl_supply
                       SET receipt_date = ld_exp_receipt_date, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id,
                           change_flag = 'Y'
                     WHERE     shipment_header_id =
                               line_rec.SHIPMENT_HEADER_ID
                           AND supply_type_code = 'SHIPMENT'
                           AND to_organization_id = p_inv_org_id;
                END IF;
            ELSIF l_fac_asn_count = 1
            THEN
                -- END CCR0006704
                --Loop through the cursor and first update the shipment header
                UPDATE rcv_shipment_headers
                   SET expected_receipt_date = line_rec.FAC_ASN_DATE, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
                 WHERE shipment_header_id = line_rec.SHIPMENT_HEADER_ID;

                --Then update mtl_sypply
                UPDATE mtl_supply
                   SET receipt_date = line_rec.FAC_ASN_DATE,    --request_date
                                                             last_update_date = SYSDATE, last_updated_by = fnd_global.user_id,
                       change_flag = 'Y'
                 WHERE     shipment_header_id = line_rec.SHIPMENT_HEADER_ID
                       AND supply_type_code = 'SHIPMENT'
                       AND to_organization_id = p_inv_org_id;
            END IF;                                              -- CCR0006704
        END LOOP;

        write_log ('UPDATE_REGIONAL_ASN_DATE - Exit');
    END;

    FUNCTION get_transit_time (p_vendor_id IN NUMBER, p_vendor_site_code IN VARCHAR2, p_ship_to_org_id IN NUMBER)
        RETURN NUMBER
    IS
        l_intransit_days          NUMBER := NULL;
        v_days_air                VARCHAR2 (5);
        v_days_ocean              VARCHAR2 (5);
        v_days_truck              VARCHAR2 (5);
        v_preferred_ship_method   VARCHAR2 (20);
    BEGIN
        SELECT NVL (flv.attribute5, 0) air_days, NVL (flv.attribute6, 0) ocean_days, NVL (flv.attribute7, 0) truck_days,
               flv.attribute8
          INTO v_days_air, v_days_ocean, v_days_truck, v_preferred_ship_method
          FROM fnd_lookup_values flv
         WHERE     flv.language = 'US'
               AND flv.lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
               AND flv.attribute1 = p_vendor_id
               AND flv.attribute2 = p_vendor_site_code
               AND flv.attribute4 =
                   (SELECT ftv.territory_short_name
                      FROM hz_cust_site_uses_all hcas, hz_cust_acct_sites_all hcasa, hz_party_sites hps,
                           hz_locations hl, fnd_territories_vl ftv
                     WHERE     hcasa.cust_acct_site_id =
                               hcas.cust_acct_site_id
                           AND hps.party_site_id = hcasa.party_site_id
                           AND hl.location_id = hps.location_id
                           AND ftv.territory_code = hl.country
                           AND hcas.site_use_id = p_ship_to_org_id)
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN flv.start_date_active
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        IF v_preferred_ship_method = 'Air'
        THEN
            RETURN TO_NUMBER (v_days_air);
        ELSIF v_preferred_ship_method = 'Truck'
        THEN
            RETURN TO_NUMBER (v_days_truck);
        ELSE
            RETURN TO_NUMBER (v_days_ocean);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
            write_log ('Error in Fetching Transit Days :: ' || SQLERRM);
    END;


    PROCEDURE TQ_SPLIT_LINE_SYNC (ERRBUF            OUT VARCHAR2,
                                  RETCODE           OUT VARCHAR2,
                                  P_INV_ORG_ID   IN     VARCHAR2,
                                  P_PO_NUMBER    IN     VARCHAR2,
                                  P_AS_OF_DATE   IN     NUMBER)
    IS
        CURSOR cur_split_line IS
            SELECT DISTINCT ooha.header_id, ooha.order_number
              FROM oe_order_headers_all ooha, oe_order_lines_all oola1
             WHERE     oola1.header_id = ooha.header_id
                   AND EXISTS
                           (SELECT 1
                              FROM po_lines_all pll, po_headers_all pha, po_line_locations_all plla,
                                   oe_order_lines_all oola, mtl_system_items_b mtl
                             WHERE     pha.po_header_id = pll.po_header_id
                                   AND oola.header_id = ooha.header_id
                                   AND plla.po_line_id = pll.po_line_id
                                   AND pll.item_id = mtl.inventory_item_id(+)
                                   AND mtl.organization_id =
                                       NVL (TO_NUMBER (p_inv_org_id),
                                            mtl.organization_id)
                                   AND mtl.organization_id =
                                       plla.ship_to_organization_id
                                   AND pll.attribute_category =
                                       'Intercompany PO Copy'
                                   AND pll.attribute5 = oola.line_id
                                   AND (   (oola.ordered_quantity <> pll.quantity)
                                        OR EXISTS
                                               (SELECT 1
                                                  FROM oe_order_lines_all
                                                 WHERE     header_id =
                                                           ooha.header_id
                                                       AND line_id NOT IN
                                                               (SELECT attribute5
                                                                  FROM po_lines_all
                                                                 WHERE po_header_id =
                                                                       pha.po_header_id)))
                                   AND pha.segment1 =
                                       NVL (p_po_number, pha.segment1)
                                   AND TRUNC (oola.last_update_date) >
                                       TRUNC (
                                           SYSDATE - (NVL (p_as_of_date, 5))));


        CURSOR cur_get_po_header_det (p_header_id IN NUMBER)
        IS
            SELECT DISTINCT pha.segment1 document_num, pha.vendor_id, pha.vendor_site_id,
                            pha.ship_to_location_id, pha.bill_to_location_id, pha.currency_code,
                            pha.agent_id, pha.po_header_id, pha.org_id,
                            plla.ship_to_organization_id, pha.revision_num, --Start PRB0041379
                                                                            pll.attribute1 line_attribute1,
                            pll.attribute2 line_attribute2, pll.attribute3 line_attribute3, pll.attribute4 line_attribute4,
                            pll.attribute6 line_attribute6, pll.attribute7 line_attribute7, pll.attribute8 line_attribute8,
                            pll.attribute9 line_attribute9, pll.attribute10 line_attribute10, pll.attribute11 line_attribute11,
                            pll.attribute12 line_attribute12, pll.attribute13 line_attribute13, pll.attribute14 line_attribute14,
                            pll.attribute15 line_attribute15, plla.attribute1 shipment_attribute1, plla.attribute2 shipment_attribute2,
                            plla.attribute3 shipment_attribute3, plla.attribute4 shipment_attribute4, plla.attribute5 shipment_attribute5,
                            plla.attribute6 shipment_attribute6, plla.attribute7 shipment_attribute7, plla.attribute8 shipment_attribute8,
                            plla.attribute9 shipment_attribute9, plla.attribute10 shipment_attribute10, plla.attribute11 shipment_attribute11,
                            plla.attribute12 shipment_attribute12, plla.attribute13 shipment_attribute13, plla.attribute14 shipment_attribute14,
                            plla.attribute15 shipment_attribute15, plla.attribute_category shipment_attribute_category
              --End PRB0041379
              FROM po_lines_all pll, po_headers_all pha, po_line_locations_all plla,
                   oe_order_lines_all oola
             WHERE     oola.line_id = pll.attribute5
                   AND pha.po_header_id = pll.po_header_id
                   AND pll.po_line_id = plla.po_line_id
                   AND oola.header_id = p_header_id
                   AND ROWNUM = 1;

        CURSOR cur_get_ord_line_det (p_header_id IN NUMBER, p_vendor_id IN NUMBER, p_ship_to_org_id IN NUMBER)
        IS
              SELECT ordered_quantity,
                     ordered_item,
                     mom.unit_of_measure,
                     promise_date,
                     unit_selling_price,
                     header_id,
                     inventory_item_id,
                     XXDO_SO_REQ_DATE_UPDATE_PKG.get_tq_list_price (
                         header_id,
                         unit_selling_price,
                         p_vendor_id,
                         inventory_item_id,
                         p_ship_to_org_id) unit_price,
                     line_id,
                     line_number
                FROM oe_order_lines_all oola, mtl_units_of_measure mom
               WHERE     oola.header_id = p_header_id
                     AND mom.uom_code = oola.order_quantity_uom
            ORDER BY line_id;

        CURSOR cur_get_po_line_det (p_line_id IN NUMBER)
        IS
            SELECT pll.po_line_id, pll.quantity, plla.ship_to_organization_id,
                   plla.shipment_num, pll.line_num, msib.segment1
              FROM po_lines_all pll, po_line_locations_all plla, mtl_system_items_b msib
             WHERE     pll.po_line_id = plla.po_line_id
                   AND pll.attribute5 = p_line_id
                   AND msib.inventory_item_id = pll.item_id
                   AND msib.organization_id = plla.ship_to_organization_id
                   AND pll.attribute_category = 'Intercompany PO Copy';

        CURSOR CUR_REPORT_ADD (p_interface_header_id IN NUMBER)
        IS
              SELECT pha.segment1, pla.line_num, pli.item,
                     ooha.order_number, oola.line_number, oola.ordered_item
                FROM po_lines_interface pli, po_lines_all pla, po_headers_all pha,
                     oe_order_lines_all oola, oe_order_headers_all ooha
               WHERE     ooha.header_id = oola.header_id
                     AND pha.po_header_id = pla.po_header_id
                     AND pla.attribute5 = oola.line_id
                     AND pli.po_line_id = pla.po_line_id
                     AND process_code = 'ACCEPTED'
                     AND interface_header_id = p_interface_header_id
            ORDER BY oola.line_number;



        TYPE t_split_line_rec IS TABLE OF cur_split_line%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_split_line_rec           t_split_line_rec;

        l_get_po_header_det        cur_get_po_header_det%ROWTYPE;
        l_get_po_line_det          cur_get_po_line_det%ROWTYPE;

        TYPE t_get_org_line_det IS TABLE OF cur_get_ord_line_det%ROWTYPE
            INDEX BY BINARY_INTEGER;

        TYPE t_report_add IS TABLE OF cur_report_add%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_report_add               t_report_add;



        l_get_ord_line_det         t_get_org_line_det;

        l_interface_header_id      NUMBER;

        l_resp_appl_id             NUMBER;
        l_resp_id                  NUMBER;
        p_header_id                NUMBER := 0;
        l_user_id                  NUMBER;

        l_result                   NUMBER;

        l_doc_number               VARCHAR2 (100) := '1';
        v_return_status            VARCHAR2 (50);
        l_retcode                  NUMBER;
        l_errbuf                   VARCHAR2 (3000);

        v_processed_lines_count    NUMBER := 0;
        v_rejected_lines_count     NUMBER := 0;
        v_err_tolerance_exceeded   VARCHAR2 (100);
        l_api_errors               PO_API_ERRORS_REC_TYPE;

        -- Start PRB0041344
        l_macau_vendor_id          NUMBER := NULL;
        l_macau_vendor_site_code   VARCHAR2 (150) := NULL;
        l_ship_to_org_id           NUMBER := NULL;
        l_macau_exfactory_date     VARCHAR2 (150) := NULL;
        l_tq_vendor_id             NUMBER := NULL;
        l_tq_vendor_site_code      VARCHAR2 (150) := NULL;
        l_macau_transit_days       NUMBER := NULL;
        l_tq_transit_days          NUMBER := NULL;
        lv_promise_date            DATE := NULL;
    -- End PRB0041344
    BEGIN
        write_log ('Begin TQ split line sync');

        --l_split_line_rec := NULL;
        l_split_line_rec.DELETE;

        OPEN cur_split_line;

        FETCH cur_split_line BULK COLLECT INTO l_split_line_rec;

        CLOSE cur_split_line;

        write_log ('l_split_line_rec.COUNT ' || l_split_line_rec.COUNT);

        IF l_split_line_rec.COUNT = 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'There are no split lines for syncing to PO');
        ELSE
            fnd_file.put_line (
                fnd_file.OUTPUT,
                'PO Number      PO Line Num    PO Item             Order Number   Order Line Num Order Item          Update/Add');
            fnd_file.put_line (
                fnd_file.OUTPUT,
                '------------------------------------------------------------------------------------------------------');

            FOR i IN 1 .. l_split_line_rec.COUNT
            LOOP
                l_interface_header_id   := NULL;
                l_get_po_header_det     := NULL;
                write_log (
                       'l_split_line_rec(i).order_number'
                    || l_split_line_rec (i).order_number);

                OPEN cur_get_po_header_det (l_split_line_rec (i).header_id);

                FETCH cur_get_po_header_det INTO l_get_po_header_det;

                CLOSE cur_get_po_header_det;

                IF l_get_po_header_det.document_num IS NULL
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'No PO found for order number '
                        || l_split_line_rec (i).order_number);
                ELSE
                    -- l_get_ord_line_det := NULL;
                    l_get_ord_line_det.DELETE;                          -- ();

                    OPEN cur_get_ord_line_det (
                        l_split_line_rec (i).header_id,
                        l_get_po_header_det.vendor_id,
                        l_get_po_header_det.ship_to_organization_id);

                    FETCH cur_get_ord_line_det
                        BULK COLLECT INTO l_get_ord_line_det;

                    CLOSE cur_get_ord_line_det;

                    write_log (
                        'l_get_ord_line_det.COUNT ' || l_get_ord_line_det.COUNT);

                    FOR j IN 1 .. l_get_ord_line_det.COUNT
                    LOOP
                        l_get_po_line_det   := NULL;

                        OPEN cur_get_po_line_det (
                            l_get_ord_line_det (j).line_id);

                        FETCH cur_get_po_line_det INTO l_get_po_line_det;

                        CLOSE cur_get_po_line_det;

                        write_log (
                               'l_get_po_line_det.quantity'
                            || l_get_po_line_det.quantity
                            || ' l_get_ord_line_det(j).ordered_quantity '
                            || l_get_ord_line_det (j).ordered_quantity);

                        IF     l_get_po_line_det.po_line_id IS NOT NULL
                           AND NVL (l_get_po_line_det.quantity, -9999) <>
                               l_get_ord_line_det (j).ordered_quantity
                        THEN
                            l_resp_appl_id   := fnd_global.resp_appl_id;
                            l_resp_id        := fnd_global.resp_id;
                            l_user_id        := fnd_global.user_id;

                            APPS.fnd_global.APPS_INITIALIZE (l_user_id,
                                                             l_resp_id,
                                                             l_resp_appl_id);
                            APPS.mo_global.init ('PO');

                            SELECT MAX (revision_num)
                              INTO l_get_po_header_det.revision_num
                              FROM po_headers_all
                             WHERE segment1 =
                                   l_get_po_header_det.document_num;

                            write_log (
                                   l_get_po_header_det.document_num
                                || ' '
                                || l_get_po_line_det.line_num
                                || ' '
                                || l_get_ord_line_det (j).ordered_quantity);

                            --Changes done by Ravi on 6-Jul-2016 for INC0301427-- not to calculate the po_list_price during split lines
                            SELECT UNIT_PRICE
                              INTO l_get_ord_line_det (j).unit_price
                              FROM po_lines_all pol, po_headers_all pha
                             WHERE     pha.po_header_id = pol.po_header_id
                                   AND po_line_id =
                                       l_get_po_line_det.po_line_id
                                   AND pha.segment1 =
                                       l_get_po_header_det.document_num
                                   AND pol.line_num =
                                       l_get_po_line_det.line_num;

                            l_result         :=
                                po_change_api1_s.update_po (
                                    x_po_number             =>
                                        l_get_po_header_det.document_num,
                                    x_release_number        => NULL,
                                    x_revision_number       =>
                                        l_get_po_header_det.revision_num,
                                    x_line_number           =>
                                        l_get_po_line_det.line_num,
                                    x_shipment_number       =>
                                        l_get_po_line_det.shipment_num,
                                    new_quantity            =>
                                        l_get_ord_line_det (j).ordered_quantity,
                                    new_price               =>
                                        l_get_ord_line_det (j).unit_price,
                                    new_promised_date       => NULL,
                                    new_need_by_date        => NULL,
                                    launch_approvals_flag   => 'N',         --
                                    update_source           => NULL,
                                    version                 => '1.0',
                                    x_override_date         => NULL,
                                    x_api_errors            => l_api_errors,
                                    p_buyer_name            => NULL,
                                    p_secondary_quantity    => NULL,
                                    p_preferred_grade       => NULL,
                                    p_org_id                =>
                                        l_get_po_header_det.org_id);

                            WRITE_LOG ('After Update PO API ' || l_result);

                            IF l_result <> 1
                            THEN
                                ROLLBACK;
                                fnd_file.put_line (
                                    fnd_file.OUTPUT,
                                       'PO :'
                                    || l_get_po_header_det.document_num
                                    || ' is not updated to sync with the order number :'
                                    || l_split_line_rec (i).order_number
                                    || ' because of errors');

                                FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                                LOOP
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        l_api_errors.MESSAGE_TEXT (i));
                                END LOOP;
                            ELSE
                                PO_APPROVAL (l_get_po_header_det.document_num, l_get_po_header_det.org_id, l_retcode
                                             , l_errbuf);

                                IF l_retcode <> 0 AND l_errbuf IS NOT NULL
                                THEN
                                    write_log (
                                           'Error while approving for PO : '
                                        || l_get_po_header_det.document_num
                                        || ' is '
                                        || l_errbuf);
                                END IF;

                                COMMIT;
                                --  fnd_file.put_line (fnd_file.log, 'Success'||l_get_po_header_det.document_num);
                                --  fnd_file.put_line (fnd_file.log, 'Success1'||l_split_line_rec(i).order_number);
                                fnd_file.put_line (
                                    fnd_file.OUTPUT,
                                       RPAD (
                                           l_get_po_header_det.document_num,
                                           15,
                                           ' ')
                                    || RPAD (l_get_po_line_det.line_num,
                                             15,
                                             ' ')
                                    || RPAD (l_get_po_line_det.segment1,
                                             20,
                                             ' ')
                                    || RPAD (
                                           l_split_line_rec (i).order_number,
                                           15,
                                           ' ')
                                    || RPAD (
                                           l_get_ord_line_det (j).line_number,
                                           15,
                                           ' ')
                                    || RPAD (
                                           l_get_ord_line_det (j).ordered_item,
                                           20,
                                           ' ')
                                    || 'Update');
                            END IF;
                        ELSIF l_get_po_line_det.po_line_id IS NULL
                        THEN
                            MO_GLOBAL.SET_POLICY_CONTEXT (
                                'S',
                                l_get_po_header_det.org_id);


                            IF l_get_po_header_det.document_num <>
                               l_doc_number
                            THEN
                                l_doc_number            :=
                                    l_get_po_header_det.document_num;
                                l_interface_header_id   := NULL;
                                l_interface_header_id   :=
                                    po_headers_interface_s.NEXTVAL;

                                WRITE_LOG (
                                       'interface_header_id  '
                                    || l_interface_header_id);

                                INSERT INTO po.po_headers_interface (
                                                interface_header_id,
                                                --       batch_id,
                                                action,
                                                org_id,
                                                document_type_code,
                                                document_num,
                                                currency_code,
                                                agent_id,
                                                vendor_id,
                                                vendor_site_id,
                                                ship_to_location_id,
                                                bill_to_location_id,
                                                po_header_id)
                                         VALUES (
                                                    l_interface_header_id,
                                                    --  l_batch_id,
                                                    'UPDATE',
                                                    l_get_po_header_det.org_id,
                                                    'STANDARD',
                                                    l_get_po_header_det.document_num,
                                                    l_get_po_header_det.currency_code,
                                                    l_get_po_header_det.agent_id,
                                                    l_get_po_header_det.vendor_id,
                                                    l_get_po_header_det.vendor_site_id,
                                                    l_get_po_header_det.ship_to_location_id,
                                                    l_get_po_header_det.bill_to_location_id,
                                                    l_get_po_header_det.po_header_id);
                            END IF;

                            --Changes done by Ravi on 6-Jul-2016 for INC0301427-- not to calculate the po_list_price during split lines
                            BEGIN
                                SELECT UNIT_PRICE
                                  INTO l_get_ord_line_det (j).unit_price
                                  FROM po_lines_all pol, po_headers_all pha, mtl_system_items_b msib
                                 WHERE     pha.po_header_id =
                                           pol.po_header_id
                                       --AND po_line_id = l_get_po_line_det.po_line_id -- Raja
                                       -- This is for new lines; There is no PO Line id created -- Raja
                                       /*AND pol.attribute5 IN (SELECT split_from_line_id
                                                                FROM apps.oe_order_lines_all
                                             WHERE line_id = l_get_ord_line_det (j).line_id
                                               AND header_id = l_get_ord_line_det (j).header_id
                                            AND ROWNUM = 1)*/
                                       -- Added  MSIB and Rownum=1 condition -- Raja
                                       AND pol.item_id =
                                           msib.inventory_item_id
                                       AND msib.organization_id = 106
                                       AND msib.segment1 =
                                           l_get_ord_line_det (j).ordered_item
                                       AND pha.segment1 =
                                           l_get_po_header_det.document_num
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    l_get_ord_line_det (j).unit_price   :=
                                        NULL;
                                WHEN OTHERS
                                THEN
                                    l_get_ord_line_det (j).unit_price   :=
                                        NULL;
                            END;

                            -- START PRB0041344
                            -- Fetching Intrasit Time using Macau PO Information
                            l_macau_vendor_id          := NULL;
                            l_macau_vendor_site_code   := NULL;
                            l_ship_to_org_id           := NULL;
                            l_macau_exfactory_date     := NULL;
                            l_macau_transit_days       := NULL;
                            l_tq_transit_days          := NULL;
                            lv_promise_date            := NULL;

                            BEGIN
                                SELECT DISTINCT pha.vendor_id, assa.vendor_site_code, ooha.ship_to_org_id,
                                                NVL (plla.attribute5, plla.attribute4) --plla.attribute4
                                  INTO l_macau_vendor_id, l_macau_vendor_site_code, l_ship_to_org_id, l_macau_exfactory_date
                                  FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha, apps.oe_drop_ship_sources odss,
                                       apps.po_headers_all pha, apps.po_lines_all pla, apps.po_line_locations_all plla,
                                       apps.ap_supplier_sites_all assa
                                 WHERE     oola.line_id =
                                           l_get_ord_line_det (j).line_id
                                       AND oola.line_id = odss.line_id
                                       AND oola.header_id = ooha.header_id
                                       AND odss.po_header_id =
                                           pha.po_header_id
                                       AND pha.vendor_site_id =
                                           assa.vendor_site_id
                                       AND pha.po_header_id =
                                           pla.po_header_id
                                       AND pla.po_line_id = plla.po_line_id
                                       AND odss.line_location_id =
                                           plla.line_location_id
                                       AND odss.po_line_id = pla.po_line_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_macau_vendor_id          := NULL;
                                    l_macau_vendor_site_code   := NULL;
                                    l_ship_to_org_id           := NULL;
                            END;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Macau Vendor Id :: '
                                || l_macau_vendor_id
                                || ' Macau Vendor Site Code :: '
                                || l_macau_vendor_site_code
                                || ' Order Ship to Org id :: '
                                || l_ship_to_org_id
                                || ' Macau Exfactory Date :: '
                                || l_macau_exfactory_date);

                            l_macau_transit_days       :=
                                get_transit_time (l_macau_vendor_id,
                                                  l_macau_vendor_site_code,
                                                  l_ship_to_org_id);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Macau Transit Time :: '
                                || l_macau_transit_days);
                            -- End of Fetching Transit days for Macau PO

                            -- Start Fetching Intrasit Time using TQ PO Information
                            l_tq_vendor_id             :=
                                l_get_po_header_det.vendor_id;
                            l_tq_vendor_site_code      := NULL;
                            l_ship_to_org_id           := NULL;

                            BEGIN
                                SELECT DISTINCT ooha.ship_to_org_id
                                  INTO l_ship_to_org_id
                                  FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                                 WHERE     oola.line_id =
                                           l_get_ord_line_det (j).line_id
                                       AND oola.header_id = ooha.header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_tq_vendor_id          := NULL;
                                    l_tq_vendor_site_code   := NULL;
                                    l_ship_to_org_id        := NULL;
                            END;

                            BEGIN
                                SELECT vendor_site_code
                                  INTO l_tq_vendor_site_code
                                  FROM apps.ap_supplier_sites_all
                                 WHERE vendor_site_id =
                                       l_get_po_header_det.vendor_site_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_tq_vendor_site_code   := NULL;
                            END;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'TQ Vendor Id :: '
                                || l_tq_vendor_id
                                || ' TQ Vendor Site Code :: '
                                || l_tq_vendor_site_code
                                || ' TQ Ship to Org id :: '
                                || l_ship_to_org_id);

                            l_tq_transit_days          :=
                                get_transit_time (l_tq_vendor_id,
                                                  l_tq_vendor_site_code,
                                                  l_ship_to_org_id);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'TQ Transit Time :: ' || l_tq_transit_days);

                            lv_promise_date            :=
                                  TO_DATE (l_macau_exfactory_date,
                                           'RRRR/MM/DD HH24:MI:SS')
                                + l_macau_transit_days
                                + l_tq_transit_days;

                            l_get_ord_line_det (j).promise_date   :=
                                lv_promise_date;
                            -- End of Fetching Transit days for TQ PO

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'TQ Promise Date :: '
                                || l_get_ord_line_det (j).promise_date);

                            -- END PRB0041344

                            INSERT INTO po_lines_interface (
                                            action,
                                            interface_line_id,
                                            interface_header_id,
                                            unit_price,
                                            quantity,
                                            --  item_description,
                                            item,
                                            unit_OF_MEASURE,
                                            need_by_date,
                                            line_type_id,
                                            line_attribute_category_lines,
                                            line_attribute5,
                                            -- Start of PRB0041379
                                            line_attribute1,
                                            line_attribute2,
                                            line_attribute3,
                                            line_attribute4,
                                            line_attribute6,
                                            line_attribute7,
                                            line_attribute8,
                                            line_attribute9,
                                            line_attribute10,
                                            line_attribute11,
                                            line_attribute12,
                                            line_attribute13,
                                            line_attribute14,
                                            line_attribute15,
                                            shipment_attribute_category,
                                            shipment_attribute1,
                                            shipment_attribute2,
                                            shipment_attribute3,
                                            shipment_attribute4,
                                            shipment_attribute5,
                                            shipment_attribute6,
                                            shipment_attribute7,
                                            shipment_attribute8,
                                            shipment_attribute9,
                                            shipment_attribute10,
                                            shipment_attribute11,
                                            shipment_attribute12,
                                            shipment_attribute13,
                                            shipment_attribute14,
                                            shipment_attribute15-- End of PRB0041379
                                                                )
                                     VALUES (
                                                'ADD',
                                                po_lines_interface_s.NEXTVAL,
                                                l_interface_header_id,
                                                l_get_ord_line_det (j).unit_price,
                                                l_get_ord_line_det (j).ordered_quantity,
                                                --  l_get_ord_line_det(j).ordered_item,
                                                l_get_ord_line_det (j).ordered_item,
                                                l_get_ord_line_det (j).unit_of_measure,
                                                l_get_ord_line_det (j).promise_date,
                                                1,
                                                'Intercompany PO Copy',
                                                l_get_ord_line_det (j).line_id,
                                                -- Start PRB0041379
                                                l_get_po_header_det.line_attribute1,
                                                l_get_po_header_det.line_attribute2,
                                                l_get_po_header_det.line_attribute3,
                                                l_get_po_header_det.line_attribute4,
                                                l_get_po_header_det.line_attribute6,
                                                l_get_po_header_det.line_attribute7,
                                                l_get_po_header_det.line_attribute8,
                                                l_get_po_header_det.line_attribute9,
                                                l_get_po_header_det.line_attribute10,
                                                l_get_po_header_det.line_attribute11,
                                                l_get_po_header_det.line_attribute12,
                                                l_get_po_header_det.line_attribute13,
                                                l_get_po_header_det.line_attribute14,
                                                l_get_po_header_det.line_attribute15,
                                                l_get_po_header_det.shipment_attribute_category,
                                                l_get_po_header_det.shipment_attribute1,
                                                l_get_po_header_det.shipment_attribute2,
                                                l_get_po_header_det.shipment_attribute3,
                                                l_get_po_header_det.shipment_attribute4,
                                                l_get_po_header_det.shipment_attribute5,
                                                l_get_po_header_det.shipment_attribute6,
                                                l_get_po_header_det.shipment_attribute7,
                                                l_get_po_header_det.shipment_attribute8,
                                                l_get_po_header_det.shipment_attribute9,
                                                l_get_po_header_det.shipment_attribute10,
                                                l_get_po_header_det.shipment_attribute11,
                                                l_get_po_header_det.shipment_attribute12,
                                                l_get_po_header_det.shipment_attribute13,
                                                l_get_po_header_det.shipment_attribute14,
                                                l_get_po_header_det.shipment_attribute15);

                            -- Start PRB0041379

                            COMMIT;
                        END IF;
                    END LOOP;

                    IF l_interface_header_id IS NOT NULL
                    THEN
                        APPS.PO_PDOI_PVT.start_process (
                            p_api_version                  => 1.0,
                            p_init_msg_list                => FND_API.G_TRUE,
                            p_validation_level             => NULL,
                            p_commit                       => FND_API.G_FALSE,
                            x_return_status                => v_return_status,
                            p_gather_intf_tbl_stat         => 'N',
                            p_calling_module               => NULL,
                            p_selected_batch_id            => NULL,
                            p_batch_size                   => NULL,
                            p_buyer_id                     => NULL,
                            p_document_type                => 'STANDARD',
                            p_document_subtype             => NULL,
                            p_create_items                 => 'N',
                            p_create_sourcing_rules_flag   => 'N',
                            p_rel_gen_method               => NULL,
                            p_sourcing_level               => NULL,
                            p_sourcing_inv_org_id          => NULL,
                            p_approved_status              => 'APPROVED',
                            p_process_code                 => NULL,
                            p_interface_header_id          =>
                                l_interface_header_id,
                            p_org_id                       =>
                                l_get_po_header_det.org_id,
                            p_ga_flag                      => NULL,
                            p_submit_dft_flag              => 'N',
                            p_role                         => 'BUYER',
                            p_catalog_to_expire            => NULL,
                            p_err_lines_tolerance          => NULL,
                            p_clm_flag                     => NULL, --CLM PDOI Project
                            x_processed_lines_count        =>
                                v_processed_lines_count,
                            x_rejected_lines_count         =>
                                v_rejected_lines_count,
                            x_err_tolerance_exceeded       =>
                                v_err_tolerance_exceeded);


                        IF (v_return_status = FND_API.g_ret_sts_success)
                        THEN
                            COMMIT;
                            PO_APPROVAL (l_get_po_header_det.document_num, l_get_po_header_det.org_id, l_retcode
                                         , l_errbuf);

                            OPEN cur_report_add (l_interface_header_id);

                            FETCH cur_report_add
                                BULK COLLECT INTO l_report_add;

                            CLOSE cur_report_add;

                            IF l_report_add.COUNT = 0
                            THEN
                                fnd_file.put_line (fnd_file.OUTPUT,
                                                   'No New Lines are added');
                            ELSE
                                FOR k IN 1 .. l_report_add.COUNT
                                LOOP
                                    fnd_file.put_line (
                                        fnd_file.OUTPUT,
                                           RPAD (l_report_add (k).segment1,
                                                 15,
                                                 ' ')
                                        || RPAD (l_report_add (k).line_num,
                                                 15,
                                                 ' ')
                                        || RPAD (l_report_add (k).item,
                                                 20,
                                                 ' ')
                                        || RPAD (
                                               l_report_add (k).order_number,
                                               15,
                                               ' ')
                                        || RPAD (
                                               l_report_add (k).line_number,
                                               15,
                                               ' ')
                                        || RPAD (
                                               l_report_add (k).ordered_item,
                                               20,
                                               ' ')
                                        || 'Add');
                                END LOOP;
                            END IF;
                        ELSE
                            ROLLBACK;
                            fnd_file.put_line (
                                fnd_file.OUTPUT,
                                   v_rejected_lines_count
                                || ' lines are not added to PO :'
                                || l_get_po_header_det.document_num
                                || ' to sync with the order number :'
                                || l_split_line_rec (i).order_number
                                || ' because of errors, please check interface header id'
                                || l_interface_header_id
                                || ' in interface tables');
                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                   'Error while updating PO '
                                || l_get_po_header_det.document_num);
                        END IF;
                    END IF;
                END IF;
            END LOOP;
        END IF;
    END;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : mai_pvt
    -- Decription                : Main Procedure for preocessing all the open purchase orders
    --
    -- Parameters
    -- p_inv_org_id  INPUT
    -- Modification History
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    21-APR-2015    V1.0           Initial Version
    -- BT Tech Team  10-Jun-2015    V1.1     Orig is TRUNC(ph.last_update_date) = TRUNC(SYSDATE - 1)
    -- BT Tech Team  10-Jul-2015    V1.2     Defect 2740 and 2707
    -- BT Tech Team  15-Sep-2015    V1.3     CR# 104
    -----------------------------------------------------------------------------------
    PROCEDURE MAIN_PVT (ERRBUF OUT VARCHAR2, RETCODE OUT VARCHAR2, P_RUN_TYPE IN NUMBER, --Change from al list of strings to a list of constants
                                                                                         P_INV_ORG_ID IN VARCHAR2, P_PO_NUMBER IN VARCHAR2, P_AS_OF_DATE IN NUMBER
                        , P_RUN_MODE IN VARCHAR2) --Lookup'R'='Report', 'E'='Execute'
    IS                                  --Constants for the Run Type parameter
    BEGIN
        write_log ('Main - Enter');
        write_log ('Run type : ' || P_RUN_TYPE);

        IF p_run_type = piRunTypeISOReqDt
        THEN
            IF p_run_mode = 'R'
            THEN
                PO_ISO_DATE_MISMATCH_RPT (ERRBUF, RETCODE, P_INV_ORG_ID, --IR Destination Org -REQ
                                          P_PO_NUMBER, P_AS_OF_DATE);
            ELSE
                UPDATE_IR_REQUEST_DATE (ERRBUF, RETCODE, P_INV_ORG_ID, --IR Destination Org -REQ
                                        P_PO_NUMBER, P_AS_OF_DATE);
            END IF;
        ELSIF p_run_type = piRunTypeJapanTQ
        THEN
            UPDATE_JP_TQ_PO_PRICE (ERRBUF, RETCODE, P_INV_ORG_ID,
                                   P_PO_NUMBER, P_AS_OF_DATE);
        ELSIF p_run_type = piRunTypeTQSplitSync
        THEN
            TQ_SPLIT_LINE_SYNC (ERRBUF, RETCODE, P_INV_ORG_ID,
                                P_PO_NUMBER, P_AS_OF_DATE);
        ELSIF p_run_type = piRunUpdateRegASNDate
        THEN
            UPDATE_REGIONAL_ASN_DATE (ERRBUF, RETCODE, P_INV_ORG_ID,
                                      P_PO_NUMBER, P_AS_OF_DATE);
        END IF;

        write_log ('Main - Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    := SQLERRM;
            write_log (gv_package_name || 'Main: ' || errbuf);
    END;

    /*----------------------------------------------------------
    Main entry funtion for legacy call

    This is the main procedure that supports the existinc concurrent request used for the automated processes

    p_run_type   -- Which process to run
    p_inv_org_id -- Inventory Org Id to check
    p_po_number  -- Optional PO number to process
    p_as_of_date -- Limit on number of days to look back (for performance reasons)

    -------------------------------------------------------------*/

    PROCEDURE MAIN (errbuf            OUT VARCHAR2,
                    retcode           OUT VARCHAR2,
                    p_run_type     IN     VARCHAR2,
                    p_inv_org_id   IN     VARCHAR2,
                    p_po_number    IN     VARCHAR2,
                    p_as_of_date   IN     NUMBER)
    IS
        pn_run_type   NUMBER;
    BEGIN
        --Translate legacy run type description to constant value to support backward compatability with older processes
        BEGIN
            SELECT fv.flex_value
              INTO pn_run_type
              FROM fnd_flex_value_sets fvs, fnd_flex_values fv, fnd_flex_values_tl fvt
             WHERE     fv.flex_value_set_id = fvs.flex_value_set_id
                   AND fv.flex_value_id = fvt.flex_value_id
                   AND fvs.flex_value_set_name = pRunTypeLookupNmae
                   AND fvt.language = 'US'
                   AND fvt.description = p_run_type;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                retcode   := 2;
                errbuf    := 'Invalid run type provided';
                RETURN;
        END;

        --Call the local function to do the actual procesing
        MAIN_PVT (ERRBUF, RETCODE, pn_run_type,
                  P_INV_ORG_ID, P_PO_NUMBER, P_AS_OF_DATE,
                  'E');         --Legacy has no run mode so default to execute
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    := SQLERRM;
    END;

    /*----------------------------------------------------------
    Main entry funtion for new concurrent request

   This is the process added for the new report / execute mode option for PO XFDate to ISO date update
   --Renamed from Main as there was a conflicting procedure signature

   p_inv_org_id -- Inventory Org Id to check
   p_po_number  -- Optional PO number to process
   p_run_mode   -- Report oe Execute mode (specifically for the PO Promised Date to ISO request date update

   -------------------------------------------------------------*/

    PROCEDURE RUN_ISO_REQ_UPDATE (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_inv_org_id IN NUMBER
                                  , p_po_number IN VARCHAR2, p_run_mode IN VARCHAR2, P_as_of_date IN NUMBER)
    IS
    BEGIN
        --Call local procedure to execute process
        MAIN_PVT (ERRBUF, RETCODE, piRunTypeISOReqDt,
                  P_INV_ORG_ID, P_PO_NUMBER, P_as_of_date, --New mode does not have run days so default to 356 - 1 year back
                  P_RUN_MODE);
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    := SQLERRM;
    END;



    PROCEDURE CALL_PROCESS_ORDER (p_org_id IN NUMBER, p_header_rec IN oe_order_pub.header_rec_type:= oe_order_pub.g_miss_header_rec, p_header_price_adj_tbl IN oe_order_pub.header_adj_tbl_type:= oe_order_pub.g_miss_header_adj_tbl, p_line_tbl IN oe_order_pub.line_tbl_type:= oe_order_pub.g_miss_line_tbl, p_line_price_adj_tbl IN oe_order_pub.line_adj_tbl_type:= oe_order_pub.g_miss_line_adj_tbl, x_header_rec OUT oe_order_pub.header_rec_type, x_header_adj_tbl OUT oe_order_pub.header_adj_tbl_type, x_line_tbl OUT oe_order_pub.line_tbl_type, x_line_adj_tbl OUT oe_order_pub.line_adj_tbl_type, x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2, p_debug_location IN NUMBER:= do_debug_utils.debug_table
                                  , p_do_commit IN NUMBER:= 1)
    IS
        l_debug_location           NUMBER
            := NVL (p_debug_location, do_debug_utils.debug_table);
        l_message                  VARCHAR2 (30000);
        l_next_msg                 NUMBER;
        l_ont_debug_level          NUMBER := NULL;
        -- API Variables
        x_msg_data                 VARCHAR2 (30000);
        x_msg_count                NUMBER;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
    BEGIN
        BEGIN
            write_log ('CALL_PROCESS_ORDER' || 'Begin CALL_PROCESS_ORDER');


            l_ont_debug_level   := oe_debug_pub.g_debug_level;
            oe_msg_pub.Initialize;

            IF NVL (l_ont_debug_level, 0) = 100
            THEN
                oe_debug_pub.setdebuglevel (1);
            END IF;

            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                -- BEGIN - 03/08/2009 - KWG -- Oracle 12 Upgrade --
                p_org_id                   => p_org_id,
                -- END - 03/08/2009 - KWG -- Oracle 12 Upgrade --
                p_init_msg_list            => fnd_api.g_true,
                p_header_rec               => p_header_rec,
                p_header_adj_tbl           => p_header_price_adj_tbl,
                p_line_tbl                 => p_line_tbl,
                p_line_adj_tbl             => p_line_price_adj_tbl,
                x_return_status            => x_return_status,
                x_msg_data                 => x_msg_data,
                x_msg_count                => x_msg_count,
                x_header_rec               => x_header_rec,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => x_line_tbl,
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
                x_action_request_tbl       => x_action_request_tbl);
            write_log (
                   'After call to PROCESS_ORDER.'
                || '  Return Status: '
                || x_return_status
                || '  Message Count: '
                || x_msg_count);

            IF x_msg_count > 0
            THEN
                x_error_text   :=
                    'The following errors were encountered:' || CHR (13);

                FOR i IN 1 .. x_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_message
                                    , p_msg_index_out => l_next_msg);
                    --x_error_text := x_error_text || '  ' || l_message || CHR (13);
                    x_error_text   := l_message || CHR (13);
                END LOOP;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_return_status   := fnd_api.g_ret_sts_unexp_error;
                x_error_text      :=
                    SUBSTR (
                           NVL (x_error_text, ' ')
                        || 'An unknown exception was encountered.  The exception was: '
                        || SQLERRM,
                        1,
                        4000);
        END;

        IF NVL (l_ont_debug_level, 0) = 100
        THEN
            oe_debug_pub.setdebuglevel (l_ont_debug_level);
        END IF;

        IF NVL (p_do_commit, 1) = 1
        THEN
            COMMIT;
        END IF;

        write_log (
               'CALL_PROCESS_ORDER,  Done CALL_PROCESS_ORDER.'
            || '  Return Status: '
            || x_return_status
            || '  Error Text: '
            || NVL (x_error_text, '--none--'));
    END;
END XXDO_SO_REQ_DATE_UPDATE_PKG;
/
