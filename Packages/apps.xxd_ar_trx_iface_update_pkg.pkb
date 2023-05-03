--
-- XXD_AR_TRX_IFACE_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_TRX_IFACE_UPDATE_PKG"
AS
    --  ####################################################################################################
    --  Package      : xxd_ar_trx_iface_update_pkg
    --  Design       : This package is used to update the records in RA Interface Tables.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  22-Mar-2020     1.0        Showkath Al             Initial Version
    --  17-DEC-2020     2.0        Srinath Siricilla       CCR0008507
    --  20-JAN-2020     3.0        Satyanarayana Kotha     CCR0009060
    --  ####################################################################################################
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    g_set_pcc_value            VARCHAR2 (50)
        := NVL (fnd_profile.VALUE ('XXD_AR_REMOVE_TAX_CODE'), 'N'); -- Added for CCR0008507

    /***********************************************************************************************
    ************** Function to get Code combination based on Auto Accounting Setup *****************
    ************************************************************************************************/

    FUNCTION get_autoacct_seg_value (
        p_err_msg                OUT VARCHAR2,
        p_acct_type           IN     VARCHAR2,
        p_acct_seg            IN     VARCHAR2,
        p_inv_org_id          IN     NUMBER,
        p_salesrep_id         IN     NUMBER,
        p_cust_acct_site_id   IN     NUMBER,
        p_cust_trx_type_id    IN     NUMBER,
        p_item_id             IN     NUMBER,
        p_org_id              IN     NUMBER,
        p_memo_line_id        IN     NUMBER,
        p_segment_source      IN     VARCHAR2 DEFAULT NULL)
        RETURN VARCHAR2
    IS
        lv_segment_source     ra_account_default_segments.table_name%TYPE;
        lv_segment_constant   ra_account_default_segments.CONSTANT%TYPE;
        lv_num_coa_id         NUMBER;
        lv_seg_value          gl_code_combinations.segment1%TYPE;
    BEGIN
        IF p_acct_type NOT IN ('REV')
        THEN                                        --Receivable, Revenue, Tax
            lv_seg_value   := 'INVALID_ACCTTYPE';
        ELSE
            --Get the Source of Location Segment
            IF p_segment_source IS NULL
            THEN
                BEGIN
                    SELECT rads.table_name, rads.CONSTANT
                      INTO lv_segment_source, lv_segment_constant
                      FROM ra_account_default_segments rads, ra_account_defaults_all rad
                     WHERE     1 = 1
                           AND rad.TYPE = p_acct_type
                           AND rad.org_id = p_org_id
                           AND rads.gl_default_id = rad.gl_default_id
                           AND rads.SEGMENT = p_acct_seg;

                    IF lv_segment_constant IS NULL
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               p_acct_type
                            || ' '
                            || p_acct_seg
                            || ' comes from: '
                            || lv_segment_source);
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               p_acct_type
                            || ' '
                            || p_acct_seg
                            || ' is Constant: '
                            || lv_segment_constant);
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_segment_constant   := 'ERR';
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error in getting Segment Value: '
                            || p_acct_type
                            || ' '
                            || p_acct_seg);
                END;
            ELSE
                lv_segment_source     := p_segment_source;
                lv_segment_constant   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       p_acct_type
                    || ' '
                    || p_acct_seg
                    || ' comes from: '
                    || lv_segment_source);
            END IF;

            --Check if there's a Constant, then thats the Segment Value.
            --Else get it from the Source table.
            IF lv_segment_constant IS NOT NULL
            THEN
                lv_seg_value   := lv_segment_constant;
            ELSE
                IF lv_segment_source = 'RA_SALESREPS'
                THEN
                    BEGIN
                        --SalesRep does not have Tax Account. Both Revenue and Tax Accounting
                        --are derived from Revenue Account Code defined for the SalesRep
                        SELECT DECODE (p_acct_seg,  'SEGMENT1', gcc.segment1,  'SEGMENT2', gcc.segment2,  'SEGMENT3', gcc.segment3,  'SEGMENT4', gcc.segment4,  'SEGMENT5', gcc.segment5,  'SEGMENT6', gcc.segment6,  'SEGMENT7', gcc.segment7,  'SEGMENT8', gcc.segment8,  'INVALID_SEG')
                          INTO lv_seg_value
                          FROM ra_salesreps_all rs, gl_code_combinations gcc
                         WHERE     1 = 1
                               AND rs.salesrep_id = p_salesrep_id --r_raintfoe.primary_salesrep_id
                               AND gcc.code_combination_id = rs.gl_id_rev;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Value of  '
                            || p_acct_seg
                            || ' is:'
                            || lv_seg_value);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_seg_value   := NULL;
                            p_err_msg      :=
                                   'Error in getting '
                                || p_acct_seg
                                || ' for '
                                || p_acct_type
                                || ' from SalesReps with SalesRep Id: '
                                || p_salesrep_id;
                            fnd_file.put_line (fnd_file.LOG, p_err_msg);
                            fnd_file.put_line (fnd_file.LOG,
                                               SUBSTR (SQLERRM, 1, 100));
                    END;
                ELSIF lv_segment_source = 'RA_SITE_USES'
                THEN
                    BEGIN
                        SELECT DECODE (p_acct_seg,  'SEGMENT1', gcc.segment1,  'SEGMENT2', gcc.segment2,  'SEGMENT3', gcc.segment3,  'SEGMENT4', gcc.segment4,  'SEGMENT5', gcc.segment5,  'SEGMENT6', gcc.segment6,  'SEGMENT7', gcc.segment7,  'SEGMENT8', gcc.segment8,  'INVALID_SEG')
                          INTO lv_seg_value
                          FROM gl_code_combinations gcc, hz_cust_site_uses_all hcsu
                         WHERE     hcsu.site_use_code = 'BILL_TO'
                               AND hcsu.cust_acct_site_id =
                                   p_cust_acct_site_id
                               AND gcc.code_combination_id =
                                   DECODE (p_acct_type,
                                           'REV', hcsu.gl_id_rev,
                                           'REC', hcsu.gl_id_rec,
                                           hcsu.gl_id_tax);

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Value of  '
                            || p_acct_seg
                            || ' is:'
                            || lv_seg_value);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_seg_value   := NULL;
                            p_err_msg      :=
                                   'Error in getting '
                                || p_acct_seg
                                || ' for '
                                || p_acct_type
                                || ' from Bill to Site: '
                                || p_cust_acct_site_id;
                            fnd_file.put_line (fnd_file.LOG, p_err_msg);
                            fnd_file.put_line (fnd_file.LOG,
                                               SUBSTR (SQLERRM, 1, 100));
                    END;
                ELSIF lv_segment_source = 'RA_CUST_TRX_TYPES'
                THEN
                    BEGIN
                        SELECT DECODE (p_acct_seg,  'SEGMENT1', gcc.segment1,  'SEGMENT2', gcc.segment2,  'SEGMENT3', gcc.segment3,  'SEGMENT4', gcc.segment4,  'SEGMENT5', gcc.segment5,  'SEGMENT6', gcc.segment6,  'SEGMENT7', gcc.segment7,  'SEGMENT8', gcc.segment8,  'INVALID_SEG')
                          INTO lv_seg_value
                          FROM ra_cust_trx_types_all rctt, gl_code_combinations gcc
                         WHERE     1 = 1
                               AND rctt.cust_trx_type_id = p_cust_trx_type_id
                               AND gcc.code_combination_id =
                                   DECODE (p_acct_type,
                                           'REV', rctt.gl_id_rev,
                                           'REC', rctt.gl_id_rec,
                                           rctt.gl_id_tax);

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Value of  '
                            || p_acct_seg
                            || ' is:'
                            || lv_seg_value);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_seg_value   := NULL;
                            p_err_msg      :=
                                   'Error in getting '
                                || p_acct_seg
                                || ' for '
                                || p_acct_type
                                || ' from Transaction Types with Trx Type Id: '
                                || p_cust_trx_type_id;
                            fnd_file.put_line (fnd_file.LOG, p_err_msg);
                            fnd_file.put_line (fnd_file.LOG,
                                               SUBSTR (SQLERRM, 1, 100));
                    END;
                ELSIF lv_segment_source = 'RA_STD_TRX_LINES'
                THEN
                    BEGIN
                        --Item does not have Tax Account. Both Revenue and Tax Accounting
                        --are derived from Sales Account Code defined for the Item
                        SELECT DECODE (p_acct_seg,  'SEGMENT1', gcc.segment1,  'SEGMENT2', gcc.segment2,  'SEGMENT3', gcc.segment3,  'SEGMENT4', gcc.segment4,  'SEGMENT5', gcc.segment5,  'SEGMENT6', gcc.segment6,  'SEGMENT7', gcc.segment7,  'SEGMENT8', gcc.segment8,  'INVALID_SEG')
                          INTO lv_seg_value
                          FROM mtl_system_items_b msi, gl_code_combinations gcc
                         WHERE     msi.inventory_item_id = p_item_id
                               AND msi.organization_id = p_inv_org_id
                               AND gcc.code_combination_id =
                                   msi.sales_account;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Value of  '
                            || p_acct_seg
                            || ' is:'
                            || lv_seg_value);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            BEGIN
                                SELECT DECODE (p_acct_seg,  'SEGMENT1', gcc.segment1,  'SEGMENT2', gcc.segment2,  'SEGMENT3', gcc.segment3,  'SEGMENT4', gcc.segment4,  'SEGMENT5', gcc.segment5,  'SEGMENT6', gcc.segment6,  'SEGMENT7', gcc.segment7,  'SEGMENT8', gcc.segment8,  'INVALID_SEG')
                                  INTO lv_seg_value
                                  FROM ar_memo_lines_all_b aml, gl_code_combinations gcc
                                 WHERE     gcc.code_combination_id =
                                           aml.gl_id_rev
                                       AND aml.memo_line_id = p_memo_line_id;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Value of  '
                                    || p_acct_seg
                                    || ' is:'
                                    || lv_seg_value);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_seg_value   := NULL;
                                    p_err_msg      :=
                                           'Error in getting '
                                        || p_acct_seg
                                        || ' for '
                                        || p_acct_type
                                        || ' from Standard Memo Lines with Item: '
                                        || p_item_id;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       p_err_msg);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        SUBSTR (SQLERRM, 1, 100));
                                    RETURN NVL (lv_seg_value, 'NO_VAL');
                            END;
                        WHEN OTHERS
                        THEN
                            lv_seg_value   := NULL;
                            p_err_msg      :=
                                   'Error in getting '
                                || p_acct_seg
                                || ' for '
                                || p_acct_type
                                || ' from Standard Lines with Item: '
                                || p_item_id;
                            fnd_file.put_line (fnd_file.LOG, p_err_msg);
                            fnd_file.put_line (fnd_file.LOG,
                                               SUBSTR (SQLERRM, 1, 100));
                    END;                           /*IF p_tax_id IS NOT NULL*/
                END IF;             /*IF lv_segment_source = 'RA_SALESREPS' */
            END IF;                    /*IF lv_segment_constant IS NOT NULL */
        END IF;                       /*IF p_acct_type NOT IN ('REV', 'TAX')*/

        RETURN NVL (lv_seg_value, 'NO_VAL');
    END get_autoacct_seg_value;

    /***********************************************************************************************
    ************************************** Main Procedure ******************************************
    ************************************************************************************************/

    PROCEDURE trx_iface_update_main_prc (p_errbuf              OUT VARCHAR2,
                                         p_retcode             OUT NUMBER,
                                         p_operating_unit   IN     NUMBER,
                                         p_pay_date_from    IN     VARCHAR2,
                                         p_pay_date_to      IN     VARCHAR2)
    IS
        CURSOR eligible_trade_line_records IS
            SELECT *
              FROM apps.ra_interface_lines_all rila
             WHERE     1 = 1
                   AND rila.interface_line_context = 'CLAIM'
                   AND rila.org_id = p_operating_unit
                   AND TRUNC (rila.creation_date) BETWEEN NVL (
                                                              TRUNC (
                                                                  TO_DATE (
                                                                      p_pay_date_from,
                                                                      'YYYY/MM/DD HH24:MI:SS')),
                                                              TRUNC (
                                                                  rila.creation_date))
                                                      AND NVL (
                                                              TRUNC (
                                                                  TO_DATE (
                                                                      p_pay_date_to,
                                                                      'YYYY/MM/DD HH24:MI:SS')),
                                                              TRUNC (
                                                                  rila.creation_date))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                             WHERE     1 = 1
                                   AND ffvs.flex_value_set_name =
                                       'XXD_AR_TRANSACTION_SOURCE_VS'
                                   AND ffvs.flex_value_set_id =
                                       ffvl.flex_value_set_id
                                   AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                                   AND NVL (ffvl.start_date_active, SYSDATE) <=
                                       SYSDATE
                                   AND NVL (ffvl.end_date_active, SYSDATE) >=
                                       SYSDATE
                                   AND ffvl.attribute2 =
                                       (SELECT batch_source_id
                                          FROM ra_batch_sources_all
                                         WHERE     name =
                                                   rila.batch_source_name
                                               AND org_id = rila.org_id)
                                   AND NVL (ffvl.attribute1, rila.org_id) =
                                       rila.org_id); --Query to fetch the Source and org to consider the updation from value set

        CURSOR lines_records_count IS
            SELECT COUNT (1)
              FROM apps.ra_interface_lines_all rila
             WHERE     1 = 1
                   AND rila.interface_line_context = 'CLAIM'
                   AND rila.org_id = p_operating_unit
                   AND TRUNC (rila.creation_date) BETWEEN NVL (
                                                              TRUNC (
                                                                  TO_DATE (
                                                                      p_pay_date_from,
                                                                      'YYYY/MM/DD HH24:MI:SS')),
                                                              TRUNC (
                                                                  rila.creation_date))
                                                      AND NVL (
                                                              TRUNC (
                                                                  TO_DATE (
                                                                      p_pay_date_to,
                                                                      'YYYY/MM/DD HH24:MI:SS')),
                                                              TRUNC (
                                                                  rila.creation_date))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                             WHERE     1 = 1
                                   AND ffvs.flex_value_set_name =
                                       'XXD_AR_TRANSACTION_SOURCE_VS'
                                   AND ffvs.flex_value_set_id =
                                       ffvl.flex_value_set_id
                                   AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                                   AND NVL (ffvl.start_date_active, SYSDATE) <=
                                       SYSDATE
                                   AND NVL (ffvl.end_date_active, SYSDATE) >=
                                       SYSDATE
                                   AND ffvl.attribute2 =
                                       (SELECT batch_source_id
                                          FROM ra_batch_sources_all
                                         WHERE     name =
                                                   rila.batch_source_name
                                               AND org_id = rila.org_id)
                                   AND NVL (ffvl.attribute1, rila.org_id) =
                                       rila.org_id);

        -- Start of Change for CCR0008507

        CURSOR upd_rila_cur IS
            SELECT *
              FROM ra_interface_lines_all rila
             WHERE     1 = 1
                   AND rila.org_id = p_operating_unit
                   AND rila.tax_code IS NOT NULL
                   AND EXISTS
                           (SELECT hou.organization_id
                              FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvv, hr_operating_units hou
                             WHERE     ffvs.flex_value_set_name =
                                       'XXD_MTD_OU_VS'
                                   AND ffvv.flex_value_set_id =
                                       ffvs.flex_value_set_id
                                   AND ffvv.enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   ffvv.start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   ffvv.end_date_active,
                                                                     TRUNC (
                                                                         SYSDATE)
                                                                   + 1)
                                   AND hou.name = ffvv.flex_value
                                   AND hou.organization_id = rila.org_id);

        -- End of Change for CCR0008507
        -- Added for CCR0009060

        CURSOR gl_date_cur IS
            SELECT ocl.approved_date, rila.interface_line_attribute1, rila.batch_source_name,
                   rila.gl_date, rila.org_id
              FROM apps.ra_interface_lines_all rila, apps.ozf_claims_all ocl
             WHERE     1 = 1
                   AND rila.interface_line_context = 'CLAIM'
                   AND UPPER (rila.batch_source_name) =
                       UPPER ('Trade Management')
                   AND rila.interface_line_attribute1 = ocl.claim_number
                   AND rila.org_id = p_operating_unit
                   AND TRUNC (rila.creation_date) BETWEEN NVL (
                                                              TRUNC (
                                                                  TO_DATE (
                                                                      p_pay_date_from,
                                                                      'YYYY/MM/DD HH24:MI:SS')),
                                                              TRUNC (
                                                                  rila.creation_date))
                                                      AND NVL (
                                                              TRUNC (
                                                                  TO_DATE (
                                                                      p_pay_date_to,
                                                                      'YYYY/MM/DD HH24:MI:SS')),
                                                              TRUNC (
                                                                  rila.creation_date));

        -- Ended for CCR0009060

        ln_cost_centre           NUMBER;
        ln_code_combination_id   NUMBER := 0;
        ln_dist_suc_count        NUMBER := 0;
        ln_dist_fail_count       NUMBER := 0;
        ln_rila_suc_count        NUMBER := 0;
        ln_rila_upd_count        NUMBER := 0;       -- Added as per CCR0008507
        ln_rila_fail_count       NUMBER := 0;
        ln_rila_upd_fail_count   NUMBER := 0;       -- Added as per CCR0008507
        ln_rila_count            NUMBER := 0;
        ln_distribution_count    NUMBER := 0;
        lv_chr_errbuf            VARCHAR2 (4000);
        lv_chr_rev_segment1      gl_code_combinations.segment1%TYPE := NULL;
        lv_chr_rev_segment2      gl_code_combinations.segment2%TYPE := NULL;
        lv_chr_rev_segment3      gl_code_combinations.segment3%TYPE := NULL;
        lv_chr_rev_segment4      gl_code_combinations.segment4%TYPE := NULL;
        lv_chr_rev_segment5      gl_code_combinations.segment5%TYPE := NULL;
        lv_chr_rev_segment6      gl_code_combinations.segment6%TYPE := NULL;
        lv_chr_rev_segment7      gl_code_combinations.segment7%TYPE := NULL;
        lv_chr_rev_segment8      gl_code_combinations.segment8%TYPE := NULL;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'RA Interface Update Program Starts Here.....');
        fnd_file.put_line (fnd_file.LOG,
                           '--------------------------------------------');

        fnd_file.put_line (
            fnd_file.LOG,
               'Org ID is - '
            || p_operating_unit
            || ' - and profile value is - '
            || fnd_profile.VALUE ('XXD_AR_REMOVE_TAX_CODE'));
        fnd_file.put_line (fnd_file.LOG,
                           'Profile value set was - ' || g_set_pcc_value);

        -- Start of Change for CCR0008507

        IF g_set_pcc_value IS NOT NULL AND g_set_pcc_value = 'Y'
        THEN
            FOR rec IN upd_rila_cur
            LOOP
                BEGIN
                    UPDATE ra_interface_lines_all
                       SET tax_code = NULL, last_update_date = SYSDATE, last_updated_by = gn_user_id
                     WHERE     interface_line_attribute1 =
                               rec.interface_line_attribute1
                           AND batch_source_name = rec.batch_source_name;

                    COMMIT;
                    ln_rila_upd_count   := ln_rila_upd_count + 1;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'RILA Table Updated Successfully for interface_line_attribute1:'
                        || rec.interface_line_attribute1);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'RILA Table Update Failed for interface_line_attribute1:'
                            || rec.interface_line_attribute1);
                        ln_rila_upd_fail_count   :=
                            ln_rila_upd_fail_count + 1;
                END;
            END LOOP;
        END IF;

        -- end of Change for CCR0008507


        FOR i IN eligible_trade_line_records
        LOOP
            --UPDATE the override_auto_accounting_flag in RILA
            BEGIN
                UPDATE ra_interface_lines_all
                   SET override_auto_accounting_flag = 'Y', last_update_date = SYSDATE, last_updated_by = gn_user_id
                 WHERE     interface_line_attribute1 =
                           i.interface_line_attribute1
                       AND batch_source_name = i.batch_source_name;

                COMMIT;
                ln_rila_suc_count   := ln_rila_suc_count + 1;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'RILA Table Updated Successfully for interface_line_attribute1:'
                    || i.interface_line_attribute1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'RILA Table Update Failed for interface_line_attribute1:'
                        || i.interface_line_attribute1);
                    ln_rila_fail_count   := ln_rila_fail_count + 1;
            END;

            -- Query to verify the claim was inserted in distributions or not
            BEGIN
                SELECT COUNT (interface_line_attribute1)
                  INTO ln_distribution_count
                  FROM ra_interface_distributions_all
                 WHERE     interface_line_attribute1 =
                           i.interface_line_attribute1
                       AND org_id = i.org_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Distribution count for the claim:'
                    || ln_distribution_count);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_distribution_count   := 0;
            END;

            IF ln_distribution_count > 0
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Record already exist in distributions table for the claim:'
                    || i.interface_line_attribute1);
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Fetching the segment values for interface_line_attribute1:'
                    || i.interface_line_attribute1);
                lv_chr_rev_segment1   :=
                    get_autoacct_seg_value (lv_chr_errbuf, 'REV', --p_acct_type
                                                                  'SEGMENT1', --p_acct_seg
                                            i.interface_line_attribute10, --Organization_id
                                                                          i.primary_salesrep_id, --p_salesrep_id
                                                                                                 i.orig_system_bill_address_id, --p_cust_acct_site_id
                                                                                                                                i.cust_trx_type_id, --p_cust_trx_type_id
                                                                                                                                                    i.inventory_item_id, --p_item_id
                                                                                                                                                                         i.org_id
                                            ,                       --p_org_id
                                              i.memo_line_id  --p_memo_line_id
                                                            );
                lv_chr_rev_segment2   :=
                    get_autoacct_seg_value (lv_chr_errbuf, 'REV', --p_acct_type
                                                                  'SEGMENT2', --p_acct_seg
                                            i.interface_line_attribute10, --Organization_id
                                                                          i.primary_salesrep_id, --p_salesrep_id
                                                                                                 i.orig_system_bill_address_id, --p_cust_acct_site_id
                                                                                                                                i.cust_trx_type_id, --p_cust_trx_type_id
                                                                                                                                                    i.inventory_item_id, --p_item_id
                                                                                                                                                                         i.org_id
                                            ,                       --p_org_id
                                              i.memo_line_id  --p_memo_line_id
                                                            );
                lv_chr_rev_segment3   :=
                    get_autoacct_seg_value (lv_chr_errbuf, 'REV', --p_acct_type
                                                                  'SEGMENT3', --p_acct_seg
                                            i.interface_line_attribute10, --Organization_id
                                                                          i.primary_salesrep_id, --p_salesrep_id
                                                                                                 i.orig_system_bill_address_id, --p_cust_acct_site_id
                                                                                                                                i.cust_trx_type_id, --p_cust_trx_type_id
                                                                                                                                                    i.inventory_item_id, --p_item_id
                                                                                                                                                                         i.org_id
                                            ,                       --p_org_id
                                              i.memo_line_id  --p_memo_line_id
                                                            );
                lv_chr_rev_segment4   :=
                    get_autoacct_seg_value (lv_chr_errbuf, 'REV', --p_acct_type
                                                                  'SEGMENT4', --p_acct_seg
                                            i.interface_line_attribute10, --Organization_id
                                                                          i.primary_salesrep_id, --p_salesrep_id
                                                                                                 i.orig_system_bill_address_id, --p_cust_acct_site_id
                                                                                                                                i.cust_trx_type_id, --p_cust_trx_type_id
                                                                                                                                                    i.inventory_item_id, --p_item_id
                                                                                                                                                                         i.org_id
                                            ,                       --p_org_id
                                              i.memo_line_id  --p_memo_line_id
                                                            );
                lv_chr_rev_segment5   :=
                    get_autoacct_seg_value (lv_chr_errbuf,
                                            'REV',               --p_acct_type
                                            'SEGMENT5',           --p_acct_seg
                                            i.interface_line_attribute10, --Organization_id
                                            i.primary_salesrep_id, --p_salesrep_id
                                            i.orig_system_bill_address_id, --p_cust_acct_site_id
                                            i.cust_trx_type_id, --p_cust_trx_type_id
                                            i.inventory_item_id,   --p_item_id
                                            i.org_id,               --p_org_id
                                            i.memo_line_id,   --p_memo_line_id
                                            'RA_CUST_TRX_TYPES' -- cost centre from trx_type
                                                               );
                lv_chr_rev_segment6   :=
                    get_autoacct_seg_value (lv_chr_errbuf, 'REV', --p_acct_type
                                                                  'SEGMENT6', --p_acct_seg
                                            i.interface_line_attribute10, --Organization_id
                                                                          i.primary_salesrep_id, --p_salesrep_id
                                                                                                 i.orig_system_bill_address_id, --p_cust_acct_site_id
                                                                                                                                i.cust_trx_type_id, --p_cust_trx_type_id
                                                                                                                                                    i.inventory_item_id, --p_item_id
                                                                                                                                                                         i.org_id
                                            ,                       --p_org_id
                                              i.memo_line_id  --p_memo_line_id
                                                            );
                lv_chr_rev_segment7   :=
                    get_autoacct_seg_value (lv_chr_errbuf, 'REV', --p_acct_type
                                                                  'SEGMENT7', --p_acct_seg
                                            i.interface_line_attribute10, --Organization_id
                                                                          i.primary_salesrep_id, --p_salesrep_id
                                                                                                 i.orig_system_bill_address_id, --p_cust_acct_site_id
                                                                                                                                i.cust_trx_type_id, --p_cust_trx_type_id
                                                                                                                                                    i.inventory_item_id, --p_item_id
                                                                                                                                                                         i.org_id
                                            ,                       --p_org_id
                                              i.memo_line_id  --p_memo_line_id
                                                            );
                lv_chr_rev_segment8   :=
                    get_autoacct_seg_value (lv_chr_errbuf, 'REV', --p_acct_type
                                                                  'SEGMENT8', --p_acct_seg
                                            i.interface_line_attribute10, --Organization_id
                                                                          i.primary_salesrep_id, --p_salesrep_id
                                                                                                 i.orig_system_bill_address_id, --p_cust_acct_site_id
                                                                                                                                i.cust_trx_type_id, --p_cust_trx_type_id
                                                                                                                                                    i.inventory_item_id, --p_item_id
                                                                                                                                                                         i.org_id
                                            ,                       --p_org_id
                                              i.memo_line_id  --p_memo_line_id
                                                            );

                -- Query to get code combination id based on segments.
                BEGIN
                    SELECT code_combination_id
                      INTO ln_code_combination_id
                      FROM gl_code_combinations
                     WHERE     segment1 = lv_chr_rev_segment1
                           AND segment2 = lv_chr_rev_segment2
                           AND segment3 = lv_chr_rev_segment3
                           AND segment4 = lv_chr_rev_segment4
                           AND segment5 = lv_chr_rev_segment5
                           AND segment6 = lv_chr_rev_segment6
                           AND segment7 = lv_chr_rev_segment7
                           AND segment8 = lv_chr_rev_segment8;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Code Combination id:' || ln_code_combination_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_code_combination_id   := NULL;
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Failed to fetch Code Combination id:'
                            || ln_code_combination_id);
                END;


                -- Insert the records in distributions table
                BEGIN
                    INSERT INTO ra_interface_distributions (
                                    interface_line_context,
                                    interface_line_attribute1,
                                    interface_line_attribute2,
                                    interface_line_attribute3,
                                    interface_line_attribute4,
                                    interface_line_attribute5,
                                    interface_line_attribute6,
                                    interface_line_attribute7,
                                    interface_line_attribute8,
                                    interface_line_attribute9,
                                    interface_line_attribute10,
                                    interface_line_attribute11,
                                    interface_line_attribute12,
                                    interface_line_attribute13,
                                    interface_line_attribute14,
                                    interface_line_attribute15,
                                    account_class,
                                    amount,
                                    PERCENT,
                                    interface_status,
                                    code_combination_id,
                                    acctd_amount,
                                    org_id)
                         VALUES (i.interface_line_context, i.interface_line_attribute1, i.interface_line_attribute2, i.interface_line_attribute3, i.interface_line_attribute4, i.interface_line_attribute5, i.interface_line_attribute6, i.interface_line_attribute7, i.interface_line_attribute8, i.interface_line_attribute9, i.interface_line_attribute10, i.interface_line_attribute11, i.interface_line_attribute12, i.interface_line_attribute13, i.interface_line_attribute14, i.interface_line_attribute15, 'REV', i.amount, 100, i.interface_status, ln_code_combination_id
                                 , i.acctd_amount, i.org_id);

                    COMMIT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Processed the Record for:' || i.interface_line_attribute1);
                    ln_dist_suc_count   := ln_dist_suc_count + 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error in inserting in ra_int_dist table():'
                            || SQLERRM);
                        ln_dist_fail_count   := ln_dist_fail_count + 1;
                END;
            END IF;                               --IF ln_distribution_count=0
        END LOOP;

        -- Print the counts in log file

        OPEN lines_records_count;

        FETCH lines_records_count INTO ln_rila_count;

        CLOSE lines_records_count;

        IF ln_rila_count = 0
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'No Data Found');
        END IF;

        -- Print the counts in log file
        fnd_file.put_line (
            fnd_file.LOG,
            '*****************Transaction Interface Update Program counts**********************');
        fnd_file.put_line (
            fnd_file.LOG,
            '------------------------------------------------------------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
               'Total Eligible Records in ra_interface_lines_all Table         :'
            || ln_rila_count);
        fnd_file.put_line (
            fnd_file.LOG,
               'Total Success Records in ra_interface_lines_all Table          :'
            || ln_rila_suc_count);
        fnd_file.put_line (
            fnd_file.LOG,
               'Total Failed Records in ra_interface_lines_all Table           :'
            || ln_rila_fail_count);
        fnd_file.put_line (
            fnd_file.LOG,
               'Total Success Records in ra_interface_distributions_all Table  :'
            || ln_dist_suc_count);
        fnd_file.put_line (
            fnd_file.LOG,
               'Total Failed Records in ra_interface_distributions_all Table   :'
            || ln_dist_fail_count);

        -- Added for CCR0009060
        FOR i IN gl_date_cur
        LOOP
            --UPDATE the GL DATE in RILA
            BEGIN
                UPDATE ra_interface_lines_all
                   SET gl_date = i.approved_date, last_update_date = SYSDATE, last_updated_by = gn_user_id
                 WHERE     interface_line_attribute1 =
                           i.interface_line_attribute1
                       AND batch_source_name = i.batch_source_name
                       AND org_id = i.org_id;

                COMMIT;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'GL DATE is Updated Successfully for interface_line_attribute1:'
                    || i.interface_line_attribute1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'GL DATE is Update Failed for interface_line_attribute1:'
                        || i.interface_line_attribute1);
            END;
        END LOOP;
    -- END for CCR0009060
    END trx_iface_update_main_prc;
END;
/
