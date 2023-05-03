--
-- XXDO_PURGING_STAGING_TABLE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PURGING_STAGING_TABLE_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  XXDO_PURGING_STAGING_TABLE_PKG.sql   1.0    2015/09/02    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  XXDO_PURGING_STAGING_TABLE_PKG
    --
    -- Description  :  This is package  for purging staging table
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 02-Sep-2015    Infosys            1.0       Created
    -- ***************************************************************************


    PROCEDURE main (p_error_buf OUT VARCHAR2, p_ret_code OUT NUMBER, p_table_name IN VARCHAR2
                    , p_to_email_id IN VARCHAR2, p_mode IN VARCHAR2)
    IS
        l_num_return_value          NUMBER := 0;
        l_record_set                SYS_REFCURSOR;
        l_record_count              SYS_REFCURSOR;
        l_record_set_count          NUMBER;
        l_error_occured             NUMBER := 0;
        l_where_clause              VARCHAR2 (2000);
        l_child_stg_tab_name        VARCHAR2 (100);
        l_child_stg_arch_tab_name   VARCHAR2 (100);
        l_wait_for_request          BOOLEAN;
        l_phase                     VARCHAR2 (50);
        l_status                    VARCHAR2 (50);
        l_dev_phase                 VARCHAR2 (50);
        l_dev_status                VARCHAR2 (50);
        l_message                   VARCHAR2 (2000);
        l_num_request_id            NUMBER;
        g_num_request_id            NUMBER := fnd_global.conc_request_id;
        l_where_clause1             VARCHAR2 (100);
        l_where_clause2             VARCHAR2 (100);
        l_where_clause3             VARCHAR2 (100);
        l_where_clause4             VARCHAR2 (100);
        l_where_clause5             VARCHAR2 (100);
        p_where_clause              VARCHAR2 (2000);
        l_meaning                   VARCHAR2 (100);
        l_rec_count                 NUMBER;


        CURSOR c_rec_data (p_table_name IN VARCHAR2)
        IS
              SELECT lookup_code QUERY_ID, meaning TABLE_NAME, attribute2 STG_TABLE_NAME,
                     attribute3 ARCHIVAL_TABLE_NAME, attribute4 WHERE_CLAUSE_1, attribute5 WHERE_CLAUSE_2,
                     attribute6 WHERE_CLAUSE_3, attribute7 WHERE_CLAUSE_4, attribute8 WHERE_CLAUSE_5
                FROM fnd_lookup_values
               WHERE     lookup_type = 'XXDO_STAG_PURG_QUERY_TBL'
                     AND enabled_flag = 'Y'
                     AND UPPER (meaning) = UPPER (p_table_name)
                     AND language = USERENV ('LANG')
            ORDER BY lookup_code ASC;

        CURSOR c_get_child (p_tbl_name IN VARCHAR2)
        IS
            SELECT P_COL.table_name parent_table, P_COL.column_name parent_col_name, C_COL.table_name child_table,
                   C_COL.column_name child_col_name
              FROM DBA_CONS_COLUMNS C_COL, DBA_CONS_COLUMNS P_COL, DBA_CONSTRAINTS C,
                   DBA_CONSTRAINTS P
             WHERE     C_COL.CONSTRAINT_NAME = C.CONSTRAINT_NAME
                   AND P_COL.CONSTRAINT_NAME = P.CONSTRAINT_NAME
                   AND C.r_constraint_name = P.constraint_name
                   AND P.constraint_type IN ('P', 'U')
                   AND UPPER (P.table_name) = UPPER (p_tbl_name)
                   AND C.CONSTRAINT_TYPE = 'R';
    BEGIN
        --FND_FILE.PUT_LINE (FND_FILE.LOG, 'Beginning of the program');
        FND_FILE.PUT_LINE (fnd_file.OUTPUT,
                           'Beginning of the BT purging program');

        fnd_file.put_line (fnd_file.OUTPUT, 'Table Name  : ' || p_table_name);

        --l_rec_count := 0;

        IF (p_mode = 'Extract')
        THEN
            FND_FILE.PUT_LINE (fnd_file.OUTPUT, 'Mode: ' || p_mode);

            BEGIN
                  SELECT meaning, attribute4 WHERE_CLAUSE_1, attribute5 WHERE_CLAUSE_2,
                         attribute6 WHERE_CLAUSE_3, attribute7 WHERE_CLAUSE_4, attribute8 WHERE_CLAUSE_5
                    INTO l_meaning, l_where_clause1, l_where_clause2, l_where_clause3,
                                  l_where_clause4, l_where_clause5
                    FROM fnd_lookup_values
                   WHERE     lookup_type = 'XXDO_STAG_PURG_QUERY_TBL'
                         AND enabled_flag = 'Y'
                         AND UPPER (meaning) = UPPER (p_table_name)
                         AND language = USERENV ('LANG')
                ORDER BY lookup_code ASC;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.OUTPUT,
                           'Error occured  while fetching the WHERE Clause for Table Extract. Error : '
                        || SQLERRM);
            END;

            IF l_where_clause1 IS NOT NULL
            THEN
                p_where_clause   := l_where_clause1;
            END IF;

            IF l_where_clause2 IS NOT NULL
            THEN
                p_where_clause   :=
                    p_where_clause || ' AND ' || l_where_clause2;
            END IF;

            IF l_where_clause3 IS NOT NULL
            THEN
                p_where_clause   :=
                    p_where_clause || ' AND ' || l_where_clause3;
            END IF;

            IF l_where_clause4 IS NOT NULL
            THEN
                p_where_clause   :=
                    p_where_clause || ' AND ' || l_where_clause4;
            END IF;

            IF l_where_clause5 IS NOT NULL
            THEN
                p_where_clause   :=
                    p_where_clause || ' AND ' || l_where_clause5;
            END IF;



            fnd_file.put_line (fnd_file.OUTPUT, 'Calling Spool Program.');
            l_num_request_id   :=
                fnd_request.submit_request ('XXDO',
                                            'XXDO_PURG_TABLE_DATA',
                                            NULL,
                                            NULL,
                                            FALSE,
                                            g_num_request_id,
                                            l_meaning,
                                            p_where_clause,
                                            p_to_email_id);
            COMMIT;


            IF NVL (l_num_request_id, 0) > 0
            THEN
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                    'Spool Program Request ID: ' || l_num_request_id);

                l_wait_for_request   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => l_num_request_id,
                        interval     => 30,
                        max_wait     => 0,
                        phase        => l_phase,
                        status       => l_status,
                        dev_phase    => l_dev_phase,
                        dev_status   => l_dev_status,
                        MESSAGE      => l_message);

                IF    UPPER (l_dev_status) IN ('ERROR', 'TERMINATED')
                   OR UPPER (l_status) IN ('ERROR', 'TERMINATED')
                THEN
                    fnd_file.put_line (
                        fnd_file.OUTPUT,
                           'Spool Program Request ID: '
                        || l_num_request_id
                        || ' completed in status, '
                        || NVL (l_dev_status, l_status));
                ELSE
                    fnd_file.put_line (
                        fnd_file.OUTPUT,
                           'Spool Program Request ID: '
                        || l_num_request_id
                        || ' Completed Successfully.');
                END IF;
            ELSE
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                    'Spool Program not submitted successfully.');
            END IF;
        ELSE
            FOR c_rec_data_rec IN c_rec_data (p_table_name)
            LOOP
                --       fnd_file.put_line (fnd_file.LOG, 'Query id is  ' || c_rec_data.QUERY_ID);
                fnd_file.put_line (
                    fnd_file.OUTPUT,
                    'Started Query id is : ' || c_rec_data_rec.QUERY_ID);

                --ROLLBACK;

                BEGIN
                    IF c_rec_data_rec.WHERE_CLAUSE_1 IS NOT NULL
                    THEN
                        l_where_clause   := c_rec_data_rec.WHERE_CLAUSE_1;
                    END IF;

                    IF c_rec_data_rec.WHERE_CLAUSE_2 IS NOT NULL
                    THEN
                        l_where_clause   :=
                               l_where_clause
                            || ' AND '
                            || c_rec_data_rec.WHERE_CLAUSE_2;
                    END IF;

                    IF c_rec_data_rec.WHERE_CLAUSE_3 IS NOT NULL
                    THEN
                        l_where_clause   :=
                               l_where_clause
                            || ' AND '
                            || c_rec_data_rec.WHERE_CLAUSE_3;
                    END IF;

                    IF c_rec_data_rec.WHERE_CLAUSE_4 IS NOT NULL
                    THEN
                        l_where_clause   :=
                               l_where_clause
                            || ' AND '
                            || c_rec_data_rec.WHERE_CLAUSE_4;
                    END IF;

                    IF c_rec_data_rec.WHERE_CLAUSE_5 IS NOT NULL
                    THEN
                        l_where_clause   :=
                               l_where_clause
                            || ' AND '
                            || c_rec_data_rec.WHERE_CLAUSE_5;
                    END IF;

                    OPEN l_record_set FOR
                           ' select count(*) from '
                        || c_rec_data_rec.STG_TABLE_NAME
                        || ' where '
                        || l_where_clause;

                    FETCH l_record_set INTO l_record_set_count;

                    fnd_file.put_line (
                        fnd_file.OUTPUT,
                           'Select query fetched record count :  '
                        || l_record_set_count);

                    fnd_file.put_line (
                        fnd_file.OUTPUT,
                        'Parent Table :  ' || c_rec_data_rec.STG_TABLE_NAME);


                    IF l_record_set%FOUND AND l_record_set_count > 0
                    THEN
                        l_error_occured      := 1;

                        FOR c_get_child_rec
                            IN c_get_child (c_rec_data_rec.table_name)
                        LOOP
                            l_child_stg_tab_name        := NULL;
                            l_child_stg_arch_tab_name   := NULL;

                            fnd_file.put_line (
                                fnd_file.OUTPUT,
                                   'Parent Table :  '
                                || c_get_child_rec.parent_table
                                || ' Child Table :  '
                                || c_get_child_rec.child_table);

                            SELECT attribute2 child_stg_tab_name, attribute3 child_stg_arch_tab_name
                              INTO l_child_stg_tab_name, l_child_stg_arch_tab_name
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_STAG_PURG_QUERY_TBL'
                                   AND enabled_flag = 'N'
                                   AND language = USERENV ('LANG')
                                   AND UPPER (meaning) =
                                       UPPER (c_get_child_rec.child_table);


                            IF    l_child_stg_tab_name IS NULL
                               OR l_child_stg_arch_tab_name IS NULL
                            THEN
                                IF l_child_stg_tab_name IS NULL
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.OUTPUT,
                                           'Child Table Information is not available in the lookup : '
                                        || l_child_stg_tab_name);
                                END IF;

                                IF l_child_stg_arch_tab_name IS NULL
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.OUTPUT,
                                           'Child Table Archival Information is not available in the lookup : '
                                        || l_child_stg_arch_tab_name);
                                END IF;
                            ELSE
                                BEGIN
                                    l_rec_count   := 0;

                                    OPEN l_record_count FOR
                                           'select count(*) from '
                                        || l_child_stg_tab_name
                                        || ' a , '
                                        || c_rec_data_rec.STG_TABLE_NAME
                                        || ' b  where b.'
                                        || c_get_child_rec.parent_col_name
                                        || ' = a.'
                                        || c_get_child_rec.child_col_name
                                        || ' and b.'
                                        || l_where_clause;

                                    FETCH l_record_count INTO l_rec_count;

                                    IF l_rec_count > 0
                                    THEN
                                        --                              fnd_file.put_line (
                                        --                                 fnd_file.OUTPUT,
                                        --                                    'SQL Query:  insert into '
                                        --                                 || l_child_stg_arch_tab_name
                                        --                                 || '  select a.*, sysdate Date_deleted,  fnd_global.user_id Deleted_by  from '
                                        --                                 || l_child_stg_tab_name
                                        --                                 || ' a , '
                                        --                                 || c_rec_data_rec.STG_TABLE_NAME
                                        --                                 || ' b  where b.'
                                        --                                 || c_get_child_rec.parent_col_name
                                        --                                 || ' = a.'
                                        --                                 || c_get_child_rec.child_col_name
                                        --                                 || ' and b.'
                                        --                                 || l_where_clause);

                                        EXECUTE IMMEDIATE   ' insert into '
                                                         || l_child_stg_arch_tab_name
                                                         || '  select a.*, sysdate Date_deleted,  fnd_global.user_id Deleted_by  from '
                                                         || l_child_stg_tab_name
                                                         || ' a , '
                                                         || c_rec_data_rec.STG_TABLE_NAME
                                                         || ' b  where b.'
                                                         || c_get_child_rec.parent_col_name
                                                         || ' = a.'
                                                         || c_get_child_rec.child_col_name
                                                         || ' and b.'
                                                         || l_where_clause;

                                        --                              fnd_file.put_line (
                                        --                                 fnd_file.OUTPUT,
                                        --                                    'delete from '
                                        --                                 || l_child_stg_tab_name
                                        --                                 || ' where '
                                        --                                 || c_get_child_rec.child_col_name
                                        --                                 || ' in (select '
                                        --                                 || c_get_child_rec.parent_col_name
                                        --                                 || ' from '
                                        --                                 || c_rec_data_rec.STG_TABLE_NAME
                                        --                                 || ' where '
                                        --                                 || l_where_clause
                                        --                                 || ' )');


                                        EXECUTE IMMEDIATE   'delete from '
                                                         || l_child_stg_tab_name
                                                         || ' where '
                                                         || c_get_child_rec.child_col_name
                                                         || ' in (select '
                                                         || c_get_child_rec.parent_col_name
                                                         || ' from '
                                                         || c_rec_data_rec.STG_TABLE_NAME
                                                         || ' where '
                                                         || l_where_clause
                                                         || ' )';

                                        fnd_file.put_line (
                                            fnd_file.OUTPUT,
                                               'Inserted record into table :  '
                                            || l_child_stg_arch_tab_name);

                                        fnd_file.put_line (
                                            fnd_file.OUTPUT,
                                               'Deleted record from table :  '
                                            || l_child_stg_tab_name);

                                        l_error_occured   := 1;
                                    ELSE
                                        fnd_file.put_line (
                                            fnd_file.OUTPUT,
                                               'No data to insert into child table: '
                                            || l_child_stg_arch_tab_name
                                            || ' based on the given condition.');
                                    END IF;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.OUTPUT,
                                               'Error occured while insert or delete. Error : '
                                            || SQLERRM);
                                        l_error_occured   := 0;
                                END;
                            END IF;
                        END LOOP;


                        BEGIN
                            EXECUTE IMMEDIATE   ' insert into '
                                             || c_rec_data_rec.ARCHIVAL_TABLE_NAME
                                             || '  select a.*, sysdate Date_deleted,  fnd_global.user_id Deleted_by  from '
                                             || c_rec_data_rec.STG_TABLE_NAME
                                             || ' a  where '
                                             || l_where_clause;



                            EXECUTE IMMEDIATE   ' delete from '
                                             || c_rec_data_rec.STG_TABLE_NAME
                                             || ' where '
                                             || l_where_clause;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.OUTPUT,
                                       'Error occured while insert or delete. Error : '
                                    || SQLERRM);
                                l_error_occured   := 0;
                        END;


                        IF l_error_occured = 1
                        THEN
                            COMMIT;                 -- Commenting for testing.
                            fnd_file.put_line (
                                fnd_file.OUTPUT,
                                   'Inserted record into table :  '
                                || c_rec_data_rec.ARCHIVAL_TABLE_NAME);

                            fnd_file.put_line (
                                fnd_file.OUTPUT,
                                   'Deleted record from table :  '
                                || c_rec_data_rec.STG_TABLE_NAME);

                            fnd_file.put_line (fnd_file.OUTPUT,
                                               'Commit changes. ');
                        ELSE
                            ROLLBACK;
                            fnd_file.put_line (fnd_file.OUTPUT,
                                               'Rollback changes. ');
                        END IF;

                        l_num_return_value   := 1;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.OUTPUT,
                            'Select query did not returned any value. ');
                        fnd_file.put_line (
                            fnd_file.OUTPUT,
                            'Table :  ' || c_rec_data_rec.STG_TABLE_NAME);
                        fnd_file.put_line (
                            fnd_file.OUTPUT,
                            'Where Clause :  ' || l_where_clause);
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (fnd_file.OUTPUT,
                                           'Error 1: ' || SQLERRM);
                END;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_buf   := SQLERRM;
            p_ret_code    := 2;
            FND_FILE.PUT_LINE (
                FND_FILE.OUTPUT,
                'Unexpected error at generating report : ' || p_error_buf);
    END main;
END XXDO_PURGING_STAGING_TABLE_PKG;
/
