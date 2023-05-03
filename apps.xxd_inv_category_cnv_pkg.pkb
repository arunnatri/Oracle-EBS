--
-- XXD_INV_CATEGORY_CNV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_CATEGORY_CNV_PKG"
AS
    -- +==============================================================================+
    -- +                        TOPPS Oracle 12i                                      +
    -- +==============================================================================+
    -- |                                                                              |
    -- |CVS ID:   1.1                                                                 |
    -- |Source File Name: XXD_INV_CATEGORY_CNV_PKG.sql                                 |
    -- |                                                                              |
    -- |Object Name :   XXD_INV_CATEGORY_CNV_PKG                                      |
    -- |Description   : The package  is defined to convert the                        |
    -- |                Topps INV Item Categories Creation and Assignment             |
    -- |                Conversion to R12                                             |
    -- |                                                                              |
    -- |Usage:                                                                        |
    -- |                                                                              |
    -- |Parameters   :  p_candidate_set   - type of records to pick                   |
    -- |                p_validate_only  -- mode of operation                         |
    -- |                p_debug          -- Debug Flag                                |
    -- |                                                                              |
    -- |                                                                              |
    -- |                                                                              |
    -- |Change Record:                                                                |
    -- |===============                                                               |
    -- |Version   Date             Author             Remarks                              |
    -- |=======   ==========  ===================   ============================      |
    --     1.0       12-Dec-2014  BT Technology team                       Initial draft version
    -- +==============================================================================+
    --gn_request_id NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    --gn_user_id NUMBER := FND_GLOBAL.USER_ID;

    PROCEDURE print_msg_prc (p_debug VARCHAR2, p_message IN VARCHAR2)
    AS
    BEGIN
        IF p_debug = 'Y'
        THEN
            FND_FILE.put_line (FND_FILE.LOG, p_message);
            DBMS_OUTPUT.put_line (p_message);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            FND_FILE.put_line (FND_FILE.LOG, SQLERRM);
        WHEN OTHERS
        THEN
            FND_FILE.put_line (FND_FILE.LOG, SQLERRM);
    END print_msg_prc;


    FUNCTION category_exists (p_debug               IN     VARCHAR2,
                              p_category            IN     VARCHAR2,
                              p_category_set_name   IN     VARCHAR2,
                              x_cate_set_id            OUT NUMBER,
                              x_structure_id           OUT NUMBER)
        RETURN NUMBER
    IS
        CURSOR get_str_id_c IS
            SELECT structure_id, category_set_id
              FROM mtl_category_sets_v
             WHERE category_set_name = p_category_set_name;

        ln_structure_id      NUMBER;


        CURSOR get_category_id (cp_structure_id        NUMBER,
                                cp_concatenated_segs   VARCHAR2)
        IS
            SELECT category_id
              FROM mtl_categories_b_kfv
             WHERE     structure_id = cp_structure_id
                   AND concatenated_segments = cp_concatenated_segs;

        ln_category_id       NUMBER;
        ln_category_set_id   NUMBER;
    BEGIN
        print_msg_prc (p_debug, 'p_category in ' || p_category);
        print_msg_prc (p_debug,
                       'p_category_set_name in ' || p_category_set_name);


        OPEN get_str_id_c;

        ln_structure_id   := NULL;

        FETCH get_str_id_c INTO ln_structure_id, ln_category_set_id;

        CLOSE get_str_id_c;


        OPEN get_category_id (ln_structure_id, p_category);

        ln_category_id    := NULL;

        FETCH get_category_id INTO ln_category_id;

        CLOSE get_category_id;

        --fnd_file.put_line (fnd_file.LOG, 'ln_category_id ' || ln_category_id);

        x_structure_id    := ln_structure_id;
        x_cate_set_id     := ln_category_set_id;

        RETURN ln_category_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 1000));
            RETURN NULL;
    END;


    FUNCTION validate_valueset_value (p_debug IN VARCHAR2, p_category_set_name IN VARCHAR2, p_application_column_name IN VARCHAR2
                                      , p_flex_value IN VARCHAR2 --p_flex_desc                 IN VARCHAR2,
                                                                )
        RETURN BOOLEAN
    AS
        x_rowid                VARCHAR2 (1000);
        ln_flex_value_id       NUMBER := 0;
        ln_flex_value_set_id   NUMBER := 0;
        --ln_flex_value_id            NUMBER   := 0;
        lc_validation_type     VARCHAR2 (10);

        TYPE get_value_set IS REF CURSOR;

        get_value_tab_set      get_value_set;

        lc_query               VARCHAR2 (1000);

        CURSOR get_tab_val_c (p_value_set_id NUMBER)
        IS
            SELECT APPLICATION_TABLE_NAME, VALUE_COLUMN_NAME, ENABLED_COLUMN_NAME,
                   NVL (TO_CHAR (ADDITIONAL_WHERE_CLAUSE), ' WHERE  1=1 ') ADDITIONAL_WHERE_CLAUSE
              FROM fnd_flex_validation_tables
             WHERE flex_value_set_id = p_value_set_id;

        lcu_get_tab_val_c      get_tab_val_c%ROWTYPE;

        lc_code                VARCHAR2 (200);
        lc_flex_value          VARCHAR2 (100);
    BEGIN --print_msg_prc( p_debug   => gc_debug_flag,p_message => 'validate_valueset_value for '|| p_application_column_name || ' and value '||  p_flex_value);
        print_msg_prc (p_debug, ' Validating for values ' || p_flex_value);



        BEGIN
            SELECT ffs.flex_value_set_id, mcs.category_set_id
              INTO ln_flex_value_set_id, gn_category_set_id
              FROM fnd_id_flex_segments ffs, mtl_category_sets_v mcs --, fnd_flex_values ffv
             WHERE     application_id = 401
                   AND id_flex_code = 'MCAT'
                   AND id_flex_num = mcs.structure_id         --l_structure_id
                   AND ffs.enabled_flag = 'Y'
                   -- AND ffv.enabled_flag        = 'Y'
                   AND mcs.category_set_name = p_category_set_name --'TOPPS ITEM CATEGORY SET'
                   --    AND ffs.flex_value_set_id   = ffv.flex_value_set_id
                   AND application_column_name = p_application_column_name;

            --    AND flex_value              = p_flex_value  ;

            SELECT validation_type
              INTO lc_validation_type
              FROM fnd_flex_value_sets
             WHERE flex_value_set_id = ln_flex_value_set_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_flex_value_set_id   := 0;
            WHEN OTHERS
            THEN
                ln_flex_value_set_id   := 0;
        END;



        BEGIN
            SELECT FLEX_VALUE_ID
              INTO ln_flex_value_id
              FROM fnd_flex_values ffs
             WHERE     ffs.flex_value_set_id = ln_flex_value_set_id
                   AND ENABLED_FLAG = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (Start_Date_Active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (End_Date_Active,
                                                        SYSDATE + 1)) --Added on 22-DEC-2015
                   AND flex_value = p_flex_value;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_flex_value_id   := 0;
            WHEN OTHERS
            THEN
                ln_flex_value_id   := 0;
        END;

        print_msg_prc (p_debug, 'Validation ' || lc_validation_type);


        IF lc_validation_type = 'F' AND ln_flex_value_set_id IS NOT NULL
        THEN
            OPEN get_tab_val_c (ln_flex_value_set_id);

            lcu_get_tab_val_c   := NULL;

            FETCH get_tab_val_c INTO lcu_get_tab_val_c;

            CLOSE get_tab_val_c;

            lc_code             := NULL;

            lc_flex_value       := REPLACE (p_flex_value, '''', '''''');

            print_msg_prc (p_debug, 'p_flex ' || lc_flex_value);


            lc_query            :=
                   'SELECT '
                || lcu_get_tab_val_c.VALUE_COLUMN_NAME
                || '
              FROM
             '
                || lcu_get_tab_val_c.APPLICATION_TABLE_NAME
                || ' '
                || lcu_get_tab_val_c.ADDITIONAL_WHERE_CLAUSE
                || ' AND '
                || lcu_get_tab_val_c.VALUE_COLUMN_NAME
                || '
             = '''
                || lc_flex_value
                || '''';


            print_msg_prc (p_debug, 'Query ' || lc_query);



            OPEN get_value_tab_set FOR lc_query;

            FETCH get_value_tab_set INTO lc_code;

            CLOSE get_value_tab_set;

            IF lc_code IS NOT NULL
            THEN
                ln_flex_value_id   := 100;
            END IF;
        END IF;

        print_msg_prc (p_debug, 'ln_flex_value_id ' || ln_flex_value_id);



        IF ln_flex_value_id = 0
        THEN
            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error ' || SQLERRM);
            RETURN FALSE;
    END;



    PROCEDURE inv_category_validation (x_error OUT VARCHAR2, x_ret OUT VARCHAR2, p_batch_no IN NUMBER
                                       , p_debug IN VARCHAR2)
    AS
        CURSOR get_category_c IS
            SELECT RECORD_ID, TRIM (BRAND) BRAND, TRIM (CLASS) CLASS,
                   TRIM (COLOR_CODE) COLOR_CODE, TRIM (DEPARTMENT) DEPARTMENT, TRIM (DIVISION) DIVISION,
                   TRIM (MASTER_STYLE) MASTER_STYLE, TRIM (STYLE) STYLE, TRIM (STYLE_CODE) STYLE_CODE,
                   TRIM (STYLE_OPTION) STYLE_OPTION, TRIM (SUB_CLASS) SUB_CLASS
              --NTILE (p_no_of_process) OVER (ORDER BY RECORD_ID) BATCH_NUM
              FROM XXD_CONV.XXD_PLM_ATTR_STG_T
             WHERE     (OM_RECORD_STATUS IN ('N', 'E') OR INV_RECORD_STATUS IN ('N', 'E') OR PO_RECORD_STATUS IN ('N', 'E'))
                   AND batch_number = p_batch_no;     --AND record_id = 344885

        --AND style_code in (select distinct segment1 from   XXD_ITEM_CONV_STG_T )
        /*AND record_id in (79365,
    248562,
    244224)*/
        --AND RECORD_ID = 260741
        --             AND style_code in ( '5835','1003390','1001730') and color_code in ( 'NAVY','CHRC','STT')
        --AND style_code = '1006210'
        --AND color_code = 'HBCK'
        --AND style_code IN (select style_code from    STYLE_TAB)



        TYPE get_category_tab IS TABLE OF get_category_c%ROWTYPE;

        xxd_category_tab      get_category_tab;
        lc_category_exists    VARCHAR2 (1);
        lc_error_message      VARCHAR2 (4000);
        lc_error_flag         VARCHAR2 (1);
        lc_inv_category       VARCHAR2 (1000);
        lc_po_category        VARCHAR2 (1000);
        lc_om_category        VARCHAR2 (1000);
        ln_inv_structure_id   NUMBER;
        ln_po_structure_id    NUMBER;
        ln_om_structure_id    NUMBER;
        lc_inv_status         VARCHAR2 (1);
        lc_po_status          VARCHAR2 (1);
        lc_om_status          VARCHAR2 (1);
        ln_inv_cat_set_id     NUMBER;
        ln_om_cat_set_id      NUMBER;
        ln_po_cat_set_id      NUMBER;
        ln_inv_category_id    NUMBER;
        ln_po_category_id     NUMBER;
        ln_om_category_id     NUMBER;
        ln_error_cnt          NUMBER;
        ln_val_cnt            NUMBER;
    BEGIN
        --UPDATE XXD_CONV.XXD_PLM_ATTR_STG_T1 SET INV_RECORD_STATUS = 'N',PO_RECORD_STATUS='N',OM_RECORD_STATUS = 'N';

        UPDATE XXD_CONV.XXD_PLM_ATTR_STG_T
           SET ERROR_MESSAGE   = NULL
         WHERE     (OM_RECORD_STATUS IN ('N', 'E') OR INV_RECORD_STATUS IN ('N', 'E') OR PO_RECORD_STATUS IN ('N', 'E'))
               AND batch_number = p_batch_no;


        UPDATE XXD_CONV.XXD_PLM_ATTR_STG_T
           SET BRAND = SUBSTR (BRAND, 1, 40), DIVISION = SUBSTR (DIVISION, 1, 40), DEPARTMENT = SUBSTR (DEPARTMENT, 1, 40),
               CLASS = SUBSTR (CLASS, 1, 40), SUB_CLASS = SUBSTR (SUB_CLASS, 1, 40), MASTER_STYLE = SUBSTR (MASTER_STYLE, 1, 40),
               STYLE = SUBSTR (STYLE, 1, 40), STYLE_OPTION = SUBSTR (STYLE_OPTION, 1, 40)
         WHERE batch_number = p_batch_no;

        /*    WHERE (   OM_RECORD_STATUS IN ('N', 'E')
                       OR INV_RECORD_STATUS IN ('N', 'E')
                       OR PO_RECORD_STATUS IN ('N', 'E')) ; */

        COMMIT;

        OPEN get_category_c;



        LOOP
            FETCH get_category_c
                BULK COLLECT INTO xxd_category_tab
                LIMIT 1000;

            IF xxd_category_tab.COUNT > 0
            THEN
                FOR i IN 1 .. xxd_category_tab.COUNT
                LOOP
                    BEGIN
                        --Validation
                        --lc_error_flag := 'N';
                        lc_category_exists    := NULL;
                        lc_error_message      := NULL;
                        lc_inv_category       := NULL;
                        lc_po_category        := NULL;
                        lc_om_category        := NULL;
                        ln_inv_structure_id   := NULL;
                        ln_po_structure_id    := NULL;
                        ln_om_structure_id    := NULL;
                        ln_inv_cat_set_id     := NULL;
                        ln_om_cat_set_id      := NULL;
                        ln_po_cat_set_id      := NULL;
                        ln_inv_category_id    := NULL;
                        ln_po_category_id     := NULL;
                        ln_om_category_id     := NULL;
                        ln_error_cnt          := NULL;
                        ln_val_cnt            := NULL;
                        lc_inv_status         := 'V';
                        lc_po_status          := 'V';
                        lc_om_status          := 'V';

                        lc_inv_category       :=
                               TRIM (xxd_category_tab (i).BRAND)
                            || '.'
                            || TRIM (xxd_category_tab (i).DIVISION)
                            || '.'
                            || TRIM (xxd_category_tab (i).DEPARTMENT)
                            || '.'
                            || TRIM (xxd_category_tab (i).CLASS)
                            || '.'
                            || TRIM (xxd_category_tab (i).SUB_CLASS)
                            || '.'
                            || TRIM (xxd_category_tab (i).MASTER_STYLE)
                            || '.'
                            || TRIM (xxd_category_tab (i).STYLE)
                            || '.'
                            || TRIM (xxd_category_tab (i).STYLE_OPTION);

                        print_msg_prc (
                            p_debug,
                            'Inventory Category ' || lc_inv_category);

                        ln_inv_category_id    := NULL;

                        --Inventory category set Validation

                        ln_inv_category_id    :=
                            category_exists (p_debug,
                                             lc_inv_category,
                                             'Inventory',
                                             ln_inv_cat_set_id,
                                             ln_inv_structure_id);

                        print_msg_prc (
                            p_debug,
                            'inv_category_id ' || ln_inv_category_id);



                        IF ln_inv_category_id IS NULL
                        THEN
                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'Inventory',
                                       'SEGMENT1',
                                       xxd_category_tab (i).BRAND)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_inv_status   := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Brand Value '
                                    || xxd_category_tab (i).BRAND
                                    || ' is not defined for the category set Inventory';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'Brand Value '
                                        || xxd_category_tab (i).BRAND
                                        || ' is not defined for the category set Inventory',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_request_id, -- concurrent request ID
                                    p_more_info1   => lc_inv_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                           'Structure id '
                                        || ln_inv_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);
                            END IF;

                            print_msg_prc (
                                p_debug,
                                'lc_error_flag for BRAND ' || lc_error_flag);



                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'Inventory',
                                       'SEGMENT2',
                                       xxd_category_tab (i).DIVISION)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_inv_status   := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Division Value '
                                    || xxd_category_tab (i).DIVISION
                                    || ' is not defined for the category set Inventory ';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'Division Value '
                                        || xxd_category_tab (i).DIVISION
                                        || ' is not defined for the category set Inventory',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_request_id, -- concurrent request ID
                                    p_more_info1   => lc_inv_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                           'Structure id '
                                        || ln_inv_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);
                            END IF;


                            print_msg_prc (
                                p_debug,
                                   'lc_error_flag for DIVISION '
                                || lc_error_flag);


                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'Inventory',
                                       'SEGMENT3',
                                       xxd_category_tab (i).DEPARTMENT)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_inv_status   := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Department Value '
                                    || xxd_category_tab (i).DEPARTMENT
                                    || ' is not defined for the category set Inventory ';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'Department Value '
                                        || xxd_category_tab (i).DEPARTMENT
                                        || ' is not defined for the category set Inventory',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_request_id, -- concurrent request ID
                                    p_more_info1   => lc_inv_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                           'Structure id '
                                        || ln_inv_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);
                            END IF;

                            print_msg_prc (
                                p_debug,
                                   'lc_error_flag for DEPARTMENT '
                                || lc_error_flag);


                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'Inventory',
                                       'SEGMENT4',
                                       xxd_category_tab (i).CLASS)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_inv_status   := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Class Value '
                                    || xxd_category_tab (i).CLASS
                                    || ' is not defined for the category set Inventory';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'Class Value '
                                        || xxd_category_tab (i).CLASS
                                        || ' is not defined for the category set Inventory ',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_request_id, -- concurrent request ID
                                    p_more_info1   => lc_inv_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                           'Structure id '
                                        || ln_inv_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);
                            END IF;

                            print_msg_prc (
                                p_debug,
                                'lc_error_flag for CLASS ' || lc_error_flag);



                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'Inventory',
                                       'SEGMENT5',
                                       xxd_category_tab (i).SUB_CLASS)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_inv_status   := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Sub class '
                                    || xxd_category_tab (i).SUB_CLASS
                                    || ' is not defined for the category set Inventory';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'Sub class Value '
                                        || xxd_category_tab (i).SUB_CLASS
                                        || ' is not defined for the category set Inventory',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_request_id, -- concurrent request ID
                                    p_more_info1   => lc_inv_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                           'Structure id '
                                        || ln_inv_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);
                            END IF;

                            print_msg_prc (
                                p_debug,
                                   'lc_error_flag for SUB_CLASS '
                                || lc_error_flag);



                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'Inventory',
                                       'SEGMENT6',
                                       xxd_category_tab (i).MASTER_STYLE)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_inv_status   := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Master style '
                                    || xxd_category_tab (i).MASTER_STYLE
                                    || ' is not defined for the category set Inventory';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'Master style '
                                        || xxd_category_tab (i).MASTER_STYLE
                                        || ' is not defined for the category set Inventory ',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_request_id, -- concurrent request ID
                                    p_more_info1   => lc_inv_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                           'Structure id '
                                        || ln_inv_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);
                            END IF;

                            print_msg_prc (
                                p_debug,
                                   'lc_error_flag for MASTER_STYLE '
                                || lc_error_flag);



                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'Inventory',
                                       'SEGMENT7',
                                       xxd_category_tab (i).STYLE)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_inv_status   := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Style Value '
                                    || xxd_category_tab (i).STYLE
                                    || ' is not defined for the category set Inventory';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'Style Value '
                                        || xxd_category_tab (i).STYLE
                                        || ' is not defined for the category set Inventory',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_request_id, -- concurrent request ID
                                    p_more_info1   => lc_inv_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                           'Structure id '
                                        || ln_inv_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);
                            END IF;

                            print_msg_prc (
                                p_debug,
                                'lc_error_flag for STYLE ' || lc_error_flag);



                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'Inventory',
                                       'SEGMENT8',
                                       xxd_category_tab (i).STYLE_OPTION)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_inv_status   := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Style option Value '
                                    || xxd_category_tab (i).STYLE_OPTION
                                    || ' is not defined for the category set Inventory';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'Style option '
                                        || xxd_category_tab (i).STYLE_OPTION
                                        || ' is not defined for the category set Inventory',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_request_id, -- concurrent request ID
                                    p_more_info1   => lc_inv_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                           'Structure id '
                                        || ln_inv_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);
                            END IF;

                            print_msg_prc (
                                p_debug,
                                   'lc_error_flag for STYLE_OPTION '
                                || lc_error_flag);
                        ELSE
                            lc_inv_status   := 'L';
                            --lc_inv_status := 'V';

                            print_msg_prc (
                                p_debug,
                                   'Category '
                                || lc_inv_category
                                || ' already exists in the system');
                        END IF;



                        --for PO Item Category

                        lc_po_category        :=
                               'Trade'
                            || '.'
                            || xxd_category_tab (i).CLASS
                            || '.'
                            || xxd_category_tab (i).STYLE;

                        print_msg_prc (p_debug,
                                       'PO category ' || lc_po_category);
                        print_msg_prc (
                            p_debug,
                            'ln_po_cat_set_id ' || ln_po_cat_set_id);
                        print_msg_prc (
                            p_debug,
                            'ln_po_structure_id ' || ln_po_structure_id);



                        ln_po_category_id     := NULL;

                        ln_po_category_id     :=
                            category_exists (p_debug,
                                             lc_po_category,
                                             'PO Item Category',
                                             ln_po_cat_set_id,
                                             ln_po_structure_id);

                        print_msg_prc (
                            p_debug,
                            'po_category_id ' || ln_po_category_id);



                        IF ln_po_category_id IS NULL
                        THEN
                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'PO Item Category',
                                       'SEGMENT2',
                                       xxd_category_tab (i).CLASS)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_po_status    := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Class Value '
                                    || xxd_category_tab (i).CLASS
                                    || ' is not defined for the category set PO Item Category';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'CLASS '
                                        || xxd_category_tab (i).STYLE_OPTION
                                        || ' is not defined for the category set  ',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_parent_request_id, -- concurrent request ID
                                    p_more_info1   => lc_po_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                        'Structure id ' || ln_po_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);
                            END IF;


                            print_msg_prc (
                                p_debug,
                                'lc_error_flag for CLASS ' || lc_error_flag);


                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'PO Item Category',
                                       'SEGMENT3',
                                       xxd_category_tab (i).STYLE)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_po_status    := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Style  Value '
                                    || xxd_category_tab (i).STYLE
                                    || ' is not defined for the category set PO Item Category ';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'Brand Value '
                                        || xxd_category_tab (i).STYLE_OPTION
                                        || ' is not defined for the category set PO Item Category ',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_parent_request_id, -- concurrent request ID
                                    p_more_info1   => lc_po_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                        'Structure id ' || ln_po_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);

                                print_msg_prc (
                                    p_debug,
                                       'lc_error_flag for STYLE'
                                    || lc_error_flag);
                            END IF;
                        ELSE
                            lc_po_status   := 'L';

                            print_msg_prc (
                                p_debug,
                                   'Category '
                                || lc_po_category
                                || ' already exists in the system');
                        END IF;

                        --For OM Item Category


                        print_msg_prc (
                            p_debug,
                               'OM Sales Category '
                            || xxd_category_tab (i).STYLE);



                        lc_om_category        := xxd_category_tab (i).STYLE;

                        ln_om_category_id     := NULL;

                        ln_om_category_id     :=
                            category_exists (p_debug,
                                             lc_om_category,
                                             'OM Sales Category',
                                             ln_om_cat_set_id,
                                             ln_om_structure_id);

                        --            fnd_file.put_line(fnd_file.log,'ln_om_category_id '||ln_om_category_id);

                        IF ln_om_category_id IS NULL
                        THEN
                            IF NOT validate_valueset_value (
                                       p_debug,
                                       'OM Sales Category',
                                       'SEGMENT1',
                                       xxd_category_tab (i).STYLE)
                            THEN
                                lc_error_flag   := 'Y';
                                lc_om_status    := 'E';
                                lc_error_message   :=
                                       lc_error_message
                                    || ','
                                    || ' Style  Value '
                                    || xxd_category_tab (i).STYLE
                                    || ' is not defined for the category set OM Sales Category ';

                                xxd_common_utils.record_error (
                                    p_module       => 'INV', --Oracle module short name
                                    p_org_id       => gn_org_id,
                                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                    p_error_msg    =>
                                           'Brand Value '
                                        || xxd_category_tab (i).STYLE_OPTION
                                        || ' is not defined for the category set Inventory ',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                    p_created_by   => gn_user_id,    --USER_ID
                                    p_request_id   => gn_parent_request_id, -- concurrent request ID
                                    p_more_info1   => lc_om_category, --additional information for troubleshooting
                                    p_more_info2   =>
                                        'Structure id ' || ln_om_structure_id,
                                    p_more_info3   =>
                                           'record id  '
                                        || xxd_category_tab (i).record_id);

                                print_msg_prc (
                                    p_debug,
                                       'lc_error_flag for STYLE '
                                    || lc_error_flag);
                            END IF;
                        ELSE
                            print_msg_prc (
                                p_debug,
                                   'Category '
                                || lc_po_category
                                || ' already exists in the system');

                            lc_om_status   := 'L';
                        END IF;



                        UPDATE XXD_CONV.XXD_PLM_ATTR_STG_T
                           SET ERROR_MESSAGE = SUBSTR (ERROR_MESSAGE || ',' || lc_error_message, 1, 1000), --BATCH_NUMBER = xxd_category_tab (i).BATCH_NUM,
                                                                                                           om_RECORD_STATUS = lc_om_status, po_RECORD_STATUS = lc_po_status,
                               inv_RECORD_STATUS = lc_inv_status, OM_STRUCTURE_ID = ln_om_structure_id, PO_STRUCTURE_ID = ln_po_structure_id,
                               INV_STRUCTURE_ID = ln_inv_structure_id, INV_CATEGORY_SET_ID = ln_inv_cat_set_id, PO_CATEGORY_SET_ID = ln_po_cat_set_id,
                               OM_CATEGORY_SET_ID = ln_om_cat_set_id, INV_CATEGORY_ID = ln_inv_category_id, PO_CATEGORY_ID = ln_po_category_id,
                               OM_CATEGORY_ID = ln_om_category_id, --BATCH_NUMBER = xxd_category_tab (i).BATCH_NUM,
                                                                   creation_date = SYSDATE, created_by = fnd_global.user_id,
                               last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, last_update_login = fnd_global.login_id,
                               request_id = gn_request_id
                         WHERE RECORD_ID = xxd_category_tab (i).record_id;


                        COMMIT;
                    --END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error ' || SUBSTR (SQLERRM, 1, 500));

                            lc_error_message   :=
                                'Error ' || SUBSTR (SQLERRM, 1, 500);


                            UPDATE XXD_CONV.XXD_PLM_ATTR_STG_T
                               SET ERROR_MESSAGE = ERROR_MESSAGE || ',' || lc_error_message, --BATCH_NUMBER = xxd_category_tab (i).BATCH_NUM,
                                                                                             om_RECORD_STATUS = 'E', po_RECORD_STATUS = 'E',
                                   inv_RECORD_STATUS = 'E', creation_date = SYSDATE, created_by = fnd_global.user_id,
                                   last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, last_update_login = fnd_global.login_id,
                                   request_id = gn_request_id
                             WHERE RECORD_ID = xxd_category_tab (i).record_id;

                            COMMIT;
                    END;
                END LOOP;
            ELSE
                EXIT;
            END IF;
        END LOOP;



        SELECT COUNT (*)
          INTO ln_error_cnt
          FROM XXD_CONV.XXD_PLM_ATTR_STG_T
         WHERE (om_RECORD_STATUS = 'E' OR inv_RECORD_STATUS = 'E' OR om_RECORD_STATUS = 'E');

        SELECT COUNT (*)
          INTO ln_val_cnt
          FROM XXD_CONV.XXD_PLM_ATTR_STG_T
         WHERE (om_RECORD_STATUS <> 'E' AND inv_RECORD_STATUS <> 'E' AND om_RECORD_STATUS <> 'E');


        -- Writing Counts to output file.

        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Deckers Item Categories Creation and Assignment Program ');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '-------------------------------------------------');

        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no records validated in XXD_PLM_ATTR_STG_T Table '
            || ln_val_cnt);
        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no records Errored in XXD_PLM_ATTR_STG_T Table '
            || ln_error_cnt);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error   := SUBSTR (SQLERRM, 1, 250);
            x_ret     := 2;
            fnd_file.put_line (fnd_file.LOG, 'Error ' || x_error);
    --print_msg_prc (p_debug     => gc_debug_flag, p_message   => 'errbuf => ' || errbuf);
    END;


    PROCEDURE create_Category_Assignment (
        p_debug               IN     VARCHAR2,
        p_record_id           IN     NUMBER,
        p_category_id         IN     NUMBER,
        --p_old_category_id     IN     NUMBER,
        p_category_set_id     IN     NUMBER,
        p_inventory_item_id   IN     NUMBER,
        p_organization_id     IN     NUMBER,
        x_return_status          OUT VARCHAR2,
        x_error_messsage         OUT VARCHAR2)
    IS
        l_out_category_id   NUMBER;
        l_return_status     VARCHAR2 (1);
        l_error_code        VARCHAR2 (1);
        l_msg_count         NUMBER;
        l_msg_data          VARCHAR2 (100);
        l_messages          VARCHAR2 (4000);
    BEGIN
        print_msg_prc (
            p_debug,
            'Calling inv_item_category_pub.Create_Category_Assignment ');


        print_msg_prc (p_debug, 'fnd_api.g_false ' || fnd_api.g_false);
        print_msg_prc (p_debug, 'l_return_status ' || l_return_status);
        print_msg_prc (p_debug, 'l_error_code ' || l_error_code);
        print_msg_prc (p_debug, 'l_msg_count ' || l_msg_count);
        print_msg_prc (p_debug, 'p_category_id ' || p_category_id);
        print_msg_prc (p_debug, 'p_category_set_id ' || p_category_set_id);
        print_msg_prc (p_debug,
                       'p_inventory_item_id ' || p_inventory_item_id);
        print_msg_prc (p_debug, 'p_organization_id ' || p_organization_id);


        inv_item_category_pub.Create_Category_Assignment (
            p_api_version         => 1,
            p_init_msg_list       => fnd_api.g_false,
            p_commit              => fnd_api.g_false,
            x_return_status       => l_return_status,
            x_errorcode           => l_error_code,
            x_msg_count           => l_msg_count,
            x_msg_data            => l_msg_data,
            p_category_id         => p_category_id,
            -- p_old_category_id     => p_old_category_id,
            p_category_set_id     => p_category_set_id,
            p_inventory_item_id   => p_inventory_item_id,
            p_organization_id     => p_organization_id);



        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            x_return_status    := 'E';
            FND_MSG_PUB.COUNT_AND_GET (p_encoded   => 'F',
                                       p_count     => l_msg_count,
                                       p_data      => l_msg_data);

            --fnd_file.put_line (fnd_file.LOG, 'Count ' || l_msg_count);
            --fnd_file.put_line (fnd_file.LOG, 'l_msg_data ' || substr(l_msg_data,1,3000));

            FOR K IN 1 .. l_msg_count
            LOOP
                l_messages   :=
                    SUBSTR (
                           l_messages
                        || fnd_msg_pub.get (p_msg_index => k, p_encoded => 'F')
                        || ';',
                        1,
                        4000);
            --fnd_file.put_line (fnd_file.LOG, 'Error ' || l_messages);
            END LOOP;



            FND_MESSAGE.SET_NAME ('FND', 'GENERIC-INTERNAL ERROR');
            FND_MESSAGE.SET_TOKEN ('ROUTINE', 'Category Migration');
            FND_MESSAGE.SET_TOKEN ('REASON', l_messages);

            x_error_messsage   := l_messages;

            COMMIT;

            IF l_messages IS NOT NULL
            THEN
                xxd_common_utils.record_error (
                    p_module       => 'INV',        --Oracle module short name
                    p_org_id       => gn_org_id,
                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                    p_error_msg    => SUBSTR (l_messages, 1, 2000),  --SQLERRM
                    p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                    p_created_by   => gn_user_id,                    --USER_ID
                    p_request_id   => gn_request_id,  -- concurrent request ID
                    p_more_info1   => ' record_id ' || p_record_id, --additional information for troubleshooting
                    p_more_info2   => 'Category set id ' || p_category_set_id, --additional information for troubleshooting
                    p_more_info3   =>
                        'inventory item id ' || p_inventory_item_id, --additional information for troubleshooting
                    p_more_info4   => 'Error ' || SUBSTR (l_messages, 1, 2000)); --additional information for troubleshooting
            END IF;
        ELSE
            x_return_status   := 'S';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'E';
            fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 1000));
    END;

    PROCEDURE create_category (p_debug IN VARCHAR2, p_record_id IN NUMBER, p_category_set_name IN VARCHAR2, p_category_rec IN inv_item_category_pub.category_rec_type, x_category_id OUT NUMBER, x_return_status OUT VARCHAR2
                               , x_error_message OUT VARCHAR2)
    IS
        l_out_category_id   NUMBER;
        l_return_status     VARCHAR2 (1);
        l_error_code        VARCHAR2 (1);
        l_msg_count         NUMBER;
        l_msg_data          VARCHAR2 (1000);
        l_messages          VARCHAR2 (4000);
        lc_category         VARCHAR2 (1000);
    BEGIN
        lc_category   :=
               p_category_rec.segment1
            || '.'
            || p_category_rec.segment2
            || '.'
            || p_category_rec.segment3
            || '.'
            || p_category_rec.segment4
            || '.'
            || p_category_rec.segment5
            || '.'
            || p_category_rec.segment6
            || '.'
            || p_category_rec.segment7
            || '.'
            || p_category_rec.segment8;

        print_msg_prc (p_debug, 'Category  ' || lc_category);

        print_msg_prc (p_debug,
                       'Calling inv_item_category_pub.create_category ');



        inv_item_category_pub.create_category (
            p_api_version     => 1.0,
            p_init_msg_list   => fnd_api.g_false,
            p_commit          => fnd_api.g_false,
            x_return_status   => l_return_status,
            x_errorcode       => l_error_code,
            x_msg_count       => l_msg_count,
            x_msg_data        => l_msg_data,
            p_category_rec    => p_category_rec,
            x_category_id     => l_out_category_id);



        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            x_return_status   := 'E';
            FND_MSG_PUB.COUNT_AND_GET (p_encoded   => 'F',
                                       p_count     => l_msg_count,
                                       p_data      => l_msg_data);



            FOR K IN 1 .. l_msg_count
            LOOP
                l_messages   :=
                    fnd_msg_pub.get (p_msg_index => k, p_encoded => 'F') || ';';
            END LOOP;



            --fnd_file.put_line (fnd_file.LOG, 'Error ' || l_messages);

            FND_MESSAGE.SET_NAME ('FND', 'GENERIC-INTERNAL ERROR');
            FND_MESSAGE.SET_TOKEN ('ROUTINE', 'Category Migration');
            FND_MESSAGE.SET_TOKEN ('REASON', l_messages);

            x_error_message   := l_messages;


            xxd_common_utils.record_error (
                p_module       => 'INV',            --Oracle module short name
                p_org_id       => gn_org_id,
                p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                p_error_msg    => 'Error ' || SUBSTR (l_messages, 1, 2000),
                p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                p_created_by   => gn_user_id,                        --USER_ID
                p_request_id   => gn_request_id,      -- concurrent request ID
                p_more_info1   => 'INVENTORY_ITEM', --additional information for troubleshooting
                p_more_info2   => 'record_id ' || p_record_id,
                p_more_info3   => 'CATEGORY_SET_NAME ' || p_category_set_name --p_more_info4   =>   gn_category_set_name
                                                                             );
        ELSE
            x_return_status   := 'S';
            x_category_id     := l_out_category_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'E';
            fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 1000));
    END;



    PROCEDURE Update_Category_Assignment (p_debug IN VARCHAR2, p_record_id IN NUMBER, p_category_id IN NUMBER, p_old_category_id IN NUMBER, p_category_set_id IN NUMBER, p_inventory_item_id IN NUMBER
                                          , p_organization_id IN NUMBER, x_return_status OUT VARCHAR2, x_error_messsage OUT VARCHAR2)
    IS
        l_out_category_id   NUMBER;
        l_return_status     VARCHAR2 (1);
        l_error_code        VARCHAR2 (1);
        l_msg_count         NUMBER;
        l_msg_data          VARCHAR2 (100);
        l_messages          VARCHAR2 (4000);
    BEGIN
        print_msg_prc (
            p_debug,
            'Calling inv_item_category_pub.Update_Category_Assignment ');

        print_msg_prc (
            p_debug,
            'Calling inv_item_category_pub.Update_Category_Assignment ');


        inv_item_category_pub.Update_Category_Assignment (
            p_api_version         => 1,
            p_init_msg_list       => fnd_api.g_false,
            p_commit              => fnd_api.g_false,
            x_return_status       => l_return_status,
            x_errorcode           => l_error_code,
            x_msg_count           => l_msg_count,
            x_msg_data            => l_msg_data,
            p_category_id         => p_category_id,
            p_old_category_id     => p_old_category_id,
            p_category_set_id     => p_category_set_id,
            p_inventory_item_id   => p_inventory_item_id,
            p_organization_id     => p_organization_id);



        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            x_return_status    := 'E';
            FND_MSG_PUB.COUNT_AND_GET (p_encoded   => 'F',
                                       p_count     => l_msg_count,
                                       p_data      => l_msg_data);

            --fnd_file.put_line (fnd_file.LOG, 'Count ' || l_msg_count);
            --fnd_file.put_line (fnd_file.LOG, 'l_msg_data ' || substr(l_msg_data,1,3000));

            FOR K IN 1 .. l_msg_count
            LOOP
                l_messages   :=
                    SUBSTR (
                           l_messages
                        || fnd_msg_pub.get (p_msg_index => k, p_encoded => 'F')
                        || ';',
                        1,
                        4000);
            --fnd_file.put_line (fnd_file.LOG, 'Error ' || l_messages);
            END LOOP;



            FND_MESSAGE.SET_NAME ('FND', 'GENERIC-INTERNAL ERROR');
            FND_MESSAGE.SET_TOKEN ('ROUTINE', 'Category Migration');
            FND_MESSAGE.SET_TOKEN ('REASON', l_messages);

            x_error_messsage   := l_messages;

            COMMIT;

            IF l_messages IS NOT NULL
            THEN
                xxd_common_utils.record_error (
                    p_module       => 'INV',        --Oracle module short name
                    p_org_id       => gn_org_id,
                    p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                    p_error_msg    => SUBSTR (l_messages, 1, 2000),  --SQLERRM
                    p_error_line   => DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                    p_created_by   => gn_user_id,                    --USER_ID
                    p_request_id   => gn_request_id,  -- concurrent request ID
                    p_more_info1   => ' record_id ' || p_record_id, --additional information for troubleshooting
                    p_more_info2   => 'Category set id ' || p_category_set_id, --additional information for troubleshooting
                    p_more_info3   =>
                        'inventory item id ' || p_inventory_item_id, --additional information for troubleshooting
                    p_more_info4   => 'Error ' || SUBSTR (l_messages, 1, 2000)); --additional information for troubleshooting
            END IF;
        ELSE
            x_return_status   := 'S';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'E';
            fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 1000));
    END;


    PROCEDURE inv_category_create (x_error OUT VARCHAR2, x_ret OUT VARCHAR2, p_batch_no IN NUMBER
                                   , p_debug IN VARCHAR2)
    AS
        CURSOR get_category_c IS
            SELECT RECORD_ID, STYLE_CODE, COLOR_CODE,
                   BRAND, DIVISION, DEPARTMENT,
                   CLASS, SUB_CLASS, MASTER_STYLE,
                   STYLE, STYLE_OPTION, SUB,
                   DETAIL, om_STRUCTURE_ID, po_STRUCTURE_ID,
                   inv_STRUCTURE_ID, om_category_ID, po_category_ID,
                   inv_category_ID, om_category_set_ID, po_category_set_ID,
                   inv_category_set_ID, OM_RECORD_STATUS, PO_RECORD_STATUS,
                   INV_RECORD_STATUS
              FROM XXD_CONV.XXD_PLM_ATTR_STG_T
             WHERE     1 = 1
                   AND (OM_RECORD_STATUS = 'V' OR PO_RECORD_STATUS = 'V' OR INV_RECORD_STATUS = 'V')
                   AND batch_number = p_batch_no
                   AND (om_category_ID IS NULL OR po_category_ID IS NULL OR inv_category_ID IS NULL) /*
                                                                                                                     AND style_code IN (SELECT DISTINCT segment1
                                                                                                                                          FROM XXD_ITEM_CONV_STG_T
                                                                                                                                         WHERE organization_id = 106)--AND style_code = '1006454'
                                                                                                                                                                     --AND color_code = 'BCHS'
                                                                                                                                                                     /*                   AND (   SUBSTR (style_code, 1, 2) <> 'BG'
                                                                                                                                                                                AND  style_code NOT LIKE 'S%R'
                                                                                                                                                                                AND style_code NOT LIKE 'S%L'
                                                                                                                                                                                AND  style_code NOT LIKE '%BG') */
                                                                                                    --AND record_id = 1758
                                                                                                    ;


        TYPE get_category_tab IS TABLE OF get_category_c%ROWTYPE;

        xxd_category_tab       get_category_tab;

        CURSOR Get_category_id_c (p_concatenated_segs   VARCHAR2,
                                  p_cat_set_name        VARCHAR2)
        IS
            SELECT category_id
              FROM mtl_categories_b_kfv mcb, mtl_category_sets mcs
             WHERE     mcb.structure_id = mcs.structure_id
                   AND mcs.category_set_name = p_cat_set_name    --'Inventory'
                   AND concatenated_segments = p_concatenated_segs;

        ln_cat_id              NUMBER;



        /*      CURSOR Get_sample_item_c (
                 p_code IN VARCHAR2)
              IS
                 SELECT DISTINCT attribute28
                   FROM mtl_system_items_b msib, org_organization_definitions ood
                  WHERE     SUBSTR (segment1,
                                    1,
                                      INSTR (segment1,
                                             '-',
                                             1,
                                             2)
                                    - 1) = p_code
                        AND (attribute28 LIKE 'SAMPLE%' OR attribute28 LIKE 'BGRADE%')
                        AND msib.organization_id = ood.organization_id
                        AND ood.organization_code = 'MST'; */


        lc_attribute           VARCHAR2 (100);
        lc_category_exists     VARCHAR2 (1);
        lc_error_message       VARCHAR2 (1000);
        lc_inv_category        VARCHAR2 (1000);
        ln_inv_category_id     NUMBER;
        lc_error_flag          VARCHAR2 (1);
        lc_po_category         VARCHAR2 (1000);
        ln_po_category_id      NUMBER;
        lc_om_category         VARCHAR2 (1000);
        ln_om_category_id      NUMBER;
        ln_inv_s_category_id   NUMBER;
        ln_inv_b_category_id   NUMBER;
        ln_structure_id        NUMBER;
        l_category_rec         inv_item_category_pub.category_rec_type;
        l_out_category_id      NUMBER;
        l_msg_count            NUMBER;
        l_msg_data             VARCHAR2 (1000);
        l_return_status        VARCHAR2 (1);
        l_error_code           VARCHAR2 (100);
        l_messages             VARCHAR2 (1000);
        ln_error_cnt           NUMBER;
        ln_val_cnt             NUMBER;
        lc_om_status           VARCHAR2 (1);
        lc_po_status           VARCHAR2 (1);
        lc_inv_status          VARCHAR2 (1);
        lc_segments            VARCHAR2 (3500);
    BEGIN
        --Creating categories


        OPEN get_category_c;

        LOOP
            FETCH get_category_c
                BULK COLLECT INTO xxd_category_tab
                LIMIT 1000;



            IF xxd_category_tab.COUNT > 0
            THEN
                FOR i IN 1 .. xxd_category_tab.COUNT
                LOOP
                    BEGIN
                        lc_error_message       := NULL;
                        ln_inv_category_id     := NULL;


                        lc_attribute           := NULL;
                        lc_category_exists     := NULL;
                        lc_error_message       := NULL;
                        lc_inv_category        := NULL;
                        ln_inv_category_id     := NULL;
                        lc_po_category         := NULL;
                        ln_po_category_id      := NULL;
                        lc_om_category         := NULL;
                        ln_om_category_id      := NULL;
                        ln_inv_s_category_id   := NULL;
                        ln_inv_b_category_id   := NULL;
                        ln_structure_id        := NULL;
                        l_category_rec         := NULL;
                        l_out_category_id      := NULL;
                        l_msg_count            := NULL;
                        l_msg_data             := NULL;
                        l_return_status        := NULL;
                        l_error_code           := NULL;
                        l_messages             := NULL;
                        ln_error_cnt           := NULL;
                        ln_val_cnt             := NULL;
                        lc_om_status           := 'L';
                        lc_po_status           := 'L';
                        lc_inv_status          := 'L';
                        lc_error_flag          := 'N';
                        l_return_status        := 'S';

                        print_msg_prc (
                            p_debug,
                            'Inventory category creation for regular  ');


                        l_category_rec         := NULL;

                        --fnd_file.put_line(fnd_file.log,'Record_id '||xxd_category_tab (i).record_id);

                        --Inventory category creation
                        IF xxd_category_tab (i).INV_RECORD_STATUS = 'V'
                        THEN
                            l_category_rec                      := NULL;

                            --Start Code commented by 17-Apr-2015 as per PMO Decision
                            /* FOR j IN 1 .. 4
                             LOOP */
                            --End Code commented by 17-Apr-2015 as per PMO Decision
                            l_category_rec.structure_id         :=
                                xxd_category_tab (i).INV_STRUCTURE_ID;
                            l_category_rec.segment1             :=
                                xxd_category_tab (i).BRAND;
                            l_category_rec.segment2             :=
                                TRIM (xxd_category_tab (i).DIVISION);
                            l_category_rec.segment3             :=
                                TRIM (xxd_category_tab (i).DEPARTMENT);

                            l_category_rec.segment4             :=
                                TRIM (xxd_category_tab (i).CLASS);
                            l_category_rec.segment5             :=
                                TRIM (xxd_category_tab (i).SUB_CLASS);
                            l_category_rec.segment6             :=
                                TRIM (xxd_category_tab (i).MASTER_STYLE);


                            l_category_rec.segment7             :=
                                TRIM (xxd_category_tab (i).STYLE);

                            --Start Code commented by 17-Apr-2015 as per PMO Decision
                            /*    IF j = 1
                                THEN*/
                            --End Code commented by 17-Apr-2015 as per PMO Decision
                            l_category_rec.segment8             :=
                                TRIM (xxd_category_tab (i).STYLE_OPTION);
                            --Start Code commented by 17-Apr-2015 as per PMO Decision
                            /*    || '-B';
                          ELSIF j = 2
                          THEN
                             l_category_rec.segment8 :=
                                   TRIM (xxd_category_tab (i).STYLE_OPTION)
                                || '-S';
                          ELSIF j = 3
                          THEN
                             l_category_rec.segment8 :=
                                   TRIM (xxd_category_tab (i).STYLE_OPTION)
                                || '-G';
                          ELSIF j = 4
                          THEN
                             l_category_rec.segment8 :=
                                TRIM (xxd_category_tab (i).STYLE_OPTION);
                          END IF; */
                            --End Code commented by 17-Apr-2015 as per PMO Decision

                            l_category_rec.attribute_category   :=
                                'Item Categories';

                            l_category_rec.attribute5           :=
                                xxd_category_tab (i).SUB;

                            l_category_rec.attribute6           :=
                                xxd_category_tab (i).DETAIL;

                            l_category_rec.attribute7           :=
                                xxd_category_tab (i).STYLE_CODE;

                            l_category_rec.attribute8           :=
                                xxd_category_tab (i).COLOR_CODE;

                            l_category_rec.SUMMARY_FLAG         := 'N';
                            l_category_rec.ENABLED_FLAG         := 'Y';


                            --Creating inventory category code

                            lc_segments                         := NULL;

                            lc_segments                         :=
                                   l_category_rec.segment1
                                || '.'
                                || l_category_rec.segment2
                                || '.'
                                || l_category_rec.segment3
                                || '.'
                                || l_category_rec.segment4
                                || '.'
                                || l_category_rec.segment5
                                || '.'
                                || l_category_rec.segment6
                                || '.'
                                || l_category_rec.segment7
                                || '.'
                                || l_category_rec.segment8;


                            l_category_rec.description          :=
                                lc_segments;



                            OPEN Get_category_id_c (lc_segments, 'Inventory');

                            ln_cat_id                           := NULL;

                            FETCH Get_category_id_c INTO ln_cat_id;

                            CLOSE Get_category_id_c;


                            IF ln_cat_id IS NULL
                            THEN
                                create_category (p_debug, xxd_category_tab (i).record_id, 'Inventory ', l_category_rec, ln_inv_category_id, l_return_status
                                                 , l_messages);
                            ELSE
                                lc_error_message     := NULL; --  'Inventory  Category already created';
                                ln_inv_category_id   := ln_cat_id; --Added on 22-DEC-2015
                            END IF;



                            IF l_return_status <> 'S'
                            THEN
                                lc_error_flag      := 'Y';
                                lc_error_message   :=
                                    'For Inventory  ' || l_messages;
                                lc_inv_status      := 'E';
                            END IF;
                        --END LOOP;
                        END IF;

                        --fnd_file.put_line (fnd_file.LOG,     'lc_segments ' || lc_segments);
                        --fnd_file.put_line (                     fnd_file.LOG,                     'ln_inv_category_id ' || ln_inv_category_id);
                        --fnd_file.put_line (fnd_file.LOG,                                     'lc_inv_status ' || lc_inv_status);

                        --Start Code commented by 17-Apr-2015 as per PMO Decision
                        --END LOOP;

                        --CLOSE Get_sample_item_c;
                        --END IF;
                        --End Code commented by 17-Apr-2015 as per PMO Decision

                        --Purchasing  category creation

                        print_msg_prc (p_debug,
                                       'Purchasing category creation ');


                        l_category_rec         := NULL;
                        l_return_status        := NULL;               --22-DEC

                        IF xxd_category_tab (i).PO_RECORD_STATUS = 'V'
                        THEN
                            l_category_rec.structure_id   :=
                                xxd_category_tab (i).PO_STRUCTURE_ID;
                            l_category_rec.segment1       := 'Trade';
                            l_category_rec.segment2       :=
                                xxd_category_tab (i).CLASS;
                            l_category_rec.segment3       :=
                                xxd_category_tab (i).STYLE;


                            l_category_rec.SUMMARY_FLAG   := 'N';
                            l_category_rec.ENABLED_FLAG   := 'Y';

                            l_category_rec.description    :=
                                   l_category_rec.segment1
                                || '.'
                                || l_category_rec.segment2
                                || '.'
                                || l_category_rec.segment3;

                            lc_segments                   :=
                                   l_category_rec.segment1
                                || '.'
                                || l_category_rec.segment2
                                || '.'
                                || l_category_rec.segment3;

                            OPEN Get_category_id_c (lc_segments,
                                                    'PO Item Category');

                            ln_cat_id                     := NULL;

                            FETCH Get_category_id_c INTO ln_cat_id;

                            CLOSE Get_category_id_c;



                            IF ln_cat_id IS NULL
                            THEN
                                --Creating Purchasing category code
                                create_category (p_debug, xxd_category_tab (i).record_id, 'Purchasing ', l_category_rec, ln_po_category_id, l_return_status
                                                 , l_messages);
                            ELSE
                                lc_error_message    := NULL; --'PO  Category already created';
                                ln_po_category_id   := ln_cat_id; --Added on 22-DEC-2015
                            END IF;

                            IF l_return_status <> 'S'
                            THEN
                                lc_error_flag      := 'Y';
                                lc_error_message   :=
                                       lc_error_message
                                    || ' For PO '
                                    || l_messages;
                                lc_po_status       := 'E';
                            END IF;
                        END IF;

                        --fnd_file.put_line (fnd_file.LOG,                                     'lc_segments ' || lc_segments);
                        --fnd_file.put_line (                     fnd_file.LOG,                     'ln_po_category_id ' || ln_po_category_id);
                        --fnd_file.put_line (fnd_file.LOG,                                     'lc_po_status ' || lc_po_status);

                        print_msg_prc (p_debug, 'OM category creation ');


                        l_category_rec         := NULL;
                        l_return_status        := NULL;               --22-DEC

                        IF xxd_category_tab (i).OM_RECORD_STATUS = 'V'
                        THEN
                            l_category_rec.structure_id   :=
                                xxd_category_tab (i).OM_STRUCTURE_ID;
                            l_category_rec.segment1       :=
                                xxd_category_tab (i).STYLE;
                            l_category_rec.SUMMARY_FLAG   := 'N';
                            l_category_rec.ENABLED_FLAG   := 'Y';

                            l_category_rec.description    :=
                                l_category_rec.segment1;

                            lc_segments                   :=
                                l_category_rec.segment1;

                            OPEN Get_category_id_c (lc_segments,
                                                    'OM Sales Category');

                            ln_cat_id                     := NULL;

                            FETCH Get_category_id_c INTO ln_cat_id;

                            CLOSE Get_category_id_c;

                            IF ln_cat_id IS NULL
                            THEN
                                --Creating om category code
                                create_category (p_debug, xxd_category_tab (i).record_id, 'OM Category ', l_category_rec, ln_om_category_id, l_return_status
                                                 , l_messages);
                            ELSE
                                lc_error_message    := NULL; --'OM Category already created';
                                ln_om_category_id   := ln_cat_id; --Added on 22-DEC-2015
                            END IF;

                            IF l_return_status <> 'S'
                            THEN
                                lc_error_flag      := 'Y';
                                lc_error_message   :=
                                       lc_error_message
                                    || ' For OM '
                                    || l_messages;
                                lc_om_status       := 'E';
                            END IF;
                        END IF;

                        --fnd_file.put_line (fnd_file.LOG,                                     'lc_segments ' || lc_segments);
                        --fnd_file.put_line (                     fnd_file.LOG,                     'ln_om_category_id ' || ln_om_category_id);
                        --fnd_file.put_line (fnd_file.LOG,                                     'lc_om_status ' || lc_om_status);

                        UPDATE XXD_CONV.XXD_PLM_ATTR_STG_T
                           SET inv_category_id = ln_inv_category_id, om_category_id = ln_om_category_id, po_category_id = ln_po_category_id,
                               --22 DEC Start
                               /*  om_RECORD_STATUS = lc_om_status,
                                 po_RECORD_STATUS = lc_po_status,
                                 inv_RECORD_STATUS = lc_inv_status, */
                               --22 DEC End
                               om_RECORD_STATUS = DECODE (om_RECORD_STATUS, 'E', 'E', lc_om_status), po_RECORD_STATUS = DECODE (po_RECORD_STATUS, 'E', 'E', lc_po_status), inv_RECORD_STATUS = DECODE (inv_RECORD_STATUS, 'E', 'E', lc_inv_status),
                               ERROR_MESSAGE = ERROR_MESSAGE || ',' || lc_error_message, creation_date = SYSDATE, created_by = fnd_global.user_id,
                               last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, last_update_login = fnd_global.login_id,
                               request_id = gn_request_id
                         WHERE RECORD_ID = xxd_category_tab (i).record_id;
                    --END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_msg_prc (
                                p_debug,
                                   'Error for record '
                                || xxd_category_tab (i).record_id
                                || ' '
                                || SUBSTR (SQLERRM, 1, 300));

                            lc_error_message   := SUBSTR (SQLERRM, 1, 300);

                            xxd_common_utils.record_error (
                                p_module       => 'INV', --Oracle module short name
                                p_org_id       => gn_org_id,
                                p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                p_error_msg    => SUBSTR (l_messages, 1, 2000), --SQLERRM
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                p_created_by   => gn_user_id,        --USER_ID
                                p_request_id   => gn_request_id, -- concurrent request ID
                                p_more_info1   => 'RECORD ID ', --additional information for troubleshooting
                                p_more_info2   =>
                                    xxd_category_tab (i).record_id);


                            UPDATE XXD_CONV.XXD_PLM_ATTR_STG_T
                               SET inv_category_id = ln_inv_category_id, om_category_id = ln_om_category_id, po_category_id = ln_po_category_id,
                                   om_RECORD_STATUS = 'E', po_RECORD_STATUS = 'E', inv_RECORD_STATUS = 'E',
                                   ERROR_MESSAGE = ERROR_MESSAGE || ',' || lc_error_message, creation_date = SYSDATE, created_by = fnd_global.user_id,
                                   last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, last_update_login = fnd_global.login_id,
                                   request_id = gn_request_id
                             WHERE RECORD_ID = xxd_category_tab (i).record_id;
                    END;
                END LOOP;
            ELSE
                EXIT;
            END IF;

            COMMIT;
        END LOOP;

        COMMIT;

        --Category_assignment

        SELECT COUNT (*)
          INTO ln_error_cnt
          FROM XXD_CONV.XXD_PLM_ATTR_STG_T
         WHERE (om_RECORD_STATUS = 'E' OR inv_RECORD_STATUS = 'E' OR po_RECORD_STATUS = 'E');

        SELECT COUNT (*)
          INTO ln_val_cnt
          FROM XXD_CONV.XXD_PLM_ATTR_STG_T
         WHERE (om_RECORD_STATUS = 'L' AND inv_RECORD_STATUS = 'L' AND po_RECORD_STATUS = 'L');


        -- Writing Counts to output file.

        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Deckers Item Categories Creation and Assignment Program ');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '-------------------------------------------------');

        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no categories created from  XXD_PLM_ATTR_STG_T Table '
            || ln_val_cnt);
        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no categories failed in creation from  XXD_PLM_ATTR_STG_T Table '
            || ln_error_cnt);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error   := SUBSTR (SQLERRM, 1, 250);
            x_ret     := 2;
    --print_msg_prc (p_debug     => gc_debug_flag,                        p_message   => 'errbuf => ' || errbuf);
    END inv_category_create;



    PROCEDURE inv_category_assign (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_batch_no IN NUMBER
                                   , p_debug IN VARCHAR2)
    AS
        CURSOR get_category_assign_c IS
            SELECT RECORD_ID, BRAND, DIVISION,
                   DEPARTMENT, CLASS, SUB_CLASS,
                   MASTER_STYLE, STYLE, STYLE_OPTION,
                   STYLE_CODE, COLOR_CODE, om_STRUCTURE_ID,
                   po_STRUCTURE_ID, inv_STRUCTURE_ID, om_category_ID,
                   po_category_ID, inv_category_ID, om_category_set_ID,
                   po_category_set_ID, inv_category_set_ID, MSIB.inventory_item_id,
                   MSIB.organization_id, msib.attribute28, inv_s_category_id,
                   inv_b_category_id, om_RECORD_STATUS, inv_RECORD_STATUS,
                   po_RECORD_STATUS
              --XPAS.category_set_id
              FROM XXD_CONV.XXD_PLM_ATTR_STG_T XPAS, MTL_SYSTEM_ITEMS_B MSIB, ORG_ORGANIZATION_DEFINITIONS OOD
             WHERE     1 = 1
                   --AND batch_number = p_batch_no
                   AND (OM_RECORD_STATUS = 'L' OR PO_RECORD_STATUS = 'L' OR INV_RECORD_STATUS = 'L')
                   --AND XPAS.style_code IN (select style_code from    STYLE_TAB)
                   AND MSIB.ORGANIZATION_ID = OOD.ORGANIZATION_ID
                   --AND style_code in (select distinct segment1 from   XXD_ITEM_CONV_STG_T where  organization_id = 106)
                   --AND MSIB.inventory_item_id IN (14005263)
                   --AND XPAS.record_id IN (356722)
                   /* AND (   OM_CATEGORY_ID is not null
                                AND  PO_CATEGORY_ID is not null
                                AND  INV_RECORD_STATUS  is not null ) */
                   AND BATCH_NUMBER = p_batch_no
                   AND OOD.ORGANIZATION_CODE = 'MST'
                   --AND record_id=389921
                   AND SUBSTR (MSIB.segment1,
                               1,
                                 INSTR (MSIB.segment1, '-', 1,
                                        1)
                               - 1) = XPAS.STYLE_CODE
                   AND SUBSTR (segment1,
                                 INSTR (segment1, '-', 1,
                                        1)
                               + 1,
                               (  INSTR (segment1, '-', 1,
                                         2)
                                - INSTR (segment1, '-', 1,
                                         1)
                                - 1)) = XPAS.COLOR_CODE    --AND rownum <= 100
                                                       ;

        --Start Code commented by 17-Apr-2015 as per PMO Decision
        /*     OR     (    SUBSTR (MSIB.segment1,
                                 2,
                                   INSTR (MSIB.segment1,
                                          '-',
                                          1,
                                          1)
                                 - 3) = XPAS.STYLE_CODE
                     AND SUBSTR (segment1,
                                   INSTR (segment1,
                                          '-',
                                          1,
                                          1)
                                 + 1,
                                 (  INSTR (segment1,
                                           '-',
                                           1,
                                           2)
                                  - INSTR (segment1,
                                           '-',
                                           1,
                                           1)
                                  - 1)) = XPAS.COLOR_CODE)
                AND msib.attribute28 IN
                       ('SAMPLE', 'SAMPLE-L', 'SAMPLE-R')
             OR     (    REPLACE (SUBSTR (MSIB.segment1,
                                          1,
                                            INSTR (MSIB.segment1,
                                                   '-',
                                                   1,
                                                   1)
                                          - 1),
                                  'BG') = XPAS.STYLE_CODE
                     AND SUBSTR (segment1,
                                   INSTR (segment1,
                                          '-',
                                          1,
                                          1)
                                 + 1,
                                 (  INSTR (segment1,
                                           '-',
                                           1,
                                           2)
                                  - INSTR (segment1,
                                           '-',
                                           1,
                                           1)
                                  - 1)) = XPAS.COLOR_CODE)
                AND msib.attribute28 IN ('BGRADE')) --AND inventory_item_id = 8419278
                                                   /*
                                                           SUBSTR (segment1,
                                                                               1,
                                                                                 INSTR (segment1,
                                                                                        '-',
                                                                                        1,
                                                                                        2)
                                                                               - 1) = XPAS.STYLE_CODE || '-' || XPAS.COLOR_CODE */
        --AND MSIB.segment1 = '1005487-MRL-07'
        --AND (MSIB.attribute28 like 'SAMPLE%' or MSIB.attribute28 like 'BG%')
        --AND XPAS.record_id = 805
        --AND record_id IN (153, 167, 170, 173, 178)
        --AND  record_id = 16188
        --End Code commented by 17-Apr-2015 as per PMO Decision
        TYPE get_category_assign_tab
            IS TABLE OF get_category_assign_c%ROWTYPE;

        xxd_category_assign_tab   get_category_assign_tab;

        /*     CURSOR get_item_data_c (
                p_code VARCHAR2)
             IS
                SELECT MSIB.inventory_item_id,
                       MSIB.organization_id,
                       msib.attribute28
                  FROM MTL_SYSTEM_ITEMS_B MSIB, ORG_ORGANIZATION_DEFINITIONS OOD
                 WHERE     MSIB.ORGANIZATION_ID = OOD.ORGANIZATION_ID
                       AND OOD.ORGANIZATION_CODE = 'MST'
                       AND SUBSTR (segment1,
                                   1,
                                     INSTR (segment1,
                                            '-',
                                            1,
                                            2)
                                   - 1) = p_code;

             lcu_get_item_data_c       get_item_data_c%ROWTYPE; */

        CURSOR get_old_category_id_c (p_organization_id NUMBER, p_inventory_item_id NUMBER, p_category_set_id NUMBER)
        IS
            SELECT category_id
              FROM mtl_item_categories
             WHERE     organization_id = p_organization_id
                   AND inventory_item_id = p_inventory_item_id
                   AND category_set_id = p_category_set_id;


        CURSOR Get_category_segs_c (p_cat_id NUMBER)
        IS
            SELECT concatenated_segments
              FROM mtl_categories_b_kfv mcb, mtl_category_sets mcs
             WHERE     mcb.structure_id = mcs.structure_id
                   AND mcs.category_set_name = 'Inventory'
                   AND category_id = p_cat_id;

        lc_segments               VARCHAR2 (3500);


        CURSOR Get_category_id_c (p_segs VARCHAR2)
        IS
            SELECT category_id
              FROM mtl_categories_b_kfv mcb, mtl_category_sets mcs
             WHERE     mcb.structure_id = mcs.structure_id
                   AND mcs.category_set_name = 'Inventory'
                   AND concatenated_segments = p_segs;

        ln_new_cat_id             NUMBER;

        --lc_segments               VARCHAR2 (3500);


        ln_old_category_id        NUMBER;
        ln_category_id            NUMBER;
        l_return_status           VARCHAR2 (1);
        lc_error_flag             VARCHAR2 (1);
        l_messages                VARCHAR2 (4000);
        lc_error_message          VARCHAR2 (4000);
        ln_po_category_id         NUMBER;
        ln_om_category_id         NUMBER;
        ln_inv_category_id        NUMBER;
        ln_error_cnt              NUMBER;
        ln_val_cnt                NUMBER;
        lc_om_status              VARCHAR2 (1);
        lc_po_status              VARCHAR2 (1);
        lc_inv_status             VARCHAR2 (1);
    BEGIN
        OPEN get_category_assign_c;

        LOOP
            --xxd_category_assign_tab.delete;

            FETCH get_category_assign_c
                BULK COLLECT INTO xxd_category_assign_tab
                LIMIT 1000;



            IF xxd_category_assign_tab.COUNT > 0
            THEN
                FOR i IN 1 .. xxd_category_assign_tab.COUNT
                LOOP
                    BEGIN
                        --Assigning inventory category code



                        l_return_status      := NULL;
                        lc_error_flag        := 'N';
                        l_return_status      := 'N';
                        l_messages           := NULL;
                        ln_category_id       := NULL;
                        ln_old_category_id   := NULL;
                        lc_error_message     := NULL;
                        ln_po_category_id    := NULL;
                        ln_om_category_id    := NULL;
                        ln_inv_category_id   := NULL;
                        lc_om_status         := 'P';
                        lc_po_status         := 'P';
                        lc_inv_status        := 'P';
                        l_return_status      := 'S';

                        IF xxd_category_assign_tab (i).INV_RECORD_STATUS =
                           'L'
                        THEN
                            print_msg_prc (
                                p_debug,
                                   'organization_id '
                                || xxd_category_assign_tab (i).organization_id);
                            print_msg_prc (
                                p_debug,
                                   'inventory_item_id '
                                || xxd_category_assign_tab (i).inventory_item_id);
                            print_msg_prc (
                                p_debug,
                                   'inv_category_set_id '
                                || xxd_category_assign_tab (i).inv_category_set_id);



                            OPEN get_old_category_id_c (
                                xxd_category_assign_tab (i).organization_id,
                                xxd_category_assign_tab (i).inventory_item_id,
                                xxd_category_assign_tab (i).inv_category_set_id);

                            ln_old_category_id   := NULL;

                            FETCH get_old_category_id_c
                                INTO ln_old_category_id;

                            CLOSE get_old_category_id_c;

                            print_msg_prc (
                                p_debug,
                                'ln_old_category_id ' || ln_old_category_id);



                            IF ln_old_category_id IS NOT NULL
                            THEN
                                print_msg_prc (
                                    p_debug,
                                       'attribute '
                                    || xxd_category_assign_tab (i).attribute28);

                                --Start Code commented by 17-Apr-2015 as per PMO Decision

                                /*    IF SUBSTR (xxd_category_assign_tab (i).attribute28,
                                               1,
                                               6) = 'SAMPLE'
                                    THEN
                                       OPEN Get_category_segs_c (xxd_category_assign_tab (
                                                                    i).inv_category_id);

                                       lc_segments := NULL;

                                       FETCH Get_category_segs_c INTO lc_segments;

                                       CLOSE Get_category_segs_c;

                                       lc_segments := lc_segments || '-S';

                                       print_msg_prc (p_debug, 'Sample  ' || lc_segments);


                                       OPEN Get_category_id_c (lc_segments);

                                       ln_new_cat_id := NULL;

                                       FETCH Get_category_id_c INTO ln_new_cat_id;

                                       CLOSE Get_category_id_c;

                                       print_msg_prc (p_debug,
                                                      'Category id   ' || ln_new_cat_id);


                                       lc_segments := NULL;

                                       ln_category_id := ln_new_cat_id;
                                    ELSIF xxd_category_assign_tab (i).attribute28 =
                                             'BGRADE'
                                    THEN
                                       OPEN Get_category_segs_c (xxd_category_assign_tab (
                                                                    i).inv_category_id);

                                       lc_segments := NULL;

                                       FETCH Get_category_segs_c INTO lc_segments;

                                       CLOSE Get_category_segs_c;

                                       lc_segments := lc_segments || '-B';

                                       print_msg_prc (p_debug, 'Bgrade  ' || lc_segments);

                                       OPEN Get_category_id_c (lc_segments);

                                       ln_new_cat_id := NULL;

                                       FETCH Get_category_id_c INTO ln_new_cat_id;

                                       CLOSE Get_category_id_c;

                                       print_msg_prc (p_debug,
                                                      'Category id   ' || ln_new_cat_id);

                                       lc_segments := NULL;

                                       ln_category_id := ln_new_cat_id;
                                    --Start Modified on 13-APR-2015
                                    ELSIF xxd_category_assign_tab (i).attribute28 =
                                             'GENERIC'
                                    THEN
                                       OPEN Get_category_segs_c (xxd_category_assign_tab (
                                                                    i).inv_category_id);

                                       lc_segments := NULL;

                                       FETCH Get_category_segs_c INTO lc_segments;

                                       CLOSE Get_category_segs_c;

                                       lc_segments := lc_segments || '-G';

                                       print_msg_prc (p_debug,
                                                      'Generic  ' || lc_segments);

                                       OPEN Get_category_id_c (lc_segments);

                                       ln_new_cat_id := NULL;

                                       FETCH Get_category_id_c INTO ln_new_cat_id;

                                       CLOSE Get_category_id_c;

                                       print_msg_prc (p_debug,
                                                      'Category id   ' || ln_new_cat_id);

                                       lc_segments := NULL;

                                       ln_category_id := ln_new_cat_id;
                                    --End Modified on 13-APR-2015
                                    ELSE */
                                --End Code commented by 17-Apr-2015 as per PMO Decision
                                ln_category_id   :=
                                    xxd_category_assign_tab (i).inv_category_id;

                                IF NVL (ln_old_category_id, 1) <>
                                   NVL (ln_category_id, 2)
                                THEN
                                    Update_Category_Assignment (
                                        p_debug,
                                        xxd_category_assign_tab (i).record_id,
                                        ln_category_id,
                                        ln_old_category_id,
                                        xxd_category_assign_tab (i).inv_category_set_id,
                                        xxd_category_assign_tab (i).inventory_item_id,
                                        xxd_category_assign_tab (i).organization_id,
                                        l_return_status,
                                        l_messages);
                                ELSE
                                    l_return_status   := 'S';
                                END IF;
                            ELSE
                                ln_category_id   :=
                                    xxd_category_assign_tab (i).inv_category_id;

                                --Create_Category_assignment
                                create_Category_Assignment (
                                    p_debug,
                                    xxd_category_assign_tab (i).record_id,
                                    ln_category_id,
                                    --ln_old_category_id,
                                    xxd_category_assign_tab (i).inv_category_set_id,
                                    xxd_category_assign_tab (i).inventory_item_id,
                                    xxd_category_assign_tab (i).organization_id,
                                    l_return_status,
                                    l_messages);
                            END IF;

                            print_msg_prc (
                                p_debug,
                                'ln_category_id ' || ln_category_id);



                            print_msg_prc (
                                p_debug,
                                'l_return_status ' || l_return_status);
                            print_msg_prc (p_debug,
                                           'l_messages ' || l_messages);



                            IF l_return_status = 'S'
                            THEN
                                lc_error_flag   := 'N';
                                lc_inv_status   := 'P';
                            ELSE
                                lc_error_flag      := 'Y';

                                lc_error_message   :=
                                    SUBSTR (
                                        (lc_error_message || ' ' || SUBSTR (l_messages, 1, 4000)),
                                        1,
                                        3000);


                                lc_inv_status      := 'E';
                            END IF;
                        ELSE
                            print_msg_prc (
                                p_debug,
                                   'Failed to derive old category id for Inventory category set for item '
                                || xxd_category_assign_tab (i).inventory_item_id);
                        END IF;

                        --END IF;

                        --Assigning po category code

                        IF xxd_category_assign_tab (i).PO_RECORD_STATUS = 'L'
                        THEN
                            print_msg_prc (
                                p_debug,
                                   'Po organization_id '
                                || xxd_category_assign_tab (i).organization_id);

                            print_msg_prc (
                                p_debug,
                                   'Po inventory_item_id '
                                || xxd_category_assign_tab (i).inventory_item_id);
                            print_msg_prc (
                                p_debug,
                                   'Po inv_category_set_id '
                                || xxd_category_assign_tab (i).po_category_set_id);



                            OPEN get_old_category_id_c (
                                xxd_category_assign_tab (i).organization_id,
                                xxd_category_assign_tab (i).inventory_item_id,
                                xxd_category_assign_tab (i).po_category_set_ID);

                            ln_old_category_id   := NULL;

                            FETCH get_old_category_id_c
                                INTO ln_old_category_id;

                            CLOSE get_old_category_id_c;

                            print_msg_prc (
                                p_debug,
                                   'PO ln_old_category_id '
                                || ln_old_category_id);


                            IF ln_old_category_id IS NOT NULL
                            THEN
                                IF NVL (ln_old_category_id, 1) <>
                                   NVL (
                                       xxd_category_assign_tab (i).po_category_id,
                                       2)
                                THEN
                                    Update_Category_Assignment (
                                        p_debug,
                                        xxd_category_assign_tab (i).record_id,
                                        xxd_category_assign_tab (i).po_category_id,
                                        ln_old_category_id,
                                        xxd_category_assign_tab (i).po_category_set_id,
                                        xxd_category_assign_tab (i).inventory_item_id,
                                        xxd_category_assign_tab (i).organization_id,
                                        l_return_status,
                                        l_messages);
                                ELSE
                                    l_return_status   := 'S';
                                END IF;
                            ELSE
                                create_Category_Assignment (
                                    p_debug,
                                    xxd_category_assign_tab (i).record_id,
                                    xxd_category_assign_tab (i).po_category_id,
                                    --ln_old_category_id,
                                    xxd_category_assign_tab (i).po_category_set_id,
                                    xxd_category_assign_tab (i).inventory_item_id,
                                    xxd_category_assign_tab (i).organization_id,
                                    l_return_status,
                                    l_messages);
                            END IF;


                            IF l_return_status = 'S'
                            THEN
                                lc_error_flag   := 'N';
                                lc_po_status    := 'P';
                            ELSE
                                lc_error_flag   := 'Y';
                                lc_po_status    := 'E';
                                lc_error_message   :=
                                    SUBSTR (
                                        (lc_error_message || ' ' || SUBSTR (l_messages, 1, 4000)),
                                        1,
                                        3000);
                            END IF;
                        END IF;

                        --Assigning om category code

                        IF xxd_category_assign_tab (i).OM_RECORD_STATUS = 'L'
                        THEN
                            OPEN get_old_category_id_c (
                                xxd_category_assign_tab (i).organization_id,
                                xxd_category_assign_tab (i).inventory_item_id,
                                xxd_category_assign_tab (i).om_category_set_ID);

                            ln_old_category_id   := NULL;

                            FETCH get_old_category_id_c
                                INTO ln_old_category_id;

                            CLOSE get_old_category_id_c;

                            IF ln_old_category_id IS NOT NULL
                            THEN
                                IF ln_old_category_id <>
                                   xxd_category_assign_tab (i).om_category_id
                                THEN
                                    Update_Category_Assignment (
                                        p_debug,
                                        xxd_category_assign_tab (i).record_id,
                                        xxd_category_assign_tab (i).om_category_id,
                                        ln_old_category_id,
                                        xxd_category_assign_tab (i).om_category_set_id,
                                        xxd_category_assign_tab (i).inventory_item_id,
                                        xxd_category_assign_tab (i).organization_id,
                                        l_return_status,
                                        l_messages);
                                ELSE
                                    l_return_status   := 'S';
                                END IF;
                            ELSE
                                create_Category_Assignment (
                                    p_debug,
                                    xxd_category_assign_tab (i).record_id,
                                    xxd_category_assign_tab (i).om_category_id,
                                    --ln_old_category_id,
                                    xxd_category_assign_tab (i).om_category_set_ID,
                                    xxd_category_assign_tab (i).inventory_item_id,
                                    xxd_category_assign_tab (i).organization_id,
                                    l_return_status,
                                    l_messages);
                            END IF;

                            IF l_return_status = 'S'
                            THEN
                                lc_error_flag   := 'N';
                                lc_om_status    := 'P';
                            ELSE
                                lc_error_flag      := 'Y';
                                lc_error_message   :=
                                    SUBSTR (
                                        (lc_error_message || ' ' || SUBSTR (l_messages, 1, 4000)),
                                        1,
                                        3000);
                                lc_om_status       := 'E';
                            END IF;
                        END IF;

                        print_msg_prc (p_debug,
                                       'lc_error_flag ' || lc_error_flag);



                        UPDATE XXD_CONV.XXD_PLM_ATTR_STG_T
                           SET ERROR_MESSAGE = SUBSTR (lc_error_message, 1, 2000), creation_date = SYSDATE, created_by = fnd_global.user_id,
                               last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, last_update_login = fnd_global.login_id,
                               --22 DEC Start
                               /*  om_RECORD_STATUS = lc_om_status,
                                 po_RECORD_STATUS = lc_po_status,
                                 inv_RECORD_STATUS = lc_inv_status, */
                               --22 DEC End
                               om_RECORD_STATUS = DECODE (om_RECORD_STATUS, 'E', 'E', lc_om_status), po_RECORD_STATUS = DECODE (po_RECORD_STATUS, 'E', 'E', lc_po_status), inv_RECORD_STATUS = DECODE (inv_RECORD_STATUS, 'E', 'E', lc_inv_status),
                               request_id = gn_request_id
                         WHERE RECORD_ID =
                               xxd_category_assign_tab (i).record_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'INV', --Oracle module short name
                                p_org_id       => gn_org_id,
                                p_program      => gc_program_name, --Concurrent program, PLSQL procedure, etc..
                                p_error_msg    => SUBSTR (SQLERRM, 1, 2000), --SQLERRM
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                p_created_by   => gn_user_id,        --USER_ID
                                p_request_id   => gn_request_id, -- concurrent request ID
                                p_more_info1   => 'RECORD_ID ', --additional information for troubleshooting
                                p_more_info2   =>
                                    xxd_category_assign_tab (i).record_id);
                    END;
                END LOOP;
            ELSE
                EXIT;
            END IF;

            COMMIT;
        END LOOP;


        SELECT COUNT (*)
          INTO ln_error_cnt
          FROM XXD_CONV.XXD_PLM_ATTR_STG_T
         WHERE (om_RECORD_STATUS = 'E' OR inv_RECORD_STATUS = 'E' OR om_RECORD_STATUS = 'E');

        SELECT COUNT (*)
          INTO ln_val_cnt
          FROM XXD_CONV.XXD_PLM_ATTR_STG_T
         WHERE (om_RECORD_STATUS = 'P' AND inv_RECORD_STATUS = 'P' AND om_RECORD_STATUS = 'P');


        -- Writing Counts to output file.

        fnd_file.put_line (
            fnd_file.OUTPUT,
            'Deckers Item Categories Creation and Assignment Program ');
        fnd_file.put_line (
            fnd_file.OUTPUT,
            '-------------------------------------------------');

        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no of record processed for assignment from  XXD_PLM_ATTR_STG_T Table '
            || ln_val_cnt);
        fnd_file.put_line (
            fnd_file.OUTPUT,
               'Total no of record failed for assignment from  XXD_PLM_ATTR_STG_T Table '
            || ln_error_cnt);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SUBSTR (SQLERRM, 1, 250);
            retcode   := 2;
    --print_msg_prc (p_debug     => gc_debug_flag,                         p_message   => 'errbuf => ' || errbuf);
    END inv_category_assign;

    --END;

    PROCEDURE inv_category_main (errbuf               OUT NOCOPY VARCHAR2,
                                 retcode              OUT NOCOPY NUMBER,
                                 p_process         IN            VARCHAR2,
                                 p_no_of_process   IN            NUMBER,
                                 --p_batch_size      IN             NUMBER,
                                 p_debug           IN            VARCHAR2 --p_create_cat_only IN             VARCHAR2
                                                                         )
    IS
        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        CURSOR Get_batch_num_c IS
            SELECT DISTINCT batch_number
              FROM XXD_CONV.XXD_PLM_ATTR_STG_T
             WHERE (om_record_status = 'L' OR inv_record_status = 'L' OR po_record_status = 'L');



        CURSOR Get_batch_num_cr_c IS
            SELECT DISTINCT batch_number
              FROM XXD_CONV.XXD_PLM_ATTR_STG_T
             WHERE (om_record_status = 'V' OR inv_record_status = 'V' OR po_record_status = 'V');



        CURSOR Get_batch_num_val_c IS
            SELECT DISTINCT batch_number
              FROM XXD_CONV.XXD_PLM_ATTR_STG_T
             WHERE (om_record_status IN ('N', 'E') OR inv_record_status IN ('N', 'E') OR po_record_status IN ('N', 'E'));



        CURSOR Get_non_plm_data_c IS
            SELECT style_code, BRAND, CLASS,
                   DEPARTMENT, DIVISION, MASTER_STYLE,
                   STYLE, XPAS.SUB_CLASS, SUB,
                   DETAIL
              FROM XXD_CONV.XXD_PLM_ATTR_STG_T XPAS
             WHERE XPAS.color_code IS NULL --             AND record_id IS NULL
                                           AND DATA_SOURCE LIKE 'NONPLM%';

        lcu_Get_non_plm_data_c    Get_non_plm_data_c%ROWTYPE;

        CURSOR inv_data (p_style VARCHAR2)
        IS
            SELECT DISTINCT color_code
              FROM XXD_CONV.STYLE_COLOR
             WHERE style_code = p_style;

        lcu_inv_data              inv_data%ROWTYPE;

        CURSOR get_style_option_c (p_color VARCHAR2)
        IS
            SELECT fv.DESCRIPTION
              FROM apps.FND_FLEX_VALUES_VL fv, fnd_flex_value_sets ffvs
             WHERE     1 = 1
                   --AND fv.flex_value_set_id = 1015995
                   AND fv.flex_value_set_id = ffvs.FLEX_VALUE_SET_ID
                   AND FLEX_VALUE_SET_NAME = 'DO_COLOR_CODE'
                   AND fv.FLEX_VALUE = p_color;


        /*   CURSOR Get_style_C
           IS
              SELECT msib.segment1,
                     mc.attribute7,
                     SUBSTR (msib.segment1,
                             1,
                               INSTR (msib.segment1,
                                      '-',
                                      1,
                                      1)
                             - 1)
                        style,
                     msib.inventory_item_id,
                     mc.category_id
                FROM MTL_SYSTEM_ITEMS_B msib,
                     mtl_item_categories mic,
                     mtl_categories_b mc,
                     mtl_category_sets mcs,
                     mtl_parameters mp
               WHERE     msib.inventory_item_id = mic.inventory_item_id
                     AND msib.organization_id = mic.organization_id
                     AND mc.category_id = mic.category_id
                     AND msib.organization_id = mp.organization_id
                     AND mcs.CATEGORY_SET_NAME = 'Inventory'
                     AND mic.category_set_id = mcs.category_set_id
                     AND (   SUBSTR (msib.segment1,
                                     1,
                                       INSTR (msib.segment1,
                                              '-',
                                              1,
                                              1)
                                     - 1) <> mc.attribute7
                          OR mc.attribute7 IS NULL); */

        --lcu_Get_style_C           Get_style_C%ROWTYPE;


        lc_style_option           VARCHAR2 (100);


        ln_batch_no               NUMBER;

        ln_hdr_batch_id           hdr_batch_id_t;
        ln_new_rec_count          NUMBER;
        ln_err_rec_count          NUMBER;
        ln_validated_rec_count    NUMBER;
        ln_interfaced_rec_count   NUMBER;
        ln_success_rec_count      NUMBER;
        ln_total_rec_count        NUMBER;
        lc_conlc_status           VARCHAR2 (150);
        ln_request_id             NUMBER := 0;
        lc_phase                  VARCHAR2 (200);
        lc_status                 VARCHAR2 (200);
        lc_delc_phase             VARCHAR2 (200);
        lc_delc_status            VARCHAR2 (200);
        lc_message                VARCHAR2 (200);
        ln_ret_code               NUMBER;
        lc_err_buff               VARCHAR2 (1000);
        ln_count                  NUMBER;
        ln_cntr                   NUMBER := 0;
        --      ln_batch_cnt          NUMBER         := 0;
        ln_parent_request_id      NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
        lb_wait                   BOOLEAN;
        ln_batch_cnt              NUMBER;
        lc_err                    VARCHAR2 (1000);
        ln_err                    NUMBER;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                  request_table;
        ln_hdr_bat_id             NUMBER;
        ln_loop_counter           NUMBER;
        lc_dev_phase              VARCHAR2 (100);
        lc_dev_status             VARCHAR2 (100);
        lb_wait_for_request       BOOLEAN := FALSE;
        ln_cnt                    NUMBER;
    BEGIN
        errbuf          := NULL;
        retcode         := 0;
        gc_debug_flag   := p_debug;

        IF p_process = 'POPULATE'
        THEN
            BEGIN
                OPEN Get_non_plm_data_c;


                LOOP
                    FETCH Get_non_plm_data_c INTO lcu_Get_non_plm_data_c;

                    EXIT WHEN Get_non_plm_data_c%NOTFOUND;

                    OPEN inv_data (lcu_Get_non_plm_data_c.style_code);



                    LOOP
                        FETCH inv_data INTO lcu_inv_data;

                        EXIT WHEN inv_data%NOTFOUND;

                        OPEN get_style_option_c (lcu_inv_data.color_code);

                        FETCH get_style_option_c INTO lc_style_option;

                        CLOSE get_style_option_c;


                        INSERT INTO XXD_CONV.XXD_PLM_ATTR_STG_T (
                                        record_id,
                                        data_source,
                                        BRAND,
                                        CLASS,
                                        COLOR_CODE,
                                        DEPARTMENT,
                                        DIVISION,
                                        MASTER_STYLE,
                                        STYLE,
                                        STYLE_CODE,
                                        STYLE_OPTION,
                                        SUB_CLASS,
                                        SUB,
                                        DETAIL,
                                        INV_RECORD_STATUS,
                                        PO_RECORD_STATUS,
                                        OM_RECORD_STATUS)
                             VALUES (XXD_CONV.XXD_PLM_ATTR_STG_SEQ.NEXTVAL, 'NONPLM', lcu_Get_non_plm_data_c.BRAND, lcu_Get_non_plm_data_c.CLASS, lcu_inv_data.color_code, lcu_Get_non_plm_data_c.DEPARTMENT, lcu_Get_non_plm_data_c.DIVISION, lcu_Get_non_plm_data_c.MASTER_STYLE, lcu_Get_non_plm_data_c.STYLE, lcu_Get_non_plm_data_c.STYLE_CODE, lc_style_option, lcu_Get_non_plm_data_c.SUB_CLASS, lcu_Get_non_plm_data_c.SUB, lcu_Get_non_plm_data_c.DETAIL, 'N'
                                     , 'N', 'N');
                    END LOOP;

                    CLOSE inv_data;
                END LOOP;


                COMMIT;

                DELETE FROM XXD_CONV.XXD_PLM_ATTR_STG_T
                      WHERE COLOR_CODE IS NULL;

                COMMIT;

                CLOSE Get_non_plm_data_c;
            END;
        ELSIF p_process = 'VALIDATE'
        THEN
            --fnd_file.put_line (fnd_file.LOG, 'Test1');

            --Start modification on 13-OCT-2015
            /*      FOR i IN 1 .. p_no_of_process
                        LOOP

                              SELECT xxd_item_conv_bth_seq.NEXTVAL
                                INTO ln_hdr_bat_id
                                FROM DUAL;

                        SELECT count(1) INTO  ln_cnt FROM XXD_CONV.XXD_PLM_ATTR_STG_T;

                           UPDATE XXD_CONV.XXD_PLM_ATTR_STG_T
                              SET BATCH_NUMBER = ln_hdr_bat_id
                            --, REQUEST_ID = ln_parent_request_id
                            WHERE     batch_number IS NULL
                                  AND ROWNUM <= CEIL (ln_cnt / p_no_of_process);
                                  --AND organization_id = ln_organization_id
                                  --AND record_status IN ('N', 'E');
                        END LOOP; */


            UPDATE Xxd_Conv.Xxd_Plm_Attr_Stg_T
               SET Inv_Record_Status = 'N', po_Record_Status = 'N', om_Record_Status = 'N',
                   Batch_Number = NULL, Inv_Structure_Id = NULL, Po_Structure_Id = NULL,
                   Om_Structure_Id = NULL, Inv_Category_Id = NULL, Om_Category_Id = NULL,
                   Po_Category_Id = NULL, error_message = NULL, INV_CATEGORY_SET_ID = NULL,
                   po_CATEGORY_SET_ID = NULL, om_CATEGORY_SET_ID = NULL, RECORD_ID = NULL;

            --fnd_file.put_line (fnd_file.LOG, 'Test2');

            COMMIT;

            INSERT INTO XXD_CONV.XXD_PLM_ATTR_STG_T (RECORD_ID,
                                                     STYLE_CODE,
                                                     COLOR_CODE,
                                                     BRAND,
                                                     DIVISION,
                                                     DEPARTMENT,
                                                     CLASS,
                                                     SUB_CLASS,
                                                     MASTER_STYLE,
                                                     STYLE,
                                                     STYLE_OPTION,
                                                     SUB,
                                                     DETAIL,
                                                     DATA_SOURCE,
                                                     OM_RECORD_STATUS,
                                                     INV_RECORD_STATUS,
                                                     PO_RECORD_STATUS,
                                                     batch_number)
                SELECT XXD_CONV.XXD_PLM_ATTR_STG_SEQ.NEXTVAL, --    Commented on 09-OCT-2015
                       STYLE_CODE,
                       COLOR_CODE,
                       BRAND,
                       DIVISION,
                       DEPARTMENT,
                       CLASS,
                       SUB_CLASS,
                       REPLACE (MASTER_STYLE, CHR (146), '''') MASTER_STYLE,
                       REPLACE (STYLE, CHR (146), '''') STYLE,
                       REPLACE (style_option, CHR (13)) STYLE_OPTION,
                       SUB,
                       DETAIL,
                       DATA_SOURCE,
                       OM_RECORD_STATUS,
                       INV_RECORD_STATUS,
                       PO_RECORD_STATUS,
                       NTILE (p_no_of_process)
                           OVER (ORDER BY
                                     BRAND, DIVISION, DEPARTMENT,
                                     CLASS, SUB_CLASS, MASTER_STYLE,
                                     STYLE, STYLE_OPTION)
                  FROM XXD_CONV.XXD_PLM_ATTR_STG_T;

            --fnd_file.put_line (fnd_file.LOG, 'Test3');

            COMMIT;


            DELETE XXD_CONV.XXD_PLM_ATTR_STG_T
             WHERE RECORD_ID IS NULL;

            COMMIT;

            /*   fnd_file.put_line (fnd_file.LOG, 'Test4');
                  UPDATE XXD_CONV.XXD_PLM_ATTR_STG_T X2
                     SET X2.batch_number =
                            (SELECT MIN (batch_number)
                               FROM XXD_CONV.XXD_PLM_ATTR_STG_T X1
                              WHERE     NVL (X1.BRAND, 'XX') = NVL (X2.BRAND, 'XX')
                                    AND NVL (X1.DIVISION, 'XX') =  NVL (X2.DIVISION, 'XX')
                                    AND NVL (X1.DEPARTMENT, 'XX') =   NVL (X2.DEPARTMENT, 'XX')
                                    AND NVL (X1.CLASS, 'XX') = NVL (X2.CLASS, 'XX')
                                    AND NVL (X1.SUB_CLASS, 'XX') = NVL (X2.SUB_CLASS, 'XX')
                                    AND NVL (X1.MASTER_STYLE, 'XX') =     NVL (X2.MASTER_STYLE, 'XX')
                                    AND NVL (X1.STYLE, 'XX') = NVL (X2.STYLE, 'XX')
                                    AND NVL (X1.STYLE_OPTION, 'XX') =  NVL (X2.STYLE_OPTION, 'XX'));

                           fnd_file.put_line (fnd_file.LOG, 'Test5'); */

            COMMIT;

            --End modification on 13-OCT-2015
            --fnd_file.put_line(fnd_file.log,'Test2');

            --inv_category_validation (lc_err, ln_err, p_debug,p_no_of_process);

            --inv_category_create (lc_err, ln_err, p_debug);



            --inv_category_create (lc_err, ln_err);
            ln_loop_counter   := 1;

            --fnd_file.put_line (fnd_file.LOG, 'Test6');

            OPEN Get_batch_num_val_c;

            LOOP
                -- fnd_file.put_line (fnd_file.LOG, 'Test7');
                ln_batch_no   := NULL;

                FETCH Get_batch_num_val_c INTO ln_batch_no;

                EXIT WHEN Get_batch_num_val_c%NOTFOUND;

                -- inv_category_assign (lc_err, ln_err);


                ln_request_id   :=
                    fnd_request.submit_request (application => 'XXDCONV', program => 'XXD_CAT_VAL', description => 'Deckers Item Categories Validation  Program -Child', start_time => SYSDATE, sub_request => NULL, argument1 => ln_batch_no
                                                , argument2 => p_debug);


                IF ln_request_id > 0
                THEN
                    l_req_id (ln_loop_counter)   := ln_request_id;
                    ln_loop_counter              := ln_loop_counter + 1;
                    COMMIT;
                ELSE
                    ROLLBACK;
                END IF;
            END LOOP;

            CLOSE Get_batch_num_val_c;


            --Waits for the Child requests completion
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                BEGIN
                    IF l_req_id (rec) IS NOT NULL
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;
                            lb_wait_for_request   :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => l_req_id (rec),
                                    interval     => 60,
                                    max_wait     => 0,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);
                            COMMIT;


                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                END;
            END LOOP;
        /*    OPEN Get_style_C;

            LOOP
               FETCH Get_style_C INTO lcu_Get_style_C;

               EXIT WHEN Get_style_C%NOTFOUND;

               UPDATE mtl_categories_b
                  SET attribute7 = lcu_Get_style_C.style
                WHERE category_id = lcu_Get_style_C.category_id;
            END LOOP;

            CLOSE Get_style_C; */

        ELSIF p_process = 'CREATE'
        THEN
            --inv_category_create (lc_err, ln_err, p_debug);



            --inv_category_create (lc_err, ln_err);
            ln_loop_counter   := 1;

            OPEN Get_batch_num_cr_c;

            LOOP
                ln_batch_no   := NULL;

                FETCH Get_batch_num_cr_c INTO ln_batch_no;

                EXIT WHEN Get_batch_num_cr_c%NOTFOUND;

                -- inv_category_assign (lc_err, ln_err);


                ln_request_id   :=
                    fnd_request.submit_request (application => 'XXDCONV', program => 'XXD_CAT_CREATE', description => 'Deckers Item Categories Creation  Program -Child', start_time => SYSDATE, sub_request => NULL, argument1 => ln_batch_no
                                                , argument2 => p_debug);


                IF ln_request_id > 0
                THEN
                    l_req_id (ln_loop_counter)   := ln_request_id;
                    ln_loop_counter              := ln_loop_counter + 1;
                    COMMIT;
                ELSE
                    ROLLBACK;
                END IF;
            END LOOP;

            CLOSE Get_batch_num_cr_c;


            --Waits for the Child requests completion
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                BEGIN
                    IF l_req_id (rec) IS NOT NULL
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;
                            lb_wait_for_request   :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => l_req_id (rec),
                                    interval     => 60,
                                    max_wait     => 0,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);
                            COMMIT;


                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                END;
            END LOOP;

            /*    OPEN Get_style_C;

                LOOP
                   FETCH Get_style_C INTO lcu_Get_style_C;

                   EXIT WHEN Get_style_C%NOTFOUND;

                   UPDATE mtl_categories_b
                      SET attribute7 = lcu_Get_style_C.style
                    WHERE category_id = lcu_Get_style_C.category_id;
                END LOOP;

                CLOSE Get_style_C; */

            --Start of duplicate categories

            DECLARE
                CURSOR get_conc_seg_c IS
                      SELECT CONCATENATED_SEGMENTS
                        FROM mtl_categories_kfv mck
                       WHERE     1 = 1
                             --AND CONCATENATED_SEGMENTS = 'Trade.MARKETING PROMO.RM202-17MM CUFF TABLEGRADE SHEEPSKIN'
                             AND EXISTS
                                     (SELECT 1
                                        FROM mtl_category_sets mcs
                                       WHERE     mcs.STRUCTURE_ID =
                                                 mck.STRUCTURE_ID
                                             AND category_set_name IN
                                                     ('Inventory', 'OM Sales Category', 'PO Item Category'))
                    GROUP BY CONCATENATED_SEGMENTS
                      HAVING COUNT (1) > 1;

                lc_CONCATENATED_SEGMENTS   VARCHAR2 (1000);

                CURSOR get_cat_id_c (p_CONCATENATED_SEGMENTS VARCHAR2)
                IS
                    SELECT category_id
                      FROM mtl_categories_kfv mck
                     WHERE     CONCATENATED_SEGMENTS =
                               p_CONCATENATED_SEGMENTS
                           AND EXISTS
                                   (SELECT 1
                                      FROM mtl_category_sets mcs
                                     WHERE     mcs.STRUCTURE_ID =
                                               mck.STRUCTURE_ID
                                           AND category_set_name IN
                                                   ('Inventory', 'OM Sales Category', 'PO Item Category'))
                           AND ROWID NOT IN
                                   (SELECT MIN (ROWID)
                                      FROM mtl_categories_kfv mck
                                     WHERE     CONCATENATED_SEGMENTS =
                                               p_CONCATENATED_SEGMENTS
                                           AND EXISTS
                                                   (SELECT 1
                                                      FROM mtl_category_sets mcs
                                                     WHERE     mcs.STRUCTURE_ID =
                                                               mck.STRUCTURE_ID
                                                           AND category_set_name IN
                                                                   ('Inventory', 'OM Sales Category', 'PO Item Category')));

                ln_cat_id                  NUMBER;
                l_return_status            VARCHAR2 (1);
                l_error_code               VARCHAR2 (1);
                l_msg_count                NUMBER;
                l_msg_data                 VARCHAR2 (1000);
                l_messages                 VARCHAR2 (4000);
                lc_category                VARCHAR2 (1000);
                x_error_message            VARCHAR2 (4000);
                ln_count                   NUMBER := 0;
            BEGIN
                DBMS_OUTPUT.PUT_LINE (
                    'Sysdate ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                OPEN get_conc_seg_c;

                LOOP
                    lc_CONCATENATED_SEGMENTS   := NULL;

                    FETCH get_conc_seg_c INTO lc_CONCATENATED_SEGMENTS;

                    EXIT WHEN get_conc_seg_c%NOTFOUND;

                    OPEN get_cat_id_c (lc_CONCATENATED_SEGMENTS);

                    LOOP
                        ln_cat_id   := NULL;

                        FETCH get_cat_id_c INTO ln_cat_id;

                        EXIT WHEN get_cat_id_c%NOTFOUND;

                        --DBMS_OUTPUT.put_line ('Cat id ' || ln_cat_id);

                        inv_item_category_pub.delete_category (
                            p_api_version     => 1.0,
                            p_init_msg_list   => fnd_api.g_false,
                            p_commit          => fnd_api.g_false,
                            x_return_status   => l_return_status,
                            x_errorcode       => l_error_code,
                            x_msg_count       => l_msg_count,
                            x_msg_data        => l_msg_data,
                            p_category_id     => ln_cat_id);

                        --DBMS_OUTPUT.put_line ('l_return_status ' || l_return_status);

                        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
                        THEN
                            l_return_status   := 'E';
                            FND_MSG_PUB.COUNT_AND_GET (
                                p_encoded   => 'F',
                                p_count     => l_msg_count,
                                p_data      => l_msg_data);

                            FOR K IN 1 .. l_msg_count
                            LOOP
                                l_messages   :=
                                       fnd_msg_pub.get (p_msg_index   => k,
                                                        p_encoded     => 'F')
                                    || ';';
                            END LOOP;



                            FND_MESSAGE.SET_NAME ('FND',
                                                  'GENERIC-INTERNAL ERROR');
                            FND_MESSAGE.SET_TOKEN ('ROUTINE',
                                                   'Category Migration');
                            FND_MESSAGE.SET_TOKEN ('REASON', l_messages);

                            x_error_message   := l_messages;
                        ELSE
                            l_return_status   := 'S';
                        --x_category_id := l_out_category_id;
                        END IF;

                        ln_count    := ln_count + 1;
                    --DBMS_OUTPUT.put_line ('l_return_status ' || l_return_status);
                    END LOOP;

                    --DBMS_OUTPUT.put_line ('l_messages ' || l_messages);

                    CLOSE get_cat_id_c;
                END LOOP;

                CLOSE get_conc_seg_c;

                DBMS_OUTPUT.put_line (
                    'No of categories deleted ' || ln_count);
                COMMIT;
            END;
        --End of duplicate categories

        ELSIF p_process = 'ASSIGN'
        THEN
            --inv_category_create (lc_err, ln_err);
            ln_loop_counter   := 1;

            OPEN Get_batch_num_c;

            LOOP
                ln_batch_no   := NULL;

                FETCH Get_batch_num_c INTO ln_batch_no;

                EXIT WHEN Get_batch_num_c%NOTFOUND;

                -- inv_category_assign (lc_err, ln_err);

                --fnd_file.put_line(fnd_file.log,'Test1');


                ln_request_id   :=
                    fnd_request.submit_request (application => 'XXDCONV', program => 'XXD_CAT_UPDATE', description => 'Deckers Item Categories Creation and Assignment Program -Child', start_time => SYSDATE, sub_request => NULL, argument1 => ln_batch_no
                                                , argument2 => p_debug);

                --fnd_file.put_line(fnd_file.log,'Test2');

                IF ln_request_id > 0
                THEN
                    l_req_id (ln_loop_counter)   := ln_request_id;
                    ln_loop_counter              := ln_loop_counter + 1;
                    COMMIT;
                ELSE
                    ROLLBACK;
                END IF;
            END LOOP;

            CLOSE Get_batch_num_c;

            --fnd_file.put_line(fnd_file.log,'Test3');

            --Waits for the Child requests completion
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                --fnd_file.put_line(fnd_file.log,'Test4');

                BEGIN
                    IF l_req_id (rec) IS NOT NULL
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;
                            lb_wait_for_request   :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => l_req_id (rec),
                                    interval     => 60,
                                    max_wait     => 0,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);
                            COMMIT;


                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;
                END;
            --fnd_file.put_line(fnd_file.log,'Test5');

            END LOOP;
        --fnd_file.put_line(fnd_file.log,'Test6');

        /*    OPEN Get_style_C;

            LOOP
               FETCH Get_style_C INTO lcu_Get_style_C;

               EXIT WHEN Get_style_C%NOTFOUND;

               UPDATE mtl_categories_b
                  SET attribute7 = lcu_Get_style_C.style
                WHERE category_id = lcu_Get_style_C.category_id;
            END LOOP;

            CLOSE Get_style_C; */
        END IF;

        retcode         := ln_err;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SUBSTR (SQLERRM, 1, 250);
            retcode   := 2;
            print_msg_prc (p_debug     => gc_debug_flag,
                           p_message   => 'errbuf => ' || errbuf);
    END inv_category_main;
END XXD_INV_CATEGORY_CNV_PKG;
/
