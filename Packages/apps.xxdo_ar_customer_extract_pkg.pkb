--
-- XXDO_AR_CUSTOMER_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AR_CUSTOMER_EXTRACT_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ar_customer_extract_pkg_b.sql   1.0    2014/10/08    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ar_customer_extract_pkg
    --
    -- Description  :  This is package for EBS to WMS Customer conversion
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 08-Oct-14    Infosys            1.0       Created
    -- ***************************************************************************

    -- ***************************************************************************
    -- Procedure/Function Name  :  Purge
    --
    -- Description              :  The purpose of this procedure is to purge the old ASN receipt records
    --
    -- parameters               :  p_out_chr_errbuf  out : Error message
    --                                   p_out_chr_retcode  out : Execution status
    --                                  p_in_num_purge_days  IN : Purge days
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/25    Infosys            1.0   Initial Version
    -- ***************************************************************************
    PROCEDURE purge (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER)
    IS
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (
            fnd_file.LOG,
            'Purging ' || p_in_num_purge_days || ' days old records...');

        BEGIN
            INSERT INTO xxdo_ar_customer_extract_log (customer_code, customer_name, status, customer_addr1, customer_addr2, customer_addr3, customer_city, customer_state, customer_zip, customer_country_code, customer_country_name, customer_phone, customer_email, customer_category, process_status, error_message, Request_ID, creation_date, created_by, last_update_date, last_updated_by, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, cust_account_id, account_number, party_id, party_site_id, cust_acct_site_id, cust_acct_site_use_id, location_id, operating_unit_id, extract_seq_id, archive_date
                                                      , archive_request_id)
                SELECT customer_code, customer_name, status,
                       customer_addr1, customer_addr2, customer_addr3,
                       customer_city, customer_state, customer_zip,
                       customer_country_code, customer_country_name, customer_phone,
                       customer_email, customer_category, process_status,
                       error_message, Request_ID, creation_date,
                       created_by, last_update_date, last_updated_by,
                       attribute1, attribute2, attribute3,
                       attribute4, attribute5, attribute6,
                       attribute7, attribute8, attribute9,
                       attribute10, attribute11, attribute12,
                       attribute13, attribute14, attribute15,
                       attribute16, attribute17, attribute18,
                       attribute19, attribute20, cust_account_id,
                       account_number, party_id, party_site_id,
                       cust_acct_site_id, cust_acct_site_use_id, location_id,
                       operating_unit_id, extract_seq_id, SYSDATE,
                       g_num_request_id
                  FROM xxdo_ar_customer_extract_stg
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_ar_customer_extract_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving old customer extract data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving old customer extract data: '
                    || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            p_out_chr_retcode   := '1';
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexepected error while purging the records' || SQLERRM);
    END PURGE;

    -- ***************************************************************************
    -- Procedure/Function Name  :  main
    --
    -- Description              :  This is the driver procedure which processes the receipts
    --
    -- parameters               :  p_out_chr_errbuf OUT : Error message
    --                                   p_out_chr_retcode OUT : Execution status
    --                                p_in_chr_process_mode IN : Process mode - Process or Reprocess
    --                                p_in_chr_warehouse    IN  : Warehouse code
    --                                p_in_chr_shipment_no  IN  : Shipment number
    --                                p_in_chr_source       IN  : Source  - WMS
    --                                p_in_chr_dest         IN   : Destination  - EBS
    --                                p_in_num_purge_days   IN  : Purge days
    --                                p_in_num_bulk_limit   IN  : Bulk Limit
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/25    Infosys            1.0   Initial Version
    -- ***************************************************************************

    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_org_id IN NUMBER
                    , p_in_num_no_of_months IN NUMBER, p_in_num_purge_days IN NUMBER, p_in_num_bulk_limit IN NUMBER)
    IS
        l_chr_errbuf               VARCHAR2 (4000);
        l_chr_retcode              VARCHAR2 (30);
        l_num_error_count          NUMBER;
        l_customer_dtl_tab         g_customer_dtl_tab_type;
        l_exe_bulk_fetch_failed    EXCEPTION;
        l_exe_bulk_insert_failed   EXCEPTION;
        l_exe_dml_errors           EXCEPTION;
        PRAGMA EXCEPTION_INIT (l_exe_dml_errors, -24381);

        CURSOR cur_customer_dtl (p_num_org_id         IN NUMBER,
                                 p_num_no_of_months   IN NUMBER)
        IS
            SELECT --          'ERP:' || hcsua.org_id || ':' || hca.account_number  customer_code,
                   hca.account_number
                       customer_code,
                   hp.party_name
                       customer_name,
                   DECODE (hca.status,  'A', 'Active',  'I', 'Inactive')
                       status,
                   hl.address1
                       customer_addr1,
                   hl.address2
                       customer_addr2,
                   hl.address3
                       customer_addr3,                          --hl.address4,
                   hl.city
                       customer_city,
                   hl.state
                       customer_state,
                   --hl.province,
                   hl.postal_code
                       customer_zip,
                   -- hl.county,
                   hl.country
                       customer_country_code,
                   ftt.territory_short_name
                       customer_country_name,
                   (SELECT raw_phone_number
                      FROM ar.hz_contact_points hcp
                     WHERE     hcp.owner_table_name = 'HZ_PARTY_SITES'
                           AND owner_table_id = hcasa.party_site_id
                           AND contact_point_type = 'PHONE'
                           AND primary_flag = 'Y'
                           AND ROWNUM = 1)
                       customer_phone,
                   (SELECT email_address
                      FROM ar.hz_contact_points hcp
                     WHERE     hcp.owner_table_name = 'HZ_PARTY_SITES'
                           AND owner_table_id = hcasa.party_site_id
                           AND contact_point_type = 'EMAIL'
                           AND primary_flag = 'Y'
                           AND ROWNUM = 1)
                       customer_email,
                   (SELECT meaning
                      FROM apps.ar_lookups
                     WHERE     lookup_type = 'CUSTOMER_CATEGORY'
                           AND lookup_code = hcasa.customer_category_code)
                       customer_category,
                   'NEW'
                       process_status,
                   NULL
                       error_message,
                   g_num_request_id
                       request_id,
                   SYSDATE
                       creation_date,
                   g_num_user_id
                       created_by,
                   SYSDATE
                       last_update_date,
                   g_num_user_id
                       last_updated_by,
                   NULL
                       attribute1,
                   NULL
                       attribute2,
                   NULL
                       attribute3,
                   NULL
                       attribute4,
                   NULL
                       attribute5,
                   NULL
                       attribute6,
                   NULL
                       attribute7,
                   NULL
                       attribute8,
                   NULL
                       attribute9,
                   NULL
                       attribute10,
                   NULL
                       attribute11,
                   NULL
                       attribute12,
                   NULL
                       attribute13,
                   NULL
                       attribute14,
                   NULL
                       attribute15,
                   NULL
                       attribute16,
                   NULL
                       attribute17,
                   NULL
                       attribute18,
                   NULL
                       attribute19,
                   NULL
                       attribute20,
                   hca.cust_account_id,
                   hca.account_number,
                   hp.party_id,
                   hps.party_site_id,
                   hcasa.cust_acct_site_id,
                   hcsua.site_use_id
                       cust_acct_site_use_id,
                   hl.location_id,
                   hcsua.org_id
                       operating_unit_id,
                   xxdo_ar_cust_extract_stg_s.NEXTVAL
                       extract_seq_id
              FROM hz_cust_accounts hca, hz_cust_acct_sites_all hcasa, hz_cust_site_uses_all hcsua,
                   hz_party_sites hps, hz_locations hl, hz_parties hp,
                   fnd_territories_tl ftt
             WHERE     hcasa.cust_account_id = hca.cust_account_id
                   AND hcasa.org_id = p_num_org_id
                   AND hcasa.status = 'A'              -- and hcasa.org_id = 2
                   AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                   AND hcsua.org_id = hcasa.org_id
                   AND hcsua.site_use_code = 'SHIP_TO'
                   AND hcsua.primary_flag = 'Y'
                   AND hcsua.status = 'A'
                   AND hps.party_site_id = hcasa.party_site_id
                   AND hl.location_id = hps.location_id
                   AND hp.party_id = hca.party_id
                   AND ftt.territory_code = hl.country
                   AND ftt.LANGUAGE = 'US'
                   AND hca.cust_account_id NOT IN (4712, 1641, 1877,
                                                   2139, 2408, 4987,
                                                   6486, 9263, 3193295,
                                                   61456883)
                   AND hca.cust_account_id IN
                           (SELECT sold_to_org_id
                              FROM oe_order_headers_all
                             WHERE     ordered_date >
                                       ADD_MONTHS (SYSDATE,
                                                   -p_num_no_of_months)
                                   AND org_id = p_num_org_id);
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        IF p_in_num_purge_days IS NOT NULL
        THEN
            -- Purge the records
            BEGIN
                PURGE (p_out_chr_errbuf      => l_chr_errbuf,
                       p_out_chr_retcode     => l_chr_retcode,
                       p_in_num_purge_days   => p_in_num_purge_days);

                IF l_chr_retcode <> '0'
                THEN
                    p_out_chr_errbuf    :=
                        'Error in Purge procedure : ' || l_chr_errbuf;
                    p_out_chr_retcode   := '1';
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                        p_in_num_purge_days || ' old days records are purged');
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf    :=
                           'Unexpected error while invoking purge procedure : '
                        || SQLERRM;
                    p_out_chr_retcode   := '1';
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            END;
        END IF;

        -- Extract header
        fnd_file.put_line (
            fnd_file.output,
               'customer_code'
            || CHR (9)
            || 'customer_name'
            || CHR (9)
            || 'status'
            || CHR (9)
            || 'customer_addr1'
            || CHR (9)
            || 'customer_addr2'
            || CHR (9)
            || 'customer_addr3'
            || CHR (9)
            || 'customer_city'
            || CHR (9)
            || 'customer_state'
            || CHR (9)
            || 'customer_zip'
            || CHR (9)
            || 'customer_country_code'
            || CHR (9)
            || 'customer_country_name'
            || CHR (9)
            || 'customer_phone'
            || CHR (9)
            || 'customer_email'
            || CHR (9)
            || 'customer_category');


        OPEN cur_customer_dtl (p_in_num_org_id, p_in_num_no_of_months);

        LOOP
            IF l_customer_dtl_tab.EXISTS (1)
            THEN
                l_customer_dtl_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_customer_dtl
                    BULK COLLECT INTO l_customer_dtl_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_customer_dtl;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Customer Extract : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_customer_dtl_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN l_customer_dtl_tab.FIRST .. l_customer_dtl_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ar_customer_extract_stg
                         VALUES l_customer_dtl_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    l_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of Customer Extract data: '
                        || l_num_error_count);

                    FOR i IN 1 .. l_num_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;
                --                              CLOSE cur_customer_dtl;
                --                              RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_customer_dtl;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Insert of Customer Extract : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;

            FOR l_num_ind IN l_customer_dtl_tab.FIRST ..
                             l_customer_dtl_tab.LAST
            LOOP
                fnd_file.put_line (
                    fnd_file.output,
                       l_customer_dtl_tab (l_num_ind).customer_code
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_name
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).status
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_addr1
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_addr2
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_addr3
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_city
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_state
                    || CHR (9)
                    || ''''
                    || l_customer_dtl_tab (l_num_ind).customer_zip
                    || ''''
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_country_code
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_country_name
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_phone
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_email
                    || CHR (9)
                    || l_customer_dtl_tab (l_num_ind).customer_category);
            END LOOP;

            COMMIT;
        END LOOP;                                -- Receipt headers fetch loop

        CLOSE cur_customer_dtl;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                'Unexpected error at main procedure : ' || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END main;
END xxdo_ar_customer_extract_pkg;
/
