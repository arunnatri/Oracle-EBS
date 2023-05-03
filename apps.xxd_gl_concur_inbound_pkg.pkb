--
-- XXD_GL_CONCUR_INBOUND_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_CONCUR_INBOUND_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  GL Accruals Concur Inbound process                               *
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
      * 1.2     13-MAY-2019  Srinath Siricilla     CCR0007989                          *
      * 1.3     15-JUL-2019  Srinath Siricilla     CCR0008079                          *
      * 1.4     19-NOV-2019  Srinath Siricilla     CCR0008320                          *
      * 2.0     24-DEC-2021  Srinath Siricilla     CCR0009228
      **********************************************************************************/
    g_interfaced    VARCHAR2 (1) := 'I';
    g_errored       VARCHAR2 (1) := 'E';
    g_validated     VARCHAR2 (1) := 'V';
    g_processed     VARCHAR2 (1) := 'P';
    g_created       VARCHAR2 (1) := 'C';
    g_new           VARCHAR2 (1) := 'N';
    g_other         VARCHAR2 (1) := 'O';
    gn_user_id      NUMBER := fnd_global.user_id;
    gn_login_id     NUMBER := fnd_global.login_id;
    gn_request_id   NUMBER := fnd_global.conc_request_id;
    gd_sysdate      DATE := SYSDATE;
    G_desc          VARCHAR2 (100) := 'AL - Concur Accrual'; -- Added for Change 1.2
    G_vt_desc       VARCHAR2 (100) := 'AL - Reversal Concur Accrual'; -- -- Added for Change 1.2

    -- Start of Change for CCR0009228

    PROCEDURE purge_prc (pn_purge_days IN NUMBER)
    IS
        CURSOR purge_cur_sae IS
            SELECT DISTINCT stg.request_id
              FROM xxdo.xxd_gl_concur_acc_t stg
             WHERE 1 = 1 AND stg.creation_date < (SYSDATE - pn_purge_days);

        CURSOR purge_cur_sae_stg IS
            SELECT DISTINCT stg.request_id
              FROM xxdo.xxd_gl_concur_acc_stg_t stg
             WHERE 1 = 1 AND stg.creation_date < (SYSDATE - pn_purge_days);
    BEGIN
        FOR purge_rec IN purge_cur_sae
        LOOP
            DELETE FROM xxdo.xxd_gl_concur_acc_t
                  WHERE 1 = 1 AND request_id = purge_rec.request_id;

            COMMIT;
        END LOOP;

        FOR purge_stg_rec IN purge_cur_sae_stg
        LOOP
            DELETE FROM xxdo.xxd_gl_concur_acc_stg_t
                  WHERE 1 = 1 AND request_id = purge_stg_rec.request_id;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in Purge Procedure -' || SQLERRM);
    END purge_prc;

    -- End of Change for CCR0009228

    PROCEDURE INSERT_STAGING (x_ret_code        OUT NOCOPY VARCHAR2,
                              x_ret_msg         OUT NOCOPY VARCHAR2,
                              p_source       IN            VARCHAR2,
                              p_category     IN            VARCHAR2,
                              --p_gl_date     IN   VARCHAR2,
                              p_bal_seg      IN            VARCHAR2,
                              p_as_of_date   IN            VARCHAR2,
                              p_report_id    IN            VARCHAR2,
                              p_currency     IN            VARCHAR2)
    IS
        CURSOR acc_gl_cur IS
            SELECT *
              FROM xxdo.xxd_gl_concur_acc_t
             WHERE     1 = 1
                   AND NVL (status, 'N') = 'N'
                   AND NVL (bal_seg, 'A') =
                       NVL (p_bal_seg, NVL (bal_seg, 'A'))
                   AND TO_DATE (file_processed_date, 'RRRR-MM-DD') <=
                       fnd_date.canonical_to_date (p_as_of_date)
                   AND report_id = NVL (p_report_id, report_id)
                   AND currency = NVL (p_currency, currency);

        gl_rec_cur   acc_gl_cur%ROWTYPE;
    BEGIN
        FOR gl_rec IN acc_gl_cur
        LOOP
            --xxv_debug_test_prc ('Inserting into Table');
            BEGIN
                INSERT INTO xxdo.xxd_gl_concur_acc_stg_t (
                                seq_db_num,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                last_update_login,
                                file_name,
                                file_processed_date,
                                status,
                                journal_batch_id,
                                journal_header_id,
                                journal_line_num,
                                request_id,
                                emp_first_name,
                                emp_last_name,
                                bal_seg,
                                interco_bal_seg,
                                report_id,
                                company_seg,
                                brand_seg,
                                geo_seg,
                                channel_seg,
                                cost_center_seg,
                                account_code_seg,
                                intercompany_seg,
                                future_use_seg,
                                vendor_name,
                                vendor_desc,
                                description,
                                amount,
                                currency,
                                paid_flag,
                                je_source_name,
                                je_category_name,
                                line_desc)
                         VALUES (
                                    gl_rec.seq_db_num,
                                    gl_rec.creation_date,
                                    gl_rec.created_by,
                                    gl_rec.last_update_date,
                                    gl_rec.last_updated_by,
                                    gl_rec.last_update_login,
                                    gl_rec.file_name,
                                    gl_rec.file_processed_date,
                                    gl_rec.status,
                                    NULL,
                                    NULL,
                                    NULL,
                                    gn_request_id,
                                    gl_rec.emp_first_name,
                                    gl_rec.emp_last_name,
                                    gl_rec.bal_seg,
                                    gl_rec.interco_bal_seg,
                                    gl_rec.report_id,
                                    gl_rec.company_seg,
                                    gl_rec.brand_seg,
                                    gl_rec.geo_seg,
                                    gl_rec.channel_seg,
                                    gl_rec.cost_center_seg,
                                    gl_rec.account_code_seg,
                                    gl_rec.intercompany_seg,
                                    gl_rec.future_use_seg,
                                    gl_rec.vendor_name,
                                    gl_rec.vendor_desc --,gl_rec.report_id||'-'||gl_rec.emp_first_name||'-'||gl_rec.description
                                                      --,substr(gl_rec.report_id||'-'||gl_rec.emp_first_name||'-'||gl_rec.emp_last_name||'-'||gl_rec.description,1,240) -- Added for Change 1.2
                                                      ,
                                    SUBSTR (
                                           gl_rec.account_code_seg
                                        || '-'
                                        || gl_rec.report_id
                                        || '-'
                                        || gl_rec.emp_first_name
                                        || '-'
                                        || gl_rec.emp_last_name
                                        || '-'
                                        || gl_rec.vendor_name
                                        || '-'
                                        || gl_rec.description,
                                        1,
                                        240)        -- -- Added for Change 1.3
                                            ,
                                    --gl_rec.amount,
                                    ROUND (gl_rec.amount, 2), --- Added as per CCR0009228
                                    gl_rec.currency,
                                    TRIM (gl_rec.paid_flag),
                                    p_source,
                                    p_category,
                                    SUBSTR (gl_rec.description, 1, 240) -- Added for Change 1.2
                                                                       );
            EXCEPTION
                WHEN OTHERS
                THEN
                    --        xxv_debug_test_prc('Exception Occurred : '||SQLERRM);
                    x_ret_code   := '2';
                    x_ret_msg    :=
                           'Exception while Inserting the Data into Staging: '
                        || SUBSTR (SQLERRM, 1, 200);

                    BEGIN
                        UPDATE xxdo.xxd_gl_concur_acc_t stg
                           SET stg.status = g_errored, stg.error_msg = x_ret_msg, stg.creation_date = gd_sysdate,
                               stg.created_by = gn_user_id, stg.last_updated_by = gn_user_id, stg.last_update_login = gn_login_id,
                               stg.request_id = gn_request_id
                         WHERE seq_db_num = gl_rec.seq_db_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            x_ret_code   := '2';
                            x_ret_msg    :=
                                   'Exception while updating stg table with Insertion Error : '
                                || SUBSTR (SQLERRM, 1, 200);
                    END;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception while Inserting the staging Data : '
                || SUBSTR (SQLERRM, 1, 200);
    END INSERT_STAGING;

    PROCEDURE update_staging (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2, p_bal_seg IN VARCHAR2, p_as_of_date IN VARCHAR2
                              , p_report_id IN VARCHAR2, p_currency IN VARCHAR2, p_reprocess IN VARCHAR2)
    IS
        CURSOR conc_acc_lin_upd_cur IS
            SELECT *
              FROM xxdo.xxd_gl_concur_acc_stg_t
             WHERE     1 = 1
                   AND NVL (bal_seg, 'A') =
                       NVL (p_bal_seg, NVL (bal_seg, 'A'))
                   AND TO_DATE (file_processed_date, 'RRRR-MM-DD') <=
                       fnd_date.canonical_to_date (p_as_of_date)
                   AND report_id = NVL (p_report_id, report_id)
                   AND currency = NVL (p_currency, currency)
                   AND NVL (status, 'N') =
                       DECODE (p_reprocess, 'Y', 'E', 'N');
    BEGIN
        FOR i IN conc_acc_lin_upd_cur
        LOOP
            UPDATE xxdo.xxd_gl_concur_acc_stg_t
               SET Status = 'N', request_id = gn_request_id
             WHERE seq_db_num = i.seq_db_num;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                SUBSTR (
                       'Exception while updating the staging table and Error is : '
                    || SQLERRM,
                    1,
                    2000);
    END update_staging;

    FUNCTION is_gl_date_valid (p_gl_date   IN     DATE,
                               p_org_id    IN     NUMBER,
                               x_ret_msg      OUT VARCHAR2)
        RETURN DATE
    IS
        l_valid_date   DATE;
    BEGIN
        SELECT p_gl_date
          INTO l_valid_date
          FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
         WHERE     gps.application_id = 101                            --SQLAP
               AND gps.ledger_id = hou.set_of_books_id
               AND hou.organization_id = p_org_id
               AND gps.start_date <= p_gl_date
               AND gps.end_date >= p_gl_date
               AND gps.closing_status = 'O';

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

    PROCEDURE validate_staging (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2, p_gl_date IN DATE, p_reprocess IN VARCHAR2, p_bal_seg IN VARCHAR2, --                            p_as_of_date   IN   DATE,
                                                                                                                                                                                                  p_as_of_date IN VARCHAR2, p_report_id IN VARCHAR2
                                , p_currency IN VARCHAR2)
    IS
        CURSOR acc_bal_seg_cur IS
              SELECT DISTINCT bal_seg
                FROM xxdo.xxd_gl_concur_acc_stg_t
               WHERE     1 = 1
                     AND je_source_name = NVL (p_source, je_source_name)
                     AND je_category_name = NVL (p_category, je_category_name)
                     --                  AND NVL (status, 'N') IN DECODE (p_reprocess, 'Y', 'E', 'N') -- Reprocessing updates Error Records to N
                     AND NVL (status, 'N') IN
                             DECODE (p_reprocess, 'Y', 'N', 'N')
                     AND TO_DATE (file_processed_date, 'RRRR-MM-DD') <=
                         fnd_date.canonical_to_date (p_as_of_date)
                     AND bal_seg = NVL (p_bal_seg, bal_seg)
                     AND report_id = NVL (p_report_id, report_id)
                     AND currency = NVL (p_currency, currency)
                     AND NVL (process_flag, 'Z') <> 'E'
                     AND request_id = gn_request_id               -- Added New
                     AND bal_seg IS NOT NULL
            ORDER BY bal_seg;

        CURSOR acc_gl_cur (p_seg IN VARCHAR2)
        IS
              SELECT *
                FROM xxdo.xxd_gl_concur_acc_stg_t
               WHERE     1 = 1
                     AND bal_seg = p_seg
                     AND je_source_name = NVL (p_source, je_source_name)
                     AND je_category_name = NVL (p_category, je_category_name)
                     --                  AND NVL (status, 'N') IN DECODE (p_reprocess, 'Y', 'E', 'N') -- Reprocessing updates Error Records to N
                     AND NVL (status, 'N') IN
                             DECODE (p_reprocess, 'Y', 'N', 'N')
                     AND TO_DATE (file_processed_date, 'RRRR-MM-DD') <=
                         fnd_date.canonical_to_date (p_as_of_date)
                     AND report_id = NVL (p_report_id, report_id)
                     AND currency = NVL (p_currency, currency)
                     AND NVL (process_flag, 'Z') <> 'E'
                     AND request_id = gn_request_id               -- Added New
                     AND bal_seg IS NOT NULL
            ORDER BY seq_db_num;

        CURSOR upd_gl_acc_cur (p_seg IN VARCHAR2)
        IS
            SELECT DISTINCT bal_seg
              FROM xxdo.xxd_gl_concur_acc_stg_t stg
             WHERE     1 = 1
                   AND stg.bal_seg = p_seg
                   AND stg.je_source_name =
                       NVL (p_source, stg.je_source_name)
                   AND stg.je_category_name =
                       NVL (p_category, stg.je_category_name)
                   AND TO_DATE (file_processed_date, 'RRRR-MM-DD') <=
                       fnd_date.canonical_to_date (p_as_of_date)
                   AND stg.report_id = NVL (p_report_id, report_id)
                   AND stg.currency = NVL (p_currency, currency)
                   AND stg.request_id = gn_request_id
                   AND NVL (stg.process_flag, 'Z') <> 'E'
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_concur_acc_stg_t stg1
                             WHERE     stg.bal_seg = stg1.bal_seg
                                   AND stg.je_source_name =
                                       stg1.je_source_name
                                   AND stg1.status = 'E'
                                   AND stg.je_category_name =
                                       stg1.je_category_name
                                   AND stg.file_processed_date =
                                       stg1.file_processed_date
                                   AND stg.report_id = stg1.report_id
                                   AND stg.currency = stg1.currency
                                   AND stg.request_id = stg1.request_id);

        gl_rec_cur              acc_gl_cur%ROWTYPE;

        l_bal_seg               VARCHAR2 (100);
        l_dist_value            VARCHAR2 (100);
        l_debit_ccid            gl_code_combinations_kfv.code_combination_id%TYPE;
        l_debit_cc              gl_code_combinations_kfv.concatenated_segments%TYPE;
        l_credit_cc             gl_code_combinations_kfv.concatenated_segments%TYPE;
        l_credit_ccid           gl_code_combinations_kfv.code_combination_id%TYPE;
        l_offset_gl_code        gl_code_combinations_kfv.concatenated_segments%TYPE;
        l_offset_gl_code_paid   gl_code_combinations_kfv.concatenated_segments%TYPE;
        l_offset_gl_ID          gl_code_combinations_kfv.code_combination_id%TYPE;
        l_offset_gl_ID_paid     gl_code_combinations_kfv.code_combination_id%TYPE;
        l_offset_gl_comb        gl_code_combinations_kfv.code_combination_id%TYPE;
        l_offset_gl_comb_paid   gl_code_combinations_kfv.code_combination_id%TYPE;
        l_process_msg           VARCHAR2 (4000);
        l_process_flag          VARCHAR2 (1);
        l_curr_code             VARCHAR2 (10);
        l_paid_flag             VARCHAR2 (10);
        l_ledger_id             NUMBER;
        l_ledger_name           VARCHAR2 (240);
        l_period_name           VARCHAR2 (10);
        l_curr_period_name      VARCHAR2 (10);
        l_old_period_name       VARCHAR2 (10);
        l_rev_period_name       VARCHAR2 (10);
        -- Start of Change 1.2
        l_rev_date              VARCHAR2 (10);
        l_upd_natual_account    gl_code_combinations.segment6%TYPE;
        l_default_account       gl_code_combinations.segment6%TYPE;
        -- End of Change 1.2

        l_ledger_curr           VARCHAR2 (100);
        l_hdr_boolean           BOOLEAN;
        l_boolean               BOOLEAN;
        l_hdr_status            VARCHAR2 (10);
        l_status                VARCHAR2 (10);
        l_hdr_msg               VARCHAR2 (4000);
        l_msg                   VARCHAR2 (4000);
        l_ret_msg               VARCHAR2 (4000);
        l_hdr_ret_msg           VARCHAR2 (4000);
        l_hdr_seg_value         VARCHAR2 (10);
        l_user_je_source        gl_je_sources.user_je_source_name%TYPE;
        l_user_je_category      VARCHAR2 (100);
        l_main_msg              VARCHAR2 (4000);
        l_main_status           VARCHAR2 (10);
        ln_count                NUMBER := 0;
        l_sysdate               DATE := SYSDATE;
    --  l_gl_date             DATE := p_gl_date;

    BEGIN
        l_main_status   := NULL;
        l_main_msg      := NULL;

        UPDATE xxdo.xxd_gl_concur_acc_stg_t
           SET process_msg = NULL, error_msg = NULL
         WHERE     1 = 1
               AND je_source_name = NVL (p_source, je_source_name)
               AND je_category_name = NVL (p_category, je_category_name)
               --             AND NVL (status, 'N') IN DECODE (p_reprocess, 'Y', 'E', 'N') Commented
               AND NVL (status, 'N') IN DECODE (p_reprocess, 'Y', 'N', 'N')
               AND TO_DATE (file_processed_date, 'RRRR-MM-DD') <=
                   fnd_date.canonical_to_date (p_as_of_date)
               AND NVL (bal_seg, 'A') = NVL (p_bal_seg, NVL (bal_seg, 'A'))
               AND report_id = NVL (p_report_id, report_id)
               AND currency = NVL (p_currency, currency);



        BEGIN
            --      l_hdr_status := NULL;
            l_ret_msg   := NULL;
            l_user_je_source   :=
                get_user_je_source (p_source    => p_source,
                                    x_ret_msg   => l_ret_msg);

            IF l_user_je_source IS NULL OR l_ret_msg IS NOT NULL
            THEN
                l_main_status   := g_errored;
                l_main_msg      := l_main_msg || ' - ' || l_ret_msg;
            END IF;
        END;

        BEGIN
            l_ret_msg   := NULL;
            l_user_je_category   :=
                get_user_je_category (p_category   => p_category,
                                      x_ret_msg    => l_ret_msg);

            IF l_user_je_category IS NULL OR l_ret_msg IS NOT NULL
            THEN
                l_main_status   := g_errored;
                l_main_msg      := l_main_msg || ' - ' || l_ret_msg;
            END IF;
        END;

        BEGIN
            UPDATE xxdo.xxd_gl_concur_acc_stg_t
               SET status = g_errored, process_flag = g_errored, request_id = gn_request_id,
                   creation_date = gd_sysdate, last_update_date = gd_sysdate, created_by = gn_user_id,
                   last_update_login = gn_login_id, error_msg = 'Balancing Segment Cannot be NULL'
             WHERE 1 = 1 AND bal_seg IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_main_status   := g_errored;
        --       l_main_status := l_main_status||' - '||' Initial Exception = '||SUBSTR(SQLERRM,1,200);
        END;

        IF l_main_status IS NULL
        THEN
            FOR seg_rec IN acc_bal_seg_cur
            LOOP
                l_ledger_id            := NULL;
                l_ledger_name          := NULL;
                l_period_name          := NULL;
                l_rev_period_name      := NULL;
                l_curr_period_name     := NULL;
                l_old_period_name      := NULL;
                l_hdr_status           := NULL;
                l_hdr_msg              := NULL;
                l_hdr_boolean          := NULL;
                l_hdr_ret_msg          := NULL;
                l_hdr_seg_value        := NULL;

                -- Start of Change 1.2
                l_upd_natual_account   := NULL;
                l_rev_date             := NULL;

                -- End of Change 1.2


                -- Validate Balancing segment

                IF seg_rec.bal_seg IS NOT NULL
                THEN
                    l_hdr_boolean     := NULL;
                    --        l_hdr_status  := NULL;
                    l_hdr_ret_msg     := NULL;
                    l_hdr_seg_value   := NULL;
                    l_hdr_boolean     :=
                        is_bal_seg_valid (p_company   => seg_rec.bal_seg,
                                          x_ret_msg   => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := g_errored;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    ELSE
                        l_hdr_seg_value   := 'VALID';
                    END IF;
                ELSE
                    l_hdr_status   := g_errored;
                    l_hdr_msg      :=
                        l_hdr_msg || ' Balancing segment Cannot be NULL ';
                END IF;

                -- Get Ledger ID and Name

                IF l_hdr_seg_value = 'VALID'
                THEN
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    l_ledger_id     := NULL;
                    l_ledger_name   := NULL;
                    --      Get Ledger ID and Name

                    l_hdr_boolean   :=
                        get_ledger (p_seg_val => seg_rec.bal_seg, x_ledger_id => l_ledger_id, x_ledger_name => l_ledger_name
                                    , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := g_errored;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;
                END IF;

                IF l_hdr_seg_value = 'VALID' AND l_ledger_id IS NOT NULL
                THEN
                    --      Get the Period name if the Date is Open
                    l_hdr_boolean   := NULL;
                    l_hdr_ret_msg   := NULL;
                    l_period_name   := NULL;
                    l_hdr_boolean   :=
                        get_period_name (p_ledger_id => l_ledger_id, p_gl_date => p_gl_date, x_period_name => l_period_name
                                         , x_ret_msg => l_hdr_ret_msg);

                    IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                    THEN
                        l_hdr_status   := g_errored;
                        l_hdr_msg      := l_hdr_msg || ' - ' || l_hdr_ret_msg;
                    END IF;

                    IF l_period_name IS NOT NULL
                    THEN
                        l_hdr_boolean       := NULL;
                        l_hdr_ret_msg       := NULL;
                        l_rev_period_name   := NULL;
                        l_rev_date          := NULL;   -- Added for Change 1.2
                        l_hdr_boolean       :=
                            get_rev_period_name (
                                p_ledger_id     => l_ledger_id,
                                p_gl_date       => p_gl_date,
                                x_period_name   => l_rev_period_name,
                                x_date          => l_rev_date -- Added for Change 1.2
                                                             ,
                                x_ret_msg       => l_hdr_ret_msg);

                        IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                        THEN
                            l_hdr_status   := g_errored;
                            l_hdr_msg      :=
                                l_hdr_msg || ' - ' || l_hdr_ret_msg;
                        END IF;
                    END IF;
                END IF;

                IF l_hdr_seg_value = 'VALID'
                THEN
                    l_offset_gl_comb_paid   := NULL;
                    l_offset_gl_comb        := NULL;
                    l_default_account       := NULL;   -- Added for Change 1.2

                    -- Get ledger Currency

                    IF l_ledger_id IS NOT NULL
                    THEN
                        l_hdr_boolean   := NULL;
                        l_ledger_curr   := NULL;
                        l_hdr_ret_msg   := NULL;
                        l_hdr_boolean   :=
                            get_ledger_curr (p_ledger_id     => l_ledger_id,
                                             x_ledger_curr   => l_ledger_curr,
                                             x_ret_msg       => l_hdr_ret_msg);

                        IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                        THEN
                            l_hdr_status   := g_errored;
                            l_hdr_msg      :=
                                l_hdr_msg || ' - ' || l_hdr_ret_msg;
                        END IF;
                    END IF;


                    BEGIN
                        SELECT ffv.attribute13, ffv.attribute14, ffv.attribute19 -- Added for Change 1.2
                          INTO l_offset_gl_comb, l_offset_gl_comb_paid, l_default_account -- Added for Change 1.2
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                         WHERE     ffvs.flex_value_set_id =
                                   ffv.flex_value_set_id
                               AND ffvs.flex_value_set_name = 'XXD_CONCUR_OU'
                               AND ffv.enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (
                                                       ffv.start_date_active,
                                                       SYSDATE)
                                               AND NVL (ffv.end_date_active,
                                                        SYSDATE)
                               AND ffv.flex_value = seg_rec.bal_seg;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            l_hdr_msg      :=
                                   l_hdr_msg
                                || ' Mapping is not found for the Company Segment ';
                            l_hdr_status   := g_errored;
                        WHEN OTHERS
                        THEN
                            l_hdr_msg      :=
                                   l_hdr_msg
                                || ' - '
                                || ' Exception in Valueset : '
                                || SUBSTR (SQLERRM, 1, 200);
                            l_hdr_status   := g_errored;
                    END;

                    -- Start of Change 1.2

                    IF l_default_account IS NOT NULL
                    THEN
                        l_hdr_boolean   := NULL;
                        l_hdr_ret_msg   := NULL;
                        l_hdr_boolean   :=
                            is_seg_valid (p_seg => l_default_account, p_flex_type => 'DO_GL_ACCOUNT', p_seg_type => 'Account'
                                          , x_ret_msg => l_hdr_ret_msg);

                        IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                        THEN
                            l_hdr_status   := g_errored;
                            l_hdr_msg      :=
                                l_hdr_msg || ' - ' || l_hdr_ret_msg;
                        END IF;
                    END IF;

                    -- End of Change 1.2

                    IF l_offset_gl_comb IS NOT NULL
                    THEN
                        l_hdr_boolean      := NULL;
                        --          l_hdr_status := NULL;
                        l_offset_gl_code   := NULL;
                        l_hdr_ret_msg      := NULL;
                        l_hdr_boolean      :=
                            get_code_comb (p_code_comb   => l_offset_gl_comb,
                                           x_code_comb   => l_offset_gl_code,
                                           x_ret_msg     => l_hdr_ret_msg);

                        IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                        THEN
                            l_hdr_status   := g_errored;
                            l_hdr_msg      :=
                                l_hdr_msg || ' - ' || l_hdr_ret_msg;
                        END IF;
                    ELSE
                        l_hdr_status   := g_errored;
                        l_hdr_msg      :=
                               l_hdr_msg
                            || ' - '
                            || ' Offset Code combination cannot be NULL ';
                    END IF;

                    IF l_offset_gl_comb_paid IS NOT NULL
                    THEN
                        l_hdr_boolean           := NULL;
                        l_offset_gl_code_paid   := NULL;
                        l_ret_msg               := NULL;
                        l_hdr_boolean           :=
                            get_code_comb (
                                p_code_comb   => l_offset_gl_comb_paid,
                                x_code_comb   => l_offset_gl_code_paid,
                                x_ret_msg     => l_hdr_ret_msg);

                        IF l_hdr_boolean = FALSE OR l_hdr_ret_msg IS NOT NULL
                        THEN
                            l_hdr_msg      :=
                                l_hdr_msg || ' - ' || l_hdr_ret_msg;
                            l_hdr_status   := g_errored;
                        END IF;
                    ELSE
                        l_hdr_status   := g_errored;
                        l_hdr_msg      :=
                               l_hdr_msg
                            || ' - '
                            || 'Offset Code combination paid cannot be NULL in Valueset';
                    END IF;
                ELSE
                    l_hdr_status   := g_errored;
                    l_hdr_msg      :=
                           l_hdr_msg
                        || ' Balancing segment has to be valid to derive offset code combinations ';
                END IF;

                IF l_hdr_status IS NULL
                THEN
                    FOR gl_rec IN acc_gl_cur (seg_rec.bal_seg)
                    LOOP
                        ln_count        := ln_count + 1;
                        l_debit_ccid    := NULL;
                        l_debit_cc      := NULL;
                        l_credit_ccid   := NULL;
                        l_credit_cc     := NULL;
                        l_msg           := NULL;
                        l_ret_msg       := NULL;
                        l_status        := NULL;
                        l_boolean       := NULL;
                        l_ret_msg       := NULL;
                        l_dist_value    := NULL;

                        -- Validate the Company Segment

                        IF gl_rec.company_seg IS NOT NULL
                        THEN
                            l_ret_msg   := NULL;
                            l_boolean   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => gl_rec.company_seg, p_flex_type => 'DO_GL_COMPANY', p_seg_type => 'Company'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := g_errored;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := g_errored;
                            l_msg      :=
                                l_msg || ' Company Segment cannot be NULL ';
                        END IF;

                        -- Validate the Brand segment

                        IF gl_rec.brand_seg IS NOT NULL
                        THEN
                            l_ret_msg   := NULL;
                            l_boolean   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => gl_rec.brand_seg, p_flex_type => 'DO_GL_BRAND', p_seg_type => 'Brand'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := g_errored;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := g_errored;
                            l_msg      :=
                                l_msg || ' Brand Segment cannot be NULL ';
                        END IF;

                        -- Validate Geo segment

                        IF gl_rec.geo_seg IS NOT NULL
                        THEN
                            l_ret_msg   := NULL;
                            l_boolean   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => gl_rec.geo_seg, p_flex_type => 'DO_GL_GEO', p_seg_type => 'Geo'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := g_errored;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := g_errored;
                            l_msg      :=
                                l_msg || ' Geo Segment cannot be NULL ';
                        END IF;

                        -- Validate Channel segment

                        IF gl_rec.channel_seg IS NOT NULL
                        THEN
                            l_ret_msg   := NULL;
                            l_boolean   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => gl_rec.channel_seg, p_flex_type => 'DO_GL_CHANNEL', p_seg_type => 'Channel'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := g_errored;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := g_errored;
                            l_msg      :=
                                l_msg || ' Channel Segment cannot be NULL ';
                        END IF;

                        -- Validate Cost Center Segment

                        IF gl_rec.cost_center_seg IS NOT NULL
                        THEN
                            l_ret_msg   := NULL;
                            l_boolean   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => gl_rec.cost_center_seg, p_flex_type => 'DO_GL_COST_CENTER', p_seg_type => 'Cost Center'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := g_errored;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            --- Start of Change 1.2
                            ELSE
                                l_boolean              := NULL;
                                l_ret_msg              := NULL;
                                l_upd_natual_account   := NULL;
                                l_boolean              :=
                                    get_cost_center_begin_value (
                                        p_cost_center_seg   =>
                                            gl_rec.cost_center_seg,
                                        x_upd_nat_account   =>
                                            l_upd_natual_account,
                                        x_ret_msg   => l_ret_msg);

                                IF l_ret_msg IS NOT NULL
                                THEN
                                    l_status   := g_errored;
                                    l_msg      := l_msg || ' - ' || l_ret_msg;
                                END IF;
                            --- End of Change
                            END IF;
                        ELSE
                            l_status   := g_errored;
                            l_msg      :=
                                   l_msg
                                || ' Cost Center Segment cannot be NULL ';
                        END IF;

                        -- Validate Account segment

                        IF gl_rec.account_code_seg IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => gl_rec.account_code_seg, p_flex_type => 'DO_GL_ACCOUNT', p_seg_type => 'Account'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := g_errored;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := g_errored;
                            l_msg      :=
                                l_msg || ' Account Segment cannot be NULL ';
                        END IF;

                        -- Validate Intercompany segment

                        IF gl_rec.intercompany_seg IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            --            l_dist_value := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => gl_rec.intercompany_seg, p_flex_type => 'DO_GL_COMPANY', p_seg_type => 'Intercompany Account'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := g_errored;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := g_errored;
                            l_msg      :=
                                   l_msg
                                || ' Intercompany Segment cannot be NULL ';
                        END IF;

                        -- Validate Future segment

                        IF gl_rec.future_use_seg IS NOT NULL
                        THEN
                            l_boolean   := NULL;
                            l_ret_msg   := NULL;
                            --              l_dist_value := NULL;
                            l_boolean   :=
                                is_seg_valid (p_seg => gl_rec.future_use_seg, p_flex_type => 'DO_GL_FUTURE', p_seg_type => 'Future Account'
                                              , x_ret_msg => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status       := g_errored;
                                l_msg          := l_msg || ' - ' || l_ret_msg;
                                l_dist_value   := 'INVALID';
                            END IF;
                        ELSE
                            l_status   := g_errored;
                            l_msg      :=
                                   l_msg
                                || ' Future Account Segment cannot be NULL ';
                        END IF;

                        -- Get Amount based on Conversion Type

                        IF gl_rec.amount / 1 <> gl_rec.amount
                        THEN
                            l_status   := g_errored;
                            l_msg      :=
                                l_msg || ' Amount value Should be a Number ';
                        END IF;


                        --          IF NVL(l_dist_value,'ABC') = 'ABC'
                        --          THEN
                        --            l_boolean := NULL;
                        --            l_ret_msg := NULL;
                        --            l_debit_ccid := NULL;
                        --            l_debit_cc := NULL;
                        --            l_boolean := is_code_comb_valid  (p_seg1    => gl_rec.company_seg
                        --                                               ,p_seg2    => gl_rec.brand_seg
                        --                                               ,p_seg3    => gl_rec.geo_seg
                        --                                               ,p_seg4    => gl_rec.channel_seg
                        --                                               ,p_seg5    => gl_rec.cost_center_seg
                        --                                               ,p_seg6    => gl_rec.account_code_seg
                        --                                               ,p_seg7    => gl_rec.intercompany_seg
                        --                                               ,p_seg8    => gl_rec.future_use_seg
                        --                                               ,x_ccid    => l_debit_ccid
                        --                                               ,x_cc      => l_debit_cc
                        --                                               ,x_ret_msg => l_ret_msg);
                        --
                        --              IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                        --              THEN
                        --                l_status := g_errored;
                        --                l_msg := l_msg||' - '||l_ret_msg;
                        --              END IF;
                        --          END IF;

                        IF NVL (l_dist_value, 'ABC') = 'ABC'
                        THEN
                            l_boolean      := NULL;
                            l_ret_msg      := NULL;
                            l_debit_ccid   := NULL;
                            l_debit_cc     := NULL;
                            l_boolean      :=
                                is_code_comb_valid (
                                    p_seg1      => gl_rec.company_seg,
                                    p_seg2      => gl_rec.brand_seg,
                                    p_seg3      => gl_rec.geo_seg,
                                    p_seg4      => gl_rec.channel_seg,
                                    p_seg5      => gl_rec.cost_center_seg,
                                    p_seg6      => gl_rec.account_code_seg,
                                    p_seg7      => gl_rec.intercompany_seg,
                                    p_seg8      => gl_rec.future_use_seg,
                                    x_ccid      => l_debit_ccid,
                                    x_cc        => l_debit_cc,
                                    x_ret_msg   => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL -- Given Code Combination is not enabled
                            THEN
                                -- Start of Change 1.2

                                --l_status := g_errored;
                                --l_msg := l_msg||' - '||l_ret_msg;

                                IF l_upd_natual_account IS NOT NULL -- Cost center value begins with 2 and associated DFF has account value
                                THEN
                                    l_ret_msg      := NULL;
                                    l_boolean      := NULL;
                                    l_debit_ccid   := NULL;
                                    l_debit_cc     := NULL;
                                    l_boolean      :=
                                        is_code_comb_valid (
                                            p_seg1      => gl_rec.company_seg,
                                            p_seg2      => gl_rec.brand_seg,
                                            p_seg3      => gl_rec.geo_seg,
                                            p_seg4      => gl_rec.channel_seg,
                                            p_seg5      => gl_rec.cost_center_seg,
                                            p_seg6      => l_upd_natual_account,
                                            p_seg7      =>
                                                gl_rec.intercompany_seg,
                                            p_seg8      => gl_rec.future_use_seg,
                                            x_ccid      => l_debit_ccid,
                                            x_cc        => l_debit_cc,
                                            x_ret_msg   => l_ret_msg);

                                    IF    l_boolean = FALSE
                                       OR l_ret_msg IS NOT NULL
                                    THEN
                                        l_status   := g_errored;
                                        l_msg      :=
                                            l_msg || ' - ' || l_ret_msg;
                                    END IF;
                                ELSIF l_default_account IS NOT NULL -- Finally, check if default account is NOT NULL
                                THEN
                                    l_ret_msg      := NULL;
                                    l_boolean      := NULL;
                                    l_debit_ccid   := NULL;
                                    l_debit_cc     := NULL;
                                    l_boolean      :=
                                        is_code_comb_valid (
                                            p_seg1      => gl_rec.company_seg,
                                            p_seg2      => gl_rec.brand_seg,
                                            p_seg3      => gl_rec.geo_seg,
                                            p_seg4      => gl_rec.channel_seg,
                                            p_seg5      => gl_rec.cost_center_seg,
                                            p_seg6      => l_default_account,
                                            p_seg7      =>
                                                gl_rec.intercompany_seg,
                                            p_seg8      => gl_rec.future_use_seg,
                                            x_ccid      => l_debit_ccid,
                                            x_cc        => l_debit_cc,
                                            x_ret_msg   => l_ret_msg);

                                    IF    l_boolean = FALSE
                                       OR l_ret_msg IS NOT NULL
                                    THEN
                                        l_status   := g_errored;
                                        l_msg      :=
                                            l_msg || ' - ' || l_ret_msg;
                                    END IF;
                                ELSE
                                    l_status   := g_errored;
                                    l_msg      := l_msg || ' - ' || l_ret_msg;
                                END IF;
                            --- End of Change

                            END IF;
                        END IF;

                        -- Validate Paid Flag

                        IF gl_rec.paid_flag IS NOT NULL
                        THEN
                            l_ret_msg     := NULL;
                            l_paid_flag   := NULL;
                            l_boolean     := NULL;
                            l_boolean     :=
                                is_flag_valid (p_flag      => gl_rec.paid_flag,
                                               x_flag      => l_paid_flag,
                                               x_ret_msg   => l_ret_msg);


                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status   := g_errored;
                                l_msg      := l_msg || ' - ' || l_ret_msg;
                            ELSIF l_boolean = TRUE AND l_paid_flag = 'Y'
                            THEN
                                l_credit_cc     := l_offset_gl_code_paid;
                                l_credit_ccid   := l_offset_gl_comb_paid;
                            ELSIF l_boolean = TRUE AND l_paid_flag = 'N'
                            THEN
                                l_credit_ccid   := l_offset_gl_comb;
                                l_credit_cc     := l_offset_gl_code;
                            END IF;
                        END IF;


                        -- Validate GL Currency

                        IF gl_rec.currency IS NOT NULL
                        THEN
                            l_boolean     := NULL;
                            l_ret_msg     := NULL;
                            l_curr_code   := NULL;
                            l_boolean     :=
                                is_curr_code_valid (
                                    p_curr_code   => gl_rec.currency,
                                    x_ret_msg     => l_ret_msg);

                            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                            THEN
                                l_status   := g_errored;
                                l_msg      := l_msg || ' - ' || l_ret_msg;
                            ELSE
                                l_curr_code   :=
                                    UPPER (TRIM (gl_rec.currency));
                            END IF;

                            IF l_curr_code = l_ledger_curr
                            THEN
                                NULL;
                            ELSE
                                l_boolean   := NULL;
                                l_ret_msg   := NULL;
                                l_boolean   :=
                                    check_rate_exists (
                                        p_conv_date   => p_gl_date,
                                        p_from_curr   => l_ledger_curr,
                                        p_to_curr     => l_curr_code,
                                        x_ret_msg     => l_ret_msg);

                                IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
                                THEN
                                    l_status   := g_errored;
                                    l_msg      := l_msg || ' - ' || l_ret_msg;
                                END IF;
                            END IF;
                        END IF;


                        IF l_status = g_errored
                        THEN
                            BEGIN
                                UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
                                   SET stg.status = g_errored, stg.error_msg = l_msg, stg.last_update_date = gd_sysdate,
                                       stg.creation_date = gd_sysdate, stg.created_by = gn_user_id, stg.last_updated_by = gn_user_id,
                                       stg.last_update_login = gn_login_id, stg.request_id = gn_request_id, --                      stg.data_msg = stg.data_msg||' - '||l_data_msg,
                                                                                                            stg.ledger_id = l_ledger_id,
                                       stg.ledger_name = l_ledger_name, stg.upd_natural_account = l_upd_natual_account, --- Added for Change 1.2
                                                                                                                        stg.comp_default_account = l_default_account, --- Added for Change 1.2
                                       stg.debit_code_combination = DECODE (SIGN (gl_rec.amount), 1, l_debit_cc, l_credit_cc), stg.debit_ccid = DECODE (SIGN (gl_rec.amount), 1, l_debit_ccid, l_credit_ccid), stg.credit_code_combination = DECODE (SIGN (gl_rec.amount), 1, l_credit_cc, l_debit_cc),
                                       stg.credit_ccid = DECODE (SIGN (gl_rec.amount), 1, l_credit_ccid, l_debit_ccid), stg.currency_code = l_curr_code, stg.ledger_currency = l_ledger_curr,
                                       stg.user_je_source_name = l_user_je_source, stg.user_je_category_name = l_user_je_category, stg.accounting_date = p_gl_date,
                                       stg.period_name = l_period_name, stg.rev_period_name = l_rev_period_name, stg.rev_date = l_rev_date, --- Added for Change 1.2
                                       stg.paid_flag_value = l_paid_flag
                                 WHERE     stg.bal_seg = seg_rec.bal_seg
                                       AND stg.seq_db_num = gl_rec.seq_db_num;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_status   := g_errored;
                                    l_msg      :=
                                           l_msg
                                        || ' - '
                                        || ' Error while updating the Staging Table: '
                                        || SUBSTR (SQLERRM, 1, 200);


                                    BEGIN
                                        UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
                                           SET stg.status = g_errored, stg.error_msg = l_msg, stg.creation_date = gd_sysdate,
                                               stg.created_by = gn_user_id, stg.last_updated_by = gn_user_id, stg.last_update_login = gn_login_id,
                                               stg.request_id = gn_request_id
                                         WHERE seq_db_num = gl_rec.seq_db_num;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_status   := g_errored;
                                            l_msg      :=
                                                   l_msg
                                                || ' - '
                                                || ' Error while updating the Staging Table: '
                                                || SUBSTR (SQLERRM, 1, 200);
                                    END;
                            END;
                        ELSE
                            BEGIN
                                --            l_data_msg := ' Line validation is complete ';
                                UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
                                   SET stg.status = g_validated, stg.error_msg = l_msg, stg.last_update_date = gd_sysdate,
                                       stg.creation_date = gd_sysdate, stg.created_by = gn_user_id, stg.last_updated_by = gn_user_id,
                                       stg.last_update_login = gn_login_id, stg.request_id = gn_request_id, --                      stg.data_msg = stg.data_msg||' - '||l_data_msg,
                                                                                                            stg.ledger_id = l_ledger_id,
                                       stg.ledger_name = l_ledger_name, stg.upd_natural_account = l_upd_natual_account, --- Added for Change 1.2
                                                                                                                        stg.comp_default_account = l_default_account, --- Added for Change 1.2
                                       stg.debit_code_combination = DECODE (SIGN (gl_rec.amount), 1, l_debit_cc, l_credit_cc), stg.debit_ccid = DECODE (SIGN (gl_rec.amount), 1, l_debit_ccid, l_credit_ccid), stg.credit_code_combination = DECODE (SIGN (gl_rec.amount), 1, l_credit_cc, l_debit_cc),
                                       stg.credit_ccid = DECODE (SIGN (gl_rec.amount), 1, l_credit_ccid, l_debit_ccid), stg.currency_code = l_curr_code, stg.ledger_currency = l_ledger_curr,
                                       stg.user_je_source_name = l_user_je_source, stg.user_je_category_name = l_user_je_category, stg.accounting_date = p_gl_date,
                                       stg.period_name = l_period_name, stg.rev_period_name = l_rev_period_name, stg.rev_date = l_rev_date, --- Added for Change 1.2
                                       stg.paid_flag_value = l_paid_flag
                                 WHERE     stg.bal_seg = seg_rec.bal_seg
                                       AND stg.seq_db_num = gl_rec.seq_db_num;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_status   := g_errored;
                                    l_msg      :=
                                           l_msg
                                        || ' - '
                                        || ' Error while updating the Staging Table: '
                                        || SUBSTR (SQLERRM, 1, 200);

                                    BEGIN
                                        UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
                                           SET stg.status = g_errored, stg.error_msg = l_msg, stg.creation_date = gd_sysdate,
                                               stg.created_by = gn_user_id, stg.last_updated_by = gn_user_id, stg.last_update_login = gn_login_id,
                                               stg.request_id = gn_request_id
                                         WHERE seq_db_num = gl_rec.seq_db_num;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_status   := g_errored;
                                            l_msg      :=
                                                   l_msg
                                                || ' - '
                                                || ' Error while updating the Staging Table: '
                                                || SUBSTR (SQLERRM, 1, 200);
                                    END;
                            END;
                        END IF;

                        FOR rec IN upd_gl_acc_cur (seg_rec.bal_seg)
                        LOOP
                            UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
                               SET stg.status = 'E', stg.process_msg = ' GL Lines are rejected, as one or more lines of the Bal Segment are Error  = ' || seg_rec.bal_seg
                             WHERE     1 = 1
                                   AND bal_seg = seg_rec.bal_seg
                                   AND company_seg = seg_rec.bal_seg
                                   AND request_id = gn_request_id; -- added for change 1.1
                        END LOOP;
                    END LOOP;
                ELSE
                    l_hdr_status   := g_errored;
                    l_hdr_msg      :=
                           l_hdr_msg
                        || ' Header level values for the balancing segment is not valid ';

                    BEGIN
                        UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
                           SET stg.status = g_errored, stg.error_msg = l_hdr_msg, stg.last_update_date = gd_sysdate
                         WHERE     stg.bal_seg = seg_rec.bal_seg
                               AND stg.bal_seg IS NOT NULL
                               AND NVL (stg.status, 'N') <> 'P'
                               AND stg.request_id = gn_request_id; -- Added New as per 1.4

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'No of Records : ' || SQL%ROWCOUNT);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_hdr_status   := g_errored;
                            l_msg          :=
                                   l_msg
                                || ' - '
                                || ' Error while updating the Staging Table: '
                                || SUBSTR (SQLERRM, 1, 200);
                    END;
                END IF;
            END LOOP;
        ELSE
            UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
               SET stg.status = g_errored, stg.error_msg = l_main_msg, stg.last_update_date = gd_sysdate,
                   stg.last_updated_by = gn_user_id, stg.last_update_login = gn_login_id
             WHERE     NVL (stg.status, 'N') <> 'P'
                   AND stg.request_id = gn_request_id; -- Added New as per 1.4
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception while Validating the staging Data : '
                || SUBSTR (SQLERRM, 1, 200);
    END validate_staging;

    PROCEDURE email_out (p_dist_list_name IN VARCHAR2, x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        l_out_line          VARCHAR2 (10000);
        l_counter           NUMBER := 0;
        l_ret_val           NUMBER := 0;
        l_def_mail_recips   apps.do_mail_utils.tbl_recips;
        l_sqlerrm           VARCHAR2 (4000);


        CURSOR data_cur IS
              SELECT stg.ledger_id, stg.accounting_date accounting_date, stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     stg.debit_ccid, NULL credit_ccid, stg.paid_flag_value,
                     stg.bal_seg Header_Company, stg.description, ABS (SUM (amount)) Entered_Dr,
                     NULL Entered_Cr, SUBSTR (debit_code_combination, 1, 3) Company, SUBSTR (debit_code_combination, 5, 4) Brand,
                     SUBSTR (debit_code_combination, 10, 3) Geo, SUBSTR (debit_code_combination, 14, 3) Channel, SUBSTR (debit_code_combination, 18, 4) CC,
                     SUBSTR (debit_code_combination, 23, 5) Account, SUBSTR (debit_code_combination, 29, 3) IC, SUBSTR (debit_code_combination, 33, 4) Future,
                     stg.debit_code_combination acct_seg, stg.user_je_category_name, stg.user_je_source_name,
                     stg.rev_period_name, -- Start of Change 1.2
                                          stg.rev_date, g_desc J_desc
                -- End of Change
                FROM xxdo.xxd_gl_concur_acc_stg_t stg
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = g_validated
                     AND stg.bal_seg <> stg.company_seg
                     AND stg.request_id = gn_request_id
            GROUP BY stg.ledger_id, stg.accounting_date, stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     stg.description, stg.debit_ccid, stg.paid_flag_value,
                     stg.bal_seg, stg.debit_code_combination, stg.rev_period_name,
                     -- Start of Change 1.2
                     stg.rev_date, g_desc, g_vt_desc,
                     -- Start of Change 1.2
                     stg.user_je_category_name, stg.user_je_source_name
            UNION ALL
              SELECT stg.ledger_id, stg.accounting_date, stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     NULL, stg.credit_ccid, stg.paid_flag_value,
                     stg.bal_seg Header_Company, stg.description, NULL,
                     ABS (SUM (amount)) Entered_Cr, SUBSTR (credit_code_combination, 1, 3), SUBSTR (credit_code_combination, 5, 4),
                     SUBSTR (credit_code_combination, 10, 3), SUBSTR (credit_code_combination, 14, 3), SUBSTR (credit_code_combination, 18, 4),
                     SUBSTR (credit_code_combination, 23, 5), SUBSTR (credit_code_combination, 29, 3), SUBSTR (credit_code_combination, 33, 4),
                     stg.credit_code_combination, stg.user_je_category_name, stg.user_je_source_name,
                     stg.rev_period_name, -- Start of Change 1.2
                                          stg.rev_date, g_desc
                -- End of Change 1.2
                FROM xxdo.xxd_gl_concur_acc_stg_t stg
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = g_validated
                     AND stg.bal_seg <> stg.company_seg
                     AND stg.request_id = gn_request_id
            GROUP BY stg.ledger_id, stg.accounting_date, stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     stg.description, stg.debit_ccid, stg.credit_ccid,
                     stg.paid_flag_value, stg.bal_seg, stg.credit_code_combination,
                     stg.rev_period_name, -- Start of Change 1.2
                                          stg.rev_date, g_desc,
                     g_vt_desc, -- Start of Change 1.2
                                stg.user_je_category_name, stg.user_je_source_name
            --- Start of Change 1.2
            UNION ALL
              SELECT stg.ledger_id, TO_DATE (stg.rev_date, 'DD-MON-RRRR'), --- Added for Change 1.2
                                                                           stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     stg.debit_ccid, NULL credit_ccid, stg.paid_flag_value,
                     stg.bal_seg Header_Company, stg.description, --          ABS(SUM(amount)) Entered_Dr,
                                                                  --          NULL  Entered_Cr,
                                                                  NULL Entered_Dr,
                     ABS (SUM (amount)) Entered_Cr, SUBSTR (debit_code_combination, 1, 3) Company, SUBSTR (debit_code_combination, 5, 4) Brand,
                     SUBSTR (debit_code_combination, 10, 3) Geo, SUBSTR (debit_code_combination, 14, 3) Channel, SUBSTR (debit_code_combination, 18, 4) CC,
                     SUBSTR (debit_code_combination, 23, 5) Account, SUBSTR (debit_code_combination, 29, 3) IC, SUBSTR (debit_code_combination, 33, 4) Future,
                     stg.debit_code_combination acct_seg, stg.user_je_category_name, stg.user_je_source_name,
                     stg.rev_period_name, TO_CHAR (stg.accounting_date, 'DD-MON-RRRR'), g_vt_desc --- Added for Change 1.2
                FROM xxdo.xxd_gl_concur_acc_stg_t stg
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = g_validated
                     AND stg.bal_seg <> stg.company_seg
                     AND stg.request_id = gn_request_id
            GROUP BY stg.ledger_id, stg.accounting_date, stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     stg.description, stg.debit_ccid, stg.paid_flag_value,
                     stg.bal_seg, stg.debit_code_combination, stg.rev_period_name,
                     -- Start of Change 1.2
                     stg.rev_date, g_desc, g_vt_desc,
                     -- End of Change 1.2
                     stg.user_je_category_name, stg.user_je_source_name
            UNION ALL
              SELECT stg.ledger_id, TO_DATE (stg.rev_date, 'DD-MON-RRRR'), --- Added for Change 1.2
                                                                           stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     NULL, stg.credit_ccid, stg.paid_flag_value,
                     stg.bal_seg Header_Company, stg.description, ABS (SUM (amount)) Entered_Dr,
                     NULL Entered_Cr, SUBSTR (credit_code_combination, 1, 3), SUBSTR (credit_code_combination, 5, 4),
                     SUBSTR (credit_code_combination, 10, 3), SUBSTR (credit_code_combination, 14, 3), SUBSTR (credit_code_combination, 18, 4),
                     SUBSTR (credit_code_combination, 23, 5), SUBSTR (credit_code_combination, 29, 3), SUBSTR (credit_code_combination, 33, 4),
                     stg.credit_code_combination, stg.user_je_category_name, stg.user_je_source_name,
                     stg.rev_period_name, TO_CHAR (stg.accounting_date, 'DD-MON-RRRR'), g_vt_desc -- Added for Change 1.2
                FROM xxdo.xxd_gl_concur_acc_stg_t stg
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = g_validated
                     AND stg.bal_seg <> stg.company_seg
                     AND stg.request_id = gn_request_id
            GROUP BY stg.ledger_id, stg.accounting_date, stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     stg.description, stg.debit_ccid, stg.credit_ccid,
                     stg.paid_flag_value, stg.bal_seg, stg.credit_code_combination,
                     stg.rev_period_name, -- Start of Change 1.2
                                          stg.rev_date, g_desc,
                     g_vt_desc, -- End of Change 1.2
                                stg.user_je_category_name, stg.user_je_source_name;

        -- End of Change 1.2

        ex_no_recips        EXCEPTION;
        ex_validation_err   EXCEPTION;
        ex_no_data_found    EXCEPTION;

        lv_org_code         VARCHAR2 (240);
        ln_cnt              NUMBER := 1;
        l_hdr_status        VARCHAR2 (30);
        l_line_status       VARCHAR2 (30);
        l_db_name           VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT name INTO l_db_name FROM v$DATABASE;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_db_name   := NULL;
        END;

        l_def_mail_recips (1)   := p_dist_list_name;

        apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), l_def_mail_recips, 'Concur Accrual Intercompany Transactions - ' || l_db_name || ' - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS')
                                             , l_ret_val);
        apps.do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                           l_ret_val);
        apps.do_mail_utils.send_mail_line ('', l_ret_val);
        /*apps.do_mail_utils.send_mail_line ('Organization - ' || lv_org_code,
                                           l_ret_val
                                          );*/
        apps.do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                           l_ret_val);
        apps.do_mail_utils.send_mail_line (
            'Content-Disposition: attachment; filename="Concur Accrual Intercompany Transactions.xls"',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('', l_ret_val);

        apps.do_mail_utils.send_mail_line (
               'Line Company '
            || CHR (9)
            || 'Line Description '
            || CHR (9)
            || 'Entered DR '
            || CHR (9)
            || 'Entered CR'
            || CHR (9)
            || 'Company'
            || CHR (9)
            || 'Brand '
            || CHR (9)
            || 'Geo '
            || CHR (9)
            || 'Channel '
            || CHR (9)
            || 'Cost Center '
            || CHR (9)
            || 'Account'
            || CHR (9)
            || 'InterCompany'
            || CHR (9)
            || 'Future'
            || CHR (9)
            || 'Accounting Date'
            || CHR (9)
            || 'Header Company'
            || CHR (9)
            ||                                                    --attribute4
               'Journal Currency'
            || CHR (9)
            || 'Journal Name'
            || CHR (9)
            ||                                                    --attribute3
               'Journal Description'
            || CHR (9)
            ||                                                    --attribute5
               'VT Transaction Type'
            || CHR (9)
            ||                                                    --attribute6
               'Exchange Date'
            || CHR (9)
            ||                                                    --attribute7
               'Exchange Type',
            l_ret_val);

        FOR data_rec IN data_cur
        LOOP
            --      xxv_debug_test_prc('Entered to Submit email');
            l_line_status   := NULL;
            l_counter       := l_counter + 1;
            l_out_line      := NULL;
            l_out_line      :=
                   data_rec.Company
                || CHR (9)
                || data_rec.description
                || CHR (9)
                || --                    to_char(data_rec.Entered_Cr)                  ||CHR(9)||  -- commented for 1.1
 --                    to_char(data_rec.Entered_dr)                  ||CHR(9)||  -- commented for 1.1
                 TO_CHAR (data_rec.Entered_dr)
                || CHR (9)
                ||                                     -- added for Change 1.1
                   TO_CHAR (data_rec.Entered_cr)
                || CHR (9)
                ||                                     -- added for Change 1.1
                   data_rec.Company
                || CHR (9)
                || data_rec.Brand
                || CHR (9)
                || data_rec.Geo
                || CHR (9)
                || data_rec.Channel
                || CHR (9)
                || data_rec.cc
                || CHR (9)
                || data_rec.Account
                || CHR (9)
                || data_rec.ic
                || CHR (9)
                || data_rec.future
                || CHR (9)
                || TO_CHAR (data_rec.accounting_date, 'DD-MON-RRRR')
                || CHR (9)
                || data_rec.header_company
                || CHR (9)
                || data_rec.currency
                || CHR (9)
                || data_rec.j_desc
                || '-'
                || data_rec.header_company
                || '-'
                || data_rec.currency
                || '-'
                || data_rec.accounting_date
                || '-'
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SSSSS')
                || CHR (9)
                ||                                                --attribute3
                   NULL
                || CHR (9)
                || 'Miscellaneous IC'
                || CHR (9)
                || TO_CHAR (data_rec.accounting_date, 'DD-MON-RRRR')
                || CHR (9)
                || 'Corporate';

            apps.do_mail_utils.send_mail_line (l_out_line, l_ret_val);
            l_counter       := l_counter + 1;
        END LOOP;

        BEGIN
            UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
               SET stg.status   = g_processed
             WHERE     1 = 1
                   AND NVL (stg.status, 'N') = g_validated
                   --         AND stg.bal_seg = r_valid_seg.bal_seg
                   AND stg.bal_seg <> stg.company_seg
                   AND stg.request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while updating Intercompany records');
        END;

        apps.do_mail_utils.send_mail_close (l_ret_val);
        ln_cnt                  := ln_cnt + 1;

        IF l_counter = 0
        THEN
            RAISE ex_no_data_found;
        END IF;
    EXCEPTION
        WHEN ex_no_data_found
        THEN
            apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), l_def_mail_recips, 'Concur Accrual Intercompany Transactions - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS')
                                                 , l_ret_val);
            apps.do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                l_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
            apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                               l_ret_val);
            apps.do_mail_utils.send_mail_line ('', l_ret_val);
            apps.do_mail_utils.send_mail_line (' ', l_ret_val);
            apps.do_mail_utils.send_mail_line (
                '*******No Eligible Records for this Request*********.',
                l_ret_val);
            apps.do_mail_utils.send_mail_line (' ', l_ret_val);
            apps.do_mail_utils.send_mail_line (
                'Request ID -' || gn_request_id,
                l_ret_val);
            apps.do_mail_utils.send_mail_close (l_ret_val);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '*************** No Eligible Records at this Request *******************');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
        WHEN ex_validation_err
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '*************** Invalid Email format *******************');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            x_ret_code   := 1;
        WHEN OTHERS
        THEN
            l_sqlerrm   := SUBSTR (SQLERRM, 1, 200);
            apps.do_mail_utils.send_mail_close (l_ret_val);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '******** Exception Occured while submitting the Request'
                || SQLERRM);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '----------------------------------------------------------------------------');
            COMMIT;


            NULL;
    END;


    PROCEDURE load_interface (x_ret_code   OUT VARCHAR2,
                              x_ret_msg    OUT VARCHAR2)
    IS
        CURSOR c_valid_seg IS
              SELECT bal_seg
                FROM xxdo.xxd_gl_concur_acc_stg_t stg
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = g_validated
                     AND stg.bal_seg = stg.company_seg
                     AND stg.request_id = gn_request_id
            GROUP BY bal_seg
            ORDER BY bal_seg;

        --Cursor to fetch all valid(V) records from staging
        CURSOR c_valid_data (p_bal_seg IN VARCHAR2)
        IS
              SELECT stg.ledger_id, stg.accounting_date, stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     stg.description, stg.debit_ccid, NULL credit_ccid,
                     stg.paid_flag_value, stg.bal_seg, stg.user_je_category_name,
                     stg.user_je_source_name, stg.rev_period_name, stg.rev_date, --- Added for Change 1.2
                     ABS (SUM (amount)) amount
                FROM xxdo.xxd_gl_concur_acc_stg_t stg
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = g_validated
                     AND stg.bal_seg = stg.company_seg
                     AND stg.bal_seg = p_bal_seg
                     AND stg.request_id = gn_request_id
            GROUP BY stg.ledger_id, stg.accounting_date, stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     stg.description, stg.debit_ccid, stg.paid_flag_value,
                     stg.bal_seg, stg.rev_period_name, stg.rev_date, --- Added for Change 1.2
                     stg.user_je_category_name, stg.user_je_source_name
            UNION ALL
              SELECT stg.ledger_id, stg.accounting_date, stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     NULL, NULL, stg.credit_ccid,
                     stg.paid_flag_value, stg.bal_seg, stg.user_je_category_name,
                     stg.user_je_source_name, stg.rev_period_name, stg.rev_date, --- Added for Change 1.2
                     ABS (SUM (amount)) amount
                FROM xxdo.xxd_gl_concur_acc_stg_t stg
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = g_validated
                     AND stg.bal_seg = stg.company_seg
                     AND stg.bal_seg = p_bal_seg
                     AND stg.request_id = gn_request_id
            GROUP BY stg.ledger_id, stg.accounting_date, stg.currency,
                     stg.ledger_currency, stg.creation_date, stg.created_by,
                     stg.credit_ccid, stg.paid_flag_value, stg.bal_seg,
                     stg.rev_period_name, stg.rev_date, --- Added for Change 1.2
                                                        stg.user_je_category_name,
                     stg.user_je_source_name;

        l_count   NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside Populate GL Interface Procedure');

        FOR r_valid_seg IN c_valid_seg
        LOOP
            FOR r_valid_data IN c_valid_data (r_valid_seg.bal_seg)
            LOOP
                l_count   := l_count + 1;

                IF r_valid_data.debit_ccid IS NOT NULL
                THEN
                    BEGIN
                        INSERT INTO gl_interface (
                                        status,
                                        ledger_id,
                                        accounting_date,
                                        currency_code,
                                        date_created,
                                        created_by,
                                        actual_flag,
                                        currency_conversion_date,
                                        reference10,
                                        reference8,
                                        reference7,
                                        code_combination_id,
                                        entered_dr,
                                        user_je_source_name,
                                        user_je_category_name,
                                        user_currency_conversion_type)
                                 VALUES (
                                            'NEW',
                                            r_valid_data.ledger_id,
                                            r_valid_data.accounting_date,
                                            r_valid_data.currency,
                                            r_valid_data.creation_date,
                                            r_valid_data.created_by,
                                            'A',
                                            CASE
                                                WHEN r_valid_data.ledger_currency <>
                                                     r_valid_data.currency
                                                THEN
                                                    r_valid_data.accounting_date
                                                ELSE
                                                    NULL
                                            END,
                                            r_valid_data.description,
                                            r_valid_data.rev_period_name,
                                            'Y',
                                            r_valid_data.debit_ccid,
                                            r_valid_data.amount,
                                            r_valid_data.user_je_source_name,
                                            r_valid_data.user_je_category_name,
                                            CASE
                                                WHEN r_valid_data.ledger_currency <>
                                                     r_valid_data.currency
                                                THEN
                                                    'Corporate'
                                                ELSE
                                                    NULL
                                            END);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
                               SET stg.status = g_errored, stg.error_msg = 'Exception while inserting into GL Interface', stg.last_update_date = gd_sysdate,
                                   stg.last_updated_by = gn_user_id, stg.last_update_login = gn_login_id
                             WHERE     stg.request_id = gn_request_id
                                   AND stg.bal_seg = stg.company_seg
                                   AND stg.bal_seg = r_valid_data.bal_seg
                                   AND stg.ledger_id = r_valid_data.ledger_id
                                   AND stg.description =
                                       r_valid_data.description
                                   AND stg.debit_ccid =
                                       r_valid_data.debit_ccid;
                    END;
                ELSIF r_valid_data.credit_ccid IS NOT NULL
                THEN
                    BEGIN
                        INSERT INTO gl_interface (
                                        status,
                                        ledger_id,
                                        accounting_date,
                                        currency_code,
                                        date_created,
                                        created_by,
                                        actual_flag,
                                        currency_conversion_date,
                                        reference10,
                                        reference8,
                                        reference7,
                                        code_combination_id,
                                        entered_cr,
                                        user_je_source_name,
                                        user_je_category_name,
                                        user_currency_conversion_type)
                                 VALUES (
                                            'NEW',
                                            r_valid_data.ledger_id,
                                            r_valid_data.accounting_date,
                                            r_valid_data.currency,
                                            r_valid_data.creation_date,
                                            r_valid_data.created_by,
                                            'A',
                                            CASE
                                                WHEN r_valid_data.ledger_currency <>
                                                     r_valid_data.currency
                                                THEN
                                                    r_valid_data.accounting_date
                                                ELSE
                                                    NULL
                                            END,
                                            r_valid_data.description,
                                            r_valid_data.rev_period_name,
                                            'Y',
                                            r_valid_data.credit_ccid,
                                            r_valid_data.amount,
                                            r_valid_data.user_je_source_name,
                                            r_valid_data.user_je_category_name,
                                            CASE
                                                WHEN r_valid_data.ledger_currency <>
                                                     r_valid_data.currency
                                                THEN
                                                    'Corporate'
                                                ELSE
                                                    NULL
                                            END);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
                               SET stg.status = g_errored, stg.error_msg = 'Exception while inserting into GL Interface', stg.last_update_date = gd_sysdate,
                                   stg.last_updated_by = gn_user_id, stg.last_update_login = gn_login_id
                             WHERE     stg.request_id = gn_request_id
                                   AND stg.bal_seg = stg.company_seg
                                   AND stg.bal_seg = r_valid_data.bal_seg
                                   AND stg.ledger_id = r_valid_data.ledger_id
                                   AND stg.description =
                                       r_valid_data.description
                                   AND stg.debit_ccid =
                                       r_valid_data.credit_ccid;
                    END;
                END IF;
            END LOOP;

            UPDATE xxdo.xxd_gl_concur_acc_stg_t stg
               SET stg.status   = g_processed
             WHERE     1 = 1
                   AND NVL (stg.status, 'N') = g_validated
                   AND stg.bal_seg = r_valid_seg.bal_seg
                   AND stg.bal_seg = stg.company_seg
                   AND stg.request_id = gn_request_id;
        END LOOP;

        COMMIT;
        x_ret_code   := '0';
        x_ret_msg    := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in load_interface:' || SQLERRM);
    END load_interface;

    FUNCTION get_user_je_source (p_source    IN     VARCHAR2,
                                 x_ret_msg      OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        l_source   apps.gl_je_sources.user_je_source_name%TYPE;
    BEGIN
        SELECT user_je_source_name
          INTO l_source
          FROM apps.gl_je_sources
         WHERE je_source_name = p_source AND LANGUAGE = 'US';

        RETURN l_source;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   'Exception Occurred while getting Journal Source : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN NULL;
    END get_user_je_source;

    FUNCTION check_rate_exists (p_conv_date IN VARCHAR2, p_from_curr IN VARCHAR2, p_to_curr IN VARCHAR2
                                , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM gl_daily_rates
         WHERE     conversion_type = 'Corporate'
               AND from_currency = p_from_curr
               AND to_currency = p_to_curr
               AND conversion_date = p_conv_date;

        IF l_count > 0
        THEN
            RETURN TRUE;
        ELSE
            x_ret_msg   :=
                'Corporate Rate doesnot exists for date = ' || p_conv_date;
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END check_rate_exists;


    FUNCTION get_user_je_category (p_category   IN     VARCHAR2,
                                   x_ret_msg       OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        l_category   gl_je_categories.user_je_category_name%TYPE;
    BEGIN
        SELECT user_je_category_name
          INTO l_category
          FROM apps.gl_je_categories
         WHERE je_category_name = p_category AND LANGUAGE = 'US';

        RETURN l_category;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   'Exception Occurred while getting Journal Category : '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN NULL;
    END get_user_je_category;

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
            x_ret_msg   := ' Balancing segment is Invalid: ';
            RETURN FALSE;
        END IF;
    END is_bal_seg_valid;

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
                   p_seg_type
                || ' is Invalid, Please check the corresponding segment Qualifiers as well: '
                || p_seg;
            RETURN FALSE;
        END IF;
    END is_seg_valid;

    --- Start of Change 1.2

    FUNCTION get_cost_center_begin_value (p_cost_center_seg IN VARCHAR2, x_upd_nat_account OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid_value       VARCHAR2 (10);
        l_upd_nat_account   VARCHAR2 (100);
    BEGIN
        SELECT ffv.attribute1, ffv.attribute2
          INTO l_valid_value, l_upd_nat_account
          FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
         WHERE     ffv.flex_value_set_id = ffvs.flex_value_set_id
               AND ffvs.flex_value_set_name = 'XXD_GL_CONCUR_CC_BEGIN_VS'
               AND NVL (ffv.enabled_flag, 'Y') = 'Y'
               AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                               AND NVL (ffv.end_date_active, SYSDATE)
               AND ffv.attribute1 = SUBSTR (p_cost_center_seg, 1, 1);

        IF l_valid_value IS NOT NULL
        THEN
            IF l_upd_nat_account IS NOT NULL
            THEN
                x_upd_nat_account   := l_upd_nat_account;
                RETURN TRUE;
            ELSE
                x_upd_nat_account   := NULL;
                x_ret_msg           :=
                       'There is no Natural account assigned to DFF for Cost Center value: '
                    || SUBSTR (p_cost_center_seg, 1, '1');
                RETURN FALSE;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_upd_nat_account   := NULL;
            x_ret_msg           := NULL;
            RETURN TRUE;
    END get_cost_center_begin_value;

    --- End of Change 1.2


    FUNCTION get_code_comb (p_code_comb IN VARCHAR2, x_code_comb OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT concatenated_segments
          INTO x_code_comb
          FROM gl_code_combinations_kfv
         WHERE     code_combination_id = p_code_comb
               AND NVL (enabled_flag, 'N') = 'Y';

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' There is No valid code combination available with CCID as : '
                || p_code_comb;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' There is multiple code combinations available with CCID as : '
                || p_code_comb;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Exception Occurred with CCID as : '
                || p_code_comb
                || ' - '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_code_comb;

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
                   ' Please check the Code Combination provided '
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
            x_ret_msg   := ' Invalid Currency Code.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Currencies exist with same code.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Currency Code: ' || SQLERRM;
            RETURN FALSE;
    END is_curr_code_valid;

    FUNCTION get_ledger (p_seg_val IN VARCHAR2, x_ledger_id OUT NUMBER, x_ledger_name OUT VARCHAR2
                         , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT DISTINCT ledger_id, ledger_name
          INTO x_ledger_id, x_ledger_name
          FROM XLE_LE_OU_LEDGER_V
         WHERE legal_entity_identifier = p_seg_val;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' No Ledger found for the Balancing Segment: ' || p_seg_val;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Ledgers found for Balancing Segment: '
                || p_seg_val;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                ' Exception found for Balancing Segment: ' || SQLERRM;
            RETURN FALSE;
    END get_ledger;

    FUNCTION get_ledger_curr (p_ledger_id IN NUMBER, x_ledger_curr OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT currency_code
          INTO x_ledger_curr
          FROM gl_ledgers
         WHERE ledger_id = p_ledger_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' There is no Ledger currency for Ledger ID : '
                || p_ledger_id;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Currencies derived for Ledger ID : '
                || p_ledger_id;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Invalid Currency for Ledger ID : '
                || p_ledger_id
                || ' - '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_ledger_curr;

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
               AND enabled_flag = 'Y' --         AND  UPPER(lookup_code) = upper(TRIM(p_flag));
               AND UPPER (meaning) = UPPER (TRIM (p_flag));

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


    FUNCTION get_period_name (p_ledger_id IN NUMBER, p_gl_date IN VARCHAR2, x_period_name OUT VARCHAR2
                              , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT period_name
          INTO x_period_name
          FROM gl_period_statuses
         WHERE     application_id = 101
               AND ledger_id = p_ledger_id
               AND closing_status = 'O'
               AND p_gl_date BETWEEN start_date AND end_date;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Open Period is not found for Date : '
                || p_gl_date
                || CHR (9)
                || ' ledger ID = '
                || p_ledger_id;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Open periods found for date : '
                || p_gl_date
                || CHR (9)
                || ' ledger ID = '
                || p_ledger_id;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Exception found while getting open period date for  : '
                || p_gl_date
                || CHR (9)
                || SQLERRM;
            RETURN FALSE;
    END get_period_name;


    FUNCTION get_rev_period_name (p_ledger_id     IN     NUMBER,
                                  p_gl_date       IN     VARCHAR2,
                                  x_period_name      OUT VARCHAR2,
                                  x_date             OUT VARCHAR2,
                                  x_ret_msg          OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT period_name, end_date                  --- Added for Change 1.2
          INTO x_period_name, x_date                  --- Added for Change 1.2
          FROM gl_period_statuses
         WHERE     application_id = 101
               AND ledger_id = p_ledger_id
               AND closing_status IN ('O', 'F')
               AND LAST_DAY (TRUNC (TO_DATE (p_gl_date, 'DD-MON-RRRR'))) + 1 BETWEEN start_date
                                                                                 AND end_date;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                   ' Open or Future Period is not found for Date : '
                || p_gl_date
                || CHR (9)
                || ' ledger ID = '
                || p_ledger_id;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Open periods found for date : '
                || p_gl_date
                || CHR (9)
                || ' ledger ID = '
                || p_ledger_id;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Exception found while getting open period date: '
                || SQLERRM;
            RETURN FALSE;
    END get_rev_period_name;

    PROCEDURE Update_acc_data (x_ret_code OUT NOCOPY VARCHAR2, x_ret_msg OUT NOCOPY VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2, p_gl_date IN VARCHAR2, p_reprocess IN VARCHAR2, p_bal_seg IN VARCHAR2, p_as_of_date IN VARCHAR2, p_report_id IN VARCHAR2
                               , p_currency IN VARCHAR2)
    IS
        CURSOR update_acc_data IS
            SELECT *
              FROM xxdo.xxd_gl_concur_acc_t
             WHERE     1 = 1
                   AND TO_DATE (file_processed_date, 'RRRR-MM-DD') <=
                       fnd_date.canonical_to_date (p_as_of_date)
                   AND NVL (bal_seg, 'A') =
                       NVL (p_bal_seg, NVL (bal_seg, 'A'))
                   AND report_id = NVL (p_report_id, report_id)
                   AND currency = NVL (p_currency, currency);
    BEGIN
        FOR upd IN update_acc_data
        LOOP
            UPDATE xxdo.xxd_gl_concur_acc_t acc
               SET (acc.status, acc.error_msg, acc.creation_date,
                    acc.created_by, acc.last_update_date, acc.last_updated_by
                    , acc.last_update_login, acc.request_id)   =
                       (SELECT stg1.status, stg1.error_msg || ' - ' || stg1.process_msg, stg1.creation_date,
                               stg1.created_by, stg1.last_update_date, stg1.last_updated_by,
                               stg1.last_update_login, stg1.request_id
                          FROM xxdo.xxd_gl_concur_acc_stg_t stg1
                         WHERE acc.seq_db_num = stg1.seq_db_num)
             WHERE acc.seq_db_num = upd.seq_db_num;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception while updating the SAE Data : '
                || SUBSTR (SQLERRM, 1, 200);
    END Update_acc_data;

    PROCEDURE log_data (x_ret_code      OUT NOCOPY VARCHAR2,
                        x_ret_msg       OUT NOCOPY VARCHAR2)
    IS
        l_ret_code       NUMBER;
        ln_total_count   NUMBER;
        ln_processed     NUMBER;
        ln_error         NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Submitted Request ID = ' || gn_request_id);

        -- Total Records Processed
        SELECT COUNT (*)
          INTO ln_total_count
          FROM xxdo.xxd_gl_concur_acc_t
         WHERE request_id = gn_request_id;

        IF ln_total_count < 1
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'There are no records considered for Request ID = '
                || gn_request_id);
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Total count of records considered are = ' || ln_total_count);
        END IF;

        -- Total Processed records
        SELECT COUNT (*)
          INTO ln_processed
          FROM xxdo.xxd_gl_concur_acc_t
         WHERE request_id = gn_request_id AND status = g_processed;

        IF ln_total_count < 1
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'There are No records processed sucessfully for Request ID = '
                || gn_request_id);
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                   'Total count of records processed sucessfully are = '
                || ln_processed);
        END IF;

        -- Total Error records
        SELECT COUNT (*)
          INTO ln_error
          FROM xxdo.xxd_gl_concur_acc_t
         WHERE request_id = gn_request_id AND status = g_errored;

        IF ln_total_count > 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Total count of Error records are = '
                || ln_error
                || ' and please refer to xxdo.xxd_gl_concur_acc_t table for Error record details ');
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'There are No error records ');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                   'Exception while listing the detail Log Data : '
                || SUBSTR (SQLERRM, 1, 200);
    END log_data;


    PROCEDURE MAIN (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_source IN VARCHAR2, p_category IN VARCHAR2, p_gl_date IN VARCHAR2, p_reprocess IN VARCHAR2, p_bal_seg IN VARCHAR2, p_as_of_date IN VARCHAR2, p_report_id IN VARCHAR2, p_currency IN VARCHAR2, p_dist_list_name IN VARCHAR2, p_provided_gl_date IN VARCHAR2
                    ,                         -- Added New paramter as per 1.4
                      pn_purge_days IN NUMBER       -- Added as per CCR0009228
                                             )
    IS
        l_ret_code           VARCHAR2 (10);
        l_err_msg            VARCHAR2 (4000);
        ex_load_interface    EXCEPTION;
        ex_create_invoices   EXCEPTION;
        ex_val_staging       EXCEPTION;
        ex_email_out         EXCEPTION;
        ex_check_data        EXCEPTION;
        ex_insert_stg        EXCEPTION;
        ex_acc_data          EXCEPTION;
        ex_log_data          EXCEPTION;
        lc_err_message       VARCHAR2 (100);
        l_gl_date            VARCHAR2 (100) := p_gl_date;
        l_curr_date          VARCHAR2 (100);
        l_gl_date1           VARCHAR2 (100);
        l_gl_date2           VARCHAR2 (100);
        l_gl_date3           VARCHAR2 (100);
        l_gl_date4           VARCHAR2 (100);
    BEGIN
        l_gl_date   := fnd_date.canonical_to_date (p_gl_date);
        l_curr_date   :=
            fnd_date.canonical_to_date (
                TO_CHAR (SYSDATE, 'RRRR/MM/DD HH24:MI:SS'));

        -- Start of Change as per 1.4

        IF NVL (p_provided_gl_date, 'Y') = 'N'
        THEN
            BEGIN
                SELECT TRUNC (fnd_date.canonical_to_date (TO_CHAR (SYSDATE, 'RRRR/MM/DD HH24:MI:SS')), 'MM'), LAST_DAY (fnd_date.canonical_to_date (TO_CHAR (SYSDATE, 'RRRR/MM/DD HH24:MI:SS'))), LAST_DAY (fnd_date.canonical_to_date (p_gl_date)),
                       TRUNC (fnd_date.canonical_to_date (TO_CHAR (SYSDATE, 'RRRR/MM/DD HH24:MI:SS')), 'MM') - 1
                  INTO l_gl_date1, l_gl_date2, l_gl_date3, l_gl_date4
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            IF l_gl_date BETWEEN l_gl_date1 AND l_gl_date2
            THEN
                l_gl_date   := l_gl_date4;
            ELSE
                l_gl_date   := l_gl_date3;
            END IF;
        ELSIF NVL (p_provided_gl_date, 'Y') = 'Y'
        THEN
            l_gl_date   := fnd_date.canonical_to_date (p_gl_date);
        END IF;

        -- End of Change


        IF NVL (p_reprocess, 'N') = 'N'
        THEN
            insert_staging (l_ret_code, l_err_msg, p_source,
                            p_category, p_bal_seg, p_as_of_date,
                            p_report_id, p_currency);
        ELSIF NVL (p_reprocess, 'N') = 'Y'
        THEN
            update_staging (l_ret_code, l_err_msg, p_source,
                            p_category, p_bal_seg, p_as_of_date,
                            p_report_id, p_currency, p_reprocess);
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Insert_staging message : ' || l_err_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_insert_stg;
        END IF;

        -- Start of Change for CCR0009228

        -- Purge the Data in the Staging tables

        purge_prc (pn_purge_days);

        -- End of Change for CCR0009228


        validate_staging (l_ret_code, l_err_msg, p_source,
                          p_category, l_gl_date, p_reprocess,
                          p_bal_seg, p_as_of_date, p_report_id,
                          p_currency);

        IF l_ret_code = '2'
        THEN
            RAISE ex_val_staging;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Validate Data Message : ' || l_err_msg);

        load_interface (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_load_interface;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Interface Message: ' || l_err_msg);

        email_out (p_dist_list_name, l_ret_code, l_err_msg);
        fnd_file.put_line (fnd_file.LOG,
                           'Sent Email to Dist list: ' || l_err_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_email_out;
        END IF;

        Update_acc_data (x_ret_code => l_ret_code, x_ret_msg => l_err_msg, p_source => p_source, p_category => p_category, p_gl_date => l_gl_date, p_reprocess => p_reprocess, p_bal_seg => p_bal_seg, p_as_of_date => p_as_of_date, p_report_id => p_report_id
                         , p_currency => p_currency);

        fnd_file.put_line (fnd_file.LOG,
                           'Update Acc data Message: ' || l_err_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_acc_data;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Record details are below: ' || l_err_msg);

        log_data (x_ret_code => l_ret_code, x_ret_msg => l_err_msg);



        IF l_ret_code = '2'
        THEN
            RAISE ex_log_data;
        END IF;
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
                'Error Populating GL_INTERFACE tables:' || l_err_msg);
        WHEN ex_email_out
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while Sending data to Distribution list:' || l_err_msg);
        WHEN ex_acc_data
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while updating Accrual table data:' || l_err_msg);
        WHEN ex_log_data
        THEN
            x_retcode   := l_ret_code;
            x_errbuf    := l_err_msg;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while displaying log data:' || l_err_msg);
        WHEN OTHERS
        THEN
            x_retcode   := '2';
            x_errbuf    := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Error in main:' || SQLERRM);
    END MAIN;
END XXD_GL_CONCUR_INBOUND_PKG;
/
