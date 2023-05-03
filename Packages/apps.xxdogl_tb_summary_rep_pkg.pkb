--
-- XXDOGL_TB_SUMMARY_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOGL_TB_SUMMARY_REP_PKG"
AS
    /***************************************************************************************
    * Program Name : XXDOGL_TB_SUMMARY_REP_PKG                                             *
    * Language     : PL/SQL                                                                *
    * Description  : Package to generate tab-delimited text files with TB Summary at the   *
    *                company and account level                                             *
    * History      :                                                                       *
    *                                                                                      *
    * WHO          :       WHAT      Desc                                    WHEN          *
    * -------------- ----------------------------------------------------------------------*
    * Madhav Dhurjaty      1.0      Initial Version                         06-DEC-2017    *
    * -------------------------------------------------------------------------------------*/
    ----
    PROCEDURE print_out (p_msg IN VARCHAR2)
    IS
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.OUTPUT, p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in print_out:' || SQLERRM);
    END print_out;

    ----
    PROCEDURE print_log (p_msg IN VARCHAR2)
    IS
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in print_log:' || SQLERRM);
    END print_log;

    ----
    ----
    --This procedure checks if given file exists or not in the directory
    --Parameters
    --p_file_dir    --Directory to look for file --IN Parameter --Mandatory
    --p_file_name   --File to be checked in the directory --IN Parameter --Mandatory
    --x_file_exists --If file exists in directory, TRUE is returned else FALSE --OUT Parameter
    --x_file_lenght --If file exists return the length of the file in bytes else NULL --OUT Parameter
    --x_block_size  --If file exists return the filesystem block size in bytes else NULL --OUT Parameter
    PROCEDURE check_file_exists (p_file_path     IN     VARCHAR2,
                                 p_file_name     IN     VARCHAR2,
                                 x_file_exists      OUT BOOLEAN,
                                 x_file_length      OUT NUMBER,
                                 x_block_size       OUT BINARY_INTEGER)
    IS
        lv_proc_name     VARCHAR2 (30) := 'CHECK_FILE_EXISTS';
        lb_file_exists   BOOLEAN := FALSE;
        ln_file_length   NUMBER := NULL;
        ln_block_size    BINARY_INTEGER := NULL;
        lv_err_msg       VARCHAR2 (2000) := NULL;
    BEGIN
        --Checking if p_file_name file exists in p_file_dir directory
        --If exists, x_file_exists is true else false
        UTL_FILE.FGETATTR (location      => p_file_path,
                           filename      => p_file_name,
                           fexists       => lb_file_exists,
                           file_length   => ln_file_length,
                           block_size    => ln_block_size);
        x_file_exists   := lb_file_exists;
        x_file_length   := ln_file_length;
        x_block_size    := ln_block_size;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_file_exists   := lb_file_exists;
            x_file_length   := ln_file_length;
            x_block_size    := ln_block_size;
            lv_err_msg      :=
                SUBSTR (
                       'When Others expection while checking file is created or not in '
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            print_log (lv_err_msg);
    END check_file_exists;

    ----
    /*
    FUNCTION before_report
    RETURN BOOLEAN
    IS
    BEGIN
      RETURN NULL;
    EXCEPTION
      WHEN OTHERS
      THEN
        print_log ('Error in before_report:'||SQLERRM);
    END before_report;
    ----
    FUNCTION after_report
    RETURN BOOLEAN
    IS
    BEGIN
      RETURN NULL;
    EXCEPTION
      WHEN OTHERS
      THEN
        print_log ('Error in after_report:'||SQLERRM);
    END after_report;
    */
    FUNCTION get_first_period (p_ledger_id     IN NUMBER,
                               p_period_name   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_first_period   VARCHAR2 (30);
    BEGIN
        SELECT a.period_name
          INTO lv_first_period
          FROM gl_period_statuses a, gl_period_statuses b
         WHERE     a.application_id = 101
               AND b.application_id = 101
               AND a.ledger_id = p_ledger_id
               AND b.ledger_id = p_ledger_id
               AND a.period_type = b.period_type
               AND a.period_year = b.period_year
               --AND a.quarter_num = b.quarter_num
               AND b.period_name = p_period_name
               AND a.period_num =
                   (  SELECT MIN (c.period_num)
                        FROM gl_period_statuses c
                       WHERE     c.application_id = 101
                             AND c.ledger_id = p_ledger_id
                             AND c.period_year = a.period_year
                             -- AND c.quarter_num = a.quarter_num
                             AND c.period_type = a.period_type
                    GROUP BY c.period_year                    --,c.quarter_num
                                          );

        RETURN lv_first_period;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                   'Error in getting first_period for ledger id:'
                || p_ledger_id
                || '-'
                || p_period_name
                || ':'
                || SQLERRM);
            RETURN NULL;
    END get_first_period;

    ----
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_access_set_id IN NUMBER, p_ledger_name IN VARCHAR2, p_ledger_id IN NUMBER, p_chart_of_accounts_id IN NUMBER, p_legal_entity_id IN NUMBER, p_ledger_currency IN VARCHAR2, p_period_from IN VARCHAR2
                    --,p_period_to            IN  VARCHAR2
                    , p_file_path IN VARCHAR2, p_file_name IN VARCHAR2)
    IS
        CURSOR c_bal (p_ledger_id IN NUMBER, p_company_code IN VARCHAR2, p_from_period IN VARCHAR2
                      , p_ledger_currency IN VARCHAR2)
        IS
              SELECT gcc.segment1 company_code, gcc.segment6 natural_account, --bal.begin_balance_dr - bal.begin_balance_cr,
                                                                              --XXDOGL_TB_SUMMARY_REP_PKG.get_first_period (bal.ledger_id, bal.period_name) first_period,
                                                                              SUM (DECODE (bal.period_name, xxdogl_tb_summary_rep_pkg.get_first_period (bal.ledger_id, bal.period_name), NVL (bal.begin_balance_dr, 0) - NVL (bal.begin_balance_cr, 0), 0)) begin_balance,
                     --DECODE(BAL.PERIOD_NAME, XXDOGL_TB_SUMMARY_REP_PKG.get_first_period (bal.ledger_id, bal.period_name), NVL(bal.BEGIN_BALANCE_DR,0) + NVL(bal.PERIOD_NET_DR,0),0) period_dr,
                     --DECODE(BAL.PERIOD_NAME, XXDOGL_TB_SUMMARY_REP_PKG.get_first_period (bal.ledger_id, bal.period_name), NVL(bal.BEGIN_BALANCE_cR,0) + NVL(bal.PERIOD_NET_cR,0),0) period_cr,
                     SUM ((DECODE (bal.period_name, xxdogl_tb_summary_rep_pkg.get_first_period (bal.ledger_id, bal.period_name), NVL (bal.begin_balance_dr, 0) - NVL (bal.begin_balance_cr, 0), 0) + bal.period_net_dr - bal.period_net_cr)) ending_balance
                --, bal.*
                FROM apps.gl_balances bal, apps.gl_period_statuses gps, apps.gl_code_combinations gcc,
                     apps.gl_ledgers gll
               WHERE     1 = 1
                     AND bal.code_combination_id = gcc.code_combination_id
                     AND bal.ledger_id = gll.ledger_id                      --
                     AND bal.period_year = gps.period_year
                     AND bal.period_num <= gps.period_num
                     AND gps.application_id = 101
                     AND bal.ledger_id = gps.ledger_id
                     AND (   bal.ledger_id = p_ledger_id
                          OR bal.ledger_id IN
                                 (SELECT LEDGER_ID
                                    FROM GL_LEDGER_SET_NORM_ASSIGN_V
                                   WHERE ledger_set_id = p_ledger_id))
                     AND gps.period_name = p_from_period
                     AND gcc.segment1 = NVL (p_company_code, gcc.segment1)
                     --AND   gcc.segment6 = '10999'
                     AND gcc.template_id IS NULL
                     AND bal.actual_flag = 'A'
                     --AND   bal.currency_code = p_ledger_currency
                     AND bal.currency_code =
                         NVL (
                             p_ledger_currency,
                             GL_LEDGER_UTILS_PKG.GET_DEFAULT_LEDGER_CURRENCY (
                                 gll.short_name))
            GROUP BY gcc.segment1, gcc.segment6
            ORDER BY 1, 2;

        /*
        SELECT
            gcc.segment1 company_code,
            gcc.segment6 natural_account,
            SUM(DECODE(bal.period_name, get_first_period (bal.ledger_id, bal.period_name), NVL(bal.begin_balance_dr,0) - NVL(bal.begin_balance_cr,0),0)) BEGIN_BALANCE,
            SUM(DECODE(bal.period_name, get_first_period (bal.ledger_id, bal.period_name), NVL(bal.begin_balance_dr,0) + NVL(bal.period_net_dr,0),0)) PERIOD_DR,
            SUM(DECODE(bal.period_name, get_first_period (bal.ledger_id, bal.period_name),  NVL(bal.begin_balance_cr,0) + NVL(bal.period_net_cr, 0), 0)
            - DECODE(bal.period_name, get_first_period (bal.ledger_id, bal.period_name), NVL(bal.begin_balance_cr,0), 0)) PERIOD_CR,
            --SUM(DECODE(bal.period_name, get_first_period (bal.ledger_id, bal.period_name), (nvl(bal.period_net_dr,0) ),0) ) accounted_dr,
            --SUM(DECODE(bal.period_name, get_first_period (bal.ledger_id, bal.period_name), (nvl(bal.period_net_dr,0) ),0) ) accounted_cr,
            SUM (NVL(bal.begin_balance_dr,0) + NVL(bal.period_net_dr,0)) accounted_dr,
            SUM (NVL(bal.begin_balance_cr,0) + NVL(bal.period_net_cr,0)) accounted_cr
             --, bal.period_net_dr
             --, bal.period_net_cr
        FROM
            apps.gl_balances bal,
            apps.gl_code_combinations gcc,
            apps.gl_ledgers gll
        WHERE
            1 = 1
            AND   bal.code_combination_id = gcc.code_combination_id
            AND   bal.currency_code = gll.currency_code
            AND   gcc.summary_flag = 'N'
            AND   gcc.template_id IS NULL
            AND   gll.ledger_id = p_ledger_id
            AND   gcc.segment1 = NVL(p_company_code, gcc.segment1)
            AND   bal.ledger_id = gll.ledger_id
            --AND   bal.period_name = p_from_period
            AND   bal.period_name IN (
                SELECT
                    period_name
                FROM
                    gl_periods per
                WHERE
                    per.period_set_name = gll.period_set_name
                    AND   per.start_date >= (
                        SELECT
                            per1.start_date
                        FROM
                            gl_periods per1
                        WHERE
                            per1.period_set_name = per.period_set_name
                            AND   per1.period_name =p_from_period
                    )
                    AND   per.end_date <= (
                        SELECT
                            per2.end_date
                        FROM
                            gl_periods per2
                        WHERE
                            per2.period_set_name = per.period_set_name
                            AND   per2.period_name =p_to_period
                    )
            )
        GROUP BY
            gcc.segment1,
            gcc.segment6
        ORDER BY
            1,
            2;*/

        lv_ledger_currency   VARCHAR2 (10) := NULL;
        lv_company_code      VARCHAR2 (10) := NULL;
        lv_first_period      VARCHAR2 (30) := NULL;
        ln_count             NUMBER := 0;
        lv_output_file       UTL_FILE.file_type;
        lv_file_path         VARCHAR2 (360) := p_file_path;
        lv_rec               VARCHAR2 (32767) := NULL;
        lv_tb_summary_file   VARCHAR2 (360) := p_file_name;
        lb_file_exists       BOOLEAN;
        ln_file_length       NUMBER := NULL;
        ln_block_size        NUMBER := NULL;
        lv_file_timestamp    VARCHAR2 (50);
        ln_end_balance       NUMBER := 0;
    BEGIN
        print_log (RPAD ('p_access_set_id', 40) || ':' || p_access_set_id);
        print_log (RPAD ('p_ledger_name', 40) || ':' || p_ledger_name);
        print_log (RPAD ('p_ledger_id', 40) || ':' || p_ledger_id);
        print_log (
               RPAD ('p_chart_of_accounts_id', 40)
            || ':'
            || p_chart_of_accounts_id);
        print_log (
            RPAD ('p_legal_entity_id', 40) || ':' || p_legal_entity_id);
        print_log (
            RPAD ('p_ledger_currency', 40) || ':' || p_ledger_currency);
        print_log (RPAD ('p_period', 40) || ':' || p_period_from);
        --print_log(RPAD('p_period_to',40)||':'||p_period_to);
        print_log (RPAD ('p_file_path', 40) || ':' || p_file_path);
        print_log (RPAD ('p_file_name', 40) || ':' || p_file_name);

        --Get Timestamp for Filename
        BEGIN
            SELECT TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
              INTO lv_file_timestamp
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_log (
                    'Error in getting Timestamp for Filename:' || SQLERRM);
        END;

        --Get Default Ledger Currency
        BEGIN
            SELECT GL_LEDGER_UTILS_PKG.GET_DEFAULT_LEDGER_CURRENCY (p_ledger_name)
              INTO lv_ledger_currency
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_log ('Error in getting ledger currency:' || SQLERRM);
        END;

        IF p_ledger_currency IS NOT NULL
        THEN
            lv_ledger_currency   := p_ledger_currency;
        END IF;

        --Get Balancing Segment Value
        IF p_legal_entity_id IS NOT NULL
        THEN
            BEGIN
                SELECT flex_segment_value
                  INTO lv_company_code
                  FROM apps.gl_legal_entities_bsvs bsv
                 WHERE 1 = 1 AND bsv.legal_entity_id = p_legal_entity_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log (
                           'Error in getting balancing segment value:'
                        || SQLERRM);
            END;
        END IF;

        ----
        lv_tb_summary_file   :=
               lv_tb_summary_file
            || '_'
            || p_ledger_name
            || '_'
            || REPLACE (p_period_from, '-', '');

        ----
        IF lv_file_path IS NOT NULL
        THEN
            lv_output_file   :=
                UTL_FILE.fopen (lv_file_path, lv_tb_summary_file || '_' || lv_file_timestamp || '.tmp', 'W' --opening the file in write mode
                                , 32767);
        END IF;

        --
        FOR r_bal IN c_bal (p_ledger_id => p_ledger_id, p_company_code => lv_company_code, p_from_period => p_period_from
                            , p_ledger_currency => lv_ledger_currency)
        LOOP
            ln_end_balance   := 0;
            ln_count         := ln_count + 1;

            --ln_end_balance := NVL(r_bal.begin_balance,0) + NVL(r_bal.period_dr,0) - NVL(r_bal.period_cr,0);

            lv_rec           :=
                   r_bal.company_code
                || CHR (9)
                || r_bal.natural_account
                || CHR (9)
                || r_bal.begin_balance
                || CHR (9)
                || r_bal.ending_balance--ln_end_balance
                                       ;
            --                     r_bal.accounted_dr ||CHR(9)||
            --                     r_bal.accounted_cr;

            print_out (lv_rec);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.put_line (lv_output_file, lv_rec);
            END IF;
        END LOOP;

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            UTL_FILE.fclose (lv_output_file);

            check_file_exists (
                p_file_path     => lv_file_path,
                p_file_name     =>
                    lv_tb_summary_file || '_' || lv_file_timestamp || '.tmp',
                x_file_exists   => lb_file_exists,
                x_file_length   => ln_file_length,
                x_block_size    => ln_block_size);

            IF lb_file_exists
            THEN
                print_log (
                    'Summary Trial Balance File is successfully created in the directory.');

                UTL_FILE.frename (
                    src_location    => lv_file_path,
                    src_filename    =>
                           lv_tb_summary_file
                        || '_'
                        || lv_file_timestamp
                        || '.tmp',
                    dest_location   => lv_file_path,
                    dest_filename   =>
                           lv_tb_summary_file
                        || '_'
                        || lv_file_timestamp
                        || '.txt',
                    overwrite       => TRUE);
            ELSE
                print_log ('Summary Trial Balance File creation failed.');
            END IF;
        END IF;


        IF ln_count = 0
        THEN
            print_log ('   ***   No Data Found.   ***   ');
        ELSE
            print_log ('Total Record Count :' || ln_count);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error in main:' || SQLERRM);
    END main;
END XXDOGL_TB_SUMMARY_REP_PKG;
/
