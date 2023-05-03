--
-- XXDOAR021_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR021_REP_PKG"
AS
    /******************************************************************************
       NAME: XXDOAR021_REP_PKG
      Program NAME:Transmit Factored Remittance Batch detail - Deckers

       REVISIONS:
       Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
    -- MODIFICATION HISTORY
    -- Person                          Date                                Comments
    --Shibu Alex                      12-12-2011                           Initial Version
    --Madhav Dhurjaty                 12-13-2013                           Modified  after_report, main_prog for CIT FTP change ENHC0011747
    --Madhav Dhurjaty                 08-04-2014                           Modified main_prog and Added function is_batch_balanced for ENHC0012098
    ******************************************************************************/
    FUNCTION before_report
        RETURN BOOLEAN
    IS
    BEGIN
        p_sql_stmt   :=
            'SELECT
            apps.fnd_profile.VALUE(''DO CIT: CLIENT NUMBER'')  CLIENT_NUMBER
        ,   :P_IDEN_REC             IDENTIFICATION_RECORD
        ,   RPAD('' '',1,'' '') TRADE_STYLE
        ,   CUST.CUST_ACCOUNT_ID
        ,   RPAD(CUST.ACCOUNT_NUMBER,15,'' '')  ACCOUNT_NUMBER
        ,   RPAD(TRX.TRX_NUMBER,8,'' '')        TRX_NUMBER
        ,   RPAD('' '',7,'' '') FILLER
        ,   TRX.BILL_TO_SITE_USE_ID
        ,   TRX.SHIP_TO_SITE_USE_ID
        ,   TRX_LINES.LINE_NUMBER
        ,   TRX_LINES.QUANTITY_INVOICED
        ,   TRX_LINES.UNIT_SELLING_PRICE
        ,   TO_NUMBER(TO_CHAR(PS.AMOUNT_APPLIED,''99999999V99'')) AMOUNT_APPLIED
        ,   nvl(TRX_LINES.UOM_CODE,''EA'') MEASUREMENT_CODE
        ,   nvl(TRX_LINES.UOM_CODE,''PE'') UNIT_PRICE_CODE
        ,   RPAD(MSI.SEGMENT1||''-''||MSI.SEGMENT2||''-''||MSI.SEGMENT3,30,'' '') ITEM
        ,   RPAD(MSI.DESCRIPTION,30,'' '')  DESCRIPTION
        ,   RPAD(MSI.SEGMENT1,20,'' '') VENDOR_STYLE_NUMBER
        ,   TRX.TRX_DATE
        ,   lpad(decode(ps.DUE_DATE, NULL, 0, ps.DUE_DATE - ps.TRX_DATE ),3,0) CLIENT_TERMS_CODE
        ,   RPAD(RT.NAME,30,'' '')  TERMS_DESC
        ,   RPAD(TRX.PURCHASE_ORDER,22,'' '') PURCHASE_ORDER
        ,   TRX.PURCHASE_ORDER_DATE
        ,   PS.AMOUNT_LINE_ITEMS_ORIGINAL
        ,   PS.TAX_ORIGINAL
        ,   PS.RECEIVABLES_CHARGES_CHARGED
        ,   RPAD(PARTY.PARTY_NAME,30,'' '')            CUST_BILL_TO_NAME
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''ADDR1'')     BILL_TO_ADDRESS_1
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''ADDR2'')     BILL_TO_ADDRESS_2
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''CITY'')      BILL_TO_CITY
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''STATE'')     BILL_TO_STATE
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''ZIP'')       BILL_TO_ZIP
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''BILL_TO'',''COUNTRY'')   BILL_TO_COUNTRY
        ,   RPAD(XXDOOM_CIT_INT_PKG.Cust_Phone_f(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID),15,'' '')            CUSTOMER_PHONE
        ,   XXDOAR021_REP_PKG.cust_contact_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''FAX'')                CUSTOMER_FAX
        ,   RPAD(PARTY.DUNS_NUMBER_C,9,'' '')                                                                            CUSTOMER_DUNS
        ,   XXDOAR021_REP_PKG.cust_contact_det(CUST.CUST_ACCOUNT_ID,TRX.BILL_TO_SITE_USE_ID,''EMAIL'')              CUSTOMER_EMAIL
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''ADDR1'')     SHIP_TO_ADDRESS_1
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''ADDR2'')     SHIP_TO_ADDRESS_2
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''CITY'')      SHIP_TO_CITY
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''STATE'')     SHIP_TO_STATE
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''ZIP'')       SHIP_TO_ZIP
        ,   XXDOAR021_REP_PKG.cust_addr_det(CUST.CUST_ACCOUNT_ID,TRX.SHIP_TO_SITE_USE_ID,''SHIP_TO'',''COUNTRY'')   SHIP_TO_COUNTRY
        ,   XXDO.XXDOAR021_REP_PKG.itm_color_style_desc(MSI.INVENTORY_ITEM_ID,OSP.MASTER_ORGANIZATION_ID,''COLOR'')      COLOR_DESC
        ,   RPAD(SHIP_VIA.DESCRIPTION,30,'' '')        FREIGHT_CARRIER
        ,   RPAD(MSI.ATTRIBUTE11,20,'' '')             UPC_NUMBER
        ,   RPAD('' '',2,'' '')     SHIPMENT_PAY_CODE
        ,   LPAD(0,6,''0'')         NO_OF_CARTONS
            from
              APPS.AR_CASH_RECEIPT_HISTORY_ALL       ACRH
            , APPS.AR_RECEIVABLE_APPLICATIONS_ALL    ARA
            , APPS.AR_PAYMENT_SCHEDULES_ALL          PS
            , APPS.RA_CUSTOMER_TRX_ALL               TRX
            , APPS.RA_CUSTOMER_TRX_LINES_ALL         TRX_LINES
            , APPS.HZ_CUST_ACCOUNTS                  CUST
            , APPS.HZ_PARTIES                        PARTY
            , APPS.MTL_SYSTEM_ITEMS_B                MSI
            , APPS.RA_TERMS                          RT
            , APPS.OE_SYSTEM_PARAMETERS_ALL          OSP
            , (SELECT F.DESCRIPTION,FREIGHT_CODE
               FROM   APPS.ORG_FREIGHT F,
                      APPS.OE_SYSTEM_PARAMETERS_ALL OSP
               WHERE  F.ORGANIZATION_ID = OSP.MASTER_ORGANIZATION_ID
               AND    OSP.ORG_ID = :P_ORG_ID)        SHIP_VIA
            Where
            ACRH.CASH_RECEIPT_ID                =   ARA.CASH_RECEIPT_ID
            AND ACRH.ORG_ID                     =   ARA.ORG_ID
            AND ARA.DISPLAY                     =   ''Y''
            AND ARA.APPLIED_PAYMENT_SCHEDULE_ID =   PS.PAYMENT_SCHEDULE_ID
            AND ARA.APPLIED_CUSTOMER_TRX_ID     =   TRX.CUSTOMER_TRX_ID
            AND TRX.CUSTOMER_TRX_ID             =   TRX_LINES.CUSTOMER_TRX_ID
            and TRX_LINES.LINE_TYPE             =   ''LINE''
            and TRX.BILL_TO_CUSTOMER_ID         =   CUST.CUST_ACCOUNT_ID
            and CUST.PARTY_ID                   =   PARTY.PARTY_ID
            AND TRX_LINES.INVENTORY_ITEM_ID     =   MSI.INVENTORY_ITEM_ID
            and MSI.ORGANIZATION_ID             =   OSP.MASTER_ORGANIZATION_ID
            AND TRX.TERM_ID                     =   RT.TERM_ID
            AND TRX.SHIP_VIA                    =   SHIP_VIA.FREIGHT_CODE(+)
            AND ACRH.batch_id                   =   :P_BATCH_ID
            AND OSP.ORG_ID                      =   :P_ORG_ID
            order by CUST_BILL_TO_NAME, TRX.TRX_NUMBER,TRX_LINES.LINE_NUMBER';
        apps.fnd_file.put_line (apps.fnd_file.LOG, p_sql_stmt);
        p_sql_stmt2   :=
            'select
            ABA.CONTROL_COUNT,
            ABA.NAME,
            ABA.BATCH_DATE,
            count(ARA.APPLIED_CUSTOMER_TRX_ID) TRX_TOTAL,
            TO_NUMBER(TO_CHAR(SUM(ARA.AMOUNT_APPLIED),''99999999V99''))  BATCH_AMT
            from
              APPS.AR_CASH_RECEIPT_HISTORY_ALL       ACRH
            , APPS.AR_RECEIVABLE_APPLICATIONS_ALL    ARA
            , APPS.AR_BATCHES_ALL                    ABA
            Where
            ACRH.CASH_RECEIPT_ID                =   ARA.CASH_RECEIPT_ID
            AND ACRH.ORG_ID                     =   ARA.ORG_ID
            AND ARA.DISPLAY                     =   ''Y''
            AND ACRH.batch_id                   =   ABA.BATCH_ID
            AND ACRH.batch_id                   =   :P_BATCH_ID
            AND ARA.ORG_ID                      =   :P_ORG_ID
            group by CONTROL_COUNT,ABA.NAME,ABA.BATCH_DATE';
        apps.fnd_file.put_line (apps.fnd_file.LOG, p_sql_stmt2);
        COMMIT;
        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Before Report Failed');
            RETURN FALSE;
    END before_report;

    FUNCTION after_report
        RETURN BOOLEAN
    IS
        ln_request       NUMBER;
        ln_req_id        NUMBER;
        lv_source_path   VARCHAR2 (5000);
        lv_success       BOOLEAN := FALSE;
        lv_success2      BOOLEAN := FALSE;
        lv_phase         VARCHAR2 (50);
        lv_status        VARCHAR2 (50);
        lv_dev_phase     VARCHAR2 (50);
        lv_dev_phase1    VARCHAR2 (50);
        lv_dev_status    VARCHAR2 (50);
        lv_dev_status1   VARCHAR2 (50);
        lv_message       VARCHAR2 (500);
        lv_file_server   VARCHAR2 (50);
    BEGIN
        ln_request    := apps.fnd_profile.VALUE ('CONC_REQUEST_ID');
        p_file_name   := 'XXDOAR021_' || ln_request || '_1.ETEXT';

        IF p_sent_yn = 'Y'
        THEN
            -- Getting the File  server
            BEGIN
                SELECT DECODE (applications_system_name, 'PROD', apps.fnd_profile.VALUE ('DO CIT: FTP Address'), apps.fnd_profile.VALUE ('DO CIT: Test FTP Address')) file_server_name
                  INTO lv_file_server
                  FROM apps.fnd_product_groups;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'File Server Not Found');
            END;

            -- Getting the source path of the request_id
            BEGIN
                SELECT SUBSTR (outfile_name, 1, INSTR (outfile_name, 'out') + 2)
                  INTO lv_source_path
                  FROM apps.fnd_concurrent_requests
                 WHERE request_id = ln_request;

                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'lv_source_path  ' || lv_source_path);
            END;

            lv_success   :=
                apps.fnd_concurrent.get_request_status (ln_request,
                                                        NULL,
                                                        NULL,
                                                        lv_phase,
                                                        lv_status,
                                                        lv_dev_phase,
                                                        lv_dev_status,
                                                        lv_message);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'lv_dev_phase  ' || lv_dev_phase);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'lv_status' || lv_status || 'lv_dev_status' || lv_dev_status);

            IF lv_dev_status = 'NORMAL'
            THEN
                --             lv_success2 := apps.FND_CONCURRENT.WAIT_FOR_REQUEST(ln_request
                --                                                ,5
                --                                                ,0
                --                                                ,lv_phase
                --                                                ,lv_status
                --                                                ,lv_dev_phase1
                --                                                ,lv_dev_status1
                --                                                ,lv_message);
                ln_req_id   :=
                    apps.fnd_request.submit_request (application => 'XXDO', program => 'XXDOOM005B', description => NULL, start_time => TO_CHAR (SYSDATE, 'DD-MON-YY'), sub_request => FALSE, argument1 => lv_source_path, argument2 => 'CIT_XXDOAR021'-- log purpose
                                                                                                                                                                                                                                                       , argument3 => p_file_name, argument4 => lv_file_server
                                                     , argument5 => 'data.DI'--Added by Madhav Dhurjaty  on 12/13/13 CIT FTP Change
                                                                             --filetype=data.DI for invoice, data.CO for Orders
                                                                             );

                --  Updating the batch if success
                UPDATE apps.ar_batches_all
                   SET attribute10   = 'Y'
                 WHERE batch_id = p_batch_id;

                COMMIT;
            END IF;
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'After Report Failed');
            RETURN FALSE;
    END after_report;

    FUNCTION is_batch_balanced (p_batch_id IN NUMBER, p_org_id IN NUMBER)
        RETURN BOOLEAN
    IS
        CURSOR c_batch IS
              SELECT aba.control_count, aba.NAME, aba.batch_date,
                     rct.trx_number, acr.receipt_number, ara.amount_applied rct_amt,
                     SUM (rctl.extended_amount) inv_amt
                FROM apps.ar_cash_receipt_history_all acrh, apps.ar_receivable_applications_all ara, apps.ar_batches_all aba,
                     apps.ra_customer_trx_lines_all rctl, apps.ra_customer_trx_all rct, apps.ar_cash_receipts_all acr
               WHERE     1 = 1
                     AND acrh.cash_receipt_id = ara.cash_receipt_id
                     AND acrh.batch_id = aba.batch_id
                     AND ara.applied_customer_trx_id = rct.customer_trx_id
                     AND ara.applied_customer_trx_id = rctl.customer_trx_id
                     AND acrh.org_id = ara.org_id
                     AND acrh.cash_receipt_id = acr.cash_receipt_id
                     AND ara.display = 'Y'
                     AND acrh.batch_id = p_batch_id
                     AND ara.org_id = p_org_id                     --:P_ORG_ID
            --AND aba.batch_date >= '01-APR-2014'
            GROUP BY aba.control_count, aba.NAME, aba.batch_date,
                     rct.trx_number, acr.receipt_number, ara.amount_applied;

        l_invoice_amount   NUMBER := 0;
        l_applied_amount   NUMBER := 0;
        l_invoice_total    NUMBER := 0;
        l_applied_total    NUMBER := 0;
        l_variance         NUMBER := 0;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Invoice Number  '
            || 'Invoice Amount  '
            || 'Receipt Number  '
            || 'Applied Amount  '
            || 'Variance        ');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '--------------- '
            || '--------------- '
            || '--------------- '
            || '--------------- '
            || '--------------- ');

        FOR r_batch IN c_batch
        LOOP
            l_invoice_total   := l_invoice_total + r_batch.inv_amt;
            l_applied_total   := l_applied_total + r_batch.rct_amt;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   RPAD (r_batch.trx_number, 15, ' ')
                || ' '
                || LPAD (r_batch.inv_amt, 15, ' ')
                || ' '
                || RPAD (r_batch.receipt_number, 15, ' ')
                || ' '
                || LPAD (r_batch.rct_amt, 15, ' ')
                || ' '
                || LPAD (NVL (r_batch.inv_amt, 0) - NVL (r_batch.rct_amt, 0),
                         15,
                         ' '));
        END LOOP;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '--------------- '
            || '--------------- '
            || '--------------- '
            || '--------------- '
            || '--------------- ');

        IF l_invoice_total <> l_applied_total
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    '***   Batch is out of balance   ***');
            RETURN FALSE;
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    '***   Batch is balanced   ***');
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Error in is_batch_balanced:' || SQLERRM);
            RETURN FALSE;
    END is_batch_balanced;

    FUNCTION cust_contact_det (p_cust_id   NUMBER,
                               p_site_id   NUMBER,
                               p_ret_col   VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR c1 (p_cust_id NUMBER, p_site_id NUMBER)
        IS
            SELECT DISTINCT h_contact.party_name contact_name, hcar.primary_flag primary_flag, hp.cust_account_id cust_account_id,
                            org_cont.job_title title, hcp.raw_phone_number, DECODE (hcp.phone_number, NULL, '', hcp.phone_country_code || hcp.phone_area_code || hcp.phone_number) phone,
                            DECODE (hcp_fax.phone_number, NULL, '', hcp_fax.phone_country_code || hcp_fax.phone_area_code || hcp_fax.phone_number) fax, hcp_email.email_address email_address
              FROM apps.hz_cust_accounts hp, apps.hz_relationships hr, apps.hz_parties h_contact,
                   apps.hz_contact_points hcp_email, apps.hz_contact_points hcp_fax, apps.hz_contact_points hcp,
                   apps.hz_org_contacts org_cont, apps.hz_cust_account_roles hcar, apps.hz_cust_acct_sites_all sites,
                   apps.hz_cust_site_uses_all uses
             WHERE     hr.subject_id = h_contact.party_id
                   AND hr.subject_type = 'PERSON'
                   AND hr.object_id = hp.party_id
                   AND hcp.owner_table_id(+) = hr.party_id
                   AND hcp.phone_line_type(+) = 'GEN'
                   AND hcp.contact_point_type(+) = 'PHONE'
                   AND hcp.status(+) = 'A'
                   AND hcp.primary_flag(+) = 'Y'
                   AND hcp_email.owner_table_id(+) = hr.party_id
                   AND hcp_email.contact_point_type(+) = 'EMAIL'
                   AND hcp_email.status(+) = 'A'
                   AND hcp_email.primary_flag(+) = 'Y'
                   AND hcp_fax.owner_table_id(+) = hr.party_id
                   AND hcp_fax.contact_point_type(+) = 'PHONE'
                   AND hcp_fax.phone_line_type(+) = 'FAX'
                   AND hcp_fax.status(+) = 'A'
                   AND org_cont.party_relationship_id = hr.relationship_id
                   AND hr.party_id = hcar.party_id
                   -- (hcar party_id is id of contact)
                   AND hcar.cust_account_id = hp.cust_account_id
                   AND hcar.status = 'A'
                   AND hcar.cust_acct_site_id IS NULL
                   AND hp.cust_account_id = sites.cust_account_id
                   AND sites.cust_acct_site_id = uses.cust_acct_site_id
                   AND uses.site_use_id = p_site_id
                   AND uses.site_use_code = 'BILL_TO'
                   AND hp.cust_account_id = p_cust_id;

        l_return             VARCHAR2 (5000);
        l_phone              VARCHAR2 (500);
        l_ret_phone          VARCHAR2 (5000);
        l_ret_fax            VARCHAR2 (5000);
        l_ret_email          VARCHAR2 (5000);
        l_fax                VARCHAR2 (500);
        l_contact_name       VARCHAR2 (5000);
        l_ret_contact_name   VARCHAR2 (5000);
    BEGIN
        FOR i IN c1 (p_cust_id, p_site_id)
        LOOP
            IF NVL (SUBSTR (l_phone, 2, 10), 'A') !=
               SUBSTR (i.raw_phone_number, 2, 10)
            THEN
                l_phone       := i.raw_phone_number;
                l_ret_phone   := l_ret_phone || ',' || i.phone;
            END IF;

            IF NVL (SUBSTR (l_fax, 2, 10), 'A') != SUBSTR (i.fax, 2, 10)
            THEN
                l_fax       := i.fax;
                l_ret_fax   := l_ret_fax || ',' || i.fax;
            END IF;

            IF NVL (l_contact_name, 'A') != i.contact_name
            THEN
                l_contact_name   := i.contact_name;
                l_ret_contact_name   :=
                    l_ret_contact_name || ',' || i.contact_name;
            END IF;

            l_ret_email   := l_ret_email || ',' || i.email_address;
        END LOOP;

        IF p_ret_col = 'PHONE'
        THEN
            l_return   := RPAD (TRIM (',' FROM l_ret_phone), 15, ' ');
        ELSIF p_ret_col = 'FAX'
        THEN
            l_return   := RPAD (TRIM (',' FROM l_ret_fax), 15, ' ');
        ELSIF p_ret_col = 'EMAIL'
        THEN
            l_return   := RPAD (TRIM (',' FROM l_ret_email), 40, ' ');
        ELSIF p_ret_col = 'CONTACT'
        THEN
            l_return   := TRIM (',' FROM l_ret_contact_name);
        END IF;

        RETURN NVL (l_return, ' ');
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END cust_contact_det;

    FUNCTION cust_addr_det (p_cust_id NUMBER, p_site_id NUMBER, p_use_code VARCHAR2
                            , p_ret_col VARCHAR2)
        RETURN VARCHAR2
    IS
        l_address1   VARCHAR2 (1000);
        l_address2   VARCHAR2 (1000);
        l_city       VARCHAR2 (100);
        l_zip        VARCHAR2 (100);
        l_state      VARCHAR2 (100);
        l_country    VARCHAR2 (1000);
        l_co_code    VARCHAR2 (100);
        l_return     VARCHAR2 (1000);
    BEGIN
        SELECT loc.address1,
               loc.address2,
               loc.city,
               loc.postal_code,
               loc.state,
               loc.country co_code,
               (SELECT meaning
                  FROM apps.fnd_common_lookups
                 WHERE     lookup_type = 'PER_US_COUNTRY_CODE'
                       AND enabled_flag = 'Y'
                       AND lookup_code = loc.country) country
          INTO l_address1, l_address2, l_city, l_zip,
                         l_state, l_co_code, l_country
          FROM apps.hz_party_sites psites, apps.hz_locations loc, apps.hz_cust_acct_sites_all sites,
               apps.hz_cust_site_uses_all uses, apps.hz_cust_accounts cust_acct, apps.hz_parties party
         WHERE     sites.party_site_id = psites.party_site_id
               AND loc.location_id = psites.location_id
               AND sites.cust_account_id = p_cust_id
               AND sites.cust_acct_site_id = uses.cust_acct_site_id
               --  and uses.PRIMARY_FLAG               = 'Y'
               AND uses.site_use_code = p_use_code
               AND uses.site_use_id = p_site_id
               AND sites.cust_account_id = cust_acct.cust_account_id
               AND cust_acct.party_id = party.party_id;

        IF p_ret_col = 'ADDR1'
        THEN
            l_return   := RPAD (l_address1, 30, ' ');
        ELSIF p_ret_col = 'ADDR2'
        THEN
            l_return   := RPAD (l_address2, 30, ' ');
        ELSIF p_ret_col = 'CITY'
        THEN
            l_return   := RPAD (l_city, 17, ' ');
        ELSIF p_ret_col = 'ZIP'
        THEN
            l_return   := RPAD (l_zip, 10, ' ');
        ELSIF p_ret_col = 'STATE'
        THEN
            l_return   := RPAD (l_state, 2, ' ');
        ELSIF p_ret_col = 'COUNTRY'
        THEN
            IF l_co_code = 'US'
            THEN
                l_return   := 'US';
            ELSE
                l_return   := RPAD (l_country, 17, ' ');
            END IF;
        END IF;

        RETURN NVL (l_return, ' ');
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END cust_addr_det;

    FUNCTION itm_color_style_desc (p_item_id      NUMBER,
                                   p_inv_org_id   NUMBER,
                                   p_ret_col      VARCHAR2)
        RETURN VARCHAR2
    IS
        l_return   VARCHAR2 (1000);
        l_color    VARCHAR2 (1000);
        l_style    VARCHAR2 (1000);
    BEGIN
        --Start modification by BT Technology Team on 19-Feb-2015

        /* SELECT style_descs.description, color_descs.description
            INTO l_style, l_color
            FROM apps.fnd_flex_values_vl color_descs,
                 apps.fnd_flex_values_vl style_descs,
                 apps.mtl_system_items_b itm
           WHERE itm.organization_id = p_inv_org_id
             AND itm.item_type IN ('P', 'PF')
             AND color_descs.flex_value = itm.segment2
             AND color_descs.flex_value_set_id = 1003724
             AND style_descs.flex_value = itm.segment1
             AND style_descs.flex_value_set_id = 1003729
             AND itm.inventory_item_id = p_item_id;*/
        SELECT comm_item.style_desc, comm_item.color_desc
          INTO l_style, l_color
          FROM apps.xxd_common_items_v comm_item, apps.mtl_system_items_b itm
         WHERE     comm_item.organization_id = itm.organization_id
               AND comm_item.organization_id = p_inv_org_id
               AND itm.item_type IN ('P', 'PF')
               AND comm_item.inventory_item_id = itm.inventory_item_id
               AND comm_item.inventory_item_id = p_item_id;

        --End modification by BT Technology Team on 19-Feb-2015
        IF p_ret_col = 'STYLE'
        THEN
            l_return   := l_style;
        ELSIF p_ret_col = 'COLOR'
        THEN
            l_return   := RPAD (l_color, 20, ' ');
        END IF;

        RETURN l_return;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END itm_color_style_desc;

    PROCEDURE main_prog (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, p_org_id IN NUMBER, p_batch_id IN NUMBER, p_file_name IN VARCHAR2, p_source IN VARCHAR2
                         , p_iden_rec IN VARCHAR2, p_sent_yn IN VARCHAR2)
    IS
        ln_request_id         NUMBER := 0;
        ln_request_id1        NUMBER := 0;
        lv_source_path        VARCHAR2 (100);
        lv_filename           VARCHAR2 (60);
        lv_fileserver         VARCHAR2 (80);
        lv_phasecode          VARCHAR2 (100) := NULL;
        lv_statuscode         VARCHAR2 (100) := NULL;
        lv_devphase           VARCHAR2 (100) := NULL;
        lv_devstatus          VARCHAR2 (100) := NULL;
        lv_returnmsg          VARCHAR2 (200) := NULL;
        lv_concreqcallstat    BOOLEAN := FALSE;
        lv_concreqcallstat1   BOOLEAN := FALSE;
        lv_concreqcallstat2   BOOLEAN := FALSE;
        lv_phasecode1         VARCHAR2 (100) := NULL;
        lv_statuscode1        VARCHAR2 (100) := NULL;
        lv_devphase1          VARCHAR2 (100) := NULL;
        lv_devstatus1         VARCHAR2 (100) := NULL;
        lv_returnmsg1         VARCHAR2 (200) := NULL;
        xml_layout            BOOLEAN;
        ex_batch_bal          EXCEPTION;
    BEGIN
        IF NOT is_batch_balanced (p_batch_id   => p_batch_id,
                                  p_org_id     => p_org_id)
        THEN
            RAISE ex_batch_bal;
        END IF;

        -- template  assigning.
        xml_layout    :=
            apps.fnd_request.add_layout ('XXDO', 'XXDOAR021', 'en',
                                         'US', 'ETEXT');
        -- Calling the report to generate the output
        ln_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'XXDO',
                program       => 'XXDOAR021',
                description   => '',
                start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                sub_request   => FALSE,
                argument1     => p_org_id,
                argument2     => p_batch_id,
                argument3     => p_file_name,
                argument4     => p_source,
                argument5     => p_iden_rec,
                argument6     => p_sent_yn);
        COMMIT;
        --
        lv_concreqcallstat1   :=
            apps.fnd_concurrent.wait_for_request (ln_request_id,
                                                  5 -- wait 5 seconds between db checks
                                                   ,
                                                  0,
                                                  lv_phasecode,
                                                  lv_statuscode,
                                                  lv_devphase,
                                                  lv_devstatus,
                                                  lv_returnmsg);
        --
        COMMIT;
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Request id is ' || ln_request_id);

        /* getting the Source Path */
        BEGIN
            SELECT SUBSTR (outfile_name, 1, INSTR (outfile_name, 'out') + 2)
              INTO lv_source_path
              FROM apps.fnd_concurrent_requests
             WHERE request_id = ln_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Concurrent Request id path is still  not available erroring out ');
                pv_retcode   := 2;
        END;

        /* Retrieving the File Server Name */
        BEGIN
            SELECT DECODE (applications_system_name, 'PROD', apps.fnd_profile.VALUE ('DO CIT: FTP Address'), apps.fnd_profile.VALUE ('DO CIT: Test FTP Address')) file_server_name
              INTO lv_fileserver
              FROM apps.fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Unable to fetch the File server name');
                pv_retcode   := 2;
        END;

        lv_filename   := 'XXDOAR021_' || ln_request_id || '_1.ETEXT';
        -- Checking the report status
        lv_concreqcallstat2   :=
            apps.fnd_concurrent.get_request_status (ln_request_id,
                                                    NULL,
                                                    NULL,
                                                    lv_phasecode1,
                                                    lv_statuscode1,
                                                    lv_devphase1,
                                                    lv_devstatus1,
                                                    lv_returnmsg1);

        WHILE lv_devphase1 != 'COMPLETE'
        LOOP
            lv_phasecode1    := NULL;
            lv_statuscode1   := NULL;
            lv_devphase1     := NULL;
            lv_devstatus1    := NULL;
            lv_returnmsg1    := NULL;
            lv_concreqcallstat2   :=
                apps.fnd_concurrent.get_request_status (ln_request_id,
                                                        NULL,
                                                        NULL,
                                                        lv_phasecode1,
                                                        lv_statuscode1,
                                                        lv_devphase1,
                                                        lv_devstatus1,
                                                        lv_returnmsg1);
            EXIT WHEN lv_devphase1 IN ('COMPLETE', 'ERROR', 'WARNING');
        END LOOP;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'lv_PhaseCode1 is ' || lv_phasecode1);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'lv_StatusCode1 is ' || lv_statuscode1);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'lv_DevPhase1 is ' || lv_devphase1);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'lv_DevStatus1 is ' || lv_devstatus1);

        IF     p_sent_yn = 'Y'
           AND lv_devphase1 = 'COMPLETE'
           AND lv_devstatus1 = 'NORMAL'
        THEN
            BEGIN
                ln_request_id1   :=
                    apps.fnd_request.submit_request (application => 'XXDO', program => 'XXDOOM005B', description => '', start_time => TO_CHAR (SYSDATE, 'DD-MON-YY'), sub_request => FALSE, argument1 => lv_source_path, argument2 => 'CIT_XXDOAR021', argument3 => lv_filename, argument4 => lv_fileserver
                                                     , argument5 => 'data.DI'--Added by Madhav Dhurjaty  on 12/13/13 CIT FTP Change
                                                                             --filetype=data.DI for invoice, data.CO for Orders
                                                                             );
                lv_phasecode    := NULL;
                lv_statuscode   := NULL;
                lv_devphase     := NULL;
                lv_devstatus    := NULL;
                lv_returnmsg    := NULL;
                COMMIT;
                lv_concreqcallstat   :=
                    apps.fnd_concurrent.wait_for_request (ln_request_id1,
                                                          5 -- wait 5 seconds between db checks
                                                           ,
                                                          0,
                                                          lv_phasecode,
                                                          lv_statuscode,
                                                          lv_devphase,
                                                          lv_devstatus,
                                                          lv_returnmsg);

                --  Updating the batch if success
                UPDATE apps.ar_batches_all
                   SET attribute10   = 'Y'
                 WHERE batch_id = p_batch_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception occured while running ftp program'
                        || SQLERRM);
                    pv_retcode   := 2;
            END;
        END IF;
    EXCEPTION
        WHEN ex_batch_bal
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Batch is not balanced. Please verify.');
            pv_retcode   := 1;
            pv_errbuf    := 'Batch is not balanced. Please see the log.';
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Exception occured while running Main program' || SQLERRM);
            pv_retcode   := 2;
    END main_prog;
END xxdoar021_rep_pkg;
/
