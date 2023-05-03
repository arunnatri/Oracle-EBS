--
-- XXD_PO_FCTY_ACC_BAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_FCTY_ACC_BAL_PKG"
IS
      /******************************************************************************************
 NAME           : XXD_PO_FCTY_ACC_BAL_PKG
 REPORT NAME    : Deckers Factory Accrual Balance Report to Black Line

 REVISIONS:
 Date        Author             Version  Description
 ----------  ----------         -------  ---------------------------------------------------
 31-JUL-2021 Damodara Gupta     1.0      Created this package using XXD_PO_FCTY_ACC_BAL_PKG
                                         for sending the report output to BlackLine
*********************************************************************************************/
    -- Global constants
    -- Return Statuses
    gn_user_id      CONSTANT NUMBER := fnd_global.user_id;
    gn_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    gv_delimeter             VARCHAR2 (1) := '|';
    gn_error        CONSTANT NUMBER := 2;
    gn_warning      CONSTANT NUMBER := 1;

    --gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    --gn_org_id            CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    --gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    --gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    --gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    --gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    --gv_ret_unexp_error   CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_unexp_error ;
    --gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    --gn_success           CONSTANT NUMBER := 0;
    --gn_limit_rec         CONSTANT NUMBER := 100;
    --gn_commit_rows       CONSTANT NUMBER := 1000;

    FUNCTION xxd_remove_junk_fnc (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), ''), ',', '')
              INTO lv_output
              FROM DUAL;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END xxd_remove_junk_fnc;


    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
         /***************************************************************************
-- PROCEDURE write_log
-- PURPOSE: This Procedure write the log messages
***************************************************************************/
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in WRITE_LOG Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;


    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'DirList.getList( java.lang.String )' ;

    PROCEDURE load_file_into_tbl (pv_table IN VARCHAR2, pv_dir IN VARCHAR2 DEFAULT 'XXD_FCTY_ACC_BAL_BL_INB_DIR', pv_filename IN VARCHAR2, pv_ignore_headerlines IN INTEGER DEFAULT 1, pv_delimiter IN VARCHAR2 DEFAULT ',', pv_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                  , pv_num_of_columns IN NUMBER)
    IS
               /***************************************************************************
-- PROCEDURE load_file_into_tbl
-- PURPOSE: This Procedure read the data from a CSV file.
-- And load it into the target oracle table.
-- Finally it renames the source file with date.
--
-- PV_FILENAME
-- The name of the flat file(a text file)
--
-- PV_DIRECTORY
-- Name of the directory where the file is been placed.
-- Note: The grant has to be given for the user to the directory
-- before executing the function
--
-- PV_IGNORE_HEADERLINES:
-- Pass the value as '1' to ignore importing headers.
--
-- PV_DELIMITER
-- By default the delimiter is used as ','
-- As we are using CSV file to load the data into oracle
--
-- PV_OPTIONAL_ENCLOSED
-- By default the optionally enclosed is used as '"'
-- As we are using CSV file to load the data into oracle
--
**************************************************************************/
        l_input       UTL_FILE.file_type;

        l_lastLine    VARCHAR2 (4000);
        l_cnames      VARCHAR2 (4000);
        l_bindvars    VARCHAR2 (4000);
        l_status      INTEGER;
        l_cnt         NUMBER DEFAULT 0;
        l_rowCount    NUMBER DEFAULT 0;
        l_sep         CHAR (1) DEFAULT NULL;
        L_ERRMSG      VARCHAR2 (4000);
        V_EOF         BOOLEAN := FALSE;
        l_theCursor   NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert      VARCHAR2 (1100);
    BEGIN
        l_cnt        := 1;

        FOR TAB_COLUMNS
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE     table_name = pv_table
                         AND column_id < pv_num_of_columns
                ORDER BY column_id)
        LOOP
            l_cnames   := l_cnames || tab_columns.column_name || ',';

            l_bindvars   :=
                   l_bindvars
                || CASE
                       WHEN tab_columns.data_type IN ('DATE', 'TIMESTAMP(6)')
                       THEN
                           ':b' || l_cnt || ','
                       ELSE
                           ':b' || l_cnt || ','
                   END;

            l_cnt      := l_cnt + 1;
        END LOOP;

        l_cnames     := RTRIM (l_cnames, ',');
        l_bindvars   := RTRIM (l_bindvars, ',');

        write_log ('Count of Columns is - ' || l_cnt);

        l_input      :=
            UTL_FILE.FOPEN (pv_dir, pv_filename, 'r',
                            32767);

        IF pv_ignore_headerlines > 0
        THEN
            BEGIN
                FOR i IN 1 .. pv_ignore_headerlines
                LOOP
                    write_log ('No of lines Ignored is - ' || i);
                    UTL_FILE.get_line (l_input, l_lastLine);
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_eof   := TRUE;
            END;
        END IF;

        v_insert     :=
               'insert into '
            || pv_table
            || '('
            || l_cnames
            || ') values ('
            || l_bindvars
            || ')';

        IF NOT v_eof
        THEN
            write_log (
                   l_theCursor
                || '-'
                || 'insert into '
                || pv_table
                || '('
                || l_cnames
                || ') values ('
                || l_bindvars
                || ')');

            DBMS_SQL.parse (l_theCursor, v_insert, DBMS_SQL.native);

            LOOP
                BEGIN
                    UTL_FILE.get_line (l_input, l_lastLine);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        EXIT;
                END;

                IF LENGTH (l_lastLine) > 0
                THEN
                    FOR i IN 1 .. l_cnt - 1
                    LOOP
                        DBMS_SQL.bind_variable (
                            l_theCursor,
                            ':b' || i,
                            xxd_remove_junk_fnc (
                                RTRIM (
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (l_lastline, '(^|,)("[^"]*"|[^",]*)', 1
                                                                        , i),
                                                         pv_delimiter),
                                                  pv_optional_enclosed),
                                           pv_delimiter),
                                    pv_optional_enclosed)));
                    END LOOP;

                    BEGIN
                        l_status     := DBMS_SQL.execute (l_theCursor);

                        l_rowCount   := l_rowCount + 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            L_ERRMSG   := SQLERRM;
                    END;
                END IF;
            END LOOP;

            DBMS_SQL.close_cursor (l_theCursor);
            UTL_FILE.fclose (l_input);

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in load_file_into_tbl Procedure -' || SQLERRM);
    END load_file_into_tbl;


    PROCEDURE process_data_prc (pv_period_end_date IN VARCHAR2)
    IS
            /***************************************************************************
-- PROCEDURE process_data_prc
-- PURPOSE: This Procedure update segment information into the STG table
**************************************************************************/
        lv_last_date   VARCHAR2 (50);

        CURSOR cur_val_set_data IS
              SELECT attribute1, attribute2, attribute3,
                     attribute4, attribute5, attribute6,
                     attribute7, attribute8, attribute9,
                     attribute10, attribute11
                FROM apps.fnd_flex_values_vl FFVL
               WHERE     1 = 1
                     AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                         TRUNC (SYSDATE)
                     AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                         TRUNC (SYSDATE)
                     AND ffvl.enabled_flag = 'Y'
                     -- AND ffvl.description = 'FACTORYACC'
                     AND ffvl.flex_value_set_id IN
                             (SELECT flex_value_set_id
                                FROM apps.fnd_flex_value_sets
                               WHERE flex_value_set_name = 'XXD_PO_AAR_GL_VS')
            ORDER BY attribute11 DESC;
    BEGIN
        -- Period end date of the as of date
        SELECT LAST_DAY (TO_DATE (pv_period_end_date, 'RRRR/MM/DD HH24:MI:SS'))
          INTO lv_last_date
          FROM DUAL;

        UPDATE xxdo.xxd_po_fcty_acc_bal_stg_t t1
           SET key3   =
                   (SELECT DECODE (
                               t1.brand,
                               'ALL BRAND', '1000',
                               (SELECT flex_value
                                  FROM fnd_flex_values_vl
                                 WHERE     flex_value_set_id = 1015912
                                       AND UPPER (description) = t1.brand))
                      FROM DUAL)
         WHERE 1 = 1 AND request_id = gn_request_id;

        write_log (
            'Number of Records Updated for BRAND Segment- ' || SQL%ROWCOUNT);

        COMMIT;

        -- IF pv_type = 'FACTORYACC'
        -- THEN

        FOR data_rec IN cur_val_set_data
        LOOP
            -- write_log ('Attribute1:' data_rec.attribute1);
            -- write_log ('Attribute2:' data_rec.attribute2);
            -- write_log ('Attribute3:' data_rec.attribute3);
            -- write_log ('Attribute4:' data_rec.attribute4);

            -- UPDATE the GL Code Combination

            IF (data_rec.attribute1 IS NOT NULL AND data_rec.attribute2 IS NOT NULL AND data_rec.attribute3 IS NOT NULL AND data_rec.attribute4 IS NOT NULL)
            THEN
                BEGIN
                    write_log ('Case1:');

                    UPDATE xxdo.xxd_po_fcty_acc_bal_stg_t
                       SET entity_uniq_identifier = data_rec.attribute5, account_number = data_rec.attribute9-- ,key3 = brand
                                                                                                             , key4 = data_rec.attribute6,
                           key5 = data_rec.attribute7, key6 = data_rec.attribute8, key7 = data_rec.attribute10,
                           key8 = NULL, key9 = NULL, key10 = NULL,
                           period_end_date = lv_last_date, subledr_rep_bal = NULL, subledr_alt_bal = NULL,
                           subledr_acc_bal = invoice_amount
                     WHERE     UPPER (buyer_name) =
                               UPPER (data_rec.attribute1)
                           AND UPPER (buyer_country) =
                               UPPER (data_rec.attribute2)
                           AND UPPER (destination_name) =
                               UPPER (data_rec.attribute3)
                           AND UPPER (destination_country) =
                               UPPER (data_rec.attribute4)
                           AND request_id = gn_request_id;

                    write_log (
                           'Case 1: Number of Records Updated - '
                        || SQL%ROWCOUNT);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Case 1: Error Occured While Updating The Attribtues '
                            || SQLERRM);
                END;
            ELSIF (data_rec.attribute1 IS NOT NULL AND data_rec.attribute2 IS NOT NULL AND data_rec.attribute3 IS NULL AND data_rec.attribute4 IS NOT NULL)
            THEN
                BEGIN
                    write_log ('Case2:');

                    UPDATE xxdo.xxd_po_fcty_acc_bal_stg_t
                       SET entity_uniq_identifier = data_rec.attribute5, account_number = data_rec.attribute9-- ,key3 = brand
                                                                                                             , key4 = data_rec.attribute6,
                           key5 = data_rec.attribute7, key6 = data_rec.attribute8, key7 = data_rec.attribute10,
                           key8 = NULL, key9 = NULL, key10 = NULL,
                           period_end_date = lv_last_date, subledr_rep_bal = NULL, subledr_alt_bal = NULL,
                           subledr_acc_bal = invoice_amount
                     WHERE     UPPER (buyer_name) =
                               UPPER (data_rec.attribute1)
                           AND UPPER (buyer_country) =
                               UPPER (data_rec.attribute2)
                           AND NVL (UPPER (destination_name), 'X1X') <>
                               NVL (UPPER (data_rec.attribute3), 'Y1Y')
                           AND UPPER (destination_country) =
                               UPPER (data_rec.attribute4)
                           AND request_id = gn_request_id;

                    write_log (
                           'Case 2: Number of Records Updated - '
                        || SQL%ROWCOUNT);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Case 2: Error Occured While Updating The Attribtues '
                            || SQLERRM);
                END;
            ELSIF (data_rec.attribute1 IS NOT NULL AND data_rec.attribute2 IS NOT NULL AND data_rec.attribute3 IS NOT NULL AND data_rec.attribute4 IS NULL)
            THEN
                BEGIN
                    write_log ('Case3:');

                    UPDATE xxdo.xxd_po_fcty_acc_bal_stg_t
                       SET entity_uniq_identifier = data_rec.attribute5, account_number = data_rec.attribute9-- ,key3 = brand
                                                                                                             , key4 = data_rec.attribute6,
                           key5 = data_rec.attribute7, key6 = data_rec.attribute8, key7 = data_rec.attribute10,
                           key8 = NULL, key9 = NULL, key10 = NULL,
                           period_end_date = lv_last_date, subledr_rep_bal = NULL, subledr_alt_bal = NULL,
                           subledr_acc_bal = invoice_amount
                     WHERE     UPPER (buyer_name) =
                               UPPER (data_rec.attribute1)
                           AND UPPER (buyer_country) =
                               UPPER (data_rec.attribute2)
                           AND UPPER (destination_name) =
                               UPPER (data_rec.attribute3)
                           AND NVL (UPPER (destination_country), 'X1X') <>
                               NVL (UPPER (data_rec.attribute4), 'Y1Y')
                           AND request_id = gn_request_id;

                    write_log (
                           'Case 3: Number of Records Updated - '
                        || SQL%ROWCOUNT);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Case 3: Error Occured While Updating The Attribtues '
                            || SQLERRM);
                END;
            ELSIF (data_rec.attribute1 IS NOT NULL AND data_rec.attribute2 IS NULL AND data_rec.attribute3 IS NOT NULL AND data_rec.attribute4 IS NOT NULL)
            THEN
                BEGIN
                    write_log ('Case4:');

                    UPDATE xxdo.xxd_po_fcty_acc_bal_stg_t
                       SET entity_uniq_identifier = data_rec.attribute5, account_number = data_rec.attribute9-- ,key3 = brand
                                                                                                             , key4 = data_rec.attribute6,
                           key5 = data_rec.attribute7, key6 = data_rec.attribute8, key7 = data_rec.attribute10,
                           key8 = NULL, key9 = NULL, key10 = NULL,
                           period_end_date = lv_last_date, subledr_rep_bal = NULL, subledr_alt_bal = NULL,
                           subledr_acc_bal = invoice_amount
                     WHERE     UPPER (buyer_name) =
                               UPPER (data_rec.attribute1)
                           AND NVL (UPPER (buyer_country), 'X1X') <>
                               NVL (UPPER (data_rec.attribute2), 'Y1Y')
                           AND UPPER (destination_name) =
                               UPPER (data_rec.attribute3)
                           AND UPPER (destination_country) =
                               UPPER (data_rec.attribute4)
                           AND request_id = gn_request_id;

                    write_log (
                           'Case 4: Number of Records Updated - '
                        || SQL%ROWCOUNT);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Case 4: Error Occured While Updating The Attribtues '
                            || SQLERRM);
                END;
            ELSIF (data_rec.attribute1 IS NOT NULL AND data_rec.attribute2 IS NULL AND data_rec.attribute3 IS NULL AND data_rec.attribute4 IS NOT NULL)
            THEN
                BEGIN
                    write_log ('Case5:');

                    UPDATE xxdo.xxd_po_fcty_acc_bal_stg_t
                       SET entity_uniq_identifier = data_rec.attribute5, account_number = data_rec.attribute9-- ,key3 = brand
                                                                                                             , key4 = data_rec.attribute6,
                           key5 = data_rec.attribute7, key6 = data_rec.attribute8, key7 = data_rec.attribute10,
                           key8 = NULL, key9 = NULL, key10 = NULL,
                           period_end_date = lv_last_date, subledr_rep_bal = NULL, subledr_alt_bal = NULL,
                           subledr_acc_bal = invoice_amount
                     WHERE     UPPER (buyer_name) =
                               UPPER (data_rec.attribute1)
                           AND NVL (UPPER (buyer_country), 'X1X') <>
                               NVL (UPPER (data_rec.attribute2), 'Y1Y')
                           AND NVL (UPPER (destination_name), 'X1X') <>
                               NVL (UPPER (data_rec.attribute3), 'Y1Y')
                           AND UPPER (destination_country) =
                               UPPER (data_rec.attribute4)
                           AND request_id = gn_request_id;

                    write_log (
                           'Case 5: Number of Records Updated - '
                        || SQL%ROWCOUNT);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Case 5: Error Occured While Updating The Attribtues '
                            || SQLERRM);
                END;
            ELSIF (data_rec.attribute1 IS NOT NULL AND data_rec.attribute2 IS NOT NULL AND data_rec.attribute3 IS NULL AND data_rec.attribute4 IS NULL)
            THEN
                BEGIN
                    write_log ('Case6:');

                    UPDATE xxdo.xxd_po_fcty_acc_bal_stg_t
                       SET entity_uniq_identifier = data_rec.attribute5, account_number = data_rec.attribute9-- ,key3 = brand
                                                                                                             , key4 = data_rec.attribute6,
                           key5 = data_rec.attribute7, key6 = data_rec.attribute8, key7 = data_rec.attribute10,
                           key8 = NULL, key9 = NULL, key10 = NULL,
                           period_end_date = lv_last_date, subledr_rep_bal = NULL, subledr_alt_bal = NULL,
                           subledr_acc_bal = invoice_amount
                     WHERE     UPPER (buyer_name) =
                               UPPER (data_rec.attribute1)
                           AND UPPER (buyer_country) =
                               UPPER (data_rec.attribute2)
                           AND NVL (UPPER (destination_name), 'X1X') <>
                               NVL (UPPER (data_rec.attribute3), 'Y1Y')
                           AND NVL (UPPER (destination_country), 'X1X') <>
                               NVL (UPPER (data_rec.attribute4), 'Y1Y')
                           AND request_id = gn_request_id;

                    write_log (
                           'Case 6: Number of Records Updated - '
                        || SQL%ROWCOUNT);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Case 6: Error Occured While Updating The Attribtues '
                            || SQLERRM);
                END;
            ELSIF (data_rec.attribute1 IS NOT NULL AND data_rec.attribute2 IS NULL AND data_rec.attribute3 IS NOT NULL AND data_rec.attribute4 IS NULL)
            THEN
                BEGIN
                    write_log ('Case7:');

                    UPDATE xxdo.xxd_po_fcty_acc_bal_stg_t
                       SET entity_uniq_identifier = data_rec.attribute5, account_number = data_rec.attribute9-- ,key3 = brand
                                                                                                             , key4 = data_rec.attribute6,
                           key5 = data_rec.attribute7, key6 = data_rec.attribute8, key7 = data_rec.attribute10,
                           key8 = NULL, key9 = NULL, key10 = NULL,
                           period_end_date = lv_last_date, subledr_rep_bal = NULL, subledr_alt_bal = NULL,
                           subledr_acc_bal = invoice_amount
                     WHERE     UPPER (buyer_name) =
                               UPPER (data_rec.attribute1)
                           AND NVL (UPPER (buyer_country), 'X1X') <>
                               NVL (UPPER (data_rec.attribute2), 'Y1Y')
                           AND UPPER (destination_name) =
                               UPPER (data_rec.attribute3)
                           AND NVL (UPPER (destination_country), 'X1X') <>
                               NVL (UPPER (data_rec.attribute4), 'Y1Y')
                           AND request_id = gn_request_id;

                    write_log (
                           'Case 7: Number of Records Updated - '
                        || SQL%ROWCOUNT);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Case 7: Error Occured While Updating The Attribtues '
                            || SQLERRM);
                END;
            ELSIF (data_rec.attribute1 IS NOT NULL AND data_rec.attribute2 IS NULL AND data_rec.attribute3 IS NULL AND data_rec.attribute4 IS NULL)
            THEN
                BEGIN
                    write_log ('Case8:');

                    UPDATE xxdo.xxd_po_fcty_acc_bal_stg_t
                       SET entity_uniq_identifier = data_rec.attribute5, account_number = data_rec.attribute9-- ,key3 = brand
                                                                                                             , key4 = data_rec.attribute6,
                           key5 = data_rec.attribute7, key6 = data_rec.attribute8, key7 = data_rec.attribute10,
                           key8 = NULL, key9 = NULL, key10 = NULL,
                           period_end_date = lv_last_date, subledr_rep_bal = NULL, subledr_alt_bal = NULL,
                           subledr_acc_bal = invoice_amount
                     WHERE     UPPER (buyer_name) =
                               UPPER (data_rec.attribute1)
                           AND NVL (UPPER (buyer_country), 'X1X') <>
                               NVL (UPPER (data_rec.attribute2), 'Y1Y')
                           AND NVL (UPPER (destination_name), 'X1X') <>
                               NVL (UPPER (data_rec.attribute3), 'Y1Y')
                           AND NVL (UPPER (destination_country), 'X1X') <>
                               NVL (UPPER (data_rec.attribute4), 'Y1Y')
                           AND request_id = gn_request_id;

                    write_log (
                           'Case 8: Number of Records Updated - '
                        || SQL%ROWCOUNT);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Case 8: Error Occured While Updating The Attribtues '
                            || SQLERRM);
                END;
            END IF;
        END LOOP;
    -- END IF;

    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                'Error Occurred in Procedure process_data_prc: ' || SQLERRM);
    END process_data_prc;

    PROCEDURE write_fcty_recon_file (pv_file_path IN VARCHAR2)
    IS
            /***************************************************************************
-- PROCEDURE write_fcty_recon_file
-- PURPOSE: This Procedure generate the output and write the file
-- into BlackLine directory
**************************************************************************/
        CURSOR fcty_reconcilation IS
              SELECT entity_uniq_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || TO_CHAR (Period_End_Date, 'MM/DD/RRRR') || CHR (9) || Subledr_Rep_Bal || CHR (9) || Subledr_alt_Bal || CHR (9) || SUM (Subledr_Acc_Bal) * -1 line
                FROM xxdo.xxd_po_fcty_acc_bal_stg_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     -- AND pv_type = 'FACTORYACC'
                     AND    buyer_name
                         || buyer_country
                         || seller_name
                         || invoice_number
                         || payment_initiation_type
                         || invoice_issue_date
                         || invoice_status
                         || po_number
                         || brand
                         || invoice_total_qty
                         || invoice_amount
                         || pod_compliance_date
                         || incosat_date
                         || destination_name
                         || destination_country
                         || estimated_departure_date
                         || estimated_arrival_date
                         || future_attr1
                         || future_attr2
                         || future_attr3
                         || future_attr4
                         || future_attr5
                         || future_attr6
                         || future_attr7
                         || future_attr8
                         || future_attr9
                         || future_attr10
                             IS NOT NULL
            GROUP BY entity_uniq_identifier, account_number, key3,
                     key4, key5, key6,
                     key7, key8, key9,
                     key10, period_end_date, subledr_rep_bal,
                     subledr_alt_bal;

        --DEFINE VARIABLES
        lv_file_path              VARCHAR2 (360);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        l_line                    VARCHAR2 (4000);
    BEGIN
        FOR i IN fcty_reconcilation
        LOOP
            l_line   := i.line;
            fnd_file.put_line (fnd_file.output, l_line);
        END LOOP;


        IF pv_file_path IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute2, ffvl.attribute4
                  INTO lv_vs_file_path, lv_vs_file_name
                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                 WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND fvs.flex_value_set_name =
                           'XXD_GL_AAR_FILE_DETAILS_VS'
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.description = 'FACTORYACC'
                       AND ffvl.flex_value = pv_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

            IF     lv_vs_file_name IS NOT NULL
               AND NVL (lv_vs_file_path, 'X') <> 'NA'
            THEN
                IF lv_vs_file_path IS NOT NULL
                THEN
                    lv_file_path   := lv_vs_file_path;
                ELSE
                    BEGIN
                        SELECT ffvl.description
                          INTO lv_vs_default_file_path
                          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                         WHERE     fvs.flex_value_set_id =
                                   ffvl.flex_value_set_id
                               AND fvs.flex_value_set_name =
                                   'XXD_AAR_GL_BL_FILE_PATH_VS'
                               AND NVL (TRUNC (ffvl.start_date_active),
                                        TRUNC (SYSDATE)) <=
                                   TRUNC (SYSDATE)
                               AND NVL (TRUNC (ffvl.end_date_active),
                                        TRUNC (SYSDATE)) >=
                                   TRUNC (SYSDATE)
                               AND ffvl.enabled_flag = 'Y';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_vs_default_file_path   := NULL;
                    END;

                    lv_file_path   := lv_vs_default_file_path;
                END IF;

                -- WRITE INTO BL FOLDER

                lv_outbound_file   :=
                       lv_vs_file_name
                    || '_'
                    -- || pv_type
                    -- || '-'
                    || gn_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';

                fnd_file.put_line (fnd_file.LOG,
                                   'BL File Name is - ' || lv_outbound_file);

                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                       ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN fcty_reconcilation
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg   :=
                        SUBSTR (
                               'Error in Opening the Account Balance data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    write_log (lv_err_msg);
                    RETURN;
                END IF;

                UTL_FILE.fclose (lv_output_file);
            END IF;
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            raise_application_error (-20109, lv_err_msg);
    END write_fcty_recon_file;


    PROCEDURE write_op_file (pv_file_path         IN VARCHAR2,
                             pv_period_end_date   IN VARCHAR2)
    IS
               /***************************************************************************
-- PROCEDURE write_op_file
-- PURPOSE: This Procedure generate the output and write the file
-- into Subledger directory
**************************************************************************/
        CURSOR op_file_fcty IS
              SELECT line
                FROM (SELECT 1 AS seq, buyer_name || gv_delimeter || buyer_country || gv_delimeter || seller_name || gv_delimeter || invoice_number || gv_delimeter || payment_initiation_type || gv_delimeter || invoice_issue_date || gv_delimeter || invoice_status || gv_delimeter || po_number || gv_delimeter || brand || gv_delimeter || invoice_total_qty || gv_delimeter || invoice_amount || gv_delimeter || pod_compliance_date || gv_delimeter || incosat_date || gv_delimeter || destination_name || gv_delimeter || destination_country || gv_delimeter || estimated_departure_date || gv_delimeter || estimated_arrival_date line
                        FROM xxdo.xxd_po_fcty_acc_bal_stg_t
                       WHERE     1 = 1
                             AND request_id = gn_request_id
                             AND    buyer_name
                                 || buyer_country
                                 || seller_name
                                 || invoice_number
                                 || payment_initiation_type
                                 || invoice_issue_date
                                 || invoice_status
                                 || po_number
                                 || brand
                                 || invoice_total_qty
                                 || invoice_amount
                                 || pod_compliance_date
                                 || incosat_date
                                 || destination_name
                                 || destination_country
                                 || estimated_departure_date
                                 || estimated_arrival_date
                                 || future_attr1
                                 || future_attr2
                                 || future_attr3
                                 || future_attr4
                                 || future_attr5
                                 || future_attr6
                                 || future_attr7
                                 || future_attr8
                                 || future_attr9
                                 || future_attr10
                                     IS NOT NULL
                      UNION
                      SELECT 2 AS seq, 'Buyer Name' || gv_delimeter || 'Buyer Country' || gv_delimeter || 'Seller Name' || gv_delimeter || 'Invoice Number' || gv_delimeter || 'Payment Initiation Type' || gv_delimeter || 'Invoice Issue Date' || gv_delimeter || 'Invoice Status' || gv_delimeter || 'Po Number' || gv_delimeter || 'Brand' || gv_delimeter || 'Invoice Total Qty' || gv_delimeter || 'Invoice Amount' || gv_delimeter || 'Pod Compliance Date' || gv_delimeter || 'Incosat Date' || gv_delimeter || 'Destination Name' || gv_delimeter || 'Destination Country' || gv_delimeter || 'Estimated Departure Date' || gv_delimeter || 'Estimated Arrival Date Line'
                        FROM DUAL)
            ORDER BY 1 ASC;

        --DEFINE VARIABLES
        lv_file_path              VARCHAR2 (360);          -- := pv_file_path;
        lv_file_name              VARCHAR2 (360);
        lv_file_dir               VARCHAR2 (1000);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);          -- := pv_file_name;
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        lv_period_name            VARCHAR2 (50);
    BEGIN
        -- WRITE INTO BL FOLDER

        IF pv_file_path IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1, ffvl.attribute3
                  INTO lv_vs_file_path, lv_vs_file_name
                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                 WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND fvs.flex_value_set_name =
                           'XXD_GL_AAR_FILE_DETAILS_VS'
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.description = 'FACTORYACC'
                       AND ffvl.flex_value = pv_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;


            IF pv_period_end_date IS NULL
            THEN
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND TRUNC (SYSDATE) BETWEEN start_date
                                                   AND end_date;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_period_name   := NULL;
                END;
            ELSE
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_CY_CALENDAR'
                           AND TO_DATE (pv_period_end_date,
                                        'YYYY/MM/DD HH24:MI:SS') BETWEEN start_date
                                                                     AND end_date;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_period_name   := NULL;
                END;
            END IF;


            IF     lv_vs_file_path IS NOT NULL
               AND NVL (lv_vs_file_path, 'X') <> 'NA'
               AND lv_vs_file_name IS NOT NULL
            THEN
                lv_file_dir   := lv_vs_file_path;

                -- IF pv_type = 'FACTORYACC'
                -- THEN
                lv_file_name   :=
                       lv_vs_file_name
                    || '_'
                    || lv_period_name
                    || '_'
                    -- || pv_type
                    -- || '_'
                    || gn_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Supporting File Name is - ' || lv_file_name);

                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                  ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN op_file_fcty
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg   :=
                        SUBSTR (
                               'Error in Opening the  data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    write_log (lv_err_msg);
                    RETURN;
                END IF;

                UTL_FILE.fclose (lv_output_file);
            -- END IF;

            END IF;
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            raise_application_error (-20109, lv_err_msg);
    END write_op_file;


    PROCEDURE update_valueset_prc (pv_file_path IN VARCHAR2)
    IS
         /***************************************************************************
-- PROCEDURE update_valueset_prc
-- PURPOSE: This Procedure update USER NAME and REQUEST INFO in the valueset
**************************************************************************/
        lv_user_name      VARCHAR2 (100);
        lv_request_info   VARCHAR2 (100);
    BEGIN
        lv_user_name      := NULL;
        lv_request_info   := NULL;

        BEGIN
            SELECT fu.user_name, TO_CHAR (fcr.actual_start_date, 'MM/DD/RRRR HH24:MI:SS')
              INTO lv_user_name, lv_request_info
              FROM apps.fnd_concurrent_requests fcr, apps.fnd_user fu
             WHERE request_id = gn_request_id AND requested_by = fu.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_user_name      := NULL;
                lv_request_info   := NULL;
        END;

        UPDATE apps.fnd_flex_values_vl FFVL
           SET ffvl.attribute5 = lv_user_name, ffvl.attribute6 = lv_request_info
         WHERE     NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                   TRUNC (SYSDATE)
               AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                   TRUNC (SYSDATE)
               AND ffvl.enabled_flag = 'Y'
               AND ffvl.description = 'FACTORYACC'
               AND ffvl.flex_value = pv_file_path
               AND ffvl.flex_value_set_id IN
                       (SELECT flex_value_set_id
                          FROM apps.fnd_flex_value_sets
                         WHERE flex_value_set_name =
                               'XXD_GL_AAR_FILE_DETAILS_VS');

        COMMIT;
    END update_valueset_prc;

    PROCEDURE CopyFile_prc (pv_in_filename IN VARCHAR2, pv_out_filename IN VARCHAR2, pv_src_dir IN VARCHAR2
                            , pv_dest_dir IN VARCHAR2)
    IS
         /***************************************************************************
-- PROCEDURE CopyFile_prc
-- PURPOSE: This Procedure copy the file from one directory to another directory
**************************************************************************/
        in_file                UTL_FILE.FILE_TYPE;
        out_file               UTL_FILE.FILE_TYPE;

        buffer_size   CONSTANT INTEGER := 32767;    -- Max Buffer Size = 32767
        buffer                 RAW (32767);
        buffer_length          INTEGER;
    BEGIN
        -- Open a handle to the location where you are going to read the Text or Binary file from
        -- NOTE: The 'rb' parameter means "read in byte mode" and is only available

        in_file         :=
            UTL_FILE.FOPEN (pv_src_dir, pv_in_filename, 'rb',
                            buffer_size);

        -- Open a handle to the location where you are going to write the Text or Binary file to
        -- NOTE: The 'wb' parameter means "write in byte mode" and is only available

        out_file        :=
            UTL_FILE.FOPEN (pv_dest_dir, pv_out_filename, 'wb',
                            buffer_size);

        -- Attempt to read the first chunk of the in_file
        UTL_FILE.GET_RAW (in_file, buffer, buffer_size);

        -- Determine the size of the first chunk read
        buffer_length   := UTL_RAW.LENGTH (buffer);

        -- Only write the chunk to the out_file if data exists
        WHILE buffer_length > 0
        LOOP
            -- Write one chunk of data
            UTL_FILE.PUT_RAW (out_file, buffer, TRUE);

            -- Read the next chunk of data
            IF buffer_length = buffer_size
            THEN
                -- Buffer was full on last read, read another chunk
                UTL_FILE.GET_RAW (in_file, buffer, buffer_size);
                -- Determine the size of the current chunk
                buffer_length   := UTL_RAW.LENGTH (buffer);
            ELSE
                buffer_length   := 0;
            END IF;
        END LOOP;

        -- Close the file handles
        UTL_FILE.FCLOSE (in_file);
        UTL_FILE.FCLOSE (out_file);
    EXCEPTION
        -- Raised when the size of the file is a multiple of the buffer_size
        WHEN NO_DATA_FOUND
        THEN
            -- Close the file handles
            UTL_FILE.FCLOSE (in_file);
            UTL_FILE.FCLOSE (out_file);
        WHEN OTHERS
        THEN
            -- Close the file handles
            UTL_FILE.FCLOSE (in_file);
            UTL_FILE.FCLOSE (out_file);
    END CopyFile_prc;

    /***************************************************************************
    -- PROCEDURE main_prc
    -- PURPOSE: This Procedure is Concurrent Program.
    **************************************************************************/
    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_period_end_date IN VARCHAR2
                        , --                      pv_type              IN  VARCHAR2,
                          pv_file_path IN VARCHAR2)
    IS
        CURSOR get_file_cur IS
            SELECT filename
              FROM XXD_DIR_LIST_TBL_SYN
             WHERE UPPER (filename) NOT LIKE 'ARCHIVE';

        lv_inb_directory_path   VARCHAR2 (1000);
        lv_arc_directory_path   VARCHAR2 (1000);
        lv_directory            VARCHAR2 (1000);
        lv_file_name            VARCHAR2 (1000) := NULL;
        lv_ret_message          VARCHAR2 (4000) := NULL;
        lv_ret_code             VARCHAR2 (30) := NULL;
        lv_period_name          VARCHAR2 (100);
        ln_file_exists          NUMBER;
        ln_ret_count            NUMBER := 0;
        ln_final_count          NUMBER := 0;
        ln_lia_count            NUMBER := 0;
        ln_req_id               NUMBER;
        lv_phase                VARCHAR2 (100);
        lv_status               VARCHAR2 (30);
        lv_dev_phase            VARCHAR2 (100);
        lv_dev_status           VARCHAR2 (100);
        lb_wait_req             BOOLEAN;
        lv_message              VARCHAR2 (1000);
    BEGIN
        lv_inb_directory_path   := NULL;
        lv_arc_directory_path   := NULL;
        lv_directory            := 'XXD_FCTY_ACC_BAL_BL_INB_DIR';
        ln_file_exists          := 0;

        -- Derive the directory Path
        BEGIN
            SELECT directory_path
              INTO lv_inb_directory_path
              FROM dba_directories
             WHERE     1 = 1
                   AND directory_name LIKE 'XXD_FCTY_ACC_BAL_BL_INB_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inb_directory_path   := NULL;
        END;

        BEGIN
            SELECT directory_path
              INTO lv_arc_directory_path
              FROM dba_directories
             WHERE     1 = 1
                   AND directory_name LIKE 'XXD_FCTY_ACC_BAL_BL_ARC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_arc_directory_path   := NULL;
        END;


        -- Now Get the file names

        get_file_names (lv_inb_directory_path);

        -- IF pv_type = 'FACTORYACC'
        -- THEN

        FOR data IN get_file_cur
        LOOP
            ln_file_exists   := 0;

            write_log (' File is availale - ' || data.filename);

            -- Check the file name exists in the table if exists then SKIP
            lv_file_name     := NULL;
            lv_file_name     := data.filename;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_file_exists
                  FROM xxdo.xxd_po_fcty_acc_bal_stg_t
                 WHERE UPPER (file_name) = UPPER (data.filename);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_file_exists   := 0;
            END;

            IF ln_file_exists = 0
            THEN
                load_file_into_tbl (pv_table => 'XXD_PO_FCTY_ACC_BAL_STG_T', pv_dir => 'XXD_FCTY_ACC_BAL_BL_INB_DIR', pv_filename => data.filename, pv_ignore_headerlines => 1, pv_delimiter => ',', pv_optional_enclosed => '"'
                                    , pv_num_of_columns => 28); -- Verify and Change the number of columns

                -- BEGIN
                -- CopyFile_prc (lv_file_name,SYSDATE||'_'||lv_file_name,'XXD_FCTY_ACC_BAL_BL_INB_DIR','XXD_FCTY_ACC_BAL_BL_ARC_DIR');
                -- Utl_File.Fremove('XXD_FCTY_ACC_BAL_BL_INB_DIR', lv_file_name);
                -- EXCEPTION
                -- WHEN OTHERS
                -- THEN
                -- write_log ('Error Occured while Copying/Removing file from Inbound directory, Check File Privileges: '||SQLERRM);
                -- retcode := gn_warning;
                -- END;

                BEGIN
                    write_log (
                           'Move files Process Begins...'
                        || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                    ln_req_id   :=
                        fnd_request.submit_request (
                            application   => 'XXDO',
                            program       => 'XXDO_CP_MV_RM_FILE',
                            argument1     => 'MOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                            argument2     => 2,
                            argument3     =>
                                lv_inb_directory_path || '/' || lv_file_name, -- Source File Directory
                            argument4     =>
                                   lv_arc_directory_path
                                || '/'
                                || SYSDATE
                                || '_'
                                || lv_file_name, -- Destination File Directory
                            start_time    => SYSDATE,
                            sub_request   => FALSE);
                    COMMIT;

                    IF ln_req_id = 0
                    THEN
                        retcode   := gn_warning;
                        write_log (
                            ' Unable to submit move files concurrent program ');
                    ELSE
                        write_log (
                            'Move Files concurrent request submitted successfully.');
                        lb_wait_req   :=
                            fnd_concurrent.wait_for_request (
                                request_id   => ln_req_id,
                                interval     => 5,
                                phase        => lv_phase,
                                status       => lv_status,
                                dev_phase    => lv_dev_phase,
                                dev_status   => lv_dev_status,
                                MESSAGE      => lv_message);

                        IF     lv_dev_phase = 'COMPLETE'
                           AND lv_dev_status = 'NORMAL'
                        THEN
                            write_log (
                                   'Move Files concurrent request with the request id '
                                || ln_req_id
                                || ' completed with NORMAL status.');
                        ELSE
                            retcode   := gn_warning;
                            write_log (
                                   'Move Files concurrent request with the request id '
                                || ln_req_id
                                || ' did not complete with NORMAL status.');
                        END IF; -- End of if to check if the status is normal and phase is complete
                    END IF;          -- End of if to check if request ID is 0.

                    COMMIT;
                    write_log (
                           'Move Files Ends...'
                        || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        retcode   := gn_error;
                        write_log ('Error in Move Files -' || SQLERRM);
                END;



                BEGIN
                    UPDATE xxdo.xxd_po_fcty_acc_bal_stg_t
                       SET file_name = data.filename, request_id = gn_request_id, creation_date = SYSDATE,
                           last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id
                     WHERE file_name IS NULL AND request_id IS NULL;

                    write_log (
                           SQL%ROWCOUNT
                        || ' Records updated with Filename, Request ID and WHO Columns');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Error Occured while Updating the Filename, Request ID and WHO Columns-'
                            || SQLERRM);
                END;

                process_data_prc (pv_period_end_date);

                write_op_file (pv_file_path, pv_period_end_date);

                -- update_attributes (lv_ret_message, pv_period_end_date,pv_type);

                write_fcty_recon_file (pv_file_path);

                update_valueset_prc (pv_file_path);
            ELSE
                write_log (
                       ' Data with this File name - '
                    || data.filename
                    || ' - is already loaded. Please change the file data ');

                -- BEGIN
                -- CopyFile_prc (lv_file_name,SYSDATE||'_'||lv_file_name,'XXD_FCTY_ACC_BAL_BL_INB_DIR','XXD_FCTY_ACC_BAL_BL_ARC_DIR');
                -- Utl_File.Fremove('XXD_FCTY_ACC_BAL_BL_INB_DIR', lv_file_name);
                -- EXCEPTION
                -- WHEN OTHERS
                -- THEN
                -- write_log ('File already exists, Error Occured while Copying/Removing file from Inbound directory, Check File Privileges: '||SQLERRM);
                -- retcode := gn_warning;
                -- END;

                BEGIN
                    write_log (
                           'Move files Process Begins...'
                        || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                    ln_req_id   :=
                        fnd_request.submit_request (
                            application   => 'XXDO',
                            program       => 'XXDO_CP_MV_RM_FILE',
                            argument1     => 'MOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                            argument2     => 2,
                            argument3     =>
                                lv_inb_directory_path || '/' || lv_file_name, -- Source File Directory
                            argument4     =>
                                   lv_arc_directory_path
                                || '/'
                                || SYSDATE
                                || '_'
                                || lv_file_name, -- Destination File Directory
                            start_time    => SYSDATE,
                            sub_request   => FALSE);
                    COMMIT;

                    IF ln_req_id = 0
                    THEN
                        retcode   := gn_warning;
                        write_log (
                            ' Unable to submit move files concurrent program ');
                    ELSE
                        write_log (
                            'Move Files concurrent request submitted successfully.');
                        lb_wait_req   :=
                            fnd_concurrent.wait_for_request (
                                request_id   => ln_req_id,
                                interval     => 5,
                                phase        => lv_phase,
                                status       => lv_status,
                                dev_phase    => lv_dev_phase,
                                dev_status   => lv_dev_status,
                                MESSAGE      => lv_message);

                        IF     lv_dev_phase = 'COMPLETE'
                           AND lv_dev_status = 'NORMAL'
                        THEN
                            write_log (
                                   'Move Files concurrent request with the request id '
                                || ln_req_id
                                || ' completed with NORMAL status.');
                        ELSE
                            retcode   := gn_warning;
                            write_log (
                                   'Move Files concurrent request with the request id '
                                || ln_req_id
                                || ' did not complete with NORMAL status.');
                        END IF; -- End of if to check if the status is normal and phase is complete
                    END IF;          -- End of if to check if request ID is 0.

                    COMMIT;
                    write_log (
                           'Move Files Ends...'
                        || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        retcode   := gn_error;
                        write_log ('Error in Move Files -' || SQLERRM);
                END;
            END IF;
        END LOOP;

        --         END IF;

        IF lv_file_name IS NULL
        THEN
            write_log ('There is nothing to Process...No File Exists.');
            retcode   := gn_warning;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := gn_error;
            write_log ('Error Occured in Procedure MAIN_PRC: ' || SQLERRM);
    END MAIN_PRC;
END XXD_PO_FCTY_ACC_BAL_PKG;
/
