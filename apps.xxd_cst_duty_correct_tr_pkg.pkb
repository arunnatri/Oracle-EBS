--
-- XXD_CST_DUTY_CORRECT_TR_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_CST_DUTY_CORRECT_TR_PKG"
AS
    /******************************************************************************************
    NAME           : XXD_CST_DUTY_CORRECT_TR_PKG
    REPORT NAME    : Deckers Average Cost Correction

    REVISIONS:
    Date            Author                  Version     Description
    ----------      ----------              -------     ---------------------------------------------------
    13-AUG-2021     Srinath Siricilla       1.0         Created this package using XXD_CST_DUTY_CORRECT_TR_PKG
                                                        to load the Corrective into the staging table and process them.
    *********************************************************************************************/

    /***************************************************************************
    -- PROCEDURE write_log_prc
    -- PURPOSE: This Procedure write the log messages
    ***************************************************************************/
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

    PROCEDURE write_log_prc (pv_msg IN VARCHAR2)
    IS
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
                'Error in write_log_prc Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in write_log_prc Procedure -' || SQLERRM);
    END write_log_prc;

    /***************************************************************************
 -- PROCEDURE load_file_into_tbl_prc
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
 -- By default the delimiter is used as '|'
 -- As we are using CSV file to load the data into oracle
 --
 -- PV_OPTIONAL_ENCLOSED
 -- By default the optionally enclosed is used as '"'
 -- As we are using CSV file to load the data into oracle
 --
 **************************************************************************/
    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'DirList.getList( java.lang.String )' ;

    PROCEDURE load_file_into_tbl_prc (pv_table IN VARCHAR2, pv_dir IN VARCHAR2 DEFAULT 'XXD_CST_DUTY_CORR_INB_DIR', pv_filename IN VARCHAR2, pv_ignore_headerlines IN INTEGER DEFAULT 1, pv_delimiter IN VARCHAR2 DEFAULT '|', pv_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                      , pv_num_of_columns IN NUMBER)
    IS
        l_input       UTL_FILE.file_type;

        l_lastLine    VARCHAR2 (4000);
        l_cnames      VARCHAR2 (4000);
        l_bindvars    VARCHAR2 (4000);
        l_status      INTEGER;
        l_cnt         NUMBER DEFAULT 0;
        l_rowCount    NUMBER DEFAULT 0;
        l_sep         CHAR (1) DEFAULT NULL;
        l_errmsg      VARCHAR2 (4000);
        v_eof         BOOLEAN := FALSE;
        l_theCursor   NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert      VARCHAR2 (1100);
    BEGIN
        write_log_prc ('Load Data Process Begins...');
        l_cnt        := 1;

        FOR TAB_COLUMNS
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE     1 = 1
                         AND table_name = pv_table
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
        L_BINDVARS   := RTRIM (L_BINDVARS, ',');

        write_log_prc ('Count of Columns is - ' || l_cnt);

        L_INPUT      := UTL_FILE.FOPEN (pv_dir, pv_filename, 'r');

        IF pv_ignore_headerlines > 0
        THEN
            BEGIN
                FOR i IN 1 .. pv_ignore_headerlines
                LOOP
                    write_log_prc ('No of lines Ignored is - ' || i);
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
            write_log_prc (
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
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (l_lastline, --'(^|,)("[^"]*"|[^",]*)',
                                                                                    '([^|]*)(\||$)', 1
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

            --CopyFile_prc (pv_filename,SYSDATE||'_'||pv_filename,'XXD_CST_DUTY_ELE_INB_DIR','XXD_CST_DUTY_ELE_ARC_DIR');
            --Utl_File.Fremove('XXD_CST_DUTY_ELE_INB_DIR', pv_filename);

            DBMS_SQL.close_cursor (l_theCursor);
            UTL_FILE.fclose (l_input);

            UPDATE xxdo.xxd_cst_duty_correct_tr_t
               SET file_name = pv_filename, request_id = gn_request_id, creation_date = SYSDATE,
                   last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id,
                   --                   current_flag = 'Y',
                   status = 'N'
             WHERE 1 = 1 AND file_name IS NULL AND request_id IS NULL;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc ('load_file_into_tbl_prc: ' || SQLERRM);
    END load_file_into_tbl_prc;

    /***************************************************************************
  -- PROCEDURE CopyFile_prc
  -- PURPOSE: This Procedure copy the file from one directory to another directory
  **************************************************************************/
    PROCEDURE CopyFile_prc (pv_in_filename IN VARCHAR2, pv_out_filename IN VARCHAR2, pv_src_dir IN VARCHAR2
                            , pv_dest_dir IN VARCHAR2)
    IS
        in_file                UTL_FILE.FILE_TYPE;
        out_file               UTL_FILE.FILE_TYPE;

        buffer_size   CONSTANT INTEGER := 32767;    -- Max Buffer Size = 32767
        buffer                 RAW (32767);
        buffer_length          INTEGER;
    BEGIN
        -- Open a handle to the location where you are going to read the Text or Binary file from
        -- NOTE: The 'rb' parameter means "read in byte mode" and is only available
        write_log_prc ('Copy File Program Begin...');
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

    FUNCTION get_company_ou_fnc (pn_org_id IN NUMBER)
        RETURN VARCHAR2
    IS
        x_company   VARCHAR2 (10);
    BEGIN
        SELECT DISTINCT glev.flex_segment_value
          INTO x_company
          FROM apps.xle_entity_profiles lep, apps.xle_registrations reg, apps.hr_operating_units hro,
               apps.hr_all_organization_units_tl hroutl_ou, apps.hr_organization_units gloperatingunitseo, apps.gl_legal_entities_bsvs glev
         WHERE     lep.transacting_entity_flag = 'Y'
               AND lep.legal_entity_id = reg.source_id
               AND reg.source_table = 'XLE_ENTITY_PROFILES'
               AND hroutl_ou.language = 'US'
               AND reg.identifying_flag = 'Y'
               AND lep.legal_entity_id = hro.default_legal_context_id
               AND gloperatingunitseo.organization_id = hro.organization_id
               AND hroutl_ou.organization_id = hro.organization_id
               AND glev.legal_entity_id = lep.legal_entity_id
               AND hroutl_ou.organization_id = pn_org_id;

        RETURN x_company;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_company   := NULL;
            RETURN x_company;
    END get_company_ou_fnc;

    PROCEDURE insert_into_staging_prc (pv_file_name IN VARCHAR2)
    IS
    BEGIN
        INSERT INTO xxdo.xxd_cst_duty_correct_stg_tr_t (
                        organization_code,
                        style,
                        color,
                        item_number,
                        transaction_date,
                        transaction_type,
                        transaction_account,
                        avg_cost,
                        avg_percent_change,
                        mat_avg_cost,
                        mat_avg_percent_change,
                        mat_oh_cost,
                        mat_oh_percent_change,
                        duty,
                        oh_duty,
                        oh_non_duty,
                        freight_duty,
                        freight,
                        future_col1,
                        future_col2,
                        future_col3,
                        future_col4,
                        future_col5,
                        future_col6,
                        future_col7,
                        future_col8,
                        future_col9,
                        future_col10,
                        request_id,
                        file_name,
                        status,
                        error_msg,
                        creation_date,
                        created_by,
                        last_update_date,
                        last_updated_by)
            SELECT *
              FROM xxdo.xxd_cst_duty_correct_tr_t
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND file_name = pv_file_name
                   AND status = 'N';

        COMMIT;
    END insert_into_staging_prc;

    -- Insert into Staging Table for item Records

    PROCEDURE Insert_style_color (
        pv_org_code                 IN VARCHAR2 := NULL,
        pv_Style                    IN VARCHAR2 := NULL,
        pv_color                    IN VARCHAR2 := NULL,
        pv_Item_Number              IN VARCHAR2 := NULL,
        pv_Trx_Date                 IN VARCHAR2 := NULL,
        pv_Trx_type                 IN VARCHAR2 := NULL,
        pv_Trx_Account              IN VARCHAR2 := NULL,
        pn_Avg_cost                 IN VARCHAR2 := NULL,
        pn_Avg_Percent_change       IN VARCHAR2 := NULL,
        pn_Mat_Avg_cost             IN VARCHAR2 := NULL,
        pn_Mat_Avg_Percent_change   IN VARCHAR2 := NULL,
        pn_Mat_OH_cost              IN VARCHAR2 := NULL,
        pn_Mat_OH_Percent_change    IN VARCHAR2 := NULL,
        pn_Duty                     IN VARCHAR2 := NULL,
        pn_oh_duty                  IN VARCHAR2 := NULL,
        pn_oh_non_Duty              IN NUMBER := NULL,
        pn_Freight_Duty             IN NUMBER := NULL,
        pn_Freight                  IN NUMBER := NULL,
        pn_request_id               IN NUMBER := NULL,
        pv_file_name                IN VARCHAR2 := NULL,
        pv_status                   IN VARCHAR2 := NULL,
        pv_error_msg                IN VARCHAR2 := NULL,
        pn_inv_item_id              IN NUMBER := NULL,
        pn_organization_id          IN NUMBER := NULL,
        pn_ccid                     IN NUMBER := NULL,
        pv_rec_type                 IN VARCHAR2 := 'DERIVED')
    IS
    BEGIN
        --        write_log_prc(' Start of Insert_Style_color PRC');

        INSERT INTO xxdo.xxd_cst_duty_correct_stg_tr_t (Organization_code, Style, Color, Item_Number, Transaction_Date, Transaction_type, Transaction_Account, Avg_cost, Avg_Percent_change, Mat_Avg_cost, Mat_Avg_Percent_change, Mat_OH_cost, Mat_OH_Percent_change, Duty, oh_duty, oh_non_Duty, Freight_Duty, Freight, request_id, file_name, inventory_item_id, organization_id, record_type, ccid
                                                        , status)
             VALUES (pv_org_code, pv_Style, pv_color,
                     pv_Item_Number, pv_Trx_Date, pv_Trx_type,
                     pv_Trx_Account, pn_Avg_cost, pn_Avg_Percent_change,
                     pn_Mat_Avg_cost, pn_Mat_Avg_Percent_change, pn_Mat_OH_cost, pn_Mat_OH_Percent_change, pn_Duty, pn_oh_duty, pn_oh_non_Duty, pn_Freight_Duty, pn_Freight, pn_request_id, pv_file_name, pn_inv_item_id, pn_organization_id, pv_rec_type, pn_ccid
                     , pv_status);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                   'Exception While Inserting Items records into Stg Table - '
                || SQLERRM);
    END;

    /*************************************************************************
    -- PROCEDURE validate_prc
    -- PURPOSE: This Procedure validate the recoreds present in staging table.
    ****************************************************************************/

    PROCEDURE validate_prc (pv_file_name VARCHAR2)
    IS
        CURSOR style_dup IS
              SELECT style, organization_code
                FROM xxdo.xxd_cst_duty_correct_tr_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND status = 'N'
                     --   AND UPPER (file_name) = UPPER (pv_file_name)
                     AND color IS NULL
                     AND item_number IS NULL
            GROUP BY style, organization_code;

        CURSOR style_color_dup IS
              SELECT style, color, organization_code
                FROM xxdo.xxd_cst_duty_correct_tr_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND status = 'N'
                     --   AND UPPER (file_name) = UPPER (pv_file_name)
                     AND color IS NOT NULL
                     AND item_number IS NULL
            GROUP BY style, color, organization_code;


        CURSOR fetch_duty_elements IS
            SELECT ROWID, Organization_code, Style,
                   Color, Item_Number, Transaction_Date,
                   Transaction_type, Transaction_Account, Avg_cost,
                   Avg_Percent_change, Mat_Avg_cost, Mat_Avg_Percent_change,
                   Mat_OH_cost, Mat_OH_Percent_change, Duty,
                   oh_duty, oh_non_Duty, Freight_Duty,
                   Freight, Future_col1, Future_col2,
                   Future_col3, Future_col4, Future_col5,
                   Future_col6, Future_col7, Future_col8,
                   Future_col9, Future_col10, request_id,
                   file_name, status, error_msg,
                   creation_date, created_by, last_update_date,
                   last_updated_by
              FROM xxdo.xxd_cst_duty_correct_tr_t
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND status = 'N'
                   AND UPPER (file_name) = UPPER (pv_file_name);

        TYPE tb_rec IS TABLE OF fetch_duty_elements%ROWTYPE;

        v_tb_rec                tb_rec;

        v_bulk_limit            NUMBER := 5000;

        ln_organization_id      NUMBER;
        ln_ou_id                NUMBER;
        lv_company              VARCHAR2 (10);
        lv_segment1             VARCHAR2 (10);
        ln_inventory_item_id    NUMBER;
        ln_ccid                 NUMBER;

        e_bulk_errors           EXCEPTION;
        PRAGMA EXCEPTION_INIT (e_bulk_errors, -24381);
        l_msg                   VARCHAR2 (4000);
        l_idx                   NUMBER;
        l_error_count           NUMBER;
        ln_style_color_count    NUMBER;
        ln_style_color_count1   NUMBER;
        --ln_style_color_count2    NUMBER;
        ln_style_count          NUMBER;
        ln_style_count1         NUMBER;
        ln_style_count2         NUMBER;
        ln_style_count3         NUMBER;
        lv_open_flag            VARCHAR2 (10);
    BEGIN
        write_log_prc ('Validate PRC Begins...');

        FOR style_rec IN style_dup
        LOOP
            ln_style_count    := 0;
            ln_style_count1   := 0;
            ln_style_count2   := 0;
            ln_style_count3   := 0;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_style_count
                  FROM xxdo.xxd_cst_duty_correct_tr_t st_t
                 WHERE     1 = 1
                       AND style = style_rec.style
                       AND organization_code = style_rec.organization_code
                       AND request_id = gn_request_id
                       AND color IS NOT NULL
                       AND item_number IS NOT NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_style_count   := 0;
            END;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_style_count1
                  FROM xxdo.xxd_cst_duty_correct_tr_t st_t
                 WHERE     1 = 1
                       AND style = style_rec.style
                       AND organization_code = style_rec.organization_code
                       AND request_id = gn_request_id
                       AND color IS NULL
                       AND item_number IS NOT NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_style_count1   := 0;
            END;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_style_count2
                  FROM xxdo.xxd_cst_duty_correct_tr_t st_t
                 WHERE     1 = 1
                       AND style = style_rec.style
                       AND organization_code = style_rec.organization_code
                       AND request_id = gn_request_id
                       AND color IS NOT NULL
                       AND item_number IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_style_count2   := 0;
            END;

            -- If the Same Style is repeated again without Color and Item Number

            BEGIN
                SELECT COUNT (1)
                  INTO ln_style_count3
                  FROM xxdo.xxd_cst_duty_correct_tr_t st_t
                 WHERE     1 = 1
                       AND style = style_rec.style
                       AND organization_code = style_rec.organization_code
                       AND request_id = gn_request_id
                       AND color IS NULL
                       AND item_number IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_style_count3   := 0;
            END;

            IF    ln_style_count1 <> 0
               OR ln_style_count <> 0
               OR ln_style_count2 <> 0
               OR ln_style_count3 > 1
            THEN
                UPDATE xxdo.xxd_cst_duty_correct_tr_t st_t
                   SET error_msg = 'Duplicate Record with Style Combination', status = 'E'
                 WHERE     1 = 1
                       AND style = style_rec.style
                       AND organization_code = style_rec.organization_code
                       --                   AND  file_name = pv_file_name
                       AND request_id = gn_request_id;
            END IF;

            COMMIT;
        END LOOP;

        FOR color_rec IN style_color_dup
        LOOP
            ln_style_color_count    := 0;
            ln_style_color_count1   := 0;

            --            ln_style_color_count2 := 0;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_style_color_count
                  FROM xxdo.xxd_cst_duty_correct_tr_t
                 WHERE     1 = 1
                       AND style = color_rec.style
                       AND color = color_rec.color
                       AND request_id = gn_request_id
                       AND organization_code = color_rec.organization_code
                       AND item_number IS NOT NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_style_color_count   := 0;
            END;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_style_color_count1
                  FROM xxdo.xxd_cst_duty_correct_tr_t st_t
                 WHERE     1 = 1
                       AND style = color_rec.style
                       AND color = color_rec.color
                       AND request_id = gn_request_id
                       AND organization_code = color_rec.organization_code
                       AND item_number IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_style_color_count1   := 0;
            END;

            IF ln_style_color_count1 > 1 OR ln_style_color_count <> 0
            THEN
                UPDATE xxdo.xxd_cst_duty_correct_tr_t st_t
                   SET error_msg = 'Duplicate Record with Style and Color Combination', status = 'E'
                 WHERE     1 = 1
                       AND style = color_rec.style
                       AND color = color_rec.color
                       AND organization_code = color_rec.organization_code
                       --                   AND  file_name = pv_file_name
                       AND request_id = gn_request_id;
            END IF;

            COMMIT;
        END LOOP;


        OPEN fetch_duty_elements;

        --v_tb_rec.DELETE;

        LOOP
            FETCH fetch_duty_elements
                BULK COLLECT INTO v_tb_rec
                LIMIT v_bulk_limit;

            EXIT WHEN v_tb_rec.COUNT = 0;

            IF v_tb_rec.COUNT > 0
            THEN
                write_log_prc ('Record Count: ' || v_tb_rec.COUNT);

                BEGIN
                    FOR i IN 1 .. v_tb_rec.COUNT
                    LOOP
                        v_tb_rec (i).status   := 'V';

                        ln_organization_id    := NULL;

                        --ln_style_color_count := 0;

                        -- Validate Style and Color

                        IF v_tb_rec (i).style IS NOT NULL
                        THEN
                            ln_style_color_count   := 0;

                            BEGIN
                                SELECT COUNT (1)
                                  INTO ln_style_color_count
                                  FROM mtl_system_items_b --xxd_common_items_v
                                 WHERE     1 = 1
                                       --AND style_number = v_tb_rec (i).style
                                       AND REGEXP_SUBSTR (segment1, '[^-]+', 1
                                                          , 1) =
                                           v_tb_rec (i).style
                                       AND NVL (TRUNC (start_date_active),
                                                TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND enabled_flag = 'Y'
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_style_color_count   := 0;
                            END;

                            IF ln_style_color_count = 0
                            THEN
                                v_tb_rec (i).status   := 'E';
                                v_tb_rec (i).error_msg   :=
                                       v_tb_rec (i).error_msg
                                    || ' Style is Invalid - '
                                    || v_tb_rec (i).Style;
                                write_log_prc (
                                       'Style is Invalid : '
                                    || v_tb_rec (i).Style);
                            END IF;
                        ELSE
                            v_tb_rec (i).status   := 'E';
                            v_tb_rec (i).error_msg   :=
                                   v_tb_rec (i).error_msg
                                || ' Style Cannnot be Null-';
                            write_log_prc (
                                'Style is Invalid : ' || v_tb_rec (i).Style);
                        END IF;

                        IF v_tb_rec (i).color IS NOT NULL
                        THEN
                            ln_style_color_count   := 0;

                            BEGIN
                                SELECT COUNT (1)
                                  INTO ln_style_color_count
                                  FROM mtl_system_items_b --xxd_common_items_v
                                 WHERE     1 = 1
                                       --AND color_code = v_tb_rec (i).color
                                       AND REGEXP_SUBSTR (segment1, '[^-]+', 1
                                                          , 2) =
                                           v_tb_rec (i).color
                                       AND NVL (TRUNC (start_date_active),
                                                TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND enabled_flag = 'Y'
                                       AND ROWNUM = 1;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_style_color_count   := 0;
                            END;

                            IF ln_style_color_count = 0
                            THEN
                                v_tb_rec (i).status   := 'E';
                                v_tb_rec (i).error_msg   :=
                                       v_tb_rec (i).error_msg
                                    || ' Color is Invalid - '
                                    || v_tb_rec (i).Style;

                                write_log_prc (
                                       'Color is Invalid : '
                                    || v_tb_rec (i).Style);
                            END IF;
                        END IF;

                        -- Validate Inventory Organization

                        IF ln_style_color_count <> 0
                        THEN
                            IF v_tb_rec (i).Organization_Code IS NOT NULL
                            THEN
                                ln_ou_id   := NULL;

                                BEGIN
                                    write_log_prc (
                                           'Organization Code : '
                                        || v_tb_rec (i).Organization_Code);

                                    SELECT organization_id, operating_unit
                                      INTO ln_organization_id, ln_ou_id
                                      FROM apps.org_organization_definitions
                                     WHERE     1 = 1
                                           AND organization_code =
                                               v_tb_rec (i).organization_code;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        v_tb_rec (i).status   := 'E';
                                        v_tb_rec (i).error_msg   :=
                                               v_tb_rec (i).error_msg
                                            || 'Organization Code is Invalid - '
                                            || SUBSTR (SQLERRM, 1, 200);
                                        write_log_prc (
                                            'Organization Code' || SQLERRM);
                                END;
                            ELSIF v_tb_rec (i).Organization_Code IS NULL
                            THEN
                                v_tb_rec (i).status   := 'E';
                                v_tb_rec (i).error_msg   :=
                                       v_tb_rec (i).error_msg
                                    || 'Organization Code Cannnot be Null-';
                            END IF;
                        END IF;

                        IF v_tb_rec (i).Transaction_Account IS NOT NULL
                        THEN
                            BEGIN
                                write_log_prc (
                                       'Transaction Account : '
                                    || v_tb_rec (i).Transaction_Account);

                                SELECT code_combination_id
                                  INTO ln_ccid
                                  FROM apps.gl_code_combinations_kfv
                                 WHERE     1 = 1
                                       AND concatenated_segments =
                                           v_tb_rec (i).Transaction_Account
                                       AND enabled_flag = 'Y';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    write_log_prc (
                                        'Transaction Account' || SQLERRM);
                                    v_tb_rec (i).status   := 'E';
                                    v_tb_rec (i).error_msg   :=
                                           v_tb_rec (i).error_msg
                                        || 'Transaction Accountis Invalid - '
                                        || SUBSTR (SQLERRM, 1, 200);
                            END;
                        ELSIF v_tb_rec (i).Transaction_Account IS NULL
                        THEN
                            v_tb_rec (i).status   := 'E';
                            v_tb_rec (i).error_msg   :=
                                   v_tb_rec (i).error_msg
                                || 'Transaction Account Cannnot be Null-';
                        END IF;

                        IF v_tb_rec (i).Transaction_Type IS NOT NULL
                        THEN
                            BEGIN
                                write_log_prc (
                                       'Transaction Type: '
                                    || v_tb_rec (i).Transaction_Type);

                                IF v_tb_rec (i).Transaction_Type <>
                                   'Average Cost Update'
                                THEN
                                    v_tb_rec (i).status   := 'E';
                                    v_tb_rec (i).error_msg   :=
                                           v_tb_rec (i).error_msg
                                        || 'Transaction Type is not Valid-';
                                END IF;
                            END;
                        ELSIF v_tb_rec (i).Transaction_Type IS NULL
                        THEN
                            v_tb_rec (i).status   := 'E';
                            v_tb_rec (i).error_msg   :=
                                   v_tb_rec (i).error_msg
                                || 'Transaction Type Cannnot be Null-';
                        END IF;

                        IF ln_organization_id IS NOT NULL
                        THEN
                            write_log_prc (
                                ' ln_organization_id ' || ln_organization_id);

                            IF v_tb_rec (i).Item_Number IS NOT NULL
                            THEN
                                write_log_prc (
                                       ' Item_Number '
                                    || v_tb_rec (i).Item_Number);

                                BEGIN
                                    SELECT inventory_item_id
                                      INTO ln_inventory_item_id
                                      FROM apps.mtl_system_items_b
                                     WHERE     1 = 1
                                           AND segment1 =
                                               v_tb_rec (i).Item_Number
                                           AND organization_id =
                                               ln_organization_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        write_log_prc (
                                            'Item Number' || SQLERRM);
                                END;
                            END IF;

                            -- Check whether Transaction Date is in Open Period

                            IF v_tb_rec (i).Transaction_date IS NOT NULL
                            THEN
                                lv_open_flag   := NULL;

                                BEGIN
                                    write_log_prc (
                                           'Transaction date : '
                                        || v_tb_rec (i).Transaction_date);

                                    SELECT oap.open_flag
                                      INTO lv_open_flag
                                      FROM org_acct_periods oap, org_organization_definitions ood
                                     WHERE     1 = 1
                                           AND oap.organization_id =
                                               ood.organization_id
                                           AND ood.organization_id =
                                               ln_organization_id
                                           AND TRUNC (
                                                   TO_DATE (
                                                       v_tb_rec (i).Transaction_date,
                                                       'DD-MON-RRRR')) BETWEEN TRUNC (
                                                                                   NVL (
                                                                                       oap.period_start_date,
                                                                                       SYSDATE))
                                                                           AND TRUNC (
                                                                                   NVL (
                                                                                       oap.schedule_close_date,
                                                                                       SYSDATE));
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        write_log_prc (
                                            'Transaction Date' || SQLERRM);
                                        v_tb_rec (i).status   := 'E';
                                        v_tb_rec (i).error_msg   :=
                                               v_tb_rec (i).error_msg
                                            || 'Transaction Date is Invalid - '
                                            || SUBSTR (SQLERRM, 1, 200);
                                END;

                                IF NVL (lv_open_flag, 'ZZ') <> 'Y'
                                THEN
                                    v_tb_rec (i).status   := 'E';
                                    v_tb_rec (i).error_msg   :=
                                           v_tb_rec (i).error_msg
                                        || 'Inventory Period is not open for Date  - '
                                        || v_tb_rec (i).Transaction_date
                                        || ' - for Organization Code - '
                                        || v_tb_rec (i).organization_code;
                                END IF;
                            ELSIF v_tb_rec (i).Transaction_Date IS NULL
                            THEN
                                v_tb_rec (i).status   := 'E';
                                v_tb_rec (i).error_msg   :=
                                       v_tb_rec (i).error_msg
                                    || 'Transaction Date Cannnot be Null-';
                            END IF;

                            -- Validate Whether the OU and GL Code belongs to same ledger

                            BEGIN
                                lv_segment1   := NULL;

                                SELECT segment1
                                  INTO lv_segment1
                                  FROM apps.gl_code_combinations
                                 WHERE     1 = 1
                                       AND code_combination_id = ln_ccid;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_segment1   := NULL;
                            END;

                            -- Get the OU ID based on the Or

                            -- Now fetch the Company associated with the OU

                            lv_company   := NULL;

                            lv_company   := get_company_ou_fnc (ln_ou_id);

                            IF NVL (lv_segment1, 'XYZ') <>
                               NVL (lv_company, 'XYZ')
                            THEN
                                v_tb_rec (i).status   := 'E';
                                v_tb_rec (i).error_msg   :=
                                       v_tb_rec (i).error_msg
                                    || ' Please check the Code Combination against the Inventory associated OU - ';
                            END IF;
                        END IF;
                    END LOOP;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        -- v_tb_rec (i).status := 'E';
                        -- v_tb_rec (i).error_msg := v_tb_rec (i).error_msg|| ' Record Wise Validation Failed - ' ;
                        write_log_prc (
                            SQLERRM || ' Record wise Validations Failed');
                END;

                BEGIN
                    FORALL i IN v_tb_rec.FIRST .. v_tb_rec.LAST
                      SAVE EXCEPTIONS
                        UPDATE xxdo.xxd_cst_duty_correct_tr_t
                           SET     --inventory_item_id = ln_inventory_item_id,
                                       --organization_id = ln_organization_id,
                                                             --ccid = ln_ccid,
                           status = v_tb_rec (i).status, error_msg = v_tb_rec (i).error_msg
                         WHERE ROWID = v_tb_rec (i).ROWID;

                    write_log_prc (
                           SQL%ROWCOUNT
                        || ' Number of Records Updated in Stg table with Org ID and CCID details ');
                EXCEPTION
                    WHEN e_bulk_errors
                    THEN
                        write_log_prc ('Inside E_BULK_ERRORS');
                        l_error_count   := SQL%BULK_EXCEPTIONS.COUNT;

                        FOR i IN 1 .. l_error_count
                        LOOP
                            l_msg   :=
                                SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                            l_idx   := SQL%BULK_EXCEPTIONS (i).ERROR_INDEX;
                            write_log_prc (
                                   'Failed to update TR Element For Item Number- '
                                || v_tb_rec (l_idx).item_number
                                || ' with error_code- '
                                || l_msg);
                        END LOOP;
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                            'Update Failed for Error Records' || SQLERRM);
                END;

                COMMIT;
            END IF;

            EXIT WHEN fetch_duty_elements%NOTFOUND;
        END LOOP;

        --  BEGIN
        --
        --  UPDATE xxdo.xxd_cst_duty_correct_tr_t
        --           SET  status = 'E',
        --                error_msg = error_msg || 'Duplicate Record-'
        --         WHERE     1 = 1
        --               AND (NVL(Style,'XYZ123'), NVL(color,'XYZ123'), NVL(item_number,'XYZ123'),organization_code) IN
        --                       (  SELECT NVL(Style,'XYZ123'),
        --                                 NVL(color,'XYZ123'),
        --                                 NVL(item_number,'XYZ123'),
        --                                 organization_code
        --                            FROM xxdo.xxd_cst_duty_correct_tr_t
        --                           WHERE     1 = 1
        --                                 --AND rec_status = 'N'
        --                                 AND request_id = gn_request_id
        --                                 AND file_name = pv_file_name
        ----                                 AND item_number IS NOT NULL
        --                        GROUP BY NVL(Style,'XYZ123'),
        --                                 NVL(color,'XYZ123'),
        --                                 NVL(item_number,'XYZ123'),
        --                                 organization_code
        --                          HAVING COUNT (1) > 1)
        --               --AND rec_status = 'N'
        --               AND request_id = gn_request_id
        --               AND file_name = pv_file_name;
        --
        --            write_log_prc (
        --               SQL%ROWCOUNT
        --            || ' Element records updated with error - Duplicate Records');
        --
        --        COMMIT;
        --
        --        EXCEPTION
        --        WHEN OTHERS
        --        THEN
        --
        --            write_log_prc (' Exception for Duplicate Records section - '||SQLERRM);
        --
        --        END;

        UPDATE xxdo.xxd_cst_duty_correct_tr_t
           SET status   = 'V'
         WHERE     status = 'N'
               AND error_msg IS NULL
               --AND active_flag = 'Y'
               AND request_id = gn_request_id
               AND file_name = pv_file_name;
    --        UPDATE xxdo.xxd_cst_duty_correct_tr_t
    --     SET status = 'V' -- Ignore
    --   WHERE 1 = 1
    --     AND request_id = gn_request_id
    --     AND file_name = pv_file_name
    --     AND item_number IS NULL;
    --
    --  COMMIT;

    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (SQLERRM || 'validate_prc');
    END validate_prc;

    /***************************************************************************
 -- PROCEDURE insert_into_custom_table_prc
 -- PURPOSE: This Procedure insert the duty element recoreds into xxdo.xxd_cst_duty_ele_upld_stg_t
 ***************************************************************************/

    PROCEDURE insert_into_custom_table_prc (pv_file_name IN VARCHAR2)
    IS
        CURSOR cur_tr_data IS
            SELECT organization_code, style, color,
                   item_number, transaction_date, transaction_type,
                   transaction_account, avg_cost, avg_percent_change,
                   mat_avg_cost, mat_avg_percent_change, mat_oh_cost,
                   mat_oh_percent_change, duty, oh_duty,
                   oh_non_duty, freight_duty, freight,
                   future_col1, future_col2, future_col3,
                   future_col4, future_col5, future_col6,
                   future_col7, future_col8, future_col9,
                   future_col10, request_id, file_name,
                   status, error_msg, creation_date,
                   created_by, last_update_date, last_updated_by
              FROM xxdo.xxd_cst_duty_correct_tr_t s
             WHERE     1 = 1
                   AND status = 'V'
                   AND error_msg IS NULL
                   AND request_id = gn_request_id
                   AND UPPER (file_name) = UPPER (pv_file_name);

        --ORDER BY style_number, country_of_origin, destination_country;

        CURSOR cur_comm_items (pv_style_number VARCHAR2, pv_color VARCHAR2, pv_item_number VARCHAR2
                               , pv_inv_org_id VARCHAR2)
        IS
            SELECT inventory_item_id inv_item_id,
                   organization_id org_id,
                   segment1 item_number,
                   REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                  1) style_number,
                   REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                  2) style_color,
                   REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                  3) item_size,
                   primary_uom_code primary_uom_code
              FROM apps.mtl_system_items_b
             WHERE     1 = 1
                   AND NVL (REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                           1),
                            'ABC123') = NVL (pv_style_number, 'ABC123')
                   AND NVL (segment1, 'ABC123') =
                       NVL (pv_item_number, 'ABC123')
                   AND organization_id = pv_inv_org_id
            UNION
            SELECT inventory_item_id,
                   organization_id,
                   segment1 item_number,
                   REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                  1) style_number,
                   REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                  2) style_color,
                   REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                  3) item_size,
                   primary_uom_code primary_uom_code
              FROM apps.mtl_system_items_b
             WHERE     1 = 1
                   AND NVL (REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                           1),
                            'ABC123') = NVL (pv_style_number, 'ABC123')
                   AND NVL (REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                           2),
                            'ABC123') = NVL (pv_color, 'ABC123')
                   AND organization_id = pv_inv_org_id
            UNION
            SELECT inventory_item_id,
                   organization_id,
                   segment1 item_number,
                   REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                  1) style_number,
                   REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                  2) style_color,
                   REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                  3) item_size,
                   primary_uom_code primary_uom_code
              FROM apps.mtl_system_items_b
             WHERE     1 = 1
                   AND NVL (REGEXP_SUBSTR (segment1, '[^-]+', 1,
                                           1),
                            'ABC123') = NVL (pv_style_number, 'ABC123')
                   AND organization_id = pv_inv_org_id;

        /*SELECT inventory_item_id     inv_item_id,
               organization_id       org_id,
               item_number           item_number,
               style_number          style_number,
               color_code            style_color,
               item_size             item_size,
               primary_uom_code      primary_uom_code
          FROM apps.xxd_common_items_v
         WHERE     1 = 1
               AND NVL(style_number,'ABC123') = NVL(pv_style_number,'ABC123')
               AND NVL(item_number,'ABC123') = NVL(pv_item_number,'ABC123')
               AND organization_id = pv_inv_org_id
        UNION
        SELECT inventory_item_id,
               organization_id,
               item_number,
               style_number,
               color_code,
               item_size,
               primary_uom_code
          FROM apps.xxd_common_items_v
         WHERE     1 = 1
               AND NVL(style_number,'ABC123') = NVL(pv_style_number,'ABC123')
               AND NVL(color_code,'ABC123') = NVL(pv_color,'ABC123')
               AND organization_id = pv_inv_org_id
        UNION
        SELECT inventory_item_id,
               organization_id,
               item_number,
               style_number,
               color_code,
               item_size,
               primary_uom_code
          FROM apps.xxd_common_items_v
         WHERE     1 = 1
               AND NVL(style_number,'ABC123') = NVL(pv_style_number,'ABC123')
               AND organization_id = pv_inv_org_id; */

        lv_operating_unit        VARCHAR2 (100);
        -- lv_src_region            VARCHAR2(100);
        -- lv_src_country           VARCHAR2(100);
        -- lv_src_inv_org_id        VARCHAR2(100);
        lv_dest_region           VARCHAR2 (100);
        lv_dest_country          VARCHAR2 (100);
        ln_inv_org_id            NUMBER;
        ln_ccid                  NUMBER;
        lv_org_code              VARCHAR2 (100);
        l_group_id               NUMBER
                                     := xxdo.xxd_cst_duty_ele_upld_stg_t_s.NEXTVAL;
        xv_errbuf                VARCHAR2 (4000);
        xv_retcode               VARCHAR2 (100);
        lv_tot_addl_duty_per     VARCHAR2 (240);
        lv_duty_rate             VARCHAR2 (240);
        lv_start_date            VARCHAR2 (240);
        lv_end_date              VARCHAR2 (240);
        lv_sku_weight_uom_code   VARCHAR2 (240);
        lv_sku_unit_weight       VARCHAR2 (240);
        ln_ele_rec_success       NUMBER;
        ln_ele_rec_error         NUMBER;
        ln_ele_rec_total         NUMBER;
        ln_cnt                   NUMBER;
        lv_cost_group            cst_cost_groups.cost_group%TYPE;
        ln_cost_group_id         cst_cost_groups.cost_group_id%TYPE;
    BEGIN
        write_log_prc ('Procedure insert_into_custom_table_prc Begins...');

        BEGIN
            SELECT COUNT (1)
              INTO ln_cnt
              FROM xxdo.xxd_cst_duty_correct_tr_t
             WHERE     1 = 1
                   AND status = 'V'
                   AND error_msg IS NULL
                   AND file_name = pv_file_name
                   AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                    'Exception occurred while retriving the count from xxdo.xxd_cst_duty_correct_tr_t');
                ln_cnt   := 0;
        END;

        IF ln_cnt > 0
        THEN
            write_log_prc (
                'Procedure insert_into_custom_table_prc Begins again...');

            FOR i IN cur_tr_data
            LOOP
                ln_inv_org_id   := NULL;
                ln_ccid         := NULL;

                BEGIN
                    SELECT organization_id
                      INTO ln_inv_org_id
                      FROM org_organization_definitions
                     WHERE 1 = 1 AND organization_code = i.organization_code;

                    write_log_prc (
                        ' organization_id fetched is  - ' || ln_inv_org_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_inv_org_id   := NULL;
                        write_log_prc (
                            ' Organization is Invalid - ' || i.organization_code);
                END;

                -- Get the Cost Group ID and Cost Group

                BEGIN
                    lv_cost_group      := NULL;
                    ln_cost_group_id   := NULL;

                    write_log_prc ('Fetch the Cost Group Code : ');

                    SELECT cost_group, cost_group_id
                      INTO lv_cost_group, ln_cost_group_id
                      FROM apps.cst_cost_groups
                     WHERE 1 = 1 AND organization_id = ln_inv_org_id;

                    write_log_prc (
                           'Derived the Cost Group Code : '
                        || lv_cost_group
                        || ' With Cost Group ID is - '
                        || ln_cost_group_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc ('Cost Group Code Error - ' || SQLERRM);
                END;

                BEGIN
                    SELECT code_combination_id
                      INTO ln_ccid
                      FROM apps.gl_code_combinations_kfv
                     WHERE     1 = 1
                           AND concatenated_segments = i.transaction_account
                           AND enabled_flag = 'Y';

                    write_log_prc (' CCID fetched is  - ' || ln_ccid);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_ccid   := NULL;
                        write_log_prc (
                            ' Code Combination is Invalid - ' || i.transaction_account);
                END;

                FOR k IN cur_comm_items (i.style, i.color, i.item_number,
                                         ln_inv_org_id)
                LOOP
                    write_log_prc (
                           'inv_item_id:'
                        || k.inv_item_id
                        || 'org_id:'
                        || k.org_id
                        || 'item_number:'
                        || k.item_number
                        || 'style_number:'
                        || k.style_number
                        || 'style_color:'
                        || k.style_color
                        || 'UOM Code is: '
                        || k.primary_uom_code);


                    BEGIN
                        -- write_log_prc ('Create Element Record with Derived columns and Insert into Stg Table');
                        INSERT INTO xxdo.xxd_cst_duty_correct_stg_tr_t (
                                        organization_code,
                                        style,
                                        color,
                                        item_number,
                                        transaction_date,
                                        transaction_type,
                                        transaction_account,
                                        avg_cost,
                                        avg_percent_change,
                                        mat_avg_cost,
                                        mat_avg_percent_change,
                                        mat_oh_cost,
                                        mat_oh_percent_change,
                                        duty,
                                        oh_duty,
                                        oh_non_duty,
                                        freight_duty,
                                        freight,
                                        future_col1,
                                        future_col2,
                                        future_col3,
                                        future_col4,
                                        future_col5,
                                        future_col6,
                                        future_col7,
                                        future_col8,
                                        future_col9,
                                        future_col10,
                                        request_id,
                                        file_name,
                                        status,
                                        error_msg,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        inventory_item_id,
                                        organization_id,
                                        ccid,
                                        primary_uom_code,
                                        cost_group_code,
                                        cost_group_id)
                                 VALUES (i.organization_code,
                                         k.style_number,
                                         k.style_color,
                                         k.item_number,
                                         i.transaction_date,
                                         i.transaction_type,
                                         i.transaction_account,
                                         i.avg_cost,
                                         i.avg_percent_change,
                                         i.mat_avg_cost,
                                         i.mat_avg_percent_change,
                                         i.mat_oh_cost,
                                         i.mat_oh_percent_change,
                                         i.duty,
                                         i.oh_duty,
                                         i.oh_non_duty,
                                         i.freight_duty,
                                         i.freight,
                                         i.future_col1,
                                         i.future_col2,
                                         i.future_col3,
                                         i.future_col4,
                                         i.future_col5,
                                         i.future_col6,
                                         i.future_col7,
                                         i.future_col8,
                                         i.future_col9,
                                         i.future_col10,
                                         i.request_id,
                                         i.file_name,
                                         i.status,
                                         i.error_msg,
                                         SYSDATE,
                                         gn_user_id,
                                         SYSDATE,
                                         gn_user_id,
                                         k.inv_item_id,
                                         k.org_id,
                                         ln_ccid,
                                         k.primary_uom_code,
                                         lv_cost_group,
                                         ln_cost_group_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            write_log_prc (
                                   SQLERRM
                                || ' Insertion Failed for Staging table: xxdo.xxd_cst_duty_ele_upld_stg_t');
                    END;

                    i.error_msg   := '';

                    EXIT WHEN cur_comm_items%NOTFOUND;
                END LOOP;

                COMMIT;
                EXIT WHEN cur_tr_data%NOTFOUND;
            END LOOP;

            COMMIT;

            BEGIN
                write_log_prc ('Update Inbound Stg table as Processed');

                UPDATE xxdo.xxd_cst_duty_correct_tr_t s
                   SET status   = 'P'
                 WHERE     1 = 1
                       AND status = 'V'
                       AND error_msg IS NULL
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_cst_duty_correct_stg_tr_t u
                                 WHERE     1 = 1
                                       AND s.style = u.style
                                       AND u.request_id = gn_request_id);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log_prc (
                           ' Updation Failed for Staging table: xxdo.xxd_cst_duty_correct_tr_t'
                        || SQLERRM);
            END;


            SELECT COUNT (1)
              INTO ln_ele_rec_total
              FROM xxdo.xxd_cst_duty_correct_tr_t
             WHERE request_id = gn_request_id;

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '**************************************************************************************');
        --            apps.fnd_file.put_line (
        --                apps.fnd_file.output,
        --                   ' Number of Rows in Process Staging Table  -                         '
        --                || ln_ele_rec_total);
        ELSIF ln_cnt = 0
        THEN
            write_log_prc (
                   'No Valid records are present in the xxdo.xxd_cst_duty_correct_tr_t table and SQLERRM'
                || SQLERRM);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                'No Valid records are present in the xxdo.xxd_cst_duty_correct_tr_t table');
        END IF;


        write_log_prc ('Procedure insert_into_custom_table_prc Ends...');
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Error in Procedure insert_into_custom_table_prc:' || SQLERRM);
    END insert_into_custom_table_prc;

    PROCEDURE get_cost_prc (pn_inventory_item_id IN NUMBER, pn_organization_id IN NUMBER, x_mat_cost OUT NUMBER
                            , x_mat_OH_cost OUT NUMBER, x_total_cost OUT NUMBER, x_error_msg OUT VARCHAR2)
    IS
    BEGIN
        SELECT material_cost, Material_overhead_cost
          INTO x_mat_cost, x_mat_OH_cost
          FROM apps.cst_item_costs
         WHERE     1 = 1
               AND inventory_item_id = pn_inventory_item_id
               AND organization_id = pn_organization_id
               AND cost_type_id = 2;

        x_total_cost   := NVL (x_mat_cost, 0) + NVL (x_mat_OH_cost, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_mat_cost      := NULL;
            x_mat_OH_cost   := NULL;
            x_total_cost    := NULL;
            x_error_msg     :=
                   'Error While getting the Material Cost of an Item - '
                || SQLERRM;
    END get_cost_prc;

    PROCEDURE validate_interface_prc (pv_file_name IN VARCHAR2)
    IS
        CURSOR fetch_duty_elements IS
            SELECT ROWID, Organization_code, Style,
                   Color, Item_Number, Transaction_Date,
                   Transaction_type, Transaction_Account, Avg_cost,
                   Avg_Percent_change, Mat_Avg_cost, Mat_Avg_Percent_change,
                   Mat_OH_cost, Mat_OH_Percent_change, Duty,
                   oh_duty, oh_non_Duty, Freight_Duty,
                   Freight, Future_col1, Future_col2,
                   Future_col3, Future_col4, Future_col5,
                   Future_col6, Future_col7, Future_col8,
                   Future_col9, Future_col10, request_id,
                   file_name, status, error_msg,
                   creation_date, created_by, last_update_date,
                   last_updated_by, inventory_item_id, organization_id,
                   ccid
              FROM xxdo.xxd_cst_duty_correct_stg_tr_t
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND status = 'V'
                   AND UPPER (file_name) = UPPER (pv_file_name)
                   AND inventory_item_id IS NOT NULL;

        TYPE tb_rec IS TABLE OF fetch_duty_elements%ROWTYPE;

        v_tb_rec                 tb_rec;

        v_bulk_limit             NUMBER := 5000;

        e_bulk_errors            EXCEPTION;
        PRAGMA EXCEPTION_INIT (e_bulk_errors, -24381);
        l_msg                    VARCHAR2 (4000);
        l_idx                    NUMBER;
        l_error_count            NUMBER;

        lv_err_msg               VARCHAR2 (4000);
        lv_err_msg1              VARCHAR2 (4000);
        ln_curr_mat_cost         NUMBER;
        ln_curr_mat_OH_cost      NUMBER;
        ln_curr_total_cost       NUMBER;
        ln_mat_cost_percent      NUMBER;
        ln_mat_oh_cost_percent   NUMBER;
        ln_new_mat_cost          NUMBER;
        ln_mat_OH_cost           NUMBER;
        l_upd_count              NUMBER;
        ln_override_OH_cost      NUMBER;
    BEGIN
        write_log_prc ('Load Data into Interface PRC Begins...');

        OPEN fetch_duty_elements;

        --v_tb_rec.DELETE;

        LOOP
            l_upd_count   := 0;

            FETCH fetch_duty_elements
                BULK COLLECT INTO v_tb_rec
                LIMIT v_bulk_limit;

            EXIT WHEN v_tb_rec.COUNT = 0;

            IF v_tb_rec.COUNT > 0
            THEN
                write_log_prc ('Record Count: ' || v_tb_rec.COUNT);

                BEGIN
                    FOR i IN 1 .. v_tb_rec.COUNT
                    LOOP
                        l_upd_count           := l_upd_count + 1;

                        v_tb_rec (i).status   := 'I';

                        lv_err_msg1           := NULL;
                        lv_err_msg            := NULL;
                        ln_override_OH_cost   := NULL;

                        IF    NVL (v_tb_rec (i).Duty, 0) <> 0
                           OR NVL (v_tb_rec (i).oh_duty, 0) <> 0
                           OR NVL (v_tb_rec (i).oh_non_Duty, 0) <> 0
                           OR NVL (v_tb_rec (i).Freight_Duty, 0) <> 0
                           OR NVL (v_tb_rec (i).Freight, 0) <> 0
                        THEN
                            ln_override_OH_cost   :=
                                  NVL (v_tb_rec (i).Duty, 0)
                                + NVL (v_tb_rec (i).oh_duty, 0)
                                + NVL (v_tb_rec (i).oh_non_Duty, 0)
                                + NVL (v_tb_rec (i).Freight_Duty, 0)
                                + NVL (v_tb_rec (i).Freight, 0);
                        END IF;


                        IF     v_tb_rec (i).inventory_item_id IS NOT NULL
                           AND v_tb_rec (i).organization_id IS NOT NULL
                        THEN
                            BEGIN
                                get_cost_prc (
                                    pn_inventory_item_id   =>
                                        v_tb_rec (i).inventory_item_id,
                                    pn_organization_id   =>
                                        v_tb_rec (i).organization_id,
                                    x_mat_cost      => ln_curr_mat_cost,
                                    x_mat_OH_cost   => ln_curr_mat_OH_cost,
                                    x_total_cost    => ln_curr_total_cost,
                                    x_error_msg     => lv_err_msg1);

                                IF lv_err_msg1 IS NOT NULL
                                THEN
                                    v_tb_rec (i).status   := 'E';
                                    v_tb_rec (i).error_msg   :=
                                        v_tb_rec (i).error_msg || lv_err_msg1;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    write_log_prc (
                                        'Organization Code' || SQLERRM);
                            END;

                            --- Now Determine the % of Cost and OH value of the total cost

                            IF ln_curr_total_cost <> 0
                            THEN
                                NULL;

                                ln_mat_cost_percent   :=
                                    (ln_curr_mat_cost / ln_curr_total_cost);
                                ln_mat_oh_cost_percent   :=
                                    (ln_curr_mat_OH_cost / ln_curr_total_cost);

                                -- This is applicable only when Average Cost is NOT NULL

                                IF NVL (v_tb_rec (i).Avg_cost, 0) <> 0
                                THEN
                                    --ln_new_mat_cost  := ln_curr_mat_cost+ROUND(ln_mat_cost_percent*v_tb_rec (i). Avg_cost,5) ;
                                    --ln_Mat_OH_cost   := ln_curr_mat_OH_cost+ROUND(ln_mat_oh_cost_percent*v_tb_rec (i). Avg_cost,5) ;

                                    ln_new_mat_cost   :=
                                        ROUND (
                                              ln_mat_cost_percent
                                            * v_tb_rec (i).Avg_cost,
                                            5);
                                    ln_Mat_OH_cost   :=
                                        ROUND (
                                              ln_mat_oh_cost_percent
                                            * v_tb_rec (i).Avg_cost,
                                            5);
                                ELSIF     NVL (v_tb_rec (i).Avg_cost, 0) = 0
                                      AND NVL (
                                              v_tb_rec (i).Avg_Percent_change,
                                              0) <>
                                          0
                                THEN
                                    -- ln_new_mat_cost     := ROUND(ln_mat_cost_percent*v_tb_rec (i). Avg_Percent_change,5) ;  -- ln_curr_mat_cost
                                    -- ln_Mat_OH_cost   := ROUND(ln_mat_oh_cost_percent*v_tb_rec (i). Avg_Percent_change,5) ;

                                    ln_new_mat_cost   :=
                                          ln_curr_mat_cost
                                        + ROUND (
                                                ln_curr_mat_cost
                                              * (v_tb_rec (i).Avg_Percent_change / 100),
                                              5);          -- ln_curr_mat_cost
                                    ln_Mat_OH_cost   :=
                                          ln_curr_mat_OH_cost
                                        + ROUND (
                                                ln_curr_mat_OH_cost
                                              * (v_tb_rec (i).Avg_Percent_change / 100),
                                              5);
                                ELSIF     NVL (v_tb_rec (i).Avg_cost, 0) = 0
                                      AND NVL (
                                              v_tb_rec (i).Avg_Percent_change,
                                              0) =
                                          0
                                THEN
                                    IF NVL (v_tb_rec (i).Mat_Avg_cost, 0) <>
                                       0
                                    THEN
                                        -- ln_new_mat_cost     := ln_curr_mat_cost+ROUND(ln_mat_cost_percent*v_tb_rec (i). Mat_Avg_cost,5) ;
                                        --ln_Mat_OH_cost  := ROUND(ln_mat_oh_cost_percent*v_tb_rec (i). Avg_cost) ;
                                        ln_new_mat_cost   :=
                                            ROUND (v_tb_rec (i).Mat_Avg_cost,
                                                   5);
                                    ELSIF     NVL (v_tb_rec (i).Mat_Avg_cost,
                                                   0) =
                                              0
                                          AND NVL (
                                                  v_tb_rec (i).Mat_Avg_Percent_change,
                                                  0) <>
                                              0
                                    THEN
                                        ln_new_mat_cost   :=
                                              ln_curr_mat_cost
                                            + ROUND (
                                                    ln_curr_mat_cost
                                                  * (v_tb_rec (i).Mat_Avg_Percent_change / 100),
                                                  5);
                                    --ln_Mat_OH_cost  := ROUND(ln_mat_oh_cost_percent*v_tb_rec (i). Avg_Percent_change);

                                    END IF;

                                    IF NVL (v_tb_rec (i).Mat_OH_cost, 0) <> 0
                                    THEN
                                        --ln_new_mat_cost     := ROUND(ln_mat_cost_percent*v_tb_rec (i). Mat_Avg_cost) ;
                                        --ln_Mat_OH_cost  := ln_curr_mat_OH_cost+ROUND(ln_mat_cost_percent*v_tb_rec (i). Mat_OH_cost,5) ;
                                        ln_Mat_OH_cost   :=
                                            ROUND (v_tb_rec (i).Mat_OH_cost,
                                                   5);
                                    ELSIF     NVL (v_tb_rec (i).Mat_OH_cost,
                                                   0) =
                                              0
                                          AND NVL (
                                                  v_tb_rec (i).Mat_OH_Percent_change,
                                                  0) <>
                                              0
                                    THEN
                                        --ln_new_mat_cost     := ROUND(ln_mat_cost_percent*v_tb_rec (i). Mat_Avg_Percent_change) ;
                                        ln_Mat_OH_cost   :=
                                              ln_curr_mat_OH_cost
                                            + ROUND (
                                                    ln_curr_mat_OH_cost
                                                  * (v_tb_rec (i).Mat_OH_Percent_change / 100),
                                                  5);
                                    ELSIF     NVL (v_tb_rec (i).Mat_OH_cost,
                                                   0) =
                                              0
                                          AND NVL (
                                                  v_tb_rec (i).Mat_OH_Percent_change,
                                                  0) =
                                              0
                                          AND NVL (ln_override_OH_cost, 0) <>
                                              0
                                    THEN
                                        --ln_new_mat_cost     := ROUND(ln_mat_cost_percent*v_tb_rec (i). Mat_Avg_Percent_change) ;
                                        ln_Mat_OH_cost   :=
                                            ROUND (ln_override_OH_cost, 5);
                                    END IF;
                                END IF;
                            END IF;
                        ELSE
                            v_tb_rec (i).status   := 'E';
                            v_tb_rec (i).error_msg   :=
                                   v_tb_rec (i).error_msg
                                || ' - Inventory Item and Organization ID cannot be NULL 
																				for deriving the Overhead Values ';
                        END IF;


                        UPDATE xxdo.xxd_cst_duty_correct_stg_tr_t
                           SET curr_mat_cost = ln_curr_mat_cost, curr_mat_oh_cost = ln_curr_mat_oh_cost, curr_total_cost = ln_curr_total_cost,
                               mat_cost_percent = ln_mat_cost_percent, mat_oh_cost_percent = ln_mat_oh_cost_percent, new_mat_cost = ln_new_mat_cost,
                               new_Mat_OH_cost = ln_Mat_OH_cost, status = v_tb_rec (i).status, error_msg = v_tb_rec (i).error_msg
                         WHERE     inventory_item_id =
                                   v_tb_rec (i).inventory_item_id
                               AND organization_id =
                                   v_tb_rec (i).organization_id
                               AND request_id = gn_request_id
                               AND status = 'V'
                               AND UPPER (file_name) = UPPER (pv_file_name);

                        IF l_upd_count >= 1000
                        THEN
                            COMMIT;
                            l_upd_count   := 0;
                        END IF;
                    END LOOP;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                        write_log_prc (
                            SQLERRM || ' Record wise Validations Failed');
                END;

                BEGIN
                    FORALL i IN v_tb_rec.FIRST .. v_tb_rec.LAST
                      SAVE EXCEPTIONS
                        UPDATE xxdo.xxd_cst_duty_correct_stg_tr_t
                           SET creation_date = SYSDATE, last_update_date = SYSDATE, created_by = gn_user_id,
                               last_updated_by = gn_user_id
                         --                               status = v_tb_rec (i).status,
                         --                               error_msg = v_tb_rec (i).error_msg
                         WHERE ROWID = v_tb_rec (i).ROWID;
                --                    write_log_prc (SQL%ROWCOUNT || ' Number of Records Updated in the table with Status - '||v_tb_rec (i).status);
                EXCEPTION
                    WHEN e_bulk_errors
                    THEN
                        write_log_prc ('Inside E_BULK_ERRORS');
                        l_error_count   := SQL%BULK_EXCEPTIONS.COUNT;

                        FOR i IN 1 .. l_error_count
                        LOOP
                            l_msg   :=
                                SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                            l_idx   := SQL%BULK_EXCEPTIONS (i).ERROR_INDEX;
                            write_log_prc (
                                   'Failed to update TR Element For Style Number- '
                                || v_tb_rec (l_idx).item_number
                                || ' with error_code- '
                                || l_msg);
                        END LOOP;
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                            'Update Failed for Error Records' || SQLERRM);
                END;

                COMMIT;
            END IF;
        --EXIT WHEN feth_duty_elements%NOTFOUND;
        END LOOP;
    END validate_interface_prc;

    PROCEDURE load_interface_prc (pv_file_name IN VARCHAR2)
    IS
        CURSOR trxn_cur IS
            SELECT *
              FROM xxdo.xxd_cst_duty_correct_stg_tr_t
             WHERE     request_id = gn_request_id
                   AND status = 'I'
                   AND file_name = pv_file_name;

        CURSOR mat_trxn_cur (pn_inventory_item_id   NUMBER,
                             pn_organization_id     NUMBER)
        IS
            SELECT *
              FROM xxdo.xxd_cst_duty_correct_stg_tr_t
             WHERE     inventory_item_id = pn_inventory_item_id
                   AND organization_id = pn_organization_id
                   AND request_id = gn_request_id
                   AND status = 'I'
                   AND file_name = pv_file_name
                   AND (avg_cost IS NOT NULL OR avg_percent_change IS NOT NULL OR mat_avg_cost IS NOT NULL OR mat_avg_percent_change IS NOT NULL);

        CURSOR oh_mat_trxn_cur (pn_inventory_item_id   NUMBER,
                                pn_organization_id     NUMBER)
        IS
            SELECT *
              FROM xxdo.xxd_cst_duty_correct_stg_tr_t
             WHERE     inventory_item_id = pn_inventory_item_id
                   AND organization_id = pn_organization_id
                   AND request_id = gn_request_id
                   AND status = 'I'
                   AND file_name = pv_file_name
                   AND (avg_cost IS NOT NULL OR avg_percent_change IS NOT NULL OR mat_oh_cost IS NOT NULL OR mat_oh_percent_change IS NOT NULL OR FREIGHT IS NOT NULL OR FREIGHT_DUTY IS NOT NULL OR OH_NON_DUTY IS NOT NULL OR OH_DUTY IS NOT NULL OR DUTY IS NOT NULL);

        l_insert_count   NUMBER := 0;
    BEGIN
        l_insert_count   := 0;

        FOR trxn_rec IN trxn_cur
        LOOP
            l_insert_count   := l_insert_count + 1;

            INSERT INTO mtl_transactions_interface (source_code, source_line_id, source_header_id, process_flag, transaction_mode, creation_date, last_update_date, created_by, last_updated_by, inventory_item_id, organization_id, transaction_date, transaction_quantity, transaction_uom, transaction_type_id, transaction_interface_id, material_overhead_account, material_account, resource_account, overhead_account, outside_processing_account
                                                    , cost_group_id)
                 VALUES ('AvgCostUpdate', 1, 1,
                         1, 3, SYSDATE,
                         SYSDATE, gn_user_id, gn_user_id,
                         trxn_rec.inventory_item_id,   --5773922,--900363834 ,
                                                     trxn_rec.organization_id, SYSDATE, 0, trxn_rec.primary_uom_code, 80, mtl_material_transactions_s.NEXTVAL, trxn_rec.ccid, trxn_rec.ccid, trxn_rec.ccid, trxn_rec.ccid, trxn_rec.ccid
                         , trxn_rec.cost_group_id);

            FOR mat_trxn
                IN mat_trxn_cur (trxn_rec.inventory_item_id,
                                 trxn_rec.organization_id)
            LOOP
                INSERT INTO mtl_txn_cost_det_interface (
                                cost_element_id,
                                level_Type,
                                Organization_id,
                                new_average_cost,
                                transaction_cost,
                                transaction_interface_id,
                                last_update_date,
                                creation_date,
                                last_updated_by,
                                created_by,
                                percentage_change,
                                value_change)
                     VALUES (1, 1, mat_trxn.organization_id,
                             mat_trxn.new_mat_cost, NULL, mtl_material_transactions_s.CURRVAL, SYSDATE, SYSDATE, gn_user_id
                             , gn_user_id, NULL, NULL);
            END LOOP;

            FOR oh_mat_trxn
                IN oh_mat_trxn_cur (trxn_rec.inventory_item_id,
                                    trxn_rec.organization_id)
            LOOP
                INSERT INTO mtl_txn_cost_det_interface (
                                cost_element_id,
                                level_Type,
                                Organization_id,
                                new_average_cost,
                                transaction_cost,
                                transaction_interface_id,
                                last_update_date,
                                creation_date,
                                last_updated_by,
                                created_by,
                                percentage_change,
                                value_change)
                     VALUES (2, 1, oh_mat_trxn.organization_id,
                             oh_mat_trxn.new_mat_oh_cost, NULL, mtl_material_transactions_s.CURRVAL, SYSDATE, SYSDATE, gn_user_id
                             , gn_user_id, NULL, NULL);
            END LOOP;

            IF l_insert_count >= 1000
            THEN
                COMMIT;
                l_insert_count   := 0;
            END IF;
        END LOOP;

        COMMIT;

        BEGIN
            UPDATE xxdo.xxd_cst_duty_correct_stg_tr_t xcdeus
               SET xcdeus.status   = 'P'
             WHERE     1 = 1
                   AND EXISTS
                           (SELECT 1
                              FROM mtl_transactions_interface mti, mtl_txn_cost_det_interface mtcdi
                             WHERE     1 = 1
                                   AND xcdeus.inventory_item_id =
                                       mti.inventory_item_id
                                   AND xcdeus.organization_id =
                                       mti.organization_id
                                   AND mti.transaction_interface_id =
                                       mtcdi.transaction_interface_id
                                   AND mti.ERROR_CODE IS NULL)
                   AND xcdeus.request_id = gn_request_id
                   AND xcdeus.status = 'I'
                   AND xcdeus.file_name = pv_file_name;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                       'Exception Occured while updating status I to staging table: '
                    || SQLERRM);
        END;
    --        NULL;
    END load_interface_prc;

    /***************************************************************************
    -- PROCEDURE update_interface_status_prc
    -- PURPOSE: This Procedure update staging table rec_status based on
    --          Interface record status
    ***************************************************************************/
    PROCEDURE update_interface_status_prc (pv_file_name IN VARCHAR2)
    IS
        CURSOR c_interfaced_records IS
            SELECT *
              FROM xxdo.xxd_cst_duty_correct_stg_tr_t
             WHERE 1 = 1 AND status = 'P';

        CURSOR c_err (p_item_id NUMBER, p_org_id NUMBER)
        IS
            SELECT ERROR_CODE, error_explanation
              FROM mtl_transactions_interface
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND inventory_item_id = p_item_id
                   AND organization_id = p_org_id;

        l_status         VARCHAR2 (1);
        l_err_msg        VARCHAR2 (4000);
        v_interfaced     VARCHAR2 (1);
        l_update_count   NUMBER := 0;
    BEGIN
        write_log_prc ('Procedure update_interface_status_prc Begins....');

        BEGIN
            UPDATE xxdo.xxd_cst_duty_correct_stg_tr_t xcdeus
               SET xcdeus.status   = 'S'
             WHERE     EXISTS
                           (SELECT 1
                              FROM mtl_transactions_interface
                             WHERE     1 = 1
                                   AND xcdeus.inventory_item_id =
                                       inventory_item_id
                                   AND xcdeus.organization_id =
                                       organization_id
                                   AND ERROR_CODE IS NULL
                                   AND process_flag = 1)
                   AND xcdeus.request_id = gn_request_id
                   AND xcdeus.status = 'P'
                   AND xcdeus.file_name = pv_file_name;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                       'Exception Occured while updating the processed status in staging table: '
                    || SQLERRM);
        END;

        BEGIN
            UPDATE xxdo.xxd_cst_duty_correct_stg_tr_t xcdeus
               SET xcdeus.status   = 'E',
                   error_msg      =
                       (SELECT error_explanation
                          FROM mtl_transactions_interface int
                         WHERE     1 = 1
                               AND xcdeus.inventory_item_id =
                                   int.inventory_item_id
                               AND xcdeus.organization_id =
                                   int.organization_id
                               AND ERROR_CODE IS NOT NULL)
             WHERE     EXISTS
                           (SELECT 1
                              FROM mtl_transactions_interface int
                             WHERE     1 = 1
                                   AND xcdeus.inventory_item_id =
                                       inventory_item_id
                                   AND xcdeus.organization_id =
                                       organization_id
                                   AND ERROR_CODE IS NOT NULL)
                   AND xcdeus.request_id = gn_request_id
                   AND xcdeus.file_name = pv_file_name;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                       ' Exception Occured while updating the Error status in staging table by checking in Interface: '
                    || SQLERRM);
        END;

        BEGIN
            UPDATE xxdo.xxd_cst_duty_correct_tr_t xcdcrt
               SET (status, error_msg)   =
                       (SELECT status, error_msg
                          FROM xxdo.xxd_cst_duty_correct_stg_tr_t xcdcsrt
                         WHERE     1 = 1
                               AND xcdcsrt.style = xcdcrt.style
                               --AND
                               AND NVL (xcdcrt.item_number, 'ABC123') =
                                   NVL (xcdcsrt.item_number, 'ABC123')
                               AND xcdcsrt.organization_code =
                                   xcdcrt.organization_code
                               AND xcdcsrt.request_id = xcdcrt.request_id
                               AND xcdcsrt.file_name = xcdcrt.file_name
                               AND xcdcsrt.request_id = gn_request_id-- AND GROUP_ID = p_group_id
                                                                     )
             WHERE     1 = 1
                   AND xcdcrt.request_id = gn_request_id
                   AND xcdcrt.item_number IS NOT NULL
                   AND xcdcrt.file_name = pv_file_name;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                       'Exception Occured while updating the status in Initial staging table: '
                    || SQLERRM);
        END;

        COMMIT;

        write_log_prc ('Procedure update_interface_status_prc Ends....');
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Error in update_interface_status_prc Procedure -' || SQLERRM);
    END update_interface_status_prc;

    /***************************************************************************
 -- PROCEDURE generate_exception_report_prc
 -- PURPOSE: This Procedure generate the output and write the file
 -- into Exception directory
 **************************************************************************/
    PROCEDURE generate_exception_report_prc (pv_exc_file_name OUT VARCHAR2)
    IS
        CURSOR exception_rec IS
              SELECT seq, line
                FROM (SELECT 1 AS seq, Organization_code || gv_delim_pipe || Style || gv_delim_pipe || Color || gv_delim_pipe || Item_Number || gv_delim_pipe || Transaction_Date || gv_delim_pipe || Transaction_type || gv_delim_pipe || Transaction_account || gv_delim_pipe || Avg_cost || gv_delim_pipe || Avg_percent_change || gv_delim_pipe || Mat_Avg_cost || gv_delim_pipe || Mat_Avg_percent_change || gv_delim_pipe || Mat_OH_cost || gv_delim_pipe || Mat_OH_percent_change || gv_delim_pipe || Duty || gv_delim_pipe || OH_Duty || gv_delim_pipe || OH_Non_Duty || gv_delim_pipe || Freight_DUty || gv_delim_pipe || Freight || gv_delim_pipe || status || gv_delim_pipe || error_msg || gv_delim_pipe || file_name line
                        FROM xxdo.xxd_cst_duty_correct_tr_t
                       WHERE     1 = 1
                             AND status = 'E'
                             AND error_msg IS NOT NULL
                             AND request_id = gn_request_id
                      UNION
                      SELECT 2 AS seq, 'Organization' || gv_delim_pipe || 'Style' || gv_delim_pipe || 'Color' || gv_delim_pipe || 'Item Number' || gv_delim_pipe || 'Transaction Date' || gv_delim_pipe || 'Transaction Type' || gv_delim_pipe || 'Transaction Account' || gv_delim_pipe || 'New Avg Cost' || gv_delim_pipe || '% Change' || gv_delim_pipe || 'New Mat Average Cost' || gv_delim_pipe || 'New Mat Average %' || gv_delim_pipe || 'New Mat OH Cost' || gv_delim_pipe || 'New Mat OH %' || gv_delim_pipe || 'Duty' || gv_delim_pipe || 'OH Duty' || gv_delim_pipe || 'OH Non Duty' || gv_delim_pipe || 'Freight DU' || gv_delim_pipe || 'Freight' || gv_delim_pipe || 'Record Status' || gv_delim_pipe || 'Error Msg' || gv_delim_pipe || 'File Name'
                        FROM DUAL)
            ORDER BY seq DESC;

        --DEFINE VARIABLES
        lv_output_file      UTL_FILE.file_type;
        lv_outbound_file    VARCHAR2 (4000);
        lv_err_msg          VARCHAR2 (4000) := NULL;
        lv_line             VARCHAR2 (32767) := NULL;
        lv_directory_path   VARCHAR2 (2000);
        lv_file_name        VARCHAR2 (4000);
        l_line              VARCHAR2 (4000);
        lv_result           VARCHAR2 (1000);
    BEGIN
        lv_outbound_file   :=
               gn_request_id
            || '_Exception_RPT_'
            || TO_CHAR (SYSDATE, 'RRRR-MON-DD HH24:MI:SS')
            || '.txt';
        write_log_prc ('Exception File Name is - ' || lv_outbound_file);

        -- Derive the directory Path

        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_CST_DUTY_ELE_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
        END;

        /*       BEGIN
             SELECT COUNT(1)
               INTO ln_rec_exists
               FROM xxdo.xxd_cst_duty_ele_inb_stg_tr_t
              WHERE 1 = 1
                --AND rec_status = 'E'
                --AND error_msg IS NOT NULL
                AND request_id = gn_request_id
                AND filename = pv_file_name;
        EXCEPTION
             WHEN OTHERS
             THEN
                  ln_rec_exists := 0;
        END;

        IF ln_rec_exists = 0
        THEN

            lv_output_file :=
                UTL_FILE.fopen (lv_directory_path,
                                lv_outbound_file,
                                'W'       --opening the file in write mode
                                   ,
                                32767);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
               l_line := pv_msg;
               UTL_FILE.put_line (lv_output_file, lv_line);

            ELSE
              lv_err_msg :=
                  SUBSTR (
                         'Error in Opening the data file for writing. Error is : '
                      || SQLERRM,
                      1,
                      2000);
              write_log_prc (lv_err_msg);

              RETURN;

            END IF;

        ELSIF ln_rec_exists > 0
        THEN*/

        FOR i IN exception_rec
        LOOP
            l_line   := i.line;
            write_log_prc (l_line);
        END LOOP;

        -- WRITE INTO FOLDER

        lv_output_file     :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                    ,
                            32767);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            FOR i IN exception_rec
            LOOP
                lv_line   := i.line;
                UTL_FILE.put_line (lv_output_file, lv_line);
            END LOOP;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Error in Opening the data file for writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log_prc (lv_err_msg);

            RETURN;
        END IF;

        --END IF;

        UTL_FILE.fclose (lv_output_file);
        pv_exc_file_name   := lv_outbound_file;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END generate_exception_report_prc;

    PROCEDURE generate_report_prc                --(pv_file_name IN  VARCHAR2)
    IS
        ln_count                NUMBER;
        lv_directory_path       VARCHAR2 (1000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_directory            VARCHAR2 (1000);
        lv_file_name            VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_ret_message          VARCHAR2 (4000) := NULL;
        lv_ret_code             VARCHAR2 (30) := NULL;
        ln_file_exists          NUMBER;
        lv_line                 VARCHAR2 (32767) := NULL;
        lv_all_file_names       VARCHAR2 (4000) := NULL;
        ln_rec_fail             NUMBER := 0;
        ln_rec_success          NUMBER;
        ln_rec_total            NUMBER;
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_message1             VARCHAR2 (32000);
        lv_message2             VARCHAR2 (32000);
        lv_message3             VARCHAR2 (32000);
        lv_sender               VARCHAR2 (100);
        lv_recipients           VARCHAR2 (4000);
        lv_ccrecipients         VARCHAR2 (4000);
        l_cnt                   NUMBER := 0;
        ln_upd_count            NUMBER := 0;
        ln_upd_rec_fail         NUMBER := 0;
        ln_upd_rec_total        NUMBER := 0;
        ln_upd_rec_success      NUMBER := 0;
    BEGIN
        ln_count                := 0;
        ln_rec_fail             := 0;
        ln_rec_total            := 0;
        ln_rec_success          := 0;
        ln_upd_count            := 0;
        ln_upd_rec_fail         := 0;
        ln_upd_rec_total        := 0;
        ln_upd_rec_success      := 0;
        lv_exc_directory_path   := NULL;

        BEGIN
            SELECT COUNT (1)
              INTO ln_count
              FROM xxdo.xxd_cst_duty_correct_tr_t
             WHERE 1 = 1 AND request_id = gn_request_id;
        --                   AND UPPER(file_name) =  UPPER(pv_file_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_count   := 0;
        END;


        IF ln_count < 0
        THEN
            write_log_prc ('There is nothing to Process...No File Exists.');
        ELSE
            BEGIN
                SELECT COUNT (1)
                  INTO ln_rec_fail
                  FROM xxdo.xxd_cst_duty_correct_tr_t
                 WHERE     1 = 1
                       AND status = 'E'
                       AND error_msg IS NOT NULL
                       AND request_id = gn_request_id;
            --                       AND UPPER(file_name) =  UPPER(pv_file_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_rec_fail   := 0;
            END;

            SELECT COUNT (1)
              INTO ln_rec_total
              FROM xxdo.xxd_cst_duty_correct_tr_t
             WHERE request_id = gn_request_id;

            ln_rec_success       := ln_rec_total - ln_rec_fail;

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '              Summary of Deckers Average Cost Update ');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                'Date:' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '************************************************************************');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Considered into Inbound Staging Table - '
                || ln_rec_total);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Errored                               - '
                || ln_rec_fail);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Successful                            - '
                || ln_rec_success);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '************************************************************************');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');

            --            apps.fnd_file.put_line (apps.fnd_file.output, '');

            BEGIN
                SELECT COUNT (1)
                  INTO ln_upd_rec_fail
                  FROM xxdo.xxd_cst_duty_correct_stg_tr_t
                 WHERE     1 = 1
                       AND status = 'E'
                       AND error_msg IS NOT NULL
                       AND request_id = gn_request_id;
            --                       AND UPPER(file_name) =  UPPER(pv_file_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_upd_rec_fail   := 0;
            END;

            SELECT COUNT (1)
              INTO ln_upd_rec_total
              FROM xxdo.xxd_cst_duty_correct_stg_tr_t
             WHERE request_id = gn_request_id;

            ln_upd_rec_success   := ln_upd_rec_total - ln_upd_rec_fail;

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '              Details of Deckers Average Cost Update ');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            --            apps.fnd_file.put_line (apps.fnd_file.output,'Date:' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
            --            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '************************************************************************');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Considered into Detail Staging Table  - '
                || ln_upd_rec_total);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Errored                               - '
                || ln_upd_rec_fail);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Successful                            - '
                || ln_upd_rec_success);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '************************************************************************');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
        END IF;

        IF ln_rec_fail > 0
        THEN
            generate_exception_report_prc (lv_exc_file_name);

            BEGIN
                SELECT directory_path
                  INTO lv_exc_directory_path
                  FROM dba_directories
                 WHERE     1 = 1
                       AND directory_name LIKE 'XXD_CST_DUTY_ELE_EXC_DIR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_directory_path   := NULL;
            END;

            lv_exc_file_name   :=
                   lv_exc_directory_path
                || lv_mail_delimiter
                || lv_exc_file_name;



            write_log_prc (lv_exc_file_name);

            IF 1 = 1
            THEN
                lv_message1   :=
                       'Hello Team,'
                    || CHR (10)
                    || CHR (10)
                    || 'Please Find the Attached Deckers Average Cost Update Exception Report. '
                    || CHR (10)
                    || CHR (10)
                    --|| lv_message2
                    || CHR (10)
                    --|| lv_message3
                    || CHR (10)
                    || CHR (10)
                    || 'Regards,'
                    || CHR (10)
                    || 'SYSADMIN.'
                    || CHR (10)
                    || CHR (10)
                    || 'Note: This is auto generated mail, please donot reply.';

                BEGIN
                    SELECT LISTAGG (ffvl.description, ';') WITHIN GROUP (ORDER BY ffvl.description)
                      INTO lv_recipients
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                     WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                           AND fvs.flex_value_set_name =
                               'XXD_CM_AVG_COST_UPD_EMAIL_VS'
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
                        lv_recipients   := NULL;
                END;

                xxdo_mail_pkg.send_mail (
                    pv_sender         => 'erp@deckers.com',
                    pv_recipients     => lv_recipients,
                    pv_ccrecipients   => NULL, --'srinath.siricilla@deckers.com',
                    pv_subject        =>
                        'Deckers Average Cost Update Exception Report',
                    pv_message        => lv_message1,
                    pv_attachments    => lv_exc_file_name,
                    xv_result         => lv_result,
                    xv_result_msg     => lv_result_msg);

                write_log_prc ('lvresult is - ' || lv_result);
                write_log_prc ('lv_result_msg is - ' || lv_result_msg);
            END IF;
        END IF;
    END;


    PROCEDURE main_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    IS
        CURSOR get_file_cur IS
              SELECT filename
                FROM XXD_DIR_LIST_TBL_SYN
               WHERE 1 = 1 AND UPPER (filename) NOT LIKE UPPER ('%ARCHIVE%')
            ORDER BY filename;

        CURSOR get_file_names_cur IS
              SELECT file_name
                FROM xxdo.xxd_cst_duty_correct_tr_t
               WHERE request_id = gn_request_id
            --AND  status = 'N'
            GROUP BY file_name;

        lv_directory_path       VARCHAR2 (1000);
        lv_inb_directory_path   VARCHAR2 (1000);
        lv_arc_directory_path   VARCHAR2 (1000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_directory            VARCHAR2 (1000);
        lv_file_name            VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_ret_message          VARCHAR2 (4000) := NULL;
        lv_ret_code             VARCHAR2 (30) := NULL;
        ln_file_exists          NUMBER;
        lv_line                 VARCHAR2 (32767) := NULL;
        lv_all_file_names       VARCHAR2 (4000) := NULL;
        ln_rec_fail             NUMBER := 0;
        ln_rec_success          NUMBER;
        ln_rec_total            NUMBER;
        ln_ele_rec_total        NUMBER;
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_message              VARCHAR2 (4000);
        lv_sender               VARCHAR2 (100);
        lv_recipients           VARCHAR2 (4000);
        lv_ccrecipients         VARCHAR2 (4000);
        l_cnt                   NUMBER := 0;
        ln_req_id               NUMBER;
        lv_phase                VARCHAR2 (100);
        lv_status               VARCHAR2 (30);
        lv_dev_phase            VARCHAR2 (100);
        lv_dev_status           VARCHAR2 (100);
        lb_wait_req             BOOLEAN;
    -- lv_message              VARCHAR2 (1000);

    BEGIN
        lv_exc_file_name   := NULL;
        lv_file_name       := NULL;

        -- Derive the directory Path

        BEGIN
            lv_directory_path   := NULL;
            lv_directory        := 'XXD_CST_DUTY_CORR_INB_DIR';

            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_CST_DUTY_CORR_INB_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
                write_log_prc (
                    ' Exception Occurred while retriving the Inbound Directory');
        END;

        BEGIN
            lv_arc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_arc_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_CST_DUTY_CORR_ARC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_arc_directory_path   := NULL;
                write_log_prc (
                    ' Exception Occurred while retriving the Archive Directory');
        END;

        BEGIN
            lv_exc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_exc_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_CST_DUTY_ELE_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_exc_directory_path   := NULL;
                write_log_prc (
                    ' Exception Occurred while retriving the Exception Directory');
        END;

        -- Now Get the file names

        get_file_names (lv_directory_path);

        FOR data IN get_file_cur
        LOOP
            ln_file_exists   := 0;
            lv_file_name     := NULL;
            lv_file_name     := data.filename;

            write_log_prc (' File is available - ' || lv_file_name);

            -- Check the file name exists in the table if exists then SKIP

            BEGIN
                SELECT COUNT (1)
                  INTO ln_file_exists
                  FROM xxdo.xxd_cst_duty_correct_tr_t
                 WHERE 1 = 1 AND UPPER (file_name) = UPPER (lv_file_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_file_exists   := 0;
            END;

            IF ln_file_exists = 0
            THEN
                load_file_into_tbl_prc (pv_table => 'XXD_CST_DUTY_CORRECT_TR_T', pv_dir => 'XXD_CST_DUTY_CORR_INB_DIR', pv_filename => lv_file_name, pv_ignore_headerlines => 1, pv_delimiter => '|', pv_optional_enclosed => '"'
                                        , pv_num_of_columns => 28); -- Change the number of columns

                BEGIN
                    UPDATE xxdo.xxd_cst_duty_correct_tr_t
                       SET file_name = lv_file_name, request_id = gn_request_id, creation_date = SYSDATE,
                           last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id,
                           status = 'N'
                     WHERE 1 = 1 AND file_name IS NULL AND request_id IS NULL;

                    write_log_prc (
                           SQL%ROWCOUNT
                        || ' Records updated with Filename, Request ID and WHO Columns');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                               'Error Occured while Updating the Filename, Request ID and WHO Columns-'
                            || SQLERRM);
                END;

                COMMIT;


                validate_prc (lv_file_name);

                BEGIN
                    write_log_prc (
                           'Move files Process Begins...'
                        || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                    ln_req_id   :=
                        fnd_request.submit_request (
                            application   => 'XXDO',
                            program       => 'XXDO_CP_MV_RM_FILE',
                            argument1     => 'MOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                            argument2     => 2,
                            argument3     =>
                                lv_directory_path || '/' || lv_file_name, -- Source File Directory
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
                        write_log_prc (
                            ' Unable to submit move files concurrent program ');
                    ELSE
                        write_log_prc (
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
                            write_log_prc (
                                   'Move Files concurrent request with the request id '
                                || ln_req_id
                                || ' completed with NORMAL status.');
                        ELSE
                            retcode   := gn_warning;
                            write_log_prc (
                                   'Move Files concurrent request with the request id '
                                || ln_req_id
                                || ' did not complete with NORMAL status.');
                        END IF; -- End of if to check if the status is normal and phase is complete
                    END IF;          -- End of if to check if request ID is 0.

                    COMMIT;
                    write_log_prc (
                           'Move Files Ends...'
                        || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        retcode   := gn_error;
                        write_log_prc ('Error in Move Files -' || SQLERRM);
                END;
            --    CopyFile_prc (lv_file_name,SYSDATE||'_'||lv_file_name,'XXD_CST_DUTY_CORR_INB_DIR','XXD_CST_DUTY_CORR_ARC_DIR');
            --
            --    Utl_File.Fremove('XXD_CST_DUTY_CORR_INB_DIR', lv_file_name);
            --
            --    COMMIT;

            ELSIF ln_file_exists > 0
            THEN
                --l_cnt := l_cnt + 1;

                write_log_prc (
                    '**************************************************************************************************');
                write_log_prc (
                       'Data with this File name - '
                    || lv_file_name
                    || ' - is already loaded. Please change the file data.  ');
                write_log_prc (
                    '**************************************************************************************************');

                CopyFile_prc (lv_file_name, SYSDATE || '_' || lv_file_name, 'XXD_CST_DUTY_ELE_INB_DIR'
                              , 'XXD_CST_DUTY_ELE_ARC_DIR');
                UTL_FILE.Fremove ('XXD_CST_DUTY_ELE_INB_DIR', lv_file_name);

                retcode   := gn_warning;
            --lv_exc_file_name := gn_request_id||'_Exception_RPT_'||TO_CHAR (SYSDATE, 'RRRR-MON-DD HH24:MI:SS')||'.txt';
            --lv_line := lv_line||' Data with this File name - '||lv_file_name|| ' - is already loaded. Please change the file data. Inbound File Attached. '||CHR(10);
            --lv_all_file_names := lv_exc_directory_path||lv_mail_delimiter||lv_exc_file_name||';'||lv_all_file_names;

            --CopyFile_prc (lv_file_name,lv_exc_file_name,'XXD_CST_DUTY_ELE_INB_DIR','XXD_CST_DUTY_ELE_EXC_DIR');
            --CopyFile_prc (lv_file_name,SYSDATE||'_'||lv_file_name,'XXD_CST_DUTY_ELE_INB_DIR','XXD_CST_DUTY_ELE_ARC_DIR');
            --Utl_File.Fremove('XXD_CST_DUTY_ELE_INB_DIR', lv_file_name);

            --lv_message := 'Hello Team,'||CHR(10)||CHR(10)||'Please Find the Attached Deckers TRO Inbound Duty Elements Exception Report. '||CHR(10)||CHR(10)||lv_line||CHR(10)||CHR(10)||'Regards'||CHR(10)||'SYSADMIN.';
            --write_log_prc (lv_all_file_names);

            END IF;

            EXIT WHEN get_file_cur%NOTFOUND;
        END LOOP;

        FOR file_names IN get_file_names_cur
        LOOP
            insert_into_staging_prc (file_names.file_name);

            --    validate_prc (file_names.file_name);

            insert_into_custom_table_prc (file_names.file_name);

            validate_interface_prc (file_names.file_name);

            load_interface_prc (file_names.file_name);

            update_interface_status_prc (file_names.file_name);
        END LOOP;

        generate_report_prc;
    END main_prc;
END XXD_CST_DUTY_CORRECT_TR_PKG;
/
