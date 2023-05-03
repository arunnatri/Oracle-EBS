--
-- XXD_AP_CONCUR_INBOUND_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_CONCUR_INBOUND_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  AP Invoice Concurr Inbound process                               *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  02-AUG-2018                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     02-AUG-2018  Srinath Siricilla     Initial Creation CCR0007443         *
      * 1.1     11-JAN-2019  Srinath Siricilla     CCR0007726                          *
      * 1.2     17-APR-2019  Aravind Kannuri       Changes as per CCR0007945           *
      * 2.0     06-JUL-2019  Srinath Siricilla     Changes as per CCR0007979           *
      * 3.0     28-MAR-2020  Srinath Siricilla     China Payments CCR0008481           *
      * 4.0     12-JUL-2021  Satyanarayana Kotha   Added for CCR0009255                *
      * 4.1     15-OCT-2021  Srinath Siricilla     Changes as per CCR0009592           *
      **********************************************************************************/

    gn_user_id          NUMBER := fnd_global.user_id;
    gn_resp_id          NUMBER := fnd_global.resp_id;
    gn_resp_appl_id     NUMBER := fnd_global.resp_appl_id;
    gn_request_id       NUMBER := fnd_global.conc_request_id;
    gn_sob_id           NUMBER := fnd_profile.VALUE ('GL_SET_OF_BKS_ID');
    gn_org_id           NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_login_id         NUMBER := fnd_global.login_id;
    --  gn_update_date      DATE            := SYSDATE;
    gd_sysdate          DATE := SYSDATE;
    --gn_creation_date    VARCHAR2(10)    := to_char(SYSDATE,'YYYY-MM-DD');
    --gn_update_date      VARCHAR2(10)    := to_char(SYSDATE,'YYYY-MM-DD');
    gn_inv_process      NUMBER;
    gn_inv_reject       NUMBER;
    gn_dist_processed   NUMBER;
    gn_dist_rejected    NUMBER;
    gn_limit            NUMBER := 1000;
    gc_yesflag          VARCHAR2 (1) := 'Y';
    gc_noflag           VARCHAR2 (1) := 'N';
    gc_debug_flag       VARCHAR2 (1) := 'Y';
    gn_gl_date          DATE;
    gn_limit            NUMBER := 1000;
    g_inv_source        VARCHAR2 (10) := 'CONCUR';
    g_interfaced        VARCHAR2 (1) := 'I';
    g_errored           VARCHAR2 (1) := 'E';
    g_validated         VARCHAR2 (1) := 'V';
    g_processed         VARCHAR2 (1) := 'P';
    g_created           VARCHAR2 (1) := 'C';
    g_new               VARCHAR2 (1) := 'N';
    g_other             VARCHAR2 (1) := 'O';
    g_tax_line          VARCHAR2 (1) := 'T';
    g_ignore            VARCHAR2 (1) := 'U';
    g_format_mask       VARCHAR2 (240) := 'MM/DD/YYYY';
    gc_debug_enable     VARCHAR2 (1)
        := NVL (fnd_profile.VALUE ('XXD_AP_CONCUR_ENABLE'), 'N');

    PROCEDURE purge_prc (pn_purge_days IN NUMBER)
    IS
        CURSOR purge_cur_sae IS
            SELECT DISTINCT stg.request_id
              FROM xxdo.xxd_ap_concur_sae_t stg
             WHERE 1 = 1 AND stg.creation_date < (SYSDATE - pn_purge_days);

        CURSOR purge_cur_sae_stg IS
            SELECT DISTINCT stg.request_id
              FROM xxdo.xxd_ap_concur_sae_stg_t stg
             WHERE 1 = 1 AND stg.creation_date < (SYSDATE - pn_purge_days);
    BEGIN
        FOR purge_rec IN purge_cur_sae
        LOOP
            DELETE FROM xxdo.xxd_ap_concur_sae_t
                  WHERE 1 = 1 AND request_id = purge_rec.request_id;

            COMMIT;
        END LOOP;

        FOR purge_stg_rec IN purge_cur_sae_stg
        LOOP
            DELETE FROM xxdo.xxd_ap_concur_sae_stg_t
                  WHERE 1 = 1 AND request_id = purge_stg_rec.request_id;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in Purge Procedure -' || SQLERRM);
    END purge_prc;

    --- Main Procedure to process the records

    PROCEDURE MAIN (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_org_name IN VARCHAR2, p_exp_rep_num IN VARCHAR2, p_reprocess IN VARCHAR2, p_dummy_par IN VARCHAR2, p_inv_type IN VARCHAR2, p_cm_type IN VARCHAR2, p_pay_group IN VARCHAR2
                    , pn_purge_days IN NUMBER)
    IS
        l_ret_code           VARCHAR2 (10);
        l_err_msg            VARCHAR2 (4000);
        ex_load_interface    EXCEPTION;
        ex_create_invoices   EXCEPTION;
        ex_val_staging       EXCEPTION;
        ex_email_out         EXCEPTION;
        ex_check_data        EXCEPTION;
        ex_insert_stg        EXCEPTION;
        ex_sae_data          EXCEPTION;
        ex_display_data      EXCEPTION;
        lc_err_message       VARCHAR2 (100);
    BEGIN
        IF NVL (p_reprocess, 'N') = 'N'
        THEN
            -- Insert the data into the Stgaing tables

            insert_staging (l_ret_code, l_err_msg, p_org_name,
                            p_exp_rep_num, p_reprocess);

            fnd_file.put_line (fnd_file.LOG,
                               ' Inserted data into Staging Table ');

            IF l_ret_code = '2'
            THEN
                RAISE ex_insert_stg;
            END IF;
        END IF;

        -- Purge the Data in the Staging tables

        purge_prc (pn_purge_days);

        -- Validate inserted data into Staging tables

        validate_staging (x_ret_code => l_ret_code, x_ret_msg => l_err_msg, p_org => p_org_name, p_exp => p_exp_rep_num, p_re_flag => p_reprocess, p_inv_type => p_inv_type
                          , p_cm_type => p_cm_type, p_pay_group => p_pay_group);

        IF l_ret_code = '2'
        THEN
            RAISE ex_val_staging;
        END IF;

        fnd_file.put_line (fnd_file.LOG, ' Validated Staging Data ');

        -- Clear interface tables before upload
        clear_int_tables;

        -- Load Data into AP Interface headers and lines

        load_interface (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);

        fnd_file.put_line (fnd_file.LOG, ' Loaded to Interface ');

        IF l_ret_code = '2'
        THEN
            RAISE ex_load_interface;
        END IF;

        -- Create invoices in the system

        create_invoices (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);

        fnd_file.put_line (fnd_file.LOG, ' Created Invoices ');

        IF l_ret_code = '2'
        THEN
            RAISE ex_create_invoices;
        END IF;

        --- check the invoices creation

        check_data (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);

        fnd_file.put_line (fnd_file.LOG, ' Data Verified ');

        IF l_ret_code = '2'
        THEN
            RAISE ex_check_data;
        END IF;

        --- Finally update the staging table with Error and Process record details

        Update_sae_data (x_ret_code => l_ret_code, x_ret_msg => l_err_msg, p_org => p_org_name
                         , p_exp => p_exp_rep_num);

        fnd_file.put_line (fnd_file.LOG, ' Updated SAE table ');

        IF l_ret_code = '2'
        THEN
            RAISE ex_sae_data;
        END IF;

        -- Show the details

        display_data (x_ret_code     => l_ret_code,
                      x_ret_msg      => l_err_msg,
                      p_request_id   => gn_request_id);
    EXCEPTION
        WHEN ex_insert_stg
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Inserting data into Staging:' || l_err_msg);
        WHEN ex_val_staging
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (fnd_file.LOG,
                               'Error Validating Staging Data:' || l_err_msg);
        WHEN ex_load_interface
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Populating AP_INTERFACE tables:' || l_err_msg);
        WHEN ex_create_invoices
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Submitting Program - Payables Import program :'
                || l_err_msg);
        WHEN ex_check_data
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while checking Invoice created:' || l_err_msg);
        WHEN ex_sae_data
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while updating SAE table data:' || l_err_msg);
        WHEN ex_display_data
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while displaying output data:' || l_err_msg);
        WHEN OTHERS
        THEN
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Error in main:' || SQLERRM);
    END MAIN;

    -- Get OU, Geo and CC through custom valueset

    FUNCTION get_ou_data (pv_emp_org_company IN VARCHAR2, pv_geo IN VARCHAR2, pv_cost_center IN VARCHAR2, x_ou_id OUT VARCHAR2, x_pg_pcard OUT VARCHAR2, x_pg_pcard_per OUT VARCHAR2, x_pg_card_comp OUT VARCHAR2, x_pg_card_per OUT VARCHAR2, x_pg_oop OUT VARCHAR2, x_inv_terms OUT VARCHAR2, x_cm_terms OUT VARCHAR2, x_inv_trx_type OUT VARCHAR2, x_CM_trx_type OUT VARCHAR2, x_group_by_type OUT VARCHAR2, x_bal_segment OUT VARCHAR2, x_offset_gl_comb OUT VARCHAR2, x_offset_gl_comb_paid OUT VARCHAR2, x_IC_positive OUT VARCHAR2, x_IC_Negative OUT VARCHAR2, x_emp_receivable OUT VARCHAR2, x_tax_rate_flag OUT VARCHAR2, x_def_nat_acct OUT VARCHAR2, x_ou_geo OUT VARCHAR2, --- Added as per change 2.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        x_ou_cost_center OUT VARCHAR2, --- Added as per change 2.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       -- Start of Change 3.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       x_pcard_match OUT VARCHAR2, x_pcard_per_match OUT VARCHAR2, x_card_comp_match OUT VARCHAR2
                          , x_card_per_match OUT VARCHAR2, x_oop_match OUT VARCHAR2, -- End of Change 3.0
                                                                                     x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT ffv.attribute1, ffv.attribute2, ffv.attribute3,
               ffv.attribute4, ffv.attribute5, ffv.attribute6,
               ffv.attribute7, ffv.attribute8, ffv.attribute9,
               ffv.attribute10, ffv.attribute11, ffv.attribute12,
               ffv.attribute13, ffv.attribute14, ffv.attribute15,
               ffv.attribute16, ffv.attribute17, ffv.attribute18,
               ffv.attribute19, ffv.attribute20, ffv.attribute21,
               -- Start of Change 3.0
               ffv.attribute22, ffv.attribute23, ffv.attribute24,
               ffv.attribute25, ffv.attribute26
          -- End of Change 3.0
          INTO x_ou_id, x_pg_pcard, x_pg_pcard_per, x_pg_card_comp,
                      x_pg_card_per, x_pg_oop, x_inv_terms,
                      x_cm_terms, x_inv_trx_type, x_CM_trx_type,
                      x_group_by_type, x_bal_segment, x_offset_gl_comb,
                      x_offset_gl_comb_paid, x_IC_positive, x_IC_Negative,
                      x_emp_receivable, x_tax_rate_flag, x_def_nat_acct,
                      x_ou_geo, x_ou_cost_center,       -- Start of Change 3.0
                                                  x_pcard_match,
                      x_pcard_per_match, x_card_comp_match, x_card_per_match,
                      x_oop_match
          -- End of Change 3.0
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
         WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffvs.flex_value_set_name = 'XXD_CONCUR_OU'
               AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                               AND NVL (ffv.end_date_active, SYSDATE)
               AND ffv.attribute12 = pv_emp_org_company
               AND ffv.attribute20 = pv_geo
               AND ffv.attribute21 = pv_cost_center;

        RETURN TRUE;
    EXCEPTION
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   'More than one OU found for Company : '
                || pv_emp_org_company
                || ' Geo: '
                || pv_geo
                || ' CC: '
                || pv_cost_center
                || ' combination ';
            RETURN FALSE;
        WHEN NO_DATA_FOUND
        THEN
            BEGIN
                SELECT ffv.attribute1, ffv.attribute2, ffv.attribute3,
                       ffv.attribute4, ffv.attribute5, ffv.attribute6,
                       ffv.attribute7, ffv.attribute8, ffv.attribute9,
                       ffv.attribute10, ffv.attribute11, ffv.attribute12,
                       ffv.attribute13, ffv.attribute14, ffv.attribute15,
                       ffv.attribute16, ffv.attribute17, ffv.attribute18,
                       ffv.attribute19, ffv.attribute20, ffv.attribute21,
                       -- Start of Change 3.0
                       ffv.attribute22, ffv.attribute23, ffv.attribute24,
                       ffv.attribute25, ffv.attribute26
                  -- End of Change 3.0
                  INTO x_ou_id, x_pg_pcard, x_pg_pcard_per, x_pg_card_comp,
                              x_pg_card_per, x_pg_oop, x_inv_terms,
                              x_cm_terms, x_inv_trx_type, x_CM_trx_type,
                              x_group_by_type, x_bal_segment, x_offset_gl_comb,
                              x_offset_gl_comb_paid, x_IC_positive, x_IC_Negative,
                              x_emp_receivable, x_tax_rate_flag, x_def_nat_acct,
                              x_ou_geo, x_ou_cost_center, -- Start of Change 3.0
                                                          x_pcard_match,
                              x_pcard_per_match, x_card_comp_match, x_card_per_match,
                              x_oop_match
                  -- End of change 3.0
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                 WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                       AND ffvs.flex_value_set_name = 'XXD_CONCUR_OU'
                       AND SYSDATE BETWEEN NVL (ffv.start_date_active,
                                                SYSDATE)
                                       AND NVL (ffv.end_date_active, SYSDATE)
                       AND ffv.attribute12 = pv_emp_org_company
                       AND ffv.attribute20 = pv_geo
                       AND ffv.attribute21 IS NULL;

                RETURN TRUE;
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    x_ret_msg   :=
                           'More than one OU found for Company : '
                        || pv_emp_org_company
                        || ' Geo: '
                        || pv_geo
                        || ' combination ';
                    RETURN FALSE;
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        SELECT ffv.attribute1, ffv.attribute2, ffv.attribute3,
                               ffv.attribute4, ffv.attribute5, ffv.attribute6,
                               ffv.attribute7, ffv.attribute8, ffv.attribute9,
                               ffv.attribute10, ffv.attribute11, ffv.attribute12,
                               ffv.attribute13, ffv.attribute14, ffv.attribute15,
                               ffv.attribute16, ffv.attribute17, ffv.attribute18,
                               ffv.attribute19, ffv.attribute20, ffv.attribute21,
                               -- Start of Change 3.0
                               ffv.attribute22, ffv.attribute23, ffv.attribute24,
                               ffv.attribute25, ffv.attribute26
                          -- End of Change 3.0
                          INTO x_ou_id, x_pg_pcard, x_pg_pcard_per, x_pg_card_comp,
                                      x_pg_card_per, x_pg_oop, x_inv_terms,
                                      x_cm_terms, x_inv_trx_type, x_CM_trx_type,
                                      x_group_by_type, x_bal_segment, x_offset_gl_comb,
                                      x_offset_gl_comb_paid, x_IC_positive, x_IC_Negative,
                                      x_emp_receivable, x_tax_rate_flag, x_def_nat_acct,
                                      x_ou_geo, x_ou_cost_center, -- Start of Change 3.0
                                                                  x_pcard_match,
                                      x_pcard_per_match, x_card_comp_match, x_card_per_match,
                                      x_oop_match
                          -- End of change 3.0
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                         WHERE     ffvs.flex_value_set_id =
                                   ffv.flex_value_set_id
                               AND ffvs.flex_value_set_name = 'XXD_CONCUR_OU'
                               AND SYSDATE BETWEEN NVL (
                                                       ffv.start_date_active,
                                                       SYSDATE)
                                               AND NVL (ffv.end_date_active,
                                                        SYSDATE)
                               AND ffv.attribute12 = pv_emp_org_company
                               AND ffv.attribute21 = pv_cost_center
                               AND ffv.attribute20 IS NULL;

                        RETURN TRUE;
                    EXCEPTION
                        WHEN TOO_MANY_ROWS
                        THEN
                            x_ret_msg   :=
                                   'More than one OU found for Company : '
                                || pv_emp_org_company
                                || ' Geo: '
                                || pv_geo
                                || ' combination ';
                            RETURN FALSE;
                        WHEN NO_DATA_FOUND
                        THEN
                            BEGIN
                                SELECT ffv.attribute1, ffv.attribute2, ffv.attribute3,
                                       ffv.attribute4, ffv.attribute5, ffv.attribute6,
                                       ffv.attribute7, ffv.attribute8, ffv.attribute9,
                                       ffv.attribute10, ffv.attribute11, ffv.attribute12,
                                       ffv.attribute13, ffv.attribute14, ffv.attribute15,
                                       ffv.attribute16, ffv.attribute17, ffv.attribute18,
                                       ffv.attribute19, ffv.attribute20, ffv.attribute21,
                                       -- Start of Change 3.0
                                       ffv.attribute22, ffv.attribute23, ffv.attribute24,
                                       ffv.attribute25, ffv.attribute26
                                  -- End of Change 3.0
                                  INTO x_ou_id, x_pg_pcard, x_pg_pcard_per, x_pg_card_comp,
                                              x_pg_card_per, x_pg_oop, x_inv_terms,
                                              x_cm_terms, x_inv_trx_type, x_CM_trx_type,
                                              x_group_by_type, x_bal_segment, x_offset_gl_comb,
                                              x_offset_gl_comb_paid, x_IC_positive, x_IC_Negative,
                                              x_emp_receivable, x_tax_rate_flag, x_def_nat_acct,
                                              x_ou_geo, x_ou_cost_center, -- Start of Change 3.0
                                                                          x_pcard_match,
                                              x_pcard_per_match, x_card_comp_match, x_card_per_match,
                                              x_oop_match
                                  -- End of change 3.0
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                                 WHERE     ffvs.flex_value_set_id =
                                           ffv.flex_value_set_id
                                       AND ffvs.flex_value_set_name =
                                           'XXD_CONCUR_OU'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffv.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               ffv.end_date_active,
                                                               SYSDATE)
                                       AND ffv.attribute12 =
                                           pv_emp_org_company
                                       AND ffv.attribute21 IS NULL
                                       AND ffv.attribute20 IS NULL;

                                RETURN TRUE;
                            EXCEPTION
                                WHEN TOO_MANY_ROWS
                                THEN
                                    x_ret_msg   :=
                                           'More than one OU found for Company : '
                                        || pv_emp_org_company
                                        || ' With Geo and Cost Center as NULL ';
                                    RETURN FALSE;
                                WHEN NO_DATA_FOUND
                                THEN
                                    x_ret_msg   :=
                                           'No Data found for Company : '
                                        || pv_emp_org_company
                                        || ' With Geo and Cost Center as NULL ';
                                    RETURN FALSE;
                            END;
                    END;
            END;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   'Exception occurred for Company : '
                || pv_emp_org_company
                || ' Geo: '
                || pv_geo
                || ' CC: '
                || pv_cost_center
                || ' combination and error is: '
                || SUBSTR (SQLERRM, 1, 200);
    END get_ou_data;


    /*FUNCTION get_ou_data ( pv_emp_org_company     IN   VARCHAR2,
                           pv_geo                 IN   VARCHAR2,
                           pv_cost_center         IN   VARCHAR2,
                           x_ou_id                OUT  VARCHAR2,
                           x_ou_geo               OUT  VARCHAR2,           --- Added as per change 2.0
                           x_ou_cost_center       OUT  VARCHAR2,         --- Added as per change 2.0
                           x_ret_msg                 OUT  VARCHAR2)
     RETURN BOOLEAN
     IS

     BEGIN
       SELECT
              ffv.attribute1,
              ffv.attribute20,
              ffv.attribute21
         INTO
               x_ou_id
              ,x_ou_geo
              ,x_ou_cost_center
        FROM
              apps.fnd_flex_value_sets ffvs,
              apps.fnd_flex_values ffv
       WHERE  ffvs.flex_value_set_id      = ffv.flex_value_set_id
         AND  ffvs.flex_value_set_name    = 'XXD_CONCUR_OU'
         AND  SYSDATE BETWEEN NVL(ffv.start_date_active,SYSDATE) AND NVL(ffv.end_date_active,SYSDATE)
         AND  ffv.attribute12             = pv_emp_org_company
         AND  ffv.attribute20             = pv_geo
         AND  ffv.attribute21             = pv_cost_center;

         RETURN TRUE;
     EXCEPTION
     WHEN TOO_MANY_ROWS
     THEN
          x_ret_msg := 'More than one OU found for Company : '||pv_emp_org_company||' Geo: '||pv_geo||' CC: '||pv_cost_center||' combination ';
          RETURN FALSE;
      WHEN NO_DATA_FOUND
      THEN
          BEGIN
              SELECT
                      ffv.attribute1,
                      ffv.attribute20,
                      ffv.attribute21
                INTO
                       x_ou_id
                      ,x_ou_geo
                      ,x_ou_cost_center
                FROM
                      apps.fnd_flex_value_sets ffvs,
                      apps.fnd_flex_values ffv
               WHERE  ffvs.flex_value_set_id      = ffv.flex_value_set_id
                 AND  ffvs.flex_value_set_name    = 'XXD_CONCUR_OU'
                 AND  SYSDATE BETWEEN NVL(ffv.start_date_active,SYSDATE) AND NVL(ffv.end_date_active,SYSDATE)
                 AND  ffv.attribute12             = pv_emp_org_company
                 AND  ffv.attribute20             = pv_geo
                 AND  ffv.attribute21             IS NULL;

                 RETURN TRUE;
              EXCEPTION
              WHEN TOO_MANY_ROWS
              THEN
                  x_ret_msg := 'More than one OU found for Company : '||pv_emp_org_company||' Geo: '||pv_geo||' combination ';
                  RETURN FALSE;
              WHEN NO_DATA_FOUND
              THEN
                  BEGIN
                      SELECT
                                ffv.attribute1,
                              ffv.attribute20,
                              ffv.attribute21
                        INTO
                               x_ou_id
                              ,x_ou_geo
                              ,x_ou_cost_center
                        FROM
                              apps.fnd_flex_value_sets ffvs,
                              apps.fnd_flex_values ffv
                       WHERE  ffvs.flex_value_set_id      = ffv.flex_value_set_id
                         AND  ffvs.flex_value_set_name    = 'XXD_CONCUR_OU'
                         AND  SYSDATE BETWEEN NVL(ffv.start_date_active,SYSDATE) AND NVL(ffv.end_date_active,SYSDATE)
                         AND  ffv.attribute12             = pv_emp_org_company
                         AND  ffv.attribute21             = pv_cost_center
                         AND  ffv.attribute20             IS NULL;
                      RETURN TRUE;
                  EXCEPTION
                  WHEN TOO_MANY_ROWS
                  THEN
                      x_ret_msg := 'More than one OU found for Company : '||pv_emp_org_company||' Geo: '||pv_geo||' combination ';
                      RETURN FALSE;
                  WHEN NO_DATA_FOUND
                  THEN
                      BEGIN
                          SELECT
                                  ffv.attribute1,
                                  ffv.attribute20,
                                  ffv.attribute21
                            INTO
                                   x_ou_id
                                  ,x_ou_geo
                                  ,x_ou_cost_center
                            FROM
                                  apps.fnd_flex_value_sets ffvs,
                                  apps.fnd_flex_values ffv
                           WHERE  ffvs.flex_value_set_id      = ffv.flex_value_set_id
                             AND  ffvs.flex_value_set_name    = 'XXD_CONCUR_OU'
                             AND  SYSDATE BETWEEN NVL(ffv.start_date_active,SYSDATE) AND NVL(ffv.end_date_active,SYSDATE)
                             AND  ffv.attribute12             = pv_emp_org_company
                             AND  ffv.attribute21             IS NULL
                             AND  ffv.attribute20             IS NULL;
                          RETURN TRUE;
                      EXCEPTION
                      WHEN TOO_MANY_ROWS
                      THEN
                          x_ret_msg := 'More than one OU found for Company : '||pv_emp_org_company||' With Geo and Cost Center as NULL ';
                          RETURN FALSE;
                      WHEN NO_DATA_FOUND
                      THEN
                          x_ret_msg := 'No Data found for Company : '||pv_emp_org_company||' With Geo and Cost Center as NULL ';
                          RETURN FALSE;
                      END;
                  END;
          END;
      WHEN OTHERS
      THEN
          x_ret_msg := 'Exception occurred for Company : '||pv_emp_org_company||' Geo: '||pv_geo||' CC: '||pv_cost_center||' combination and error is: '|| SUBSTR(SQLERRM,1,200);
       END get_ou_data;*/

    -- Validate company segment value

    FUNCTION is_bal_seg_valid (p_company IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid_value   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_valid_value
          FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
         WHERE     ffv.flex_value_set_id = ffvs.flex_value_set_id
               AND ffvs.flex_value_set_name = 'DO_GL_COMPANY'
               AND NVL (ffv.enabled_flag, 'Y') = 'Y'
               AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                               AND NVL (ffv.end_date_active, SYSDATE)
               AND DECODE (
                       SUBSTR (TO_CHAR (ffv.compiled_value_attributes), 1, 1),
                       'N', 'No',
                       'Yes') =
                   'Yes'
               AND DECODE (
                       SUBSTR (TO_CHAR (ffv.compiled_value_attributes), 3, 1),
                       'N', 'No',
                       'Yes') =
                   'Yes'
               AND TRIM (ffv.flex_value) = TRIM (p_company);

        IF l_valid_value > 0
        THEN
            RETURN TRUE;
        ELSE
            x_ret_msg   := ' Company Org is Invalid = ' || p_company;
            RETURN FALSE;
        END IF;
    END is_bal_seg_valid;

    -- Validate gl account segment values

    FUNCTION is_seg_valid (p_seg IN VARCHAR2, p_flex_type IN VARCHAR2, p_seg_type IN VARCHAR2
                           , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid_value   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_valid_value
          FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
         WHERE     ffv.flex_value_set_id = ffvs.flex_value_set_id
               AND ffvs.flex_value_set_name = p_flex_type
               AND NVL (ffv.enabled_flag, 'Y') = 'Y'
               AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                               AND NVL (ffv.end_date_active, SYSDATE)
               AND DECODE (
                       SUBSTR (TO_CHAR (ffv.compiled_value_attributes), 1, 1),
                       'N', 'No',
                       'Yes') =
                   'Yes'
               AND DECODE (
                       SUBSTR (TO_CHAR (ffv.compiled_value_attributes), 3, 1),
                       'N', 'No',
                       'Yes') =
                   'Yes'
               AND ffv.flex_value = p_seg;

        IF l_valid_value > 0
        THEN
            RETURN TRUE;
        ELSE
            x_ret_msg   :=
                   p_seg
                || ' is Invalid: Please check the Segment Qualifiers as well for : '
                || p_seg_type;
            RETURN FALSE;
        END IF;
    END is_seg_valid;

    -- Validate code combination segments and derive CCID

    FUNCTION is_code_comb_valid (p_seg1 IN VARCHAR2, p_seg2 IN VARCHAR2, p_seg3 IN VARCHAR2, p_seg4 IN VARCHAR2, p_seg5 IN VARCHAR2, p_seg6 IN VARCHAR2, p_seg7 IN VARCHAR2, p_seg8 IN VARCHAR2, x_ccid OUT NUMBER
                                 , x_cc OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT code_combination_id, concatenated_segments
          INTO x_ccid, x_cc
          FROM gl_code_combinations_kfv
         WHERE     1 = 1
               AND NVL (enabled_flag, 'N') = 'Y'
               AND segment1 = p_seg1
               AND segment2 = p_seg2
               AND segment3 = p_seg3
               AND segment4 = p_seg4
               AND segment5 = p_seg5
               AND segment6 = p_seg6
               AND segment7 = p_seg7
               AND segment8 = p_seg8;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Please check the Code Combination provided :'
                || p_seg1
                || '.'
                || p_seg2
                || '.'
                || p_seg3
                || '.'
                || p_seg4
                || '.'
                || p_seg5
                || '.'
                || p_seg6
                || '.'
                || p_seg7
                || '.'
                || p_seg8;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Code Combinations exist with same the same set';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Code Combination: ' || SQLERRM;
            RETURN FALSE;
    END is_code_comb_valid;

    -- Derive GL Coount combination using CCID

    FUNCTION is_gl_code_valid (p_ccid      IN     VARCHAR2,
                               x_cc           OUT VARCHAR2,
                               x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT concatenated_segments
          INTO x_cc
          FROM gl_code_combinations_kfv
         WHERE     1 = 1
               AND NVL (enabled_flag, 'N') = 'Y'
               AND code_combination_id = p_ccid;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Please check the GL Code Combination ID provided = '
                || p_ccid;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Code Combinations exist with same ID in the same set = '
                || p_ccid;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Code Combination: ' || SQLERRM;
            RETURN FALSE;
    END is_gl_code_valid;

    -- Validate OU

    FUNCTION is_org_valid (p_org_id IN NUMBER, p_org_name IN VARCHAR2 --Added as per version 1.2
                                                                     , x_org_id OUT VARCHAR2
                           , x_org_name OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_org_id   NUMBER;
    BEGIN
        SELECT name, organization_id
          INTO x_org_name, x_org_id
          FROM apps.hr_operating_units
         WHERE     1 = 1
               AND UPPER (organization_id) = TRIM (p_org_id)
               AND date_from <= SYSDATE
               AND NVL (date_to, SYSDATE) >= SYSDATE;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Invalid Operating Unit Name for OU: '
                || p_org_name
                || ' and Org_Id: '
                || p_org_id;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Operating Units exist for OU: '
                || p_org_name
                || ' and Org_Id: '
                || p_org_id;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Operating Unit: ' || SQLERRM;
            RETURN FALSE;
    END is_org_valid;

    -- Validate Vendor

    FUNCTION is_vendor_valid (p_vendor_number   IN     VARCHAR2,
                              x_vendor_id          OUT NUMBER,
                              x_vendor_num         OUT VARCHAR2,
                              x_vendor_name        OUT VARCHAR2,
                              x_ret_msg            OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT ap.vendor_id, ap.vendor_name, ap.segment1
          INTO x_vendor_id, x_vendor_name, x_vendor_num
          FROM apps.ap_suppliers ap, per_all_people_f papf
         WHERE     1 = 1
               AND SYSDATE BETWEEN NVL (ap.start_date_active, SYSDATE)
                               AND NVL (ap.end_date_active, SYSDATE)
               AND NVL (ap.enabled_flag, 'Y') = 'Y'
               AND SYSDATE BETWEEN NVL (papf.effective_start_date, SYSDATE)
                               AND NVL (papf.effective_end_date, SYSDATE)
               AND papf.person_id = employee_id
               AND papf.employee_number = p_vendor_number;

        --AND NVL(attribute2,'N') = 'N'; -- GTN Supplier
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Invalid Vendor. Supplier should be valid : '
                || p_vendor_number;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Vendors exist with same name for emp num = '
                || p_vendor_number;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Vendor: ' || SQLERRM;
            RETURN FALSE;
    END is_vendor_valid;

    -- Get Vendor Site and get OFFICE as site if multiple sites exists

    FUNCTION is_site_valid (p_org_id IN NUMBER, p_org_name IN VARCHAR2, p_vendor_id IN NUMBER, p_vendor_number IN VARCHAR2 --Added as per version 1.2
                                                                                                                          , x_site_id OUT NUMBER, x_site OUT VARCHAR2
                            , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT vendor_site_id, vendor_site_code
          INTO x_site_id, x_site
          FROM apps.ap_supplier_sites_all
         WHERE 1 = 1  --AND UPPER(vendor_site_code) = UPPER(TRIM(p_site_code))
                     AND org_id = p_org_id AND vendor_id = p_vendor_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Invalid Vendor Site code for Vendor Num = '
                || p_vendor_number
                || ' with Org name = '
                || p_org_name;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            BEGIN
                SELECT vendor_site_id, vendor_site_code
                  INTO x_site_id, x_site
                  FROM apps.ap_supplier_sites_all
                 WHERE     1 = 1
                       --AND UPPER(vendor_site_code) = UPPER(TRIM(p_site_code))
                       AND org_id = p_org_id
                       AND vendor_id = p_vendor_id
                       AND UPPER (TRIM (vendor_site_code)) = 'OFFICE';

                RETURN TRUE;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_msg   :=
                           ' Mutiple Vendor Sites found, but not Office site for Vendor Num = '
                        || p_vendor_number
                        || ' with Org ID = '
                        || p_org_name;
                    RETURN FALSE;
            END;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Vendor Site: ' || SQLERRM;
            RETURN FALSE;
    END is_site_valid;

    -- Validate Currency Code

    FUNCTION is_curr_code_valid (p_curr_code   IN     VARCHAR2,
                                 x_ret_msg        OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_curr   NUMBER := 0;
    BEGIN
        SELECT 1
          INTO l_curr
          FROM apps.fnd_currencies
         WHERE     enabled_flag = 'Y'
               AND currency_code = UPPER (TRIM (p_curr_code));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Currency Code = ' || p_curr_code;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Currencies exist with same code = ' || p_curr_code;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Currency Code: ' || SQLERRM;
            RETURN FALSE;
    END is_curr_code_valid;

    -- Validate Flag (Yes/No)

    FUNCTION is_flag_valid (p_flag      IN     VARCHAR2,
                            x_flag         OUT VARCHAR2,
                            x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_flag
          FROM apps.fnd_lookups
         WHERE     lookup_type = 'YES_NO'
               AND enabled_flag = 'Y'
               AND UPPER (lookup_code) = UPPER (TRIM (p_flag));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid - Value can be either Yes or No only;';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Lookup values exist with same code;';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Lookup Code: ' || SQLERRM;
            RETURN FALSE;
    END is_flag_valid;

    -- Derive Currency Code assigned at Supplier Site

    FUNCTION get_curr_code (p_vendor_id        IN     NUMBER,
                            p_vendor_site_id   IN     NUMBER,
                            p_org_id           IN     NUMBER,
                            x_curr_code           OUT VARCHAR2,
                            x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT invoice_currency_code
          INTO x_curr_code
          FROM apps.ap_supplier_sites_all
         WHERE     vendor_site_id = p_vendor_site_id
               AND vendor_id = p_vendor_id
               AND org_id = p_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Please check the Currency Code at Supplier Site for Site ID = '
                || p_vendor_site_id
                || ' for Org ID = '
                || p_org_id;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Currencies exist at the Supplier Site for Site ID = '
                || p_vendor_site_id
                || ' for Org ID = '
                || p_org_id;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Currency Code: ' || SQLERRM;
            RETURN FALSE;
    END get_curr_code;

    -- Check if Invoice exists

    FUNCTION is_inv_num_valid (p_inv_num IN VARCHAR2, p_vendor_id IN NUMBER, p_vendor_site_id IN NUMBER
                               , p_org_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM apps.ap_invoices_all
         WHERE     1 = 1
               AND org_id = p_org_id
               AND vendor_id = p_vendor_id
               AND vendor_site_id = p_vendor_site_id
               AND UPPER (invoice_num) = TRIM (UPPER (p_inv_num));

        IF l_count > 0
        THEN
            x_ret_msg   :=
                ' Invoice number:' || p_inv_num || ' already exists.';
            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Unable to validate Invoice number:'
                || p_inv_num
                || ' - '
                || SQLERRM;
            RETURN FALSE;
    END is_inv_num_valid;

    -- Derive Pay group using Custom valuesets

    FUNCTION get_payment_code (p_pay_group IN VARCHAR2, p_pay_ou IN VARCHAR2, x_pay_code OUT VARCHAR2
                               , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT flv.lookup_code
          INTO x_pay_code
          FROM fnd_flex_value_sets ffvs1, fnd_flex_value_sets ffvs2, fnd_flex_values_vl ffv1,
               fnd_flex_values_vl ffv2, apps.fnd_lookup_values flv
         WHERE     1 = 1
               AND ffvs1.flex_value_set_name = 'XXD_AP_CONCUR_PAY_OU_VS'
               AND ffvs2.flex_value_set_name = 'XXD_AP_CONCUR_PG_OU_VALUES'
               AND ffvs1.flex_value_set_id = ffv1.flex_value_set_id
               AND ffvs2.flex_value_set_id = ffv2.flex_value_set_id
               AND ffv1.flex_value = ffv2.parent_flex_value_low
               AND ffv2.value_category = 'XXD_AP_CONCUR_PG_OU_VALUES'
               AND flv.LOOKUP_TYPE = 'PAYMENT METHOD'
               AND flv.language = USERENV ('LANG')
               AND ffv1.enabled_flag = 'Y'
               AND ffv2.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffv1.start_date_active, SYSDATE)
                               AND NVL (ffv1.end_date_active, SYSDATE)
               AND SYSDATE BETWEEN NVL (ffv2.start_date_active, SYSDATE)
                               AND NVL (ffv2.end_date_active, SYSDATE)
               AND UPPER (ffv1.flex_value) = UPPER (p_pay_ou)
               AND UPPER (ffv2.flex_value) = UPPER (p_pay_group)
               AND UPPER (ffv2.attribute1) = UPPER (flv.LOOKUP_code);

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Invalid Pay Method Code :'
                || p_pay_group
                || CHR (9)
                || 'OU = '
                || p_pay_ou;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Pay Method Codes exist with same name: '
                || p_pay_group
                || CHR (9)
                || 'OU = '
                || p_pay_ou;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Invalid Pay Method Code: '
                || p_pay_group
                || CHR (9)
                || 'OU = '
                || p_pay_ou
                || '  '
                || SQLERRM;
            RETURN FALSE;
    END get_payment_code;

    -- Validate Payment Method

    FUNCTION is_pay_method_valid (p_pay_method IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_code
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'PAYMENT METHOD'
               AND language = USERENV ('LANG')
               AND enabled_flag = 'Y'
               AND UPPER (lookup_code) = UPPER (TRIM (p_pay_method));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Invalid Payment method lookup code = ' || p_pay_method;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple payment method lookups exist with same name = '
                || p_pay_method;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Payment Method: ' || SQLERRM;
            RETURN FALSE;
    END is_pay_method_valid;

    -- Split the CCID into Individual Segments

    FUNCTION get_cc_segments (p_ic_acct IN NUMBER, x_seg1 OUT VARCHAR2, x_seg2 OUT VARCHAR2, x_seg3 OUT VARCHAR2, x_seg4 OUT VARCHAR2, x_seg5 OUT VARCHAR2, x_seg6 OUT VARCHAR2, x_seg7 OUT VARCHAR2, x_seg8 OUT VARCHAR2
                              , x_cc OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT segment1, segment2, segment3,
               segment4, segment5, segment6,
               segment7, segment8, concatenated_segments
          INTO x_seg1, x_seg2, x_seg3, x_seg4,
                     x_seg5, x_seg6, x_seg7,
                     x_seg8, x_cc
          FROM gl_code_combinations_kfv
         WHERE     code_combination_id = p_ic_acct
               AND NVL (enabled_flag, 'N') = 'Y';

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Please check the Code Combination ID provided = '
                || p_ic_acct;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Code Combinations ID exist with same the same set = '
                || p_ic_acct;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Code Combination: ' || SQLERRM;
            RETURN FALSE;
    END get_cc_segments;

    -- Derive  payment method assigned at Supplier Site/ Supplier

    FUNCTION get_pay_method (p_vendor_id        IN     NUMBER,
                             p_vendor_site_id   IN     NUMBER,
                             p_org_id           IN     NUMBER,
                             x_pay_method          OUT VARCHAR2,
                             x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT ieppm.payment_method_code
          INTO x_pay_method
          FROM apps.ap_supplier_sites_all assa, apps.ap_suppliers sup, apps.iby_external_payees_all iepa,
               apps.iby_ext_party_pmt_mthds ieppm
         WHERE     sup.vendor_id = assa.vendor_id
               AND assa.vendor_site_id = iepa.supplier_site_id
               AND iepa.ext_payee_id = ieppm.ext_pmt_party_id
               AND NVL (ieppm.inactive_date, SYSDATE + 1) > SYSDATE
               AND ieppm.primary_flag = 'Y'
               AND assa.pay_site_flag = 'Y'
               AND assa.vendor_site_id = p_vendor_site_id
               AND assa.org_id = p_org_id
               AND sup.vendor_id = p_vendor_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            BEGIN
                SELECT ibeppm.payment_method_code
                  INTO x_pay_method
                  FROM ap_suppliers sup, iby_external_payees_all ibep, iby_ext_party_pmt_mthds ibeppm
                 WHERE     sup.party_id = IBEP.payee_party_id
                       AND ibeppm.ext_pmt_party_id = ibep.ext_payee_id
                       AND ibep.supplier_site_id IS NULL
                       AND ibeppm.primary_flag = 'Y'
                       AND NVL (ibeppm.inactive_date, SYSDATE + 1) > SYSDATE
                       AND sup.vendor_id = p_vendor_id;

                RETURN TRUE;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_ret_msg   :=
                           ' Please check the Payment method code at Supplier ID = '
                        || p_vendor_id;
                    RETURN FALSE;
                WHEN OTHERS
                THEN
                    x_ret_msg   :=
                           ' '
                        || 'Invalid Payment Method at Supplier: '
                        || SQLERRM;
                    RETURN FALSE;
            END;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple payment method codes exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Payment Method: ' || SQLERRM;
            RETURN FALSE;
    END get_pay_method;

    -- Derive the Asset book assigned to a company

    FUNCTION get_asset_book (p_comp_seg1 IN VARCHAR2, x_asset_book OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        lv_asset_book   VARCHAR2 (100);
    BEGIN
        SELECT book_type_code
          INTO lv_asset_book
          FROM fa_book_controls fbc, gl_code_combinations gcc
         WHERE     1 = 1
               AND fbc.flexbuilder_defaults_ccid = gcc.code_combination_id
               AND gcc.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (gcc.START_DATE_ACTIVE, SYSDATE)
                               AND NVL (gcc.END_DATE_ACTIVE, SYSDATE)
               AND gcc.segment1 = p_comp_seg1;

        x_asset_book   := lv_asset_book;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' No Asset Book is assigned for Company = ' || p_comp_seg1;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Asset book names exist for the Company: '
                || p_comp_seg1;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Book Type: ' || SQLERRM;
            RETURN FALSE;
    END get_asset_book;

    -- Validate Asset book for the ledger

    FUNCTION is_asset_book_valid (p_asset_book IN VARCHAR2, p_org_id IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid   VARCHAR2 (100);
    BEGIN
        SELECT DISTINCT fbc.book_type_code
          INTO l_valid
          FROM XLE_LE_OU_LEDGER_V xle, FA_BOOK_CONTROLS_SEC fbc
         WHERE     1 = 1
               AND fbc.set_of_books_id = xle.ledger_id
               AND UPPER (TRIM (fbc.book_type_code)) =
                   UPPER (TRIM (p_asset_book))
               AND xle.operating_unit_id = p_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   'Invalid Asset book = '
                || p_asset_book
                || ' for the OU ID = '
                || p_org_id;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Asset Books exist with same name for OU = '
                || p_org_id;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Book Type for OU: ' || SQLERRM;
            RETURN FALSE;
    END is_asset_book_valid;

    -- Derive the asset category

    FUNCTION get_asset_category (p_asset_cat IN VARCHAR2, x_asset_cat_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_asset_cat_id   VARCHAR2 (100);
    BEGIN
        SELECT category_id
          INTO l_asset_cat_id
          FROM fa_categories
         WHERE    UPPER (TRIM (segment1))
               || '.'
               || UPPER (TRIM (segment2))
               || '.'
               || UPPER (TRIM (segment3)) =
               UPPER (TRIM (p_asset_cat));

        x_asset_cat_id   := l_asset_cat_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Asset Category = ' || p_asset_cat;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Asset categories exist with same name = '
                || p_asset_cat;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Asset Category: ' || SQLERRM;
            RETURN FALSE;
    END get_asset_category;

    -- Validate the asset category

    FUNCTION is_asset_cat_valid (p_asset_cat_id IN VARCHAR2, p_asset_book IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid   VARCHAR2 (100);
    BEGIN
        SELECT book_type_code
          INTO l_valid
          FROM apps.fa_category_books
         WHERE     UPPER (TRIM (book_type_code)) =
                   UPPER (TRIM (p_asset_book))
               AND category_id = p_asset_cat_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Category does not belong to Asset Book = ' || p_asset_book;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Asset and Category Exception. ';
            RETURN FALSE;
    END;

    -- Get Asset clearing account

    FUNCTION get_asset_cc (p_cat_id IN NUMBER, p_asset_book IN VARCHAR2, x_ccid OUT NUMBER
                           , x_cc OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT fcb.asset_clearing_account_ccid, gcc.concatenated_segments
          INTO x_ccid, x_cc
          FROM apps.fa_category_books fcb, apps.gl_code_combinations_kfv gcc
         WHERE     fcb.book_type_code = p_asset_book
               AND fcb.category_id = p_cat_id
               AND gcc.code_combination_id = fcb.asset_clearing_account_ccid
               AND gcc.enabled_flag = 'Y';

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' There is No Asset Clearing account assigned for Book '
                || p_asset_book
                || 'and Category ID'
                || p_cat_id;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                ' ' || 'Invalid Asset clearing Category Exception. ';
            RETURN FALSE;
    END get_asset_cc;

    -- Derive Asset location id

    FUNCTION get_asset_location (p_asset_loc IN VARCHAR2, x_asset_loc_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT location_id
          INTO x_asset_loc_id
          FROM fa_locations_kfv
         WHERE     1 = 1
               AND NVL (enabled_flag, 'N') = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE)
               AND concatenated_segments = p_asset_loc;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Asset location does not exists for the given combination : '
                || p_asset_loc;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Too many rows found for the given Asset combination : '
                || p_asset_loc;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Asset Loc combination : ' || SQLERRM;
            RETURN FALSE;
    END get_asset_location;

    -- Derive person id (Asset Custodian)

    FUNCTION get_asset_custodian (p_custodian IN VARCHAR2, x_cust_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT papf.person_id
          INTO x_cust_id
          FROM per_all_people_f papf, per_all_assignments_f paaf
         WHERE     papf.person_id = paaf.person_id
               AND papf.attribute_category = 'Fixed Asset Related'
               AND papf.attribute2 = 'Y'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (paaf.effective_start_date)
                                       AND TRUNC (paaf.effective_end_date)
               AND papf.full_name = p_custodian;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Custodian does not exists for the given value : '
                || p_custodian;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Too many rows found for the given Custodian : '
                || p_custodian;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Asset Custodian : ' || SQLERRM;
            RETURN FALSE;
    END;

    -- Derive Project ID

    FUNCTION get_project_id (p_proj_number IN VARCHAR2, p_org_id IN NUMBER, p_org_name IN VARCHAR2 --Added as per version 1.2
                             , x_proj_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT project_id
          INTO x_proj_id
          FROM pa_projects_all
         WHERE     org_id = p_org_id
               AND segment1 = p_proj_number
               AND NVL (enabled_flag, 'Y') = 'Y'
               AND project_status_code <> 'CLOSED'
               AND SYSDATE BETWEEN NVL (start_date, SYSDATE)
                               AND NVL (completion_date, SYSDATE);

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' There is no Project for : '
                || p_proj_number
                || ' in Operating Unit : '
                || p_org_name;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' There are multiple Projects for : '
                || p_proj_number
                || ' in Operating Unit : '
                || p_org_name;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Project : ' || SQLERRM;
            RETURN FALSE;
    END get_project_id;

    -- Derive project task ID

    FUNCTION get_project_task_id (p_task_number IN VARCHAR2, p_proj_id IN NUMBER, x_proj_task_id OUT NUMBER
                                  , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT task_id
          INTO x_proj_task_id
          FROM pa_tasks
         WHERE     task_number = p_task_number
               AND project_id = p_proj_id
               AND SYSDATE BETWEEN NVL (start_date, SYSDATE)
                               AND NVL (completion_date, SYSDATE);

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' There is no project assocaited with task : '
                || p_task_number;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' There are multiple Projects associated with task : '
                || p_task_number;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Project task association : ' || SQLERRM;
            RETURN FALSE;
    END get_project_task_id;

    -- Validate Expenditure Type

    FUNCTION is_expend_type_valid (p_expend_type IN VARCHAR2, p_inv_type_code IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_count   NUMBER;
    BEGIN
        SELECT COUNT (pt.expenditure_type)
          INTO l_count
          FROM pa_expenditure_types pt, PA_EXPEND_TYP_SYS_LINKS ES
         WHERE     pt.expenditure_type = p_expend_type
               AND es.expenditure_type = pt.expenditure_type
               AND es.system_linkage_function =
                   DECODE (p_inv_type_code, 'EXPENSE REPORT', 'ER', 'VI')
               AND SYSDATE BETWEEN NVL (pt.start_date_active, SYSDATE)
                               AND NVL (pt.end_date_active, SYSDATE);

        --RETURN  TRUE;

        IF l_count = 1
        THEN
            RETURN TRUE;
        ELSIF l_count > 1
        THEN
            x_ret_msg   :=
                ' There are multiple expenditure types : ' || p_expend_type;
            RETURN FALSE;
        ELSE
            x_ret_msg   :=
                   ' Invalid expenditure type : '
                || p_expend_type
                || ' for Invoice Type code '
                || p_inv_type_code;
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Expenditure Type provided is not valid : ' || p_expend_type;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' There are multiple expenditure types : ' || p_expend_type;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid expenditure type : ' || SQLERRM;
            RETURN FALSE;
    END is_expend_type_valid;

    -- Derive Expenditure org ID

    FUNCTION get_exp_org_id (p_exp_org IN VARCHAR2, p_org_id IN NUMBER, x_exp_org_id OUT NUMBER
                             , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT hou.organization_id
          INTO x_exp_org_id
          FROM hr_organization_information hoi, hr_organization_units hou, pa_all_organizations paorg
         WHERE     1 = 1
               AND hoi.organization_id = hou.organization_id
               AND hoi.org_information1 = 'PA_EXPENDITURE_ORG'
               AND SYSDATE BETWEEN NVL (hou.date_from, SYSDATE)
                               AND NVL (hou.date_to, SYSDATE)
               AND paorg.organization_id = hou.organization_id
               AND paorg.pa_org_use_type = 'EXPENDITURES'
               AND paorg.inactive_date IS NULL
               AND paorg.org_id = p_org_id
               AND NVL (hou.attribute6, hou.name) = p_exp_org;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' There is no Expenditure Org for : ' || p_exp_org;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' There are multiple Expenditure orgs for : ' || p_exp_org;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Expenditure Org : ' || SQLERRM;
            RETURN FALSE;
    END get_exp_org_id;


    -- Validate Expenditure Date

    FUNCTION is_exp_item_date_valid (p_exp_date IN VARCHAR2, p_prj_task_id IN NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM pa_tasks
         WHERE     task_id = p_prj_task_id
               AND p_exp_date BETWEEN NVL (start_date, SYSDATE)
                                  AND NVL (completion_date, SYSDATE);

        IF l_count = 1
        THEN
            RETURN TRUE;
        ELSIF l_count > 1
        THEN
            x_ret_msg   :=
                ' Invalid expenditure date and should be valid between project task dates ';
            RETURN FALSE;
        ELSIF l_count = 0
        THEN
            x_ret_msg   := ' Expenditure date is not valid, please check';
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Unable to validate Expenditure Item Data: '
                || p_exp_date
                || ' - '
                || SQLERRM;
            RETURN FALSE;
    END is_exp_item_date_valid;

    -- Validate payment terms

    FUNCTION is_term_valid (p_term_id IN NUMBER, x_term_id OUT VARCHAR2, x_term_name OUT VARCHAR2
                            , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_term_id   NUMBER;
    BEGIN
        SELECT term_id, name
          INTO x_term_id, x_term_name
          FROM apps.ap_terms
         WHERE TRIM (term_id) = TRIM (p_term_id);

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Invalid Payment Term Name with ID = ' || p_term_id;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Payment terms exist with ID = ' || p_term_id;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Payment Term: ' || SQLERRM;
            RETURN FALSE;
    END is_term_valid;

    -- Derive Payment Terms from Supplier Site

    FUNCTION get_terms (p_vendor_id        IN     NUMBER,
                        p_vendor_site_id   IN     NUMBER,
                        p_org_id           IN     NUMBER,
                        x_term_id             OUT NUMBER,
                        x_term_name           OUT VARCHAR2,
                        x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_term_id   NUMBER;
    BEGIN
        SELECT apsa.terms_id, apt.name
          INTO x_term_id, x_term_name
          FROM apps.ap_supplier_sites_all apsa, apps.ap_terms apt
         WHERE     apsa.vendor_site_id = p_vendor_site_id
               AND apsa.vendor_id = p_vendor_id
               AND apsa.org_id = p_org_id
               AND apt.term_id = apsa.terms_id
               AND SYSDATE BETWEEN NVL (apt.start_date_active, SYSDATE)
                               AND NVL (apt.end_date_active, SYSDATE)
               AND NVL (apt.enabled_flag, 'Y') = 'Y';

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Please check the Payment Terms at Supplier Site.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Payment terms exist at the Supplier Site';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid payment terms: ' || SQLERRM;
            RETURN FALSE;
    END get_terms;

    -- Validate pay Group

    FUNCTION is_pay_group_valid (p_pay_group IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_code
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'PAY GROUP'
               AND language = USERENV ('LANG')
               AND NVL (enabled_flag, 'Y') = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE)
               AND UPPER (lookup_code) = UPPER (TRIM (p_pay_group));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Pay group lookup code = ' || p_pay_group;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple pay group codes exist with same name = '
                || p_pay_group;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Pay group: ' || SQLERRM;
            RETURN FALSE;
    END is_pay_group_valid;

    -- Validate Invoice Line Type

    FUNCTION is_line_type_valid (p_line_type IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_code   VARCHAR2 (30);
    BEGIN
        SELECT lookup_code
          INTO l_code
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'INVOICE LINE TYPE'
               AND language = USERENV ('LANG')
               AND enabled_flag = 'Y'
               AND UPPER (TRIM (lookup_code)) = UPPER (TRIM (p_line_type));

        x_code   := l_code;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Line type lookup code = ' || p_line_type;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Line type lookup codes exist with same name = '
                || p_line_type;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                ' ' || 'Invalid Line type lookup code: ' || SQLERRM;
            RETURN FALSE;
    END is_line_type_valid;

    -- Derive CCID

    FUNCTION dist_account_exists (p_dist_acct IN VARCHAR2, x_dist_ccid OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT code_combination_id
          INTO x_dist_ccid
          FROM apps.gl_code_combinations_kfv
         WHERE     enabled_flag = 'Y'
               AND concatenated_segments = TRIM (p_dist_acct);

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Distribution Account = ' || p_dist_acct;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Accounts exist with same code combination = '
                || p_dist_acct;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Distribution Account: ' || SQLERRM;
            RETURN FALSE;
    END dist_account_exists;

    -- Validate Intercompany account

    FUNCTION is_interco_acct (p_interco_acct_id IN NUMBER, p_dist_ccid IN NUMBER, p_interco_cc IN VARCHAR2
                              , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM apps.gl_code_combinations_kfv gcc
         WHERE     gcc.detail_posting_allowed = 'Y'
               AND gcc.summary_flag = 'N'
               AND NVL (gcc.enabled_flag, 'N') = 'Y'
               AND gcc.code_combination_id = p_interco_acct_id
               AND gcc.segment1 IN
                       (SELECT SUBSTR (val.description, 1, 3)
                          FROM apps.fnd_flex_values_vl val, apps.fnd_flex_value_sets vset, apps.gl_code_combinations_kfv gcc1
                         WHERE     1 = 1
                               AND val.flex_value_set_id =
                                   vset.flex_value_set_id
                               AND val.enabled_flag = 'Y'
                               AND vset.flex_value_set_name =
                                   'XXDO_INTERCO_AP_AR_MAPPING'
                               AND val.flex_value =
                                   gcc1.concatenated_segments
                               AND gcc1.code_combination_id = p_dist_ccid)
               AND gcc.segment6 NOT IN
                       (SELECT val1.flex_value
                          FROM apps.fnd_flex_values_vl val1, apps.fnd_flex_value_sets vset1
                         WHERE     1 = 1
                               AND val1.flex_value_set_id =
                                   vset1.flex_value_set_id
                               AND val1.enabled_flag = 'Y'
                               AND vset1.flex_value_set_name =
                                   'XXDO_INTERCO_RESTRICTIONS');

        IF l_count = 1
        THEN
            RETURN TRUE;
        ELSIF l_count > 1
        THEN
            x_ret_msg   :=
                   ' There are multiple Intercompany Account Combinations : '
                || p_interco_cc;
            RETURN FALSE;
        ELSE
            x_ret_msg   :=
                   ' Intercompany Account Combination is not found : '
                || p_interco_cc;
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                ' Invalid Intercompany Account Combination : ' || SQLERRM;
            RETURN FALSE;
    END is_interco_acct;

    -- Validate Ship to Location

    FUNCTION is_ship_to_valid (p_ship_to_code IN VARCHAR2, x_ship_to_loc_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_location_id   NUMBER;
    BEGIN
        SELECT location_id
          INTO l_location_id
          FROM apps.hr_locations_all
         WHERE     1 = 1
               AND UPPER (TRIM (location_code)) =
                   UPPER (TRIM (p_ship_to_code));

        x_ship_to_loc_id   := l_location_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Invalid Ship to location code:' || p_ship_to_code;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Ship to location codes exist with same name:'
                || p_ship_to_code;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Invalid Ship to location code:'
                || p_ship_to_code
                || '  '
                || SQLERRM;
            RETURN FALSE;
    END is_ship_to_valid;

    -- Derive Ship to Location ID at Site level

    FUNCTION get_ship_to_loc_id (p_vendor_site_id   IN     NUMBER,
                                 p_org_id           IN     NUMBER,
                                 x_location_id         OUT NUMBER,
                                 x_loc_code            OUT VARCHAR2,
                                 x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_value   NUMBER;
    BEGIN
        SELECT apsa.ship_to_location_id, hla.location_code
          INTO x_location_id, x_loc_code
          FROM ap_supplier_sites_all apsa, hr_locations_all hla
         WHERE     1 = 1
               AND apsa.ship_to_location_id = hla.location_id
               AND vendor_site_id = p_vendor_site_id
               AND org_id = p_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Ship to location doesnot exists for Vendor Site';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Ship to location codes exist for the vendor site ';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Ship to location: ' || SQLERRM;
            RETURN FALSE;
    END;

    -- Check if Period is Open

    FUNCTION is_gl_date_valid (p_gl_date   IN     DATE,
                               p_org_id    IN     NUMBER,
                               x_ret_msg      OUT VARCHAR2)
        RETURN DATE
    IS
        l_valid_date   DATE;
    BEGIN
        IF p_gl_date IS NOT NULL
        THEN
            SELECT p_gl_date
              INTO l_valid_date
              FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
             WHERE     gps.application_id = 200                        --SQLAP
                   AND gps.ledger_id = hou.set_of_books_id
                   AND hou.organization_id = p_org_id
                   AND gps.start_date <= p_gl_date
                   AND gps.end_date >= p_gl_date
                   AND gps.closing_status = 'O';
        /*ELSE
           SELECT MAX(gps.start_date)
             INTO l_valid_date
             FROM apps.gl_period_statuses gps
                , apps.hr_operating_units hou
            WHERE gps.application_id = 200 --SQLAP
              AND gps.ledger_id = hou.set_of_books_id
              AND hou.organization_id = p_org_id
              AND gps.closing_status = 'O';*/
        END IF;

        RETURN l_valid_date;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Date is not in open AP Period: ' || p_gl_date;
            RETURN NULL;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Date:' || p_gl_date || SQLERRM;
            RETURN NULL;
    END is_gl_date_valid;

    -- Check if the date is Open/Future

    FUNCTION is_date_future_valid (p_date      IN     DATE,
                                   p_org_id    IN     NUMBER,
                                   x_ret_msg      OUT VARCHAR2)
        RETURN DATE
    IS
        l_valid_date   DATE;
    BEGIN
        IF p_date IS NOT NULL
        THEN
            SELECT p_date
              INTO l_valid_date
              FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
             WHERE     gps.application_id = 200                        --SQLAP
                   AND gps.ledger_id = hou.set_of_books_id
                   AND hou.organization_id = p_org_id
                   AND gps.start_date <= p_date
                   AND gps.end_date >= p_date
                   AND gps.closing_status IN ('O', 'F');
        /*ELSE
           SELECT MAX(gps.start_date)
             INTO l_valid_date
             FROM apps.gl_period_statuses gps
                , apps.hr_operating_units hou
            WHERE gps.application_id = 200 --SQLAP
              AND gps.ledger_id = hou.set_of_books_id
              AND hou.organization_id = p_org_id
              AND gps.closing_status = 'O';*/
        END IF;

        RETURN l_valid_date;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Date is not in open or Future AP Period: ' || p_date;
            RETURN NULL;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Date:' || p_date || SQLERRM;
            RETURN NULL;
    END is_date_future_valid;

    --START Added as per version 1.2
    -- Check if the period is closed

    FUNCTION is_date_period_close (p_date      IN     DATE,
                                   p_org_id    IN     NUMBER,
                                   x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid_date   DATE;
    BEGIN
        IF p_date IS NOT NULL
        THEN
            SELECT p_date
              INTO l_valid_date
              FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
             WHERE     gps.application_id = 200                        --SQLAP
                   AND gps.ledger_id = hou.set_of_books_id
                   AND hou.organization_id = p_org_id
                   AND gps.start_date <= p_date
                   AND gps.end_date >= p_date
                   AND gps.closing_status IN ('C');
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Date is not in Closed AP Period: ' || p_date;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Date:' || p_date || SQLERRM;
            RETURN FALSE;
    END is_date_period_close;

    -- Derive open period date

    FUNCTION get_open_period_date (p_date      IN     DATE,
                                   p_org_id    IN     NUMBER,
                                   x_ret_msg      OUT VARCHAR2)
        RETURN DATE
    IS
        l_per_start_date   DATE;
    BEGIN
        IF p_date IS NOT NULL
        THEN
            SELECT MAX (gps.start_date)
              INTO l_per_start_date
              FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
             WHERE     gps.application_id = 200                        --SQLAP
                   AND gps.ledger_id = hou.set_of_books_id
                   AND hou.organization_id = p_org_id
                   AND gps.closing_status = 'O';
        END IF;

        RETURN l_per_start_date;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Date is not in Open Period: ' || p_date;
            RETURN NULL;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Date:' || p_date || SQLERRM;
            RETURN NULL;
    END get_open_period_date;

    --END Added as per version 1.2

    -- Check if Project Period is Open

    FUNCTION is_project_period_open (p_gl_date   IN     DATE,
                                     p_org_id    IN     NUMBER,
                                     x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM apps.pa_periods_all pa
         WHERE     pa.org_id = p_org_id
               AND pa.start_date <= p_gl_date
               AND pa.end_date >= p_gl_date
               AND pa.status = 'O';

        IF ln_count > 0
        THEN
            RETURN TRUE;
        ELSE
            x_ret_msg   :=
                ' Project Date is not open for Date: ' || p_gl_date;
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   'Exception Occurred in is_project_period_open function = '
                || SUBSTR (SQLERRM, 1, 200);
    END is_project_period_open;

    -- validate if the given value is Numeric value

    FUNCTION validate_amount (p_amount    IN     VARCHAR2,
                              x_amount       OUT NUMBER,
                              x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_amount   NUMBER;
    BEGIN
        SELECT TO_NUMBER (p_amount) INTO x_amount FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := 'Invalid Number format';
            RETURN FALSE;
    END validate_amount;

    -- Derive Tax Code assigned to OU using custom valueset
    FUNCTION is_tax_code_valid (p_tax_percent IN VARCHAR2, p_tax_ou IN VARCHAR2, x_tax_code OUT VARCHAR2
                                , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT flv.lookup_code
          INTO x_tax_code
          FROM fnd_flex_value_sets ffvs1, fnd_flex_value_sets ffvs2, fnd_flex_values_vl ffv1,
               fnd_flex_values_vl ffv2, apps.fnd_lookup_values flv
         WHERE     1 = 1
               AND ffvs1.flex_value_set_name = 'XXD_AP_CONCUR_TAX_OU'
               AND ffvs2.flex_value_set_name = 'XXD_AP_CONCUR_TAX_OU_VALUES'
               AND ffvs1.flex_value_set_id = ffv1.flex_value_set_id
               AND ffvs2.flex_value_set_id = ffv2.flex_value_set_id
               AND ffv1.flex_value = ffv2.parent_flex_value_low
               AND ffv2.value_category = 'XXD_AP_CONCUR_TAX_OU_VALUES'
               AND flv.LOOKUP_TYPE = 'ZX_OUTPUT_CLASSIFICATIONS'
               AND flv.language = USERENV ('LANG')
               AND flv.lookup_code = lookup_code
               AND ffv1.enabled_flag = 'Y'
               AND ffv2.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffv1.start_date_active, SYSDATE)
                               AND NVL (ffv1.end_date_active, SYSDATE)
               AND SYSDATE BETWEEN NVL (ffv2.start_date_active, SYSDATE)
                               AND NVL (ffv2.end_date_active, SYSDATE)
               AND UPPER (ffv1.flex_value) = UPPER (p_tax_ou)
               AND ffv2.flex_value = p_tax_percent
               AND UPPER (ffv2.attribute1) = UPPER (flv.LOOKUP_code);

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Invalid Tax Classification code:'
                || p_tax_percent
                || CHR (9)
                || 'OU = '
                || p_tax_ou;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Tax Classification codes exist with same name: '
                || p_tax_percent
                || CHR (9)
                || 'OU = '
                || p_tax_ou;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Invalid Tax Classification code: '
                || p_tax_percent
                || CHR (9)
                || 'OU = '
                || p_tax_ou
                || '  '
                || SQLERRM;
            RETURN FALSE;
    END is_tax_code_valid;

    -- Validate Invoice type to be used

    FUNCTION is_inv_type_valid (p_inv_type IN VARCHAR2, x_inv_type OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_inv_type
          FROM fnd_lookup_values
         WHERE     1 = 1
               AND language = 'US'
               AND lookup_type = 'INVOICE TYPE'
               AND view_application_id = 200
               AND NVL (enabled_flag, 'Y') = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE)
               AND UPPER (meaning) = UPPER (TRIM (p_inv_type));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Invoice Type = ' || p_inv_type;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Invoice type lookup codes exist with same name = '
                || p_inv_type;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Line type lookup code: ' || SQLERRM;
            RETURN FALSE;
    END is_inv_type_valid;

    -- Validate email ID

    FUNCTION get_email (x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        l_emp_id   NUMBER;
        l_email    VARCHAR2 (240);
    BEGIN
        BEGIN
            SELECT employee_id, email_address
              INTO l_emp_id, l_email
              FROM apps.fnd_user
             WHERE user_id = apps.fnd_global.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        IF l_email IS NULL AND l_emp_id IS NOT NULL
        THEN
            BEGIN
                SELECT ppf.email_address
                  INTO l_email
                  FROM apps.per_all_people_f ppf
                 WHERE ppf.person_id = l_emp_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_msg   := 'Unable to get email address.';
                    RETURN NULL;
            END;

            RETURN l_email;
        ELSIF l_emp_id IS NULL AND l_email IS NULL
        THEN
            x_ret_msg   := 'Unable to get email address.';
            RETURN NULL;
        ELSIF l_email IS NOT NULL
        THEN
            RETURN l_email;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := 'Unable to get email address.';
            RETURN NULL;
    END get_email;

    -- Get the Error code description

    FUNCTION get_error_desc (p_rejection_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_desc   VARCHAR2 (240);
    BEGIN
        SELECT description
          INTO l_desc
          FROM apps.fnd_lookup_values
         WHERE     lookup_code = p_rejection_code
               AND lookup_type = 'REJECT CODE'
               AND language = USERENV ('LANG');

        RETURN l_desc;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_error_desc;

    -- Added for Change 1.1

    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (32000);
    BEGIN
        IF gc_debug_enable = 'Y'
        THEN
            lv_msg   := pv_msg;

            --Writing into Log file if the program is submitted from Front end application
            IF apps.fnd_global.user_id <> -1
            THEN
                fnd_file.put_line (fnd_file.LOG, lv_msg);
            ELSE
                DBMS_OUTPUT.put_line (lv_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (
                -20020,
                'Error in Procedure write_log -> ' || SQLERRM);
    END write_log;

    -- End of Change 1.1

    -- Start of Change 3.0
    FUNCTION is_match_seg_valid (p_seg_value IN VARCHAR2, p_flex_type IN VARCHAR2, x_match_val OUT VARCHAR2
                                 , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_match_value   VARCHAR2 (100);
    BEGIN
        SELECT ffv.flex_value                                 --ffv.attribute1
          INTO x_match_val
          FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
         WHERE     ffv.flex_value_set_id = ffvs.flex_value_set_id
               AND ffvs.flex_value_set_name = p_flex_type
               --AND ffv.value_category = p_flex_type
               AND ffv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                               AND NVL (ffv.end_date_active, SYSDATE)
               --AND ffv.attribute1 = p_seg_value;
               AND ffv.flex_value = p_seg_value;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Invalid Segment value for Valueset = ' || p_flex_type;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Segment value for Valueset = ' || p_flex_type;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid segment match value: ' || SQLERRM;
            RETURN FALSE;
    END is_match_seg_valid;

    FUNCTION get_emp_bank_acct_num (pn_vendor_id IN NUMBER, -- external_bank_account_id
                                                            pv_match_value IN VARCHAR2, pv_emp_name IN VARCHAR2
                                    , x_ext_bank_account_id OUT VARCHAR2, x_ext_bank_account_num OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_ext_bank_account_id   NUMBER := NULL;
    BEGIN
        SELECT ieba.ext_bank_account_id, ieba.bank_account_num
          INTO x_ext_bank_account_id, x_ext_bank_account_num
          FROM ap.ap_suppliers aps, per_all_people_f papf, apps.iby_ext_bank_accounts ieba,
               apps.iby_account_owners iao, apps.iby_ext_banks_v ieb, apps.iby_ext_bank_branches_v iebb
         WHERE     1 = 1
               AND iao.account_owner_party_id = aps.party_id
               AND ieba.ext_bank_account_id = iao.ext_bank_account_id
               AND ieb.bank_party_id = iebb.bank_party_id
               AND ieba.branch_id = iebb.branch_party_id
               AND ieba.bank_id = ieb.bank_party_id
               AND aps.employee_id = papf.person_id
               AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                       AND papf.effective_end_date
               AND aps.vendor_id = pn_vendor_id
               AND ieba.attribute1 = pv_match_value
               AND ieba.attribute_category = 'XXD CONCUR CARD MATCH';

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' There is No bank account found for Employee = '
                || pv_emp_name
                || ' with Bank Attribute value: '
                || pv_match_value;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Segment value for Employee = '
                || pv_emp_name
                || ' with Bank Attribute value: '
                || pv_match_value;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' '
                || 'Invalid bank match value: '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_emp_bank_acct_num;


    -- End of Change 3.0

    -- Procedure to Insert data into SAE Staging table

    PROCEDURE insert_staging (x_ret_code         OUT NOCOPY VARCHAR2,
                              x_ret_msg          OUT NOCOPY VARCHAR2,
                              p_org_name      IN            VARCHAR2,
                              p_exp_rep_num   IN            VARCHAR2,
                              p_reprocess     IN            VARCHAR2)
    IS
        CURSOR sae_hdr_line_cur IS
              SELECT *
                FROM xxdo.xxd_ap_concur_sae_t
               WHERE     1 = 1
                     AND inv_emp_org_company =
                         NVL (p_org_name, inv_emp_org_company)
                     AND inv_num = NVL (p_exp_rep_num, inv_num)
                     AND NVL (status, 'N') =
                         DECODE (p_reprocess, 'Y', 'E', 'N')
            ORDER BY batch_id, inv_emp_org_company, inv_emp_num,
                     Inv_num;
    BEGIN
        FOR inv_rec IN sae_hdr_line_cur
        LOOP
            --xxv_debug_test_prc ('Inserting into Table');
            write_log ('Inserting into Table');

            BEGIN
                INSERT INTO xxdo.xxd_ap_concur_sae_stg_t (
                                seq_db_num,
                                creation_date,
                                created_by,
                                last_updated_date,
                                last_update_by,
                                last_update_login,
                                file_name,
                                file_processed_date,
                                request_id,
                                Ccard_company_rec,
                                Ccard_personal_rec,
                                oop_rec,
                                Pcard_company_rec,
                                Pcard_Personal_rec,
                                identifier_src,
                                batch_id,
                                batch_date,
                                status,
                                error_msg,
                                seq_num,
                                inv_emp_org_company,
                                emp_num,
                                inv_num,
                                inv_date,
                                Inv_Curr_Code,
                                inv_pay_curr,
                                Inv_desc,
                                inv_exp_rep_type_cc,
                                inv_exp_rep_type_oop,
                                inv_personal_exp_flag,
                                inv_card_Prog_code,
                                inv_pay_type_code,
                                inv_merch_name,
                                inv_merch_city,
                                inv_merch_state,
                                inv_amt,
                                inv_pay_method,
                                inv_line_num,
                                inv_line_type,
                                Inv_line_amt,
                                inv_line_desc,
                                Inv_line_company,
                                inv_line_brand,
                                inv_line_geo,
                                inv_line_channel,
                                inv_line_cost_center,
                                inv_line_acct_code,
                                inv_line_IC,
                                inv_line_future,
                                inv_line_def_option,
                                inv_line_def_start_date,
                                inv_line_def_end_date,
                                inv_line_asset_cat,
                                inv_line_asset_loc,
                                inv_line_asst_cust,
                                inv_line_tax_percent,
                                inv_line_proj_num,
                                inv_line_proj_task,
                                inv_line_proj_exp_date,
                                inv_line_proj_exp_type,
                                inv_line_proj_exp_org,
                                credit_card_acc_num,
                                fapio_number        --Added as per version 1.2
                                            )
                         VALUES (
                                    inv_rec.seq_db_num,
                                    gd_sysdate,
                                    gn_user_id,
                                    gd_sysdate,
                                    gn_user_id,
                                    gn_login_id,
                                    inv_rec.FILE_NAME,
                                    inv_rec.FILE_PROCESSED_DATE,
                                    gn_request_id,
                                    'N'         --,inv_rec.card_company_record
                                       ,
                                    'N'        --,inv_rec.card_personal_record
                                       ,
                                    'N'                  --,inv_rec.opp_record
                                       ,
                                    'N'            --inv_rec.inv_future_value7
                                       ,
                                    'N'            --inv_rec.inv_future_value6
                                       ,
                                    inv_rec.IDENTIFIER_SRC,
                                    inv_rec.batch_id,
                                    inv_rec.batch_date,
                                    'N',
                                    inv_rec.error_msg,
                                    inv_rec.seq_num,
                                    inv_rec.inv_emp_org_company,
                                    inv_rec.inv_emp_num,
                                    inv_rec.inv_num,
                                    inv_rec.inv_date,
                                    inv_rec.inv_curr_code,
                                    inv_rec.inv_pay_curr,
                                    inv_rec.inv_desc,
                                    inv_rec.inv_exp_rep_type_cc,
                                    inv_rec.inv_exp_rep_type_oop,
                                    inv_rec.inv_personal_exp_flag,
                                    inv_rec.inv_future_value4,
                                    inv_rec.inv_future_value5,
                                    inv_rec.inv_future_value1,
                                    inv_rec.inv_future_value2,
                                    inv_rec.inv_future_value3,
                                    NULL,
                                    NULL,
                                    NULL,
                                    'Item',
                                    inv_rec.inv_line_amt --START Commented and Added as per version 1.2
                                                        /*
                                                        ,NVL(inv_rec.Inv_line_vendor_desc,inv_rec.inv_future_value1)
                                                        ||'-'||inv_rec.inv_future_value2||'-'||inv_rec.inv_future_value3||'-'||inv_rec.inv_line_exp_type_name||'-'||
                                                        inv_rec.inv_line_curr_code||'-'||inv_rec.inv_line_buss_pur
                                                        */
                                                        ,
                                    SUBSTRB ( -- Added SUBSTRB instead of SUBSTR
                                           NVL (inv_rec.Inv_line_vendor_desc,
                                                inv_rec.inv_future_value1)
                                        || '|'
                                        || inv_rec.inv_future_value2
                                        || '|'
                                        || inv_rec.inv_future_value3
                                        || '|'
                                        || inv_rec.inv_line_exp_type_name
                                        || '|'
                                        || inv_rec.inv_line_curr_code
                                        || '|'
                                        || inv_rec.inv_line_buss_pur,
                                        1,
                                        240) --END Commented and Added as per version 1.2
                                            ,
                                    inv_rec.Inv_line_dist_company,
                                    inv_rec.Inv_line_dist_brand,
                                    inv_rec.Inv_line_dist_geo,
                                    inv_rec.Inv_line_dist_channel,
                                    inv_rec.Inv_line_dist_cost_center,
                                    inv_rec.inv_line_dist_acct_code,
                                    inv_rec.Inv_line_dist_IC,
                                    inv_rec.Inv_line_dist_future,
                                    inv_rec.inv_line_def_option,
                                    inv_rec.inv_line_def_start_date,
                                    inv_rec.inv_line_def_end_date,
                                    inv_rec.inv_line_asset_cat,
                                    inv_rec.inv_line_asset_loc,
                                    inv_rec.inv_line_asset_custodian,
                                    inv_rec.inv_line_tax_percent,
                                    inv_rec.inv_line_prj_num,
                                    inv_rec.inv_line_prj_task,
                                    inv_rec.inv_lin_prj_expend_item_date,
                                    inv_rec.inv_lin_prj_expend_type,
                                    inv_rec.inv_lin_prj_expend_org,
                                    inv_rec.inv_future_value6,
                                    inv_rec.inv_future_value7 --Added as per version 1.2
                                                             );
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_code   := '2';
                    x_ret_msg    :=
                           'Exception while Inserting the staging Data : '
                        || SUBSTR (SQLERRM, 1, 200);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception while Inserting the staging Data : '
                || SUBSTR (SQLERRM, 1, 200);
    END Insert_Staging;

    -- Validate the data inserted into Staging table

    PROCEDURE validate_staging (x_ret_code       OUT NOCOPY VARCHAR2,
                                x_ret_msg        OUT NOCOPY VARCHAR2,
                                p_org         IN            VARCHAR2,
                                p_exp         IN            VARCHAR2,
                                p_re_flag     IN            VARCHAR2,
                                p_inv_type    IN            VARCHAR2,
                                p_cm_type     IN            VARCHAR2,
                                p_pay_group   IN            VARCHAR2)
    IS
        -- Header Cursor only to select batch and org, excluding Tax Lines

        CURSOR sae_batch_org_cur IS
              SELECT batch_id, inv_emp_org_company, inv_line_geo -- Added as per Change 2.0
                                                                ,
                     inv_line_cost_center           -- Added as per Change 2.0
                FROM xxdo.xxd_ap_concur_sae_stg_t
               WHERE     1 = 1
                     AND NVL (status, 'N') = DECODE (p_re_flag, 'Y', 'E', 'N')
                     AND (NVL (invoice_type_code, 'A') = DECODE (p_inv_type, 'Y', 'STANDARD', NVL (invoice_type_code, 'A')) OR NVL (invoice_type_code, 'A') = DECODE (p_inv_type, 'Y', 'EXPENSE REPORT', NVL (invoice_type_code, 'A')))
                     AND (NVL (invoice_type_code, 'A') = DECODE (p_cm_type, 'Y', 'CREDIT MEMO', NVL (invoice_type_code, 'A')) OR NVL (invoice_type_code, 'A') = DECODE (p_cm_type, 'Y', 'EXPENSE REPORT', NVL (invoice_type_code, 'A')))
                     AND NVL (inv_pay_group, 'A') =
                         DECODE (p_pay_group,
                                 'Y', inv_pay_group,
                                 NVL (inv_pay_group, 'A'))
                     AND inv_emp_org_company = NVL (p_org, inv_emp_org_company)
                     AND inv_num = NVL (p_exp, inv_num)
                     AND NVL (status, 'N') <> G_TAX_LINE
            --       AND  NVL(status,'N') = DECODE(p_reprocess,'Y','E',status)
            GROUP BY batch_id, inv_emp_org_company, inv_line_geo -- Added as per Change 2.0
                                                                ,
                     inv_line_cost_center           -- Added as per Change 2.0
            ORDER BY batch_id, inv_emp_org_company, inv_line_geo -- Added as per Change 2.0
                                                                ,
                     inv_line_cost_center;          -- Added as per Change 2.0

        -- Line Cursor to select all records based on batch and Org company, excluding tax lines

        CURSOR sae_hdr_line_cur (pn_batch_id IN NUMBER, pn_inv_emp_org IN NUMBER, pn_inv_geo IN NUMBER -- Added as per Change 2.0
                                 , pn_inv_cc IN NUMBER -- Added as per Change 2.0
                                                      )
        IS
              SELECT *
                FROM xxdo.xxd_ap_concur_sae_stg_t
               WHERE     1 = 1
                     AND NVL (status, 'N') = DECODE (p_re_flag, 'Y', 'E', 'N')
                     AND (NVL (invoice_type_code, 'A') = DECODE (p_inv_type, 'Y', 'STANDARD', NVL (invoice_type_code, 'A')) OR NVL (invoice_type_code, 'A') = DECODE (p_inv_type, 'Y', 'EXPENSE REPORT', NVL (invoice_type_code, 'A')))
                     AND (NVL (invoice_type_code, 'A') = DECODE (p_cm_type, 'Y', 'CREDIT MEMO', NVL (invoice_type_code, 'A')) OR NVL (invoice_type_code, 'A') = DECODE (p_cm_type, 'Y', 'EXPENSE REPORT', NVL (invoice_type_code, 'A')))
                     AND NVL (inv_pay_group, 'A') =
                         DECODE (p_pay_group,
                                 'Y', inv_pay_group,
                                 NVL (inv_pay_group, 'A'))
                     AND NVL (status, 'N') <> G_TAX_LINE
                     AND inv_num = NVL (p_exp, inv_num)
                     AND batch_id = pn_batch_id
                     AND inv_emp_org_company = pn_inv_emp_org
                     AND inv_line_geo = pn_inv_geo  -- Added as per Change 2.0
                     AND inv_line_cost_center = pn_inv_cc -- Added as per Change 2.0
            ORDER BY batch_id, inv_emp_org_company, vendor_num,
                     Inv_num, seq_db_num;

        -- Cursor to pick invoices before dividing

        CURSOR upd_err_inv (pn_batch_id IN NUMBER, pn_inv_emp_org IN NUMBER, pn_inv_geo IN NUMBER -- Added as per Change 2.0
                            , pn_inv_cc IN NUMBER   -- Added as per Change 2.0
                                                 )
        IS
            SELECT DISTINCT stg.inv_num
              FROM xxdo.xxd_ap_concur_sae_stg_t stg
             WHERE     1 = 1
                   AND (stg.ou_id IS NULL OR stg.vendor_id IS NULL OR stg.vendor_site_id IS NULL OR stg.invoice_type_code IS NULL OR stg.inv_pay_group IS NULL)
                   AND stg.request_id = gn_request_id
                   AND stg.batch_id = pn_batch_id
                   AND NVL (stg.status, 'N') NOT IN (G_TAX_LINE, G_IGNORE)
                   AND stg.inv_emp_org_company = pn_inv_emp_org
                   AND stg.inv_line_geo = pn_inv_geo -- Added as per Change 2.0
                   AND stg.inv_line_cost_center = pn_inv_cc; -- Added as per Change 2.0

        --START Added as per version 1.2
        -- Cursor to pick Invoices for Segregation of Invoice Num

        CURSOR get_inv_to_upd_num (pn_batch_id      IN NUMBER,
                                   pn_inv_emp_org   IN NUMBER-- Start of Change for CCR0009592
                                                             --pn_inv_geo       IN NUMBER,                 -- Added as per Change 2.0
                                                             --pn_inv_cc        IN NUMBER                 -- Added as per Change 2.0
                                                             -- End of Change for CCR0009592
                                                             )
        IS
              SELECT batch_id, inv_emp_org_company, inv_num
                -- Start of Change for CCR0009592
                --inv_line_geo,
                --inv_line_cost_center
                -- End of Change for CCR0009592
                FROM xxdo.xxd_ap_concur_sae_stg_t stg
               WHERE     1 = 1
                     AND stg.batch_id = pn_batch_id
                     AND stg.inv_emp_org_company = pn_inv_emp_org
                     -- Start of Change for CCR0009592
                     --AND stg.inv_line_geo = pn_inv_geo -- Added as per Change 2.0
                     --AND stg.inv_line_cost_center = pn_inv_cc -- Added as per Change 2.0
                     -- End of Change for CCR0009592
                     AND stg.request_id = gn_request_id
                     AND stg.mod_inv_num IS NULL
                     AND NVL (status, 'N') NOT IN (G_TAX_LINE, G_IGNORE)
                     AND (stg.ou_id IS NOT NULL AND stg.vendor_id IS NOT NULL AND stg.vendor_site_id IS NOT NULL AND stg.invoice_type_code IS NOT NULL AND stg.inv_pay_group IS NOT NULL)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_ap_concur_sae_stg_t stg1
                               WHERE     stg.inv_num = stg1.inv_num
                                     AND stg.inv_emp_org_company =
                                         stg1.inv_emp_org_company
                                     -- We are  adding below condition as it has no impact on grouping
                                     AND stg.inv_line_geo = stg1.inv_line_geo -- Added as per Change 2.0
                                     AND stg.inv_line_cost_center =
                                         stg1.inv_line_cost_center -- Added as per Change 2.0;
                                     AND (stg1.ou_id IS NULL OR stg1.vendor_id IS NULL OR stg1.vendor_site_id IS NULL OR stg1.invoice_type_code IS NULL OR stg1.inv_pay_group IS NULL))
            GROUP BY stg.batch_id, stg.inv_emp_org_company, stg.inv_num
            -- Start of Change for CCR0009592
            --stg.inv_line_geo,
            --stg.inv_line_cost_center
            -- End of Change for CCR0009592
            UNION
              SELECT batch_id, inv_emp_org_company, inv_num
                -- Start of Change for CCR0009592
                --inv_line_geo,
                --inv_line_cost_center
                -- End of Change for CCR0009592
                FROM xxdo.xxd_ap_concur_sae_stg_t stg
               WHERE     1 = 1
                     AND stg.batch_id = pn_batch_id
                     AND stg.inv_emp_org_company = pn_inv_emp_org
                     -- Start of Change for CCR0009592
                     --AND stg.inv_line_geo = pn_inv_geo -- Added as per Change 2.0
                     --AND stg.inv_line_cost_center = pn_inv_cc -- Added as per Change 2.0
                     -- End of Change for CCR0009592
                     AND stg.request_id = gn_request_id
                     AND stg.mod_inv_num IS NULL
                     AND NVL (stg.status, 'N') NOT IN (G_TAX_LINE)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM XXDO.XXD_AP_CONCUR_SAE_STG_T stg1
                               WHERE     stg.inv_num = stg1.inv_num
                                     AND stg.inv_emp_org_company =
                                         stg1.inv_emp_org_company
                                     AND stg.inv_line_geo = stg1.inv_line_geo -- Added as per Change 2.0
                                     AND stg.inv_line_cost_center =
                                         stg1.inv_line_cost_center -- Added as per Change 2.0;
                                     AND NVL (stg.status, 'N') IN (G_TAX_LINE))
            GROUP BY stg.batch_id, stg.inv_emp_org_company, stg.inv_num;

        -- Start of Change for CCR0009592
        --stg.inv_line_geo,
        --stg.inv_line_cost_center
        -- End of Change for CCR0009592

        --END Added as per version 1.2

        -- Cursor to pick dividing invoices criteria

        CURSOR update_inv_num (pn_batch_id IN NUMBER, pn_inv_emp_org IN NUMBER, pv_inv_num IN VARCHAR2-- Start of Change for CCR0009592
                                                                                                      --pn_inv_geo       IN NUMBER,                 -- Added as per Change 2.0
                                                                                                      --pn_inv_cc        IN NUMBER                  -- Added as per Change 2.0
                                                                                                      -- End of Change for CCR0009592
                                                                                                      )
        IS
              SELECT inv_num, ou_id, vendor_id,
                     vendor_site_id, invoice_type_code, inv_pay_group,
                     group_by_type_flag
                FROM xxdo.xxd_ap_concur_sae_stg_t stg
               WHERE     1 = 1
                     AND stg.batch_id = pn_batch_id
                     AND stg.inv_emp_org_company = pn_inv_emp_org
                     AND stg.request_id = gn_request_id
                     AND stg.inv_num = pv_inv_num  -- Added as per version 1.2
                     -- Start of Change for CCR0009592
                     --AND stg.inv_line_geo = pn_inv_geo -- Added as per Change 2.0
                     --AND stg.inv_line_cost_center = pn_inv_cc -- Added as per Change 2.0
                     -- End of Change for CCR0009592
                     AND stg.mod_inv_num IS NULL
                     AND NVL (status, 'N') NOT IN (G_TAX_LINE, G_IGNORE)
                     AND (stg.ou_id IS NOT NULL AND stg.vendor_id IS NOT NULL AND stg.vendor_site_id IS NOT NULL AND stg.invoice_type_code IS NOT NULL AND stg.inv_pay_group IS NOT NULL)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM XXDO.XXD_AP_CONCUR_SAE_STG_T stg1
                               WHERE     stg.inv_num = stg1.inv_num
                                     AND stg.inv_emp_org_company =
                                         stg1.inv_emp_org_company
                                     AND stg.inv_line_geo = stg1.inv_line_geo -- Added as per Change 2.0
                                     AND stg.inv_line_cost_center =
                                         stg1.inv_line_cost_center -- Added as per Change 2.0
                                     AND (stg1.ou_id IS NULL OR stg1.vendor_id IS NULL OR stg1.vendor_site_id IS NULL OR stg1.invoice_type_code IS NULL OR stg1.inv_pay_group IS NULL))
            GROUP BY inv_num, ou_id, vendor_id,
                     vendor_site_id, inv_pay_group, invoice_type_code,
                     group_by_type_flag
            UNION
              SELECT inv_num, ou_id, vendor_id,
                     vendor_site_id, invoice_type_code, inv_pay_group,
                     group_by_type_flag
                FROM xxdo.xxd_ap_concur_sae_stg_t stg
               WHERE     1 = 1
                     AND stg.batch_id = pn_batch_id
                     AND stg.inv_emp_org_company = pn_inv_emp_org
                     AND stg.request_id = gn_request_id
                     AND stg.inv_num = pv_inv_num
                     AND stg.mod_inv_num IS NULL
                     AND NVL (stg.status, 'N') NOT IN (G_TAX_LINE)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_ap_concur_sae_stg_t stg1
                               WHERE     stg.inv_num = stg1.inv_num
                                     AND stg.inv_emp_org_company =
                                         stg1.inv_emp_org_company
                                     AND NVL (stg.status, 'N') IN (G_TAX_LINE))
            GROUP BY inv_num, ou_id, vendor_id,
                     vendor_site_id, inv_pay_group, invoice_type_code,
                     group_by_type_flag;

        /*UNION
        SELECT inv_num,ou_id,vendor_id,vendor_site_id,invoice_type_code,inv_pay_group,group_by_type_flag
            FROM  XXDO.XXD_AP_CONCUR_SAE_STG_T stg
           WHERE  1=1
             AND  stg.batch_id = pn_batch_id
             AND  stg.inv_emp_org_company = pn_inv_emp_org
             AND  stg.request_id = gn_request_id
             AND  stg.mod_inv_num IS NULL
             AND  NVL(stg.status,'N') NOT IN (G_IGNORE)
             AND  NOT EXISTS (SELECT  1
                                FROM  XXDO.XXD_AP_CONCUR_SAE_STG_T stg1
                               WHERE  stg.inv_num = stg1.inv_num
                                 AND  stg.inv_emp_org_company = stg1.inv_emp_org_company
                                 AND  NVL(stg.status,'N') IN (G_IGNORE))
        GROUP BY  inv_num,ou_id,vendor_id,vendor_site_id,inv_pay_group,invoice_type_code,group_by_type_flag;*/

        --  Cursor to update error for Divided invoices

        CURSOR upd_inv_flag_cur (pn_batch_id IN NUMBER, pn_inv_emp_org IN NUMBER, pn_inv_geo IN NUMBER -- Added as per Change 2.0
                                 , pn_inv_cc IN NUMBER) -- Added as per Change 2.0))
        IS
              SELECT stg.mod_inv_num
                FROM xxdo.xxd_ap_concur_sae_stg_t stg
               WHERE     1 = 1
                     AND stg.batch_id = pn_batch_id
                     AND stg.inv_emp_org_company = pn_inv_emp_org
                     AND stg.request_id = gn_request_id
                     AND stg.inv_line_geo = pn_inv_geo -- Added as per Change 2.0
                     AND stg.inv_line_cost_center = pn_inv_cc -- Added as per Change 2.0
                     AND NVL (stg.status, 'N') NOT IN (G_TAX_LINE, G_IGNORE)
                     AND (NVL (invoice_type_code, 'A') = DECODE (p_inv_type, 'Y', 'STANDARD', NVL (invoice_type_code, 'A')) OR NVL (invoice_type_code, 'A') = DECODE (p_inv_type, 'Y', 'EXPENSE REPORT', NVL (invoice_type_code, 'A')))
                     AND (NVL (invoice_type_code, 'A') = DECODE (p_cm_type, 'Y', 'CREDIT MEMO', NVL (invoice_type_code, 'A')) OR NVL (invoice_type_code, 'A') = DECODE (p_cm_type, 'Y', 'EXPENSE REPORT', NVL (invoice_type_code, 'A')))
                     AND NVL (inv_pay_group, 'A') =
                         DECODE (p_pay_group,
                                 'Y', 'inv_pay_group',
                                 NVL (inv_pay_group, 'A'))
                     AND (ou_id IS NOT NULL AND vendor_id IS NOT NULL AND vendor_site_id IS NOT NULL AND invoice_type_code IS NOT NULL AND inv_pay_group IS NOT NULL)
                     AND stg.mod_inv_num IS NOT NULL
                     AND EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_ap_concur_sae_stg_t stg1
                               WHERE     stg.inv_num = stg1.inv_num
                                     AND stg.mod_inv_num = stg1.mod_inv_num
                                     AND stg1.status = 'E'
                                     AND stg.ou_id = stg1.ou_id
                                     AND stg.vendor_id = stg1.vendor_id
                                     AND stg.inv_line_geo = stg1.inv_line_geo -- Added as per Change 2.0
                                     AND stg.inv_line_cost_center =
                                         stg1.inv_line_cost_center -- Added as per Change 2.0
                                     AND stg.vendor_site_id =
                                         stg1.vendor_site_id
                                     AND stg.invoice_type_code =
                                         stg1.invoice_type_code
                                     AND stg.inv_pay_group = stg1.inv_pay_group
                                     AND stg.group_by_type_flag =
                                         stg1.group_by_type_flag)
            GROUP BY stg.mod_inv_num, stg.inv_num, stg.ou_id,
                     stg.vendor_id, stg.vendor_site_id, stg.invoice_type_code,
                     stg.inv_pay_group, stg.group_by_type_flag;

        -- Header Level variable declaration
        -- Start of Change as per CCR0009592
        -- Added for 4.0
        --l_inv_line_cost_center      NUMBER;
        --l_inv_emp_org_company       NUMBER;
        --l_inv_line_geo              NUMBER;
        -- End for 4.0
        -- End of Change as per CCR0009592

        l_hdr_status                VARCHAR2 (10);
        l_hdr_msg                   VARCHAR2 (4000);
        l_hdr_boolean               BOOLEAN;
        l_hdr_ret_msg               VARCHAR2 (4000);
        l_inv_hdr_tbl               sae_hdr_line_cur%ROWTYPE;
        l_inv_line_tbl              sae_hdr_line_cur%ROWTYPE;
        l_invoice_id                ap_invoices_all.invoice_id%TYPE;
        l_org_id                    hr_operating_units.organization_id%TYPE;
        l_org_geo                   gl_code_combinations.segment3%TYPE; --- Added as per 2.0
        l_org_cc                    gl_code_combinations.segment5%TYPE; --- Added as per 2.0
        l_org_name                  hr_operating_units.name%TYPE;
        l_vendor_name               ap_suppliers.vendor_name%TYPE;
        l_site                      ap_supplier_sites_all.vendor_site_code%TYPE;
        l_site_id                   ap_supplier_sites_all.vendor_site_id%TYPE;
        l_vendor_id                 ap_suppliers.vendor_id%TYPE;
        l_vendor_num                ap_suppliers.segment1%TYPE;
        l_curr_code                 fnd_currencies.currency_code%TYPE;
        l_inv_term_name             ap_terms.name%TYPE;
        l_inv_term_id               ap_terms.term_id%TYPE;
        l_cm_term_name              ap_terms.name%TYPE;
        l_trx_term_name             ap_terms.name%TYPE;
        l_cm_term_id                ap_terms.term_id%TYPE;
        l_trx_term_id               ap_terms.term_id%TYPE;
        l_inv_date                  ap_invoices_all.invoice_date%TYPE;
        l_proj_exp_date             ap_invoice_lines_all.def_acctg_end_date%TYPE;
        l_inv_gl_date               ap_invoices_all.gl_date%TYPE;
        l_gl_date                   ap_invoices_all.gl_date%TYPE;
        l_inv_type                  fnd_lookup_values.lookup_code%TYPE;
        l_trx_type                  fnd_lookup_values.lookup_code%TYPE;
        l_cm_type                   fnd_lookup_values.lookup_code%TYPE;
        l_trx_type_desc             VARCHAR2 (100);
        l_pg_pcard                  fnd_lookup_values.lookup_code%TYPE;
        l_pg_pcard_per              fnd_lookup_values.lookup_code%TYPE;
        l_pg_card_comp              fnd_lookup_values.lookup_code%TYPE;
        l_pg_card_per               fnd_lookup_values.lookup_code%TYPE;
        l_pg_oop                    fnd_lookup_values.lookup_code%TYPE;
        -- Start of Change 3.0
        l_org_pcard_match           VARCHAR2 (100);
        l_org_pcard_per_match       VARCHAR2 (100);
        l_org_card_comp_match       VARCHAR2 (100);
        l_org_card_per_match        VARCHAR2 (100);
        l_org_oop_match             VARCHAR2 (100);
        l_pcard_match               VARCHAR2 (100);
        l_pcard_per_match           VARCHAR2 (100);
        l_card_comp_match           VARCHAR2 (100);
        l_card_per_match            VARCHAR2 (100);
        l_oop_match                 VARCHAR2 (100);
        -- End of Change 3.0
        l_card_comp_flag            VARCHAR2 (1);
        l_pcard_comp_flag           VARCHAR2 (1);
        l_pcard_per_flag            VARCHAR2 (1);
        l_oop_flag                  VARCHAR2 (1);
        l_card_per_flag             VARCHAR2 (1);
        l_pay_group                 fnd_lookup_values.lookup_code%TYPE;
        l_pay_method                AP_LOOKUP_CODES.lookup_code%TYPE;
        l_ext_bank_account_id       iby_ext_bank_accounts.ext_bank_account_id%TYPE; -- Added as per change 3.0
        l_ext_bank_account_num      iby_ext_bank_accounts.bank_account_num%TYPE; -- Added as per change 3.0
        l_final_match_value         VARCHAR2 (100); -- Added as per change 3.0
        l_final_match_result        VARCHAR2 (500); -- Added as per Change 3.0

        -- Line Level Variable declaration

        l_dist_ccid                 gl_code_combinations.code_combination_id%TYPE;
        l_interco_dist_ccid         gl_code_combinations.code_combination_id%TYPE;
        l_interco_dist_cc           gl_code_combinations_kfv.concatenated_segments%TYPE;
        l_dist_cc                   gl_code_combinations_kfv.concatenated_segments%TYPE;
        l_dist_pos_ic_cc            gl_code_combinations_kfv.concatenated_segments%TYPE;
        l_dist_neg_ic_cc            gl_code_combinations_kfv.concatenated_segments%TYPE;
        l_dist_value                VARCHAR2 (100);
        l_inter_dist_value          VARCHAR2 (100);
        l_bal_seg                   VARCHAR2 (100);
        l_dist_pos_ic_seg1          gl_code_combinations.segment1%TYPE;
        l_dist_pos_ic_seg2          gl_code_combinations.segment2%TYPE;
        l_dist_pos_ic_seg3          gl_code_combinations.segment3%TYPE;
        l_dist_pos_ic_seg4          gl_code_combinations.segment4%TYPE;
        l_dist_pos_ic_seg5          gl_code_combinations.segment5%TYPE;
        l_dist_pos_ic_seg6          gl_code_combinations.segment6%TYPE;
        l_dist_pos_ic_seg7          gl_code_combinations.segment7%TYPE;
        l_dist_pos_ic_seg8          gl_code_combinations.segment8%TYPE;
        l_dist_neg_ic_seg1          gl_code_combinations.segment1%TYPE;
        l_dist_neg_ic_seg2          gl_code_combinations.segment2%TYPE;
        l_dist_neg_ic_seg3          gl_code_combinations.segment3%TYPE;
        l_dist_neg_ic_seg4          gl_code_combinations.segment4%TYPE;
        l_dist_neg_ic_seg5          gl_code_combinations.segment5%TYPE;
        l_dist_neg_ic_seg6          gl_code_combinations.segment6%TYPE;
        l_dist_neg_ic_seg7          gl_code_combinations.segment7%TYPE;
        l_dist_neg_ic_seg8          gl_code_combinations.segment8%TYPE;

        l_ship_loc_id               hr_locations_all.location_id%TYPE;
        l_ship_loc_code             hr_locations_all.location_code%TYPE;
        l_def_flag                  VARCHAR2 (1); --fnd_lookups.lookup_code%TYPE;
        l_tax_rate_flag             VARCHAR2 (1);
        --  l_rec_cc                        VARCHAR2(100);
        l_rec_cc                    gl_code_combinations_kfv.concatenated_segments%TYPE;
        l_group_by_flag             VARCHAR2 (1);

        --START Added as per version 1.2
        l_def_start_dt              ap_invoice_lines_all.def_acctg_start_date%TYPE;
        l_def_end_dt                ap_invoice_lines_all.def_acctg_end_date%TYPE;
        ln_org_name                 hr_operating_units.name%TYPE;
        --END Added as per version 1.2

        l_def_start_date            ap_invoice_lines_all.def_acctg_start_date%TYPE;
        l_def_end_date              ap_invoice_lines_all.def_acctg_end_date%TYPE;
        l_def_st_date               ap_invoice_lines_all.def_acctg_start_date%TYPE;
        l_def_ed_date               ap_invoice_lines_all.def_acctg_end_date%TYPE;
        l_sys_open_date             ap_invoice_lines_all.def_acctg_start_date%TYPE;
        l_tax_code                  fnd_lookup_values.lookup_code%TYPE;
        l_asset_book                fa_book_controls.book_type_code%TYPE;
        l_asset_cat_id              fa_categories.category_id%TYPE;
        l_asset_ccid                NUMBER;
        l_asset_cc                  gl_code_combinations_kfv.concatenated_segments%TYPE;
        l_track_as_asset            VARCHAR2 (1);
        l_proj_id                   pa_projects_all.project_id%TYPE;
        l_asset_loc_id              fa_locations.location_id%TYPE;
        l_proj_task_id              hr_organization_units.organization_id%TYPE;
        l_proj_exp_org_id           NUMBER;
        l_proj_exp_type             VARCHAR2 (100);
        l_value                     VARCHAR2 (100);
        ln_loop_counter             NUMBER := 0;
        l_inv_id                    NUMBER;
        l_line_count                NUMBER := 0;
        l_line_status               VARCHAR2 (1);
        l_inv_line_id               NUMBER;
        l_line_msg                  VARCHAR2 (4000);
        ln_org_id                   NUMBER;
        l_boolean                   BOOLEAN;
        l_msg                       VARCHAR2 (4000);
        l_ret_msg                   VARCHAR2 (4000);
        l_data_msg                  VARCHAR2 (4000);
        l_status                    VARCHAR2 (1);
        l_company_org               VARCHAR2 (100);
        l_inv_count                 NUMBER;
        l_cm_count                  NUMBER;
        ln_vset_cnt                 NUMBER;
        l_org_pg_pcard              VARCHAR2 (100);
        l_org_pg_pcard_per          VARCHAR2 (100);
        l_org_pg_card_comp          VARCHAR2 (100);
        l_org_pg_card_per           VARCHAR2 (100);
        l_org_pg_oop                VARCHAR2 (100);
        l_org_inv_terms             VARCHAR2 (100);
        l_org_cm_terms              VARCHAR2 (100);
        l_org_inv_trx_type          VARCHAR2 (100);
        l_org_CM_trx_type           VARCHAR2 (100);
        l_org_group_by_type         VARCHAR2 (10);
        l_org_bal_segment           VARCHAR2 (100);
        l_org_offset_gl_comb        VARCHAR2 (100);
        l_org_offset_gl_comb_paid   VARCHAR2 (100);
        l_org_IC_positive           VARCHAR2 (100);
        l_org_IC_Negative           VARCHAR2 (100);
        l_org_emp_receivable        VARCHAR2 (10);
        l_org_tax_rate_flag         VARCHAR2 (1);
        l_org_def_nat_acct          VARCHAR2 (100);


        TYPE concur_rec_type IS RECORD
        (
            Org_id                 VARCHAR2 (200),
            pg_pcard               VARCHAR2 (100),
            pg_pcard_per           VARCHAR2 (100),
            pg_card_comp           VARCHAR2 (100),
            pg_card_per            VARCHAR2 (100),
            pg_oop                 VARCHAR2 (100),
            inv_terms              VARCHAR2 (100),
            cm_terms               VARCHAR2 (100),
            inv_trx_type           VARCHAR2 (100),
            CM_trx_type            VARCHAR2 (100),
            group_by_type          VARCHAR2 (10),
            bal_segment            VARCHAR2 (100),
            offset_gl_comb         VARCHAR2 (100),
            offset_gl_comb_paid    VARCHAR2 (100),
            IC_positive            VARCHAR2 (100),
            IC_Negative            VARCHAR2 (100),
            emp_receivable         VARCHAR2 (10),
            tax_rate_flag          VARCHAR2 (1),
            def_nat_acct           VARCHAR2 (100), --- Added as per change 2.0
            ou_geo                 VARCHAR2 (100), --- Added as per change 2.0
            ou_cost_center         VARCHAR2 (100), --- Added as per change 2.0
            -- Start of Change 3.0
            pcard_match            VARCHAR2 (100),
            pcard_per_match        VARCHAR2 (100),
            card_comp_match        VARCHAR2 (100),
            card_per_match         VARCHAR2 (100),
            oop_match              VARCHAR2 (100)
        -- End of Change 3.0
        );

        concur_rec                  concur_rec_type;
    BEGIN
        UPDATE xxdo.xxd_ap_concur_sae_stg_t
           SET data_msg            = NULL,
               process_msg         = NULL,
               error_msg          =
                   (CASE
                        WHEN inv_line_acct_code IS NULL
                        THEN
                            'Tax Line and not eligible for Processing'
                        WHEN     UPPER (INV_PAY_TYPE_CODE) = 'CBCP'
                             AND UPPER (inv_personal_exp_flag) = 'Y'
                             AND credit_card_acc_num IS NULL
                        THEN
                            'Ignore the Record for processing'
                    END),
               header_interfaced   = NULL,
               line_interfaced     = NULL,
               inv_created         = NULL,
               line_created        = NULL,
               inv_flag_valid      = NULL,
               status             =
                   (CASE
                        WHEN inv_line_acct_code IS NULL
                        THEN
                            G_TAX_LINE
                        WHEN     UPPER (INV_PAY_TYPE_CODE) = 'CBCP'
                             AND UPPER (inv_personal_exp_flag) = 'Y'
                             AND credit_card_acc_num IS NULL
                        THEN
                            G_IGNORE
                        ELSE
                            status
                    END)
         WHERE     1 = 1
               AND NVL (status, 'N') IN DECODE (p_re_flag, 'Y', 'E', 'N')
               AND inv_emp_org_company = NVL (p_org, inv_emp_org_company)
               AND inv_num = NVL (p_exp, inv_num)
               AND (NVL (invoice_type_code, 'A') = DECODE (p_inv_type, 'Y', 'STANDARD', NVL (invoice_type_code, 'A')) OR NVL (invoice_type_code, 'A') = DECODE (p_inv_type, 'Y', 'EXPENSE REPORT', NVL (invoice_type_code, 'A')))
               AND (NVL (invoice_type_code, 'A') = DECODE (p_cm_type, 'Y', 'CREDIT MEMO', NVL (invoice_type_code, 'A')) OR NVL (invoice_type_code, 'A') = DECODE (p_cm_type, 'Y', 'EXPENSE REPORT', NVL (invoice_type_code, 'A')))
               AND NVL (inv_pay_group, 'A') =
                   DECODE (p_pay_group,
                           'Y', 'inv_pay_group',
                           NVL (inv_pay_group, 'A'));

        FOR batch_org_rec IN sae_batch_org_cur
        LOOP
            l_hdr_boolean               := NULL;
            l_hdr_ret_msg               := NULL;
            l_hdr_status                := NULL;
            l_value                     := NULL;
            l_org_name                  := NULL;
            l_inv_type                  := NULL;
            l_cm_type                   := NULL;
            l_group_by_flag             := NULL;
            l_pg_pcard                  := NULL;
            l_pg_pcard_per              := NULL;
            l_pg_card_comp              := NULL;
            l_pg_card_per               := NULL;
            l_pg_oop                    := NULL;
            l_pay_method                := NULL;
            l_inv_term_id               := NULL;
            l_inv_term_name             := NULL;
            l_cm_term_id                := NULL;
            l_cm_term_name              := NULL;
            l_dist_pos_ic_seg1          := NULL;
            l_dist_pos_ic_seg2          := NULL;
            l_dist_pos_ic_seg3          := NULL;
            l_dist_pos_ic_seg4          := NULL;
            l_dist_pos_ic_seg5          := NULL;
            l_dist_pos_ic_seg6          := NULL;
            l_dist_pos_ic_seg7          := NULL;
            l_dist_pos_ic_seg8          := NULL;
            l_dist_pos_ic_cc            := NULL;
            l_dist_neg_ic_seg1          := NULL;
            l_dist_neg_ic_seg2          := NULL;
            l_dist_neg_ic_seg3          := NULL;
            l_dist_neg_ic_seg4          := NULL;
            l_dist_neg_ic_seg5          := NULL;
            l_dist_neg_ic_seg6          := NULL;
            l_dist_neg_ic_seg7          := NULL;
            l_dist_neg_ic_seg8          := NULL;
            l_dist_neg_ic_cc            := NULL;
            l_tax_rate_flag             := NULL;
            l_tax_code                  := NULL;
            l_rec_cc                    := NULL;
            l_hdr_status                := NULL;
            l_hdr_msg                   := NULL;
            l_value                     := NULL;
            l_data_msg                  := NULL;
            ln_vset_cnt                 := NULL;
            l_org_id                    := NULL;
            l_org_geo                   := NULL;
            l_org_cc                    := NULL;
            l_org_pg_pcard              := NULL;
            l_org_pg_pcard_per          := NULL;
            l_org_pg_card_comp          := NULL;
            l_org_pg_card_per           := NULL;
            l_org_pg_oop                := NULL;
            l_org_inv_terms             := NULL;
            l_org_cm_terms              := NULL;
            l_org_inv_trx_type          := NULL;
            l_org_CM_trx_type           := NULL;
            l_org_group_by_type         := NULL;
            l_org_bal_segment           := NULL;
            l_org_offset_gl_comb        := NULL;
            l_org_offset_gl_comb_paid   := NULL;
            l_org_IC_positive           := NULL;
            l_org_IC_Negative           := NULL;
            l_org_emp_receivable        := NULL;
            l_org_tax_rate_flag         := NULL;
            l_org_def_nat_acct          := NULL;
            -- Start of Change 3.0

            l_org_pcard_match           := NULL;
            l_org_pcard_per_match       := NULL;
            l_org_card_comp_match       := NULL;
            l_org_card_per_match        := NULL;
            l_org_oop_match             := NULL;
            l_pcard_match               := NULL;
            l_pcard_per_match           := NULL;
            l_card_comp_match           := NULL;
            l_card_per_match            := NULL;
            l_oop_match                 := NULL;

            -- End of Change 3.0

            -- Start of Change as per CCR0009592

            -- Added for 4.0
            /*IF  batch_org_rec.inv_emp_org_company = l_inv_emp_org_company OR
             batch_org_rec.inv_line_geo= l_inv_line_geo or
                batch_org_rec.inv_line_cost_center = l_inv_line_cost_center
                 THEN
                           l_inv_count := l_inv_count ;
               ELSE
                   l_inv_count := 1;
                   END IF;*/
            -- End of change 4.0
            -- End of Change as per CCR0009592


            -- Check the Mandatory columns to derived org_id are not null

            IF     batch_org_rec.inv_emp_org_company IS NOT NULL
               AND batch_org_rec.inv_line_geo IS NOT NULL
               AND batch_org_rec.inv_line_cost_center IS NOT NULL
            THEN
                -- Validate Emp Org Company

                IF batch_org_rec.inv_emp_org_company IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    --l_hdr_status := NULL;
                    l_value         := NULL;
                    l_hdr_boolean   :=
                        is_bal_seg_valid (
                            p_company   => batch_org_rec.inv_emp_org_company,
                            x_ret_msg   => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                        l_value        := 'ERROR';
                    ELSE
                        l_value   := 'VALID';
                    END IF;
                END IF;

                -- Added as per Change 2.0

                -- Validate GEO

                IF batch_org_rec.inv_line_geo IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    --l_hdr_status := NULL;
                    l_value         := NULL;
                    l_hdr_boolean   :=
                        is_seg_valid (p_seg => batch_org_rec.inv_line_geo, p_flex_type => 'DO_GL_GEO', p_seg_type => 'Geo'
                                      , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                        l_value        := 'ERROR';
                    ELSE
                        l_value   := 'VALID';
                    END IF;
                ELSE
                    l_hdr_status   := G_ERRORED;
                    l_hdr_msg      :=
                           l_hdr_msg
                        || ' - '
                        || ' Geo Segment at the line level cannot be NULL ';
                    l_value        := 'ERROR';
                END IF;

                -- Validate Cost Center

                IF batch_org_rec.inv_line_cost_center IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    --l_hdr_status := NULL;
                    l_value         := NULL;
                    l_hdr_boolean   :=
                        is_seg_valid (p_seg => batch_org_rec.inv_line_cost_center, p_flex_type => 'DO_GL_COST_CENTER', p_seg_type => 'Cost Center'
                                      , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                        l_value        := 'ERROR';
                    ELSE
                        l_value   := 'VALID';
                    END IF;
                ELSE
                    l_hdr_status   := G_ERRORED;
                    l_hdr_msg      :=
                           l_hdr_msg
                        || ' - '
                        || ' Cost Center Segment at the line level cannot be NULL ';
                    l_value        := 'ERROR';
                END IF;

                IF l_hdr_boolean = TRUE AND l_value = 'VALID'
                THEN
                    l_hdr_boolean               := NULL;
                    l_hdr_ret_msg               := NULL;
                    --l_hdr_status := NULL;
                    l_value                     := NULL;
                    l_org_id                    := NULL;
                    l_org_geo                   := NULL;
                    l_org_cc                    := NULL;
                    l_org_pg_pcard              := NULL;
                    l_org_pg_pcard_per          := NULL;
                    l_org_pg_card_comp          := NULL;
                    l_org_pg_card_per           := NULL;
                    l_org_pg_oop                := NULL;
                    l_org_inv_terms             := NULL;
                    l_org_cm_terms              := NULL;
                    l_org_inv_trx_type          := NULL;
                    l_org_CM_trx_type           := NULL;
                    l_org_group_by_type         := NULL;
                    l_org_bal_segment           := NULL;
                    l_org_offset_gl_comb        := NULL;
                    l_org_offset_gl_comb_paid   := NULL;
                    l_org_IC_positive           := NULL;
                    l_org_IC_Negative           := NULL;
                    l_org_emp_receivable        := NULL;
                    l_org_tax_rate_flag         := NULL;
                    l_org_def_nat_acct          := NULL;
                    -- Start of Change 3.0
                    l_org_pcard_match           := NULL;
                    l_org_pcard_per_match       := NULL;
                    l_org_card_comp_match       := NULL;
                    l_org_card_per_match        := NULL;
                    l_org_oop_match             := NULL;
                    -- End of Change 3.0

                    l_hdr_boolean               :=
                        get_ou_data (
                            pv_emp_org_company      =>
                                batch_org_rec.inv_emp_org_company,
                            pv_geo                  => batch_org_rec.inv_line_geo,
                            pv_cost_center          =>
                                batch_org_rec.inv_line_cost_center,
                            x_ou_id                 => l_org_id,
                            x_pg_pcard              => l_org_pg_pcard,
                            x_pg_pcard_per          => l_org_pg_pcard_per,
                            x_pg_card_comp          => l_org_pg_card_comp,
                            x_pg_card_per           => l_org_pg_card_per,
                            x_pg_oop                => l_org_pg_oop,
                            x_inv_terms             => l_org_inv_terms,
                            x_cm_terms              => l_org_cm_terms,
                            x_inv_trx_type          => l_org_inv_trx_type,
                            x_CM_trx_type           => l_org_CM_trx_type,
                            x_group_by_type         => l_org_group_by_type,
                            x_bal_segment           => l_org_bal_segment,
                            x_offset_gl_comb        => l_org_offset_gl_comb,
                            x_offset_gl_comb_paid   =>
                                l_org_offset_gl_comb_paid,
                            x_IC_positive           => l_org_IC_positive,
                            x_IC_Negative           => l_org_IC_Negative,
                            x_emp_receivable        => l_org_emp_receivable,
                            x_tax_rate_flag         => l_org_tax_rate_flag,
                            x_def_nat_acct          => l_org_def_nat_acct,
                            x_ou_geo                => l_org_geo,
                            x_ou_cost_center        => l_org_cc,
                            -- Start of Change 3.0
                            x_pcard_match           => l_org_pcard_match,
                            x_pcard_per_match       => l_org_pcard_per_match,
                            x_card_comp_match       => l_org_card_comp_match,
                            x_card_per_match        => l_org_card_per_match,
                            x_oop_match             => l_org_oop_match,
                            -- End of Change 3.0
                            x_ret_msg               => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                        l_value        := 'ERROR';
                    ELSE
                        l_value   := 'VALID';
                    END IF;
                ELSE
                    l_hdr_status   := G_ERRORED;
                    l_hdr_msg      :=
                        l_hdr_msg || ' - ' || 'Issue with OU derivation ';
                    l_value        := 'ERROR';
                END IF;

                /*IF l_hdr_boolean = TRUE AND l_value = 'VALID'
                THEN
                  ln_vset_cnt := 0;
                  SELECT
                          COUNT(*)
                    INTO
                          ln_vset_cnt
                    FROM
                          apps.fnd_flex_value_sets ffvs,
                          apps.fnd_flex_values ffv
                   WHERE  ffvs.flex_value_set_id      = ffv.flex_value_set_id
                     AND  ffvs.flex_value_set_name    = 'XXD_CONCUR_OU'
                     AND  SYSDATE BETWEEN NVL(ffv.start_date_active,SYSDATE) AND NVL(ffv.end_date_active,SYSDATE)
                     AND  ffv.attribute12             = batch_org_rec.inv_emp_org_company
                     AND  ((ffv.attribute20           = batch_org_rec.inv_line_geo
                           AND ffv.attribute21        IS NULL)
                           OR (ffv.attribute21        = batch_org_rec.inv_line_cost_center
                              AND ffv.attribute20     IS NULL)
                           OR (ffv.attribute20        IS NULL
                               AND ffv.attribute21    IS NULL))
                GROUP BY  attribute12,
                          attribute20,
                          attribute21
                  HAVING  count(*) > 1;

                  IF  ln_vset_cnt > 1
                  THEN
                      l_hdr_status := G_ERRORED;
                      l_hdr_msg := l_hdr_msg||' - '||'XXD_CONCUR_OU should have combination of Compant, Geo and Cost Center as Unique for '||batch_org_rec.inv_emp_org_company;
                      l_value := 'ERROR';
                  ELSE
                      l_value := 'VALID';
                  END IF;
                END IF;*/

                -- End of Change 2.0

                IF l_hdr_boolean = TRUE AND l_value = 'VALID'
                THEN
                    BEGIN
                        SELECT l_org_id, l_org_pg_pcard, l_org_pg_pcard_per,
                               l_org_pg_card_comp, l_org_pg_card_per, l_org_pg_oop,
                               l_org_inv_terms, l_org_cm_terms, l_org_inv_trx_type,
                               l_org_CM_trx_type, l_org_group_by_type, l_org_bal_segment,
                               l_org_offset_gl_comb, l_org_offset_gl_comb_paid, l_org_IC_positive,
                               l_org_IC_Negative, l_org_emp_receivable, l_org_tax_rate_flag,
                               l_org_def_nat_acct, l_org_geo, l_org_cc, -- Start of Change 3.0
                               l_org_pcard_match, l_org_pcard_per_match, l_org_card_comp_match,
                               l_org_card_per_match, l_org_oop_match
                          -- End of Change 3.0
                          /*
                          ffv.attribute1,
                          ffv.attribute2,
                          ffv.attribute3,
                          ffv.attribute4,
                          ffv.attribute5,
                          ffv.attribute6,
                          ffv.attribute7,
                          ffv.attribute8,
                          ffv.attribute9,
                          ffv.attribute10,
                          ffv.attribute11,
                          ffv.attribute12,
                          ffv.attribute13,
                          ffv.attribute14,
                          ffv.attribute15,
                          ffv.attribute16,
                          ffv.attribute17,
                          ffv.attribute18,
                          ffv.attribute19,
                          ffv.attribute20,
                          ffv.attribute21
                          */
                          INTO concur_rec
                          FROM DUAL;
                    /*apps.fnd_flex_value_sets ffvs,
                    apps.fnd_flex_values ffv
             WHERE  1=1
               AND  ffvs.flex_value_set_id    = ffv.flex_value_set_id
               AND  ffvs.flex_value_set_name  = 'XXD_CONCUR_OU'
               AND  SYSDATE BETWEEN NVL(ffv.start_date_active,SYSDATE) AND NVL(ffv.end_date_active,SYSDATE)
               AND  ffv.attribute12           = batch_org_rec.inv_emp_org_company
               -- Added as per Change 2.0
               AND  ((attribute20             = batch_org_rec.inv_line_geo
                      AND attribute21         = batch_org_rec.inv_line_cost_center )
                      OR
                      (attribute20            = batch_org_rec.inv_line_geo
                      AND attribute21 IS NULL )
                      OR
                      (attribute21 IS NULL AND attribute20 IS NULL));*/
                    -- End of Change 2.0
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_hdr_msg      :=
                                   l_hdr_msg
                                || ' Mapping is not found for the Company Segment ';
                            l_hdr_status   := G_ERRORED;
                    END;
                END IF;

                -- Fetch OU ID --

                IF concur_rec.org_id IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    --l_hdr_status := NULL;
                    l_hdr_ret_msg   := NULL;
                    l_org_id        := NULL;
                    l_org_name      := NULL;
                    ln_org_name     := NULL;

                    SELECT name
                      INTO ln_org_name
                      FROM apps.hr_operating_units
                     WHERE     organization_id = TRIM (concur_rec.org_id)
                           AND date_from <= SYSDATE
                           AND NVL (date_to, SYSDATE) >= SYSDATE;

                    l_hdr_boolean   :=
                        is_org_valid (p_org_id     => concur_rec.org_id,
                                      p_org_name   => ln_org_name, --Added as per version 1.2
                                      x_org_id     => l_org_id,
                                      x_org_name   => l_org_name,
                                      x_ret_msg    => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_org_id IS NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                ELSE
                    l_hdr_status   := G_ERRORED;
                    l_hdr_msg      :=
                           l_hdr_msg
                        || ' - '
                        || ' Operating Unit cannot be NULL in the Valueset';
                END IF;

                -- Validate Invoice Type

                IF concur_rec.inv_trx_type IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    --l_hdr_status := NULL;
                    l_inv_type      := NULL;
                    l_hdr_boolean   :=
                        is_inv_type_valid (
                            p_inv_type   => concur_rec.inv_trx_type,
                            x_inv_type   => l_inv_type,
                            x_ret_msg    => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                ELSE
                    l_hdr_status   := G_ERRORED;
                    l_hdr_msg      :=
                           l_hdr_msg
                        || ' Invoice Type Cannot be NULL in the Value set';
                END IF;

                --- Validate CM Type

                IF concur_rec.cm_trx_type IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    --l_hdr_status := NULL;
                    l_cm_type       := NULL;
                    l_hdr_boolean   :=
                        is_inv_type_valid (
                            p_inv_type   => concur_rec.cm_trx_type,
                            x_inv_type   => l_cm_type,
                            x_ret_msg    => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                ELSE
                    l_hdr_status   := G_ERRORED;
                    l_hdr_msg      :=
                           l_hdr_msg
                        || ' CM Type Cannot be NULL in the Value set';
                END IF;

                -- Validate Group by Type flag

                IF concur_rec.group_by_type IS NOT NULL
                THEN
                    --l_hdr_status := NULL;
                    l_hdr_boolean     := NULL;
                    l_ret_msg         := NULL;
                    l_group_by_flag   := NULL;
                    l_hdr_boolean     :=
                        is_flag_valid (p_flag      => concur_rec.group_by_type,
                                       x_flag      => l_group_by_flag,
                                       x_ret_msg   => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_ret_msg;
                    END IF;
                END IF;

                -- Validate PG P Card

                IF concur_rec.pg_pcard IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    --        l_hdr_status := NULL;
                    l_pg_pcard      := NULL;
                    l_hdr_boolean   :=
                        is_pay_group_valid (
                            p_pay_group   => concur_rec.pg_pcard,
                            x_code        => l_pg_pcard,
                            x_ret_msg     => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- Validate PG P Card Personal

                IF concur_rec.pg_pcard_per IS NOT NULL
                THEN
                    l_hdr_boolean    := NULL;
                    l_hdr_ret_msg    := NULL;
                    --        l_hdr_status := NULL;
                    l_pg_pcard_per   := NULL;
                    l_hdr_boolean    :=
                        is_pay_group_valid (
                            p_pay_group   => concur_rec.pg_pcard_per,
                            x_code        => l_pg_pcard_per,
                            x_ret_msg     => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- Validate PG Card Company

                IF concur_rec.pg_card_comp IS NOT NULL
                THEN
                    l_hdr_boolean    := NULL;
                    l_hdr_ret_msg    := NULL;
                    --        l_hdr_status := NULL;
                    l_pg_card_comp   := NULL;
                    l_hdr_boolean    :=
                        is_pay_group_valid (
                            p_pay_group   => concur_rec.pg_card_comp,
                            x_code        => l_pg_card_comp,
                            x_ret_msg     => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- Validate PG Card Personal

                IF concur_rec.pg_card_per IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    --        l_hdr_status := NULL;
                    l_pg_card_per   := NULL;
                    l_hdr_boolean   :=
                        is_pay_group_valid (
                            p_pay_group   => concur_rec.pg_card_per,
                            x_code        => l_pg_card_per,
                            x_ret_msg     => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- Validate PG OOP

                IF concur_rec.pg_oop IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    --        l_hdr_status := NULL;
                    l_pg_oop        := NULL;
                    l_hdr_boolean   :=
                        is_pay_group_valid (
                            p_pay_group   => concur_rec.pg_oop,
                            x_code        => l_pg_oop,
                            x_ret_msg     => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- Start of Change 3.0

                IF concur_rec.pcard_match IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    l_pcard_match   := NULL;
                    l_hdr_boolean   :=
                        is_match_seg_valid (p_seg_value => concur_rec.pcard_match, p_flex_type => 'XXD_CONCUR_CARD_MATCH_VS', x_match_val => l_pcard_match
                                            , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                IF concur_rec.pcard_per_match IS NOT NULL
                THEN
                    l_hdr_boolean       := NULL;
                    l_hdr_ret_msg       := NULL;
                    l_pcard_per_match   := NULL;
                    l_hdr_boolean       :=
                        is_match_seg_valid (p_seg_value => concur_rec.pcard_per_match, p_flex_type => 'XXD_CONCUR_CARD_MATCH_VS', x_match_val => l_pcard_per_match
                                            , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                IF concur_rec.card_comp_match IS NOT NULL
                THEN
                    l_hdr_boolean       := NULL;
                    l_hdr_ret_msg       := NULL;
                    l_card_comp_match   := NULL;
                    l_hdr_boolean       :=
                        is_match_seg_valid (p_seg_value => concur_rec.card_comp_match, p_flex_type => 'XXD_CONCUR_CARD_MATCH_VS', x_match_val => l_card_comp_match
                                            , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                IF concur_rec.card_per_match IS NOT NULL
                THEN
                    l_hdr_boolean      := NULL;
                    l_hdr_ret_msg      := NULL;
                    l_card_per_match   := NULL;
                    l_hdr_boolean      :=
                        is_match_seg_valid (p_seg_value => concur_rec.card_per_match, p_flex_type => 'XXD_CONCUR_CARD_MATCH_VS', x_match_val => l_card_per_match
                                            , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                IF concur_rec.oop_match IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    l_oop_match     := NULL;
                    l_hdr_boolean   :=
                        is_match_seg_valid (p_seg_value => concur_rec.oop_match, p_flex_type => 'XXD_CONCUR_CARD_MATCH_VS', x_match_val => l_oop_match
                                            , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- End of Change 3.0

                -- Validate and get Invoice Payment Terms

                IF concur_rec.inv_terms IS NOT NULL
                THEN
                    l_hdr_boolean     := NULL;
                    l_hdr_ret_msg     := NULL;
                    --        l_hdr_status  := NULL;
                    l_inv_term_id     := NULL;
                    l_inv_term_name   := NULL;
                    l_hdr_boolean     :=
                        is_term_valid (p_term_id => concur_rec.inv_terms, x_term_id => l_inv_term_id, x_term_name => l_inv_term_name
                                       , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    ELSE
                        l_inv_term_id   := concur_rec.inv_terms;
                    END IF;
                ELSE
                    l_hdr_boolean     := NULL;
                    l_hdr_ret_msg     := NULL;
                    --        l_hdr_status  := NULL;
                    l_inv_term_id     := NULL;
                    l_inv_term_name   := NULL;
                    l_hdr_boolean     :=
                        get_terms (p_vendor_id        => l_vendor_id,
                                   p_vendor_site_id   => l_site_id,
                                   p_org_id           => l_org_id,
                                   x_term_id          => l_inv_term_id,
                                   x_term_name        => l_inv_term_name,
                                   x_ret_msg          => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- Validate and get CM Payment Terms

                IF concur_rec.cm_terms IS NOT NULL
                THEN
                    l_hdr_boolean    := NULL;
                    l_hdr_ret_msg    := NULL;
                    --        l_hdr_status  := NULL;
                    l_cm_term_id     := NULL;
                    l_cm_term_name   := NULL;
                    l_hdr_boolean    :=
                        is_term_valid (p_term_id => concur_rec.cm_terms, x_term_id => l_cm_term_id, x_term_name => l_cm_term_name
                                       , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    ELSE
                        l_cm_term_id   := concur_rec.cm_terms;
                    END IF;
                ELSE
                    l_hdr_boolean    := NULL;
                    l_hdr_ret_msg    := NULL;
                    --        l_hdr_status  := NULL;
                    l_cm_term_id     := NULL;
                    l_cm_term_name   := NULL;
                    l_hdr_boolean    :=
                        get_terms (p_vendor_id        => l_vendor_id,
                                   p_vendor_site_id   => l_site_id,
                                   p_org_id           => l_org_id,
                                   x_term_id          => l_cm_term_id,
                                   x_term_name        => l_cm_term_name,
                                   x_ret_msg          => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- Validate Bal Segment in valueset

                IF concur_rec.bal_segment IS NOT NULL
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    --        l_hdr_status := NULL;
                    l_bal_seg       := NULL;
                    l_hdr_boolean   :=
                        is_seg_valid (p_seg => concur_rec.bal_segment, p_flex_type => 'DO_GL_COMPANY', p_seg_type => 'Company'
                                      , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    ELSE
                        l_bal_seg   := 'VALID';
                    END IF;
                ELSE
                    l_hdr_status   := G_ERRORED;
                    l_hdr_msg      :=
                           l_hdr_msg
                        || ' - '
                        || ' Balancing Segment cannot be NULL in the valueset';
                END IF;

                -- Validate IC Positive Code combination and Split it into Account Segments

                IF concur_rec.IC_positive IS NOT NULL
                THEN
                    l_hdr_boolean        := NULL;
                    l_hdr_ret_msg        := NULL;
                    --        l_hdr_status  := NULL;
                    l_dist_pos_ic_seg1   := NULL;
                    l_dist_pos_ic_seg2   := NULL;
                    l_dist_pos_ic_seg3   := NULL;
                    l_dist_pos_ic_seg4   := NULL;
                    l_dist_pos_ic_seg5   := NULL;
                    l_dist_pos_ic_seg6   := NULL;
                    l_dist_pos_ic_seg7   := NULL;
                    l_dist_pos_ic_seg8   := NULL;
                    l_dist_pos_ic_cc     := NULL;
                    l_hdr_boolean        :=
                        get_cc_segments (
                            p_ic_acct   => concur_rec.IC_positive,
                            x_seg1      => l_dist_pos_ic_seg1,
                            x_seg2      => l_dist_pos_ic_seg2,
                            x_seg3      => l_dist_pos_ic_seg3,
                            x_seg4      => l_dist_pos_ic_seg4,
                            x_seg5      => l_dist_pos_ic_seg5,
                            x_seg6      => l_dist_pos_ic_seg6,
                            x_seg7      => l_dist_pos_ic_seg7,
                            x_seg8      => l_dist_pos_ic_seg8,
                            x_cc        => l_dist_pos_ic_cc,
                            x_ret_msg   => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- Validate IC Negative Code combination and Split it into Account Segments

                IF concur_rec.IC_Negative IS NOT NULL
                THEN
                    l_hdr_boolean        := NULL;
                    l_hdr_ret_msg        := NULL;
                    --        l_hdr_status  := NULL;
                    l_dist_neg_ic_seg1   := NULL;
                    l_dist_neg_ic_seg2   := NULL;
                    l_dist_neg_ic_seg3   := NULL;
                    l_dist_neg_ic_seg4   := NULL;
                    l_dist_neg_ic_seg5   := NULL;
                    l_dist_neg_ic_seg6   := NULL;
                    l_dist_neg_ic_seg7   := NULL;
                    l_dist_neg_ic_seg8   := NULL;
                    l_dist_neg_ic_cc     := NULL;
                    l_hdr_boolean        :=
                        get_cc_segments (
                            p_ic_acct   => concur_rec.IC_positive,
                            x_seg1      => l_dist_neg_ic_seg1,
                            x_seg2      => l_dist_neg_ic_seg2,
                            x_seg3      => l_dist_neg_ic_seg3,
                            x_seg4      => l_dist_neg_ic_seg4,
                            x_seg5      => l_dist_neg_ic_seg5,
                            x_seg6      => l_dist_neg_ic_seg6,
                            x_seg7      => l_dist_neg_ic_seg7,
                            x_seg8      => l_dist_neg_ic_seg8,
                            x_cc        => l_dist_neg_ic_cc,
                            x_ret_msg   => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- Validate consider Tax Rate flag

                IF concur_rec.tax_rate_flag IS NOT NULL
                THEN
                    --        l_hdr_status := NULL;
                    l_hdr_ret_msg     := NULL;
                    l_tax_rate_flag   := NULL;
                    l_hdr_boolean     :=
                        is_flag_valid (p_flag      => concur_rec.tax_rate_flag,
                                       x_flag      => l_tax_rate_flag,
                                       x_ret_msg   => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- Validate Emp receivable code combination and get CCID

                IF concur_rec.emp_receivable IS NOT NULL
                THEN
                    --        l_hdr_status := NULL;
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    l_rec_cc        := NULL;
                    l_hdr_boolean   :=
                        is_gl_code_valid (
                            p_ccid      => concur_rec.emp_receivable,
                            x_cc        => l_rec_cc,
                            x_ret_msg   => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      :=
                               l_hdr_msg
                            || ' - emp_receivable value set '
                            || l_hdr_ret_msg;
                    END IF;
                END IF;

                -- If any one of the above conditions fails then update the full set of Staging records
                -- that belongs to Org and Batch ID


                IF l_hdr_boolean = FALSE OR l_hdr_status = G_ERRORED
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_ap_concur_sae_stg_t stg
                           SET stg.status = l_hdr_status, stg.error_msg = SUBSTR (l_hdr_msg, 1, 4000)
                         WHERE     stg.inv_emp_org_company =
                                   batch_org_rec.inv_emp_org_company
                               AND stg.inv_line_cost_center =
                                   batch_org_rec.inv_line_cost_center
                               AND stg.inv_line_geo =
                                   batch_org_rec.inv_line_geo -- Added as per Change 2.0
                               AND stg.batch_id = batch_org_rec.batch_id; -- Added as per Change 2.0
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_hdr_status   := G_ERRORED;
                            l_hdr_msg      :=
                                   l_hdr_msg
                                || ' - '
                                || 'Exception Occurred updating SAE STG table : '
                                || SUBSTR (SQLERRM, 1, 200);
                    END;
                ELSE
                    NULL;
                END IF;

                write_log (
                       ' Header records are processed succesfully for Batch ID : '
                    || batch_org_rec.batch_id
                    || ' With Emp Org Company as '
                    || batch_org_rec.inv_emp_org_company
                    || ' With Emp Geo as '
                    || batch_org_rec.inv_line_geo
                    || ' With Emp Cost Center as '
                    || batch_org_rec.inv_line_cost_center);
            ELSE
                l_hdr_status   := G_ERRORED;
                l_hdr_msg      :=
                       l_hdr_msg
                    || ' Company Segment,Geo and Cost Center values cannot be NULL ';
                l_value        := 'ERROR';

                BEGIN
                    UPDATE xxdo.xxd_ap_concur_sae_stg_t stg
                       SET stg.status = l_hdr_status, stg.error_msg = SUBSTR (l_hdr_msg, 1, 4000)
                     WHERE     1 = 1
                           AND stg.inv_emp_org_company =
                               batch_org_rec.inv_emp_org_company
                           AND stg.inv_line_cost_center =
                               batch_org_rec.inv_line_cost_center -- Added as per 2.0
                           AND stg.inv_line_geo = batch_org_rec.inv_line_geo -- Added as per 2.0
                           AND stg.batch_id = batch_org_rec.batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_hdr_status   := G_ERRORED;
                        l_hdr_msg      :=
                               l_hdr_msg
                            || ' - '
                            || 'Exception Occurred updating SAE STG table for INV Org Company : '
                            || SUBSTR (SQLERRM, 1, 200);
                END;
            END IF;

            -- Once all the values at header are validated, Looping individual lines for validation

            IF l_hdr_status IS NULL                -- l_hdr_status IS NULL AND
            THEN
                FOR inv_rec
                    IN sae_hdr_line_cur (batch_org_rec.batch_id,
                                         batch_org_rec.inv_emp_org_company,
                                         batch_org_rec.inv_line_geo, --- Added as per 2.0
                                         batch_org_rec.inv_line_cost_center --- Added as per 2.0
                                                                           )
                LOOP
                    l_msg                    := NULL;
                    l_data_msg               := NULL;
                    l_ret_msg                := NULL;
                    l_vendor_name            := NULL;
                    l_vendor_id              := NULL;
                    l_vendor_num             := NULL;
                    l_site                   := NULL;
                    l_site_id                := NULL;
                    l_ship_loc_id            := NULL;
                    l_ship_loc_code          := NULL;
                    l_curr_code              := NULL;
                    l_inv_date               := NULL;
                    l_inv_gl_date            := NULL;
                    l_gl_date                := NULL;
                    l_card_comp_flag         := NULL;
                    l_pay_group              := NULL;
                    l_pay_method             := NULL;
                    l_ext_bank_account_id    := NULL; -- Added as per change 3.0
                    l_ext_bank_account_num   := NULL; -- Added as per change 3.0
                    l_final_match_value      := NULL; -- Added as per change 3.0
                    l_final_match_result     := NULL; -- Added as per change 3.0
                    l_card_per_flag          := NULL;
                    l_oop_flag               := NULL;
                    l_pcard_per_flag         := NULL;
                    l_pcard_comp_flag        := NULL;
                    l_dist_value             := NULL;
                    l_dist_ccid              := NULL;
                    l_dist_cc                := NULL;
                    l_trx_type               := NULL;
                    l_trx_type_desc          := NULL;
                    l_trx_term_id            := NULL;
                    l_trx_term_name          := NULL;
                    l_def_flag               := NULL;
                    l_def_start_date         := NULL;
                    l_def_st_date            := NULL;
                    l_def_start_dt           := NULL;
                    l_def_end_dt             := NULL;
                    l_def_end_date           := NULL;
                    l_sys_open_date          := NULL;
                    l_proj_exp_date          := NULL;
                    l_def_ed_date            := NULL;
                    l_asset_cat_id           := NULL;
                    l_asset_book             := NULL;
                    l_asset_ccid             := NULL;
                    l_asset_cc               := NULL;
                    l_track_as_asset         := NULL;
                    l_proj_task_id           := NULL;
                    l_proj_id                := NULL;
                    l_proj_exp_org_id        := NULL;
                    l_proj_exp_type          := NULL;
                    l_inter_dist_value       := NULL;
                    l_interco_dist_ccid      := NULL;
                    l_interco_dist_cc        := NULL;
                    ln_loop_counter          := 0;
                    l_invoice_id             := NULL;
                    l_status                 := NULL;
                    l_line_count             := 0;
                    l_boolean                := NULL;

                    -- Get Vendor Number/Employee Number

                    IF inv_rec.emp_num IS NOT NULL
                    THEN
                        l_boolean       := NULL;
                        l_ret_msg       := NULL;
                        l_vendor_name   := NULL;
                        l_vendor_id     := NULL;
                        l_vendor_num    := NULL;
                        l_boolean       :=
                            is_vendor_valid (
                                p_vendor_number   => inv_rec.emp_num,
                                x_vendor_id       => l_vendor_id,
                                x_vendor_num      => l_vendor_num,
                                x_vendor_name     => l_vendor_name,
                                x_ret_msg         => l_ret_msg);

                        IF l_boolean = FALSE OR l_vendor_id IS NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        END IF;
                    ELSE
                        l_status   := G_ERRORED;
                        l_msg      :=
                            l_msg || ' Supplier Number cannot be NULL ';
                    END IF;

                    -- Get Supplier Site

                    IF inv_rec.emp_num IS NOT NULL AND l_boolean = TRUE
                    THEN
                        l_boolean   := NULL;
                        l_ret_msg   := NULL;
                        l_site_id   := NULL;
                        l_site      := NULL;
                        l_boolean   :=
                            is_site_valid (p_org_id => l_org_id, p_org_name => ln_org_name, p_vendor_id => l_vendor_id, p_vendor_number => l_vendor_num --Added as per version 1.2
                                                                                                                                                       , x_site_id => l_site_id, x_site => l_site
                                           , x_ret_msg => l_ret_msg);

                        IF l_boolean = FALSE OR l_site_id IS NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' -  ' || l_ret_msg;
                        END IF;
                    ELSE
                        l_status   := G_ERRORED;
                        l_msg      :=
                               l_msg
                            || ' Please Check Emp Number and OU assigned is Valid';
                    END IF;

                    -- Get Ship to location ID

                    IF l_site_id IS NOT NULL AND l_org_id IS NOT NULL
                    THEN
                        l_boolean         := NULL;
                        l_ret_msg         := NULL;
                        l_ship_loc_id     := NULL;
                        l_ship_loc_code   := NULL;
                        l_boolean         :=
                            get_ship_to_loc_id (
                                p_vendor_site_id   => l_site_id,
                                p_org_id           => l_org_id,
                                x_location_id      => l_ship_loc_id,
                                x_loc_code         => l_ship_loc_code,
                                x_ret_msg          => l_ret_msg);

                        IF l_ship_loc_id IS NULL OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        END IF;
                    ELSE
                        l_status   := G_ERRORED;
                        l_msg      :=
                               l_msg
                            || ' - '
                            || ' Site and OU are required for Ship to Location details ';
                    END IF;

                    -- Validate and get Payment Currency and Invoice Currency

                    IF inv_rec.inv_curr_code IS NOT NULL
                    THEN
                        l_boolean     := NULL;
                        l_ret_msg     := NULL;
                        l_curr_code   := NULL;
                        l_boolean     :=
                            is_curr_code_valid (
                                p_curr_code   => inv_rec.inv_curr_code,
                                x_ret_msg     => l_ret_msg);

                        IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        ELSE
                            l_curr_code   := inv_rec.inv_curr_code;
                        END IF;
                    END IF;

                    -- Validate Invoice date

                    IF inv_rec.Inv_date IS NOT NULL
                    THEN
                        l_boolean    := NULL;
                        l_ret_msg    := NULL;
                        l_inv_date   := NULL;

                        BEGIN
                            SELECT TO_DATE (TO_CHAR (TO_DATE (inv_rec.Inv_date, 'YYYY-MM-DD'), G_FORMAT_MASK), G_FORMAT_MASK)
                              INTO l_inv_date
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      :=
                                       l_msg
                                    || ' - '
                                    || ' Invalid Invoice date format. Please enter in the format: '
                                    || G_FORMAT_MASK;
                        END;
                    ELSE
                        l_status   := G_ERRORED;
                        l_msg      :=
                            l_msg || ' - ' || ' Invoice Date cannot be NULL ';
                    END IF;

                    -- Validate gl_date

                    BEGIN
                        SELECT TO_DATE (TO_CHAR (SYSDATE, G_FORMAT_MASK), G_FORMAT_MASK)
                          INTO l_inv_gl_date
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_inv_gl_date   := NULL;
                            l_status        := G_ERRORED;
                            l_ret_msg       :=
                                   ' Invalid GL date format. Please enter in the format: '
                                || G_FORMAT_MASK;
                            l_msg           := l_msg || ' - ' || l_ret_msg;
                    END;

                    IF l_inv_gl_date IS NOT NULL
                    THEN
                        l_ret_msg   := NULL;
                        l_gl_date   :=
                            is_gl_date_valid (p_gl_date   => l_inv_gl_date,
                                              p_org_id    => l_org_id,
                                              x_ret_msg   => l_ret_msg);

                        IF l_gl_date IS NULL OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        END IF;
                    END IF;

                    -- Validate Invoice num

                    IF inv_rec.Inv_num IS NOT NULL
                    THEN
                        l_boolean   := NULL;
                        --        l_status := NULL;
                        l_ret_msg   := NULL;
                        l_boolean   :=
                            is_inv_num_valid (p_inv_num          => inv_rec.Inv_num,
                                              p_vendor_id        => l_vendor_id,
                                              p_vendor_site_id   => l_site_id,
                                              p_org_id           => l_org_id,
                                              x_ret_msg          => l_ret_msg);

                        IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        END IF;
                    ELSE
                        l_status   := G_ERRORED;
                        l_msg      :=
                               l_msg
                            || ' - '
                            || ' Invoice Number Cannot be NULL ';
                    END IF;

                    -- Validate Cards

                    IF     UPPER (inv_rec.inv_pay_type_code) IN
                               ('IBIP', 'IBCP')
                       AND UPPER (NVL (inv_rec.inv_personal_exp_flag, 'N')) =
                           'N'
                    THEN
                        l_card_comp_flag      := 'Y';
                        l_pay_group           := concur_rec.pg_card_comp;
                        l_final_match_value   := l_card_comp_match; -- Added as per 3.0
                        l_final_match_result   :=
                               'CC COMPANY'
                            || ' - '
                            || NVL (l_card_comp_match, 'No Value'); -- Added as per 3.0
                    ELSIF     UPPER (inv_rec.INV_PAY_TYPE_CODE) IN
                                  ('IBIP', 'IBCP')
                          AND UPPER (
                                  NVL (inv_rec.inv_personal_exp_flag, 'N')) =
                              'Y'
                    THEN
                        l_card_per_flag       := 'Y';
                        l_pay_group           := concur_rec.pg_card_per;
                        l_final_match_value   := l_card_per_match; -- Added as per 3.0
                        l_final_match_result   :=
                               'CC PERSONAL'
                            || ' - '
                            || NVL (l_card_per_match, 'No Value'); -- Added as per 3.0
                    ELSIF     UPPER (inv_rec.inv_exp_rep_type_cc) =
                              'EMPLOYEE'
                          AND UPPER (inv_rec.inv_exp_rep_type_oop) =
                              'OUT-OF-POCKET'
                          AND UPPER (inv_rec.INV_PAY_TYPE_CODE) = 'CASH'
                    THEN
                        l_oop_flag            := 'Y';
                        l_pay_group           := concur_rec.pg_oop;
                        l_final_match_value   := l_oop_match; -- Added as per 3.0
                        l_final_match_result   :=
                               'OO POCKET'
                            || ' - '
                            || NVL (l_oop_match, 'No Value'); -- Added as per 3.0
                    ELSIF     UPPER (inv_rec.INV_PAY_TYPE_CODE) = 'CBCP'
                          AND UPPER (
                                  NVL (inv_rec.inv_personal_exp_flag, 'N')) =
                              'Y'
                          AND NVL (inv_rec.credit_card_acc_num, 'N') <> 'N'
                    THEN
                        l_pcard_per_flag      := 'Y';
                        l_pay_group           := concur_rec.pg_pcard_per;
                        l_final_match_value   := l_pcard_per_match; -- Added as per 3.0
                        l_final_match_result   :=
                               'PCARD PERSONAL'
                            || ' - '
                            || NVL (l_pcard_per_match, 'No Value'); -- Added as per 3.0
                    ELSIF     UPPER (inv_rec.INV_PAY_TYPE_CODE) = 'CBCP'
                          AND UPPER (
                                  NVL (inv_rec.inv_personal_exp_flag, 'N')) =
                              'N'
                          AND NVL (inv_rec.credit_card_acc_num, 'N') <> 'N'
                    THEN
                        l_pcard_comp_flag     := 'Y';
                        l_pay_group           := concur_rec.pg_pcard;
                        l_final_match_value   := l_pcard_match; -- Added as per 3.0
                        l_final_match_result   :=
                               'PC COMPANY'
                            || ' - '
                            || NVL (l_pcard_match, 'No Value'); -- Added as per 3.0
                    ELSE
                        l_pay_group            := NULL;
                        l_status               := G_ERRORED;
                        l_msg                  :=
                               l_msg
                            || ' - '
                            || ' Line should have the Pay group value derived';
                        l_final_match_value    := NULL;    -- Added as per 3.0
                        l_final_match_result   := NULL;    -- Added as per 3.0
                    END IF;

                    IF l_pay_group IS NULL
                    THEN
                        l_status   := G_ERRORED;
                        l_msg      :=
                               l_msg
                            || ' - '
                            || ' Please Check the Paygroup assigned in valueset for OU = '
                            || l_org_name;
                    END IF;

                    IF l_pay_group IS NOT NULL
                    THEN
                        l_boolean      := NULL;
                        l_pay_method   := NULL;
                        l_ret_msg      := NULL;
                        l_boolean      :=
                            get_payment_code (p_pay_group => l_pay_group, p_pay_ou => l_org_name, x_pay_code => l_pay_method
                                              , x_ret_msg => l_ret_msg);

                        IF l_pay_method IS NULL OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        END IF;
                    END IF;

                    -- Get bank account number and pass it to Interface
                    -- Added as per Change 3.0

                    IF l_final_match_value IS NOT NULL
                    THEN
                        l_boolean                := NULL;
                        l_ext_bank_account_id    := NULL;
                        l_ext_bank_account_num   := NULL;
                        l_ret_msg                := NULL;
                        l_boolean                :=
                            get_emp_bank_acct_num (
                                pn_vendor_id             => l_vendor_id, -- external_bank_account_id
                                pv_match_value           => l_final_match_value,
                                pv_emp_name              => l_vendor_num,
                                x_ext_bank_account_id    =>
                                    l_ext_bank_account_id,
                                x_ext_bank_account_num   =>
                                    l_ext_bank_account_num,
                                x_ret_msg                => l_ret_msg);

                        IF    l_ext_bank_account_id IS NULL
                           OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        END IF;


                        IF     l_ext_bank_account_id IS NOT NULL
                           AND l_ext_bank_account_num IS NOT NULL
                        THEN
                            NULL;

                            IF inv_rec.credit_card_acc_num IS NULL
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      :=
                                       l_msg
                                    || ' - '
                                    || 'There is No Credit Card Account Number Associated with this line, please check. ';
                            ELSIF SUBSTR (inv_rec.credit_card_acc_num, -4, 4) <>
                                  SUBSTR (l_ext_bank_account_num, -4, 4)
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      :=
                                       l_msg
                                    || ' - '
                                    || 'The derived bank account num '
                                    || l_ext_bank_account_num
                                    || ' is not inline with credit card account number '
                                    || inv_rec.credit_card_acc_num;
                            END IF;
                        END IF;
                    END IF;

                    -- End of Change

                    -- Validate Invoice line distribution account company segment only if it is not personal expense

                    IF UPPER (NVL (inv_rec.inv_personal_exp_flag, 'N')) = 'N'
                    THEN
                        IF inv_rec.Inv_line_company IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => inv_rec.Inv_line_company, p_flex_type => 'DO_GL_COMPANY', p_seg_type => 'Company'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := G_ERRORED;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || ' Company Segment at the line level cannot be NULL ';
                        END IF;

                        -- Validate Invoice line distribution account Brand segment

                        IF inv_rec.inv_line_brand IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => inv_rec.inv_line_brand, p_flex_type => 'DO_GL_BRAND', p_seg_type => 'Brand'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := G_ERRORED;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || ' Brand Segment at the line level cannot be NULL ';
                        END IF;

                        -- Validate Invoice line distribution account Geo segment

                        IF inv_rec.inv_line_geo IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => inv_rec.inv_line_geo, p_flex_type => 'DO_GL_GEO', p_seg_type => 'Geo'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := G_ERRORED;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || ' Geo Segment at the line level cannot be NULL ';
                        END IF;

                        -- Validate Invoice line distribution account Channel segment

                        IF inv_rec.inv_line_channel IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => inv_rec.inv_line_channel, p_flex_type => 'DO_GL_CHANNEL', p_seg_type => 'Channel'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := G_ERRORED;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || ' Channel Segment at the line level cannot be NULL ';
                        END IF;

                        -- Validate Invoice line distribution account Cost Center segment

                        IF inv_rec.inv_line_cost_center IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => inv_rec.inv_line_cost_center, p_flex_type => 'DO_GL_COST_CENTER', p_seg_type => 'Cost Center'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := G_ERRORED;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || ' Cost Center Segment at the line level cannot be NULL ';
                        END IF;

                        -- Validate Invoice line distribution account segment

                        IF inv_rec.inv_line_acct_code IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => inv_rec.inv_line_acct_code, p_flex_type => 'DO_GL_ACCOUNT', p_seg_type => 'Account'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := G_ERRORED;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        END IF;

                        -- Validate Invoice line distribution IC segment

                        IF inv_rec.inv_line_IC IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => inv_rec.inv_line_IC, p_flex_type => 'DO_GL_COMPANY', p_seg_type => 'Intercompany Account'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := G_ERRORED;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || ' Intercompany Account Segment at the line level cannot be NULL ';
                        END IF;

                        -- Validate Invoice line distribution account Future segment

                        IF inv_rec.inv_line_future IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => inv_rec.inv_line_future, p_flex_type => 'DO_GL_FUTURE', p_seg_type => 'Future Account'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := G_ERRORED;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || ' Future Account Segment at the line level cannot be NULL ';
                        END IF;

                        -- Validate Distribution Account Combination of segments
                        -- Deriving Dist. account only for Non Assets and Non projects
                        -- (For Projects and Assets Workflow should be deriving the values -- Out of scope of Concur)

                        IF     inv_rec.inv_line_asset_cat IS NULL
                           AND inv_rec.inv_line_proj_num IS NULL
                        THEN
                            IF     inv_rec.Inv_line_company IS NOT NULL
                               AND (concur_rec.bal_segment IS NOT NULL AND l_bal_seg = 'VALID')
                               AND inv_rec.Inv_line_company =
                                   concur_rec.bal_segment
                            THEN
                                IF NVL (l_dist_value, 'ABC') = 'ABC'
                                THEN
                                    l_boolean     := NULL;
                                    l_ret_msg     := NULL;
                                    l_dist_ccid   := NULL;
                                    l_dist_cc     := NULL;
                                    l_boolean     :=
                                        is_code_comb_valid (
                                            p_seg1      =>
                                                inv_rec.Inv_line_company,
                                            p_seg2      => inv_rec.inv_line_brand,
                                            p_seg3      => inv_rec.inv_line_geo,
                                            p_seg4      =>
                                                inv_rec.inv_line_channel,
                                            p_seg5      =>
                                                inv_rec.inv_line_cost_center,
                                            p_seg6      =>
                                                inv_rec.inv_line_acct_code,
                                            p_seg7      => inv_rec.inv_line_IC,
                                            p_seg8      =>
                                                inv_rec.inv_line_future,
                                            x_ccid      => l_dist_ccid,
                                            x_cc        => l_dist_cc,
                                            x_ret_msg   => l_ret_msg);

                                    IF    l_boolean = FALSE
                                       OR l_ret_msg IS NOT NULL
                                    THEN
                                        l_status   := G_ERRORED;
                                        l_msg      := l_msg || l_ret_msg;
                                    END IF;
                                ELSE
                                    l_status   := G_ERRORED;
                                    l_msg      :=
                                           l_msg
                                        || ' - '
                                        || ' Please check combination segments provided for this line ';
                                END IF;
                            ELSIF     inv_rec.Inv_line_company IS NOT NULL
                                  AND (concur_rec.bal_segment IS NOT NULL AND l_bal_seg = 'VALID')
                                  AND inv_rec.Inv_line_company <>
                                      concur_rec.bal_segment
                                  AND inv_rec.Inv_line_amt > 0
                            THEN
                                IF l_dist_pos_ic_cc IS NOT NULL
                                THEN
                                    l_boolean     := NULL;
                                    l_ret_msg     := NULL;
                                    l_dist_ccid   := NULL;
                                    l_dist_cc     := NULL;
                                    l_boolean     :=
                                        is_code_comb_valid (
                                            p_seg1      => l_dist_pos_ic_seg1,
                                            p_seg2      => l_dist_pos_ic_seg2,
                                            p_seg3      => l_dist_pos_ic_seg3,
                                            p_seg4      => l_dist_pos_ic_seg4,
                                            p_seg5      => l_dist_pos_ic_seg5,
                                            p_seg6      => l_dist_pos_ic_seg6,
                                            p_seg7      =>
                                                inv_rec.Inv_line_company,
                                            p_seg8      => l_dist_pos_ic_seg8,
                                            x_ccid      => l_dist_ccid,
                                            x_cc        => l_dist_cc,
                                            x_ret_msg   => l_ret_msg);

                                    IF    l_boolean = FALSE
                                       OR l_ret_msg IS NOT NULL
                                    THEN
                                        l_status   := G_ERRORED;
                                        l_msg      := l_msg || l_ret_msg;
                                    ELSE
                                        l_inter_dist_value   := 'VALID';
                                    END IF;
                                ELSE
                                    l_status   := G_ERRORED;
                                    l_msg      :=
                                           l_msg
                                        || ' - '
                                        || 'IC Positive Account cannot be Null or Invalid When the Invoice line is IC ';
                                END IF;
                            ELSIF     inv_rec.Inv_line_company IS NOT NULL
                                  AND (concur_rec.bal_segment IS NOT NULL AND l_bal_seg = 'VALID')
                                  AND inv_rec.Inv_line_company <>
                                      concur_rec.bal_segment
                                  AND inv_rec.Inv_line_amt < 0
                            THEN
                                IF l_dist_neg_ic_cc IS NOT NULL
                                THEN
                                    l_boolean     := NULL;
                                    l_ret_msg     := NULL;
                                    l_dist_ccid   := NULL;
                                    l_dist_cc     := NULL;
                                    --        l_status := NULL;
                                    l_boolean     :=
                                        is_code_comb_valid (
                                            p_seg1      => l_dist_neg_ic_seg1,
                                            p_seg2      => l_dist_neg_ic_seg2,
                                            p_seg3      => l_dist_neg_ic_seg3,
                                            p_seg4      => l_dist_neg_ic_seg4,
                                            p_seg5      => l_dist_neg_ic_seg5,
                                            p_seg6      => l_dist_neg_ic_seg6,
                                            p_seg7      =>
                                                inv_rec.Inv_line_company,
                                            p_seg8      => l_dist_pos_ic_seg8,
                                            x_ccid      => l_dist_ccid,
                                            x_cc        => l_dist_cc,
                                            x_ret_msg   => l_ret_msg);

                                    IF    l_boolean = FALSE
                                       OR l_ret_msg IS NOT NULL
                                    THEN
                                        l_status   := G_ERRORED;
                                        l_msg      := l_msg || l_ret_msg;
                                    ELSE
                                        l_inter_dist_value   := 'VALID';
                                    END IF;
                                ELSE
                                    l_status   := G_ERRORED;
                                    l_msg      :=
                                           l_msg
                                        || ' - '
                                        || 'IC Negative Account from Value Set cannot be Null or Invalid When the Invoice line is IC ';
                                END IF;
                            END IF;

                            -- Validate the Interco Exp Account from File.

                            IF NVL (l_inter_dist_value, 'ABC') = 'VALID'
                            THEN
                                l_boolean             := NULL;
                                l_ret_msg             := NULL;
                                l_interco_dist_ccid   := NULL;
                                l_interco_dist_cc     := NULL;
                                l_boolean             :=
                                    is_code_comb_valid (
                                        p_seg1      => inv_rec.Inv_line_company,
                                        p_seg2      => inv_rec.inv_line_brand,
                                        p_seg3      => inv_rec.inv_line_geo,
                                        p_seg4      => inv_rec.inv_line_channel,
                                        p_seg5      =>
                                            inv_rec.inv_line_cost_center,
                                        p_seg6      => inv_rec.inv_line_acct_code,
                                        p_seg7      => inv_rec.inv_line_IC,
                                        p_seg8      => inv_rec.inv_line_future,
                                        x_ccid      => l_interco_dist_ccid,
                                        x_cc        => l_interco_dist_cc,
                                        x_ret_msg   => l_ret_msg);

                                IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                                THEN
                                    l_status   := G_ERRORED;
                                    l_msg      := l_msg || ' - ' || l_ret_msg;
                                ELSIF l_interco_dist_ccid IS NOT NULL
                                THEN
                                    l_boolean   := NULL;
                                    l_ret_msg   := NULL;
                                    l_boolean   :=
                                        is_interco_acct (
                                            p_interco_acct_id   =>
                                                l_interco_dist_ccid,
                                            p_dist_ccid   => l_dist_ccid,
                                            p_interco_cc   =>
                                                l_interco_dist_cc,
                                            x_ret_msg     => l_ret_msg);

                                    IF    l_boolean = FALSE
                                       OR l_ret_msg IS NOT NULL
                                    THEN
                                        l_status   := G_ERRORED;
                                        l_msg      :=
                                            l_msg || ' - ' || l_ret_msg;
                                    END IF;
                                END IF;
                            END IF;
                        END IF;
                    -- For Personal Expense, employee receivable account from Valueset shall be considered

                    ELSIF     UPPER (
                                  NVL (inv_rec.inv_personal_exp_flag, 'N')) =
                              'Y'
                          AND (l_card_per_flag = 'Y' OR l_pcard_per_flag = 'Y')
                    THEN
                        l_boolean     := NULL;
                        l_ret_msg     := NULL;
                        l_dist_ccid   := NULL;
                        l_dist_cc     := NULL;

                        IF l_rec_cc IS NULL
                        THEN
                            l_boolean   := FALSE;
                            l_status    := G_ERRORED;
                            l_msg       :=
                                   l_msg
                                || ' - '
                                || ' Employee receivable account is required for card Personal charges ';
                        ELSE
                            l_dist_ccid   := concur_rec.emp_receivable;
                            l_dist_cc     := l_rec_cc;
                        END IF;
                    END IF;



                    IF inv_rec.inv_line_amt > 0
                    THEN
                        l_trx_type        := l_inv_type;
                        l_trx_type_desc   := concur_rec.inv_trx_type;
                        l_trx_term_id     := l_inv_term_id;
                        l_trx_term_name   := l_inv_term_name;
                    ELSE
                        l_trx_type        := l_cm_type;
                        l_trx_type_desc   := concur_rec.inv_trx_type;
                        l_trx_term_id     := l_cm_term_id;
                        l_trx_term_name   := l_cm_term_name;
                    END IF;

                    l_def_flag               := NULL;
                    l_def_start_date         := NULL;
                    l_def_st_date            := NULL;
                    l_def_start_dt           := NULL;
                    l_def_end_dt             := NULL;
                    l_def_end_date           := NULL;
                    l_def_ed_date            := NULL;
                    l_sys_open_date          := NULL;

                    -- Validate Deferred Option flag

                    IF inv_rec.Inv_line_def_option IS NOT NULL
                    THEN
                        --        l_status := NULL;
                        l_ret_msg    := NULL;
                        l_def_flag   := NULL;
                        l_boolean    :=
                            is_flag_valid (
                                p_flag      => inv_rec.Inv_line_def_option,
                                x_flag      => l_def_flag,
                                x_ret_msg   => l_ret_msg);

                        write_log (
                               ' Def line option entered : '
                            || inv_rec.Inv_line_def_option
                            || ' and validated Def line flag is : '
                            || l_def_flag);

                        IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        END IF;
                    END IF;

                    --Validate Deferred Start and End dates

                    IF inv_rec.Inv_line_def_option IS NOT NULL
                    THEN
                        IF     l_def_flag IS NOT NULL
                           AND NVL (l_def_flag, 'N') = 'Y'
                           AND (inv_rec.inv_line_def_start_date IS NULL OR inv_rec.inv_line_def_end_date IS NULL)
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || ' Deferred option validation issue- Start\End Date should not be NULL for Flag-Y ';
                        END IF;
                    END IF;

                    write_log (
                           ' Deferred option values are : option flag is : '
                        || l_def_flag
                        || ' Def Start date is : '
                        || inv_rec.inv_line_def_start_date
                        || ' Def End Date is : '
                        || inv_rec.inv_line_def_end_date);

                    -- Validate Deferred Start date

                    IF     inv_rec.Inv_line_def_option = 'Y'
                       AND inv_rec.inv_line_def_start_date IS NOT NULL
                    THEN
                        l_boolean          := NULL;
                        l_def_start_date   := NULL;
                        l_def_st_date      := NULL;
                        l_sys_open_date    := NULL;
                        l_def_start_dt     := NULL;
                        l_ret_msg          := NULL;

                        BEGIN
                            SELECT TO_DATE (TO_CHAR (TO_DATE (inv_rec.inv_line_def_start_date, 'YYYY-MM-DD'), G_FORMAT_MASK), G_FORMAT_MASK)
                              INTO l_def_st_date
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_def_st_date   := NULL;
                                l_boolean       := NULL;
                                l_status        := G_ERRORED;
                                l_ret_msg       :=
                                       ' Invalid date format. Please enter in the format: '
                                    || G_FORMAT_MASK;
                                l_msg           :=
                                    l_msg || ' - ' || l_ret_msg;
                        END;

                        -- START Added as per version 1.2
                        -- Validate Inv Line Def Option 'Y' for Start Date

                        IF l_def_st_date IS NOT NULL
                        THEN
                            -- Validate Start Date is in Closed Period
                            l_boolean   :=
                                is_date_period_close (
                                    p_date      => l_def_st_date,
                                    p_org_id    => l_org_id,
                                    x_ret_msg   => l_ret_msg);

                            IF l_boolean = TRUE
                            THEN
                                BEGIN
                                    SELECT gps.start_date
                                      INTO l_sys_open_date
                                      FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
                                     WHERE     gps.application_id = 200 --SQLAP
                                           AND gps.ledger_id =
                                               hou.set_of_books_id
                                           AND hou.organization_id = l_org_id
                                           AND gps.start_date <=
                                               TRUNC (SYSDATE)
                                           AND gps.end_date >=
                                               TRUNC (SYSDATE)
                                           AND gps.closing_status IN ('O');
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_sys_open_date   := NULL;
                                END;

                                IF l_sys_open_date IS NULL
                                THEN
                                    l_def_start_date   :=
                                        get_open_period_date (
                                            p_date      => l_def_st_date,
                                            p_org_id    => l_org_id,
                                            x_ret_msg   => l_ret_msg);
                                ELSE
                                    l_def_start_date   := l_sys_open_date;
                                END IF;
                            ELSE
                                l_def_start_date   :=
                                    is_date_future_valid (
                                        p_date      => l_def_st_date,
                                        p_org_id    => l_org_id,
                                        x_ret_msg   => l_ret_msg);
                            END IF;
                        END IF;

                        -- END Added as per version 1.2

                        IF l_def_start_date IS NULL OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        END IF;
                    ELSE
                        l_def_start_date   := NULL;
                    END IF;

                    -- Validate Deferred End date

                    IF     inv_rec.Inv_line_def_option = 'Y'
                       AND inv_rec.inv_line_def_end_date IS NOT NULL
                    THEN
                        l_boolean         := NULL;
                        l_def_end_date    := NULL;
                        l_def_end_dt      := NULL;
                        l_sys_open_date   := NULL;
                        l_ret_msg         := NULL;
                        l_def_ed_date     := NULL;

                        BEGIN
                            SELECT TO_DATE (TO_CHAR (TO_DATE (inv_rec.inv_line_def_end_date, 'YYYY-MM-DD'), G_FORMAT_MASK), G_FORMAT_MASK)
                              INTO l_def_ed_date
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_def_ed_date   := NULL;
                                l_status        := G_ERRORED;
                                l_ret_msg       :=
                                       ' Invalid date format. Please enter in the format: '
                                    || G_FORMAT_MASK;
                                l_msg           :=
                                    l_msg || ' - ' || l_ret_msg;
                        END;

                        -- START Added as per version 1.2
                        -- Validate Inv Line Def Option 'Y' for End Date

                        IF l_def_ed_date IS NOT NULL
                        THEN
                            -- Validate End Date is in Closed Period
                            l_boolean   :=
                                is_date_period_close (
                                    p_date      => l_def_ed_date,
                                    p_org_id    => l_org_id,
                                    x_ret_msg   => l_ret_msg);

                            IF l_boolean = TRUE
                            THEN
                                BEGIN
                                    SELECT gps.start_date
                                      INTO l_sys_open_date
                                      FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
                                     WHERE     gps.application_id = 200 --SQLAP
                                           AND gps.ledger_id =
                                               hou.set_of_books_id
                                           AND hou.organization_id = l_org_id
                                           AND gps.start_date <=
                                               TRUNC (SYSDATE)
                                           AND gps.end_date >=
                                               TRUNC (SYSDATE)
                                           AND gps.closing_status IN ('O');
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_sys_open_date   := NULL;
                                END;

                                IF l_sys_open_date IS NULL
                                THEN
                                    l_def_end_date   :=
                                        get_open_period_date (
                                            p_date      => l_def_ed_date,
                                            p_org_id    => l_org_id,
                                            x_ret_msg   => l_ret_msg);
                                ELSE
                                    l_def_end_date   := l_sys_open_date;
                                END IF;
                            ELSE
                                l_def_end_date   :=
                                    is_date_future_valid (
                                        p_date      => l_def_ed_date,
                                        p_org_id    => l_org_id,
                                        x_ret_msg   => l_ret_msg);
                            END IF;
                        END IF;

                        --Validate Open Period End Date should not greater than Start Date
                        IF l_def_start_date >
                           NVL (l_def_end_date, l_def_start_date)
                        THEN
                            l_def_end_date   := l_def_start_date;
                        END IF;

                        write_log (
                               ' Deferred Open period dates are : Start date is : '
                            || l_def_start_date
                            || 'and End date is : '
                            || l_def_end_date);

                        -- END Added as per version 1.2

                        IF l_def_end_date IS NULL OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        END IF;
                    ELSE
                        l_def_end_date   := NULL;
                    END IF;

                    -- Get Asset Book and Validate Asset category

                    IF inv_rec.inv_line_asset_cat IS NOT NULL
                    THEN
                        l_boolean        := NULL;
                        l_asset_cat_id   := NULL;
                        l_ret_msg        := NULL;
                        l_boolean        :=
                            get_asset_category (
                                p_asset_cat      => inv_rec.inv_line_asset_cat,
                                x_asset_cat_id   => l_asset_cat_id,
                                x_ret_msg        => l_ret_msg);

                        IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        ELSIF l_boolean = TRUE
                        THEN
                            l_boolean      := NULL;
                            l_asset_book   := NULL;
                            l_ret_msg      := NULL;
                            l_boolean      :=
                                get_asset_book (
                                    p_comp_seg1    =>
                                        inv_rec.inv_emp_org_company,
                                    x_asset_book   => l_asset_book,
                                    x_ret_msg      => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      := l_msg || ' - ' || l_ret_msg;
                            ELSIF l_boolean = TRUE
                            THEN
                                l_ret_msg   := NULL;
                                l_boolean   := NULL;
                                l_boolean   :=
                                    is_asset_cat_valid (
                                        p_asset_cat_id   => l_asset_cat_id,
                                        p_asset_book     => l_asset_book,
                                        x_ret_msg        => l_ret_msg);

                                IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                                THEN
                                    l_status   := G_ERRORED;
                                    l_msg      := l_msg || ' - ' || l_ret_msg;
                                END IF;
                            END IF;
                        END IF;

                        IF     l_boolean = TRUE
                           AND l_asset_cat_id IS NOT NULL
                           AND l_asset_book IS NOT NULL
                        THEN
                            l_track_as_asset   := 'Y';
                            l_boolean          := NULL;
                            l_ret_msg          := NULL;
                            l_asset_ccid       := NULL;
                            l_asset_cc         := NULL;
                            l_boolean          :=
                                get_asset_cc (p_cat_id       => l_asset_cat_id,
                                              p_asset_book   => l_asset_book,
                                              x_ccid         => l_asset_ccid,
                                              x_cc           => l_asset_cc,
                                              x_ret_msg      => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      := l_msg || ' - ' || l_ret_msg;
                            END IF;
                        END IF;
                    END IF;

                    IF l_tax_rate_flag IS NOT NULL AND l_tax_rate_flag = 'Y'
                    THEN
                        l_boolean    := NULL;
                        l_tax_code   := NULL;
                        l_ret_msg    := NULL;

                        IF inv_rec.inv_line_tax_percent IS NULL
                        THEN
                            l_boolean   := FALSE;
                            l_status    := G_ERRORED;
                            l_msg       :=
                                   l_msg
                                || ' - '
                                || ' Tax rate value is required for Tax related OU = '
                                || l_org_name;
                        ELSE
                            l_boolean   :=
                                is_tax_code_valid (p_tax_percent => inv_rec.inv_line_tax_percent, p_tax_ou => l_org_name, x_tax_code => l_tax_code
                                                   , x_ret_msg => l_ret_msg);

                            IF l_tax_code IS NULL OR l_ret_msg IS NOT NULL
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      := l_msg || ' - ' || l_ret_msg;
                            END IF;
                        END IF;
                    END IF;

                    -- Validate Project number

                    IF inv_rec.inv_line_proj_num IS NOT NULL
                    THEN
                        l_boolean   := NULL;
                        l_ret_msg   := NULL;
                        l_proj_id   := NULL;
                        l_boolean   :=
                            get_project_id (
                                p_proj_number   => inv_rec.inv_line_proj_num,
                                p_org_id        => l_org_id,
                                p_org_name      => ln_org_name --Added as per version 1.2
                                                              ,
                                x_proj_id       => l_proj_id,
                                x_ret_msg       => l_ret_msg);

                        IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      := l_msg || ' - ' || l_ret_msg;
                        END IF;
                    END IF;

                    -- Validate Project Task and other project activities only if it has valid project number

                    IF l_proj_id IS NOT NULL
                    THEN
                        NULL;

                        IF inv_rec.inv_line_proj_task IS NOT NULL
                        THEN
                            l_boolean        := NULL;
                            l_ret_msg        := NULL;
                            l_proj_task_id   := NULL;
                            l_boolean        :=
                                get_project_task_id (p_task_number => inv_rec.inv_line_proj_task, p_proj_id => l_proj_id, x_proj_task_id => l_proj_task_id
                                                     , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      := l_msg || ' - ' || l_ret_msg;
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || 'Project Task cannot be NULL for Project';
                        END IF;

                        -- Validate Expenditure type

                        IF inv_rec.inv_line_proj_exp_type IS NOT NULL
                        THEN
                            l_boolean         := NULL;
                            l_ret_msg         := NULL;
                            l_proj_exp_type   := NULL;
                            l_boolean         :=
                                is_expend_type_valid (
                                    p_expend_type     =>
                                        inv_rec.inv_line_proj_exp_type,
                                    p_inv_type_code   => l_trx_type,
                                    x_ret_msg         => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      := l_msg || ' - ' || l_ret_msg;
                            ELSE
                                l_proj_exp_type   :=
                                    inv_rec.inv_line_proj_exp_type;
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || 'Project Exp type cannot be NULL for Project';
                        END IF;

                        -- Validate expenditure Org

                        IF inv_rec.inv_line_proj_exp_org IS NOT NULL
                        THEN
                            l_boolean           := NULL;
                            l_ret_msg           := NULL;
                            l_proj_exp_org_id   := NULL;
                            l_boolean           :=
                                get_exp_org_id (p_exp_org => inv_rec.inv_line_proj_exp_org, p_org_id => l_org_id, x_exp_org_id => l_proj_exp_org_id
                                                , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      := l_msg || ' - ' || l_ret_msg;
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || 'Project Exp Org cannot be NULL for Project';
                        END IF;

                        -- Validate Expenditure Item Date

                        IF inv_rec.inv_line_proj_exp_date IS NOT NULL
                        THEN
                            l_boolean         := NULL;
                            l_ret_msg         := NULL;
                            l_proj_exp_date   := NULL;

                            BEGIN
                                SELECT TO_DATE (TO_CHAR (TO_DATE (inv_rec.inv_line_proj_exp_date, 'YYYY-MM-DD'), G_FORMAT_MASK), G_FORMAT_MASK)
                                  INTO l_proj_exp_date
                                  FROM DUAL;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_status   := G_ERRORED;
                                    l_msg      :=
                                           l_msg
                                        || ' - '
                                        || ' Invalid Project exp date format. Please enter in the format: '
                                        || G_FORMAT_MASK;
                            END;

                            l_boolean         :=
                                is_exp_item_date_valid (
                                    p_exp_date      => l_proj_exp_date,
                                    p_prj_task_id   => l_proj_task_id,
                                    x_ret_msg       => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      := l_msg || ' - ' || l_ret_msg;
                            END IF;
                        ELSE
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || 'Project Exp Date cannot be NULL for Project';
                        END IF;

                        -- Validate Project Open Date

                        IF l_inv_gl_date IS NOT NULL
                        THEN
                            l_ret_msg   := NULL;
                            l_boolean   := NULL;
                            l_boolean   :=
                                is_project_period_open (
                                    p_gl_date   => l_inv_gl_date,
                                    p_org_id    => l_org_id,
                                    x_ret_msg   => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      := l_msg || ' - ' || l_ret_msg;
                            END IF;
                        END IF;
                    END IF;

                    IF     l_status IS NULL
                       AND l_proj_id IS NOT NULL
                       AND l_track_as_asset = 'Y'
                    THEN
                        l_status   := G_ERRORED;
                        l_msg      :=
                               l_msg
                            || ' - '
                            || ' Project and Asset cannot go together in a line ';
                    ELSIF     l_status IS NULL
                          AND l_proj_id IS NOT NULL
                          AND NVL (l_track_as_asset, 'N') = 'N'
                          AND UPPER (
                                  NVL (inv_rec.inv_personal_exp_flag, 'N')) =
                              'N'
                    THEN
                        l_dist_cc     := NULL;
                        l_dist_ccid   := NULL;
                    ELSIF     l_status IS NULL
                          AND l_proj_id IS NULL
                          AND l_track_as_asset = 'Y'
                          AND UPPER (
                                  NVL (inv_rec.inv_personal_exp_flag, 'N')) =
                              'N'
                    THEN
                        l_dist_cc     := l_asset_cc;
                        l_dist_ccid   := l_asset_ccid;
                    END IF;

                    IF l_status = G_ERRORED
                    THEN
                        --        l_data_msg := ' Errored while doing line validation, header is processed ';
                        write_log (
                            ' Errored while doing line validation, header is processed ');

                        BEGIN
                            UPDATE xxdo.xxd_ap_concur_sae_stg_t stg
                               SET stg.status = G_ERRORED, stg.error_msg = SUBSTR (l_msg, 1, 4000), stg.last_updated_date = SYSDATE,
                                   stg.request_id = gn_request_id, stg.inv_pay_method = l_pay_method, --                  stg.data_msg = stg.data_msg||' - '||l_data_msg,
                                                                                                      stg.ccard_company_rec = l_card_comp_flag,
                                   stg.ccard_personal_rec = l_card_per_flag, stg.oop_rec = l_oop_flag, stg.pcard_company_rec = l_pcard_comp_flag,
                                   stg.pcard_personal_rec = l_pcard_per_flag, -- Start of Change 3.0
                                                                              stg.final_match_value_rec = l_final_match_value, stg.final_match_result_rec = l_final_match_result,
                                   stg.ext_bank_account_id = l_ext_bank_account_id, stg.ext_bank_account_num = l_ext_bank_account_num, -- End of Change 3.0
                                                                                                                                       stg.operating_unit = l_org_name,
                                   stg.ou_id = l_org_id, stg.Vendor_name = l_vendor_name, stg.vendor_num = l_vendor_num,
                                   stg.supplier_site = l_site, stg.invoice_date = l_inv_date, stg.Inv_Curr_Code = l_curr_code,
                                   stg.inv_pay_group = l_pay_group, stg.inv_gl_date = l_gl_date, stg.inv_pay_curr = l_curr_code,
                                   stg.inv_line_type = 'Item', stg.inv_line_dist_account = l_dist_cc, stg.cons_tax_rate = concur_rec.tax_rate_flag,
                                   stg.cons_tax_rate_flag = l_tax_rate_flag, stg.group_by_type = concur_rec.group_by_type, stg.group_by_type_flag = l_group_by_flag,
                                   stg.Inv_line_def_option = inv_rec.Inv_line_def_option, stg.Inv_line_def_flag = l_def_flag, stg.inv_line_def_st_date = l_def_start_date,
                                   stg.inv_line_def_ed_date = l_def_end_date, stg.inv_line_exp_date = l_proj_exp_date, stg.inv_line_track_asset = l_track_as_asset,
                                   stg.inv_line_asset_book = l_asset_book, stg.inv_line_tax_code = l_tax_code, stg.inv_line_ship_to = l_ship_loc_code,
                                   stg.inv_line_interco_exp_acct = l_interco_dist_cc, stg.invoice_type_code = l_trx_type, stg.invoice_type = l_trx_type_desc,
                                   stg.vendor_id = l_vendor_id, stg.vendor_site_id = l_site_id, stg.inv_term_id = l_trx_term_id,
                                   stg.inv_terms = l_trx_term_name, stg.inv_line_dist_ccid = l_dist_ccid, stg.inv_line_cat_id = l_asset_cat_id,
                                   stg.inv_line_asset_loc_id = l_asset_loc_id, stg.inv_line_ship_to_loc_id = l_ship_loc_id, stg.inv_line_proj_id = l_proj_id,
                                   stg.inv_line_proj_task_id = l_proj_task_id, stg.inv_line_proj_exp_org_id = l_proj_exp_org_id, stg.inv_line_proj_exp_type = NVL (l_proj_exp_type, stg.inv_line_proj_exp_type),
                                   stg.inv_line_interco_exp_acct_ccid = l_interco_dist_ccid
                             WHERE     stg.inv_emp_org_company =
                                       batch_org_rec.inv_emp_org_company
                                   AND stg.batch_id = batch_org_rec.batch_id
                                   AND stg.seq_db_num = inv_rec.seq_db_num
                                   AND stg.inv_line_geo =
                                       batch_org_rec.inv_line_geo -- Added as per Change 2.0
                                   AND stg.inv_line_cost_center =
                                       batch_org_rec.inv_line_cost_center -- Added as per Change 2.0
                                   AND NVL (stg.status, 'N') NOT IN
                                           (G_TAX_LINE, G_IGNORE);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      :=
                                       l_msg
                                    || ' - '
                                    || ' Error while updating the Staging Table: '
                                    || SUBSTR (SQLERRM, 1, 200);
                        END;
                    ELSE
                        BEGIN
                            --        l_data_msg := ' Line validation is complete ';
                            write_log (' Line validation is complete ');

                            UPDATE xxdo.xxd_ap_concur_sae_stg_t stg
                               SET stg.status = G_VALIDATED, stg.error_msg = SUBSTR (l_msg, 1, 4000), stg.last_updated_date = SYSDATE,
                                   stg.request_id = gn_request_id, stg.inv_pay_method = l_pay_method, --                  stg.data_msg = stg.data_msg||' - '||l_data_msg,
                                                                                                      stg.ccard_company_rec = l_card_comp_flag,
                                   stg.ccard_personal_rec = l_card_per_flag, stg.oop_rec = l_oop_flag, stg.pcard_company_rec = l_pcard_comp_flag,
                                   stg.pcard_personal_rec = l_pcard_per_flag, -- Start of Change 3.0
                                                                              stg.final_match_value_rec = l_final_match_value, stg.final_match_result_rec = l_final_match_result,
                                   stg.ext_bank_account_id = l_ext_bank_account_id, stg.ext_bank_account_num = l_ext_bank_account_num, -- End of Change 3.0
                                                                                                                                       stg.operating_unit = l_org_name,
                                   stg.ou_id = l_org_id, stg.Vendor_name = l_vendor_name, stg.vendor_num = l_vendor_num,
                                   stg.supplier_site = l_site, stg.invoice_date = l_inv_date, stg.Inv_Curr_Code = l_curr_code,
                                   stg.inv_pay_group = l_pay_group, stg.inv_gl_date = l_gl_date, stg.inv_pay_curr = l_curr_code,
                                   stg.inv_line_type = 'Item', stg.inv_line_dist_account = l_dist_cc, stg.cons_tax_rate = concur_rec.tax_rate_flag,
                                   stg.cons_tax_rate_flag = l_tax_rate_flag, stg.group_by_type = concur_rec.group_by_type, stg.group_by_type_flag = l_group_by_flag,
                                   stg.Inv_line_def_option = inv_rec.Inv_line_def_option, stg.Inv_line_def_flag = l_def_flag, stg.inv_line_def_st_date = l_def_start_date,
                                   stg.inv_line_def_ed_date = l_def_end_date, stg.inv_line_track_asset = l_track_as_asset, stg.inv_line_asset_book = l_asset_book,
                                   stg.inv_line_tax_code = l_tax_code, stg.inv_line_ship_to = l_ship_loc_code, stg.inv_line_interco_exp_acct = l_interco_dist_cc,
                                   stg.invoice_type_code = l_trx_type, stg.invoice_type = l_trx_type_desc, stg.vendor_id = l_vendor_id,
                                   stg.vendor_site_id = l_site_id, stg.inv_term_id = l_trx_term_id, stg.inv_terms = l_trx_term_name,
                                   stg.inv_line_dist_ccid = l_dist_ccid, stg.inv_line_cat_id = l_asset_cat_id, stg.inv_line_asset_loc_id = l_asset_loc_id,
                                   stg.inv_line_ship_to_loc_id = l_ship_loc_id, stg.inv_line_proj_id = l_proj_id, stg.inv_line_proj_task_id = l_proj_task_id,
                                   stg.inv_line_proj_exp_org_id = l_proj_exp_org_id, stg.inv_line_proj_exp_type = NVL (l_proj_exp_type, stg.inv_line_proj_exp_type), stg.inv_line_exp_date = l_proj_exp_date,
                                   stg.inv_line_interco_exp_acct_ccid = l_interco_dist_ccid
                             WHERE     stg.inv_emp_org_company =
                                       batch_org_rec.inv_emp_org_company
                                   AND stg.batch_id = batch_org_rec.batch_id
                                   AND stg.seq_db_num = inv_rec.seq_db_num
                                   AND stg.inv_line_geo =
                                       batch_org_rec.inv_line_geo -- Added as per Change 2.0
                                   AND stg.inv_line_cost_center =
                                       batch_org_rec.inv_line_cost_center -- Added as per Change 2.0
                                   AND NVL (stg.status, 'N') NOT IN
                                           (G_TAX_LINE, G_IGNORE);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_status   := G_ERRORED;
                                l_msg      :=
                                       l_msg
                                    || ' - '
                                    || ' Error while updating the Staging Table: '
                                    || SUBSTR (SQLERRM, 1, 200);
                        END;
                    END IF;
                END LOOP;

                FOR err_rec
                    IN upd_err_inv (batch_org_rec.batch_id, batch_org_rec.inv_emp_org_company, batch_org_rec.inv_line_geo -- Added as per Change 2.0
                                    , batch_org_rec.inv_line_cost_center -- Added as per Change 2.0
                                                                        )
                LOOP
                    BEGIN
                        UPDATE xxdo.xxd_ap_concur_sae_stg_t
                           SET status = 'E', process_msg = ' Invoice is rejected, please check OU, Vendor, Site, Invoice Lookup and Pay Group '
                         WHERE     1 = 1
                               AND inv_num = err_rec.inv_num
                               AND batch_id = batch_org_rec.batch_id
                               AND inv_emp_org_company =
                                   batch_org_rec.inv_emp_org_company
                               AND inv_line_geo = batch_org_rec.inv_line_geo
                               AND inv_line_cost_center =
                                   batch_org_rec.inv_line_cost_center
                               AND request_id = gn_request_id
                               AND status NOT IN (G_TAX_LINE, G_IGNORE);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || ' Error while updating Inv flag in Staging Table: '
                                || SUBSTR (SQLERRM, 1, 200);
                    END;
                END LOOP;


                --START Added as per version 1.2
                FOR get_inv_rec
                    IN get_inv_to_upd_num (batch_org_rec.batch_id,
                                           batch_org_rec.inv_emp_org_company)
                -- Start of Change for CCR0009592
                --batch_org_rec.inv_line_geo, --- Added as per Change 2.0
                --batch_org_rec.inv_line_cost_center) --- Added as per Change 2.0
                -- End of Change for CCR0009592
                LOOP
                    l_inv_count   := 1;
                    l_cm_count    := 1;

                    --END Added as per version 1.2

                    /*  --Commented as per version 1.2
                    FOR rec in update_inv_num(batch_org_rec.batch_id,batch_org_rec.inv_emp_org_company)
                    LOOP
                        l_inv_count := 1;
                        l_cm_count := 1;
                        --l_data_msg := ' CM Invoices are updated with Hyphen values ';
                    */

                    FOR rec
                        IN update_inv_num (get_inv_rec.batch_id,
                                           get_inv_rec.inv_emp_org_company,
                                           get_inv_rec.inv_num-- Start of Change for CCR0009592
                                                              --get_inv_rec.inv_line_geo,
                                                              --get_inv_rec.inv_line_cost_center
                                                              -- End of Change for CCR0009592
                                                              )
                    LOOP
                        write_log (
                            ' CM Invoices are updated with Hyphen values ');

                        IF UPPER (rec.invoice_type_code) = 'CREDIT MEMO'
                        THEN
                            BEGIN
                                UPDATE xxdo.xxd_ap_concur_sae_stg_t
                                   SET mod_inv_num = inv_num || '-CM-' || l_cm_count
                                 --                    data_msg = data_msg||' - '||l_data_msg
                                 WHERE     inv_num = rec.inv_num
                                       AND ou_id = rec.ou_id
                                       AND vendor_id = rec.vendor_id
                                       AND vendor_site_id =
                                           rec.vendor_site_id
                                       AND inv_pay_group = rec.inv_pay_group
                                       AND invoice_type_code =
                                           rec.invoice_type_code
                                       AND group_by_type_flag =
                                           rec.group_by_type_flag
                                       AND inv_emp_org_company =
                                           batch_org_rec.inv_emp_org_company
                                       -- Start of Change for CCR0009592
                                       --AND inv_line_geo = batch_org_rec.inv_line_geo --- Added as per Change 2.0
                                       --AND inv_line_cost_center = batch_org_rec.inv_line_cost_center --- Added as per Change 2.0
                                       -- End of Change for CCR0009592
                                       AND batch_id = batch_org_rec.batch_id
                                       AND request_id = gn_request_id
                                       AND status NOT IN
                                               (G_TAX_LINE, G_IGNORE);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_status   := G_ERRORED;
                                    l_msg      :=
                                           l_msg
                                        || ' - '
                                        || ' Error while updating Invoices in Staging Table: '
                                        || SUBSTR (SQLERRM, 1, 200);
                            END;

                            IF SQL%ROWCOUNT > 0
                            THEN
                                l_cm_count   := l_cm_count + 1;
                            ELSE
                                l_cm_count   := l_cm_count;
                            END IF;
                        ELSE
                            write_log (
                                ' INV Invoices are updated with Hyphen values ');

                            --  l_data_msg := ' INV Invoices are updated with Hyphen values ';

                            BEGIN
                                UPDATE xxdo.xxd_ap_concur_sae_stg_t
                                   SET mod_inv_num = inv_num || '-' || l_inv_count
                                 --                    data_msg = data_msg||' - '||l_data_msg
                                 WHERE     inv_num = rec.inv_num
                                       AND ou_id = rec.ou_id
                                       AND vendor_id = rec.vendor_id
                                       AND vendor_site_id =
                                           rec.vendor_site_id
                                       AND inv_pay_group = rec.inv_pay_group
                                       AND invoice_type_code =
                                           rec.invoice_type_code
                                       AND group_by_type_flag =
                                           rec.group_by_type_flag
                                       AND inv_emp_org_company =
                                           batch_org_rec.inv_emp_org_company
                                       -- Start of Change for CCR0009592
                                       --AND inv_line_geo = batch_org_rec.inv_line_geo --- Added as per Change 2.0
                                       --AND inv_line_cost_center = batch_org_rec.inv_line_cost_center --- Added as per Change 2.0
                                       -- End of Change for CCR0009592
                                       AND batch_id = batch_org_rec.batch_id
                                       AND request_id = gn_request_id
                                       AND status NOT IN
                                               (G_TAX_LINE, G_IGNORE);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_status   := G_ERRORED;
                                    l_msg      :=
                                           l_msg
                                        || ' - '
                                        || ' Error while updating Invoices in Staging Table: '
                                        || SUBSTR (SQLERRM, 1, 200);
                            END;

                            IF SQL%ROWCOUNT > 0
                            THEN
                                -- Start of Change as per CCR0009592
                                -- Added for 4.0
                                /*l_inv_emp_org_company:= batch_org_rec.inv_emp_org_company;
                                l_inv_line_geo:=batch_org_rec.inv_line_geo;
                                l_inv_line_cost_center:= batch_org_rec.inv_line_cost_center;*/
                                -- End or 4.0
                                -- End of Change as per CCR0009592

                                l_inv_count   := l_inv_count + 1;
                            ELSE
                                l_inv_count   := l_inv_count;
                            END IF;
                        END IF;
                    END LOOP;
                END LOOP;                           --Added as per version 1.2

                FOR upd_rec_flag
                    IN upd_inv_flag_cur (batch_org_rec.batch_id,
                                         batch_org_rec.inv_emp_org_company,
                                         batch_org_rec.inv_line_geo,
                                         batch_org_rec.inv_line_cost_center)
                LOOP
                    --        l_data_msg := ' Validations are complete. One of the lines is error, So invoice is rejected ';

                    Write_log (
                        'Validations are complete. One of the lines is error, So invoice is rejected');

                    BEGIN
                        UPDATE xxdo.xxd_ap_concur_sae_stg_t stg
                           SET stg.inv_flag_valid = 'N', stg.status = 'E', stg.process_msg = ' Invoice is rejected, as one or more lines of the lines are Error '
                         WHERE     1 = 1
                               AND stg.mod_inv_num = upd_rec_flag.mod_inv_num
                               AND stg.batch_id = batch_org_rec.batch_id
                               AND stg.inv_emp_org_company =
                                   batch_org_rec.inv_emp_org_company
                               AND stg.inv_line_geo =
                                   batch_org_rec.inv_line_geo --- Added as per Change 2.0
                               AND stg.inv_line_cost_center =
                                   batch_org_rec.inv_line_cost_center --- Added as per Change 2.0
                               AND stg.request_id = gn_request_id
                               AND status NOT IN (G_TAX_LINE, G_IGNORE);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_status   := G_ERRORED;
                            l_msg      :=
                                   l_msg
                                || ' - '
                                || ' Error while updating Inv flag in Staging Table: '
                                || SUBSTR (SQLERRM, 1, 200);
                    END;
                END LOOP;
            ELSE
                UPDATE xxdo.xxd_ap_concur_sae_stg_t stg
                   SET stg.status = G_ERRORED, stg.error_msg = SUBSTR (l_hdr_msg, 1, 4000)
                 WHERE     stg.inv_emp_org_company =
                           batch_org_rec.inv_emp_org_company
                       AND stg.batch_id = batch_org_rec.batch_id
                       AND stg.inv_line_geo = batch_org_rec.inv_line_geo --- Added as per Change 2.0
                       AND stg.inv_line_cost_center =
                           batch_org_rec.inv_line_cost_center --- Added as per Change 2.0
                       AND stg.request_id = gn_request_id;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception while Validating the staging Data : '
                || SUBSTR (SQLERRM, 1, 200);
    END validate_staging;

    PROCEDURE load_interface (x_ret_code   OUT VARCHAR2,
                              x_ret_msg    OUT VARCHAR2)
    IS
        CURSOR c_valid_hdr IS
            SELECT DISTINCT inv_num, operating_unit, vendor_name,
                            vendor_num, supplier_site, ou_id,
                            vendor_id, invoice_date, inv_amt,
                            inv_curr_code, inv_pay_method, inv_terms,
                            inv_term_id, inv_desc, vendor_site_id,
                            inv_pay_group, invoice_type_code, inv_gl_date,
                            group_by_type_flag, cons_tax_rate_flag --            created_by,last_updated_date,last_update_by,last_update_login,creation_date, -- Commented as per version 1.2
                                                                  , mod_inv_num,
                            ext_bank_account_id     -- Added as per Change 3.0
              FROM xxdo.xxd_ap_concur_sae_stg_t
             WHERE     1 = 1
                   AND status = G_VALIDATED
                   AND request_id = gn_request_id
                   AND mod_inv_num IS NOT NULL;

        CURSOR c_valid_line (p_inv_number IN VARCHAR2)
        IS
            SELECT inv_line_num, inv_line_type, inv_line_desc,
                   inv_line_dist_account, inv_line_def_option, inv_line_def_flag,
                   inv_line_def_start_date, inv_line_def_end_date, inv_line_def_st_date,
                   inv_line_def_ed_date, inv_line_track_asset, inv_line_asset_book,
                   inv_line_asset_cat, inv_line_asset_loc, inv_num,
                   mod_inv_num, fapio_number       -- Added as per version 1.2
                                            , inv_line_asst_cust,
                   inv_gl_date, inv_line_amt, inv_line_tax_code,
                   inv_line_ship_to, inv_line_proj_num, inv_line_proj_task,
                   inv_line_proj_exp_date, inv_line_proj_exp_type, inv_line_proj_exp_org,
                   inv_line_interco_exp_acct, inv_line_dist_ccid, inv_line_cat_id,
                   inv_line_asset_loc_id, inv_line_tax, inv_line_ship_to_loc_id,
                   inv_line_proj_id, inv_line_proj_task_id, inv_line_proj_exp_org_id,
                   inv_line_exp_date, inv_line_interco_exp_acct_ccid, seq_db_num
              --            creation_date,created_by,last_updated_date,last_update_by,last_update_login -- Commented as per version 1.2
              FROM xxdo.xxd_ap_concur_sae_stg_t
             WHERE     1 = 1
                   AND status = G_VALIDATED
                   AND request_id = gn_request_id
                   AND mod_inv_num = p_inv_number;

        l_valid_hdr_count      NUMBER := 0;
        l_inv_amount           NUMBER := 0;
        l_inv_header_id        NUMBER := 0;
        l_inv_line_id          NUMBER := 0;
        l_inv_count            NUMBER := 0;
        l_valid_lin_count      NUMBER := 0;
        ex_no_valid_data       EXCEPTION;
        l_count                NUMBER := 0;
        l_line_num             NUMBER := 0;
        header_seq             NUMBER;
        line_seq               NUMBER;
        l_hdr_status           VARCHAR2 (10);
        l_line_status          VARCHAR2 (10);
        --START Added as per version 1.2
        l_attribute_category   VARCHAR2 (150);
        l_inv_fapio_received   VARCHAR2 (10);
        l_fapio_number         VARCHAR2 (255);
        l_fapio_exists         NUMBER := 0;
        --END Added as per version 1.2
        lc_err_msg             VARCHAR2 (4000);
        lc_line_err_msg        VARCHAR2 (4000);
        le_webadi_exception    EXCEPTION;
        l_data_msg             VARCHAR2 (4000);
    BEGIN
        FOR r_valid_hdr IN c_valid_hdr
        LOOP
            l_data_msg     := NULL;
            l_inv_amount   := 0;
            lc_err_msg     := NULL;

            BEGIN
                SELECT SUM (NVL (inv_line_amt, 0))
                  INTO l_inv_amount
                  FROM xxdo.xxd_ap_concur_sae_stg_t
                 WHERE     mod_inv_num = r_valid_hdr.mod_inv_num
                       AND request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_inv_amount   := 0;
            END;

            BEGIN
                SELECT apps.AP_INVOICES_INTERFACE_S.NEXTVAL
                  INTO l_inv_header_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_inv_header_id   := NULL;
            END;

            --START Added as per version 1.2
            --Fetching Line Fapio Number exists to update Flag
            BEGIN
                SELECT COUNT (fapio_number)
                  INTO l_fapio_exists
                  FROM xxdo.xxd_ap_concur_sae_stg_t
                 WHERE     mod_inv_num = r_valid_hdr.mod_inv_num
                       AND request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_fapio_exists   := 0;
            END;

            IF l_fapio_exists <> 0
            THEN
                l_attribute_category   := 'Invoice Global Data Elements';
                l_inv_fapio_received   := 'Y';
            ELSE
                l_attribute_category   := NULL;
                l_inv_fapio_received   := NULL;
            END IF;

            write_log (
                   ' FAPIO Number exists check count: '
                || l_fapio_exists
                || ' and FAPIO Flag is : '
                || NVL (l_inv_fapio_received, 'NULL'));

            --END Added as per version 1.2

            BEGIN
                INSERT INTO apps.ap_invoices_interface (
                                invoice_id,
                                invoice_num,
                                vendor_id,
                                vendor_site_id,
                                invoice_amount,
                                description,
                                SOURCE,
                                org_id,
                                payment_method_code,
                                terms_id,
                                invoice_type_lookup_code,
                                gl_date,
                                invoice_date,
                                invoice_currency_code,
                                attribute_category, --Added as per version 1.2
                                attribute10,        --Added as per version 1.2
                                external_bank_account_id, -- Added as per Change 3.0
                                /* created_by,
                                 creation_date,
                                 last_updated_by,
                                 last_update_date,*/
                                pay_group_lookup_code)
                         VALUES (
                                    l_inv_header_id,
                                    SUBSTR (r_valid_hdr.mod_inv_num, 1, 50),
                                    r_valid_hdr.vendor_id,
                                    r_valid_hdr.vendor_site_id,
                                    l_inv_amount,
                                    SUBSTRB (r_valid_hdr.inv_desc, 1, 240), -- Added SUBSTRB instead of SUBSTR
                                    G_INV_SOURCE,             --'COMMISSIONS',
                                    r_valid_hdr.ou_id,
                                    SUBSTR (r_valid_hdr.inv_pay_method,
                                            1,
                                            30),
                                    r_valid_hdr.inv_term_id,
                                    SUBSTR (r_valid_hdr.invoice_type_code,
                                            1,
                                            25),                 --'STANDARD',
                                    r_valid_hdr.inv_gl_date,
                                    r_valid_hdr.invoice_date,
                                    SUBSTR (r_valid_hdr.inv_curr_code, 1, 15),
                                    SUBSTR (l_attribute_category, 1, 150), --Added as per version 1.2
                                    SUBSTR (l_inv_fapio_received, 1, 150), --Added as per version 1.2
                                    r_valid_hdr.ext_bank_account_id, -- Added as per Change 3.0
                                    /* r_valid_hdr.created_by,       --Commented, system will insert WHO values
                                     r_valid_hdr.creation_date,
                                     r_valid_hdr.last_update_by,
                                     r_valid_hdr.last_updated_date,*/
                                    SUBSTR (r_valid_hdr.inv_pay_group, 1, 25));

                --                     l_data_msg := ' Inserted into headers Interface table ';

                write_log (' Inserted into headers Interface table ');

                UPDATE XXDO.XXD_AP_CONCUR_SAE_STG_T
                   SET header_interfaced = 'Y', --                            data_msg = data_msg||' - '||l_data_msg,
                                                temp_inv_id = l_inv_header_id
                 WHERE     inv_num = r_valid_hdr.inv_num
                       AND mod_inv_num = r_valid_hdr.mod_inv_num
                       AND request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_hdr_status   := G_ERRORED;
                    lc_err_msg     :=
                           'Exception in AP_INVOICES_INT insertion : '
                        || SQLERRM;
            --l_status := G_ERRORED;
            END;

            --COMMIT;

            IF l_hdr_status IS NULL
            THEN
                l_line_num   := 0;

                FOR r_valid_line IN c_valid_line (r_valid_hdr.mod_inv_num)
                LOOP
                    lc_line_err_msg   := NULL;
                    l_data_msg        := NULL;

                    BEGIN
                        SELECT apps.AP_INVOICE_LINES_INTERFACE_S.NEXTVAL
                          INTO l_inv_line_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_inv_line_id   := NULL;
                    END;

                    l_line_num        := l_line_num + 1;

                    BEGIN
                        INSERT INTO apps.ap_invoice_lines_interface (
                                        invoice_id,
                                        invoice_line_id,
                                        line_number,
                                        line_type_lookup_code,
                                        amount,
                                        accounting_date,
                                        dist_code_combination_id,
                                        ship_to_location_id,
                                        description,
                                        /*created_by,              --Commented, system will insert WHO values
                                        creation_date,
                                        last_updated_by,
                                        last_update_date,*/
                                        attribute_category,
                                        attribute2,
                                        attribute13, --Added as per version 1.2
                                        asset_book_type_code,
                                        asset_category_id,
                                        assets_tracking_flag,
                                        deferred_acctg_flag,
                                        def_acctg_start_date,
                                        def_acctg_end_date,
                                        --calc_tax_during_import_flag,
                                        tax_classification_code,
                                        project_id,
                                        task_id,
                                        expenditure_organization_id,
                                        expenditure_item_date,
                                        expenditure_type)
                                 VALUES (
                                            l_inv_header_id,
                                            l_inv_line_id,
                                            l_line_num,
                                            'ITEM',    --line type lookup code
                                            r_valid_line.inv_line_amt,
                                            r_valid_hdr.inv_gl_date,
                                            r_valid_line.inv_line_dist_ccid,
                                            r_valid_line.inv_line_ship_to_loc_id,
                                            SUBSTRB (
                                                r_valid_line.inv_line_desc,
                                                1,
                                                240), -- Added SUBSTRB instead of SUBSTR
                                            /*r_valid_line.created_by,                   --Commented, system will insert WHO values
                                            r_valid_line.creation_date,
                                            r_valid_line.last_update_by,
                                            r_valid_line.last_updated_date,*/
                                            'Invoice Lines Data Elements',
                                            r_valid_line.inv_line_interco_exp_acct_ccid,
                                            r_valid_line.fapio_number, --Added as per version 1.2
                                            SUBSTR (
                                                r_valid_line.inv_line_asset_book,
                                                1,
                                                15),
                                            r_valid_line.inv_line_cat_id,
                                            r_valid_line.inv_line_track_asset,
                                            r_valid_line.inv_line_def_flag,
                                            r_valid_line.inv_line_def_st_date,
                                            r_valid_line.inv_line_def_ed_date,
                                            --               DECODE(r_valid_line.inv_line_tax_code,NULL,'N','Y'),
                                            --               r_valid_line.inv_line_def_option,
                                            --               r_valid_line.inv_line_def_start_date,
                                            --               r_valid_line.inv_line_def_end_date,
                                            SUBSTR (
                                                r_valid_line.inv_line_tax_code,
                                                1,
                                                30),
                                            r_valid_line.inv_line_proj_id,
                                            r_valid_line.inv_line_proj_task_id,
                                            r_valid_line.INV_LINE_PROJ_EXP_org_id,
                                            r_valid_line.inv_line_exp_date,
                                            SUBSTR (
                                                r_valid_line.inv_line_proj_exp_type,
                                                1,
                                                30));

                        --               l_data_msg := ' Inserted into line Interface table ';

                        write_log (' Inserted into line Interface table ');

                        UPDATE xxdo.xxd_ap_concur_sae_stg_t
                           SET line_interfaced = 'Y', temp_inv_line_id = l_inv_line_id, inv_line_num = l_line_num
                         --                      data_msg    = data_msg||' - '||l_data_msg
                         WHERE     inv_num = r_valid_line.inv_num
                               AND request_id = gn_request_id
                               AND mod_inv_num = r_valid_line.mod_inv_num
                               AND seq_db_num = r_valid_line.seq_db_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_line_status   := G_ERRORED;
                            lc_err_msg      :=
                                   'Exception in AP_INVOICES_LINES_INT insertion : '
                                || SQLERRM;
                    END;
                END LOOP;
            END IF;

            IF l_hdr_status IS NULL AND l_line_status IS NULL
            THEN
                write_log (
                    ' Inserted into Header and lines Interface table ');

                --          l_data_msg := ' Inserted into Header and lines Interface table ';

                UPDATE xxdo.xxd_ap_concur_sae_stg_t
                   SET status   = G_INTERFACED
                 --                  data_msg = data_msg||' - '||l_data_msg
                 WHERE     inv_num = r_valid_hdr.inv_num
                       AND request_id = gn_request_id
                       AND mod_inv_num = r_valid_hdr.mod_inv_num
                       AND status = G_VALIDATED
                       AND line_interfaced = 'Y'
                       AND header_interfaced = 'Y';
            ELSE
                write_log (
                    ' Error occurred while Inserting data into Header and lines Interface ');

                --         l_data_msg := ' Error occurred while Inserting data into Header and lines Interface ';

                UPDATE xxdo.xxd_ap_concur_sae_stg_t
                   SET status = G_ERRORED, error_msg = 'Interface Error'
                 --                  data_msg = data_msg||' - '||l_data_msg
                 WHERE     inv_num = r_valid_hdr.inv_num
                       AND request_id = gn_request_id
                       AND status = G_VALIDATED
                       AND mod_inv_num = r_valid_hdr.mod_inv_num;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception occured while loading data into Interface : '
                || SUBSTR (SQLERRM, 1, 200);
    END load_interface;

    PROCEDURE create_invoices (x_ret_code   OUT VARCHAR2,
                               x_ret_msg    OUT VARCHAR2)
    IS
        l_request_id       NUMBER;
        l_req_boolean      BOOLEAN;
        l_req_phase        VARCHAR2 (30);
        l_req_status       VARCHAR2 (30);
        l_req_dev_phase    VARCHAR2 (30);
        l_req_dev_status   VARCHAR2 (30);
        l_req_message      VARCHAR2 (4000);
        l_invoice_count    NUMBER := 0;
        ex_no_invoices     EXCEPTION;

        CURSOR c_inv IS
            SELECT DISTINCT org_id
              FROM apps.ap_invoices_interface
             WHERE     NVL (status, 'XXX') NOT IN ('PROCESSED', 'REJECTED')
                   AND source = G_INV_SOURCE;
    -- Order By  org_id;

    BEGIN
        FOR rec IN c_inv
        LOOP
            apps.mo_global.set_policy_context ('S', rec.org_id);
            apps.mo_global.init ('SQLAP');

            l_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'SQLAP',
                    program       => 'APXIIMPT',
                    description   => '',    --'Payables Open Interface Import'
                    start_time    => SYSDATE,                         --,NULL,
                    sub_request   => FALSE,
                    argument1     => rec.org_id,                    --2 org_id
                    --             argument1        => '', --2 org_id
                    argument2     => G_INV_SOURCE, --'COMMISSIONS',  --p_source
                    argument3     => '',
                    argument4     => 'N/A',
                    argument5     => '',
                    argument6     => '',
                    argument7     =>
                        TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'),
                    argument8     => 'N',                      --'N', -- purge
                    argument9     => 'N',               --'N', -- trace_switch
                    argument10    => 'N',               --'N', -- debug_switch
                    argument11    => 'N',           --'N', -- summarize report
                    argument12    => 1000,        --1000, -- commit_batch_size
                    argument13    => apps.fnd_global.user_id,        --'1037',
                    argument14    => apps.fnd_global.login_id   --'1347386776'
                                                             );

            IF l_request_id <> 0
            THEN
                COMMIT;
                NULL;
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'AP Request ID= ' || l_request_id);
            ELSIF l_request_id = 0
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Request Not Submitted due to "'
                    || apps.fnd_message.get
                    || '".');
            END IF;

            --===IF successful RETURN ar customer trx id as OUT parameter;
            IF l_request_id > 0
            THEN
                LOOP
                    l_req_boolean   :=
                        apps.fnd_concurrent.wait_for_request (
                            l_request_id,
                            15,
                            0,
                            l_req_phase,
                            l_req_status,
                            l_req_dev_phase,
                            l_req_dev_status,
                            l_req_message);
                    EXIT WHEN    UPPER (l_req_phase) = 'COMPLETED'
                              OR UPPER (l_req_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                IF     UPPER (l_req_phase) = 'COMPLETED'
                   AND UPPER (l_req_status) = 'ERROR'
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'The Payables Open Import prog completed in error. See log for request id:'
                        || l_request_id);
                    apps.fnd_file.put_line (apps.fnd_file.LOG, SQLERRM);
                    x_ret_code   := '2';
                    x_ret_msg    :=
                           'The Payables Open Import request failed.Review log for Oracle request id '
                        || l_request_id;
                ELSIF     UPPER (l_req_phase) = 'COMPLETED'
                      AND UPPER (l_req_status) = 'NORMAL'
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'The Payables Open Import request id: '
                        || l_request_id);
                ELSE
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'The Payables Open Import request failed.Review log for Oracle request id '
                        || l_request_id);
                    apps.fnd_file.put_line (apps.fnd_file.LOG, SQLERRM);
                    x_ret_code   := '2';
                    x_ret_msg    :=
                           'The Payables Open Import request failed.Review log for Oracle request id '
                        || l_request_id;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN ex_no_invoices
        THEN
            x_ret_msg    :=
                   x_ret_msg
                || ' No invoice data available for invoice creation.';
            x_ret_code   := '2';

            apps.fnd_file.put_line (apps.fnd_file.LOG, x_ret_msg);
        WHEN OTHERS
        THEN
            x_ret_msg    :=
                x_ret_msg || ' Error in create_invoices:' || SQLERRM;
            x_ret_code   := '2';

            apps.fnd_file.put_line (apps.fnd_file.LOG, x_ret_msg);
    END create_invoices;

    PROCEDURE clear_int_tables
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        --Delete Invoice Line rejections
        DELETE apps.ap_interface_rejections apr
         WHERE     parent_table = 'AP_INVOICE_LINES_INTERFACE'
               AND EXISTS
                       (SELECT 1
                          FROM apps.ap_invoice_lines_interface apl, apps.ap_invoices_interface api
                         WHERE     apl.invoice_line_id = apr.parent_id
                               AND api.invoice_id = apl.invoice_id
                               AND api.status = 'REJECTED'
                               AND api.source = G_INV_SOURCE);

        --Delete Invoice rejections
        DELETE apps.ap_interface_rejections apr
         WHERE     parent_table = 'AP_INVOICES_INTERFACE'
               AND EXISTS
                       (SELECT 1
                          FROM apps.ap_invoices_interface api
                         WHERE     api.invoice_id = apr.parent_id
                               AND api.status = 'REJECTED'
                               AND api.source = G_INV_SOURCE);

        --Delete Invoice lines interface
        DELETE apps.ap_invoice_lines_interface lint
         WHERE EXISTS
                   (SELECT 1
                      FROM apps.ap_invoices_interface api
                     WHERE     api.invoice_id = lint.invoice_id
                           AND API.status IN ('REJECTED')
                           AND api.source = G_INV_SOURCE);

        --Delete Invoices interface
        DELETE apps.ap_invoices_interface api
         WHERE     1 = 1
               AND API.status IN ('REJECTED')
               AND api.source = G_INV_SOURCE;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END clear_int_tables;

    FUNCTION is_invoice_created (p_org_id           IN     NUMBER,
                                 p_invoice_num      IN     VARCHAR2,
                                 p_vendor_id        IN     NUMBER,
                                 p_vendor_site_id   IN     NUMBER,
                                 x_invoice_id          OUT NUMBER)
        RETURN BOOLEAN
    IS
        l_invoice_id   NUMBER := 0;
    BEGIN
        SELECT invoice_id
          INTO l_invoice_id
          FROM apps.ap_invoices_all
         WHERE     1 = 1
               AND invoice_num = p_invoice_num
               AND org_id = p_org_id
               AND vendor_id = p_vendor_id
               AND vendor_site_id = p_vendor_site_id;

        x_invoice_id   := l_invoice_id;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_invoice_id   := NULL;
            RETURN FALSE;
    END is_invoice_created;

    FUNCTION is_line_created (p_invoice_id    IN NUMBER,
                              p_line_number   IN NUMBER)
        RETURN BOOLEAN
    IS
        l_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM apps.ap_invoice_lines_all
         WHERE invoice_id = p_invoice_id AND line_number = p_line_number;

        IF l_count = 1
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END is_line_created;

    PROCEDURE check_data (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        CURSOR c_hdr IS
            SELECT *
              FROM xxdo.xxd_ap_concur_sae_stg_t
             WHERE 1 = 1 AND Status = G_INTERFACED;

        CURSOR c_line (p_temp_inv_id IN NUMBER)
        IS
            SELECT *
              FROM xxdo.xxd_ap_concur_sae_stg_t
             WHERE 1 = 1 AND temp_inv_id = p_temp_inv_id;

        CURSOR c_hdr_rej (p_header_id IN NUMBER)
        IS
            SELECT reject_lookup_code, get_error_desc (reject_lookup_code) error_message
              FROM apps.ap_interface_rejections
             WHERE     parent_id = p_header_id
                   AND parent_table = 'AP_INVOICES_INTERFACE';

        CURSOR c_line_rej (p_line_id IN NUMBER)
        IS
            SELECT reject_lookup_code, get_error_desc (reject_lookup_code) error_message
              FROM apps.ap_interface_rejections
             WHERE     parent_id = p_line_id
                   AND parent_table = 'AP_INVOICE_LINES_INTERFACE';


        l_hdr_count      NUMBER := 0;
        l_line_count     NUMBER := 0;
        l_invoice_id     NUMBER := 0;
        l_hdr_boolean    BOOLEAN := NULL;
        l_line_boolean   BOOLEAN := NULL;
        l_hdr_error      VARCHAR2 (2000);
        l_line_error     VARCHAR2 (32000);
        l_status         VARCHAR2 (30);
        l_data_msg       VARCHAR2 (4000);
    BEGIN
        FOR r_hdr IN c_hdr
        LOOP
            l_invoice_id    := NULL;
            l_status        := NULL;

            l_hdr_boolean   := NULL;
            l_data_msg      := NULL;

            l_hdr_boolean   :=
                is_invoice_created (
                    p_org_id           => r_hdr.ou_id,
                    p_invoice_num      => r_hdr.mod_inv_num,
                    p_vendor_id        => r_hdr.vendor_id,
                    p_vendor_site_id   => r_hdr.vendor_site_id,
                    x_invoice_id       => l_invoice_id);

            IF l_hdr_boolean = TRUE
            THEN
                --            l_data_msg := ' Import is done and Invoice is created : '||r_hdr.mod_inv_num;

                write_log (
                    ' Import is done and Invoice is created : ' || r_hdr.mod_inv_num);

                UPDATE xxdo.xxd_ap_concur_sae_stg_t
                   SET inv_created = 'Y', status = G_processed
                 --                    data_msg = data_msg||' - '||l_data_msg
                 WHERE temp_inv_id = r_hdr.temp_inv_id;

                FOR r_line IN c_line (r_hdr.temp_inv_id)
                LOOP
                    l_line_boolean   := NULL;
                    l_data_msg       := NULL;
                    l_line_boolean   :=
                        is_line_created (
                            p_invoice_id    => l_invoice_id,
                            p_line_number   => r_line.inv_line_num);

                    IF l_line_boolean = TRUE
                    THEN
                        --                l_data_msg := ' Import is done and lines are created : '||r_hdr.temp_inv_line_id ;

                        --Changes as per version 1.2
                        write_log (
                               ' Import is done and lines are created with Line_Id : '
                            || r_hdr.temp_inv_line_id
                            || ' and Line_Num : '
                            || r_line.inv_line_num);

                        UPDATE xxdo.xxd_ap_concur_sae_stg_t
                           SET line_created = 'Y', status = G_processed, invoice_id = l_invoice_id
                         --                      data_msg = data_msg||' - '||l_data_msg
                         WHERE temp_inv_line_id = r_hdr.temp_inv_line_id;
                    ELSE
                        l_line_error   := 'Interface Line Error';

                        write_log ('Interface Line Error ');

                        FOR r_line_rej
                            IN c_line_rej (r_line.temp_inv_line_id)
                        LOOP
                            l_line_error   :=
                                   l_line_error
                                || '. '
                                || r_line_rej.error_message;
                        END LOOP;

                        --Changes as per version 1.2
                        write_log (
                               ' Import is done but there are errors after import for Line_Id : '
                            || r_line.temp_inv_line_id
                            || ' and Line_Num : '
                            || r_line.inv_line_num);


                        --                 l_data_msg := ' Import is done but there are errors after import for  : '||r_line.temp_inv_line_id ;

                        UPDATE xxdo.xxd_ap_concur_sae_stg_t
                           SET status = G_ERRORED, error_msg = SUBSTR (error_msg || l_line_error, 1, 4000)
                         --                       ,data_msg       = data_msg||' - '||l_data_msg
                         WHERE temp_inv_line_id = r_line.temp_inv_line_id;
                    END IF;
                END LOOP;
            ELSE
                --            l_hdr_error := ' Interface Header Error';
                FOR r_hdr_rej IN c_hdr_rej (r_hdr.temp_inv_id)
                LOOP
                    l_hdr_error   :=
                        l_hdr_error || '. ' || r_hdr_rej.error_message;
                END LOOP;

                write_log (
                       ' Import is done but there are errors after import for Header id : '
                    || r_hdr.temp_inv_id);

                --            l_data_msg := ' Import has been done but there are errors after import for  : '||r_hdr.temp_inv_id;
                UPDATE xxdo.xxd_ap_concur_sae_stg_t
                   SET status = G_ERRORED, error_msg = SUBSTR (error_msg || l_hdr_error, 1, 4000)
                 --                 ,data_msg    = data_msg||' - '||l_data_msg
                 WHERE temp_inv_id = r_hdr.temp_inv_id;
            END IF;
        END LOOP;
    -- COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg    := x_ret_msg || ' Error in check_data: ' || SQLERRM;
            x_ret_code   := '2';
    END check_data;

    PROCEDURE Update_sae_data (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_org IN VARCHAR2
                               , p_exp IN VARCHAR2)
    IS
        --      CURSOR update_sae_data
        --      IS
        --         SELECT *
        --           FROM xxdo.xxd_ap_concur_sae_t
        --          WHERE     inv_emp_org_company = NVL (p_org, inv_emp_org_company)
        --                AND inv_num = NVL (p_exp, inv_num)
        --                AND ap_invoice_id IS NULL
        --                AND NVL (Status, 'E') = 'E';        -- Added as per change 2.0

        --      AND request_id = gn_request_id;

        CURSOR update_sae_data IS
              -- Commented and Added as per CCR0009592

              /*SELECT *
                FROM xxdo.xxd_ap_concur_sae_stg_t
               WHERE     inv_emp_org_company = NVL (p_org, inv_emp_org_company)
                     AND inv_num = NVL (p_exp, inv_num)
                     --AND ap_invoice_id IS NULL
                     AND request_id = gn_request_id;*/

              SELECT file_name
                FROM xxdo.xxd_ap_concur_sae_stg_t
               WHERE     inv_emp_org_company = NVL (p_org, inv_emp_org_company)
                     AND inv_num = NVL (p_exp, inv_num)
                     --AND ap_invoice_id IS NULL
                     AND request_id = gn_request_id
            GROUP BY file_name;
    -- End of Change for CCR0009592


    BEGIN
        FOR upd IN update_sae_data
        LOOP
            UPDATE xxdo.xxd_ap_concur_sae_t sae
               SET (sae.ap_invoice_id, sae.ap_invoice_line_num, sae.ap_invoice_num, sae.status, sae.error_msg, sae.creation_date, sae.created_by, sae.last_update_date, sae.last_updated_by, sae.last_update_login, sae.card_company_record, sae.card_personal_record, sae.opp_record, sae.pcard_company_rec, sae.pcard_personal_rec
                    , sae.request_id)   =
                       (SELECT stg1.invoice_id, stg1.inv_line_num, stg1.mod_inv_num,
                               stg1.status, NVL (stg1.error_msg, stg1.process_msg), stg1.creation_date,
                               stg1.created_by, stg1.last_updated_date, stg1.last_update_by,
                               stg1.last_update_login, stg1.ccard_company_rec, stg1.ccard_personal_rec,
                               stg1.oop_rec, stg1.pcard_company_rec, stg1.pcard_personal_rec,
                               stg1.request_id
                          FROM xxdo.xxd_ap_concur_sae_stg_t stg1
                         WHERE sae.seq_db_num = stg1.seq_db_num)
             WHERE 1 = 1 --AND sae.seq_db_num = upd.seq_db_num --- Commented as per CCR0009592
                         AND sae.file_name = upd.file_name;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception while updating the SAE Data : '
                || SUBSTR (SQLERRM, 1, 200);
    END Update_sae_data;

    PROCEDURE display_data (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_request_id IN NUMBER)
    IS
        CURSOR data_cur (p_request_id IN NUMBER)
        IS
              SELECT stg.file_name, stg.inv_emp_org_company, stg.operating_unit,
                     stg.inv_num, stg.mod_inv_num, stg.invoice_type,
                     stg.status
                FROM xxdo.xxd_ap_concur_sae_t sae, xxdo.xxd_ap_concur_sae_stg_t stg
               WHERE     1 = 1
                     AND sae.request_id = stg.request_id
                     AND sae.file_name = stg.file_name
                     AND sae.seq_db_num = stg.seq_db_num
                     AND stg.request_id = p_request_id
                     AND stg.status NOT IN (G_TAX_LINE, G_IGNORE)
            GROUP BY stg.file_name, stg.inv_emp_org_company, stg.operating_unit,
                     stg.inv_num, stg.mod_inv_num, stg.invoice_type,
                     stg.status
            ORDER BY stg.file_name, stg.inv_emp_org_company, stg.inv_num,
                     stg.mod_inv_num, stg.invoice_type;

        l_total   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT COUNT (*)
              INTO l_total
              FROM xxdo.xxd_ap_concur_sae_t
             WHERE request_id = p_request_id;

            apps.fnd_file.put_line (
                fnd_file.output,
                   ' Total number of records considered in this request = '
                || l_total
                || ' and below are Distinct records ');
            apps.fnd_file.put_line (fnd_file.output, NULL);
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    fnd_file.LOG,
                       ' Exception occurred while fetching records from SAE table = '
                    || SUBSTR (SQLERRM, 1, 200));
        END;

        apps.fnd_file.put_line (
            fnd_file.output,
               RPAD ('File Name', 50)
            || CHR (9)
            || RPAD ('Expense Report ID', 40)
            || CHR (9)
            || RPAD ('Invoice Type', 20)
            || CHR (9)
            || RPAD ('Status', 6)
            || CHR (9)
            || RPAD ('Operating Unit', 45)
            || CHR (9)
            || RPAD ('Actual Invoice Number', 40));

        FOR dis_data IN data_cur (p_request_id)
        LOOP
            NULL;
            apps.fnd_file.put_line (fnd_file.output, NULL);
            apps.fnd_file.put_line (
                fnd_file.output,
                   RPAD (dis_data.file_name, 50)
                || CHR (9)
                || RPAD (dis_data.inv_num, 40)
                || CHR (9)
                || RPAD (dis_data.invoice_type, 20)
                || CHR (9)
                || RPAD (dis_data.status, 6)
                || CHR (9)
                || RPAD (dis_data.operating_unit, 45)
                || CHR (9)
                || RPAD (dis_data.mod_inv_num, 40));
        END LOOP;

        apps.fnd_file.put_line (fnd_file.output, NULL);
        apps.fnd_file.put_line (
            fnd_file.output,
               'Refer to Staging table for Error Messages for any Errored records with Request id = '
            || p_request_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception while updating the SAE Data : '
                || SUBSTR (SQLERRM, 1, 200);
    END display_data;
END XXD_AP_CONCUR_INBOUND_PKG;
/
