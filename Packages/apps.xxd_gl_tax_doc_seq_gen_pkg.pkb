--
-- XXD_GL_TAX_DOC_SEQ_GEN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_TAX_DOC_SEQ_GEN_PKG"
AS
    /****************************************************************************************
 * Package      : XXD_GL_TAX_DOC_SEQ_GEN_PKG
 * Design       : This package will be used to generate the GL Tax Authority Document Sequence
 * Notes        :
 * Modification :
 -- ======================================================================================
 -- Date         Version#   Name                    Comments
 -- ======================================================================================
 -- 11-Jan-2022 1.0        Showkath Ali            Initial Version
 -- 27-Mar-2022 1.1        Showkath Ali            CCR000 Gapless seq fix
 ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    -- Modifed to init G variable from input params

    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    ex_no_recips               EXCEPTION;
    gn_error          CONSTANT NUMBER := 2;

    /***********************************************************************************************
**************** Functio submit the xml bursting program*********************************
************************************************************************************************/

    FUNCTION send_email (pv_final_mode IN VARCHAR2)
        RETURN BOOLEAN
    AS
        -- Cursor to fetch the payment details based on the par
        ln_request_id     NUMBER;
        ln_burst_req_id   NUMBER;
    BEGIN
        --  Parameter PV_FINAL_MODE is Final then send email
        IF NVL (pv_final_mode, 'N') = 'Final'
        THEN
            -- query to get request id of XML program.
            BEGIN
                SELECT DISTINCT request_id
                  INTO ln_request_id
                  FROM xxdo.xxd_gl_tax_doc_seq_t;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_request_id   := NULL;
            END;

            -- submit the concurrent program if request id is not null

            IF ln_request_id IS NOT NULL
            THEN
                ln_burst_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XDO',
                        -- application
                        program       => 'XDOBURSTREP',
                        -- Program
                        description   =>
                            'XML Publisher Report Bursting Program',
                        -- description
                        argument1     => 'Y',
                        argument2     => ln_request_id,
                        -- argument1
                        argument3     => 'Y'                      -- argument2
                                            );

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Bursting Request ID  - ' || ln_burst_req_id);

                IF ln_burst_req_id <= 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to submit Bursting XML Publisher Request for Request ID = '
                        || ln_request_id);
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Submitted Bursting XML Publisher Request Request ID = '
                        || ln_burst_req_id);
                END IF;
            END IF;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'P_PROGRAM_MODE Parameter is Not Fianl mode - No email.');
        END IF;

        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'sqlerrm:' || SQLERRM);
            RETURN (TRUE);
    END send_email;

    -- =====================================================================================================
    -- Procedure fetch_eligible_records_prc: To fetch eligible records based on parameters
    -- =====================================================================================================

    PROCEDURE fetch_eligible_records_prc (pn_ledger_id IN NUMBER, pv_period_name IN VARCHAR2, pv_company_segment IN VARCHAR2
                                          , pv_final_mode IN VARCHAR2)
    AS
        CURSOR fetch_eligible_records IS
              SELECT /*+full(gjl) full(gjh) full(gcc)*/
                     DISTINCT
                     gl_led.name
                         ledger_name,
                     gjh.name
                         journal_name,
                     gjh.date_created
                         journal_date,
                     (SELECT user_je_category_name
                        FROM gl_je_categories
                       WHERE je_category_name = gjh.je_category)
                         journal_category,
                     (SELECT user_je_source_name
                        FROM gl_je_sources
                       WHERE je_source_name = gjh.je_source)
                         journal_source,
                     gjh.description
                         journal_desc,
                     gjh.default_effective_date
                         gl_date,
                     gjh.doc_sequence_value
                         document_number,
                     gjh.period_name
                         period_name,
                     'GL_Date Creation_date'
                         sort_by,
                     gjh.je_header_id,
                     gcc.segment1,
                     gjh.ledger_id,
                     gjh.je_source
                         source,
                     gjh.je_category
                         category
                FROM apps.gl_je_headers gjh, apps.gl_je_lines gjl, apps.gl_code_combinations gcc,
                     apps.gl_ledgers gl_led
               WHERE     gjh.je_header_id = gjl.je_header_id
                     AND gjh.ledger_id = gjl.ledger_id
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gjh.ledger_id = gl_led.ledger_id
                     AND gl_led.chart_of_accounts_id = gcc.chart_of_accounts_id
                     AND gjh.period_name = gjl.period_name
                     AND gjh.status = 'P'
                     AND gjh.actual_flag = 'A'
                     AND gjh.ledger_id = pn_ledger_id
                     AND gjl.period_name = pv_period_name
                     AND gcc.segment1 = pv_company_segment
                     --AND gjh.je_category = nvl(pv_category, gjh.je_category)
                     --AND gjh.je_source = pv_source
                     AND gjl.attribute10 IS NULL
                     AND EXISTS
                             (SELECT 1
                                FROM fnd_lookup_values flv
                               WHERE     1 = 1
                                     AND flv.lookup_type =
                                         'XXD_GL_TAX_SEQ_SOURCES_LKP'
                                     AND flv.enabled_flag = 'Y'
                                     AND flv.language = USERENV ('LANG')
                                     AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                     NVL (
                                                                         flv.start_date_active,
                                                                         SYSDATE))
                                                             AND TRUNC (
                                                                     NVL (
                                                                         flv.end_date_active,
                                                                         SYSDATE))
                                     AND tag =
                                         (SELECT user_je_source_name
                                            FROM gl_je_sources
                                           WHERE je_source_name = gjh.je_source)
                                     AND description =
                                         (SELECT user_je_category_name
                                            FROM gl_je_categories
                                           WHERE je_category_name =
                                                 gjh.je_category))
            ORDER BY gjh.default_effective_date, gjh.date_created;

        CURSOR fetch_eligible_line_records (p_je_header_id IN NUMBER)
        IS
            SELECT je_line_num
              FROM gl_je_lines gjl, gl_code_combinations gcc
             WHERE     gjl.code_combination_id = gcc.code_combination_id
                   AND je_header_id = p_je_header_id              --2034786001
                   AND gcc.segment1 = pv_company_segment;               --580;

        CURSOR fetch_reprint_records IS
              SELECT /*+full(gjl) full(gjh) full(gcc)*/
                     DISTINCT
                     gl_led.name
                         ledger_name,
                     gjh.name
                         journal_name,
                     gjh.date_created
                         journal_date,
                     (SELECT user_je_category_name
                        FROM gl_je_categories
                       WHERE je_category_name = gjh.je_category)
                         journal_category,
                     (SELECT user_je_source_name
                        FROM gl_je_sources
                       WHERE je_source_name = gjh.je_source)
                         journal_source,
                     gjh.description
                         journal_desc,
                     gjh.default_effective_date
                         gl_date,
                     gjh.doc_sequence_value
                         document_number,
                     gjl.attribute10
                         gapless_seq_no,
                     gjh.period_name
                         period_name,
                     'GL_Date Creation_date'
                         sort_by,
                     gjh.je_header_id,
                     gjl.je_line_num,
                     gcc.segment1,
                     gjl.attribute10,
                     gjh.ledger_id,
                     gjh.je_source
                         source,
                     gjh.je_category
                         category
                FROM apps.gl_je_headers gjh, apps.gl_je_lines gjl, apps.gl_code_combinations gcc,
                     apps.gl_ledgers gl_led
               WHERE     gjh.je_header_id = gjl.je_header_id
                     AND gjh.ledger_id = gjl.ledger_id
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gjh.ledger_id = gl_led.ledger_id
                     AND gl_led.chart_of_accounts_id = gcc.chart_of_accounts_id
                     AND gjh.period_name = gjl.period_name
                     AND gjh.status = 'P'
                     AND gjh.actual_flag = 'A'
                     AND gjh.ledger_id = pn_ledger_id
                     AND gjl.period_name = pv_period_name
                     AND gcc.segment1 = pv_company_segment
                     -- AND gjh.je_category = nvl(pv_category, gjh.je_category)
                     -- AND gjh.je_source = pv_source
                     AND gjl.attribute10 IS NOT NULL
                     AND EXISTS
                             (SELECT 1
                                FROM fnd_lookup_values flv
                               WHERE     1 = 1
                                     AND flv.lookup_type =
                                         'XXD_GL_TAX_SEQ_SOURCES_LKP'
                                     AND flv.enabled_flag = 'Y'
                                     AND flv.language = USERENV ('LANG')
                                     AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                     NVL (
                                                                         flv.start_date_active,
                                                                         SYSDATE))
                                                             AND TRUNC (
                                                                     NVL (
                                                                         flv.end_date_active,
                                                                         SYSDATE))
                                     AND tag =
                                         (SELECT user_je_source_name
                                            FROM gl_je_sources
                                           WHERE je_source_name = gjh.je_source)
                                     AND description =
                                         (SELECT user_je_category_name
                                            FROM gl_je_categories
                                           WHERE je_category_name =
                                                 gjh.je_category))
            ORDER BY gjh.default_effective_date, gjh.date_created;

        CURSOR fetch_rerun_records IS
              SELECT /*+full(gjl) full(gjh) full(gcc)*/
                     DISTINCT
                     gl_led.name
                         ledger_name,
                     gjh.name
                         journal_name,
                     gjh.date_created
                         journal_date,
                     (SELECT user_je_category_name
                        FROM gl_je_categories
                       WHERE je_category_name = gjh.je_category)
                         journal_category,
                     (SELECT user_je_source_name
                        FROM gl_je_sources
                       WHERE je_source_name = gjh.je_source)
                         journal_source,
                     gjh.description
                         journal_desc,
                     gjh.default_effective_date
                         gl_date,
                     gjh.doc_sequence_value
                         document_number,
                     -- gjl.attribute10 gapless_seq_no,
                     gjh.period_name
                         period_name,
                     'GL_Date Creation_date'
                         sort_by,
                     gjh.je_header_id,
                     -- gjl.je_line_num,
                     gcc.segment1,
                     -- gjl.attribute10,
                     gjh.ledger_id,
                     gjh.je_source
                         source,
                     gjh.je_category
                         category
                FROM apps.gl_je_headers gjh, apps.gl_je_lines gjl, apps.gl_code_combinations gcc,
                     apps.gl_ledgers gl_led
               WHERE     gjh.je_header_id = gjl.je_header_id
                     AND gjh.ledger_id = gjl.ledger_id
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gjh.ledger_id = gl_led.ledger_id
                     AND gl_led.chart_of_accounts_id = gcc.chart_of_accounts_id
                     AND gjh.period_name = gjl.period_name
                     AND gjh.status = 'P'
                     AND gjh.actual_flag = 'A'
                     AND gjh.ledger_id = pn_ledger_id
                     AND gjl.period_name = pv_period_name
                     AND gcc.segment1 = pv_company_segment
                     --AND gjh.je_category = nvl(pv_category, gjh.je_category)
                     --AND gjh.je_source = pv_source
                     AND gjl.attribute10 IS NULL
                     AND EXISTS
                             (SELECT 1
                                FROM fnd_lookup_values flv
                               WHERE     1 = 1
                                     AND flv.lookup_type =
                                         'XXD_GL_TAX_SEQ_SOURCES_LKP'
                                     AND flv.enabled_flag = 'Y'
                                     AND flv.language = USERENV ('LANG')
                                     AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                     NVL (
                                                                         flv.start_date_active,
                                                                         SYSDATE))
                                                             AND TRUNC (
                                                                     NVL (
                                                                         flv.end_date_active,
                                                                         SYSDATE))
                                     AND tag =
                                         (SELECT user_je_source_name
                                            FROM gl_je_sources
                                           WHERE je_source_name = gjh.je_source)
                                     AND description =
                                         (SELECT user_je_category_name
                                            FROM gl_je_categories
                                           WHERE je_category_name =
                                                 gjh.je_category))
            ORDER BY gjh.default_effective_date, gjh.date_created;

        CURSOR get_emails IS
            SELECT flv.meaning email_id
              FROM fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXD_GL_TAX_GAPLESS_MAIL_LKP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.language = USERENV ('LANG')
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE));

        -- Variable Declaration

        ln_period_year     NUMBER;
        ln_period_month    NUMBER;
        ld_start_date      DATE;
        ld_end_date        DATE;
        ln_count           NUMBER;
        ln_gapless_seq     NUMBER;
        lv_status          VARCHAR2 (10);
        lv_err_msg         VARCHAR2 (4000);
        ln_reprint_count   NUMBER;
        ln_rerun_max_seq   NUMBER;
        lv_email_address   VARCHAR2 (1000);
        ln_draft_count     NUMBER;
        ln_rerun_count     NUMBER;
        ln_email_count     NUMBER := 0;
    BEGIN
        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXD_GL_TAX_DOC_SEQ_T');

        -- Query to fetch period start date end date.
        BEGIN
            SELECT gp1.period_year, start_date, end_date,
                   period_num
              INTO ln_period_year, ld_start_date, ld_end_date, ln_period_month
              FROM apps.gl_periods gp1
             WHERE     gp1.period_name = pv_period_name
                   AND gp1.period_set_name = 'DO_FY_CALENDAR';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_period_year    := NULL;
                ld_start_date     := NULL;
                ld_end_date       := NULL;
                ln_period_month   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Failed to fetch Period details' || SQLERRM);
        -- pn_retcode := 1;
        END;

        ln_email_count   := 0;

        FOR k IN get_emails
        LOOP
            ln_email_count   := ln_email_count + 1;

            IF ln_email_count = 1
            THEN
                lv_email_address   := k.email_id;
            ELSE
                lv_email_address   := lv_email_address || ',' || k.email_id;
            END IF;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'EMail Address:' || lv_email_address);

        /* BEGIN
             SELECT
                 flv.meaning email_id
             INTO lv_email_address
             FROM
                 fnd_lookup_values flv
             WHERE
                 1 = 1
                 AND flv.lookup_type = 'XXD_GL_TAX_GAPLESS_MAIL_LKP'
                 AND flv.enabled_flag = 'Y'
                 AND flv.language = userenv('LANG')
                 AND trunc(SYSDATE) BETWEEN trunc(nvl(flv.start_date_active, SYSDATE)) AND trunc(nvl(flv.end_date_active, SYSDATE)
                 );

         EXCEPTION
             WHEN OTHERS THEN
                 lv_email_address := NULL;
         END;*/

        IF ld_start_date IS NOT NULL OR ld_end_date IS NOT NULL
        THEN
            ln_count   := 0;

            IF pv_final_mode = 'Draft'
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_draft_count
                      FROM xxdo.xxd_gl_gapless_seq_prg_det_t
                     WHERE     ledger_id = pn_ledger_id
                           AND period_name = pv_period_name
                           AND company_segment = pv_company_segment
                           AND program_mode <> 'Rollback';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_draft_count   := 0;
                END;

                IF NVL (ln_draft_count, 0) > 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Program was ran in Final mode for the period:'
                        || pv_period_name);
                ELSE
                    FOR i IN fetch_eligible_records
                    LOOP
                        ln_count   := ln_count + 1;

                        --1.1 changes start
                        IF ln_count < 100000
                        THEN
                            ln_gapless_seq   :=
                                   pv_company_segment
                                || ln_period_month
                                || ln_period_year
                                || LPAD (ln_count, 5, 0);
                        ELSE
                            --1.1 changes end
                            ln_gapless_seq   :=
                                   pv_company_segment
                                || ln_period_month
                                || ln_period_year
                                || ln_count;
                        END IF;                                         -- 1.1

                        FOR J IN fetch_eligible_line_records (i.je_header_id)
                        LOOP
                            BEGIN
                                INSERT INTO xxdo.xxd_gl_tax_doc_seq_t
                                         VALUES (i.ledger_name,
                                                 i.journal_name,
                                                 i.journal_date,
                                                 i.journal_category,
                                                 i.journal_source,
                                                 i.journal_desc,
                                                 i.gl_date,
                                                 i.document_number,
                                                 ln_gapless_seq,
                                                 i.period_name,
                                                 i.sort_by,
                                                 gn_user_id,
                                                 SYSDATE,
                                                 gn_request_id,
                                                 i.ledger_id,
                                                 i.source,
                                                 i.category,
                                                 i.je_header_id,
                                                 j.je_line_num,
                                                 lv_email_address);

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Failed to insert the data into custom table:'
                                        || SQLERRM);
                            END;
                        END LOOP;
                    END LOOP;
                END IF;
            ELSIF pv_final_mode = 'Final'
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_draft_count
                      FROM xxdo.xxd_gl_gapless_seq_prg_det_t
                     WHERE     ledger_id = pn_ledger_id
                           AND period_name = pv_period_name
                           AND company_segment = pv_company_segment
                           AND program_mode <> 'Rollback';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_draft_count   := 0;
                END;

                IF NVL (ln_draft_count, 0) > 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Program was not ran in Final mode for the period:'
                        || pv_period_name);
                ELSE
                    FOR i IN fetch_eligible_records
                    LOOP
                        ln_count   := ln_count + 1;

                        --1.1 changes start
                        IF ln_count < 100000
                        THEN
                            ln_gapless_seq   :=
                                   pv_company_segment
                                || ln_period_month
                                || ln_period_year
                                || LPAD (ln_count, 5, 0);
                        ELSE
                            --1.1 changes end
                            ln_gapless_seq   :=
                                   pv_company_segment
                                || ln_period_month
                                || ln_period_year
                                || ln_count;
                        END IF;

                        FOR J IN fetch_eligible_line_records (i.je_header_id)
                        LOOP
                            BEGIN
                                -- Insert the records in custom table
                                INSERT INTO xxdo.xxd_gl_tax_doc_seq_t
                                         VALUES (i.ledger_name,
                                                 i.journal_name,
                                                 i.journal_date,
                                                 i.journal_category,
                                                 i.journal_source,
                                                 i.journal_desc,
                                                 i.gl_date,
                                                 i.document_number,
                                                 ln_gapless_seq,
                                                 i.period_name,
                                                 i.sort_by,
                                                 gn_user_id,
                                                 SYSDATE,
                                                 gn_request_id,
                                                 i.ledger_id,
                                                 i.source,
                                                 i.category,
                                                 i.je_header_id,
                                                 j.je_line_num,
                                                 lv_email_address);

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Failed to insert the data into custom table:'
                                        || SQLERRM);
                            END;

                            -- Update the Gapless sequence in ap_invoices_all table.

                            BEGIN
                                UPDATE apps.gl_je_lines
                                   SET attribute10 = ln_gapless_seq, context = 'Italy Gapless Doc Sequence', last_updated_by = gn_user_id,
                                       last_update_date = SYSDATE
                                 WHERE     je_header_id = i.je_header_id
                                       AND je_line_num = j.je_line_num;

                                COMMIT;
                                lv_status   := 'S';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Updation of Gapless sequence failed for the header_id:'
                                        || i.je_header_id);
                                    lv_status   := 'E';
                                    lv_err_msg   :=
                                           lv_err_msg
                                        || ' Updation of Gapless sequence failed for the header_id:'
                                        || i.je_header_id;
                            END;
                        END LOOP;
                    END LOOP;

                    -- insert the program run details in custom table

                    BEGIN
                        INSERT INTO xxdo.xxd_gl_gapless_seq_prg_det_t
                             VALUES (pn_ledger_id, pv_period_name, pv_company_segment, NULL, NULL, ln_count, 'GL', gn_user_id, SYSDATE, gn_user_id, SYSDATE, pv_final_mode
                                     , lv_status, lv_err_msg, gn_request_id);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Inserting the program run details into custom table failed:'
                                || SQLERRM);
                    END;
                END IF;
            ELSIF pv_final_mode = 'Reprint'
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_reprint_count
                      FROM xxdo.xxd_gl_gapless_seq_prg_det_t
                     WHERE     ledger_id = pn_ledger_id
                           AND period_name = pv_period_name
                           AND company_segment = pv_company_segment
                           AND program_mode <> 'Rollback';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_reprint_count   := 0;
                END;

                IF NVL (ln_reprint_count, 0) = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Program was not ran in Final mode for the period:'
                        || pv_period_name);
                ELSE
                    FOR i IN fetch_reprint_records
                    LOOP
                        BEGIN
                            INSERT INTO xxdo.xxd_gl_tax_doc_seq_t
                                 VALUES (i.ledger_name, i.journal_name, i.journal_date, i.journal_category, i.journal_source, i.journal_desc, i.gl_date, i.document_number, i.gapless_seq_no, i.period_name, i.sort_by, gn_user_id, SYSDATE, gn_request_id, i.ledger_id, i.source, i.category, i.je_header_id
                                         , i.je_line_num, lv_email_address);

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to insert the data into custom table:'
                                    || SQLERRM);
                        END;
                    END LOOP;
                END IF;                                                     --
            -- Rollback mode

            ELSIF pv_final_mode = 'Rollback'
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_reprint_count
                      FROM xxdo.xxd_gl_gapless_seq_prg_det_t
                     WHERE     ledger_id = pn_ledger_id
                           AND period_name = pv_period_name
                           AND company_segment = pv_company_segment
                           AND program_mode <> 'Rollback';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_reprint_count   := 0;
                END;

                IF NVL (ln_reprint_count, 0) = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Program was not ran in Final mode for the period:'
                        || pv_period_name);
                ELSE
                    FOR i IN fetch_reprint_records
                    LOOP
                        -- Update the Gapless sequence in ap_invoices_all table.
                        BEGIN
                            UPDATE apps.gl_je_lines
                               SET attribute10 = '', last_updated_by = gn_user_id, last_update_date = SYSDATE
                             WHERE     je_header_id = i.je_header_id
                                   AND je_line_num = i.je_line_num;

                            COMMIT;
                            lv_status   := 'S';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updation of Gapless sequence failed for the je_header_id:'
                                    || i.je_header_id
                                    || SQLERRM);

                                lv_status   := 'E';
                                lv_err_msg   :=
                                       lv_err_msg
                                    || ' Updation of Gapless sequence failed for the je_header_id:'
                                    || i.je_header_id;
                        END;

                        BEGIN
                            -- Insert the records in custom table
                            INSERT INTO xxdo.xxd_gl_tax_doc_seq_t
                                 VALUES (i.ledger_name, i.journal_name, i.journal_date, i.journal_category, i.journal_source, i.journal_desc, i.gl_date, i.document_number, NULL, i.period_name, i.sort_by, gn_user_id, SYSDATE, gn_request_id, i.ledger_id, i.source, i.category, i.je_header_id
                                         , i.je_line_num, lv_email_address);

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to insert the data into custom table:'
                                    || SQLERRM);
                        END;
                    END LOOP;


                    -- insert the program run details in custom table

                    BEGIN
                        UPDATE xxdo.xxd_gl_gapless_seq_prg_det_t
                           SET program_mode = pv_final_mode, last_updated_by = gn_user_id, last_update_date = SYSDATE
                         WHERE     ledger_id = pn_ledger_id
                               AND period_name = pv_period_name
                               AND company_segment = pv_company_segment;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updation  failed for the Period:'
                                || pv_period_name
                                || SQLERRM);
                    END;
                END IF;
            -- Rollback mode
            -- rerun draft

            ELSIF pv_final_mode = 'Rerun Draft'
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_rerun_count
                      FROM xxdo.xxd_gl_gapless_seq_prg_det_t
                     WHERE     ledger_id = pn_ledger_id
                           AND period_name = pv_period_name
                           AND company_segment = pv_company_segment
                           AND program_mode <> 'Rollback';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_rerun_count   := 0;
                END;

                IF NVL (ln_rerun_count, 0) = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Program was not ran in Final mode for the period:'
                        || pv_period_name);
                ELSE
                    BEGIN
                        SELECT MAX (NVL (max_gapless_seq, 0))
                          INTO ln_rerun_max_seq
                          FROM xxdo.xxd_gl_gapless_seq_prg_det_t
                         WHERE     ledger_id = pn_ledger_id
                               AND period_name = pv_period_name
                               AND company_segment = pv_company_segment
                               AND program_mode <> 'Rollback';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_rerun_max_seq   := 0;
                    END;

                    ln_count   := ln_rerun_max_seq;

                    FOR i IN fetch_rerun_records
                    LOOP
                        ln_count   := ln_count + 1;

                        --1.1 changes start
                        IF ln_count < 100000
                        THEN
                            ln_gapless_seq   :=
                                   pv_company_segment
                                || ln_period_month
                                || ln_period_year
                                || LPAD (ln_count, 5, 0);
                        ELSE
                            --1.1 changes end
                            ln_gapless_seq   :=
                                   pv_company_segment
                                || ln_period_month
                                || ln_period_year
                                || ln_count;
                        END IF;                                         -- 1.1

                        FOR J IN fetch_eligible_line_records (i.je_header_id)
                        LOOP
                            BEGIN
                                INSERT INTO xxdo.xxd_gl_tax_doc_seq_t
                                         VALUES (i.ledger_name,
                                                 i.journal_name,
                                                 i.journal_date,
                                                 i.journal_category,
                                                 i.journal_source,
                                                 i.journal_desc,
                                                 i.gl_date,
                                                 i.document_number,
                                                 ln_gapless_seq,
                                                 i.period_name,
                                                 i.sort_by,
                                                 gn_user_id,
                                                 SYSDATE,
                                                 gn_request_id,
                                                 i.ledger_id,
                                                 i.source,
                                                 i.category,
                                                 i.je_header_id,
                                                 j.je_line_num,
                                                 lv_email_address);

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Failed to insert the data into custom table:'
                                        || SQLERRM);
                            END;
                        END LOOP;
                    END LOOP;
                END IF;
            -- rerun draft
            -- rerun final

            ELSIF pv_final_mode = 'Rerun Final'
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_rerun_count
                      FROM xxdo.xxd_gl_gapless_seq_prg_det_t
                     WHERE     ledger_id = pn_ledger_id
                           AND period_name = pv_period_name
                           AND company_segment = pv_company_segment
                           AND program_mode <> 'Rollback';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_rerun_count   := 0;
                END;

                IF NVL (ln_rerun_count, 0) = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Program was not ran in Final mode for the period:'
                        || pv_period_name);
                ELSE
                    BEGIN
                        SELECT MAX (NVL (max_gapless_seq, 0))
                          INTO ln_rerun_max_seq
                          FROM xxdo.xxd_gl_gapless_seq_prg_det_t
                         WHERE     ledger_id = pn_ledger_id
                               AND period_name = pv_period_name
                               AND company_segment = pv_company_segment
                               AND program_mode <> 'Rollback';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_rerun_max_seq   := 0;
                    END;

                    ln_count   := 0;
                    ln_count   := ln_rerun_max_seq;

                    FOR i IN fetch_rerun_records
                    LOOP
                        ln_count   := ln_count + 1;

                        --1.1 changes start
                        IF ln_count < 100000
                        THEN
                            ln_gapless_seq   :=
                                   pv_company_segment
                                || ln_period_month
                                || ln_period_year
                                || LPAD (ln_count, 5, 0);
                        ELSE
                            --1.1 changes end
                            ln_gapless_seq   :=
                                   pv_company_segment
                                || ln_period_month
                                || ln_period_year
                                || ln_count;
                        END IF;                                         -- 1.1

                        FOR J IN fetch_eligible_line_records (i.je_header_id)
                        LOOP
                            BEGIN
                                INSERT INTO xxdo.xxd_gl_tax_doc_seq_t
                                         VALUES (i.ledger_name,
                                                 i.journal_name,
                                                 i.journal_date,
                                                 i.journal_category,
                                                 i.journal_source,
                                                 i.journal_desc,
                                                 i.gl_date,
                                                 i.document_number,
                                                 ln_gapless_seq,
                                                 i.period_name,
                                                 i.sort_by,
                                                 gn_user_id,
                                                 SYSDATE,
                                                 gn_request_id,
                                                 i.ledger_id,
                                                 i.source,
                                                 i.category,
                                                 i.je_header_id,
                                                 j.je_line_num,
                                                 lv_email_address);

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Failed to insert the data into custom table:'
                                        || SQLERRM);
                            END;

                            -- Update the Gapless sequence in ap_invoices_all table.

                            BEGIN
                                UPDATE apps.gl_je_lines
                                   SET attribute10 = ln_gapless_seq, context = 'Italy Gapless Doc Sequence', last_updated_by = gn_user_id,
                                       last_update_date = SYSDATE
                                 WHERE     je_header_id = i.je_header_id
                                       AND je_line_num = j.je_line_num;

                                COMMIT;
                                lv_status   := 'S';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Updation of Gapless sequence failed for the je_header_id:'
                                        || i.je_header_id);
                                    lv_status   := 'E';
                                    lv_err_msg   :=
                                           lv_err_msg
                                        || ' Updation of Gapless sequence failed for the je_header_id:'
                                        || i.je_header_id;
                            END;
                        END LOOP;
                    END LOOP;

                    -- insert the program run details in custom table

                    BEGIN
                        INSERT INTO xxdo.xxd_gl_gapless_seq_prg_det_t
                             VALUES (pn_ledger_id, pv_period_name, pv_company_segment, NULL, NULL, ln_count, 'GL', gn_user_id, SYSDATE, gn_user_id, SYSDATE, pv_final_mode
                                     , lv_status, lv_err_msg, gn_request_id);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Inserting the program run details into custom table failed:'
                                || SQLERRM);
                    END;
                END IF;
            -- rerun final


            END IF;                          --IF pv_final_mode = 'Draft' THEN
        ELSE                    -- IF ld_start_date or ld_end_date IS NOT NULL
            fnd_file.put_line (fnd_file.LOG,
                               'Failed to fetch Period details' || SQLERRM);
        END IF;
    END fetch_eligible_records_prc;

    -- =====================================================================================================
    -- This procedure is Main procedure calling from concurrent program: Deckers AP Tax Authority Document Sequence Generation Program
    -- =====================================================================================================

    FUNCTION xml_main (pv_ledger_name IN NUMBER, pv_period_name IN VARCHAR2, pv_company_segment IN VARCHAR2
                       , pv_final_mode IN VARCHAR2)
        RETURN BOOLEAN
    AS
        x_errbuf    VARCHAR2 (4000);
        x_retcode   NUMBER;
    BEGIN
        -- Printing all the parameters
        fnd_file.put_line (
            fnd_file.LOG,
            'Deckers GL Tax Authority Document Sequence Generation Program.....');
        fnd_file.put_line (fnd_file.LOG, 'Parameters Are.....');
        fnd_file.put_line (fnd_file.LOG, '-------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'pv_ledger_name        :' || pv_ledger_name);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_period_name        :' || pv_period_name);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_company_segment    :' || pv_company_segment);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_final_mode         :' || pv_final_mode);



        -- Procedure to fetch and insert all the eligible records
        fetch_eligible_records_prc (pv_ledger_name, pv_period_name, pv_company_segment
                                    , pv_final_mode);
        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'sqlerrm:' || SQLERRM);
            RETURN (TRUE);
    END xml_main;
END;
/
