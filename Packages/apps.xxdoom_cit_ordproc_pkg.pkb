--
-- XXDOOM_CIT_ORDPROC_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOOM_CIT_ORDPROC_PKG"
AS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy ( Suneara Technologies )
    -- Creation Date           : 14-NOV-2011
    -- File Name               : XXDOOM006.pks
    -- INCIDENT                : CIT Process Order Response - Deckers
    --
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 14-NOV-2011       1.0         Vijaya Reddy         Initial development.
    -- 13-DEC-2013       1.1         Madhav Dhurjaty      Modified MAIN for CIT FTP Change ENHC0011747
    -- 07-AUG-2014       1.2         Rakesh Dudani        Archieve records and output report CCR0003727
    -- 16-JAN-2015       2.0         BT TECHNOLOGY TEAM   Retrofit from 12.0.3 to 12.2.3
    -------------------------------------------------------------------------------

    FUNCTION isnumeric (p_string IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_number   NUMBER;
    BEGIN
        l_number   := p_string;
        RETURN 'TRUE';
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'FALSE';
    END isnumeric;

    PROCEDURE ERROR_REPORT
    IS
        CURSOR error_records IS
            SELECT *
              FROM xxdoom_sanuk_crdconfirm_stg
             WHERE process_flag = 'N';

        p_success_records   NUMBER;
        p_error_records     NUMBER;
    BEGIN
        /*==============================================================================================================================================
                ******************************* ERROR RECORDS REPORT*****************************************************************
          =============================================================================================================================================*/
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '         ');
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, '         ');
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
            '===================================================================================');
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
            '***********************ERROR RECORDS SUMMARY REPORT*************************');
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
            '===================================================================================');
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
            '===================================================================================');
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
               '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|');
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
               '|'
            || RPAD ('ORDER NUMBER', 20, ' ')
            || '|'
            || RPAD ('CUSTOMER NAME', 25, ' ')
            || '|'
            || RPAD ('ORDER AMOUNT', 20, ' ')
            || '|'
            || RPAD ('APPROVED AMOUNT', 15, ' ')
            || '|'
            || RPAD ('Error', 20, ' ')
            || '|');
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
               '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|');
    /*  BEGIN
        FOR err_recs IN error_records
        LOOP

          APPS.FND_FILE.PUT_LINE
                         (APPS.FND_FILE.OUTPUT,
                             '|'
                          || RPAD (NVL (NVL (TO_CHAR (err_recs.client_order_number),
                                             ' '
                                            ),
                                        ' '
                                       ),
                                   20,
                                   ' '
                                  )
                          || '|'
                          || RPAD (NVL (NVL (TO_CHAR (err_recs.customer_name),
                                             ' '),
                                        ' '
                                       ),
                                   25,
                                   ' '
                                  )
                          || '|'
                          || RPAD (NVL (NVL (TO_CHAR (err_recs.order_amount),
                                             ' '),
                                        ' '
                                       ),
                                   20,
                                   ' '
                                  )
                          || '|'
                          || RPAD (NVL (NVL (TO_CHAR (err_recs.approved_amount),
                                             ' '
                                            ),
                                        ' '
                                       ),
                                   15,
                                   ' '
                                  )
                          || '|'
                         );

       END LOOP;
       APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,
                                     '|'
                                  || RPAD ('-', 20, '-')
                                  || '|'
                                  || RPAD ('-', 25, '-')
                                  || '|'
                                  || RPAD ('-', 20, '-')
                                  || '|'
                                  || RPAD ('-', 15, '-')
                                  || '|'
                                 );

       EXCEPTION
          WHEN OTHERS
          THEN
             APPS.FND_FILE.PUT_LINE
                       (APPS.FND_FILE.LOG,
                           'EXCEPTION OCCURED WHILE DISPLYING ERROR RECORDS   '
                        || SQLERRM
                       );
         END;

       SELECT Count(*) INTO p_success_records
       FROM xxdo.xxdoom_sanuk_crdconfirm_stg
       WHERE process_flag='P';

       SELECT Count(*) INTO p_error_records
       FROM xxdo.xxdoom_sanuk_crdconfirm_stg
       WHERE process_flag='N';

       APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,'Number of records processed: '|| p_success_records);
       APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,'Number of records Failed: '|| p_error_records); */

    END ERROR_REPORT;

    PROCEDURE GET_CIT_ORDPROC (ERRBUF           OUT VARCHAR2,
                               RETCODE          OUT VARCHAR2,
                               PV_RELRES_CODE       VARCHAR2)
    AS
        ----------------------
        -- CURSOR DECLARATIONS
        ----------------------
        ln_order_tbl        APPS.OE_HOLDS_PVT.order_tbl_type;
        lv_return_status    VARCHAR2 (30);
        ln_prf_class_id     NUMBER;
        lv_msg_data         VARCHAR2 (4000);
        ln_msg_count        NUMBER;
        ln_exists           NUMBER;
        lv_error_message    VARCHAR2 (32000);
        p_errbuf            VARCHAR2 (200);
        p_retcode           VARCHAR2 (50);
        p_success_records   NUMBER := 0;
        p_error_records     NUMBER := 0;

        ----------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE PROCESS ORDER RECORDS FROM STAGING TABLE
        ----------------------------------------------------------------------------------
        CURSOR c_proc_ordrstg_cur IS
            SELECT DISTINCT stg.client_order_number, ooh.header_id, stg.order_amount,
                            stg.cit_customer_number, stg.customer_name, stg.approved_amount
              FROM xxdoom_sanuk_crdconfirm_stg stg, oe_order_headers_all ooh, oe_order_lines_all ool
             WHERE     isnumeric (stg.client_order_number) = 'TRUE'
                   AND stg.client_order_number = ooh.order_number
                   AND ooh.header_id = ool.header_id
                   AND ool.org_id = ooh.org_id
                   AND stg.process_flag = 'N'
                   AND UPPER (TRIM (stg.action_code)) IN ('AA', 'AC')
                   AND EXISTS
                           (SELECT 1
                              FROM APPS.oe_order_holds_all oohold, APPS.oe_hold_sources_all ohs, APPS.oe_hold_definitions ohd
                             WHERE     oohold.header_id = ool.header_id
                                   AND NVL (oohold.line_id, ool.line_id) =
                                       ool.line_id
                                   AND ool.org_id = ooh.org_id
                                   AND oohold.hold_source_id =
                                       ohs.hold_source_id
                                   AND ohs.hold_id = ohd.hold_id
                                   AND oohold.released_flag = 'N'
                                   AND ohd.type_code = 'CREDIT');

        --------------------------------------------------------------------------------
        -- CURSOR TO RETRIEVE HOLD_ID for a SALES ORDER
        --------------------------------------------------------------------------------
        CURSOR c_ordhold_cur (cp_sales_ordnum IN NUMBER)
        IS
            SELECT /*+ index(hld OE_ORDER_HOLDS_ALL_N1) index(hsrc OE_HOLD_SOURCES_U1)*/
                   hdr.header_id, hsrc.hold_source_id, hsrc.hold_id,
                   hdr.sold_to_org_id, hdr.invoice_to_org_id
              FROM apps.oe_order_headers_all hdr, apps.oe_order_holds_all hld, apps.oe_hold_sources_all hsrc,
                   apps.oe_hold_definitions hdef
             WHERE     hdr.header_id = hld.header_id
                   AND hld.hold_source_id = hsrc.hold_source_id
                   AND hsrc.hold_id = hdef.hold_id
                   AND hdef.name = 'Credit Check Failure'
                   AND hld.released_flag = 'N'
                   AND hdef.type_code = 'CREDIT'
                   AND 'Y' =
                       xxdoom_cit_int_pkg.is_fact_cust_f (
                           hdr.order_number,
                           hdr.sold_to_org_id,
                           hdr.invoice_to_org_id)
                   AND hdr.order_number = cp_sales_ordnum;
    BEGIN
        ---------------------------------------------------------------------------------------
        -- RETRIEVE PROCESS ORDER RECORDS FROM STAGING TABLE
        ----------------------------------------------------------------------------------------
        ERROR_REPORT;
        GV_ERROR_POSITION   :=
            'GET_CIT_ORDPROC - RETRIEVE PROCESS ORDER RECORDS FROM STAGING TABLE';

        FOR proc_ordrstg IN c_proc_ordrstg_cur
        LOOP
            ---------------------------------------------------------------------------------------
            -- RETRIEVE HOLD_ID for a SALES ORDER
            ----------------------------------------------------------------------------------------
            GV_ERROR_POSITION   :=
                'GET_CIT_ORDPROC - RETRIEVE HOLD_ID for a SALES ORDER';

            FOR ordhold
                IN c_ordhold_cur (
                       cp_sales_ordnum => proc_ordrstg.client_order_number)
            LOOP
                APPS.FND_GLOBAL.APPS_INITIALIZE (
                    APPS.FND_GLOBAL.USER_ID,
                    APPS.FND_GLOBAL.RESP_ID,
                    APPS.FND_GLOBAL.RESP_APPL_ID);
                APPS.MO_GLOBAL.INIT ('ONT');

                ln_order_tbl (1).header_id   := ordhold.header_id;
                lv_return_status             := NULL;
                lv_msg_data                  := NULL;
                ln_msg_count                 := NULL;
                APPS.OE_HOLDS_PUB.RELEASE_HOLDS (
                    p_api_version           => 1.0,
                    p_order_tbl             => ln_order_tbl,
                    p_hold_id               => ordhold.hold_id,  --ln_hold_id,
                    p_release_reason_code   => PV_RELRES_CODE,
                    p_release_comment       => 'CIT ORDER APPROVAL',
                    x_return_status         => lv_return_status,
                    x_msg_count             => ln_msg_count,
                    x_msg_data              => lv_msg_data);


                IF lv_return_status = APPS.FND_API.G_RET_STS_SUCCESS
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Hold released for Sales Order Num: ' || proc_ordrstg.client_order_number);

                    --APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,'Hold released for Sales Order Num: '||proc_ordrstg.client_order_number);

                    UPDATE xxdoom_sanuk_crdconfirm_stg
                       SET process_flag   = 'P'
                     WHERE client_order_number =
                           proc_ordrstg.client_order_number;

                    p_success_records   := p_success_records + 1;

                    BEGIN
                        ln_prf_class_id   := NULL;


                        SELECT hcp.profile_class_id
                          INTO ln_prf_class_id
                          FROM apps.hz_customer_profiles hcp
                         WHERE     hcp.cust_account_id =
                                   ordhold.sold_to_org_id
                               AND hcp.site_use_id =
                                   ordhold.invoice_to_org_id
                               AND hcp.status = 'A'
                               AND ROWNUM <= 1;


                        IF ln_prf_class_id IS NOT NULL
                        THEN
                            UPDATE apps.hz_customer_profiles hcp
                               SET hcp.attribute2 = proc_ordrstg.cit_customer_number
                             WHERE     hcp.cust_account_id =
                                       ordhold.sold_to_org_id
                                   AND hcp.site_use_id =
                                       ordhold.invoice_to_org_id
                                   AND hcp.status = 'A';

                            COMMIT;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            BEGIN
                                SELECT hcp.profile_class_id
                                  INTO ln_prf_class_id
                                  FROM apps.hz_customer_profiles hcp
                                 WHERE     hcp.cust_account_id =
                                           ordhold.sold_to_org_id
                                       AND hcp.site_use_id IS NULL
                                       AND hcp.status = 'A'
                                       AND ROWNUM <= 1;

                                IF ln_prf_class_id IS NOT NULL
                                THEN
                                    UPDATE apps.hz_customer_profiles hcp
                                       SET hcp.attribute2 = proc_ordrstg.cit_customer_number
                                     WHERE     hcp.cust_account_id =
                                               ordhold.sold_to_org_id
                                           AND hcp.site_use_id IS NULL
                                           AND hcp.status = 'A';

                                    COMMIT;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_prf_class_id   := NULL;
                            END;
                    END;
                ELSIF lv_return_status IS NULL
                THEN
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Release Hold API Status is NULL');
                --APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,'Release Hold API Status is NULL');
                ELSE
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'Release Hold API Failed: ' || lv_msg_data);
                    --APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,'Release Hold API Failed for the order: '|| proc_ordrstg.client_order_number);
                    --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.OUTPUT,'Release Hold API Failed: '|| lv_msg_data);
                    p_error_records   := p_error_records + 1;

                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.OUTPUT,
                           '|'
                        || RPAD (
                               NVL (
                                   NVL (
                                       TO_CHAR (
                                           proc_ordrstg.client_order_number),
                                       ' '),
                                   ' '),
                               20,
                               ' ')
                        || '|'
                        || RPAD (
                               NVL (
                                   NVL (TO_CHAR (proc_ordrstg.customer_name),
                                        ' '),
                                   ' '),
                               25,
                               ' ')
                        || '|'
                        || RPAD (
                               NVL (
                                   NVL (TO_CHAR (proc_ordrstg.order_amount),
                                        ' '),
                                   ' '),
                               20,
                               ' ')
                        || '|'
                        || RPAD (
                               NVL (
                                   NVL (
                                       TO_CHAR (proc_ordrstg.approved_amount),
                                       ' '),
                                   ' '),
                               15,
                               ' ')
                        || '|'
                        || RPAD (NVL (NVL (TO_CHAR (lv_msg_data), ' '), ' '),
                                 20,
                                 ' ')
                        || '|');
                END IF;
            END LOOP;
        END LOOP;

        --   ERROR_REPORT;
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
               '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 25, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|');

        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
            'Number of records processed: ' || p_success_records);
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
            'Number of records Failed: ' || p_error_records);
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   := SQLERRM;
            APPS.FND_FILE.PUT_LINE (
                apps.FND_FILE.LOG,
                'Following Error Occured At ' || GV_ERROR_POSITION);
            RAISE_APPLICATION_ERROR (-20501, lv_error_message);
            RAISE;
    END GET_CIT_ORDPROC;

    PROCEDURE MAIN (pv_errbuf          OUT VARCHAR2,
                    pv_retcode         OUT VARCHAR2,
                    pv_rel_reason   IN     VARCHAR2)
    IS
        /* Variaables for calling the ftp program */
        lv_request_id         NUMBER := 0;
        lv_request_id1        NUMBER := 0;
        lv_request_id2        NUMBER := 0;
        lv_source_path        VARCHAR2 (100);
        lv_source_path1       VARCHAR2 (100);
        lv_source_path2       VARCHAR2 (100);
        lv_instance_name      VARCHAR2 (50);
        --lv_filename      VARCHAR2(60) :='CIT_Orderresponse'; -- Commented by BT Technology Team as part of retrofit on 16-Jan-2015
        lv_filename           VARCHAR2 (60) := 'CCDATA.TXT'; -- Added by BT Technology Team as part of retrofit on 16-Jan-2015
        lv_fileserver         VARCHAR2 (80);
        lv_rel_reason         VARCHAR2 (50);
        lv_PhaseCode          VARCHAR2 (100) := NULL;
        lv_StatusCode         VARCHAR2 (100) := NULL;
        lv_DevPhase           VARCHAR2 (100) := NULL;
        lv_DevStatus          VARCHAR2 (100) := NULL;
        lv_ReturnMsg          VARCHAR2 (200) := NULL;
        lv_ConcReqCallStat    BOOLEAN := FALSE;
        lv_ConcReqCallStat1   BOOLEAN := FALSE;
        lv_ConcReqCallStat2   BOOLEAN := FALSE;
    BEGIN
        -- Commented below by BT Technology Team as part of retrofit on 16-Jan-2015
        /*
       SELECT DISTINCT VALUE INTO lv_source_path
         FROM apps.fnd_env_context
        WHERE variable_name = 'XXDO_TOP'
          AND SUBSTR (VALUE,
                      INSTR (VALUE, '/', 1, 3) + 1,
                      INSTR (VALUE, '/', 1, 4) - 1
                      - INSTR (VALUE, '/', 1, 3)
                     ) IN (SELECT applications_system_name
                             FROM apps.fnd_product_groups)
          AND rownum <= 1;*/
        -- Commented below by BT Technology Team as part of retrofit on 16-Jan-2015

        -- Added below by BT Technology Team as part of retrofit on 16-Jan-2015
        SELECT DISTINCT VALUE
          INTO lv_source_path
          FROM apps.fnd_env_context
         WHERE variable_name = 'XXDO_TOP' AND ROWNUM = 1;

        -- Added above by BT Technology Team as part of retrofit on 16-Jan-2015

        lv_source_path1   := lv_source_path || '/bin';

        --lv_source_path2 := lv_source_path || '/bin/CIT_Orderresponse.dat'; --Commented by Madhav Dhurjaty 12/13/13
        lv_source_path2   := lv_source_path || '/bin/CCDATA.TXT'; --Added by Madhav Dhurjaty 12/13/13

        /* Retrieving the File Server Name */

        BEGIN
            SELECT DECODE (APPLICATIONS_SYSTEM_NAME, 'PROD', APPS.FND_PROFILE.VALUE ('DO CIT: FTP Address'), APPS.FND_PROFILE.VALUE ('DO CIT: Test FTP Address')) FILE_SERVER_NAME
              INTO lv_fileserver
              FROM APPS.FND_PRODUCT_GROUPS
             WHERE ROWNUM <= 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Unable to fetch the File server name');
                pv_retcode   := 2;
        END;


        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.LOG,
            'Executing CIT Process Order Response - Deckers Program');

        lv_request_id     :=
            APPS.FND_REQUEST.SUBMIT_REQUEST (
                application   => 'XXDO',
                program       => 'XXDOOM006B',
                description   => '',
                start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                sub_request   => FALSE,
                argument1     => lv_source_path1,
                argument2     => '',
                argument3     => lv_filename,
                argument4     => lv_fileserver);

        COMMIT;


        lv_ConcReqCallStat   :=
            APPS.FND_CONCURRENT.WAIT_FOR_REQUEST (lv_request_ID,
                                                  5 -- wait 5 seconds between db checks
                                                   ,
                                                  0,
                                                  lv_PhaseCode,
                                                  lv_StatusCode,
                                                  lv_DevPhase,
                                                  lv_DevStatus,
                                                  lv_ReturnMsg);
        COMMIT;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Request id is ' || lv_request_id);



        IF lv_request_id IS NOT NULL AND lv_request_id <> 0
        THEN
            BEGIN
                lv_request_id1   :=
                    APPS.FND_REQUEST.SUBMIT_REQUEST (
                        application   => 'XXDO',
                        program       => 'XXDOOM006A',
                        description   => '',
                        start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                        sub_request   => FALSE,
                        argument1     => lv_source_path2);
                COMMIT;

                lv_PhaseCode    := NULL;
                lv_StatusCode   := NULL;
                lv_DevPhase     := NULL;
                lv_DevStatus    := NULL;
                lv_ReturnMsg    := NULL;
                lv_ConcReqCallStat1   :=
                    APPS.FND_CONCURRENT.WAIT_FOR_REQUEST (lv_request_id1,
                                                          5 -- wait 5 seconds between db checks
                                                           ,
                                                          0,
                                                          lv_PhaseCode,
                                                          lv_StatusCode,
                                                          lv_DevPhase,
                                                          lv_DevStatus,
                                                          lv_ReturnMsg);
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception occured while running Loader program'
                        || SQLERRM);
            END;
        END IF;


        IF lv_request_id1 IS NOT NULL AND lv_request_id1 <> 0
        THEN
            BEGIN
                SELECT lookup_code
                  INTO lv_rel_reason
                  FROM apps.fnd_lookup_values_vl
                 WHERE     lookup_type = 'RELEASE_REASON'
                       AND lookup_code = 'CIT ORDER APPROVAL'
                       AND ROWNUM <= 1;


                lv_request_id2   :=
                    APPS.FND_REQUEST.SUBMIT_REQUEST (
                        application   => 'XXDO',
                        program       => 'XXDOOM006C',
                        description   => '',
                        start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                        sub_request   => FALSE,
                        argument1     => lv_rel_reason);
                COMMIT;

                lv_PhaseCode    := NULL;
                lv_StatusCode   := NULL;
                lv_DevPhase     := NULL;
                lv_DevStatus    := NULL;
                lv_ReturnMsg    := NULL;
                lv_ConcReqCallStat2   :=
                    APPS.FND_CONCURRENT.WAIT_FOR_REQUEST (lv_request_id2,
                                                          5 -- wait 5 seconds between db checks
                                                           ,
                                                          0,
                                                          lv_PhaseCode,
                                                          lv_StatusCode,
                                                          lv_DevPhase,
                                                          lv_DevStatus,
                                                          lv_ReturnMsg);
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception occured while running Order Release program'
                        || SQLERRM);
            END;
        END IF;

        IF lv_request_id2 IS NOT NULL AND lv_request_id2 <> 0
        THEN
            BEGIN
                INSERT INTO xxdoom_sanuk_crdconfirm_hist (
                                format_type,
                                group_client_number,
                                client_number,
                                julian_date,
                                hour_of_extraction,
                                record_type,
                                cit_customer_number,
                                client_customer_number,
                                customer_name,
                                client_order_number,
                                cit_reference_number,
                                order_amount,
                                approved_amount,
                                action_code,
                                reason_code1,
                                reason_code2,
                                reason_code3,
                                reason_code4,
                                reason_code5,
                                order_receipt_date,
                                start_ship_date,
                                completion_ship_date,
                                terms_days,
                                credit_line_amount,
                                credit_line_type,
                                credit_approver_number,
                                future_use,
                                process_flag,
                                creation_date,
                                created_by)
                    SELECT format_type, group_client_number, client_number,
                           julian_date, hour_of_extraction, record_type,
                           cit_customer_number, client_customer_number, customer_name,
                           client_order_number, cit_reference_number, order_amount,
                           approved_amount, action_code, reason_code1,
                           reason_code2, reason_code3, reason_code4,
                           reason_code5, order_receipt_date, start_ship_date,
                           completion_ship_date, terms_days, credit_line_amount,
                           credit_line_type, credit_approver_number, future_use,
                           process_flag, SYSDATE, APPS.FND_GLOBAL.USER_ID
                      FROM xxdoom_sanuk_crdconfirm_stg;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception occured while inserting data into history table: '
                        || SQLERRM);
            END;
        END IF;
    --ERROR_REPORT;

    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Exception occured while running Main program' || SQLERRM);
    END;
END XXDOOM_CIT_ORDPROC_PKG;
/
