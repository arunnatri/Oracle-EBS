--
-- XXDO_INT_010_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INT_010_PKG"
IS
    PROCEDURE xxdo_int_010_rcv (errfbuf          OUT VARCHAR2,
                                retcode          OUT VARCHAR2,
                                p_so_number   IN     NUMBER)
    IS
        CURSOR cur_get_rcv_records (p_so_number IN NUMBER)
        IS
            SELECT --Start modification by BT Technogy Team on 22-Jul-2014,  v2.0
                        --                rct.organization_id organization_id,
                  -- Start modification by BT Team on 02-Oct-15
                  (SELECT DECODE (attribute1,  'US3', 152,  'US1', 1092,  'US2', 132,  'EU4', 334,  'HK1', 872,  'JP5', 892,  'CH3', 932,  lookup_code) org_id
                     --                                (SELECT lookup_code
                     -- End modification by BT Team on 02-Oct-15
                     FROM fnd_lookup_values
                    WHERE     lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                          AND attribute1 =
                              (SELECT organization_code
                                 FROM org_organization_definitions
                                WHERE organization_id = rct.organization_id)
                          AND language = USERENV ('LANG')
                          AND ROWNUM = 1) organization_id,
                  --End modification by BT Technogy Team on 22-Jul-2014,  v2.0
                  xxdo.distro_doc_type doc_type,
                  ool.inventory_item_id item_id,
                  rct.primary_quantity unit_qty,
                  'R' receipt_type,
                  rsh.receipt_num receipt_num,
                  xxdo.asn_nbr asn_nbr,
                  xxdo.container_id cnt_qty,
                  xxdo.po_nbr po_nbr
             FROM apps.rcv_transactions rct, apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool,
                  apps.oe_order_sources oos, apps.rcv_shipment_headers rsh, xxdo_inv_int_028_stg2 xxdo
            WHERE     rct.oe_order_header_id = ooh.header_id
                  AND rct.oe_order_line_id = ool.line_id
                  AND ooh.order_source_id = oos.order_source_id
                  AND rct.shipment_header_id = rsh.shipment_header_id
                  AND oos.NAME = 'Retail'
                  AND ool.inventory_item_id = xxdo.item_id
                  AND ool.ship_from_org_id = to_location
                  AND rct.oe_order_header_id = ooh.header_id
                  AND rct.oe_order_line_id = ool.line_id
                  AND ooh.flow_status_code IN ('BOOKED', 'CLOSED')
                  AND ool.flow_status_code IN ('RETURNED', 'CLOSED')
                  AND rct.transaction_type = 'RECEIVE'
                  AND ooh.order_number =
                      DECODE (p_so_number,
                              NULL, ooh.order_number,
                              p_so_number)
                  AND XXDO.SEQ_NO = XXDO.SEQ_NO
                  AND SUBSTR (ool.orig_sys_line_ref,
                              1,
                              (  INSTR (ool.orig_sys_line_ref, '-', 1,
                                        1)
                               - 1)) = xxdo.distro_nbr
                  AND SUBSTR (ool.orig_sys_line_ref,
                              (  INSTR (ool.orig_sys_line_ref, '-', 1,
                                        3)
                               + 1),
                              (  (  INSTR (ool.orig_sys_line_ref, '-', 1,
                                           4)
                                  - 1)
                               - (INSTR (ool.orig_sys_line_ref, '-', 1,
                                         3)))) = xxdo.xml_id
                  /*AND rct.transaction_date > NVL((SELECT + INDEX(FCPT) MAX(actual_completion_date)
                                                     FROM apps.fnd_concurrent_requests fcr,
                                                          apps.fnd_concurrent_programs fcpt
                                                    WHERE fcr.concurrent_program_id = fcpt.concurrent_program_id
                                                      AND fcpt.concurrent_program_name IN('XXDOTEST', 'XXDOINV019')
                                                      AND fcr.phase_code = 'C'
                                                      AND fcr.status_code = 'C'),
                                                         TRUNC(SYSDATE))*/
                  AND rct.transaction_date >
                      DECODE (
                          p_so_number,
                          NULL, NVL ((SELECT MAX (last_run_date_time)
                                        FROM xxdo.xxdo_inv_itm_mvmt_table
                                       WHERE integration_code = 'INT_010'),
                                     SYSDATE),
                          SYSDATE - 1000);

        v_organization_id   NUMBER;
        v_doc_type          VARCHAR2 (100);
        v_item_id           NUMBER;
        v_unit_qty          NUMBER;
        v_receipt_type      VARCHAR2 (100);
        v_receipt_num       VARCHAR2 (100);
        v_asn_nbr           VARCHAR2 (100);
        v_po_nbr            VARCHAR2 (100);
        v_cnt_qty           VARCHAR2 (100);
        v_order_number      NUMBER := p_so_number;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Begin Of The Procedure');

        FOR c_cur_get_rcv_records IN cur_get_rcv_records (v_order_number)
        LOOP
            v_organization_id   := c_cur_get_rcv_records.organization_id;
            v_doc_type          := c_cur_get_rcv_records.doc_type;
            v_item_id           := c_cur_get_rcv_records.item_id;
            v_unit_qty          := c_cur_get_rcv_records.unit_qty;
            v_receipt_type      := c_cur_get_rcv_records.receipt_type;
            v_receipt_num       := c_cur_get_rcv_records.receipt_num;
            v_asn_nbr           := c_cur_get_rcv_records.asn_nbr;
            v_po_nbr            := c_cur_get_rcv_records.po_nbr;
            v_cnt_qty           := c_cur_get_rcv_records.cnt_qty;
            xxdo_int_010_prc (v_organization_id, v_doc_type, v_item_id,
                              v_unit_qty, v_receipt_type, v_receipt_num,
                              v_asn_nbr, v_po_nbr, v_cnt_qty);
        END LOOP;
    END;

    PROCEDURE xxdo_int_010_prc (p_dc_dest_id IN NUMBER, p_distro_doc_type IN VARCHAR2, p_item_id IN NUMBER, p_unit_qty IN NUMBER, p_receipt_type IN VARCHAR2, p_receipt_nbr IN VARCHAR2
                                , p_asn_nbr IN VARCHAR2, p_po_nbr IN VARCHAR2, p_cnt_qty IN VARCHAR2)
    IS
        /******************************************************************
          File Name    : xxdo_int_010_prc
          Created On   : 17-March-2012
          Created By   : Abdul (Sunera Technologies)
          Purpose      : The INT-010 integration is to get all the input from
                         a different program and use it to translate to a XML
                         file
        *******************************************************************/
        ----------------------
        -- Declaring Variables
        ----------------------
        v_dc_dest_id          VARCHAR2 (100) := p_dc_dest_id;
        v_distro_doc_type     VARCHAR2 (100) := p_distro_doc_type;
        --   v_dest_id               number          :=  p_dest_id           ;
        v_item_id             NUMBER := p_item_id;
        v_unit_qty            NUMBER := p_unit_qty;
        v_receipt_type        VARCHAR2 (100) := p_receipt_type;
        v_receipt_nbr         VARCHAR2 (100) := p_receipt_nbr;
        v_sku                 VARCHAR2 (100) := NULL;
        v_item_desc           VARCHAR2 (100) := NULL;
        v_seq_no              NUMBER := 0;
        v_processed_flag      VARCHAR2 (100) := NULL;
        v_transmission_date   DATE := NULL;
        v_error_code          VARCHAR2 (240) := NULL;
        v_xml_data            CLOB;
        lc_return             CLOB;
        lv_wsdl_ip            VARCHAR2 (25) := NULL;
        lv_wsdl_url           VARCHAR2 (4000) := NULL;
        lv_namespace          VARCHAR2 (4000) := NULL;
        lv_service            VARCHAR2 (4000) := NULL;
        lv_port               VARCHAR2 (4000) := NULL;
        lv_operation          VARCHAR2 (4000) := NULL;
        lv_targetname         VARCHAR2 (4000) := NULL;
        lx_xmltype_in         SYS.XMLTYPE;
        lx_xmltype_out        SYS.XMLTYPE;
        lv_errmsg             VARCHAR2 (240) := NULL;
        lv_atr_wsdl_url       VARCHAR2 (4000) := NULL;
        lv_atr_namespace      VARCHAR2 (4000) := NULL;
        lv_atr_service        VARCHAR2 (4000) := NULL;
        lv_atr_port           VARCHAR2 (4000) := NULL;
        lv_atr_operation      VARCHAR2 (4000) := NULL;
        lv_atr_targetname     VARCHAR2 (4000) := NULL;
        lx_atr_xmltype_in     SYS.XMLTYPE;
        lx_atr_xmltype_out    SYS.XMLTYPE;
        v_atr_xml_data        CLOB;
        atr_xml_data          CLOB;
        lc_atr_return         CLOB;
        l_http_request        UTL_HTTP.req;
        l_http_response       UTL_HTTP.resp;
        l_buffer_size         NUMBER (10) := 512;
        l_line_size           NUMBER (10) := 50;
        l_lines_count         NUMBER (10) := 20;
        l_string_request      CLOB;
        l_line                VARCHAR2 (128);
        l_substring_msg       VARCHAR2 (512);
        l_raw_data            RAW (512);
        l_clob_response       CLOB;
        lv_ip                 VARCHAR2 (100);
        buffer                VARCHAR2 (32767);
        httpdata              CLOB;
        eof                   BOOLEAN;
        xml                   CLOB;
        env                   VARCHAR2 (32767);
        resp                  XMLTYPE;
        v_xmldata             CLOB := NULL;
        v_atr_xmldata         CLOB := NULL;
        v_asn_nbr             VARCHAR2 (100) := p_asn_nbr;
        v_po_nbr              VARCHAR2 (100) := p_po_nbr;
        v_cnt_qty             VARCHAR2 (100) := p_cnt_qty;

        -------------------------------------------------------
        -- Cursor CUR_INT_010 which is used to formulate
        -- the XML data with the parameters which has been
        -- provided
        -------------------------------------------------------
        CURSOR cur_int_010 IS
            SELECT 'A' temp,
                   (SELECT XMLELEMENT (
                               "v1:ReceiptDesc",
                               XMLELEMENT (
                                   "v1:Receipt",
                                   XMLELEMENT ("v1:dc_dest_id", v_dc_dest_id),
                                   XMLELEMENT ("v1:po_nbr", v_po_nbr),
                                   XMLELEMENT ("v1:document_type",
                                               v_distro_doc_type),
                                   XMLELEMENT ("v1:asn_nbr", v_asn_nbr),
                                   XMLELEMENT (
                                       "v1:ReceiptDtl",
                                       XMLELEMENT ("v1:item_id", v_item_id),
                                       XMLELEMENT ("v1:unit_qty", v_unit_qty),
                                       XMLELEMENT ("v1:receipt_xactn_type",
                                                   v_receipt_type),
                                       XMLELEMENT ("v1:receipt_nbr",
                                                   v_receipt_nbr),
                                       XMLELEMENT ("v1:container_id",
                                                   v_cnt_qty),
                                       XMLELEMENT ("v1:to_disposition",
                                                   'TRBL'))   -- v1:ReceiptDtl
                                                           )     -- v1:Receipt
                                                            ) xml -- v1:ReceiptDesc
                      FROM DUAL) xml_data
              FROM DUAL;

        CURSOR cur_int_010_atr IS
            SELECT XMLELEMENT (
                       "v1:InvAdjustDesc",
                       XMLELEMENT ("v1:dc_dest_id", v_dc_dest_id),
                       XMLELEMENT (
                           "v1:InvAdjustDtl",
                           XMLELEMENT ("v1:item_id", v_item_id),
                           XMLELEMENT ("v1:adjustment_reason_code", 88),
                           XMLELEMENT ("v1:unit_qty", v_unit_qty),
                           XMLELEMENT ("v1:transshipment_nbr", ''),
                           XMLELEMENT ("v1:from_disposition", 'TRBL'),
                           XMLELEMENT ("v1:to_disposition", ''),
                           XMLELEMENT ("v1:from_trouble_code", ''),
                           XMLELEMENT ("v1:to_trouble_code", ''),
                           XMLELEMENT ("v1:from_wip_code", ''),
                           XMLELEMENT ("v1:to_wip_code", ''),
                           XMLELEMENT ("v1:transaction_code", 0),
                           XMLELEMENT ("v1:user_id", 'RMS13PROD'),
                           XMLELEMENT ("v1:create_date", TRUNC (SYSDATE)),
                           XMLELEMENT ("v1:po_nbr", ''),
                           XMLELEMENT ("v1:doc_type", ''),
                           XMLELEMENT ("v1:aux_reason_code", ''),
                           XMLELEMENT ("v1:weight", ''),
                           XMLELEMENT ("v1:weight_uom", ''),
                           XMLELEMENT ("v1:unit_cost", ''))) atr_xml_data
              FROM DUAL;
    --------------------------------
    -- Beginning of the program
    --------------------------------
    BEGIN
        fnd_file.put_line (fnd_file.output, 'Records Transmitted to RMS');

        ---------------------------------
        -- The Select statement to get the
        -- next value from the sequence
        ---------------------------------
        BEGIN
            SELECT xxdo_inv_int_010_seq.NEXTVAL INTO v_seq_no FROM DUAL;
        -------------------------
        -- Exception Handler
        -------------------------
        EXCEPTION
            --------------------------
            -- When No Data Found Error
            --------------------------
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'No Data Found When Getting The Value Of The Sequence');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
            --------------------------
            -- When Others Error
            --------------------------
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Others Data Found When Getting The Value Of The Sequence');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        END;

        ----------------------------------
        -- To get the profile values
        ----------------------------------
        BEGIN
            SELECT DECODE (applications_system_name,  -- Start of modification by BT Technology Team on 17-Feb-2016 V2.0
                                                      --'PROD', apps.fnd_profile.VALUE ('XXDO: RETAIL PROD'),
                                                      'EBSPROD', apps.fnd_profile.VALUE ('XXDO: RETAIL PROD'),  -- End of modification by BT Technology Team on 17-Feb-2016 V2.0
                                                                                                                'PCLN', apps.fnd_profile.VALUE ('XXDO: RETAIL DEV'),  apps.fnd_profile.VALUE ('XXDO: RETAIL TEST')) file_server_name
              INTO lv_wsdl_ip
              FROM apps.fnd_product_groups;
        -------------------------
        -- Exception Handler
        -------------------------
        EXCEPTION
            --------------------------
            -- When No Data Found Error
            --------------------------
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'No Data Found When Getting The IP');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
            --------------------------
            -- When Others Error
            --------------------------
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Others Data Found When Getting The IP');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        END;

        --------------------------------------------------------------
        -- Initializing the variables for calling the webservices
        -- The webservices takes the input parameter as wsd URL,
        -- name space, service, port, operation and target name
        --------------------------------------------------------------
        ----------------------------
        -- Starting of the program
        ----------------------------
        BEGIN
            -----------------------------------------------
            -- Inserting into the custom table, the custom
            -- table will have the data for which we need
            -- insert for storing the processed records
            -----------------------------------------------
            INSERT INTO xxdo_inv_int_010_stg (dc_dest_id,
                                              document_type,
                                              item_id,
                                              unit_qty,
                                              receipt_xactn_type,
                                              receipt_nbr,
                                              creation_date,
                                              seq_no,
                                              asn_nbr)
                 VALUES (v_dc_dest_id, v_distro_doc_type, v_item_id,
                         v_unit_qty, v_receipt_type, v_receipt_nbr,
                         SYSDATE, v_seq_no, v_asn_nbr);
        ----------------------------
        -- Exception Handler
        ----------------------------
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'No Data Found While Inserting Into The Custom Table');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Erroe Message :' || SQLERRM);
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Others Error While Inserting Into The Custom Table');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Erroe Message :' || SQLERRM);
        END;

        COMMIT;
        -----------------------
        -- End Of The Program
        -----------------------
        --------------------------------------------------------------
        -- Initializing the variables for calling the webservices
        -- The webservices takes the input parameter as wsd URL,
        -- name space, service, port, operation and target name
        --------------------------------------------------------------
        lv_wsdl_url        :=
               'http://'
            || lv_wsdl_ip
            || '//ReceivingPublishingBean/ReceivingPublishingService?WSDL';
        lv_namespace       :=
            'http://www.oracle.com/retail/igs/integration/services/ReceivingPublishingService/v1';
        lv_service         := 'ReceivingPublishingService';
        lv_port            := 'ReceivingPublishingPort';
        lv_operation       := 'publishAppointDeleteUsingAppointRef';
        lv_targetname      :=
               'http://'
            || lv_wsdl_ip
            || '//ReceivingPublishingBean/ReceivingPublishingService';
        lv_atr_wsdl_url    :=
               'http://'
            || lv_wsdl_ip
            || '//InvAdjustPublishingBean/InvAdjustPublishingService?WSDL';
        lv_atr_namespace   :=
            'http://www.oracle.com/retail/igs/integration/services/InvAdjustPublishingService/v1';
        lv_atr_service     := 'InvAdjustPublishingService';
        lv_atr_port        := 'InvAdjustPublishingPort';
        lv_atr_operation   := 'publishInvAdjustCreateUsingInvAdjustDesc';
        lv_atr_targetname   :=
               'http://'
            || lv_wsdl_ip
            || '//InvAdjustPublishingBean/InvAdjustPublishingService';

        ------------------------------------------------------------------------
        -------------------------------------------------------------------
        -- insert into the custom staging table : xxdo_inv_int_010
        -------------------------------------------------------------------
        FOR c_cur_int_010 IN cur_int_010
        LOOP
            ----------------------------
            -- Begin of the procedure
            ----------------------------
            v_xmldata   := XMLTYPE.getclobval (c_cur_int_010.xml_data);

            BEGIN
                UPDATE xxdo_inv_int_010_stg
                   SET xmldata = XMLTYPE.getclobval (c_cur_int_010.xml_data)
                 WHERE seq_no = v_seq_no;
            --------------------
            -- Exception Handler
            --------------------
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Inserting The Data');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code:' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);

                    ------------------------------
                    -- Updating the staging table
                    ------------------------------
                    UPDATE xxdo_inv_int_010_stg
                       SET status = 'VE', errorcode = 'Validation Error'
                     WHERE seq_no = v_seq_no;
            ----------------------
            -- End Of The Program
            ----------------------
            END;

            COMMIT;
            -------------------------------------------------------------
            -- Assigning the variables to call the webservices function
            -------------------------------------------------------------
            fnd_file.put_line (fnd_file.LOG, 'XML:' || v_xmldata);
            lx_xmltype_in   :=
                SYS.XMLTYPE (
                       '<publishReceiptCreateUsingReceiptDesc xmlns="http://www.oracle.com/retail/igs/integration/services/ReceivingPublishingService/v1" xmlns:v1="http://www.oracle.com/retail/integration/base/bo/ReceiptDesc/v1" xmlns:v11="http://www.oracle.com/retail/integration/custom/bo/ExtOfReceiptDesc/v1" xmlns:v12="http://www.oracle.com/retail/integration/base/bo/LocOfReceiptDesc/v1" xmlns:v13="http://www.oracle.com/retail/integration/localization/bo/InReceiptDesc/v1" xmlns:v14="http://www.oracle.com/retail/integration/custom/bo/EOfInReceiptDesc/v1" xmlns:v15="http://www.oracle.com/retail/integration/localization/bo/BrReceiptDesc/v1" xmlns:v16="http://www.oracle.com/retail/integration/custom/bo/EOfBrReceiptDesc/v1">'
                    || XMLTYPE.getclobval (c_cur_int_010.xml_data)
                    || '</publishReceiptCreateUsingReceiptDesc>');

            -----------------------------
            -- Calling the web services
            -----------------------------
            BEGIN
                ------------------------------------
                -- Calling the web services program
                ----------------------------------
                lx_xmltype_out   :=
                    xxdo_invoke_webservice_f (lv_wsdl_url, lv_namespace, lv_targetname, lv_service, lv_port, lv_operation
                                              , lx_xmltype_in);

                ----------------------------------------
                -- If the XML TYPE OUT IS NOT NULL then
                -- the result is good and debugging the
                -- same
                ----------------------------------------
                IF lx_xmltype_out IS NOT NULL
                THEN
                    -------------------------
                    -- Debugging the comments
                    -------------------------
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Response is stored in the staging table  ');
                    fnd_file.put_line (
                        fnd_file.output,
                        '***************************************************');
                    fnd_file.put_line (fnd_file.output,
                                       'Receipt Number :' || v_receipt_nbr);
                    fnd_file.put_line (fnd_file.output,
                                       'Item ID :' || v_item_id);
                    fnd_file.put_line (fnd_file.output,
                                       'Quantity :' || v_unit_qty);
                    ----------------------------
                    -- Storing the return values
                    ----------------------------
                    lc_return   := XMLTYPE.getclobval (lx_xmltype_out);
                    fnd_file.put_line (fnd_file.LOG, 'Return :' || lc_return);

                    ------------------------------------------------------
                    -- update the staging table : xxdo_inv_int_010_stg
                    ------------------------------------------------------
                    UPDATE xxdo_inv_int_010_stg
                       SET retval = lc_return, processed_flag = 'Y', status = 'P',
                           transmission_date = SYSDATE
                     WHERE seq_no = v_seq_no;

                    COMMIT;

                    ---------------------------------------------------------------------------------------
                    -- logic to process ATR message for the receipt
                    ----------------------------------------------------------------------------------------
                    FOR i IN cur_int_010_atr
                    LOOP
                        v_atr_xmldata   :=
                            XMLTYPE.getclobval (i.atr_xml_data);
                        lx_atr_xmltype_in   :=
                            SYS.XMLTYPE (
                                   '<publishInvAdjustCreateUsingInvAdjustDesc xmlns="http://www.oracle.com/retail/igs/integration/services/InvAdjustPublishingService/v1" xmlns:v1="http://www.oracle.com/retail/integration/base/bo/InvAdjustDesc/v1" xmlns:v11="http://www.oracle.com/retail/integration/custom/bo/ExtOfInvAdjustDesc/v1" xmlns:v12="http://www.oracle.com/retail/integration/base/bo/LocOfInvAdjustDesc/v1" xmlns:v13="http://www.oracle.com/retail/integration/localization/bo/InInvAdjustDesc/v1" xmlns:v14="http://www.oracle.com/retail/integration/custom/bo/EOfInInvAdjustDesc/v1" xmlns:v15="http://www.oracle.com/retail/integration/localization/bo/BrInvAdjustDesc/v1" xmlns:v16="http://www.oracle.com/retail/integration/custom/bo/EOfBrInvAdjustDesc/v1">'
                                || XMLTYPE.getclobval (i.atr_xml_data)
                                || '</publishInvAdjustCreateUsingInvAdjustDesc>');

                        BEGIN
                            ------------------------------------
                            -- Calling the web services program
                            ----------------------------------
                            lx_atr_xmltype_out   :=
                                xxdo_invoke_webservice_f (lv_atr_wsdl_url,
                                                          lv_atr_namespace,
                                                          lv_atr_targetname,
                                                          lv_atr_service,
                                                          lv_atr_port,
                                                          lv_atr_operation,
                                                          lx_atr_xmltype_in);
                        END;

                        IF lx_atr_xmltype_out IS NOT NULL
                        THEN
                            lc_atr_return   :=
                                XMLTYPE.getclobval (lx_atr_xmltype_out);

                            UPDATE xxdo_inv_int_010_stg
                               SET atr_transmission_flag   = 'Y'
                             WHERE seq_no = v_seq_no;

                            COMMIT;
                        ELSE
                            fnd_file.put_line (fnd_file.output,
                                               'Response is NULL  ');
                            lc_return   := NULL;

                            -------------------------------------------------
                            -- Updating the staging table to set the processed
                            -- flag = Validation Error and transmission date
                            --  = sysdate for the sequence number
                            -------------------------------------------------
                            UPDATE xxdo_inv_int_010_stg
                               SET atr_transmission_flag   = 'VE'
                             WHERE seq_no = v_seq_no;

                            COMMIT;
                        END IF;
                    END LOOP;
                -----------------------------------------------------------------------------------------------------------

                ---------------------------------------------
                -- If there is no response from web services
                ---------------------------------------------
                ELSE
                    fnd_file.put_line (fnd_file.output, 'Response is NULL  ');
                    lc_return   := NULL;

                    -------------------------------------------------
                    -- Updating the staging table to set the processed
                    -- flag = Validation Error and transmission date
                    --  = sysdate for the sequence number
                    -------------------------------------------------
                    UPDATE xxdo_inv_int_010_stg
                       SET retval = lc_return, processed_flag = 'VE', transmission_date = SYSDATE
                     WHERE seq_no = v_seq_no;

                    COMMIT;
                ---------------------------------
                -- Condition END IF
                ---------------------------------
                END IF;
            ---------------------
            -- Exception HAndler
            ---------------------
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_errmsg   := SQLERRM;

                    --------------------------------
                    -- Updating the staging table
                    --------------------------------
                    UPDATE xxdo_inv_int_010_stg
                       SET status = 'VE', errorcode = lv_errmsg
                     WHERE seq_no = v_seq_no;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'PROBLEM IN SENDING THE MESSAGE DETAILS STORED IN THE ERRORCODE OF THE STAGING TABLE   '
                        || SQLERRM);
            END;
        END LOOP;

        BEGIN
            UPDATE xxdo.xxdo_inv_itm_mvmt_table
               SET last_run_date_time   = SYSDATE
             WHERE integration_code = 'INT_010';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Others error Found While Updating the table');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message:' || SQLERRM);
        END;

        COMMIT;
    END;
-------------------------
-- End Of The Package
-----------------------
END;
/
