--
-- XXDO_AR_CUST_VAT_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AR_CUST_VAT_UPD_PKG"
AS
    /******************************************************************************
    -- NAME:       XXDO_AR_CUST_VAT_UPD_PKG
    -- PURPOSE:   To define procedures used for customer site-use VAT Number update
    -- REVISIONS:
    -- Ver      Date          Author          Description
    -- -----    ----------    -------------   -----------------------------------
    -- 1.0      24-OCT-2016    Infosys         Initial version
    ******************************************************************************/
    -- global variables
    g_request_id     NUMBER := 0;
    g_process_type   VARCHAR2 (100);

    -- Procedure to update vat number
    PROCEDURE xxdoar_upd_vat_number
    IS
        -- Cursor to fetch records for vat number update
        CURSOR c_upd_vat_number IS
            SELECT hou.organization_id, xacvu.*
              FROM xxdo_ar_cust_vat_upd xacvu, hr_operating_units hou
             WHERE     hou.name = xacvu.operating_unit
                   AND request_id = g_request_id
                   AND status_flag = 'NEW'
                   AND error_description IS NULL
                   AND xacvu.tax_reference IS NOT NULL;

        CURSOR c_get_cust_site_det (cp_cust_acct_site_id VARCHAR2, cp_account_number VARCHAR2, cp_organization_id NUMBER)
        IS
            SELECT hcas.cust_acct_site_id, hcsu.site_use_code, hcsu.site_use_id,
                   hcsu.object_version_number, hcsu.orig_system_reference
              FROM hz_parties hp, hz_party_sites hps, hz_cust_accounts_all hca,
                   hz_cust_acct_sites_all hcas, hr_operating_units hou, hz_cust_site_uses_all hcsu
             WHERE     hp.party_id = hca.party_id
                   AND hca.cust_account_id = hcas.cust_account_id(+)
                   AND hca.status = 'A'
                   AND hps.party_site_id(+) = hcas.party_site_id
                   AND hcas.org_id = hou.organization_id
                   AND hcas.status = 'A'
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.org_id = hcsu.org_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hcsu.status = 'A'
                   AND hcas.cust_acct_site_id = cp_cust_acct_site_id
                   AND hca.account_number = cp_account_number
                   AND hcsu.org_id = cp_organization_id;

        --
        -- Local Variable declaration
        lv_return_status           VARCHAR2 (200);
        x_return_status            VARCHAR2 (10);
        x_msg_count                NUMBER (10);
        x_msg_data                 VARCHAR2 (1200);
        P_CUST_SITE_USE_REC        hz_cust_account_site_v2pub.CUST_SITE_USE_REC_TYPE;
        lv_msg                     VARCHAR2 (200);
        lv_cust_site_count         VARCHAR2 (1);
        ln_context_org_id          NUMBER;
        ln_object_version_number   NUMBER;
        lv_update_req_flag         VARCHAR2 (1);
        lv_chr_error_message       VARCHAR2 (4000);
        lv_chr_error_code          VARCHAR2 (20);
        lv_operating_unit          VARCHAR2 (200);
        lv_total_count             NUMBER;
        lv_success_count           NUMBER;
        lv_error_count             NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside xxdoar_upd_vat_number procedure ');

        --
        FOR c_record IN c_upd_vat_number
        LOOP
            ln_context_org_id      := c_record.organization_id;
            lv_cust_site_count     := 0;
            lv_chr_error_message   := NULL;
            lv_chr_error_code      := NULL;
            lv_total_count         := 0;
            lv_success_count       := 0;
            lv_error_count         := 0;
            fnd_file.put_line (
                fnd_file.LOG,
                '------------------------------------------------------------------------------');
            fnd_file.put_line (
                fnd_file.LOG,
                'Process record for customer :' || c_record.account_number);

            --
            IF ln_context_org_id IS NOT NULL
            THEN
                mo_global.set_policy_context ('S', ln_context_org_id);
            END IF;

            SELECT COUNT (1)
              INTO lv_cust_site_count
              FROM hz_parties hp, hz_party_sites hps, hz_cust_accounts_all hca,
                   hz_cust_acct_sites_all hcas, hr_operating_units hou, hz_cust_site_uses_all hcsu
             WHERE     hp.party_id = hca.party_id
                   AND hca.cust_account_id = hcas.cust_account_id(+)
                   AND hca.status = 'A'
                   AND hps.party_site_id(+) = hcas.party_site_id
                   AND hcas.org_id = hou.organization_id
                   AND hcas.status = 'A'
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.org_id = hcsu.org_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hcsu.status = 'A'
                   AND hcas.cust_acct_site_id = c_record.cust_acct_site_id
                   AND hca.account_number = c_record.account_number
                   AND hcsu.org_id = c_record.organization_id;

            IF lv_cust_site_count = 0
            THEN
                lv_chr_error_message   :=
                       lv_chr_error_message
                    || '-'
                    || 'Cust Account Not Found :'
                    || c_record.account_number
                    || 'cust_acct_site_id :'
                    || c_record.cust_acct_site_id
                    || ' Org:'
                    || c_record.operating_unit;
                fnd_file.put_line (fnd_file.LOG, lv_chr_error_message);
                lv_chr_error_code   := 'ERROR';
            ELSIF (lv_cust_site_count > 0 AND lv_chr_error_code IS NULL)
            THEN
                BEGIN
                    FOR r_get_cust_site_det
                        IN c_get_cust_site_det (c_record.cust_acct_site_id,
                                                c_record.account_number,
                                                c_record.organization_id)
                    LOOP
                        -- Flush messages existing already
                        FND_MSG_PUB.Delete_Msg;
                        x_return_status   := NULL;
                        P_CUST_SITE_USE_REC.site_use_id   :=
                            r_get_cust_site_det.site_use_id;
                        P_CUST_SITE_USE_REC.cust_acct_site_id   :=
                            r_get_cust_site_det.cust_acct_site_id;
                        P_CUST_SITE_USE_REC.site_use_code   :=
                            r_get_cust_site_det.site_use_code;
                        p_cust_site_use_rec.orig_system   :=
                            r_get_cust_site_det.orig_system_reference;
                        P_CUST_SITE_USE_REC.tax_reference   :=
                            c_record.tax_reference;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Call to hz_cust_account_site_v2pub.update_cust_site_use API');

                        --
                        BEGIN
                            hz_cust_account_site_v2pub.update_cust_site_use (
                                p_init_msg_list       => 'T',
                                P_CUST_SITE_USE_REC   => P_CUST_SITE_USE_REC,
                                p_object_version_number   =>
                                    r_get_cust_site_det.object_version_number,
                                x_return_status       => x_return_status,
                                x_msg_count           => x_msg_count,
                                x_msg_data            => x_msg_data);

                            IF (x_return_status <> fnd_api.g_ret_sts_success)
                            THEN
                                FOR i IN 1 .. fnd_msg_pub.count_msg
                                LOOP
                                    x_msg_data          :=
                                        fnd_msg_pub.get (
                                            p_msg_index   => i,
                                            p_encoded     => fnd_api.g_false);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'The API call failed with error '
                                        || x_msg_data);
                                    lv_chr_error_code   := 'ERROR';
                                    lv_chr_error_message   :=
                                           lv_chr_error_message
                                        || ';'
                                        || 'ERROR in update API';
                                END LOOP;
                            ELSE
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'The API call status - SUCESSS');
                                COMMIT;
                                lv_chr_error_code   := 'SUCCESS';
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error while executing API. Error -'
                                    || SQLERRM);
                                lv_chr_error_code   := 'ERROR';
                                lv_chr_error_message   :=
                                       lv_chr_error_message
                                    || ';'
                                    || 'Error while executing API';
                        END;
                    END LOOP;
                END;
            END IF;

            --
            --Update success and error record details
            IF lv_chr_error_code = 'ERROR'
            THEN
                --
                UPDATE xxdo_ar_cust_vat_upd
                   SET status_flag = 'ERROR', error_description = lv_chr_error_message, -- operating_unit    = lv_operating_unit ,
                                                                                        last_update_date = SYSDATE,
                       last_updated_by = fnd_global.user_id
                 WHERE     request_id = g_request_id
                       AND account_number = c_record.account_number;
            --
            --
            ELSE
                UPDATE xxdo_ar_cust_vat_upd
                   SET status_flag = 'SUCCESS', error_description = NULL, --  operating_unit    = lv_operating_unit ,
                                                                          last_update_date = SYSDATE,
                       last_updated_by = fnd_global.user_id
                 WHERE     request_id = g_request_id
                       AND account_number = c_record.account_number;
            END IF;

            COMMIT;
        END LOOP;                                        -- End of cursor loop

        --
        fnd_file.put_line (
            fnd_file.LOG,
            '------------------------------------------------------------------------------');

        --
        --
        BEGIN
            SELECT COUNT (*)
              INTO lv_total_count
              FROM xxdo_ar_cust_vat_upd
             WHERE request_id = g_request_id;

            fnd_file.put_line (
                fnd_file.LOG,
                'Count of records to be processed ::' || lv_total_count);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in fetching count of records to be processed ::'
                    || SQLERRM);
        END;

        --
        --
        BEGIN
            SELECT COUNT (*)
              INTO lv_success_count
              FROM xxdo_ar_cust_vat_upd
             WHERE status_flag = 'SUCCESS' AND request_id = g_request_id;

            fnd_file.put_line (
                fnd_file.LOG,
                'Count of records in SUCCESS ::' || lv_success_count);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in fetching count of SUCCESS records ::'
                    || SQLERRM);
        END;

        --
        --
        BEGIN
            SELECT COUNT (*)
              INTO lv_error_count
              FROM xxdo_ar_cust_vat_upd
             WHERE status_flag = 'ERROR' AND request_id = g_request_id;

            fnd_file.put_line (
                fnd_file.LOG,
                'Count of records in ERROR ::' || lv_error_count);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error in fetching count of ERROR records ::' || SQLERRM);
        END;

        --
        --
        fnd_file.put_line (fnd_file.LOG,
                           'Exiting xxdoar_upd_vat_number procedure ');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error in xxdoar_upd_vat_number procedure :' || SQLERRM);
    END xxdoar_upd_vat_number;

    --
    --
    -- Main procedure
    /*******************************************************************************
    -- Name:                MAIN
    -- Type:                PROCEDURE
    -- Description:         Main procedure to be called from concurrent program
    --                      to load/validate/update customer information
    *******************************************************************************/
    PROCEDURE main_proc (errbuf       OUT NOCOPY VARCHAR2,
                         retcode      OUT NOCOPY NUMBER)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside main procedure...');
        g_request_id   := fnd_global.conc_request_id;

        --
        --
        BEGIN
            UPDATE xxdo_ar_cust_vat_upd
               SET request_id = g_request_id, creation_date = SYSDATE, created_by = fnd_global.user_id,
                   last_update_date = SYSDATE, last_updated_by = fnd_global.user_id
             WHERE request_id IS NULL AND STATUS_FLAG = 'NEW';

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error in updating request id :' || SQLERRM);
        END;

        -- Call procedure to update vat number
        xxdoar_upd_vat_number;
        --
        fnd_file.put_line (fnd_file.LOG, 'Exiting main procedure...');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in main procedure :' || SQLERRM);
    END main_proc;
END XXDO_AR_CUST_VAT_UPD_PKG;
/
