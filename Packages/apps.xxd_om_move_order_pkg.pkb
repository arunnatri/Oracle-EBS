--
-- XXD_OM_MOVE_ORDER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OM_MOVE_ORDER_PKG"
/***************************************************************************************
* Program Name : XXD_OM_MOVE_ORDER_PKG                                                 *
* Language     : PL/SQL                                                                *
* Description  : Package to cancel the existing order , move the sales order           *
*                                                                                      *
* History      :                                                                       *
*                                                                                      *
* WHO          :       WHAT      Desc                                    WHEN          *
* -------------- ----------------------------------------------------------------------*
* Kishan Reddy         1.0       Initial Version                         24-FEB-2023   *
* -------------------------------------------------------------------------------------*/
AS
    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id            CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id        CONSTANT NUMBER := fnd_global.conc_request_id;
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;
    gn_limit_rec         CONSTANT NUMBER := 100;
    gn_commit_rows       CONSTANT NUMBER := 1000;
    gv_delimeter                  VARCHAR2 (1) := ',';
    gv_def_mail_recips            do_mail_utils.tbl_recips;
    gn_batch_id                   NUMBER;

    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in WRITE_LOG Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;


    --
    /***********************************************************************************************
    **************************** Function to get email ids for error report ************************
    ************************************************************************************************/

    FUNCTION get_email_ids (pv_lookup_type VARCHAR2, pv_inst_name VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR recips_cur IS
            SELECT xx.email_id
              FROM (SELECT flv.meaning email_id
                      FROM fnd_lookup_values flv
                     WHERE     1 = 1
                           AND flv.lookup_type = pv_lookup_type
                           AND flv.enabled_flag = 'Y'
                           AND flv.language = USERENV ('LANG')
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))) xx
             WHERE xx.email_id IS NOT NULL;

        CURSOR submitted_by_cur IS
            SELECT (fu.email_address) email_id
              FROM fnd_user fu
             WHERE     1 = 1
                   AND fu.user_id = gn_user_id
                   AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                           AND TRUNC (
                                                   NVL (fu.end_date, SYSDATE));
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Lookup Type:' || pv_lookup_type);
        v_def_mail_recips.DELETE;

        IF pv_inst_name = 'PRODUCTION'
        THEN
            FOR recips_rec IN recips_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    recips_rec.email_id;
            END LOOP;

            -- FND_FILE.PUT_LINE(FND_FILE.LOG,'Email Recipents:'||v_def_mail_recips);

            RETURN v_def_mail_recips;
        ELSE
            FOR submitted_by_rec IN submitted_by_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    submitted_by_rec.email_id;
            END LOOP;

            --            FND_FILE.PUT_LINE(FND_FILE.LOG,'Email Recipents ' || ':' || v_def_mail_recips);

            RETURN v_def_mail_recips;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_def_mail_recips (1)   := '';
            fnd_file.put_line (fnd_file.LOG,
                               'Failed to fetch email receipents');
            RETURN v_def_mail_recips;
    END get_email_ids;

    PROCEDURE log_message (p_message_in IN VARCHAR2)
    IS
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG, p_message_in || '.');
    END log_message;

    -- -------------------------------------------------
    -- procedure generate_xml
    -- procedure to generate xml from the data in a clob
    -- field
    -- -------------------------------------------------
    PROCEDURE generate_xml (p_ref_cur IN SYS_REFCURSOR, p_row_tag IN VARCHAR2, p_row_set_tag IN VARCHAR2
                            , x_xml_data OUT NOCOPY CLOB)
    IS
        l_ctx   DBMS_XMLGEN.ctxhandle;
    BEGIN
        -- create a new context with the sql query
        l_ctx        := DBMS_XMLGEN.newcontext (p_ref_cur);

        -- add tag names for rows and row sets
        DBMS_XMLGEN.setrowsettag (l_ctx, p_row_tag);
        DBMS_XMLGEN.setrowtag (l_ctx, p_row_set_tag);

        -- generate xml data
        x_xml_data   := DBMS_XMLGEN.getxml (l_ctx);

        DBMS_XMLGEN.closecontext (l_ctx);
    EXCEPTION
        WHEN OTHERS
        THEN
            log_message ('Error generating XML ');
            log_message (SQLERRM);
    END generate_xml;

    -- ----------------------------------------------
    -- procedure print_xml_data
    -- procedure to print xml data
    -- ----------------------------------------------
    PROCEDURE print_xml_data (p_xml_data IN CLOB)
    IS
        l_amount   NUMBER;
        l_offset   NUMBER;
        l_length   NUMBER;
        l_data     VARCHAR2 (32767);
    BEGIN
        l_length   := NVL (DBMS_LOB.getlength (p_xml_data), 0);
        l_offset   := 1;
        l_amount   := 16000;

        LOOP
            EXIT WHEN l_length <= 0;

            DBMS_LOB.read (p_xml_data, l_amount, l_offset,
                           l_data);

            apps.fnd_file.put (apps.fnd_file.output, l_data);

            l_length   := l_length - l_amount;
            l_offset   := l_offset + l_amount;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_message ('Unexpected Error printing XML Output ');
            log_message (SQLERRM);
    END print_xml_data;

    -------------------------------------------------------------------------------------
    -- procedure: xx_sample_proc
    -------------------------------------------------------------------------------------
    PROCEDURE generate_report (p_errbuf          OUT VARCHAR2,
                               p_retcode         OUT NUMBER,
                               p_request_id   IN     NUMBER)
    IS
        ----------------------------------------------------------------------------------
        -- local variables
        ----------------------------------------------------------------------------------

        v_due_date       DATE;
        lv_date_to       DATE;
        lv_xml_data      CLOB;
        l_data_qry_cur   SYS_REFCURSOR;
        l_row_tag        VARCHAR2 (4000);
        l_row_set_tag    VARCHAR2 (4000);
        l_task_from      VARCHAR2 (3);
        l_task_to        VARCHAR2 (3);
    BEGIN
        l_data_qry_cur   := NULL;

        --------------------------------------------------------------------------------------------------------------
        -- Data Query
        ---------------------------------------------------------------------------------------------------------------
        OPEN l_data_qry_cur FOR
            'SELECT  source_ou
                                ,source_customer
                                ,source_order_number
                                ,source_order_cust_po_number
                                ,source_order_request_date
                                ,(SELECT location FROM hz_cust_site_uses_all
                                   WHERE site_use_id   = source_order_ship_to_location
                                     AND site_use_code = ''SHIP_TO''
                                     AND rownum = 1 )source_ship_to_location
                                ,(SELECT location FROM hz_cust_site_uses_all
                                   WHERE site_use_id   = source_order_bill_to_location
                                     AND site_use_code = ''BILL_TO''
                                     AND rownum = 1 ) source_bill_to_location
                                ,source_order_ordered_date
                                ,source_order_creation_date
                                ,source_order_cancel_date
                                ,source_order_type
                                ,(SELECT organization_code 
                                    FROM org_organization_definitions
                                   WHERE organization_id = source_order_ship_from_warehouse  )source_warehouse
                                ,(SELECT jrr.resource_name 
                                    FROM jtf_rs_salesreps               jrs,
                                         jtf_rs_resource_extns_tl       jrr
                                   WHERE 1=1
                                     AND jrs.resource_id   = jrr.resource_id(+)
                                     AND jrr.language(+) = ''US''
                                     AND jrs.salesrep_id = source_order_sales_rep
                                     AND ROWNUM=1) source_sales_rep
                                ,(SELECT name 
                                    FROM qp_list_headers 
                                   WHERE list_header_id = source_order_price_list
                                     AND ROWNUM = 1 ) source_price_list
                                ,source_order_line_tax_rate
                                ,source_order_line_tax_amount
                                ,source_order_line_ordered_item
                                ,source_line_num
                                ,source_order_line_ordered_quantity
                                ,source_order_line_latest_acceptable_date
                                ,source_order_line_creation_date
                                ,source_order_line_schedule_shipped_date
                                ,source_order_line_flow_status_code
                                ,target_ou
                                ,target_customer
                                ,target_order_number
                                ,target_order_cust_po_number
                                ,target_order_request_date
                                ,(SELECT location FROM hz_cust_site_uses_all
                                   WHERE site_use_id   = target_order_ship_to_location
                                     AND site_use_code = ''SHIP_TO''
                                     AND rownum = 1 ) target_ship_to_location
                                ,(SELECT location FROM hz_cust_site_uses_all
                                   WHERE site_use_id   = target_order_bill_to_location
                                     AND site_use_code = ''BILL_TO''
                                     AND rownum = 1 ) target_bill_to_location
                                ,target_order_ordered_date
                                ,target_order_creation_date
                                ,target_order_cancel_date
                                ,target_order_type
                                ,(SELECT organization_code 
                                    FROM org_organization_definitions
                                   WHERE organization_id = target_order_ship_from_warehouse  ) target_warehouse
                                ,(SELECT jrr.resource_name 
                                    FROM jtf_rs_salesreps               jrs,
                                         jtf_rs_resource_extns_tl       jrr
                                   WHERE 1=1
                                     AND jrs.resource_id   = jrr.resource_id(+)
                                     AND jrr.language(+) = ''US''
                                     AND jrs.salesrep_id = target_order_sales_rep
                                     AND ROWNUM=1) target_sales_rep
                                ,(SELECT name 
                                    FROM qp_list_headers 
                                   WHERE list_header_id = target_order_price_list
                                     AND ROWNUM = 1 ) target_price_list
                                ,target_order_line_tax_rate
                                ,target_order_line_tax_amount
                                ,target_order_line_ordered_item
                                ,target_line_num
                                ,target_order_line_ordered_quantity
                                ,target_order_line_latest_acceptable_date
                                ,target_order_line_creation_date
                                ,target_order_line_schedule_shipped_date
                                ,target_order_line_flow_status_code
                                ,error_message
                                ,status
                            FROM xxd_ou_alignment_lines_t
                           WHERE request_id = :p_request_id
                            order by source_order_number, source_line_num'
            USING p_request_id;


        l_row_tag        := 'XXD_OM_OU_ALIGNMENT';         --> Main Group Name
        l_row_set_tag    := 'XXD_ORDER_DETAILS';          --> Inner Group Name

        log_message ('Call generate_xml procedure');

        generate_xml (l_data_qry_cur, l_row_tag, l_row_set_tag,
                      lv_xml_data);

        log_message ('Call print_xml_data procedure');

        print_xml_data (lv_xml_data);

        log_message ('End of Processing');

        p_errbuf         := 'Program has completed successfully';
        p_retcode        := 0;
    -------------------------------------------------------------------
    EXCEPTION
        WHEN OTHERS
        THEN
            log_message ('Error in generate report ' || SQLERRM);
            p_errbuf    := SUBSTR (LTRIM (SQLERRM), 1, 254);
            p_retcode   := 2;
    END generate_report;

    --
    -- generate output
    /*
    PROCEDURE generate_report
    IS

    CURSOR lc_output
        IS
     SELECT  source_ou
            ,source_customer
            ,source_order_number
            ,source_order_cust_po_number
            ,source_order_request_date
            ,(SELECT location FROM hz_cust_site_uses_all
               WHERE site_use_id   = source_order_ship_to_location
                 AND site_use_code = 'SHIP_TO'
                 AND rownum = 1 )source_ship_to_location
            ,(SELECT location FROM hz_cust_site_uses_all
               WHERE site_use_id   = source_order_bill_to_location
                 AND site_use_code = 'BILL_TO'
                 AND rownum = 1 ) source_bill_to_location
            ,source_order_ordered_date
            ,source_order_creation_date
            ,source_order_cancel_date
            ,source_order_type
            ,(SELECT organization_code
                FROM org_organization_definitions
               WHERE organization_id = source_order_ship_from_warehouse  )source_warehouse
            ,(SELECT jrr.resource_name
                FROM jtf_rs_salesreps               jrs,
                     jtf_rs_resource_extns_tl       jrr
               WHERE 1=1
                 AND jrs.resource_id   = jrr.resource_id(+)
                 AND jrr.language(+) = 'US'
                 AND jrs.salesrep_id = source_order_sales_rep
                 AND ROWNUM=1) source_sales_rep
            ,(SELECT name
                FROM qp_list_headers
               WHERE list_header_id = source_order_price_list
                 AND ROWNUM = 1 ) source_price_list
            ,source_order_line_tax_rate
            ,source_order_line_tax_amount
            ,source_order_line_ordered_item
            ,source_line_num
            ,source_order_line_ordered_quantity
            ,source_order_line_latest_acceptable_date
            ,source_order_line_creation_date
            ,source_order_line_schedule_shipped_date
            ,source_order_line_flow_status_code
            ,target_ou
            ,target_customer
            ,target_order_number
            ,target_order_cust_po_number
            ,target_order_request_date
            ,(SELECT location FROM hz_cust_site_uses_all
               WHERE site_use_id   = target_order_ship_to_location
                 AND site_use_code = 'SHIP_TO'
                 AND rownum = 1 ) target_ship_to_location
            ,(SELECT location FROM hz_cust_site_uses_all
               WHERE site_use_id   = target_order_bill_to_location
                 AND site_use_code = 'BILL_TO'
                 AND rownum = 1 ) target_bill_to_location
            ,target_order_ordered_date
            ,target_order_creation_date
            ,target_order_cancel_date
            ,target_order_type
            ,(SELECT organization_code
                FROM org_organization_definitions
               WHERE organization_id = target_order_ship_from_warehouse  ) target_warehouse
            ,(SELECT jrr.resource_name
                FROM jtf_rs_salesreps               jrs,
                     jtf_rs_resource_extns_tl       jrr
               WHERE 1=1
                 AND jrs.resource_id   = jrr.resource_id(+)
                 AND jrr.language(+) = 'US'
                 AND jrs.salesrep_id = target_order_sales_rep
                 AND ROWNUM=1) target_sales_rep
            ,(SELECT name
                FROM qp_list_headers
               WHERE list_header_id = target_order_price_list
                 AND ROWNUM = 1 ) target_price_list
            ,target_order_line_tax_rate
            ,target_order_line_tax_amount
            ,target_order_line_ordered_item
            ,target_line_num
            ,target_order_line_ordered_quantity
            ,target_order_line_latest_acceptable_date
            ,target_order_line_creation_date
            ,target_order_line_schedule_shipped_date
            ,target_order_line_flow_status_code
            ,error_message
            ,status
        FROM xxd_ou_alignment_lines_t
       WHERE request_id = 363760311
         AND status ='COMPLETED'
        order by source_order_number, source_line_num;
    BEGIN
     fnd_file.put_line(fnd_file.log, 'Started');
     null;
    EXCEPTION
    WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.log, 'Error occured while generating the report ' || SQLERRM);
    END generate_report;
    */
    PROCEDURE insert_line_tbl
    IS
        CURSOR lc_order_data IS
            SELECT stg.original_ou
                       source_ou,
                   stg.source_org_id,
                   stg.source_customer,
                   ooha.cust_po_number,
                   ooha.order_number,
                   ooha.request_date,
                   ooha.ship_to_org_id,
                   ooha.invoice_to_org_id,
                   ooha.ordered_date,
                   ooha.creation_date,
                   ooha.attribute1
                       cancelled_date,
                   (SELECT name
                      FROM oe_transaction_types_tl otl
                     WHERE     otl.language = USERENV ('LANG')
                           AND otl.transaction_type_id = ooha.order_type_id)
                       source_order_type,
                   ooha.order_type_id,
                   ooha.ship_from_org_id,
                   ooha.salesrep_id,
                   ooha.price_list_id,
                   oola.tax_value,
                   DECODE (
                       oola.tax_value,
                       0, 0,
                       ROUND (
                           (oola.tax_value / (oola.ordered_quantity * oola.unit_selling_price)),
                           2))
                       tax_rate,
                   oola.line_id,
                   oola.line_number,
                   oola.ordered_item,
                   oola.creation_date
                       line_creation_date,
                   oola.ordered_quantity,
                   oola.latest_acceptable_date,
                   oola.schedule_ship_date,
                   oola.flow_status_code,
                   stg.error_message,
                   stg.status
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, xxd_ou_alignment_inbound_t stg
             WHERE     1 = 1
                   AND ooha.header_id = oola.header_id
                   AND ooha.order_number = stg.source_order_number
                   AND stg.request_id = gn_request_id
                   AND ooha.open_flag = 'Y'
                   AND oola.cancelled_flag = 'N'
                   AND TRUNC (oola.request_date) >=
                       stg.source_order_request_date_from
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     wdd.source_header_id = ooha.header_id
                                   AND wdd.source_line_id = oola.line_id
                                   AND wdd.released_status IN ('S', 'Y', 'C'));

        --
        ln_batch_id   NUMBER;
    BEGIN
        SELECT xxd_ou_alignment_batch_seq.NEXTVAL INTO ln_batch_id FROM DUAL;

        FOR i IN lc_order_data
        LOOP
            BEGIN
                INSERT INTO XXD_OU_ALIGNMENT_LINES_T (
                                batch_id,
                                source_ou,
                                source_org_id,
                                source_customer,
                                source_order_number,
                                source_order_cust_po_number,
                                source_order_request_date,
                                source_order_ship_to_location,
                                source_order_bill_to_location,
                                source_order_ordered_date,
                                source_order_creation_date,
                                source_order_cancel_date,
                                source_order_type,
                                source_order_ship_from_warehouse,
                                source_order_sales_rep,
                                source_order_price_list,
                                source_order_line_tax_rate,
                                source_order_line_tax_amount,
                                source_line_id,
                                source_line_num,
                                source_order_line_ordered_item,
                                source_order_line_ordered_quantity,
                                source_order_line_latest_acceptable_date,
                                source_order_line_creation_date,
                                source_order_line_schedule_shipped_date,
                                source_order_line_flow_status_code,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                request_id,
                                error_message,
                                status)
                     VALUES (ln_batch_id, i.source_ou, i.source_org_id,
                             i.source_customer, i.order_number, i.cust_po_number, i.request_date, i.ship_to_org_id, i.invoice_to_org_id, i.ordered_date, i.creation_date, i.cancelled_date, i.source_order_type, i.ship_from_org_id, i.salesrep_id, i.price_list_id, i.tax_rate, i.tax_value, i.line_id, i.line_number, i.ordered_item, i.ordered_quantity, i.latest_acceptable_date, i.line_creation_date, i.schedule_ship_date, i.flow_status_code, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                             , gn_request_id, i.error_message, i.status);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error occured while inserting custom line data of bulk order'
                        || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error occured while inserting into line table ' || SQLERRM);
    END insert_line_tbl;

    PROCEDURE create_new_bulk_order
    IS
        l_header_rec               OE_ORDER_PUB.Header_Rec_Type;
        l_header_rec_out           OE_ORDER_PUB.Header_Rec_Type;
        l_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type;
        l_line_rec                 OE_ORDER_PUB.Line_Rec_Type;
        l_line_rec1                OE_ORDER_PUB.Line_Rec_Type;
        l_action_request_tbl       OE_ORDER_PUB.Request_Tbl_Type;
        l_header_adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type;
        l_line_adj_tbl             OE_ORDER_PUB.line_adj_tbl_Type;
        l_header_scr_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        l_line_scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        l_request_rec              OE_ORDER_PUB.Request_Rec_Type;
        l_return_status            VARCHAR2 (1000);
        l_return_status1           VARCHAR2 (1000);
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (1000);
        p_api_version_number       NUMBER := 1.0;
        p_init_msg_list            VARCHAR2 (10) := FND_API.G_FALSE;
        p_return_values            VARCHAR2 (10) := FND_API.G_FALSE;
        p_action_commit            VARCHAR2 (10) := FND_API.G_FALSE;
        x_return_status            VARCHAR2 (1);
        x_msg_count                NUMBER;
        x_msg_data                 VARCHAR2 (100);
        x_header_val_rec           OE_ORDER_PUB.Header_Val_Rec_Type;
        x_Header_Adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type;
        x_Header_Adj_val_tbl       OE_ORDER_PUB.Header_Adj_Val_Tbl_Type;
        x_Header_price_Att_tbl     OE_ORDER_PUB.Header_Price_Att_Tbl_Type;
        x_Header_Adj_Att_tbl       OE_ORDER_PUB.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl     OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl       OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl   OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type;
        x_line_val_tbl             OE_ORDER_PUB.Line_Val_Tbl_Type;
        x_Line_Adj_tbl             OE_ORDER_PUB.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl         OE_ORDER_PUB.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl       OE_ORDER_PUB.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl         OE_ORDER_PUB.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl       OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        x_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type;
        x_Line_Scredit_val_tbl     OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl           OE_ORDER_PUB.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl       OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type;
        x_action_request_tbl       OE_ORDER_PUB.Request_Tbl_Type;
        X_DEBUG_FILE               VARCHAR2 (100);
        l_line_tbl_index           NUMBER;
        l_msg_index_out            NUMBER (10);
        l_split_qty                NUMBER;

        ln_resp_id                 NUMBER;
        ln_resp_appl_id            NUMBER;

        CURSOR CSR_HEADERS IS
            SELECT DISTINCT
                   ooha.org_id,
                   stg.target_org_id,
                   stg.original_ou
                       source_ou,
                   ooha.header_id,
                   ooha.order_number,
                   (SELECT account_number
                      FROM hz_cust_accounts
                     WHERE cust_account_id = ooha.sold_to_org_id)
                       source_cust_account,
                   (SELECT name
                      FROM oe_transaction_types_tl otl
                     WHERE     otl.language = USERENV ('LANG')
                           AND otl.transaction_type_id = ooha.order_type_id)
                       source_order_type,
                   stg.target_customer
                       target_customer_number,
                   (SELECT account_name
                      FROM hz_cust_accounts
                     WHERE account_number = stg.target_customer)
                       target_customer_name,
                   --  0 order_source_id,--harcoded to 0, instead of 2 Copy
                   ooha.order_source_id,    --harcoded to 0, instead of 2 Copy
                   ooha.order_number || '-' || ooha.header_id
                       orig_sys_document_ref,
                   ooha.ordered_date,
                   get_target_order_type (ooha.org_id,
                                          stg.target_org_id,
                                          ooha.order_type_id)
                       target_order_type_id,
                   ooha.order_type_id,
                   --   transactional_curr_code,
                   ooha.cust_po_number
                       customer_po_number,
                   ooha.ship_from_org_id,
                   (SELECT cust_account_id
                      FROM hz_cust_accounts
                     WHERE account_number = stg.target_customer)
                       target_sold_to_org_id,
                   ooha.ship_to_org_id,
                   ooha.invoice_to_org_id,
                   get_target_ship_to (ooha.ship_to_org_id,
                                       stg.target_customer)
                       target_ship_to_org_id,
                   get_target_bill_to (ooha.invoice_to_org_id,
                                       stg.target_customer)
                       target_bill_to_org_id,
                   deliver_to_org_id,
                   ooha.sold_to_org_id
                       customer_id,
                   ooha.shipping_method_code,
                   ooha.booked_flag,
                   ooha.attribute1,
                   ooha.attribute2,
                   ooha.attribute3,
                   ooha.attribute4,
                   ooha.attribute5,
                   ooha.attribute6,
                   ooha.attribute7,
                   ooha.attribute8,
                   ooha.attribute9,
                   ooha.attribute10,
                   ooha.attribute11,
                   ooha.attribute12,
                   ooha.attribute13,
                   ooha.attribute14,
                   ooha.attribute15,
                   ooha.attribute16,
                   ooha.attribute17,
                   ooha.attribute18,
                   ooha.attribute19,
                   ooha.price_list_id,
                   ooha.packing_instructions,
                   ooha.shipping_instructions,
                   ooha.freight_carrier_code,
                   ooha.payment_type_code,
                   ooha.conversion_type_code,
                   get_target_salesrep (ooha.salesrep_id, stg.target_org_id)
                       target_sales_rep_id,
                   ooha.freight_terms_code,
                   ooha.payment_term_id,
                   ooha.demand_class_code,
                   ooha.created_by,
                   ooha.creation_date,
                   ooha.last_updated_by,
                   ooha.last_update_date,
                   ooha.last_update_login,
                   --  TO_DATE (request_date, 'MM/DD/YYYY')  request_date,
                   ooha.request_date,
                   'INSERT'
                       operation_code,
                   ooha.sold_from_org_id
              FROM xxd_ou_alignment_inbound_t stg, apps.oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     1 = 1
                   AND stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') = 'BO'
                   AND ooha.order_category_code = 'ORDER'
                   AND stg.request_id = gn_request_id
                   AND NVL (stg.status, 'X') = 'PENDING';

        CURSOR CSR_LINES (P_HEADER_ID NUMBER)
        IS
            SELECT DISTINCT
                   ooha.header_id,
                   ooha.order_number,
                   (SELECT account_number
                      FROM hz_cust_accounts
                     WHERE cust_account_id = ooha.sold_to_org_id)
                       source_cust_account,
                   (SELECT name
                      FROM oe_transaction_types_tl
                     WHERE     language = USERENV ('LANG')
                           AND transaction_type_id = ooha.order_type_id)
                       source_order_type,
                   oola.line_id,
                   oola.line_number || '.' || oola.shipment_number
                       source_line_number,
                   -- Source End
                   stg.target_customer
                       target_customer_number,
                   oola.order_source_id, --oola.order_source_id, hardcoded to 0 to create new instead of 2 Copy
                   ooha.order_number || '-' || ooha.header_id
                       orig_sys_document_ref,
                      ooha.order_number
                   || '-'
                   || oola.line_id
                   || '-'
                   || oola.line_number
                       orig_sys_line_ref,
                   stg.target_org_id,
                   oola.org_id,
                   oola.line_number,
                   oola.flow_status_code,
                   inventory_item_id,
                   ordered_item,
                   sline.source_order_line_ordered_quantity
                       stg_ordered_qty,
                   oola.ordered_quantity, --in STG we are getting current ordered qty value
                   oola.cancelled_quantity,
                   order_quantity_uom,
                   (SELECT cust_account_id
                      FROM hz_cust_accounts
                     WHERE account_number = stg.target_customer)
                       target_sold_to_org_id,
                   oola.ship_to_org_id,
                   get_target_ship_to (ooha.ship_to_org_id,
                                       stg.target_customer)
                       target_ship_to_org_id,
                   get_target_bill_to (ooha.invoice_to_org_id,
                                       stg.target_customer)
                       target_bill_to_org_id,
                   oola.demand_class_code,
                   oola.unit_list_price,
                   oola.unit_selling_price,
                   oola.tax_value,
                   --  round((oola.tax_value/(oola.ordered_quantity * oola.unit_selling_price)),2) tax_rate,
                   -- oola.salesrep_id,
                   get_target_salesrep (oola.salesrep_id, stg.target_org_id)
                       target_sales_rep_id,
                   oola.invoice_to_org_id,
                   oola.payment_term_id,
                   oola.freight_terms_code,
                   oola.shipping_method_code,
                   oola.cust_po_number,
                   oola.packing_instructions,
                   -- TO_DATE (oola.pricing_date, 'MM/DD/YYYY') pricing_date,
                   'Y'
                       calculate_price_flag, --harcoded to Y because we are querying from cancelled Order Line
                   --               TO_CHAR (TO_DATE (oola.attribute1, 'MM/DD/YYYY'),
                   --                        'YYYY/MM/DD') attribute1
                   oola.attribute1,
                   oola.attribute2,
                   oola.attribute3,
                   oola.attribute4,
                   oola.attribute5,
                   oola.attribute6,
                   oola.attribute7,
                   oola.attribute8,
                   oola.attribute10,
                   oola.attribute11,
                   oola.attribute12,
                   oola.attribute14,
                   oola.attribute15,
                   --               TO_DATE (oola.request_date, 'MM/DD/YYYY')
                   --                   request_date,
                   oola.request_date,
                   oola.latest_acceptable_date,
                   oola.schedule_ship_date,
                   --               TO_DATE (oola.latest_acceptable_date, 'MM/DD/YYYY')
                   --                   latest_acceptable_date,
                   oola.deliver_to_org_id,
                   oola.source_document_type_id,
                   oola.source_document_id,
                   source_document_line_id,
                   oola.attribute13,
                   oola.created_by,
                   oola.creation_date,
                   oola.last_updated_by,
                   oola.last_update_date,
                   oola.last_update_login,
                   'INSERT'
                       operation_code
              FROM xxd_ou_alignment_inbound_t stg, apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha,
                   xxd_ou_alignment_lines_t sline
             WHERE     1 = 1                     -- stg.line_id = oola.line_id
                   AND stg.source_order_number = ooha.order_number
                   AND oola.header_id = ooha.header_id
                   --  AND oola.change_sequence = 8
                   AND stg.status = 'PENDING'
                   AND ooha.header_id = P_HEADER_ID
                   AND ooha.order_category_code = 'ORDER'
                   AND stg.request_id = gn_request_id
                   AND stg.source_order_number = sline.source_order_number
                   AND oola.line_id = sline.source_line_id
                   AND sline.request_id = gn_request_id
                   AND sline.status <> 'ERROR'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE demand_source_line_id = oola.line_id);

        CURSOR lc_org IS
            SELECT DISTINCT stg.target_ou, stg.target_org_id org_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') = 'BO'
                   AND stg.status = 'PENDING'
                   AND stg.request_id = gn_request_id;
    BEGIN
        --DBMS_OUTPUT.enable (buffer_size => NULL);

        FOR i IN lc_org
        LOOP
            /*
                fnd_global.apps_initialize (user_id        => 1875,
                                            resp_id        => 50746,
                                            resp_appl_id   => 660); -- pass in user_id, responsibility_id, and application_id
            */
            ln_resp_id        := NULL;
            ln_resp_appl_id   := NULL;

            BEGIN
                SELECT frv.responsibility_id, frv.application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                       apps.hr_organization_units hou
                 WHERE     1 = 1
                       AND hou.organization_id = i.org_id
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
                    DBMS_OUTPUT.put_line (
                        'Error getting the responsibility ID : ' || SQLERRM);
            END;

            fnd_global.apps_initialize (gn_user_id,
                                        ln_resp_id,
                                        ln_resp_appl_id); -- pass in user_id,responsibility_id, and application_id

            oe_msg_pub.initialize;
            oe_debug_pub.initialize;
            X_DEBUG_FILE      := OE_DEBUG_PUB.Set_Debug_Mode ('FILE');

            FOR rec_headers IN csr_headers
            LOOP
                INSERT INTO OE_HEADERS_IFACE_ALL (change_sequence, order_source_id, orig_sys_document_ref, org_id, ordered_date, order_type_id, --   transactional_curr_code,
                                                                                                                                                customer_po_number, ship_from_org_id, price_list_id, sold_to_org_id, ship_to_org_id, --  deliver_to_org_id,
                                                                                                                                                                                                                                     customer_id, shipping_method_code, booked_flag, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, packing_instructions, shipping_instructions, --  freight_carrier_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                conversion_type_code, payment_type_code, salesrep_id, freight_terms_code, payment_term_id, demand_class_code, created_by, creation_date, last_updated_by, last_update_date, last_update_login, request_date, operation_code
                                                  , sold_from_org_id)
                     VALUES (10, rec_headers.order_source_id, rec_headers.orig_sys_document_ref, rec_headers.target_org_id, rec_headers.ordered_date, rec_headers.target_order_type_id, --  rec_headers.transactional_curr_code,
                                                                                                                                                                                        rec_headers.customer_po_number, rec_headers.ship_from_org_id, rec_headers.price_list_id, rec_headers.target_sold_to_org_id, rec_headers.target_ship_to_org_id, --   rec_headers.deliver_to_org_id,
                                                                                                                                                                                                                                                                                                                                                       rec_headers.target_sold_to_org_id, rec_headers.shipping_method_code, rec_headers.booked_flag, rec_headers.attribute1, rec_headers.attribute2, rec_headers.attribute3, rec_headers.attribute4, rec_headers.attribute5, rec_headers.attribute6, rec_headers.attribute7, rec_headers.attribute8, rec_headers.attribute9, rec_headers.attribute10, rec_headers.attribute11, rec_headers.attribute12, rec_headers.attribute13, rec_headers.attribute14, rec_headers.attribute15, rec_headers.attribute16, rec_headers.attribute17, rec_headers.attribute18, rec_headers.attribute19, rec_headers.packing_instructions, rec_headers.shipping_instructions, --  rec_headers.freight_carrier_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            rec_headers.conversion_type_code, rec_headers.payment_type_code, rec_headers.target_sales_rep_id, rec_headers.freight_terms_code, rec_headers.payment_term_id, rec_headers.demand_class_code, rec_headers.created_by, rec_headers.creation_date, rec_headers.last_updated_by, rec_headers.last_update_date, rec_headers.last_update_login, rec_headers.request_date, rec_headers.operation_code
                             , rec_headers.sold_from_org_id);


                FOR rec_lines IN csr_lines (rec_headers.header_id)
                LOOP
                    INSERT INTO OE_LINES_IFACE_ALL (change_sequence, order_source_id, orig_sys_document_ref, orig_sys_line_ref, org_id, --  line_number,
                                                                                                                                        inventory_item_id, ordered_quantity, order_quantity_uom, sold_to_org_id, ship_to_org_id, demand_class_code, unit_list_price, unit_selling_price, salesrep_id, payment_term_id, freight_terms_code, shipping_method_code, customer_po_number, packing_instructions, invoice_to_org_id, --  pricing_date,
                                                                                                                                                                                                                                                                                                                                                                                                                              calculate_price_flag, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute10, attribute11, attribute12, attribute14, attribute15, request_date, latest_acceptable_date, --  deliver_to_org_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           attribute13, created_by, creation_date, last_updated_by, last_update_date, last_update_login
                                                    , operation_code)
                         VALUES (10, rec_lines.order_source_id, rec_lines.orig_sys_document_ref, rec_lines.orig_sys_line_ref, rec_lines.target_org_id, --   rec_lines.line_number,
                                                                                                                                                       rec_lines.inventory_item_id, rec_lines.stg_ordered_qty, rec_lines.order_quantity_uom, rec_lines.target_sold_to_org_id, rec_lines.target_ship_to_org_id, rec_lines.demand_class_code, rec_lines.unit_list_price, rec_lines.unit_selling_price, rec_lines.target_sales_rep_id, --  rec_lines.salesrep_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                    rec_lines.payment_term_id, rec_lines.freight_terms_code, rec_lines.shipping_method_code, rec_lines.cust_po_number, rec_lines.packing_instructions, rec_lines.target_bill_to_org_id, --    rec_lines.pricing_date,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        rec_lines.calculate_price_flag, rec_lines.attribute1, rec_lines.attribute2, rec_lines.attribute3, rec_lines.attribute4, rec_lines.attribute5, rec_lines.attribute6, rec_lines.attribute7, rec_lines.attribute8, rec_lines.attribute10, rec_lines.attribute11, rec_lines.attribute12, rec_lines.attribute14, rec_lines.attribute15, rec_lines.request_date, rec_lines.latest_acceptable_date, --  rec_lines.deliver_to_org_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     rec_lines.attribute13, rec_lines.created_by, rec_lines.creation_date, rec_lines.last_updated_by, rec_lines.last_update_date, rec_lines.last_update_login
                                 , rec_lines.operation_code);
                END LOOP;

                COMMIT;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error occured while creating the target orders ' || SQLERRM);
    END create_new_bulk_order;

    PROCEDURE create_new_non_bulk_order
    IS
        l_header_rec               OE_ORDER_PUB.Header_Rec_Type;
        l_header_rec_out           OE_ORDER_PUB.Header_Rec_Type;
        l_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type;
        l_line_rec                 OE_ORDER_PUB.Line_Rec_Type;
        l_line_rec1                OE_ORDER_PUB.Line_Rec_Type;
        l_action_request_tbl       OE_ORDER_PUB.Request_Tbl_Type;
        l_header_adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type;
        l_line_adj_tbl             OE_ORDER_PUB.line_adj_tbl_Type;
        l_header_scr_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        l_line_scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        l_request_rec              OE_ORDER_PUB.Request_Rec_Type;
        l_return_status            VARCHAR2 (1000);
        l_return_status1           VARCHAR2 (1000);
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (1000);
        p_api_version_number       NUMBER := 1.0;
        p_init_msg_list            VARCHAR2 (10) := FND_API.G_FALSE;
        p_return_values            VARCHAR2 (10) := FND_API.G_FALSE;
        p_action_commit            VARCHAR2 (10) := FND_API.G_FALSE;
        x_return_status            VARCHAR2 (1);
        x_msg_count                NUMBER;
        x_msg_data                 VARCHAR2 (100);
        x_header_val_rec           OE_ORDER_PUB.Header_Val_Rec_Type;
        x_Header_Adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type;
        x_Header_Adj_val_tbl       OE_ORDER_PUB.Header_Adj_Val_Tbl_Type;
        x_Header_price_Att_tbl     OE_ORDER_PUB.Header_Price_Att_Tbl_Type;
        x_Header_Adj_Att_tbl       OE_ORDER_PUB.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl     OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl       OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl   OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type;
        x_line_val_tbl             OE_ORDER_PUB.Line_Val_Tbl_Type;
        x_Line_Adj_tbl             OE_ORDER_PUB.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl         OE_ORDER_PUB.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl       OE_ORDER_PUB.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl         OE_ORDER_PUB.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl       OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        x_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type;
        x_Line_Scredit_val_tbl     OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl           OE_ORDER_PUB.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl       OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type;
        x_action_request_tbl       OE_ORDER_PUB.Request_Tbl_Type;
        X_DEBUG_FILE               VARCHAR2 (100);
        l_line_tbl_index           NUMBER;
        l_msg_index_out            NUMBER (10);
        l_split_qty                NUMBER;

        ln_resp_id                 NUMBER;
        ln_resp_appl_id            NUMBER;

        CURSOR CSR_HEADERS IS
            SELECT DISTINCT
                   ooha.org_id,
                   stg.original_ou
                       source_ou,
                   stg.target_org_id,
                   ooha.header_id,
                   ooha.order_number,
                   (SELECT account_number
                      FROM hz_cust_accounts
                     WHERE cust_account_id = ooha.sold_to_org_id)
                       source_cust_account,
                   (SELECT name
                      FROM oe_transaction_types_tl otl
                     WHERE     otl.language = USERENV ('LANG')
                           AND otl.transaction_type_id = ooha.order_type_id)
                       source_order_type,
                   stg.target_customer
                       target_customer_number,
                   (SELECT account_name
                      FROM hz_cust_accounts
                     WHERE account_number = stg.target_customer)
                       target_customer_name,
                   --  0 order_source_id,--harcoded to 0, instead of 2 Copy
                   ooha.order_source_id,    --harcoded to 0, instead of 2 Copy
                   ooha.order_number || '-' || ooha.header_id
                       orig_sys_document_ref,
                   ooha.ordered_date,
                   get_target_order_type (ooha.org_id,
                                          stg.target_org_id,
                                          ooha.order_type_id)
                       target_order_type_id,
                   ooha.order_type_id,
                   --   transactional_curr_code,
                   ooha.cust_po_number
                       customer_po_number,
                   ooha.ship_from_org_id,
                   (SELECT cust_account_id
                      FROM hz_cust_accounts
                     WHERE account_number = stg.target_customer)
                       target_sold_to_org_id,
                   ooha.ship_to_org_id,
                   ooha.invoice_to_org_id,
                   get_target_ship_to (ooha.ship_to_org_id,
                                       stg.target_customer)
                       target_ship_to_org_id,
                   get_target_bill_to (ooha.invoice_to_org_id,
                                       stg.target_customer)
                       target_bill_to_org_id,
                   ooha.deliver_to_org_id,
                   ooha.sold_to_org_id
                       customer_id,
                   ooha.shipping_method_code,
                   ooha.booked_flag,
                   ooha.attribute1,
                   ooha.attribute2,
                   ooha.attribute3,
                   ooha.attribute4,
                   ooha.attribute5,
                   ooha.attribute6,
                   ooha.attribute7,
                   ooha.attribute8,
                   ooha.attribute9,
                   ooha.attribute10,
                   ooha.attribute11,
                   ooha.attribute12,
                   ooha.attribute13,
                   ooha.attribute14,
                   ooha.attribute15,
                   ooha.attribute16,
                   ooha.attribute17,
                   ooha.attribute18,
                   ooha.attribute19,
                   ooha.price_list_id,
                   ooha.packing_instructions,
                   ooha.shipping_instructions,
                   ooha.freight_carrier_code,
                   ooha.payment_type_code,
                   ooha.conversion_type_code,
                   get_target_salesrep (ooha.salesrep_id, stg.target_org_id)
                       target_sales_rep_id,
                   ooha.freight_terms_code,
                   ooha.payment_term_id,
                   ooha.demand_class_code,
                   ooha.created_by,
                   ooha.creation_date,
                   ooha.last_updated_by,
                   ooha.last_update_date,
                   ooha.last_update_login,
                   --  TO_DATE (request_date, 'MM/DD/YYYY')  request_date,
                   ooha.request_date,
                   'INSERT'
                       operation_code,
                   ooha.sold_from_org_id
              FROM xxd_ou_alignment_inbound_t stg, apps.oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     1 = 1
                   AND stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND stg.request_id = gn_request_id
                   AND ooha.order_category_code = 'ORDER'
                   AND NVL (ott.attribute5, 'XX') <> 'BO'
                   AND NVL (stg.status, 'X') = 'PENDING';

        CURSOR CSR_LINES (P_HEADER_ID NUMBER)
        IS
            SELECT DISTINCT
                   ooha.header_id,
                   ooha.order_number,
                   (SELECT account_number
                      FROM hz_cust_accounts
                     WHERE cust_account_id = ooha.sold_to_org_id)
                       source_cust_account,
                   (SELECT name
                      FROM oe_transaction_types_tl
                     WHERE     language = USERENV ('LANG')
                           AND transaction_type_id = ooha.order_type_id)
                       source_order_type,
                   oola.line_id,
                   oola.line_number || '.' || oola.shipment_number
                       source_line_number,
                   -- Source End
                   stg.target_customer
                       target_customer_number,
                   oola.order_source_id, --oola.order_source_id, hardcoded to 0 to create new instead of 2 Copy
                   ooha.order_number || '-' || ooha.header_id
                       orig_sys_document_ref,
                      ooha.order_number
                   || '-'
                   || oola.line_id
                   || '-'
                   || oola.line_number
                       orig_sys_line_ref,
                   stg.target_org_id,
                   oola.org_id,
                   oola.line_number,
                   inventory_item_id,
                   oola.flow_status_code,
                   ordered_item,
                   sline.source_order_line_ordered_quantity
                       stg_ordered_qty,
                   oola.ordered_quantity, --in STG we are getting current ordered qty value
                   oola.cancelled_quantity,
                   order_quantity_uom,
                   (SELECT cust_account_id
                      FROM hz_cust_accounts
                     WHERE account_number = stg.target_customer)
                       target_sold_to_org_id,
                   oola.ship_to_org_id,
                   get_target_ship_to (ooha.ship_to_org_id,
                                       stg.target_customer)
                       target_ship_to_org_id,
                   get_target_bill_to (ooha.invoice_to_org_id,
                                       stg.target_customer)
                       target_bill_to_org_id,
                   oola.demand_class_code,
                   oola.unit_list_price,
                   oola.unit_selling_price,
                   oola.tax_value,
                   -- round((oola.tax_value/(oola.ordered_quantity * oola.unit_selling_price)),2) tax_rate,
                   get_target_salesrep (oola.salesrep_id, stg.target_org_id)
                       target_sales_rep_id,
                   oola.invoice_to_org_id,
                   oola.payment_term_id,
                   oola.freight_terms_code,
                   oola.shipping_method_code,
                   oola.cust_po_number,
                   oola.packing_instructions,
                   -- TO_DATE (oola.pricing_date, 'MM/DD/YYYY') pricing_date,
                   'Y'
                       calculate_price_flag, --harcoded to Y because we are querying from cancelled Order Line
                   --               TO_CHAR (TO_DATE (oola.attribute1, 'MM/DD/YYYY'),
                   --                        'YYYY/MM/DD') attribute1
                   oola.attribute1,
                   oola.attribute2,
                   oola.attribute3,
                   oola.attribute4,
                   oola.attribute5,
                   oola.attribute6,
                   oola.attribute7,
                   oola.attribute8,
                   oola.attribute10,
                   oola.attribute11,
                   oola.attribute12,
                   oola.attribute14,
                   oola.attribute15,
                   --               TO_DATE (oola.request_date, 'MM/DD/YYYY')
                   --                   request_date,
                   oola.request_date,
                   oola.latest_acceptable_date,
                   oola.schedule_ship_date,
                   --               TO_DATE (oola.latest_acceptable_date, 'MM/DD/YYYY')
                   --                   latest_acceptable_date,
                   oola.deliver_to_org_id,
                   oola.source_document_type_id,
                   oola.source_document_id,
                   source_document_line_id,
                   oola.attribute13,
                   oola.created_by,
                   oola.creation_date,
                   oola.last_updated_by,
                   oola.last_update_date,
                   oola.last_update_login,
                   'INSERT'
                       operation_code
              FROM xxd_ou_alignment_inbound_t stg, apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha,
                   xxd_ou_alignment_lines_t sline
             WHERE     1 = 1                     -- stg.line_id = oola.line_id
                   AND stg.source_order_number = ooha.order_number
                   AND oola.header_id = ooha.header_id
                   AND oola.change_sequence = 8
                   AND NVL (stg.status, 'X') = 'PENDING'
                   AND ooha.header_id = P_HEADER_ID
                   AND ooha.order_category_code = 'ORDER'
                   AND stg.request_id = gn_request_id
                   AND stg.source_order_number = sline.source_order_number
                   AND oola.line_id = sline.source_line_id
                   AND sline.request_id = gn_request_id
                   AND sline.status <> 'ERROR'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE demand_source_line_id = oola.line_id);

        CURSOR lc_org IS
            SELECT DISTINCT stg.target_ou, stg.target_org_id org_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') <> 'BO'
                   AND stg.status = 'PENDING'
                   AND stg.request_id = gn_request_id;
    BEGIN
        -- DBMS_OUTPUT.enable (buffer_size => NULL);
        fnd_file.put_line (fnd_file.LOG, 'gn_request_id ' || gn_request_id);

        FOR i IN lc_org
        LOOP
            ln_resp_id        := NULL;
            ln_resp_appl_id   := NULL;

            BEGIN
                SELECT frv.responsibility_id, frv.application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                       apps.hr_organization_units hou
                 WHERE     1 = 1
                       AND hou.organization_id = i.org_id
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
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error getting the responsibility ID : ' || SQLERRM);
            END;

            fnd_global.apps_initialize (gn_user_id,
                                        ln_resp_id,
                                        ln_resp_appl_id); -- pass in user_id,responsibility_id, and application_id

            oe_msg_pub.initialize;
            oe_debug_pub.initialize;
            X_DEBUG_FILE      := OE_DEBUG_PUB.Set_Debug_Mode ('FILE');

            FOR rec_headers IN csr_headers
            LOOP
                INSERT INTO OE_HEADERS_IFACE_ALL (change_sequence, order_source_id, orig_sys_document_ref, org_id, ordered_date, order_type_id, --   transactional_curr_code,
                                                                                                                                                customer_po_number, ship_from_org_id, price_list_id, sold_to_org_id, ship_to_org_id, --  deliver_to_org_id,
                                                                                                                                                                                                                                     customer_id, shipping_method_code, booked_flag, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, packing_instructions, shipping_instructions, --   freight_carrier_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                conversion_type_code, payment_type_code, salesrep_id, freight_terms_code, payment_term_id, demand_class_code, created_by, creation_date, last_updated_by, last_update_date, last_update_login, request_date, operation_code
                                                  , sold_from_org_id)
                     VALUES (10, rec_headers.order_source_id, rec_headers.orig_sys_document_ref, rec_headers.target_org_id, rec_headers.ordered_date, rec_headers.target_order_type_id, --  rec_headers.transactional_curr_code,
                                                                                                                                                                                        rec_headers.customer_po_number, rec_headers.ship_from_org_id, rec_headers.price_list_id, rec_headers.target_sold_to_org_id, rec_headers.target_ship_to_org_id, --   rec_headers.deliver_to_org_id,
                                                                                                                                                                                                                                                                                                                                                       rec_headers.target_sold_to_org_id, rec_headers.shipping_method_code, rec_headers.booked_flag, rec_headers.attribute1, rec_headers.attribute2, rec_headers.attribute3, rec_headers.attribute4, rec_headers.attribute5, rec_headers.attribute6, rec_headers.attribute7, rec_headers.attribute8, rec_headers.attribute9, rec_headers.attribute10, rec_headers.attribute11, rec_headers.attribute12, rec_headers.attribute13, rec_headers.attribute14, rec_headers.attribute15, rec_headers.attribute16, rec_headers.attribute17, rec_headers.attribute18, rec_headers.attribute19, rec_headers.packing_instructions, rec_headers.shipping_instructions, --  rec_headers.freight_carrier_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            rec_headers.conversion_type_code, rec_headers.payment_type_code, rec_headers.target_sales_rep_id, rec_headers.freight_terms_code, rec_headers.payment_term_id, rec_headers.demand_class_code, rec_headers.created_by, rec_headers.creation_date, rec_headers.last_updated_by, rec_headers.last_update_date, rec_headers.last_update_login, rec_headers.request_date, rec_headers.operation_code
                             , rec_headers.sold_from_org_id);


                FOR rec_lines IN csr_lines (rec_headers.header_id)
                LOOP
                    INSERT INTO OE_LINES_IFACE_ALL (change_sequence, order_source_id, orig_sys_document_ref, orig_sys_line_ref, org_id, --  line_number,
                                                                                                                                        inventory_item_id, ordered_quantity, order_quantity_uom, sold_to_org_id, ship_to_org_id, demand_class_code, unit_list_price, unit_selling_price, salesrep_id, payment_term_id, freight_terms_code, shipping_method_code, customer_po_number, packing_instructions, invoice_to_org_id, --  pricing_date,
                                                                                                                                                                                                                                                                                                                                                                                                                              calculate_price_flag, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute10, attribute11, attribute12, attribute14, attribute15, request_date, latest_acceptable_date, --  deliver_to_org_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           attribute13, created_by, creation_date, last_updated_by, last_update_date, last_update_login
                                                    , operation_code)
                         VALUES (10, rec_lines.order_source_id, rec_lines.orig_sys_document_ref, rec_lines.orig_sys_line_ref, rec_lines.target_org_id, --   rec_lines.line_number,
                                                                                                                                                       rec_lines.inventory_item_id, rec_lines.stg_ordered_qty, rec_lines.order_quantity_uom, rec_lines.target_sold_to_org_id, rec_lines.target_ship_to_org_id, rec_lines.demand_class_code, rec_lines.unit_list_price, rec_lines.unit_selling_price, rec_lines.target_sales_rep_id, rec_lines.payment_term_id, rec_lines.freight_terms_code, rec_lines.shipping_method_code, rec_lines.cust_po_number, rec_lines.packing_instructions, rec_lines.target_bill_to_org_id, --    rec_lines.pricing_date,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        rec_lines.calculate_price_flag, rec_lines.attribute1, rec_lines.attribute2, rec_lines.attribute3, rec_lines.attribute4, rec_lines.attribute5, rec_lines.attribute6, rec_lines.attribute7, rec_lines.attribute8, rec_lines.attribute10, rec_lines.attribute11, rec_lines.attribute12, rec_lines.attribute14, rec_lines.attribute15, rec_lines.request_date, rec_lines.latest_acceptable_date, --  rec_lines.deliver_to_org_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     rec_lines.attribute13, rec_lines.created_by, rec_lines.creation_date, rec_lines.last_updated_by, rec_lines.last_update_date, rec_lines.last_update_login
                                 , rec_lines.operation_code);
                END LOOP;

                COMMIT;
            END LOOP;
        END LOOP;
    -- fnd_file.put_line(fnd_file.log,'Target Data inserted into interface table ' );
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error occured while creating the target orders ' || SQLERRM);
    END create_new_non_bulk_order;

    --
    -- Cancel Non Bulk Orders

    PROCEDURE cancel_non_bulk_orders
    IS
        CURSOR lh_non_bulk_orders IS
            SELECT DISTINCT ooha.orig_sys_document_ref, ooha.created_by, ooha.creation_date,
                            ooha.header_id, ooha.order_number, ooha.org_id,
                            ooha.order_source_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_order_lines_all oola,
                   oe_transaction_types_all ott
             WHERE     stg.status = 'PENDING'
                   AND stg.source_order_number = ooha.order_number
                   AND ooha.header_id = oola.header_id
                   AND ooha.open_flag = 'Y'
                   AND ooha.flow_status_code = 'BOOKED'
                   AND ooha.order_category_code = 'ORDER'
                   AND oola.cancelled_flag = 'N'
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') <> 'BO'
                   AND stg.request_id = gn_request_id
                   AND TRUNC (oola.request_date) >=
                       stg.source_order_request_date_from
                   --AND oola.request_date between stg.SOURCE_ORDER_REQUEST_DATE_FROM AND NVL(stg.SOURCE_ORDER_REQUEST_DATE_TO,sysdate)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     wdd.source_header_id = ooha.header_id
                                   AND wdd.source_line_id = oola.line_id
                                   AND wdd.released_status IN ('S', 'Y', 'C'));


        CURSOR ll_non_bulk_orders IS
            SELECT DISTINCT ooha.order_source_id, ooha.order_number, ooha.orig_sys_document_ref,
                            oola.created_by, oola.creation_date, oola.line_id,
                            oola.orig_sys_line_ref, oola.org_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_order_lines_all oola,
                   oe_transaction_types_all ott
             WHERE     stg.status = 'PENDING'
                   AND stg.source_order_number = ooha.order_number
                   AND ooha.header_id = oola.header_id
                   AND ooha.open_flag = 'Y'
                   AND ooha.flow_status_code = 'BOOKED'
                   AND ooha.order_category_code = 'ORDER'
                   AND oola.cancelled_flag = 'N'
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') <> 'BO'
                   AND stg.request_id = gn_request_id
                   AND TRUNC (oola.request_date) >=
                       stg.SOURCE_ORDER_REQUEST_DATE_FROM
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     wdd.source_header_id = ooha.header_id
                                   AND wdd.source_line_id = oola.line_id
                                   AND wdd.released_status IN ('S', 'Y', 'C'));

        CURSOR lc_order_data IS
            SELECT stg.original_ou
                       source_ou,
                   stg.source_org_id,
                   stg.source_customer,
                   ooha.cust_po_number,
                   ooha.order_number,
                   ooha.request_date,
                   ooha.ship_to_org_id,
                   ooha.invoice_to_org_id,
                   ooha.ordered_date,
                   ooha.creation_date,
                   ooha.attribute1
                       cancelled_date,
                   (SELECT name
                      FROM oe_transaction_types_tl otl
                     WHERE     otl.language = USERENV ('LANG')
                           AND otl.transaction_type_id = ooha.order_type_id)
                       source_order_type,
                   ooha.order_type_id,
                   ooha.ship_from_org_id,
                   ooha.salesrep_id,
                   ooha.price_list_id,
                   oola.tax_value,
                   DECODE (
                       oola.tax_value,
                       0, 0,
                       ROUND (
                           (oola.tax_value / (oola.ordered_quantity * oola.unit_selling_price)),
                           2))
                       tax_rate,
                   oola.line_id,
                   oola.line_number,
                   oola.ordered_item,
                   oola.creation_date
                       line_creation_date,
                   oola.ordered_quantity,
                   oola.latest_acceptable_date,
                   oola.schedule_ship_date,
                   oola.flow_status_code,
                   stg.error_message,
                   stg.status
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, oe_transaction_types_all ott,
                   xxd_ou_alignment_inbound_t stg
             WHERE     1 = 1
                   AND ooha.header_id = oola.header_id
                   AND ooha.order_number = stg.source_order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND stg.request_id = gn_request_id
                   AND NVL (ott.attribute5, 'XX') <> 'BO'
                   AND ooha.open_flag = 'Y'
                   AND ooha.order_category_code = 'ORDER'
                   AND oola.cancelled_flag = 'N'
                   AND TRUNC (oola.request_date) >=
                       stg.source_order_request_date_from
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     wdd.source_header_id = ooha.header_id
                                   AND wdd.source_line_id = oola.line_id
                                   AND wdd.released_status IN ('S', 'Y', 'C'));
    BEGIN
        -- insert the order lines into staging table

        FOR k IN lc_order_data
        LOOP
            BEGIN
                INSERT INTO XXD_OU_ALIGNMENT_LINES_T (
                                batch_id,
                                source_ou,
                                source_org_id,
                                source_customer,
                                source_order_number,
                                source_order_cust_po_number,
                                source_order_request_date,
                                source_order_ship_to_location,
                                source_order_bill_to_location,
                                source_order_ordered_date,
                                source_order_creation_date,
                                source_order_cancel_date,
                                source_order_type,
                                source_order_ship_from_warehouse,
                                source_order_sales_rep,
                                source_order_price_list,
                                source_order_line_tax_rate,
                                source_order_line_tax_amount,
                                source_line_id,
                                source_line_num,
                                source_order_line_ordered_item,
                                source_order_line_ordered_quantity,
                                source_order_line_latest_acceptable_date,
                                source_order_line_creation_date,
                                source_order_line_schedule_shipped_date,
                                source_order_line_flow_status_code,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                request_id,
                                error_message,
                                status)
                     VALUES (gn_batch_id, k.source_ou, k.source_org_id,
                             k.source_customer, k.order_number, k.cust_po_number, k.request_date, k.ship_to_org_id, k.invoice_to_org_id, k.ordered_date, k.creation_date, k.cancelled_date, k.source_order_type, k.ship_from_org_id, k.salesrep_id, k.price_list_id, k.tax_rate, k.tax_value, k.line_id, k.line_number, k.ordered_item, k.ordered_quantity, k.latest_acceptable_date, k.line_creation_date, k.schedule_ship_date, k.flow_status_code, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                             , gn_request_id, k.error_message, k.status);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error occured while inserting custom line data of bulk order'
                        || SQLERRM);
            END;
        END LOOP;

        COMMIT;


        FOR i IN lh_non_bulk_orders
        LOOP
            --       fnd_file.put_line(fnd_file.log,'Cancel Data inserted into interface table ' );
            BEGIN
                INSERT INTO apps.oe_headers_iface_all (orig_sys_document_ref,
                                                       created_by,
                                                       creation_date,
                                                       last_updated_by,
                                                       last_update_date,
                                                       operation_code,
                                                       header_id,
                                                       org_id,
                                                       order_source_id,
                                                       change_sequence,
                                                       force_apply_flag)
                     VALUES (i.orig_sys_document_ref, gn_user_id, i.creation_date, gn_user_id, SYSDATE, 'UPDATE', i.header_id, i.org_id, i.order_source_id
                             , 8, 'Y');
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to insert the header IFACE of non bulk order # '
                        || i.order_number);
            END;
        END LOOP;

        FOR j IN ll_non_bulk_orders
        LOOP
            BEGIN
                -- fnd_file.put_line(fnd_file.log,'Data inserting into line iface');
                INSERT INTO apps.oe_lines_iface_all (order_source_id,
                                                     orig_sys_document_ref,
                                                     created_by,
                                                     creation_date,
                                                     last_updated_by,
                                                     last_update_date,
                                                     operation_code,
                                                     line_id,
                                                     orig_sys_line_ref,
                                                     org_id,
                                                     change_sequence,
                                                     ordered_quantity,
                                                     change_reason,
                                                     change_comments)
                         VALUES (
                                    j.order_source_id,
                                    j.orig_sys_document_ref,
                                    j.created_by,
                                    j.creation_date,
                                    gn_user_id,
                                    SYSDATE,
                                    'UPDATE',
                                    j.line_id,
                                    j.orig_sys_line_ref,
                                    j.org_id,
                                    8,
                                    0,
                                    '1',
                                    'Cancelled by Deckers Sales Order Move Program');
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to insert the lines data of non bulk order # '
                        || j.order_number);

                    BEGIN
                        UPDATE XXD_OU_ALIGNMENT_INBOUND_T
                           SET STATUS   = 'ERROR'
                         WHERE     SOURCE_ORDER_NUMBER = j.order_number
                               AND request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to insert lines IFACE of non bulk order # '
                                || j.order_number);
                    END;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Failed to insert data ito interface table '
                || 'cancel_non_bulk_orders '
                || SQLERRM);
    END cancel_non_bulk_orders;

    -- Cancel Bulk Orders

    PROCEDURE cancel_bulk_orders
    IS
        CURSOR lh_bulk_orders IS
            SELECT DISTINCT ooha.orig_sys_document_ref, ooha.created_by, ooha.creation_date,
                            ooha.header_id, ooha.order_number, ooha.org_id,
                            ooha.order_source_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_order_lines_all oola,
                   oe_transaction_types_all ott
             WHERE     stg.status = 'PENDING'
                   AND stg.source_order_number = ooha.order_number
                   AND ooha.header_id = oola.header_id
                   AND ooha.open_flag = 'Y'
                   AND ooha.flow_status_code = 'BOOKED'
                   AND ooha.order_category_code = 'ORDER'
                   AND oola.cancelled_flag = 'N'
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') = 'BO'
                   AND stg.request_id = gn_request_id
                   AND oola.request_date >=
                       NVL (stg.SOURCE_ORDER_REQUEST_DATE_FROM,
                            '01-JAN-2023')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     wdd.source_header_id = ooha.header_id
                                   AND wdd.source_line_id = oola.line_id
                                   AND wdd.released_status IN ('S', 'Y', 'C'));


        CURSOR ll_bulk_orders (p_header_id NUMBER)
        IS
            SELECT DISTINCT ooha.order_source_id, ooha.order_number, ooha.orig_sys_document_ref,
                            oola.created_by, oola.creation_date, oola.line_id,
                            oola.ordered_quantity, oola.orig_sys_line_ref, oola.org_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_order_lines_all oola,
                   oe_transaction_types_all ott
             WHERE     stg.status = 'PENDING'
                   AND stg.source_order_number = ooha.order_number
                   AND ooha.header_id = oola.header_id
                   AND ooha.open_flag = 'Y'
                   AND ooha.flow_status_code = 'BOOKED'
                   AND ooha.order_category_code = 'ORDER'
                   AND oola.cancelled_flag = 'N'
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') = 'BO'
                   AND ooha.header_id = p_header_id
                   AND oola.request_date >=
                       NVL (stg.SOURCE_ORDER_REQUEST_DATE_FROM,
                            '01-JAN-2023')
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     wdd.source_header_id = ooha.header_id
                                   AND wdd.source_line_id = oola.line_id
                                   AND wdd.released_status IN ('S', 'Y', 'C'));

        CURSOR lc_order_data IS
            SELECT stg.original_ou
                       source_ou,
                   stg.source_org_id,
                   stg.source_customer,
                   ooha.cust_po_number,
                   ooha.order_number,
                   ooha.request_date,
                   ooha.ship_to_org_id,
                   ooha.invoice_to_org_id,
                   ooha.ordered_date,
                   ooha.creation_date,
                   ooha.attribute1
                       cancelled_date,
                   (SELECT name
                      FROM oe_transaction_types_tl otl
                     WHERE     otl.language = USERENV ('LANG')
                           AND otl.transaction_type_id = ooha.order_type_id)
                       source_order_type,
                   ooha.order_type_id,
                   ooha.ship_from_org_id,
                   ooha.salesrep_id,
                   ooha.price_list_id,
                   oola.tax_value,
                   DECODE (
                       oola.tax_value,
                       0, 0,
                       ROUND (
                           (oola.tax_value / (oola.ordered_quantity * oola.unit_selling_price)),
                           2))
                       tax_rate,
                   oola.line_id,
                   oola.line_number,
                   oola.ordered_item,
                   oola.creation_date
                       line_creation_date,
                   oola.ordered_quantity,
                   oola.latest_acceptable_date,
                   oola.schedule_ship_date,
                   oola.flow_status_code,
                   stg.error_message,
                   stg.status
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, oe_transaction_types_all ott,
                   xxd_ou_alignment_inbound_t stg
             WHERE     1 = 1
                   AND ooha.header_id = oola.header_id
                   AND ooha.order_number = stg.source_order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND stg.request_id = gn_request_id
                   AND NVL (ott.attribute5, 'XX') = 'BO'
                   AND ooha.order_category_code = 'ORDER'
                   AND ooha.open_flag = 'Y'
                   AND oola.cancelled_flag = 'N'
                   AND TRUNC (oola.request_date) >=
                       stg.source_order_request_date_from
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     wdd.source_header_id = ooha.header_id
                                   AND wdd.source_line_id = oola.line_id
                                   AND wdd.released_status IN ('S', 'Y', 'C'));

        l_header_rec                   OE_ORDER_PUB.Header_Rec_Type;
        l_header_rec_out               OE_ORDER_PUB.Header_Rec_Type;
        l_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type;
        l_line_rec                     OE_ORDER_PUB.Line_Rec_Type;
        l_line_rec1                    OE_ORDER_PUB.Line_Rec_Type;
        l_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        l_header_adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        l_line_adj_tbl                 OE_ORDER_PUB.line_adj_tbl_Type;
        l_header_scr_tbl               OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        l_line_scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        l_request_rec                  OE_ORDER_PUB.Request_Rec_Type;
        l_return_status                VARCHAR2 (1000);
        l_return_status1               VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := FND_API.G_FALSE;
        p_return_values                VARCHAR2 (10) := FND_API.G_FALSE;
        p_action_commit                VARCHAR2 (10) := FND_API.G_FALSE;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_old_header_rec               OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_old_header_val_rec           OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_old_Header_Adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_old_Header_Adj_val_tbl       OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_old_Header_Price_Att_tbl     OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_old_Header_Adj_Att_tbl       OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_old_Header_Adj_Assoc_tbl     OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_old_Header_Scredit_tbl       OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_old_Header_Scredit_val_tbl   OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_old_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_old_line_val_tbl             OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_old_Line_Adj_tbl             OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_old_Line_Adj_val_tbl         OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_old_Line_Price_Att_tbl       OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_old_Line_Adj_Att_tbl         OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_old_Line_Adj_Assoc_tbl       OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_old_Line_Scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_old_Line_Scredit_val_tbl     OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_old_Lot_Serial_tbl           OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_old_Lot_Serial_val_tbl       OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_REQUEST_TBL;
        x_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type;
        x_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        x_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type;
        x_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type;
        x_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type;
        x_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type;
        x_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        x_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type;
        x_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type;
        x_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        X_DEBUG_FILE                   VARCHAR2 (100);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);
    BEGIN
        -- insert the order lines into staging table

        FOR k IN lc_order_data
        LOOP
            BEGIN
                INSERT INTO XXD_OU_ALIGNMENT_LINES_T (
                                batch_id,
                                source_ou,
                                source_org_id,
                                source_customer,
                                source_order_number,
                                source_order_cust_po_number,
                                source_order_request_date,
                                source_order_ship_to_location,
                                source_order_bill_to_location,
                                source_order_ordered_date,
                                source_order_creation_date,
                                source_order_cancel_date,
                                source_order_type,
                                source_order_ship_from_warehouse,
                                source_order_sales_rep,
                                source_order_price_list,
                                source_order_line_tax_rate,
                                source_order_line_tax_amount,
                                source_line_id,
                                source_line_num,
                                source_order_line_ordered_item,
                                source_order_line_ordered_quantity,
                                source_order_line_latest_acceptable_date,
                                source_order_line_creation_date,
                                source_order_line_schedule_shipped_date,
                                source_order_line_flow_status_code,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                request_id,
                                error_message,
                                status)
                     VALUES (gn_batch_id, k.source_ou, k.source_org_id,
                             k.source_customer, k.order_number, k.cust_po_number, k.request_date, k.ship_to_org_id, k.invoice_to_org_id, k.ordered_date, k.creation_date, k.cancelled_date, k.source_order_type, k.ship_from_org_id, k.salesrep_id, k.price_list_id, k.tax_rate, k.tax_value, k.line_id, k.line_number, k.ordered_item, k.ordered_quantity, k.latest_acceptable_date, k.line_creation_date, k.schedule_ship_date, k.flow_status_code, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                             , gn_request_id, k.error_message, k.status);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error occured while inserting custom line data of bulk order'
                        || SQLERRM);
            END;
        END LOOP;

        COMMIT;


        DBMS_OUTPUT.enable (buffer_size => NULL); --50771 Deckers Order Management User - US eCommerce/50777 Deckers Order Management User - Canada eCommerce
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_resp_id,
                                    resp_appl_id   => gn_resp_appl_id);
        oe_msg_pub.initialize;
        oe_debug_pub.initialize;
        X_DEBUG_FILE   := OE_DEBUG_PUB.Set_Debug_Mode ('FILE');

        --This is to UPDATE order header
        FOR rec_order IN lh_bulk_orders
        LOOP
            mo_global.Set_org_context (rec_order.org_id, NULL, 'ONT');

            l_header_rec                   := oe_order_pub.g_miss_header_rec;
            l_header_rec.header_id         := rec_order.header_id;
            l_header_rec.operation         := OE_GLOBALS.G_OPR_UPDATE;
            l_header_rec.change_reason     := '1';
            l_header_rec.change_comments   :=
                'Cancelled by Deckers Sales Order Move Program';
            l_line_tbl_index               := 0;
            l_line_tbl.DELETE;

            FOR rec_update_order_lines
                IN ll_bulk_orders (rec_order.header_id)
            LOOP
                OE_LINE_UTIL.Lock_Row (
                    p_line_id         => rec_update_order_lines.line_id,
                    p_x_line_rec      => l_line_rec1,
                    x_return_status   => l_return_status);

                l_line_tbl_index                                 := l_line_tbl_index + 1;
                l_line_tbl (l_line_tbl_index)                    := l_line_rec1;
                l_line_tbl (l_line_tbl_index).line_id            :=
                    rec_update_order_lines.line_id;
                l_line_tbl (l_line_tbl_index).ordered_quantity   := 0;
                --            l_line_tbl (l_line_tbl_index).cancelled_flag := 'Y';
                l_line_tbl (l_line_tbl_index).change_reason      := '1';
                l_line_tbl (l_line_tbl_index).change_comments    :=
                    'Cancelled by Deckers Sales Order Move Program';
                l_line_tbl (l_line_tbl_index).operation          :=
                    OE_GLOBALS.G_OPR_UPDATE;
            END LOOP;

            -- CALL TO PROCESS ORDER
            OE_ORDER_PUB.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl, -- OUT PARAMETERS
                -- x_header_rec               => l_header_rec,
                x_header_rec               => l_header_rec_out,
                x_header_val_rec           => x_header_val_rec,
                x_Header_Adj_tbl           => x_Header_Adj_tbl,
                x_Header_Adj_val_tbl       => x_Header_Adj_val_tbl,
                x_Header_price_Att_tbl     => x_Header_price_Att_tbl,
                x_Header_Adj_Att_tbl       => x_Header_Adj_Att_tbl,
                x_Header_Adj_Assoc_tbl     => x_Header_Adj_Assoc_tbl,
                x_Header_Scredit_tbl       => x_Header_Scredit_tbl,
                x_Header_Scredit_val_tbl   => x_Header_Scredit_val_tbl,
                x_line_tbl                 => x_line_tbl,
                x_line_val_tbl             => x_line_val_tbl,
                x_Line_Adj_tbl             => x_Line_Adj_tbl,
                x_Line_Adj_val_tbl         => x_Line_Adj_val_tbl,
                x_Line_price_Att_tbl       => x_Line_price_Att_tbl,
                x_Line_Adj_Att_tbl         => x_Line_Adj_Att_tbl,
                x_Line_Adj_Assoc_tbl       => x_Line_Adj_Assoc_tbl,
                x_Line_Scredit_tbl         => x_Line_Scredit_tbl,
                x_Line_Scredit_val_tbl     => x_Line_Scredit_val_tbl,
                x_Lot_Serial_tbl           => x_Lot_Serial_tbl,
                x_Lot_Serial_val_tbl       => x_Lot_Serial_val_tbl,
                x_action_request_tbl       => l_action_request_tbl);

            -- Check the return status
            IF l_return_status <> FND_API.G_RET_STS_SUCCESS
            THEN
                -- Retrieve messages

                Oe_Msg_Pub.get (p_msg_index => 1, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                , p_msg_index_out => l_msg_index_out);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error message is: ' || l_msg_data);
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Failed to insert data ito interface table '
                || 'cancel_bulk_orders '
                || SQLERRM);
    END cancel_bulk_orders;

    PROCEDURE import_non_bulk_order
    IS
        CURSOR lc_org IS
            SELECT DISTINCT stg.original_ou, ooha.org_id, ooha.order_source_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') <> 'BO'
                   AND stg.status = 'PENDING'
                   AND stg.request_id = gn_request_id;

        CURSOR lc_order IS
            SELECT DISTINCT stg.original_ou, ooha.order_number, ooha.org_id,
                            ooha.order_source_id, ooha.orig_sys_document_ref
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') <> 'BO'
                   AND stg.status = 'PENDING'
                   AND stg.request_id = gn_request_id;

        CURSOR lc_update_line (p_order_number VARCHAR2)
        IS
              SELECT ooha.order_number, ooha.header_id, ooha.org_id,
                     sline.source_line_id, sline.request_id
                FROM oe_order_headers_all ooha, oe_order_lines_all oola, oe_transaction_types_all ott,
                     xxd_ou_alignment_inbound_t stg, xxd_ou_alignment_lines_t sline
               WHERE     ooha.header_id = oola.header_id
                     AND ooha.order_type_id = ott.transaction_type_id
                     AND NVL (ott.attribute5, 'XX') <> 'BO'
                     AND ooha.order_number = stg.source_order_number
                     AND stg.source_order_number = sline.source_order_number
                     AND oola.line_id = sline.source_line_id
                     AND sline.request_id = gn_request_id
                     AND ooha.open_flag = 'Y'
                     AND oola.cancelled_flag = 'N'
                     AND stg.status <> 'ERROR'
                     AND stg.request_id = gn_request_id
                     AND stg.source_order_number = p_order_number
            ORDER BY ooha.order_number, sline.source_line_id;

        CURSOR lc_requests IS
            SELECT request_id
              FROM xxd_order_import_requests
             WHERE     main_request_id = gn_request_id
                   AND order_type = 'NON_BULK';

        ln_request_id         NUMBER;
        ln_resp_id            NUMBER;
        ln_appl_id            NUMBER;
        ln_impor_err_cnt      NUMBER := 0;
        lc_phase              VARCHAR2 (50);
        lc_status             VARCHAR2 (50);
        lc_dev_phase          VARCHAR2 (50);
        lc_dev_status         VARCHAR2 (50);
        lc_message            VARCHAR2 (50);
        l_req_return_status   BOOLEAN;
    BEGIN
        FOR i IN lc_org
        LOOP
            -- get responsiblity id respective org

            BEGIN
                SELECT frv.responsibility_id, frv.application_id
                  INTO ln_resp_id, ln_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                       apps.hr_organization_units hou
                 WHERE     hou.organization_id = i.org_id
                       AND fpov.profile_option_value =
                           TO_CHAR (hou.organization_id)
                       AND fpo.profile_option_id = fpov.profile_option_id
                       AND fpo.user_profile_option_name =
                           'MO: Operating Unit'
                       AND frv.responsibility_id = fpov.level_value
                       AND frv.responsibility_name LIKE
                               'Deckers Order Management User%'
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        SELECT frv.responsibility_id, frv.application_id
                          INTO ln_resp_id, ln_appl_id
                          FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                               apps.hr_organization_units hou
                         WHERE     hou.organization_id = i.org_id
                               AND fpov.profile_option_value =
                                   TO_CHAR (hou.organization_id)
                               AND fpo.profile_option_id =
                                   fpov.profile_option_id
                               AND fpo.user_profile_option_name =
                                   'MO: Operating Unit'
                               AND frv.responsibility_id = fpov.level_value
                               AND frv.responsibility_name LIKE
                                       'Deckers Order Management Manager%'
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
            END;

            --Initialize
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', i.org_id);
            fnd_global.apps_initialize (gn_user_id, ln_resp_id, ln_appl_id);

            fnd_file.put_line (fnd_file.LOG, ln_resp_id || ln_appl_id);
            -- Submit Order Import
            ln_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'ONT',
                    program       => 'OEOIMP',
                    argument1     => i.org_id,               -- Operating Unit
                    argument2     => i.order_source_id,        -- Order Source
                    argument3     => NULL,                  -- Order Reference
                    argument4     => NULL,                   -- Operation Code
                    argument5     => 'N',                    -- Validate Only?
                    argument6     => NULL,                      -- Debug Level
                    argument7     => 4,                           -- Instances
                    argument8     => NULL,                   -- Sold To Org Id
                    argument9     => NULL,                      -- Sold To Org
                    argument10    => 8,                     -- Change Sequence
                    argument11    => NULL, -- Enable Single Line Queue for Instances
                    argument12    => 'N',              -- Trim Trailing Blanks
                    argument13    => NULL, -- Process Orders With No Org Specified
                    argument14    => NULL,           -- Default Operating Unit
                    argument15    => 'Y');   -- Validate Descriptive Flexfield

            IF NVL (ln_request_id, 0) = 0
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Error in Order Import Program');
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                'Sales Order Import request Id  ' || ln_request_id);

            COMMIT;

            IF ln_request_id > 0
            THEN
                INSERT INTO XXDO.xxd_order_import_requests
                     VALUES (gn_request_id, ln_request_id, 'NON_BULK');

                COMMIT;
            END IF;
        END LOOP;

        FOR m IN lc_requests
        LOOP
            LOOP
                l_req_return_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => m.request_id,
                        INTERVAL     => 5 --interval Number of seconds to wait between checks
                                         ,
                        max_wait     => 30 --Maximum number of seconds to wait for the request completion
                                          -- out arguments
                                          ,
                        phase        => lc_phase,
                        STATUS       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_message);
                fnd_file.put_line (fnd_file.LOG,
                                   'import_non_bulk_order looped');
                EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                          OR UPPER (lc_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END LOOP;

        -- check any errors while importing sales order

        FOR j IN lc_order
        LOOP
            ln_impor_err_cnt   := 0;

            BEGIN
                SELECT COUNT (*)
                  INTO ln_impor_err_cnt
                  FROM oe_order_headers_all ooha, oe_order_lines_all oola, xxd_ou_alignment_lines_t sline
                 WHERE     ooha.header_id = oola.header_id
                       AND ooha.order_number = sline.source_order_number
                       AND oola.line_id = sline.source_line_id
                       AND sline.request_id = gn_request_id
                       AND ooha.open_flag = 'Y'
                       AND oola.cancelled_flag = 'N'
                       AND ooha.order_number = j.order_number;

                fnd_file.put_line (
                    fnd_file.LOG,
                    ' No of Lines are not cancelled : ' || ln_impor_err_cnt);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            FOR k IN lc_update_line (j.order_number)
            LOOP
                UPDATE xxd_ou_alignment_lines_t lt
                   SET lt.status = 'ERROR', lt.error_message = ' Source Order line is not cancelled '
                 WHERE     lt.source_order_number = k.order_number
                       AND lt.source_line_id = k.source_line_id
                       AND lt.request_id = k.request_id;
            END LOOP;

            IF ln_impor_err_cnt > 0
            THEN
                UPDATE xxd_ou_alignment_inbound_t stg
                   SET stg.status = 'ERROR', stg.error_message = 'Source lines are not cancelled '
                 WHERE stg.source_order_number = j.order_number;
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error occured while importing sales order' || SQLERRM);
    END import_non_bulk_order;

    -- Import bulk order

    PROCEDURE import_bulk_order
    IS
        CURSOR lc_org IS
            SELECT DISTINCT stg.original_ou, ooha.org_id, ooha.order_source_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') = 'BO'
                   AND stg.status = 'PENDING'
                   AND stg.request_id = gn_request_id;

        CURSOR lc_order IS
            SELECT DISTINCT stg.original_ou, ooha.order_number, ooha.org_id,
                            ooha.order_source_id, ooha.orig_sys_document_ref
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') = 'BO'
                   AND stg.status = 'PENDING'
                   -- AND order_number = '89784863';
                   AND stg.request_id = gn_request_id;

        CURSOR lc_update_line (p_order_number VARCHAR2)
        IS
              SELECT ooha.order_number, ooha.header_id, ooha.org_id,
                     sline.source_line_id, sline.request_id
                FROM oe_order_headers_all ooha, oe_order_lines_all oola, oe_transaction_types_all ott,
                     xxd_ou_alignment_inbound_t stg, xxd_ou_alignment_lines_t sline
               WHERE     ooha.header_id = oola.header_id
                     AND ooha.order_type_id = ott.transaction_type_id
                     AND NVL (ott.attribute5, 'XX') = 'BO'
                     AND ooha.order_number = stg.source_order_number
                     AND stg.source_order_number = sline.source_order_number
                     AND oola.line_id = sline.source_line_id
                     AND sline.request_id = gn_request_id
                     AND ooha.open_flag = 'Y'
                     AND oola.cancelled_flag = 'N'
                     AND stg.status <> 'ERROR'
                     AND stg.request_id = gn_request_id
                     AND stg.source_order_number = p_order_number
            ORDER BY ooha.order_number, sline.source_line_id;

        CURSOR lc_requests IS
            SELECT request_id
              FROM xxd_order_import_requests
             WHERE main_request_id = gn_request_id AND order_type = 'BULK';

        ln_request_id         NUMBER;
        ln_resp_id            NUMBER;
        ln_appl_id            NUMBER;
        ln_impor_err_cnt      NUMBER := 0;
        lc_phase              VARCHAR2 (50);
        lc_status             VARCHAR2 (50);
        lc_dev_phase          VARCHAR2 (50);
        lc_dev_status         VARCHAR2 (50);
        lc_message            VARCHAR2 (50);
        l_req_return_status   BOOLEAN;
    BEGIN
        FOR j IN lc_order
        LOOP
            ln_impor_err_cnt   := 0;

            BEGIN
                SELECT COUNT (*)
                  INTO ln_impor_err_cnt
                  FROM oe_order_headers_all ooha, oe_order_lines_all oola, xxd_ou_alignment_lines_t sline
                 WHERE     ooha.header_id = oola.header_id
                       AND ooha.order_number = sline.source_order_number
                       AND oola.line_id = sline.source_line_id
                       AND sline.request_id = gn_request_id
                       AND ooha.open_flag = 'Y'
                       AND oola.cancelled_flag = 'N'
                       AND ooha.order_number = j.order_number;

                fnd_file.put_line (
                    fnd_file.LOG,
                    ' No of Lines are not cancelled : ' || ln_impor_err_cnt);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            FOR k IN lc_update_line (j.order_number)
            LOOP
                UPDATE xxd_ou_alignment_lines_t lt
                   SET lt.status = 'ERROR', lt.error_message = ' Source Order line is not cancelled '
                 WHERE     lt.source_order_number = k.order_number
                       AND lt.source_line_id = k.source_line_id
                       AND lt.request_id = k.request_id;
            END LOOP;

            IF ln_impor_err_cnt > 0
            THEN
                UPDATE xxd_ou_alignment_inbound_t stg
                   SET stg.status = 'ERROR', stg.error_message = 'Source lines are not cancelled '
                 WHERE stg.source_order_number = j.order_number;
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error occured while importing sales order' || SQLERRM);
    END import_bulk_order;

    --import target bulk orders

    PROCEDURE import_target_bulk_order
    IS
        CURSOR lc_org IS
            SELECT DISTINCT stg.target_ou, stg.target_org_id org_id, ooha.order_source_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') = 'BO'
                   AND stg.status = 'PENDING'
                   AND stg.request_id = gn_request_id;

        CURSOR lc_order IS
            SELECT DISTINCT stg.original_ou, ooha.order_number, (ooha.order_number || '-' || ooha.header_id) target_orig_sys_doc,
                            stg.target_org_id org_id, ooha.order_source_id, ooha.orig_sys_document_ref
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') = 'BO'
                   AND stg.status = 'PENDING'
                   AND stg.request_id = gn_request_id;

        CURSOR lc_requests IS
            SELECT request_id
              FROM xxd_order_import_requests
             WHERE main_request_id = gn_request_id AND order_type = 'T_BULK';

        ln_request_id         NUMBER;
        ln_resp_id            NUMBER;
        ln_appl_id            NUMBER;
        ln_impor_err_cnt      NUMBER := 0;
        lc_phase              VARCHAR2 (50);
        lc_status             VARCHAR2 (50);
        lc_dev_phase          VARCHAR2 (50);
        lc_dev_status         VARCHAR2 (50);
        lc_message            VARCHAR2 (50);
        l_req_return_status   BOOLEAN;
    BEGIN
        FOR i IN lc_org
        LOOP
            -- get responsiblity id respective org

            BEGIN
                SELECT frv.responsibility_id, frv.application_id
                  INTO ln_resp_id, ln_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                       apps.hr_organization_units hou
                 WHERE     hou.organization_id = i.org_id
                       AND fpov.profile_option_value =
                           TO_CHAR (hou.organization_id)
                       AND fpo.profile_option_id = fpov.profile_option_id
                       AND fpo.user_profile_option_name =
                           'MO: Operating Unit'
                       AND frv.responsibility_id = fpov.level_value
                       AND frv.responsibility_name LIKE
                               'Deckers Order Management User%'
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        SELECT frv.responsibility_id, frv.application_id
                          INTO ln_resp_id, ln_appl_id
                          FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                               apps.hr_organization_units hou
                         WHERE     hou.organization_id = i.org_id
                               AND fpov.profile_option_value =
                                   TO_CHAR (hou.organization_id)
                               AND fpo.profile_option_id =
                                   fpov.profile_option_id
                               AND fpo.user_profile_option_name =
                                   'MO: Operating Unit'
                               AND frv.responsibility_id = fpov.level_value
                               AND frv.responsibility_name LIKE
                                       'Deckers Order Management Manager%'
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
            END;

            --Initialize
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', i.org_id);
            fnd_global.apps_initialize (gn_user_id, ln_resp_id, ln_appl_id);
            -- Submit Order Impo
            ln_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'ONT',
                    program       => 'OEOIMP',
                    argument1     => i.org_id,               -- Operating Unit
                    argument2     => i.order_source_id,        -- Order Source
                    argument3     => NULL,                  -- Order Reference
                    argument4     => NULL,                   -- Operation Code
                    argument5     => 'N',                    -- Validate Only?
                    argument6     => NULL,                      -- Debug Level
                    argument7     => 4,                           -- Instances
                    argument8     => NULL,                   -- Sold To Org Id
                    argument9     => NULL,                      -- Sold To Org
                    argument10    => 10,                    -- Change Sequence
                    argument11    => NULL, -- Enable Single Line Queue for Instances
                    argument12    => 'N',              -- Trim Trailing Blanks
                    argument13    => NULL, -- Process Orders With No Org Specified
                    argument14    => NULL,           -- Default Operating Unit
                    argument15    => 'Y');   -- Validate Descriptive Flexfield

            IF NVL (ln_request_id, 0) = 0
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Error in Target Order Import Program');
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                'Target Sales Order Import request Id' || ln_request_id);

            COMMIT;

            IF ln_request_id > 0
            THEN
                INSERT INTO xxdo.xxd_order_import_requests
                     VALUES (gn_request_id, ln_request_id, 'T_BULK');

                COMMIT;
            END IF;
        END LOOP;

        FOR m IN lc_requests
        LOOP
            LOOP
                l_req_return_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => m.request_id,
                        INTERVAL     => 5 --interval Number of seconds to wait between checks
                                         ,
                        max_wait     => 30 --Maximum number of seconds to wait for the request completion
                                          -- out arguments
                                          ,
                        phase        => lc_phase,
                        STATUS       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_message);
                EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                          OR UPPER (lc_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END LOOP;


        -- check any errors while importing sales order

        FOR j IN lc_order
        LOOP
            BEGIN
                SELECT COUNT (*)
                  INTO ln_impor_err_cnt
                  FROM oe_order_headers_all ooha
                 WHERE     orig_sys_document_ref = j.target_orig_sys_doc
                       AND ooha.org_id = j.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_impor_err_cnt   := 0;
            END;

            IF ln_impor_err_cnt = 0
            THEN
                UPDATE xxd_ou_alignment_inbound_t
                   SET status = 'INCOMPLETE', error_message = 'Target order failed to create '
                 WHERE source_order_number = j.order_number;

                COMMIT;

                UPDATE xxd_ou_alignment_lines_t
                   SET status = 'INCOMPLETE', error_message = 'Target order failed to create '
                 WHERE source_order_number = j.order_number;

                COMMIT;
            ELSE
                UPDATE xxd_ou_alignment_inbound_t
                   SET status = 'COMPLETED', error_message = NULL
                 WHERE source_order_number = j.order_number;

                COMMIT;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error occured while importing sales order' || SQLERRM);
    END import_target_bulk_order;

    -- import target non bulk order

    PROCEDURE import_target_non_bulk_order
    IS
        CURSOR lc_org IS
            SELECT DISTINCT stg.target_ou, stg.target_org_id org_id, ooha.order_source_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') <> 'BO'
                   AND stg.status = 'PENDING'
                   AND stg.request_id = gn_request_id;

        CURSOR lc_order IS
            SELECT DISTINCT stg.original_ou, ooha.order_number, (ooha.order_number || '-' || ooha.header_id) target_orig_sys_doc,
                            stg.target_org_id org_id, ooha.order_source_id, ooha.orig_sys_document_ref
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha, oe_transaction_types_all ott
             WHERE     stg.source_order_number = ooha.order_number
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND NVL (ott.attribute5, 'XX') <> 'BO'
                   AND stg.status = 'PENDING'
                   -- AND order_number = '89784863';
                   AND stg.request_id = gn_request_id;

        CURSOR lc_requests IS
            SELECT request_id
              FROM xxd_order_import_requests
             WHERE main_request_id = gn_request_id AND order_type = 'T_NBULK';

        ln_request_id         NUMBER;
        ln_resp_id            NUMBER;
        ln_appl_id            NUMBER;
        ln_impor_err_cnt      NUMBER := 0;
        lc_phase              VARCHAR2 (50);
        lc_status             VARCHAR2 (50);
        lc_dev_phase          VARCHAR2 (50);
        lc_dev_status         VARCHAR2 (50);
        lc_message            VARCHAR2 (50);
        l_req_return_status   BOOLEAN;
    BEGIN
        FOR i IN lc_org
        LOOP
            -- get responsiblity id respective org

            BEGIN
                SELECT frv.responsibility_id, frv.application_id
                  INTO ln_resp_id, ln_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                       apps.hr_organization_units hou
                 WHERE     hou.organization_id = i.org_id
                       AND fpov.profile_option_value =
                           TO_CHAR (hou.organization_id)
                       AND fpo.profile_option_id = fpov.profile_option_id
                       AND fpo.user_profile_option_name =
                           'MO: Operating Unit'
                       AND frv.responsibility_id = fpov.level_value
                       AND frv.responsibility_name LIKE
                               'Deckers Order Management User%'
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        SELECT frv.responsibility_id, frv.application_id
                          INTO ln_resp_id, ln_appl_id
                          FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                               apps.hr_organization_units hou
                         WHERE     hou.organization_id = i.org_id
                               AND fpov.profile_option_value =
                                   TO_CHAR (hou.organization_id)
                               AND fpo.profile_option_id =
                                   fpov.profile_option_id
                               AND fpo.user_profile_option_name =
                                   'MO: Operating Unit'
                               AND frv.responsibility_id = fpov.level_value
                               AND frv.responsibility_name LIKE
                                       'Deckers Order Management Manager%'
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
            END;

            --Initialize
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', i.org_id);
            fnd_global.apps_initialize (gn_user_id, ln_resp_id, ln_appl_id);
            -- Submit Order Impo
            ln_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'ONT',
                    program       => 'OEOIMP',
                    argument1     => i.org_id,               -- Operating Unit
                    argument2     => i.order_source_id,        -- Order Source
                    argument3     => NULL,                  -- Order Reference
                    argument4     => NULL,                   -- Operation Code
                    argument5     => 'N',                    -- Validate Only?
                    argument6     => NULL,                      -- Debug Level
                    argument7     => 4,                           -- Instances
                    argument8     => NULL,                   -- Sold To Org Id
                    argument9     => NULL,                      -- Sold To Org
                    argument10    => 10,                    -- Change Sequence
                    argument11    => NULL, -- Enable Single Line Queue for Instances
                    argument12    => 'N',              -- Trim Trailing Blanks
                    argument13    => NULL, -- Process Orders With No Org Specified
                    argument14    => NULL,           -- Default Operating Unit
                    argument15    => 'Y');   -- Validate Descriptive Flexfield

            IF NVL (ln_request_id, 0) = 0
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Error in Target Order Import Program');
            END IF;


            fnd_file.put_line (
                fnd_file.LOG,
                'Target Sales Order Import request Id ' || ln_request_id);

            COMMIT;

            IF ln_request_id > 0
            THEN
                INSERT INTO xxdo.xxd_order_import_requests
                     VALUES (gn_request_id, ln_request_id, 'T_NBULK');

                COMMIT;
            END IF;
        END LOOP;

        FOR m IN lc_requests
        LOOP
            LOOP
                l_req_return_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => m.request_id,
                        INTERVAL     => 5 --interval Number of seconds to wait between checks
                                         ,
                        max_wait     => 30 --Maximum number of seconds to wait for the request completion
                                          -- out arguments
                                          ,
                        phase        => lc_phase,
                        STATUS       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_message);
                EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                          OR UPPER (lc_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END LOOP;

        -- check any errors while importing sales order

        FOR j IN lc_order
        LOOP
            BEGIN
                SELECT COUNT (*)
                  INTO ln_impor_err_cnt
                  FROM oe_order_headers_all ooha
                 WHERE     orig_sys_document_ref = j.target_orig_sys_doc
                       AND ooha.org_id = j.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_impor_err_cnt   := 0;
            END;

            IF ln_impor_err_cnt = 0
            THEN
                UPDATE xxd_ou_alignment_inbound_t
                   SET status = 'INCOMPLETE', error_message = 'Target order failed to create '
                 WHERE source_order_number = j.order_number;

                COMMIT;
            ELSE
                UPDATE xxd_ou_alignment_inbound_t
                   SET status = 'COMPLETED', error_message = NULL
                 WHERE source_order_number = j.order_number;

                COMMIT;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error occured while importing sales order' || SQLERRM);
    END import_target_non_bulk_order;


    PROCEDURE update_order_details
    IS
        CURSOR lc_new_order IS
            SELECT ooha.order_number
                       source_order_number,
                   ooha.header_id,
                   ooha.org_id,
                   ooha.creation_Date,
                   ooha.created_by,
                   (SELECT hou.name
                      FROM hr_operating_units hou
                     WHERE hou.organization_id = ooha1.org_id)
                       target_ou,
                   ooha1.org_id
                       new_org_id,
                   ooha1.header_id
                       new_header_id,
                   ooha1.order_number
                       new_order_number,
                   ooha1.ordered_date
                       new_ordered_date,
                   ooha1.cust_po_number,
                   ooha1.request_date,
                   ooha1.ship_to_org_id,
                   ooha1.invoice_to_org_id,
                   ooha1.price_list_id,
                   ooha1.creation_date
                       new_order_creation_date,
                   ooha1.created_by
                       new_order_created_by,
                   ooha1.ship_from_org_id,
                   ooha1.attribute1
                       new_cancelled_date,
                   ooha1.salesrep_id,
                   (SELECT name
                      FROM oe_transaction_types_tl otl
                     WHERE     otl.language = USERENV ('LANG')
                           AND otl.transaction_type_id = ooha1.order_type_id)
                       new_order_type,
                   (SELECT account_number
                      FROM hz_cust_accounts
                     WHERE cust_account_id = ooha1.sold_to_org_id)
                       new_cust_account,
                   stg.error_message,
                   stg.status
              FROM oe_order_headers_all ooha1, xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha
             WHERE     1 = 1
                   AND stg.request_id = gn_request_id
                   AND stg.source_order_number =
                       SUBSTR (
                           ooha1.orig_sys_document_ref,
                           1,
                           INSTR (ooha1.orig_sys_document_ref, '-', 1) - 1)
                   AND ooha1.org_id = stg.target_org_id
                   --AND ooha1.request_date        >= '01-JAN-2023'
                   AND ooha1.flow_status_code = 'BOOKED'
                   AND stg.source_order_number = ooha.order_number
                   AND stg.source_org_id = ooha.org_id
                   AND NVL (stg.status, 'X') = 'COMPLETED';

        CURSOR lc_new_order_line IS
            SELECT ooha.order_number
                       source_order_number,
                   ooha.header_id,
                   ooha.org_id,
                   ooha.creation_Date,
                   ooha.created_by,
                   oola.line_id,
                   sline.source_line_id,
                   sline.source_order_line_creation_date,
                   oola.created_by
                       order_line_creation_by,
                   --    oola.updated_by order_line_updated_by,
                   oola.creation_date
                       order_line_creation_date,
                   (SELECT hou.name
                      FROM hr_operating_units hou
                     WHERE hou.organization_id = ooha1.org_id)
                       target_ou,
                   ooha1.org_id
                       new_org_id,
                   ooha1.header_id
                       new_header_id,
                   ooha1.order_number
                       new_order_number,
                   ooha1.ordered_date
                       new_ordered_date,
                   ooha1.cust_po_number,
                   ooha1.request_date,
                   ooha1.ship_to_org_id,
                   ooha1.invoice_to_org_id,
                   ooha1.price_list_id,
                   ooha1.creation_date
                       new_order_creation_date,
                   ooha1.created_by
                       new_order_created_by,
                   ooha1.ship_from_org_id,
                   ooha1.attribute1
                       new_cancelled_date,
                   ooha1.salesrep_id,
                   (SELECT name
                      FROM oe_transaction_types_tl otl
                     WHERE     otl.language = USERENV ('LANG')
                           AND otl.transaction_type_id = ooha1.order_type_id)
                       new_order_type,
                   (SELECT account_number
                      FROM hz_cust_accounts
                     WHERE cust_account_id = ooha1.sold_to_org_id)
                       new_cust_account,
                   stg.error_message,
                   stg.status
              FROM oe_order_headers_all ooha1, xxd_ou_alignment_inbound_t stg, xxd_ou_alignment_lines_t sline,
                   oe_order_headers_all ooha, oe_order_lines_all oola
             -- oe_order_lines_all           oola1
             WHERE     1 = 1
                   AND stg.request_id = gn_request_id
                   AND stg.source_order_number =
                       SUBSTR (
                           ooha1.orig_sys_document_ref,
                           1,
                           INSTR (ooha1.orig_sys_document_ref, '-', 1) - 1)
                   AND ooha1.org_id = stg.target_org_id
                   --  AND ooha1.request_date        >= '01-JAN-2023'
                   AND ooha1.flow_status_code = 'BOOKED'
                   AND stg.source_order_number = ooha.order_number
                   AND ooha1.header_id = oola.header_id
                   AND stg.source_org_id = ooha.org_id
                   AND stg.source_order_number = sline.source_order_number
                   --AND ooha.header_id            = oola1.header_id
                   -- AND sline.source_line_id      = oola1.line_id
                   AND SUBSTR (oola.orig_sys_line_ref,
                               1,
                                 INSTR (oola.orig_sys_line_ref, '-', 1,
                                        2)
                               - 1) =
                       (sline.source_order_number || '-' || sline.source_line_id)
                   --  AND oola.orig_sys_line_ref = (sline.source_order_number || '-' || sline.source_line_num || '-' || oola.shipment_number)
                   AND stg.request_id = sline.request_id
                   AND NVL (stg.status, 'X') = 'COMPLETED';

        CURSOR lc_order IS
            SELECT stg.source_order_number
              FROM xxd_ou_alignment_inbound_t stg
             WHERE     1 = 1
                   AND stg.request_id = gn_request_id
                   AND NVL (stg.status, 'X') = 'COMPLETED'
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_ou_alignment_lines_t sline
                             WHERE     sline.request_id = stg.request_id
                                   AND sline.source_order_number =
                                       stg.source_order_number
                                   AND sline.status = 'PENDING');

        CURSOR lc_bulk IS
              SELECT stg.source_order_number,
                     stg.request_id,
                     SUBSTR (SUBSTR (oola.orig_sys_line_ref,
                                     1,
                                       INSTR (oola.orig_sys_line_ref, '-', 1,
                                              2)
                                     - 1),
                             INSTR (oola.orig_sys_line_ref, '-', 1) + 1)
                         source_line_id,
                     (SELECT hou.name
                        FROM hr_operating_units hou
                       WHERE hou.organization_id = oohan.org_id)
                         target_ou,
                     oohan.org_id
                         target_org_id,
                     (SELECT account_number
                        FROM hz_cust_accounts
                       WHERE cust_account_id = oohan.sold_to_org_id)
                         target_customer,
                     oohan.order_number
                         target_order_number,
                     oohan.cust_po_number
                         target_order_cust_po_number,
                     oohan.request_date
                         target_order_request_date,
                     oola.ship_to_org_id
                         target_order_ship_to_location,
                     oohan.invoice_to_org_id
                         target_order_bill_to_location,
                     oohan.ordered_date
                         target_order_ordered_date,
                     oohan.creation_date
                         target_order_creation_date,
                     oohan.attribute1
                         target_order_cancel_date,
                     (SELECT name
                        FROM oe_transaction_types_tl otl
                       WHERE     otl.language = USERENV ('LANG')
                             AND otl.transaction_type_id = oohan.order_type_id)
                         target_order_type,
                     oohan.ship_from_org_id
                         target_order_ship_from_warehouse,
                     oohan.salesrep_id
                         target_order_sales_rep,
                     oohan.price_list_id
                         target_order_price_list,
                     oola.tax_value
                         target_order_line_tax_amount,
                     DECODE (
                         oola.tax_value,
                         0, 0,
                         DECODE (
                             oola.ordered_quantity,
                             0, 0,
                             ROUND (
                                 (oola.tax_value / (oola.ordered_quantity * oola.unit_selling_price)),
                                 2)))
                         target_order_line_tax_rate,
                     oola.line_id
                         target_line_id,
                     oola.line_number
                         target_line_num,
                     oola.ordered_item
                         target_order_line_ordered_item,
                     oola.ordered_quantity
                         target_order_line_ordered_quantity,
                     oola.latest_acceptable_date
                         target_order_line_latest_acceptable_date,
                     oola.creation_date
                         target_order_line_creation_date,
                     oola.schedule_ship_date
                         target_order_line_schedule_shipped_date,
                     oola.flow_status_code
                         target_order_flow_status_code,
                     stg.error_message
                FROM oe_order_headers_all oohan, xxd_ou_alignment_inbound_t stg, oe_order_lines_all oola
               WHERE     1 = 1
                     AND stg.request_id = gn_request_id
                     AND stg.source_order_number =
                         SUBSTR (
                             oohan.orig_sys_document_ref,
                             1,
                             INSTR (oohan.orig_sys_document_ref, '-', 1) - 1)
                     AND oohan.org_id = stg.target_org_id
                     -- AND oohan.request_date >= '01-JAN-2023'
                     AND oohan.flow_status_code = 'BOOKED'
                     AND oohan.header_id = oola.header_id(+)
                     AND NVL (stg.status, 'X') <> 'ERROR'
            ORDER BY oohan.header_id, oola.line_id;

        TYPE target_rec IS RECORD
        (
            source_order_number                         VARCHAR2 (60),
            request_id                                  NUMBER,
            source_line_id                              NUMBER,
            target_ou                                   VARCHAR2 (150),
            target_org_id                               NUMBER,
            target_customer                             VARCHAR2 (150),
            target_order_number                         VARCHAR2 (60),
            target_order_cust_po_number                 VARCHAR2 (150),
            target_order_request_date                   DATE,
            target_order_ship_to_location               NUMBER,
            target_order_bill_to_location               NUMBER,
            target_order_ordered_date                   DATE,
            target_order_creation_date                  DATE,
            target_order_cancel_date                    VARCHAR2 (240),
            target_order_type                           VARCHAR2 (150),
            target_order_ship_from_warehouse            VARCHAR2 (150),
            target_order_sales_rep                      NUMBER,
            target_order_price_list                     NUMBER,
            target_order_line_tax_amount                NUMBER,
            target_order_line_tax_rate                  NUMBER,
            target_line_id                              NUMBER,
            target_line_num                             NUMBER,
            target_order_line_ordered_item              VARCHAR2 (2000),
            target_order_line_ordered_quantity          NUMBER,
            target_order_line_latest_acceptable_date    DATE,
            target_order_line_creation_date             DATE,
            target_order_line_schedule_shipped_date     DATE,
            target_order_flow_status_code               VARCHAR2 (30),
            error_message                               VARCHAR2 (2000)
        );

        TYPE target_info_t IS TABLE OF target_rec
            INDEX BY BINARY_INTEGER;

        l_target_order     target_info_t;

        ln_impor_err_cnt   NUMBER;
    BEGIN
        FOR k IN lc_new_order
        LOOP
            BEGIN
                UPDATE OE_ORDER_HEADERS_ALL hdr
                   SET hdr.created_by = k.created_by, hdr.creation_date = k.creation_date
                 WHERE hdr.header_id = k.new_header_id;
            --  COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error occured at header and line update' || SQLERRM);
            END;
        --   COMMIT;

        END LOOP;

        COMMIT;

        FOR j IN lc_new_order_line
        LOOP
            BEGIN
                UPDATE OE_ORDER_LINES_ALL LN
                   SET LN.created_by = j.created_by, LN.creation_date = j.source_order_line_creation_date
                 WHERE     LN.header_id = j.new_header_id
                       AND LN.line_id = j.line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;

        OPEN lc_bulk;

        LOOP
            FETCH lc_bulk BULK COLLECT INTO l_target_order;

            EXIT WHEN lc_bulk%NOTFOUND;
        END LOOP;

        CLOSE lc_bulk;

        fnd_file.put_line (fnd_file.LOG,
                           'No of order lines' || l_target_order.COUNT);

        FORALL i IN 1 .. l_target_order.COUNT
            UPDATE xxdo.xxd_ou_alignment_lines_t sline
               SET sline.target_ou = l_target_order (i).target_ou, sline.target_org_id = l_target_order (i).target_org_id, sline.target_customer = l_target_order (i).target_customer,
                   sline.target_order_number = l_target_order (i).target_order_number, sline.target_order_cust_po_number = l_target_order (i).target_order_cust_po_number, sline.target_order_request_date = l_target_order (i).target_order_request_date,
                   sline.target_order_ship_to_location = l_target_order (i).target_order_ship_to_location, sline.target_order_bill_to_location = l_target_order (i).target_order_bill_to_location, sline.target_order_ordered_date = l_target_order (i).target_order_ordered_date,
                   sline.target_order_creation_date = l_target_order (i).target_order_creation_date, sline.target_order_cancel_date = l_target_order (i).target_order_cancel_date, sline.target_order_type = l_target_order (i).target_order_type,
                   sline.target_order_ship_from_warehouse = l_target_order (i).target_order_ship_from_warehouse, sline.target_order_sales_rep = l_target_order (i).target_order_sales_rep, sline.target_order_price_list = l_target_order (i).target_order_price_list,
                   sline.target_order_line_tax_rate = l_target_order (i).target_order_line_tax_rate, sline.target_order_line_tax_amount = l_target_order (i).target_order_line_tax_amount, sline.target_line_id = l_target_order (i).target_line_id,
                   sline.target_line_num = l_target_order (i).target_line_num, sline.target_order_line_ordered_item = l_target_order (i).target_order_line_ordered_item, sline.target_order_line_ordered_quantity = l_target_order (i).target_order_line_ordered_quantity,
                   sline.target_order_line_latest_acceptable_date = l_target_order (i).target_order_line_latest_acceptable_date, sline.target_order_line_creation_date = l_target_order (i).target_order_line_creation_date, sline.target_order_line_schedule_shipped_date = l_target_order (i).target_order_line_schedule_shipped_date,
                   sline.target_order_line_flow_status_code = l_target_order (i).target_order_flow_status_code, sline.error_message = l_target_order (i).error_message, sline.status = 'COMPLETED'
             WHERE     sline.source_order_number =
                       l_target_order (i).source_order_number
                   AND sline.source_line_id =
                       l_target_order (i).source_line_id
                   AND sline.request_id = l_target_order (i).request_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error occured at main ' || SQLERRM);
    END update_order_details;

    -- validate the load data
    PROCEDURE validate_load_data
    IS
        CURSOR lv_data IS
            SELECT stg.original_ou, stg.source_customer, stg.source_order_number,
                   stg.source_order_request_date_from, stg.source_order_request_date_to, stg.target_ou,
                   stg.target_customer, stg.target_ship_to_location, stg.target_bill_to_location,
                   ooha.org_id, ooha.order_number, ooha.ship_to_org_id,
                   ooha.invoice_to_org_id
              FROM xxd_ou_alignment_inbound_t stg, oe_order_headers_all ooha
             WHERE     stg.status = 'NEW'
                   AND stg.request_id = gn_request_id
                   AND stg.source_order_number = ooha.order_number;

        --
        ln_rec_fail             NUMBER;
        ln_rec_total            NUMBER;
        ln_rec_success          NUMBER;
        lv_message              VARCHAR2 (32000);
        lv_recipients           VARCHAR2 (4000);
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        lv_inst_name            VARCHAR2 (30) := NULL;
        lv_msg                  VARCHAR2 (4000) := NULL;
        ln_ret_val              NUMBER := 0;
        lv_out_line             VARCHAR2 (4000);
        lv_error_message        VARCHAR2 (32000);
        lv_error_reason         VARCHAR2 (240);
        lv_breif_err_resol      VARCHAR2 (240);
        lv_comments             VARCHAR2 (240);
        ln_counter              NUMBER;
        lv_invoice_type         VARCHAR2 (20);
        ln_err_count            NUMBER := 0;
        ln_source_org_id        NUMBER;
        ln_target_org_id        NUMBER;
        lv_target_customer      VARCHAR2 (150);
        ln_ship_to_org_id       NUMBER;
        ln_bill_to_org_id       NUMBER;
        ln_ord_cnt              NUMBER;
    BEGIN
        ln_rec_fail      := 0;
        ln_rec_total     := 0;
        ln_rec_success   := 0;

        FOR i IN lv_data
        LOOP
            ln_err_count       := 0;
            lv_error_message   := '';

            IF i.original_ou IS NULL
            THEN
                ln_err_count       := ln_err_count + 1;
                lv_error_message   := ' Source Operating Unit is Blank ';
            END IF;

            BEGIN
                SELECT organization_id
                  INTO ln_source_org_id
                  FROM hr_operating_units
                 WHERE name = i.original_ou;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_err_count   := ln_err_count + 1;
                    lv_error_message   :=
                        lv_error_message || ',' || ' Source OU is invalid ';
            END;

            BEGIN
                SELECT organization_id
                  INTO ln_target_org_id
                  FROM hr_operating_units
                 WHERE name = i.target_ou;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_target_org_id   := 0;
                    ln_err_count       := ln_err_count + 1;
                    lv_error_message   :=
                        lv_error_message || ',' || ' Target OU is invalid ';
            END;

            IF i.source_customer IS NULL
            THEN
                ln_err_count   := ln_err_count + 1;
                lv_error_message   :=
                    lv_error_message || ',' || ' Source Customer is Blank ';
            END IF;

            IF i.target_customer IS NULL
            THEN
                BEGIN
                    SELECT hca.account_number
                      INTO lv_target_customer
                      FROM fnd_lookup_values flv, hz_cust_accounts hca
                     WHERE     flv.lookup_type = 'XXD_ONT_MOVE_CUST_MAP_LKP'
                           AND flv.language = 'US'
                           AND flv.attribute3 = hca.account_number
                           AND flv.attribute1 = i.source_customer
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_err_count   := ln_err_count + 1;
                        lv_error_message   :=
                               lv_error_message
                            || ','
                            || ' Target customer mapping doesnot exist in lookup XXD_ONT_MOVE_CUST_MAP_LKP ';
                END;
            END IF;

            IF i.source_order_number IS NULL
            THEN
                ln_err_count   := ln_err_count + 1;
                lv_error_message   :=
                       lv_error_message
                    || ','
                    || ' Source order number is Blank ';
            END IF;

            IF i.source_order_number IS NOT NULL
            THEN
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_ord_cnt
                      FROM oe_order_headers_all ooha
                     WHERE     ooha.order_number = i.source_order_number
                           AND ooha.flow_status_code = 'BOOKED';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_err_count   := ln_err_count + 1;
                        lv_error_message   :=
                               lv_error_message
                            || ','
                            || ' Source order number is invalid ';
                END;

                IF ln_ord_cnt = 0
                THEN
                    ln_err_count   := ln_err_count + 1;
                    lv_error_message   :=
                           lv_error_message
                        || ','
                        || ' Source order number is not in booked status ';
                END IF;
            END IF;

            IF i.target_ou IS NULL
            THEN
                ln_err_count   := ln_err_count + 1;

                lv_error_message   :=
                       lv_error_message
                    || ','
                    || ' Target Operating Unit is Blank ';
            END IF;

            IF i.target_ship_to_location IS NULL
            THEN
                BEGIN
                    SELECT thcsua.site_use_id
                      INTO ln_ship_to_org_id
                      FROM hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa, hz_party_sites hps,
                           hz_locations hl, fnd_lookup_values flv, hz_cust_accounts shca,
                           hz_party_sites thps, hz_locations thl, hz_cust_accounts thca,
                           hz_cust_acct_sites_all thcasa, hz_cust_site_uses_all thcsua
                     WHERE     hcsua.site_use_id = i.ship_to_org_id
                           AND hcsua.cust_acct_site_id =
                               hcasa.cust_acct_site_id
                           AND hcasa.party_site_id = hps.party_site_id
                           AND hcsua.LOCATION = Thcsua.LOCATION
                           AND hl.location_id = hps.location_id
                           AND thl.location_id = thps.location_id
                           AND NVL (hl.address1, 0) = NVL (thl.address1, 0)
                           AND NVL (hl.address2, 0) = NVL (thl.address2, 0)
                           AND NVL (hl.address3, 0) = NVL (thl.address3, 0)
                           AND NVL (hl.address4, 0) = NVL (thl.address4, 0)
                           AND hps.party_site_number = flv.attribute2
                           AND hcasa.cust_account_id = shca.cust_account_id
                           AND flv.attribute1 = shca.account_number
                           AND flv.attribute4 = thps.party_site_number
                           AND thps.party_site_id = thcasa.party_site_id
                           AND thps.party_id = thca.party_id
                           AND thca.account_number = flv.attribute3
                           AND thca.cust_Account_id = thcasa.cust_account_id
                           AND thcasa.cust_acct_site_id =
                               thcsua.cust_acct_site_id
                           AND flv.lookup_type = 'XXD_ONT_MOVE_CUST_MAP_LKP'
                           AND flv.language = 'US'
                           AND flv.attribute5 = 'SHIP_TO';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        BEGIN
                            SELECT thcsua.site_use_id bill_to_org_id
                              INTO ln_ship_to_org_id
                              FROM hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa, hz_party_sites hps,
                                   hz_locations hl, fnd_lookup_values flv, hz_party_sites thps,
                                   hz_locations thl, hz_cust_accounts thca, hz_cust_acct_sites_all thcasa,
                                   hz_cust_site_uses_all thcsua
                             WHERE     hcsua.site_use_id = i.ship_to_org_id
                                   AND flv.attribute1 = i.source_customer
                                   AND hcsua.cust_acct_site_id =
                                       hcasa.cust_acct_site_id
                                   AND hcasa.party_site_id =
                                       hps.party_site_id
                                   AND hcsua.LOCATION = Thcsua.LOCATION
                                   AND hl.location_id = hps.location_id
                                   AND thl.location_id = thps.location_id
                                   AND NVL (hl.address1, 0) =
                                       NVL (thl.address1, 0)
                                   AND NVL (hl.address2, 0) =
                                       NVL (thl.address2, 0)
                                   AND NVL (hl.address3, 0) =
                                       NVL (thl.address3, 0)
                                   AND NVL (hl.address4, 0) =
                                       NVL (thl.address4, 0)
                                   AND hps.party_site_number = flv.attribute2
                                   AND flv.attribute4 =
                                       thps.party_site_number
                                   AND thps.party_site_id =
                                       thcasa.party_site_id
                                   AND thps.party_id = thca.party_id
                                   AND thca.account_number = flv.attribute3
                                   AND thca.cust_Account_id =
                                       thcasa.cust_account_id
                                   AND thcasa.cust_acct_site_id =
                                       thcsua.cust_acct_site_id
                                   AND flv.lookup_type =
                                       'XXD_ONT_MOVE_CUST_MAP_LKP'
                                   AND flv.language = 'US'
                                   AND flv.attribute5 = 'SHIP_TO';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_err_count   := ln_err_count + 1;
                                lv_error_message   :=
                                       lv_error_message
                                    || ','
                                    || ' Target Ship to Lcoation  mapping doesnot exist in lookup XXD_ONT_MOVE_CUST_MAP_LKP ';
                        END;
                END;
            END IF;


            IF i.target_bill_to_location IS NULL
            THEN
                BEGIN
                    SELECT thcsua.site_use_id
                      INTO ln_bill_to_org_id
                      FROM hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa, hz_party_sites hps,
                           hz_locations hl, fnd_lookup_values flv, hz_cust_accounts shca,
                           hz_party_sites thps, hz_locations thl, hz_cust_accounts thca,
                           hz_cust_acct_sites_all thcasa, hz_cust_site_uses_all thcsua
                     WHERE     hcsua.site_use_id = i.invoice_to_org_id
                           AND hcsua.cust_acct_site_id =
                               hcasa.cust_acct_site_id
                           AND hcasa.party_site_id = hps.party_site_id
                           AND hps.party_site_number = flv.attribute2
                           AND hcasa.cust_account_id = shca.cust_account_id
                           AND flv.attribute1 = shca.account_number
                           AND flv.attribute4 = thps.party_site_number
                           AND hl.location_id = hps.location_id
                           AND thl.location_id = thps.location_id
                           AND NVL (hl.address1, 0) = NVL (thl.address1, 0)
                           AND NVL (hl.address2, 0) = NVL (thl.address2, 0)
                           AND NVL (hl.address3, 0) = NVL (thl.address3, 0)
                           AND NVL (hl.address4, 0) = NVL (thl.address4, 0)
                           AND thps.party_site_id = thcasa.party_site_id
                           AND thps.party_id = thca.party_id
                           AND thca.account_number = flv.attribute3
                           AND thca.cust_Account_id = thcasa.cust_account_id
                           AND thcasa.cust_acct_site_id =
                               thcsua.cust_acct_site_id
                           AND flv.lookup_type = 'XXD_ONT_MOVE_CUST_MAP_LKP'
                           AND flv.language = 'US'
                           AND flv.attribute5 = 'BILL_TO';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        BEGIN
                            SELECT thcsua.site_use_id bill_to_org_id
                              INTO ln_bill_to_org_id
                              FROM hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa, hz_party_sites hps,
                                   hz_locations hl, fnd_lookup_values flv, hz_party_sites thps,
                                   hz_locations thl, hz_cust_accounts thca, hz_cust_acct_sites_all thcasa,
                                   hz_cust_site_uses_all thcsua
                             WHERE     hcsua.site_use_id =
                                       i.invoice_to_org_id
                                   AND flv.attribute1 = i.source_customer
                                   AND hcsua.cust_acct_site_id =
                                       hcasa.cust_acct_site_id
                                   AND hcasa.party_site_id =
                                       hps.party_site_id
                                   AND hps.party_site_number = flv.attribute2
                                   AND flv.attribute4 =
                                       thps.party_site_number
                                   AND hl.location_id = hps.location_id
                                   AND thl.location_id = thps.location_id
                                   AND NVL (hl.address1, 0) =
                                       NVL (thl.address1, 0)
                                   AND NVL (hl.address2, 0) =
                                       NVL (thl.address2, 0)
                                   AND NVL (hl.address3, 0) =
                                       NVL (thl.address3, 0)
                                   AND NVL (hl.address4, 0) =
                                       NVL (thl.address4, 0)
                                   AND thps.party_site_id =
                                       thcasa.party_site_id
                                   AND thps.party_id = thca.party_id
                                   AND thca.account_number = flv.attribute3
                                   AND thca.cust_Account_id =
                                       thcasa.cust_account_id
                                   AND thcasa.cust_acct_site_id =
                                       thcsua.cust_acct_site_id
                                   AND flv.lookup_type =
                                       'XXD_ONT_MOVE_CUST_MAP_LKP'
                                   AND flv.language = 'US'
                                   AND flv.attribute5 = 'BILL_TO';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_err_count   := ln_err_count + 1;
                                lv_error_message   :=
                                       lv_error_message
                                    || ','
                                    || ' Target Bill to Location  mapping doesnot exist in lookup XXD_ONT_MOVE_CUST_MAP_LKP ';
                        END;
                END;
            END IF;

            IF ln_err_count > 0
            THEN
                BEGIN
                    UPDATE xxd_ou_alignment_inbound_t
                       SET error_message = SUBSTR (lv_error_message, 1, 2000), status = 'ERROR', source_org_id = ln_source_org_id,
                           target_org_id = ln_target_org_id, target_customer = NVL (i.target_customer, lv_target_customer)
                     WHERE source_order_number = i.source_order_number;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error occured while updating the status in validate the data '
                            || SQLERRM);
                END;
            ELSE
                BEGIN
                    UPDATE xxd_ou_alignment_inbound_t
                       SET source_org_id = ln_source_org_id, target_org_id = ln_target_org_id, target_customer = NVL (i.target_customer, lv_target_customer),
                           status = 'PENDING'
                     WHERE source_order_number = i.source_order_number;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error occured while updating the status in validate the data '
                            || SQLERRM);
                END;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Failed to validate the data ' || SQLERRM);
    END validate_load_data;

    -- get target order type

    FUNCTION get_target_order_type (p_source_org_id IN NUMBER, p_target_org_id IN NUMBER, p_source_type_id IN NUMBER)
        RETURN NUMBER
    IS
        l_target_type_id   NUMBER;
    BEGIN
        SELECT TO_NUMBER (attribute4)
          INTO l_target_type_id
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_ONT_MOVE_ORD_TYPE_MAP_LKP'
               AND language = 'US'
               AND TO_NUMBER (attribute1) = p_source_org_id
               AND TO_NUMBER (attribute2) = p_target_org_id
               AND TO_NUMBER (attribute3) = p_source_type_id;

        RETURN l_target_type_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unable to get the target order type, mapping doesnot exist in the lookup XXD_ONT_MOVE_ORD_TYPE_MAP_LKP');
            RETURN 0;
    END get_target_order_type;


    -- get target salesrep

    FUNCTION get_target_salesrep (p_salesreps_id    IN NUMBER,
                                  p_target_org_id   IN NUMBER)
        RETURN NUMBER
    IS
        l_target_salesrep_id   NUMBER;
        lv_salesrep_name       VARCHAR2 (240);
    BEGIN
        BEGIN
            SELECT jrr.resource_name
              INTO lv_salesrep_name
              FROM jtf_rs_salesreps jrs, jtf_rs_resource_extns_tl jrr
             WHERE     jrs.salesrep_id = p_salesreps_id            --100147048
                   AND jrs.resource_id = jrr.resource_id(+)
                   AND jrr.language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_salesrep_name   := NULL;
        END;

        IF lv_salesrep_name IS NOT NULL
        THEN
            BEGIN
                SELECT jrs.salesrep_id
                  INTO l_target_salesrep_id
                  FROM jtf_rs_salesreps jrs, jtf_rs_resource_extns_tl jrr
                 WHERE     jrr.resource_name = lv_salesrep_name
                       AND jrs.org_id = p_target_org_id
                       AND jrs.resource_id = jrr.resource_id(+)
                       AND jrr.language = 'US';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_target_salesrep_id   := NULL;
            END;
        ELSE
            l_target_salesrep_id   := NULL;
        END IF;

        RETURN l_target_salesrep_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_target_salesrep_id   := NULL;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in getting target salesrep');
            RETURN l_target_salesrep_id;
    END get_target_salesrep;


    -- get target bill_to

    FUNCTION get_target_bill_to (p_source_bill_to    IN NUMBER,
                                 p_source_customer   IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_bill_to_org_id   NUMBER;
    BEGIN
        BEGIN
            SELECT thcsua.site_use_id
              INTO ln_bill_to_org_id
              FROM hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa, hz_party_sites hps,
                   hz_locations hl, fnd_lookup_values flv, hz_cust_accounts shca,
                   hz_party_sites thps, hz_locations thl, hz_cust_accounts thca,
                   hz_cust_acct_sites_all thcasa, hz_cust_site_uses_all thcsua
             WHERE     hcsua.site_use_id = p_source_bill_to
                   AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                   AND hcasa.party_site_id = hps.party_site_id
                   AND hps.party_site_number = flv.attribute2
                   AND hcasa.cust_account_id = shca.cust_account_id
                   AND flv.attribute1 = shca.account_number
                   AND flv.attribute4 = thps.party_site_number
                   AND hl.location_id = hps.location_id
                   AND thl.location_id = thps.location_id
                   AND NVL (hl.address1, 0) = NVL (thl.address1, 0)
                   AND NVL (hl.address2, 0) = NVL (thl.address2, 0)
                   AND NVL (hl.address3, 0) = NVL (thl.address3, 0)
                   AND NVL (hl.address4, 0) = NVL (thl.address4, 0)
                   AND thps.party_site_id = thcasa.party_site_id
                   AND thps.party_id = thca.party_id
                   AND thca.account_number = flv.attribute3
                   AND thca.cust_Account_id = thcasa.cust_account_id
                   AND thcasa.cust_acct_site_id = thcsua.cust_acct_site_id
                   AND flv.lookup_type = 'XXD_ONT_MOVE_CUST_MAP_LKP'
                   AND flv.language = 'US'
                   AND flv.attribute5 = 'BILL_TO';
        EXCEPTION
            WHEN OTHERS
            THEN
                SELECT thcsua.site_use_id bill_to_org_id
                  INTO ln_bill_to_org_id
                  FROM hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa, hz_party_sites hps,
                       hz_locations hl, fnd_lookup_values flv, hz_party_sites thps,
                       hz_cust_accounts thca, hz_cust_acct_sites_all thcasa, hz_cust_site_uses_all thcsua,
                       hz_locations thl
                 WHERE     hcsua.site_use_id = p_source_bill_to     --89580663
                       AND flv.attribute1 = p_source_customer
                       AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                       AND hcasa.party_site_id = hps.party_site_id
                       AND hps.party_site_number = flv.attribute2
                       AND flv.attribute4 = thps.party_site_number
                       AND hl.location_id = hps.location_id
                       AND thl.location_id = thps.location_id
                       AND NVL (hl.address1, 0) = NVL (thl.address1, 0)
                       AND NVL (hl.address2, 0) = NVL (thl.address2, 0)
                       AND NVL (hl.address3, 0) = NVL (thl.address3, 0)
                       AND NVL (hl.address4, 0) = NVL (thl.address4, 0)
                       AND thps.party_site_id = thcasa.party_site_id
                       AND thps.party_id = thca.party_id
                       AND thca.account_number = flv.attribute3
                       AND thca.cust_Account_id = thcasa.cust_account_id
                       AND thcasa.cust_acct_site_id =
                           thcsua.cust_acct_site_id
                       AND flv.lookup_type = 'XXD_ONT_MOVE_CUST_MAP_LKP'
                       AND flv.language = 'US'
                       AND flv.attribute5 = 'BILL_TO';
        END;

        RETURN ln_bill_to_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unable to get the target bill_to, mapping doesnot exist in the lookup XXD_ONT_MOVE_CUST_MAP_LKP');
            RETURN 0;
    END get_target_bill_to;

    -- get target bill_to

    FUNCTION get_target_ship_to (p_source_ship_to    IN NUMBER,
                                 p_source_customer   IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_ship_to_org_id   NUMBER;
    BEGIN
        BEGIN
            SELECT thcsua.site_use_id
              INTO ln_ship_to_org_id
              FROM hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa, hz_party_sites hps,
                   hz_locations hl, fnd_lookup_values flv, hz_cust_accounts shca,
                   hz_party_sites thps, hz_locations thl, hz_cust_accounts thca,
                   hz_cust_acct_sites_all thcasa, hz_cust_site_uses_all thcsua
             WHERE     hcsua.site_use_id = p_source_ship_to
                   AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                   AND hcasa.party_site_id = hps.party_site_id
                   AND hps.party_site_number = flv.attribute2
                   AND hcsua.LOCATION = Thcsua.LOCATION
                   AND hl.location_id = hps.location_id
                   AND thl.location_id = thps.location_id
                   AND NVL (hl.address1, 0) = NVL (thl.address1, 0)
                   AND NVL (hl.address2, 0) = NVL (thl.address2, 0)
                   AND NVL (hl.address3, 0) = NVL (thl.address3, 0)
                   AND NVL (hl.address4, 0) = NVL (thl.address4, 0)
                   AND hcasa.cust_account_id = shca.cust_account_id
                   AND flv.attribute1 = shca.account_number
                   AND flv.attribute4 = thps.party_site_number
                   AND thps.party_site_id = thcasa.party_site_id
                   AND thps.party_id = thca.party_id
                   AND thca.account_number = flv.attribute3
                   AND thca.cust_Account_id = thcasa.cust_account_id
                   AND thcasa.cust_acct_site_id = thcsua.cust_acct_site_id
                   AND flv.lookup_type = 'XXD_ONT_MOVE_CUST_MAP_LKP'
                   AND flv.language = 'US'
                   AND flv.attribute5 = 'SHIP_TO';
        EXCEPTION
            WHEN OTHERS
            THEN
                SELECT thcsua.site_use_id bill_to_org_id
                  INTO ln_ship_to_org_id
                  FROM hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa, hz_party_sites hps,
                       hz_locations hl, fnd_lookup_values flv, hz_party_sites thps,
                       hz_locations thl, hz_cust_accounts thca, hz_cust_acct_sites_all thcasa,
                       hz_cust_site_uses_all thcsua
                 WHERE     hcsua.site_use_id = p_source_ship_to     --89580663
                       AND flv.attribute1 = p_source_customer
                       AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                       AND hcasa.party_site_id = hps.party_site_id
                       AND hps.party_site_number = flv.attribute2
                       AND hcsua.LOCATION = Thcsua.LOCATION
                       AND hl.location_id = hps.location_id
                       AND thl.location_id = thps.location_id
                       AND NVL (hl.address1, 0) = NVL (thl.address1, 0)
                       AND NVL (hl.address2, 0) = NVL (thl.address2, 0)
                       AND NVL (hl.address3, 0) = NVL (thl.address3, 0)
                       AND NVL (hl.address4, 0) = NVL (thl.address4, 0)
                       AND flv.attribute4 = thps.party_site_number
                       AND thps.party_site_id = thcasa.party_site_id
                       AND thps.party_id = thca.party_id
                       AND thca.account_number = flv.attribute3
                       AND thca.cust_Account_id = thcasa.cust_account_id
                       AND thcasa.cust_acct_site_id =
                           thcsua.cust_acct_site_id
                       AND flv.lookup_type = 'XXD_ONT_MOVE_CUST_MAP_LKP'
                       AND flv.language = 'US'
                       AND flv.attribute5 = 'SHIP_TO';
        END;

        RETURN ln_ship_to_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unable to get the target ship_to, mapping doesnot exist in the lookup XXD_ONT_MOVE_CUST_MAP_LKP');
            RETURN 0;
    END get_target_ship_to;

    FUNCTION xxd_remove_junk_fnc (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT --replace(replace(replace(replace(p_input, CHR(9), ''), CHR(10), ''), '||', ','), CHR(13), '')
                   REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '||', ''), CHR (13), ''), ',', '')
              INTO lv_output
              FROM DUAL;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END xxd_remove_junk_fnc;

    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'DirList.getList( java.lang.String )' ;

    PROCEDURE load_file_into_tbl (p_table IN VARCHAR2, p_dir IN VARCHAR2, p_filename IN VARCHAR2, p_ignore_headerlines IN INTEGER DEFAULT 1, p_delimiter IN VARCHAR2 DEFAULT ',', p_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                  , p_num_of_columns IN NUMBER)
    IS
        /***************************************************************************
        -- PROCEDURE load_file_into_tbl
        -- PURPOSE: This Procedure read the data from a CSV file.
        -- And load it into the target oracle table.
        -- Finally it renames the source file with date.
        --
        -- P_FILENAME
        -- The name of the flat file(a text file)
        --
        -- P_DIRECTORY
        -- Name of the directory where the file is been placed.
        -- Note: The grant has to be given for the user to the directory
        -- before executing the function
        --
        -- P_IGNORE_HEADERLINES:
        -- Pass the value as '1' to ignore importing headers.
        --
        -- P_DELIMITER
        -- By default the delimiter is used as ','
        -- As we are using CSV file to load the data into oracle
        --
        -- P_OPTIONAL_ENCLOSED
        -- By default the optionally enclosed is used as '"'
        -- As we are using CSV file to load the data into oracle
        --
        **************************************************************************/

        l_input                 UTL_FILE.file_type;
        l_lastline              VARCHAR2 (32767);
        l_cnames                VARCHAR2 (32767);
        l_bindvars              VARCHAR2 (32767);
        l_status                INTEGER;
        l_cnt                   NUMBER DEFAULT 0;
        l_rowcount              NUMBER DEFAULT 0;
        l_sep                   CHAR (1) DEFAULT NULL;
        l_errmsg                VARCHAR2 (32767);
        v_eof                   BOOLEAN := FALSE;
        l_thecursor             NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert                VARCHAR2 (32767);
        lv_arc_dir              VARCHAR2 (100) := 'XXD_OM_OU_ALIGN_INB_ARC_DIR';
        ln_req_id               NUMBER;
        lb_wait_req             BOOLEAN;
        lv_phase                VARCHAR2 (100);
        lv_status               VARCHAR2 (30);
        lv_dev_phase            VARCHAR2 (100);
        lv_dev_status           VARCHAR2 (100);
        lv_message              VARCHAR2 (1000);
        lv_inb_directory_path   VARCHAR2 (1000) := NULL;
        lv_arc_directory_path   VARCHAR2 (1000) := NULL;
    BEGIN
        l_cnt        := 1;

        FOR tab_columns
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE table_name = p_table AND column_id < p_num_of_columns
                ORDER BY column_id)
        LOOP
            l_cnames   := l_cnames || tab_columns.column_name || ',';

            l_bindvars   :=
                   l_bindvars
                || CASE
                       WHEN tab_columns.data_type IN ('DATE', 'TIMESTAMP(6)')
                       THEN
                           ':b' || l_cnt || ','
                       ELSE
                           ':b' || l_cnt || ','
                   END;


            l_cnt      := l_cnt + 1;
        END LOOP;

        l_cnames     := RTRIM (l_cnames, ',');
        l_bindvars   := RTRIM (l_bindvars, ',');
        write_log ('Count of Columns is - ' || l_cnt);
        l_input      := UTL_FILE.fopen (p_dir, p_filename, 'r');

        IF p_ignore_headerlines > 0
        THEN
            BEGIN
                FOR i IN 1 .. p_ignore_headerlines
                LOOP
                    -- DBMS_OUTPUT.put_line ('No of lines Ignored is - ' || i);
                    write_log ('No of lines Ignored is - ' || i);
                    write_log ('P_DIR - ' || p_dir);
                    write_log ('P_FILENAME - ' || p_filename);
                    UTL_FILE.get_line (l_input, l_lastline);
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_eof   := TRUE;
                WHEN OTHERS
                THEN
                    write_log (
                           'File Read error due to heading size is huge: - '
                        || SQLERRM);
            END;
        END IF;

        v_insert     :=
               'insert into '
            || p_table
            || '('
            || l_cnames
            || ') values ('
            || l_bindvars
            || ')';

        -- fnd_file.put_line(fnd_file.log,v_insert);
        IF NOT v_eof
        THEN
            write_log (
                   l_thecursor
                || '-'
                || 'insert into '
                || p_table
                || '('
                || l_cnames
                || ') values ('
                || l_bindvars
                || ')');

            DBMS_SQL.parse (l_thecursor, v_insert, DBMS_SQL.native);

            LOOP
                BEGIN
                    UTL_FILE.get_line (l_input, l_lastline);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        EXIT;
                END;

                --  fnd_file.put_line(fnd_file.log,l_lastline);

                IF LENGTH (l_lastline) > 0
                THEN
                    FOR i IN 1 .. l_cnt - 1
                    LOOP
                        --  fnd_file.put_line( fnd_file.log,l_thecursor);
                        DBMS_SQL.bind_variable (
                            l_thecursor,
                            ':b' || i,
                            xxd_remove_junk_fnc (
                                RTRIM (
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (REPLACE (l_lastline, '||', ','), '(^|,)("[^"]*"|[^",]*)', 1
                                                                        , i),
                                                         p_delimiter),
                                                  p_optional_enclosed),
                                           p_delimiter),
                                    p_optional_enclosed)));
                    --fnd_file.put_line( fnd_file.log,(xxd_remove_junk_fnc(rtrim(rtrim(ltrim(ltrim(regexp_substr(replace(l_lastline,'||',','), '(^|,)("[^"]*"|[^",]*)' , 1, i), p_delimiter), p_optional_enclosed), p_delimiter), p_optional_enclosed))));

                    END LOOP;

                    BEGIN
                        l_status     := DBMS_SQL.execute (l_thecursor);
                        l_rowcount   := l_rowcount + 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_errmsg   := SQLERRM;
                            fnd_file.put_line (fnd_file.LOG, l_errmsg);
                    END;
                END IF;
            END LOOP;



            -- Derive the directory Path

            BEGIN
                SELECT directory_path
                  INTO lv_inb_directory_path
                  FROM dba_directories
                 WHERE 1 = 1 AND directory_name = 'XXD_OM_OU_ALIGN_INB_DIR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_inb_directory_path   := NULL;
            END;

            BEGIN
                SELECT directory_path
                  INTO lv_arc_directory_path
                  FROM dba_directories
                 WHERE     1 = 1
                       AND directory_name = 'XXD_OM_OU_ALIGN_INB_ARC_DIR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_arc_directory_path   := NULL;
            END;

            -- copyfile_prc(p_filename, SYSDATE || p_filename, p_dir, lv_arc_dir);
            -- utl_file.fremove(p_dir, p_filename);
            -- Moving the file

            BEGIN
                write_log (
                       'Move files Process Begins...'
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                ln_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXDO_CP_MV_RM_FILE',
                        argument1     => 'MOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                        argument2     => 2,
                        argument3     =>
                            lv_inb_directory_path || '/' || p_filename, -- Source File Directory
                        argument4     =>
                               lv_arc_directory_path
                            || '/'
                            || SYSDATE
                            || '_'
                            || p_filename,       -- Destination File Directory
                        start_time    => SYSDATE,
                        sub_request   => FALSE);
                COMMIT;

                IF ln_req_id = 0
                THEN
                    --retcode := 1;
                    write_log (
                        ' Unable to submit move files concurrent program ');
                ELSE
                    write_log (
                        'Move Files concurrent request submitted successfully.');
                    lb_wait_req   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_req_id,
                            INTERVAL     => 5,
                            phase        => lv_phase,
                            status       => lv_status,
                            dev_phase    => lv_dev_phase,
                            dev_status   => lv_dev_status,
                            MESSAGE      => lv_message);

                    IF lv_dev_phase = 'COMPLETE' AND lv_dev_status = 'NORMAL'
                    THEN
                        write_log (
                               'Move Files concurrent request with the request id '
                            || ln_req_id
                            || ' completed with NORMAL status.');
                    ELSE
                        --retcode := 1;
                        write_log (
                               'Move Files concurrent request with the request id '
                            || ln_req_id
                            || ' did not complete with NORMAL status.');
                    END IF; -- End of if to check if the status is normal and phase is complete
                END IF;              -- End of if to check if request ID is 0.

                COMMIT;
                write_log (
                       'Move Files Ends...'
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
            EXCEPTION
                WHEN OTHERS
                THEN
                    --retcode := 2;
                    write_log ('Error in Move Files -' || SQLERRM);
            END;

            DBMS_SQL.close_cursor (l_thecursor);
            UTL_FILE.fclose (l_input);
        END IF;
    -- copyfile_prc(p_filename, SYSDATE || p_filename, p_dir, lv_arc_dir);
    -- utl_file.fremove(p_dir, p_filename);
    --dbms_sql.close_cursor(l_thecursor);
    --utl_file.fclose(l_input);
    -- END IF;

    END load_file_into_tbl;

    PROCEDURE main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2--pn_org_id IN NUMBER
                                                                           )
    IS
        CURSOR get_file_cur IS
            SELECT filename
              FROM xxd_dir_list_tbl_syn
             WHERE filename LIKE '%.csv%';

        lv_directory_path   VARCHAR2 (100);
        lv_directory        VARCHAR2 (100);
        lv_file_name        VARCHAR2 (100);
        lv_ret_message      VARCHAR2 (4000) := NULL;
        lv_ret_code         VARCHAR2 (30) := NULL;
        lv_period_name      VARCHAR2 (100);
        ln_file_exists      NUMBER;
        ln_ret_count        NUMBER := 0;
        ln_final_count      NUMBER := 0;
        ln_lia_count        NUMBER := 0;
        lv_vs_file_method   VARCHAR2 (10);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, '------------------------');
        fnd_file.put_line (fnd_file.LOG, 'Program parameters are:');
        fnd_file.put_line (fnd_file.LOG, '------------------------');
        lv_directory_path   := NULL;
        lv_directory        := NULL;
        ln_file_exists      := 0;

        -- truncate request table

        EXECUTE IMMEDIATE 'TRUNCATE table xxdo.xxd_order_import_requests';

        -- Derive the directory Path
        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE directory_name = 'XXD_OM_OU_ALIGN_INB_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'Directory Path:' || lv_directory_path);
        -- Now Get the file names
        get_file_names (lv_directory_path);

        FOR data IN get_file_cur
        LOOP
            ln_file_exists   := 0;
            fnd_file.put_line (fnd_file.LOG,
                               'File is availale - ' || data.filename);

            -- Check the file name exists in the table if exists then SKIP
            BEGIN
                SELECT COUNT (1)
                  INTO ln_file_exists
                  FROM xxdo.XXD_OU_ALIGNMENT_INBOUND_T
                 WHERE UPPER (file_name) = UPPER (data.filename);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_file_exists   := 0;
            END;

            IF ln_file_exists = 0
            THEN
                -- loading the data into staging table
                load_file_into_tbl (p_table => 'XXD_OU_ALIGNMENT_INBOUND_T', p_dir => lv_directory_path, p_filename => data.filename, p_ignore_headerlines => 1, p_delimiter => ',', p_optional_enclosed => '"'
                                    , p_num_of_columns => 18);

                BEGIN
                    UPDATE xxdo.XXD_OU_ALIGNMENT_INBOUND_T
                       SET file_name = data.filename, request_id = gn_request_id, creation_date = SYSDATE,
                           last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id,
                           status = 'NEW'
                     WHERE file_name IS NULL AND request_id IS NULL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Updating the staging table is failed:'
                            || SQLERRM);
                END;
            --

            END IF;
        END LOOP;

        -- validate the data
        validate_load_data;

        --insert the data into custom line table as xxd_ou_alignment_lines_t
        --  insert_line_tbl;
        BEGIN
            SELECT xxd_ou_alignment_batch_seq.NEXTVAL
              INTO gn_batch_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                SELECT xxd_ou_alignment_batch_seq.NEXTVAL
                  INTO gn_batch_id
                  FROM DUAL;
        END;

        cancel_non_bulk_orders;

        import_non_bulk_order;

        cancel_bulk_orders;

        import_bulk_order;

        create_new_bulk_order;

        import_target_bulk_order;

        create_new_non_bulk_order;

        import_target_non_bulk_order;

        update_order_details;

        generate_report (lv_ret_message, lv_ret_code, gn_request_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error occured at Main ' || SQLERRM);
    END main;
END XXD_OM_MOVE_ORDER_PKG;
/
