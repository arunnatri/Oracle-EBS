--
-- XXDO_INTF_TBL_CLNUP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INTF_TBL_CLNUP_PKG"
AS
    gv_debug_enable   VARCHAR2 (30) := 'Y';

    /****************************************************************************
    * Procedure/Function Name  :  out
    *
    * Description              :  The purpose of this procedure is to display
    *                             output messages.
    *
    * INPUT Parameters  :
    *
    * OUTPUT Parameters :
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE out (pv_msg VARCHAR2, pn_level NUMBER:= 1000)
    IS
    BEGIN
        IF gv_debug_enable = 'Y'
        THEN
            apps.fnd_file.put_line (apps.fnd_file.output, pv_msg);
            DBMS_OUTPUT.put_line (pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.output,
                                    'Error In msg procedure' || SQLERRM);
    END;

    /****************************************************************************
    * Procedure/Function Name  :  intfc_rec_update
    *
    * Description              :  The purpose of this procedure is to update
    *                             Interface table record with given conditions.
    *
    * INPUT Parameters  : p_action
    *                     p_table
    *                     p_set_col_name1
    *                     p_set_col_value1
    *                     p_set_col_name2
    *                     p_set_col_value2
    *                     p_set_col_name3
    *                     p_set_col_value3
    *                     p_set_col_name4
    *                     p_set_col_value4
    *                     p_set_col_name5
    *                     p_set_col_value5
    *                     p_where_col_name1
    *                     p_where_col_value1
    *                     p_where_col_name2
    *                     p_where_col_value2
    *                     p_where_col_name3
    *                     p_where_col_value3
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE intfc_rec_update (p_reterror OUT VARCHAR2, p_retcode OUT NUMBER, p_action IN VARCHAR2, p_table IN VARCHAR2, p_d_action IN VARCHAR2, p_set_col_name1 IN VARCHAR2, p_set_col_value1 IN VARCHAR2, p_set_col_name2 IN VARCHAR2, p_set_col_value2 IN VARCHAR2, p_set_col_name3 IN VARCHAR2, p_set_col_value3 IN VARCHAR2, p_set_col_name4 IN VARCHAR2, p_set_col_value4 IN VARCHAR2, p_set_col_name5 IN VARCHAR2, p_set_col_value5 IN NUMBER, p_where_col_name1 IN VARCHAR2, p_where_col_value1 IN VARCHAR2, p_where_col_name2 IN VARCHAR2
                                , p_where_col_value2 IN VARCHAR2, p_where_col_name3 IN VARCHAR2, p_where_col_value3 IN VARCHAR2)
    IS
        l_action             VARCHAR2 (10);
        l_table              VARCHAR2 (50);
        l_set_col_name1      VARCHAR2 (50);
        l_set_col_value1     VARCHAR2 (2000);
        l_set_col_name2      VARCHAR2 (50);
        l_set_col_value2     VARCHAR2 (2000);
        l_set_col_name3      VARCHAR2 (50);
        l_set_col_value3     VARCHAR2 (2000);
        l_set_col_name4      VARCHAR2 (50);
        l_set_col_value4     VARCHAR2 (2000);
        l_set_col_name5      VARCHAR2 (50);
        l_set_col_value5     NUMBER;
        l_where_col_name1    VARCHAR2 (50);
        l_where_col_value1   VARCHAR2 (2000);
        l_where_col_name2    VARCHAR2 (50);
        l_where_col_value2   VARCHAR2 (2000);
        l_where_col_name3    VARCHAR2 (50);
        l_where_col_value3   VARCHAR2 (2000);
        l_plsql_block        VARCHAR2 (2000) := NULL;
        l_plsql_block_bkp    VARCHAR2 (2000) := NULL;
        l_reterror           VARCHAR2 (2000) := NULL;
        l_retcode            NUMBER := 0;
        l_reterror_bkp       VARCHAR2 (2000) := NULL;
        l_retcode_bkp        NUMBER := 0;
        l_count              NUMBER := 0;
    BEGIN
        out (
               '*** Interface Table Record Update Program Start at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
        out ('');

        l_action             := p_action;
        l_table              := p_table;
        l_set_col_name1      := p_set_col_name1;
        l_set_col_value1     := p_set_col_value1;
        l_set_col_name2      := p_set_col_name2;
        l_set_col_value2     := p_set_col_value2;
        l_set_col_name3      := p_set_col_name3;
        l_set_col_value3     := p_set_col_value3;
        l_set_col_name4      := p_set_col_name4;
        l_set_col_value4     := p_set_col_value4;
        l_set_col_name5      := p_set_col_name5;
        l_set_col_value5     := p_set_col_value5;
        l_where_col_name1    := p_where_col_name1;
        l_where_col_value1   := p_where_col_value1;
        l_where_col_name2    := p_where_col_name2;
        l_where_col_value2   := p_where_col_value2;
        l_where_col_name3    := p_where_col_name3;
        l_where_col_value3   := p_where_col_value3;


        out ('Action Type                       :: ' || l_action);
        out ('Target Table                      :: ' || l_table);
        out ('');

        IF (l_action = 'UPDATE')
        THEN
            out ('Set Column1 Name                  :: ' || l_set_col_name1);
            out ('Set Column1 Value                 :: ' || l_set_col_value1);

            IF l_set_col_name2 IS NOT NULL
            THEN
                out (
                       'Set Column2 Name                  :: '
                    || l_set_col_name2);
            END IF;

            IF l_set_col_value2 IS NOT NULL
            THEN
                out (
                       'Set Column2 Value                 :: '
                    || l_set_col_value2);
            END IF;

            IF l_set_col_name3 IS NOT NULL
            THEN
                out (
                       'Set Column3 Name                  :: '
                    || l_set_col_name3);
            END IF;

            IF l_set_col_value3 IS NOT NULL
            THEN
                out (
                       'Set Column3 Value                 :: '
                    || l_set_col_value3);
            END IF;

            IF l_set_col_name4 IS NOT NULL
            THEN
                out (
                       'Set Column4 Name                  :: '
                    || l_set_col_name4);
            END IF;

            IF l_set_col_value4 IS NOT NULL
            THEN
                out (
                       'Set Column4 Value                 :: '
                    || l_set_col_value4);
            END IF;

            IF l_set_col_name5 IS NOT NULL
            THEN
                out (
                       'Set Column5 Name                  :: '
                    || l_set_col_name5);
            END IF;

            IF l_set_col_value5 IS NOT NULL
            THEN
                out (
                       'Set Column5 Value                 :: '
                    || l_set_col_value5);
            END IF;

            out ('');
        END IF;

        out ('Where Column1 Name                :: ' || l_where_col_name1);
        out ('Where Column1 Value               :: ' || l_where_col_value1);

        out ('Where Column2 Name                :: ' || l_where_col_name2);
        out ('Where Column2 Value               :: ' || l_where_col_value2);

        out ('Where Column3 Name                :: ' || l_where_col_name3);
        out ('Where Column3 Value               :: ' || l_where_col_value3);

        out ('');

        BEGIN
            IF (l_action = 'UPDATE')
            THEN
                out ('Update process start with the selected criteria...');
                out ('');

                IF (l_set_col_name1 IS NOT NULL)
                THEN
                    BEGIN
                        l_plsql_block   :=
                               'BEGIN UPDATE '
                            || l_table
                            || ' TBL SET TBL.'
                            || l_set_col_name1
                            || ' = :l_set_col_value1'
                            || ' WHERE '
                            || l_where_col_name1
                            || ' = :l_where_col_value1'
                            || ' AND '
                            || l_where_col_name2
                            || ' = :l_where_col_value2'
                            || ' AND '
                            || l_where_col_name3
                            || ' = :l_where_col_value3'
                            || '; END;';

                        EXECUTE IMMEDIATE l_plsql_block
                            USING IN OUT l_set_col_value1, l_where_col_value1, l_where_col_value2,
                                  l_where_col_value3;

                        out (
                               ' Return Code for setting column 1  :: '
                            || l_retcode);
                        l_retcode   := 0;
                        l_reterror   :=
                               l_reterror
                            || 'Interface Table Record Updated setting column 1 value successfully. ';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_retcode   := l_count + 1;
                            l_reterror   :=
                                   l_reterror
                                || 'Interface Table Record Update failed in setting column 1 with exception :: '
                                || SUBSTR (SQLERRM, 1, 399);
                    END;
                END IF;

                IF (l_set_col_name2 IS NOT NULL)
                THEN
                    BEGIN
                        l_plsql_block   :=
                               'BEGIN UPDATE '
                            || l_table
                            || ' TBL SET TBL.'
                            || l_set_col_name2
                            || ' = :l_set_col_value2'
                            || ' WHERE '
                            || l_where_col_name1
                            || ' = :l_where_col_value1'
                            || ' AND '
                            || l_where_col_name2
                            || ' = :l_where_col_value2'
                            || ' AND '
                            || l_where_col_name3
                            || ' = :l_where_col_value3'
                            || '; COMMIT; END;';

                        EXECUTE IMMEDIATE l_plsql_block
                            USING IN OUT l_set_col_value2, l_where_col_value1, l_where_col_value2,
                                  l_where_col_value3;

                        out (
                               ' Return Code for setting column 2  :: '
                            || l_retcode);
                        l_retcode   := 0;
                        l_reterror   :=
                               l_reterror
                            || 'Interface Table Record Updated setting column 2 value successfully. ';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_retcode   := l_count + 1;
                            l_reterror   :=
                                   l_reterror
                                || 'Interface Table Record Update failed in setting column 2 with exception :: '
                                || SUBSTR (SQLERRM, 1, 399);
                    END;
                END IF;

                IF (l_set_col_name3 IS NOT NULL)
                THEN
                    BEGIN
                        l_plsql_block   :=
                               'BEGIN UPDATE '
                            || l_table
                            || ' TBL SET TBL.'
                            || l_set_col_name3
                            || ' = :l_set_col_value3'
                            || ' WHERE '
                            || l_where_col_name1
                            || ' = :l_where_col_value1'
                            || ' AND '
                            || l_where_col_name2
                            || ' = :l_where_col_value2'
                            || ' AND '
                            || l_where_col_name3
                            || ' = :l_where_col_value3'
                            || '; COMMIT; END;';

                        EXECUTE IMMEDIATE l_plsql_block
                            USING IN OUT l_set_col_value3, l_where_col_value1, l_where_col_value2,
                                  l_where_col_value3;

                        out (
                               ' Return Code for setting column 3  :: '
                            || l_retcode);
                        l_retcode   := 0;
                        l_reterror   :=
                               l_reterror
                            || 'Interface Table Record Updated setting column 3 value successfully. ';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_retcode   := l_count + 1;
                            l_reterror   :=
                                   l_reterror
                                || 'Interface Table Record Update failed in setting column 3 with exception :: '
                                || SUBSTR (SQLERRM, 1, 399);
                    END;
                END IF;

                IF (l_set_col_name4 IS NOT NULL)
                THEN
                    BEGIN
                        l_plsql_block   :=
                               'BEGIN UPDATE '
                            || l_table
                            || ' TBL SET TBL.'
                            || l_set_col_name4
                            || ' = TRUNC (TO_DATE (:l_set_col_value4, ''YYYY/MM/DD HH24:MI:SS''))'
                            || ' WHERE '
                            || l_where_col_name1
                            || ' = :l_where_col_value1'
                            || ' AND '
                            || l_where_col_name2
                            || ' = :l_where_col_value2'
                            || ' AND '
                            || l_where_col_name3
                            || ' = :l_where_col_value3'
                            || '; COMMIT; END;';

                        EXECUTE IMMEDIATE l_plsql_block
                            USING IN OUT l_set_col_value4, l_where_col_value1, l_where_col_value2,
                                  l_where_col_value3;

                        out (
                               ' Return Code for setting column 4  :: '
                            || l_retcode);
                        l_retcode   := 0;
                        l_reterror   :=
                               l_reterror
                            || 'Interface Table Record Updated setting column 4 value successfully. ';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_retcode   := l_count + 1;
                            l_reterror   :=
                                   l_reterror
                                || 'Interface Table Record Update failed in setting column 4 with exception :: '
                                || SUBSTR (SQLERRM, 1, 399);
                    END;
                END IF;

                IF (l_set_col_name5 IS NOT NULL)
                THEN
                    BEGIN
                        l_plsql_block   :=
                               'BEGIN UPDATE '
                            || l_table
                            || ' TBL SET TBL.'
                            || l_set_col_name5
                            || ' = :l_set_col_value5'
                            || ' WHERE '
                            || l_where_col_name1
                            || ' = :l_where_col_value1'
                            || ' AND '
                            || l_where_col_name2
                            || ' = :l_where_col_value2'
                            || ' AND '
                            || l_where_col_name3
                            || ' = :l_where_col_value3'
                            || '; COMMIT; END;';

                        EXECUTE IMMEDIATE l_plsql_block
                            USING IN OUT l_set_col_value5, l_where_col_value1, l_where_col_value2,
                                  l_where_col_value3;

                        out (
                               ' Return Code for setting column 5  :: '
                            || l_retcode);
                        l_retcode   := 0;
                        l_reterror   :=
                               l_reterror
                            || 'Interface Table Record Updated setting column 5 value successfully. ';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_retcode   := l_count + 1;
                            l_reterror   :=
                                   l_reterror
                                || 'Interface Table Record Update failed in setting column 5 with exception :: '
                                || SUBSTR (SQLERRM, 1, 399);
                    END;
                END IF;

                COMMIT;

                BEGIN
                    p_retcode    := l_retcode;
                    p_reterror   := l_reterror;

                    IF l_retcode > 0
                    THEN
                        out ('');
                        out (
                               'Interface Table Record Update failed :: '
                            || l_reterror);
                    ELSE
                        out ('');
                        out ('Interface Table Record Updated successfully');
                    END IF;
                END;

                out ('');
                out (
                       '*** Deckers Interface Table Record Update Program End at :: '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                    || ' ***');
            ELSIF (l_action = 'DELETE')
            THEN
                out ('Delete process start with the selected criteria...');
                out ('');

                BEGIN
                    IF (l_table = 'MTL_TRANSACTIONS_INTERFACE')
                    THEN
                        BEGIN
                            l_plsql_block_bkp   :=
                                   'BEGIN INSERT INTO MTL_TRX_INTERFACE_ITC_BKP SELECT * FROM MTL_TRANSACTIONS_INTERFACE WHERE '
                                || l_where_col_name1
                                || ' = :l_where_col_value1'
                                || ' AND '
                                || l_where_col_name2
                                || ' = :l_where_col_value2'
                                || ' AND '
                                || l_where_col_name3
                                || ' = :l_where_col_value3'
                                || '; END;';

                            EXECUTE IMMEDIATE l_plsql_block_bkp
                                USING IN OUT l_where_col_value1, l_where_col_value2, l_where_col_value3;

                            out (
                                   '  => Return Code for taking backup record  :: '
                                || l_retcode_bkp);
                            l_retcode_bkp   := 0;
                            l_reterror_bkp   :=
                                   l_reterror_bkp
                                || 'Backup record has been inserted successfully. ';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_retcode_bkp   := l_count + 1;
                                l_reterror_bkp   :=
                                       l_reterror_bkp
                                    || 'Interface Table Record Backup failed with exception :: '
                                    || SUBSTR (SQLERRM, 1, 399);
                        END;
                    ELSIF (l_table = 'PO_INTERFACE_ERRORS')
                    THEN
                        BEGIN
                            l_plsql_block_bkp   :=
                                   'BEGIN INSERT INTO PO_INTERFACE_ERRORS_ITC_BKP SELECT * FROM PO_INTERFACE_ERRORS WHERE '
                                || l_where_col_name1
                                || ' = :l_where_col_value1'
                                || ' AND '
                                || l_where_col_name2
                                || ' = :l_where_col_value2'
                                || ' AND '
                                || l_where_col_name3
                                || ' = :l_where_col_value3'
                                || '; END;';

                            EXECUTE IMMEDIATE l_plsql_block_bkp
                                USING IN OUT l_where_col_value1, l_where_col_value2, l_where_col_value3;

                            out (
                                   '  => Return Code for taking backup record  :: '
                                || l_retcode_bkp);
                            l_retcode_bkp   := 0;
                            l_reterror_bkp   :=
                                   l_reterror_bkp
                                || 'Backup record has been inserted successfully. ';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_retcode_bkp   := l_count + 1;
                                l_reterror_bkp   :=
                                       l_reterror_bkp
                                    || 'Interface Table Record Backup failed with exception :: '
                                    || SUBSTR (SQLERRM, 1, 399);
                        END;
                    ELSIF (l_table = 'RCV_HEADERS_INTERFACE')
                    THEN
                        BEGIN
                            l_plsql_block_bkp   :=
                                   'BEGIN INSERT INTO RCV_HEADERS_INTERFACE_ITC_BKP SELECT * FROM RCV_HEADERS_INTERFACE WHERE '
                                || l_where_col_name1
                                || ' = :l_where_col_value1'
                                || ' AND '
                                || l_where_col_name2
                                || ' = :l_where_col_value2'
                                || ' AND '
                                || l_where_col_name3
                                || ' = :l_where_col_value3'
                                || '; END;';

                            EXECUTE IMMEDIATE l_plsql_block_bkp
                                USING IN OUT l_where_col_value1, l_where_col_value2, l_where_col_value3;

                            out (
                                   '  => Return Code for taking backup record  :: '
                                || l_retcode_bkp);
                            l_retcode_bkp   := 0;
                            l_reterror_bkp   :=
                                   l_reterror_bkp
                                || 'Backup record has been inserted successfully. ';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_retcode_bkp   := l_count + 1;
                                l_reterror_bkp   :=
                                       l_reterror_bkp
                                    || 'Interface Table Record Backup failed with exception :: '
                                    || SUBSTR (SQLERRM, 1, 399);
                        END;
                    ELSIF (l_table = 'RCV_TRANSACTIONS_INTERFACE')
                    THEN
                        BEGIN
                            l_plsql_block_bkp   :=
                                   'BEGIN INSERT INTO RCV_TRX_INTERFACE_ITC_BKP SELECT * FROM RCV_TRANSACTIONS_INTERFACE WHERE '
                                || l_where_col_name1
                                || ' = :l_where_col_value1'
                                || ' AND '
                                || l_where_col_name2
                                || ' = :l_where_col_value2'
                                || ' AND '
                                || l_where_col_name3
                                || ' = :l_where_col_value3'
                                || '; END;';

                            EXECUTE IMMEDIATE l_plsql_block_bkp
                                USING IN OUT l_where_col_value1, l_where_col_value2, l_where_col_value3;

                            out (
                                   '  => Return Code for taking backup record  :: '
                                || l_retcode_bkp);
                            l_retcode_bkp   := 0;
                            l_reterror_bkp   :=
                                   l_reterror_bkp
                                || 'Backup record has been inserted successfully. ';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_retcode_bkp   := l_count + 1;
                                l_reterror_bkp   :=
                                       l_reterror_bkp
                                    || 'Interface Table Record Backup failed with exception :: '
                                    || SUBSTR (SQLERRM, 1, 399);
                        END;
                    END IF;

                    COMMIT;
                END;

                IF l_retcode_bkp = 0
                THEN
                    BEGIN
                        l_plsql_block   :=
                               'BEGIN DELETE FROM '
                            || l_table
                            || ' WHERE '
                            || l_where_col_name1
                            || ' = :l_where_col_value1'
                            || ' AND '
                            || l_where_col_name2
                            || ' = :l_where_col_value2'
                            || ' AND '
                            || l_where_col_name3
                            || ' = :l_where_col_value3'
                            || '; END;';

                        EXECUTE IMMEDIATE l_plsql_block
                            USING IN OUT l_where_col_value1, l_where_col_value2, l_where_col_value3;

                        out (
                               '  => Return Code for deleting record  :: '
                            || l_retcode);
                        l_retcode   := 0;
                        l_reterror   :=
                               l_reterror
                            || 'Interface Table Record Deleted successfully. ';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_retcode   := l_count + 1;
                            l_reterror   :=
                                   l_reterror
                                || 'Interface Table Record Delete failed with exception :: '
                                || SUBSTR (SQLERRM, 1, 399);
                    END;
                END IF;

                COMMIT;

                BEGIN
                    p_retcode    := l_retcode;
                    p_reterror   := l_reterror;

                    IF l_retcode > 0
                    THEN
                        out ('');
                        out (
                               'Interface Table Record Delete failed :: '
                            || l_reterror);
                    ELSE
                        out ('');
                        out ('Interface Table Record Deleted successfully');
                    END IF;
                END;

                out ('');
                out (
                       '*** Deckers Interface Table Record Update Program End at :: '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                    || ' ***');
            END IF;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode    := 1;
            p_reterror   := SUBSTR (SQLERRM, 1, 100);
            out ('');
            out (
                   '*** Deckers Interface Table Record Update Program failed with exception :: '
                || p_reterror);
    END;

    /****************************************************************************
    * Procedure/Function Name  :  p2p_asn_reprocess
    *
    * Description              :  The purpose of this procedure is to re-process
    *                             ANSs based on the inputs provided.
    *
    * INPUT Parameters  : p_rhi_hdr_intfc_id
    *                     p_rhi_hdr_intfc_grp_id
    *                     p_rhi_hdr_intfc_shpmnt_num
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE p2p_asn_reprocess (
        p_rhi_hdr_intfc_id           IN     NUMBER,
        p_rhi_hdr_intfc_grp_id       IN     NUMBER,
        p_rhi_hdr_intfc_shpmnt_num   IN     VARCHAR2,
        p_reterror                      OUT VARCHAR2,
        p_retcode                       OUT NUMBER)
    IS
        l_poi_insert_flag   NUMBER := 0;
    BEGIN
        IF ((p_rhi_hdr_intfc_id IS NULL) AND (p_rhi_hdr_intfc_grp_id IS NULL) AND (p_rhi_hdr_intfc_shpmnt_num IS NULL))
        THEN
            out (
                'Please select atleast one input for RHI and resubmit the program...');
        ELSE
            BEGIN
                BEGIN
                    INSERT INTO po_interface_errors_itc_bkp
                        (SELECT *
                           FROM po_interface_errors
                          WHERE interface_line_id IN
                                    (SELECT interface_transaction_id
                                       FROM rcv_transactions_interface rti
                                      WHERE header_interface_id IN
                                                (SELECT header_interface_id
                                                   FROM rcv_headers_interface rhi
                                                  WHERE     asn_type = 'ASN'
                                                        AND NVL (
                                                                rhi.header_interface_id,
                                                                1) =
                                                            NVL (
                                                                p_rhi_hdr_intfc_id,
                                                                NVL (
                                                                    rhi.header_interface_id,
                                                                    1))
                                                        AND NVL (
                                                                rhi.GROUP_ID,
                                                                1) =
                                                            NVL (
                                                                p_rhi_hdr_intfc_grp_id,
                                                                NVL (
                                                                    rhi.GROUP_ID,
                                                                    1))
                                                        AND NVL (
                                                                rhi.shipment_num,
                                                                'Y') =
                                                            NVL (
                                                                p_rhi_hdr_intfc_shpmnt_num,
                                                                NVL (
                                                                    rhi.shipment_num,
                                                                    'Y')))));

                    out (
                           '    => Successfully Inserted '
                        || SQL%ROWCOUNT
                        || ' record(s) into PO_INTERFACE_ERRORS_ITC_BKP backup Table ');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_retcode           := 1;
                        p_reterror          := SUBSTR (SQLERRM, 1, 200);
                        l_poi_insert_flag   := 1;
                        out (
                            '    => Exception while inserting records into po_interface_errors_itc_bkp table, Exiting the program...');
                        out ('');
                END;

                IF l_poi_insert_flag = 0
                THEN
                    BEGIN
                        DELETE FROM
                            po_interface_errors
                              WHERE interface_line_id IN
                                        (SELECT interface_transaction_id
                                           FROM rcv_transactions_interface rti
                                          WHERE header_interface_id IN
                                                    (SELECT header_interface_id
                                                       FROM rcv_headers_interface rhi
                                                      WHERE     asn_type =
                                                                'ASN'
                                                            AND NVL (
                                                                    rhi.header_interface_id,
                                                                    1) =
                                                                NVL (
                                                                    p_rhi_hdr_intfc_id,
                                                                    NVL (
                                                                        rhi.header_interface_id,
                                                                        1))
                                                            AND NVL (
                                                                    rhi.GROUP_ID,
                                                                    1) =
                                                                NVL (
                                                                    p_rhi_hdr_intfc_grp_id,
                                                                    NVL (
                                                                        rhi.GROUP_ID,
                                                                        1))
                                                            AND NVL (
                                                                    rhi.shipment_num,
                                                                    'Y') =
                                                                NVL (
                                                                    p_rhi_hdr_intfc_shpmnt_num,
                                                                    NVL (
                                                                        rhi.shipment_num,
                                                                        'Y'))));

                        out (
                               '    => Successfully Deleted '
                            || SQL%ROWCOUNT
                            || ' record(s) from PO_INTERFACE_ERRORS Table ');

                        UPDATE rcv_transactions_interface rti
                           SET processing_status_code = 'PENDING', transaction_status_code = 'PENDING'
                         WHERE     header_interface_id IN
                                       (SELECT header_interface_id
                                          FROM rcv_headers_interface rhi
                                         WHERE     asn_type = 'ASN'
                                               AND NVL (
                                                       rhi.header_interface_id,
                                                       1) =
                                                   NVL (
                                                       p_rhi_hdr_intfc_id,
                                                       NVL (
                                                           rhi.header_interface_id,
                                                           1))
                                               AND NVL (rhi.GROUP_ID, 1) =
                                                   NVL (
                                                       p_rhi_hdr_intfc_grp_id,
                                                       NVL (rhi.GROUP_ID, 1))
                                               AND NVL (rhi.shipment_num,
                                                        'Y') =
                                                   NVL (
                                                       p_rhi_hdr_intfc_shpmnt_num,
                                                       NVL (rhi.shipment_num,
                                                            'Y')))
                               AND processing_status_code IN
                                       ('ERROR', 'COMPLETED');

                        out (
                               '    => Successfully Updated '
                            || SQL%ROWCOUNT
                            || ' record(s) on RCV_TRANSACTIONS_INTERFACE Table ');

                        UPDATE rcv_headers_interface rhi
                           SET processing_status_code   = 'PENDING'
                         WHERE     asn_type = 'ASN'
                               AND NVL (rhi.header_interface_id, 1) =
                                   NVL (p_rhi_hdr_intfc_id,
                                        NVL (rhi.header_interface_id, 1))
                               AND NVL (rhi.GROUP_ID, 1) =
                                   NVL (p_rhi_hdr_intfc_grp_id,
                                        NVL (rhi.GROUP_ID, 1))
                               AND NVL (rhi.shipment_num, 'Y') =
                                   NVL (p_rhi_hdr_intfc_shpmnt_num,
                                        NVL (rhi.shipment_num, 'Y'))
                               AND processing_status_code IN
                                       ('SUCCESS', 'ERROR');

                        out (
                               '    => Successfully Updated '
                            || SQL%ROWCOUNT
                            || ' record(s) on RCV_HEADERS_INTERFACE Table ');

                        COMMIT;
                    END;
                END IF;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode    := 1;
            p_reterror   := SUBSTR (SQLERRM, 1, 200);
    END;

    /****************************************************************************
    * Procedure/Function Name  :  p2p_asn_reextract
    *
    * Description              :  The purpose of this procedure is to re-extract
    *                             ASNs for LPN\NON-LPN Warehouse.
    *
    * INPUT Parameters  : p_rhi_hdr_intfc_shpmnt_num
    *                     p_rti_intfc_trx_shpmnt_num
    *                     p_container_id
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE p2p_asn_reextract (
        p_rhi_hdr_intfc_shpmnt_num   IN     VARCHAR2,
        p_rti_intfc_trx_shpmnt_num   IN     VARCHAR2,
        p_container_id               IN     NUMBER,
        p_reterror                      OUT VARCHAR2,
        p_retcode                       OUT NUMBER)
    IS
        p_group_id          NUMBER := 0;
        p_ret_stat          VARCHAR2 (1) := NULL;
        p_error_text        VARCHAR2 (2000) := NULL;

        CURSOR cur_reextract_asn IS
            SELECT DISTINCT order_id, shipment_id, c.container_id,
                            extract_status, organization_id, po_header_id
              FROM custom.do_items i, custom.do_containers c, po_line_locations_all plla
             WHERE     i.line_location_id = plla.line_location_id
                   AND i.container_id = c.container_id
                   AND c.extract_status = 'Never Extracted'
                   AND c.container_id IN (p_container_id)
                   AND plla.closed_code IN ('CLOSED FOR INVOICE', 'OPEN');

        l_poi_insert_flag   NUMBER := 0;
        l_lpn_type          NUMBER := 0;
    BEGIN
        IF ((p_rhi_hdr_intfc_shpmnt_num IS NULL) OR (p_rti_intfc_trx_shpmnt_num IS NULL) OR (p_container_id IS NULL))
        THEN
            out (
                '"RHI Shipment Number", "RTI Shipment Number" and "Container ID" are mandatory for this process. Please resubmit the program with mandatory inputs...');
        ELSE
            BEGIN
                BEGIN
                    INSERT INTO po_interface_errors_itc_bkp
                        (SELECT *
                           FROM po_interface_errors
                          WHERE interface_line_id IN
                                    (SELECT interface_transaction_id
                                       FROM rcv_transactions_interface rti
                                      WHERE rti.shipment_num IN
                                                (p_rti_intfc_trx_shpmnt_num)));

                    out (
                           '    => Successfully Inserted '
                        || SQL%ROWCOUNT
                        || ' record(s) into PO_INTERFACE_ERRORS_ITC_BKP backup Table ');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_retcode           := 1;
                        p_reterror          := SUBSTR (SQLERRM, 1, 200);
                        l_poi_insert_flag   := 1;
                        out (
                            '    => Exception while inserting records into po_interface_errors_itc_bkp table, Exiting the program...');
                        out ('');
                END;

                IF l_poi_insert_flag = 0
                THEN
                    BEGIN
                        DELETE FROM
                            po_interface_errors
                              WHERE interface_line_id IN
                                        (SELECT interface_transaction_id
                                           FROM rcv_transactions_interface rti
                                          WHERE rti.shipment_num IN
                                                    (p_rti_intfc_trx_shpmnt_num));

                        out (
                               '    => Successfully Deleted '
                            || SQL%ROWCOUNT
                            || ' record(s) from PO_INTERFACE_ERRORS Table ');
                    END;

                    BEGIN
                        INSERT INTO rcv_shipment_headers_itc_bkp
                            (SELECT *
                               FROM rcv_shipment_headers rsh
                              WHERE rsh.shipment_num IN
                                        (p_rhi_hdr_intfc_shpmnt_num));

                        out (
                               '    => Successfully Inserted '
                            || SQL%ROWCOUNT
                            || ' record(s) into RCV_SHIPMENT_HEADERS_ITC_BKP backup Table ');

                        DELETE FROM
                            rcv_shipment_headers
                              WHERE shipment_num IN
                                        (p_rhi_hdr_intfc_shpmnt_num);

                        out (
                               '    => Successfully Deleted '
                            || SQL%ROWCOUNT
                            || ' record(s) from RCV_SHIPMENT_HEADERS Table ');
                    END;

                    BEGIN
                        INSERT INTO wms_lpns_itc_bkp
                            (SELECT *
                               FROM apps.wms_license_plate_numbers
                              WHERE license_plate_number IN
                                        (SELECT barcode_label
                                           FROM rcv_transactions_interface
                                          WHERE shipment_num IN
                                                    (p_rti_intfc_trx_shpmnt_num)));

                        out (
                               '    => Successfully Inserted '
                            || SQL%ROWCOUNT
                            || ' record(s) into WMS_LPNS_ITC_BKP backup Table ');

                        DELETE FROM
                            apps.wms_license_plate_numbers
                              WHERE license_plate_number IN
                                        (SELECT barcode_label
                                           FROM rcv_transactions_interface
                                          WHERE shipment_num IN
                                                    (p_rti_intfc_trx_shpmnt_num));

                        out (
                               '    => Successfully Deleted '
                            || SQL%ROWCOUNT
                            || ' record(s) from WMS_LICENSE_PLATE_NUMBERS Table ');
                    END;

                    BEGIN
                        INSERT INTO rcv_headers_interface_itc_bkp
                            (SELECT *
                               FROM rcv_headers_interface
                              WHERE shipment_num IN
                                        (p_rhi_hdr_intfc_shpmnt_num));

                        out (
                               '    => Successfully Inserted '
                            || SQL%ROWCOUNT
                            || ' record(s) into RCV_HEADERS_INTERFACE_ITC_BKP backup Table ');

                        DELETE FROM
                            rcv_headers_interface
                              WHERE shipment_num IN
                                        (p_rhi_hdr_intfc_shpmnt_num);

                        out (
                               '    => Successfully Deleted '
                            || SQL%ROWCOUNT
                            || ' record(s) from RCV_HEADERS_INTERFACE Table ');
                    END;

                    BEGIN
                        INSERT INTO rcv_trx_interface_itc_bkp
                            (SELECT *
                               FROM rcv_transactions_interface
                              WHERE shipment_num IN
                                        (p_rti_intfc_trx_shpmnt_num));

                        out (
                               '    => Successfully Inserted '
                            || SQL%ROWCOUNT
                            || ' record(s) into RCV_TRX_INTERFACE_ITC_BKP backup Table ');

                        DELETE FROM
                            rcv_transactions_interface
                              WHERE shipment_num IN
                                        (p_rti_intfc_trx_shpmnt_num);

                        out (
                               '    => Successfully Deleted '
                            || SQL%ROWCOUNT
                            || ' record(s) from RCV_TRANSACTIONS_INTERFACE Table ');
                    END;

                    BEGIN
                        UPDATE apps.do_items
                           SET atr_number   = NULL
                         WHERE container_id IN (p_container_id);

                        out (
                               '    => Successfully Updated '
                            || SQL%ROWCOUNT
                            || ' record(s) on DO_ITEMS Table ');

                        UPDATE apps.do_containers
                           SET extract_status   = 'Never Extracted'
                         WHERE container_id IN (p_container_id);

                        out (
                               '    => Successfully Updated '
                            || SQL%ROWCOUNT
                            || ' record(s) on DO_CONTAINERS Table ');
                    END;

                    COMMIT;


                    BEGIN
                        apps.do_apps_initialize (1876, 51395, 201); --Deckers Purchsing Super USer -Americas : User = BATCH.P2P

                        FOR rec_cur_reextract_asn IN cur_reextract_asn
                        LOOP
                            BEGIN
                                SELECT COUNT (meaning)
                                  INTO l_lpn_type
                                  FROM apps.fnd_lookup_values_vl flv
                                 WHERE     flv.lookup_type =
                                           'XXDO_ASN_RECEIPT_EXT_ORG'
                                       AND flv.tag = 'LPN'
                                       AND SYSDATE BETWEEN NVL (
                                                               flv.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               flv.end_date_active,
                                                               SYSDATE)
                                       AND flv.enabled_flag = 'Y'
                                       AND flv.lookup_code =
                                           (SELECT organization_code
                                              FROM apps.mtl_parameters
                                             WHERE organization_id =
                                                   rec_cur_reextract_asn.organization_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    p_retcode    := 1;
                                    p_reterror   := SUBSTR (SQLERRM, 1, 200);
                                    l_lpn_type   := 0;
                                    out (
                                        '    => Exception while fetching LPN Type for the Organization...');
                                    out ('');
                            END;

                            IF (l_lpn_type > 0)
                            THEN
                                BEGIN
                                    apps.do_wms_lpn_receiving_utils_pub.interface_asn_container (
                                        p_container_id              =>
                                            rec_cur_reextract_asn.container_id,
                                        p_po_header_id              =>
                                            rec_cur_reextract_asn.po_header_id,
                                        p_run_rcv_trans_processor   => 'Y',
                                        x_group_id                  =>
                                            p_group_id,
                                        x_ret_stat                  =>
                                            p_ret_stat,
                                        x_error_text                =>
                                            p_error_text);

                                    out (
                                           'Container :'
                                        || rec_cur_reextract_asn.container_id
                                        || 'Status'
                                        || p_ret_stat
                                        || ' Error : '
                                        || p_error_text);
                                END;

                                COMMIT;
                            ELSIF (l_lpn_type = 0)
                            THEN
                                BEGIN
                                    apps.do_wms_receiving_utils_pub.interface_asn_container (
                                        p_container_id              =>
                                            rec_cur_reextract_asn.container_id,
                                        p_po_header_id              =>
                                            rec_cur_reextract_asn.po_header_id,
                                        p_run_rcv_trans_processor   => 'Y',
                                        p_receipt_date              => SYSDATE,
                                        x_group_id                  =>
                                            p_group_id,
                                        x_ret_stat                  =>
                                            p_ret_stat,
                                        x_error_text                =>
                                            p_error_text);
                                    out (
                                           'Container :'
                                        || rec_cur_reextract_asn.container_id
                                        || 'Status'
                                        || p_ret_stat
                                        || ' Error : '
                                        || p_error_text);
                                END;

                                COMMIT;
                            END IF;
                        END LOOP;
                    END;
                END IF;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode    := 1;
            p_reterror   := SUBSTR (SQLERRM, 1, 200);
    END;

    /****************************************************************************
    * Procedure/Function Name  :  p2p_asn_no_open_shipments
    *
    * Description              :  The purpose of this procedure is to reset
    *                             flags for ASNs which has no open shipments.
    *
    * INPUT Parameters  : p_rhi_hdr_intfc_grp_id
    *                     p_rti_intfc_trx_grp_id
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE p2p_asn_no_open_shipments (p_rhi_hdr_intfc_grp_id IN NUMBER, p_rti_intfc_trx_grp_id IN NUMBER, p_reterror OUT VARCHAR2
                                         , p_retcode OUT NUMBER)
    IS
        l_status   NUMBER := 0;
    BEGIN
        IF ((p_rhi_hdr_intfc_grp_id IS NULL) OR (p_rti_intfc_trx_grp_id IS NULL))
        THEN
            out (
                '"RHI Group ID" and "RTI Group ID" are mandatory for this process. Please resubmit the program with mandatory inputs...');
        ELSE
            BEGIN
                BEGIN
                    SELECT COUNT (*)
                      INTO l_status
                      FROM apps.po_line_locations_all
                     WHERE     line_location_id IN
                                   (SELECT po_line_location_id
                                      FROM rcv_transactions_interface rti
                                     WHERE GROUP_ID IN
                                               (p_rti_intfc_trx_grp_id))
                           AND closed_code IN ('CLOSED FOR INVOICE', 'OPEN');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        out (
                            'Exception while fetching PO Line Location Status');
                END;

                IF l_status > 0
                THEN
                    INSERT INTO po_interface_errors_itc_bkp
                        (SELECT *
                           FROM po_interface_errors
                          WHERE interface_line_id IN
                                    (SELECT interface_transaction_id
                                       FROM rcv_transactions_interface rti
                                      WHERE GROUP_ID IN
                                                (p_rti_intfc_trx_grp_id)));

                    out (
                           '    => Successfully Inserted '
                        || SQL%ROWCOUNT
                        || ' record(s) into PO_INTERFACE_ERRORS_ITC_BKP backup Table ');

                    DELETE FROM
                        po_interface_errors
                          WHERE interface_line_id IN
                                    (SELECT interface_transaction_id
                                       FROM rcv_transactions_interface rti
                                      WHERE GROUP_ID IN
                                                (p_rti_intfc_trx_grp_id));

                    out (
                           '    => Successfully Deleted '
                        || SQL%ROWCOUNT
                        || ' record(s) from PO_INTERFACE_ERRORS Table ');

                    UPDATE rcv_transactions_interface rti
                       SET processing_status_code = 'PENDING', transaction_status_code = 'PENDING'
                     WHERE     GROUP_ID IN (p_rti_intfc_trx_grp_id)
                           AND processing_status_code IN
                                   ('ERROR', 'COMPLETED');

                    out (
                           '    => Successfully Updated '
                        || SQL%ROWCOUNT
                        || ' record(s) on RCV_TRANSACTIONS_INTERFACE Table ');

                    UPDATE rcv_headers_interface rhi
                       SET processing_status_code   = 'PENDING'
                     WHERE GROUP_ID IN (p_rhi_hdr_intfc_grp_id);

                    out (
                           '    => Successfully Updated '
                        || SQL%ROWCOUNT
                        || ' record(s) on RCV_HEADERS_INTERFACE Table ');

                    COMMIT;
                ELSE
                    out (
                        'PO Line Location Status not in "OPEN" or "CLOSED FOR INVOICE"');
                END IF;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode    := 1;
            p_reterror   := SUBSTR (SQLERRM, 1, 200);
    END;

    /****************************************************************************
    * Procedure/Function Name  :  p2p_asn_shipment_exists
    *
    * Description              :  The purpose of this procedure is to reset
    *                             flags for ASNs which shipment already exist.
    *
    * INPUT Parameters  : p_rhi_hdr_intfc_shpmnt_num
    *                     p_rti_intfc_trx_shpmnt_num
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE p2p_asn_shipment_exists (p_rhi_hdr_intfc_shpmnt_num IN VARCHAR2, p_rti_intfc_trx_shpmnt_num IN VARCHAR2, p_reterror OUT VARCHAR2
                                       , p_retcode OUT NUMBER)
    IS
        l_count    NUMBER := 0;
        l_count1   NUMBER := 0;
    BEGIN
        IF ((p_rhi_hdr_intfc_shpmnt_num IS NULL) OR (p_rti_intfc_trx_shpmnt_num IS NULL))
        THEN
            out (
                '"RHI Shipment Number" and "RTI Shipment Number" are mandatory for this process. Please resubmit the program with mandatory inputs...');
        ELSE
            BEGIN
                BEGIN
                    SELECT COUNT (*)
                      INTO l_count
                      FROM rcv_shipment_headers
                     WHERE shipment_num IN (p_rhi_hdr_intfc_shpmnt_num);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        out (
                            'Exception while fetching PO Line Location Status');
                END;

                BEGIN
                    SELECT COUNT (*)
                      INTO l_count1
                      FROM apps.rcv_shipment_lines
                     WHERE shipment_header_id IN
                               (SELECT shipment_header_id
                                  FROM rcv_shipment_headers rsh
                                 WHERE shipment_num IN
                                           (p_rhi_hdr_intfc_shpmnt_num));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        out (
                            'Exception while fetching PO Line Location Status');
                END;

                IF (l_count > 0 AND l_count1 = 0)
                THEN
                    INSERT INTO rcv_shipment_headers_itc_bkp
                        (SELECT *
                           FROM rcv_shipment_headers
                          WHERE shipment_num IN (p_rhi_hdr_intfc_shpmnt_num));

                    out (
                           '    => Successfully Inserted '
                        || SQL%ROWCOUNT
                        || ' record(s) into RCV_SHIPMENT_HEADERS_ITC_BKP backup Table ');

                    DELETE FROM rcv_shipment_headers
                          WHERE shipment_num IN (p_rhi_hdr_intfc_shpmnt_num);

                    out (
                           '    => Successfully Deleted '
                        || SQL%ROWCOUNT
                        || ' record(s) from RCV_SHIPMENT_HEADERS Table ');

                    INSERT INTO po_interface_errors_itc_bkp
                        (SELECT *
                           FROM po_interface_errors
                          WHERE interface_line_id IN
                                    (SELECT interface_transaction_id
                                       FROM rcv_transactions_interface rti
                                      WHERE rti.shipment_num IN
                                                (p_rti_intfc_trx_shpmnt_num)));

                    out (
                           '    => Successfully Inserted '
                        || SQL%ROWCOUNT
                        || ' record(s) into PO_INTERFACE_ERRORS_ITC_BKP backup Table ');

                    DELETE FROM
                        po_interface_errors
                          WHERE interface_line_id IN
                                    (SELECT interface_transaction_id
                                       FROM rcv_transactions_interface rti
                                      WHERE rti.shipment_num IN
                                                (p_rti_intfc_trx_shpmnt_num));

                    out (
                           '    => Successfully Deleted '
                        || SQL%ROWCOUNT
                        || ' record(s) from PO_INTERFACE_ERRORS Table ');

                    UPDATE rcv_transactions_interface rti
                       SET processing_status_code = 'PENDING', transaction_status_code = 'PENDING', req_distribution_id = NULL,
                           po_distribution_id = NULL, document_shipment_line_num = NULL, shipment_header_id = NULL,
                           shipment_line_id = NULL, po_revision_num = NULL
                     WHERE     shipment_num IN (p_rti_intfc_trx_shpmnt_num)
                           AND processing_status_code IN
                                   ('ERROR', 'COMPLETED');

                    out (
                           '    => Successfully Updated '
                        || SQL%ROWCOUNT
                        || ' record(s) on RCV_TRANSACTIONS_INTERFACE Table ');

                    UPDATE rcv_headers_interface rhi
                       SET processing_status_code = 'PENDING', receipt_header_id = NULL, receipt_num = NULL
                     WHERE     shipment_num IN (p_rhi_hdr_intfc_shpmnt_num)
                           AND processing_status_code IN ('SUCCESS', 'ERROR');

                    out (
                           '    => Successfully Updated '
                        || SQL%ROWCOUNT
                        || ' record(s) on RCV_HEADERS_INTERFACE Table ');

                    COMMIT;
                ELSIF (l_count = 0 AND l_count1 = 0)
                THEN
                    out (
                        'Shipment Header Details does not exists for the Shipment. Please check...');
                ELSE
                    out (
                        'Shipment Line Details exists for the Shipment along with Shipment Header. Please check...');
                END IF;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode    := 1;
            p_reterror   := SUBSTR (SQLERRM, 1, 200);
    END;

    /****************************************************************************
    * Procedure/Function Name  :  wms_mtl_trx_intfc_clnup
    *
    * Description              :  The purpose of this procedure is to clean up
    *                             MTL_TRANSACTIONS_INTERFACE table.
    *
    * INPUT Parameters  : p_mtl_trx_hdr_id
    *                     p_mtl_trx_intfc_id
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/
    PROCEDURE wms_mtl_trx_intfc_clnup (p_mtl_trx_hdr_id IN NUMBER, p_mtl_trx_intfc_id IN NUMBER, p_reterror OUT VARCHAR2
                                       , p_retcode OUT NUMBER)
    IS
        /* Cursor to pull all reservation Locator and sub inventory*/

        CURSOR cur_mti_dtl IS
            SELECT mtr.subinventory_code res_sub_inv, mtr.locator_id res_locator_id, mtr.reservation_quantity,
                   mtr.creation_date, mti.subinventory_code mti_sub_inv, mti.locator_id mti_locator_id,
                   mti.transaction_quantity mti_qty, mmt.transaction_id, mmt.subinventory_code mmt_sub_inv,
                   mmt.locator_id mmt_locator_id, mmt.transaction_quantity, mti.source_line_id,
                   mti.transaction_interface_id
              FROM mtl_transactions_interface mti, mtl_reservations mtr, mtl_material_transactions mmt
             WHERE     mti.organization_id IN (107, 108, 109)
                   AND mti.error_explanation IN
                           ('An error occurred while relieving reservations.', 'Negative balances not allowed')
                   AND mtr.demand_source_line_id = mti.source_line_id
                   AND mmt.trx_source_line_id = mti.source_line_id
                   AND mmt.locator_id = mtr.locator_id
                   AND mmt.transaction_quantity = mtr.reservation_quantity
                   AND mmt.transfer_lpn_id = mti.content_lpn_id
                   AND mtr.reservation_quantity =
                       ABS (mti.transaction_quantity)
                   AND mti.transaction_interface_id =
                       NVL (p_mtl_trx_intfc_id, mti.transaction_interface_id)
                   AND mti.transaction_header_id =
                       NVL (p_mtl_trx_hdr_id, mti.transaction_header_id)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     1 = 1
                                   AND wdd.source_line_id =
                                       mti.source_line_id
                                   AND wdd.released_status != 'C')
            UNION
            SELECT mtr.subinventory_code res_sub_inv, mtr.locator_id res_locator_id, mtr.reservation_quantity,
                   mtr.creation_date, mti.subinventory_code mti_sub_inv, mti.locator_id mti_locator_id,
                   mti.transaction_quantity mti_qty, mmt.transaction_id, mmt.subinventory_code mmt_sub_inv,
                   mmt.locator_id mmt_locator_id, mmt.transaction_quantity, mti.source_line_id,
                   mti.transaction_interface_id
              FROM mtl_transactions_interface mti, mtl_reservations mtr, mtl_material_transactions mmt
             WHERE     mti.organization_id IN (107, 108, 109)
                   AND mti.error_explanation IN
                           ('An error occurred while relieving reservations.', 'Negative balances not allowed')
                   AND mtr.demand_source_line_id = mti.source_line_id
                   AND mtr.reservation_quantity =
                       ABS (mti.transaction_quantity)
                   AND mmt.trx_source_line_id = mti.source_line_id
                   AND mmt.transfer_lpn_id = mti.content_lpn_id
                   AND mmt.transaction_quantity = mtr.reservation_quantity
                   AND mti.transaction_interface_id =
                       NVL (p_mtl_trx_intfc_id, mti.transaction_interface_id)
                   AND mti.transaction_header_id =
                       NVL (p_mtl_trx_hdr_id, mti.transaction_header_id)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     1 = 1
                                   AND wdd.source_line_id =
                                       mti.source_line_id
                                   AND wdd.released_status != 'C');

        l_count   NUMBER := 0;
    BEGIN
        -- Open cursor and fetch records
        FOR rec_mti_dtl IN cur_mti_dtl
        LOOP
            -- Update MTL records with Reservation locator ID and Sub Inventory
            UPDATE mtl_transactions_interface mti
               SET locator_id = rec_mti_dtl.res_locator_id, mti.subinventory_code = rec_mti_dtl.res_sub_inv, process_flag = 1,
                   lock_flag = 2, transaction_mode = 3, ERROR_CODE = NULL
             WHERE mti.transaction_interface_id =
                   rec_mti_dtl.transaction_interface_id;

            l_count   := l_count + 1;
        END LOOP;

        out (
               '  => Completed Successfully - Locator column update :: '
            || l_count);
        COMMIT;

        --Insert Records Before Delete
        INSERT INTO xxdo_mtl_trans_int_backup
            (SELECT *
               FROM mtl_transactions_interface
              WHERE     organization_id IN (107, 108, 109)                --US
                    AND process_flag = 3
                    AND transaction_quantity = 0);

        out (
               '  => Successfully Inserted zero qty records in XXDO_MTL_TRANS_INT_BACKUP- Record Count :: '
            || SQL%ROWCOUNT);

        -- Delete all transaction qty zero records

        DELETE FROM
            apps.mtl_transactions_interface
              WHERE     organization_id IN (107, 108, 109)                --US
                    AND process_flag = 3
                    AND transaction_quantity = 0;

        out (
               '  => Successfully Deleted zero qty records - Record Count :: '
            || SQL%ROWCOUNT);

        -- Insert Records Before Delete

        INSERT INTO xxdo_mtl_trans_int_backup
            (SELECT *
               FROM mtl_transactions_interface
              WHERE     organization_id IN (107, 108, 109)                --US
                    AND process_flag = 3
                    AND source_code IN ('Container Pack')
                    AND transaction_quantity > 0);

        out (
               '  => Successfully Inserted Container Pack records in XXDO_MTL_TRANS_INT_BACKUP- Record Count :: '
            || SQL%ROWCOUNT);

        -- Delete all container pack qty when on hand qty is zero records
        DELETE FROM
            apps.mtl_transactions_interface
              WHERE     organization_id IN (107, 108, 109)                --US
                    AND process_flag = 3
                    AND source_code IN ('Container Pack')
                    AND transaction_quantity > 0;

        out (
               '  => Successfully Deleted Container Pack records - Record Count :: '
            || SQL%ROWCOUNT);

        -- Insert Records Before Delete
        INSERT INTO xxdo_mtl_trans_int_backup
            (SELECT *
               FROM mtl_transactions_interface
              WHERE     organization_id IN (107, 108, 109)                --US
                    AND process_flag = 3
                    AND source_code IN ('Musical Split')
                    AND transaction_quantity > 0
                    AND transaction_type_id = 89);

        out (
               '  => Successfully Inserted Musical Split records in XXDO_MTL_TRANS_INT_BACKUP- Record Count :: '
            || SQL%ROWCOUNT);

        -- Delete all container pack qty when on hand qty is zero records
        DELETE FROM
            apps.mtl_transactions_interface
              WHERE     organization_id IN (107, 108, 109)
                    AND process_flag = 3
                    AND source_code IN ('Musical Split')
                    AND transaction_quantity > 0
                    AND transaction_type_id = 89;

        out (
               '  => Successfully Deleted Musical Split records - Record Count :: '
            || SQL%ROWCOUNT);

        UPDATE mtl_transactions_interface mti
           SET process_flag = 1, lock_flag = 2, transaction_mode = 3,
               ERROR_CODE = NULL, transaction_date = TRUNC (SYSDATE, 'MM')
         WHERE     process_flag = 3
               AND mti.error_explanation =
                   'No open period found for date entered';

        out (
               '  => Successfully Updated MTI records with Open period Transaction Date :: '
            || TRUNC (SYSDATE, 'MM')
            || ' - Record Count :: '
            || SQL%ROWCOUNT);

        -- Unable to process due to LPN context
        UPDATE apps.wms_license_plate_numbers
           SET lpn_context   = 11
         WHERE lpn_id IN
                   (SELECT DISTINCT content_lpn_id
                      FROM apps.mtl_transactions_interface
                     WHERE     organization_id IN (107, 108, 109)         --US
                           AND process_flag = 3
                           AND error_explanation =
                               '|Failed to update LPN status|WMS_CONTEXT_CHANGE_ERR (CONTEXT1=Packing context) (CONTEXT2=Issued out of Stores)'
                           AND content_lpn_id IS NOT NULL
                    UNION
                    SELECT DISTINCT lpn_id
                      FROM apps.mtl_transactions_interface
                     WHERE     organization_id IN (107, 108, 109)         --US
                           AND process_flag = 3
                           AND error_explanation =
                               '|Failed to update LPN status|WMS_CONTEXT_CHANGE_ERR (CONTEXT1=Packing context) (CONTEXT2=Issued out of Stores)'
                           AND lpn_id IS NOT NULL);

        out (
               '  => Successfully Updated LPN Context to  11   - Record Count  :: '
            || SQL%ROWCOUNT);

        UPDATE mtl_transactions_interface mti
           SET PROCESS_FLAG = 1, LOCK_FLAG = 2, TRANSACTION_MODE = 3,
               ERROR_CODE = NULL, transaction_date = TRUNC (transaction_date + 1)
         WHERE ERROR_CODE = 'Account period';

        out (
               '  => Successfully Updated MTI with Account Period - Record Count :: '
            || SQL%ROWCOUNT);


        -- Reprocess MTL records with Reservation locator ID and Sub Inventory
        UPDATE mtl_transactions_interface mti
           SET process_flag = 1, lock_flag = 2, transaction_mode = 3,
               ERROR_CODE = NULL
         WHERE process_flag = 3;

        out (
               '  => Successfully Updated MTI records - Record Count :: '
            || SQL%ROWCOUNT);

        -- Insert Records Before Delete
        INSERT INTO xxdo_mtl_trans_temp_backup
            (SELECT *
               FROM apps.mtl_material_transactions_temp
              WHERE     1 = 1
                    AND transaction_uom = 'X'
                    AND (process_flag = 'E' OR NVL (transaction_status, 0) <> 2));

        out (
               '  => Successfully Inserted transaction temp records with UOM code X in XXDO_MTL_TRANS_INT_BACKUP- Record Count :: '
            || SQL%ROWCOUNT);

        --Delete MMTT records with UOM code as X
        DELETE FROM
            apps.mtl_material_transactions_temp
              WHERE     1 = 1
                    AND transaction_uom = 'X'
                    AND (process_flag = 'E' OR NVL (transaction_status, 0) <> 2);

        out (
               '  => Successfully deleted MMTT records - Record Count :: '
            || SQL%ROWCOUNT);
        COMMIT;

        -- Insert Records Before Delete
        INSERT INTO xxdo_mtl_trans_temp_backup
            (SELECT *
               FROM apps.mtl_material_transactions_temp
              WHERE     1 = 1
                    AND organization_id IN (107, 108, 109)
                    AND (process_flag = 'E' OR NVL (transaction_status, 0) <> 2)
                    AND transaction_type_id IN (2, 87) -- Subinventory transfer
                    AND creation_date < SYSDATE - 2);

        out (
               '  => Successfully Inserted transaction temp records with sub inventory transaction type in XXDO_MTL_TRANS_INT_BACKUP - Record Count :: '
            || SQL%ROWCOUNT);


        /*Delete MMTT records with sub inventory transfer older than 2 days*/
        DELETE FROM
            apps.MTL_MATERIAL_TRANSACTIONS_TEMP
              WHERE     1 = 1
                    AND organization_id IN (107, 108, 109)
                    AND (process_flag = 'E' OR NVL (TRANSACTION_STATUS, 0) <> 2)
                    AND transaction_type_id IN (2, 87) -- Subinventory transfer
                    AND creation_date < SYSDATE - 2;

        out (
               '  => Successfully deleted MMTT records - Record Count :: '
            || SQL%ROWCOUNT);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode    := 1;
            p_reterror   := SUBSTR (SQLERRM, 1, 200);
            COMMIT;
    END;

    /****************************************************************************
    * Procedure/Function Name  :  wms_rma_sub_routine
    *
    * Description              :  The purpose of this procedure is to push
    *                             RMA Order Line workflow for WMS.
    *
    * INPUT Parameters  :
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/

    PROCEDURE wms_rma_sub_routine (p_reterror   OUT VARCHAR2,
                                   p_retcode    OUT NUMBER)
    IS
        CURSOR line_info IS
              SELECT DISTINCT line_id, ordered_quantity, fulfilled_quantity
                FROM apps.oe_order_lines_all ool, apps.rcv_transactions_interface rti
               WHERE     rti.oe_order_line_id = ool.line_id
                     AND rti.processing_status_code IN ('COMPLETED', 'ERROR')
                     AND rti.to_organization_id IN ('107', '108', '109')
                     AND EXISTS
                             (SELECT pir.error_message_name
                                FROM po_interface_errors pir
                               WHERE     1 = 1
                                     AND pir.interface_line_id =
                                         rti.interface_transaction_id
                                     AND pir.error_message LIKE
                                             '%RVTPT-020: Subroutine rvtoe_RmaPushApi()%'
                                     AND ROWNUM < 2)
                     AND ool.line_id IN
                             (SELECT DISTINCT oola.line_id
                                FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                               WHERE     oola.open_flag = 'Y'
                                     AND oola.fulfilled_quantity <
                                         oola.ordered_quantity
                                     AND oola.header_id = ooha.header_id
                                     AND NVL (oola.fulfilled_quantity, 0) > 0
                                     AND ooha.order_type_id IN
                                             (1226, 1225, 1245))
                     AND ool.flow_status_code = 'AWAITING_RETURN'
                     AND EXISTS
                             (SELECT 'x'
                                FROM apps.mtl_material_transactions mmt, apps.rcv_transactions rcv
                               WHERE     mmt.trx_source_line_id = ool.line_id
                                     AND mmt.transaction_type_id = 15
                                     AND rcv.oe_order_line_id = ool.line_id
                                     AND mmt.rcv_transaction_id =
                                         rcv.transaction_id)
            ORDER BY ool.line_id;

        CURSOR cur_receipt IS
            SELECT oola.line_id,
                   oola.line_number,
                   oola.inventory_item_id,
                   oola.shipment_number,
                   oola1.line_number new_line_number,
                   oola1.shipment_number new_shipment_number,
                   oola1.line_id new_line_id,
                   oola1.ordered_quantity,
                   oola1.flow_status_code,
                   (SELECT SUM (quantity)
                      FROM rcv_transactions_interface
                     WHERE oe_order_line_id = oola.line_id) pending_rcv,
                   (SELECT MAX (interface_transaction_id)
                      FROM rcv_transactions_interface
                     WHERE oe_order_line_id = oola.line_id) interface_transaction_id
              FROM oe_order_lines_all oola, oe_order_lines_all oola1
             WHERE     oola.flow_status_code IN ('RETURNED', 'CLOSED', 'CANCELLED',
                                                 'INVOICE_HOLD')
                   AND oola1.flow_status_code = 'AWAITING_RETURN'
                   AND oola.header_id = oola1.header_id
                   AND oola.line_number = oola1.line_number
                   AND NVL (oola1.fulfilled_quantity, 0) = 0
                   AND oola.line_id IN
                           (SELECT DISTINCT oe_order_line_id
                              FROM apps.rcv_transactions_interface rti
                             WHERE     source_document_code = 'RMA'
                                   AND processing_status_code IN
                                           ('COMPLETED', 'ERROR')
                                   AND rti.to_organization_id IN
                                           ('108', '109')
                                   AND EXISTS
                                           (SELECT pir.error_message_name
                                              FROM po_interface_errors pir
                                             WHERE     1 = 1
                                                   AND pir.interface_line_id =
                                                       rti.interface_transaction_id
                                                   AND pir.error_message LIKE
                                                           '%RVTPT-020: Subroutine rvtoe_RmaPushApi()%'
                                                   AND ROWNUM < 2));

        l_user_id         NUMBER := 0;
        l_resp_id         NUMBER := 0;
        l_appl_id         NUMBER := 0;
        l_org_id          NUMBER := 0;
        l_pend_qty        NUMBER := 0;
        x_return_status   VARCHAR2 (10) := NULL;
        x_msg_count       NUMBER := 0;
        x_msg_data        VARCHAR2 (2000) := NULL;
    BEGIN
        BEGIN
            out (' *** OM Push for RMA Lines Begin *** ');
            out ('');

            FOR rec IN line_info
            LOOP
                BEGIN
                    --Get Org_id from SO line for set policy context
                    SELECT org_id
                      INTO l_org_id
                      FROM oe_order_lines_all oola
                     WHERE line_id = rec.line_id;

                    SELECT number_value
                      INTO l_user_id
                      FROM apps.wf_item_attribute_values
                     WHERE     item_type = 'OEOL'
                           AND item_key = rec.line_id
                           AND name = 'USER_ID';

                    SELECT number_value
                      INTO l_resp_id
                      FROM apps.wf_item_attribute_values
                     WHERE     item_type = 'OEOL'
                           AND item_key = rec.line_id
                           AND name = 'RESPONSIBILITY_ID';

                    SELECT number_value
                      INTO l_appl_id
                      FROM apps.wf_item_attribute_values
                     WHERE     item_type = 'OEOL'
                           AND item_key = rec.line_id
                           AND name = 'APPLICATION_ID';
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        out (
                               'Error: Workflow details does not exist for the Line :: '
                            || rec.line_id);
                        out ('');
                        RETURN;
                END;

                -- Setup context
                out (
                       'USER ID :: '
                    || l_user_id
                    || ' RESP ID :: '
                    || l_resp_id
                    || ' APPL ID :: '
                    || l_appl_id);
                out ('');
                apps.fnd_global.apps_initialize (l_user_id,
                                                 l_resp_id,
                                                 l_appl_id);

                IF apps.mo_global.get_current_org_id IS NULL
                THEN
                    apps.mo_global.set_policy_context ('S', l_org_id);
                END IF;

                --Update NULL for fulfilled quantity
                UPDATE apps.oe_order_lines_all
                   SET fulfilled_quantity = NULL, shipped_quantity = NULL, last_updated_by = -99999999,
                       last_update_date = SYSDATE
                 WHERE line_id = rec.line_id;

                COMMIT;

                -- Start of OM PUSH
                BEGIN
                    out ('Push Receiving Info RECEIVE');
                    apps.oe_rma_receiving.push_receiving_info (
                        rec.line_id,
                        rec.fulfilled_quantity,
                        'NO PARENT',
                        'RECEIVE',
                        'N',
                        x_return_status,
                        x_msg_count,
                        x_msg_data);
                    out ('Return Status :: ' || x_return_status);

                    IF x_return_status = 'S'
                    THEN
                        out ('Push Receiving Info DELIVER');
                        apps.oe_rma_receiving.push_receiving_info (
                            rec.line_id,
                            rec.fulfilled_quantity,
                            'RECEIVE',
                            'DELIVER',
                            'N',
                            x_return_status,
                            x_msg_count,
                            x_msg_data);
                    END IF;

                    out ('After Push Receiving Info');
                    out ('Count of OE Messages :: ' || x_msg_count);

                    FOR k IN 1 .. x_msg_count
                    LOOP
                        x_msg_data   :=
                            apps.oe_msg_pub.get (p_msg_index   => k,
                                                 p_encoded     => 'F');
                        out (
                               'Error Message :: '
                            || SUBSTR (x_msg_data, 1, 200));
                    END LOOP;

                    apps.fnd_msg_pub.count_and_get (
                        p_encoded   => 'F',
                        p_count     => x_msg_count,
                        p_data      => x_msg_data);
                    out ('Count of FND messages :: ' || x_msg_count);

                    IF x_return_status <> 'S'
                    THEN
                        out (
                            'Error occurred, please fix the errors and retry.');
                        ROLLBACK;
                    ELSE
                        COMMIT;
                    END IF;
                END;

                out ('');
            END LOOP;

            COMMIT;
            out (' *** OM Push for RMA Lines End *** ');
            out ('');

            --
            DELETE FROM
                apps.rcv_headers_interface
                  WHERE header_interface_id IN
                            (SELECT rti.header_interface_id
                               FROM apps.rcv_transactions_interface rti
                              WHERE     1 = 1
                                    AND rti.TRANSACTION_TYPE <> 'SHIP'
                                    AND rti.SOURCE_DOCUMENT_CODE <> 'PO'
                                    AND rti.processing_status_code IN
                                            ('COMPLETED', 'ERROR')
                                    AND rti.to_organization_id = 107
                                    AND EXISTS
                                            (SELECT pir.error_message_name
                                               FROM po_interface_errors pir
                                              WHERE     1 = 1
                                                    AND pir.interface_line_id =
                                                        rti.interface_transaction_id
                                                    AND pir.error_message LIKE
                                                            '%RVTPT-020: Subroutine rvtoe_RmaPushApi()%'
                                                    AND ROWNUM < 2));

            out (
                   'Total number of lines deleted from RHI for US1 SUBROUTINE                       :: '
                || SQL%ROWCOUNT);

            --
            INSERT INTO xxdo_rti_rma_trx_backup
                (SELECT *
                   FROM apps.rcv_transactions_interface rti
                  WHERE     1 = 1
                        AND rti.processing_status_code IN
                                ('COMPLETED', 'ERROR')
                        AND rti.to_organization_id = 107
                        AND EXISTS
                                (SELECT pir.error_message_name
                                   FROM po_interface_errors pir
                                  WHERE     1 = 1
                                        AND pir.interface_line_id =
                                            rti.interface_transaction_id
                                        AND pir.error_message LIKE
                                                '%RVTPT-020: Subroutine rvtoe_RmaPushApi()%'
                                        AND ROWNUM < 2));

            out (
                   'Total number of RTI lines inserted into the backup table for US1 SUBROUTINE     :: '
                || SQL%ROWCOUNT);

            --
            DELETE FROM
                apps.rcv_transactions_interface rti
                  WHERE     1 = 1
                        AND rti.processing_status_code IN
                                ('COMPLETED', 'ERROR')
                        AND rti.to_organization_id = 107
                        AND rti.TRANSACTION_TYPE <> 'SHIP'
                        AND rti.SOURCE_DOCUMENT_CODE <> 'PO'
                        AND EXISTS
                                (SELECT pir.error_message_name
                                   FROM po_interface_errors pir
                                  WHERE     1 = 1
                                        AND pir.interface_line_id =
                                            rti.interface_transaction_id
                                        AND pir.error_message LIKE
                                                '%RVTPT-020: Subroutine rvtoe_RmaPushApi()%'
                                        AND ROWNUM < 2);

            out (
                   'Total number of lines deleted from RTI for US1 SUBROUTINE                       :: '
                || SQL%ROWCOUNT);
            out ('');
            COMMIT;

            -- Start processing new lines
            out (' *** RTI Update with RMA Line Begin *** ');
            out ('');

            FOR rec_receipt IN cur_receipt
            LOOP
                --Repoint the RTI RMA line and reset for processing
                out (
                       'Update Line ID :: '
                    || rec_receipt.line_id
                    || ' Transaction ID :: '
                    || rec_receipt.interface_transaction_id
                    || ' Pending Qty :: '
                    || rec_receipt.pending_rcv
                    || ' Remaining Qty :: '
                    || rec_receipt.ordered_quantity);

                SELECT LEAST (rec_receipt.ordered_quantity, rec_receipt.pending_rcv)
                  INTO l_pend_qty
                  FROM DUAL;

                out ('Update Line Qty :: ' || l_pend_qty);

                --
                UPDATE rcv_transactions_interface rti
                   SET oe_order_line_id = rec_receipt.new_line_id, processing_status_code = 'PENDING', transaction_status_code = 'PENDING',
                       processing_request_id = NULL, validation_flag = 'Y', request_id = NULL,
                       processing_mode_code = 'BATCH', quantity = rec_receipt.pending_rcv, primary_quantity = rec_receipt.pending_rcv
                 WHERE     oe_order_line_id = rec_receipt.line_id
                       AND rti.interface_transaction_id =
                           rec_receipt.interface_transaction_id;

                --Update the RHI record status
                UPDATE rcv_headers_interface rhi
                   SET processing_status_code = 'PENDING', processing_request_id = NULL, validation_flag = 'Y',
                       receipt_header_id = NULL, receipt_num = NULL
                 WHERE (GROUP_ID, header_interface_id) IN
                           (SELECT GROUP_ID, header_interface_id
                              FROM rcv_transactions_interface
                             WHERE interface_transaction_id =
                                   rec_receipt.interface_transaction_id);

                out (
                       'Backup Line ID :: '
                    || rec_receipt.line_id
                    || ' Not Transaction ID :: '
                    || rec_receipt.interface_transaction_id
                    || ' Quantity :: '
                    || rec_receipt.pending_rcv);

                --
                INSERT INTO xxdo_rti_rma_trx_backup
                    (SELECT rti.*
                       FROM apps.rcv_transactions_interface rti
                      WHERE     1 = 1
                            AND rti.processing_status_code IN
                                    ('COMPLETED', 'ERROR')
                            AND rti.to_organization_id IN
                                    ('107', '108', '109')
                            AND rti.oe_order_line_id = rec_receipt.line_id);

                out (
                       'Total number of RTI lines inserted into the backup table :: '
                    || SQL%ROWCOUNT);

                --
                DELETE FROM
                    apps.rcv_transactions_interface rti
                      WHERE     1 = 1
                            AND rti.processing_status_code IN
                                    ('COMPLETED', 'ERROR')
                            AND rti.to_organization_id IN
                                    ('107', '108', '109')
                            AND rti.TRANSACTION_TYPE <> 'SHIP'
                            AND rti.SOURCE_DOCUMENT_CODE <> 'PO'
                            AND rti.oe_order_line_id = rec_receipt.line_id
                            AND rti.interface_transaction_id !=
                                rec_receipt.interface_transaction_id;

                out (
                       'Total number of lines deleted from RTI :: '
                    || SQL%ROWCOUNT);

                --
                DELETE FROM
                    po_interface_errors pir
                      WHERE     1 = 1
                            AND pir.interface_line_id =
                                rec_receipt.interface_transaction_id;

                out (
                       'Total number of lines deleted from PO Interface Errors :: '
                    || SQL%ROWCOUNT);
                --
                COMMIT;
                out ('');
            END LOOP;

            out (' *** RTI Update with RMA Line End *** ');
            out ('');

            --
            UPDATE rcv_headers_interface rhi
               SET processing_status_code = 'PENDING', processing_request_id = NULL, validation_flag = 'Y',
                   receipt_header_id = NULL, receipt_num = NULL
             WHERE (GROUP_ID, header_interface_id) IN
                       (SELECT GROUP_ID, header_interface_id
                          FROM apps.rcv_transactions_interface rti
                         WHERE     1 = 1
                               AND (rti.transaction_status_code = 'ERROR' OR rti.processing_status_code = 'ERROR')
                               AND rti.to_organization_id IN (108, 109)
                               AND EXISTS
                                       (SELECT pir.error_message_name
                                          FROM po_interface_errors pir
                                         WHERE     1 = 1
                                               AND pir.interface_header_id =
                                                   rti.header_interface_id
                                               AND pir.error_message_name LIKE
                                                       '%PO_PDOI_RECEIPT_NUM_UNIQUE%'));

            out (
                   'Total number of lines updated on RHI for Receipt Already Exists                 :: '
                || SQL%ROWCOUNT);

            --
            UPDATE rcv_transactions_interface rti
               SET processing_status_code = 'PENDING', transaction_status_code = 'PENDING', processing_request_id = NULL,
                   validation_flag = 'Y', request_id = NULL, processing_mode_code = 'BATCH'
             WHERE     1 = 1
                   AND (rti.transaction_status_code = 'ERROR' OR rti.processing_status_code = 'ERROR')
                   AND rti.to_organization_id IN (108, 109)
                   AND EXISTS
                           (SELECT pir.error_message_name
                              FROM po_interface_errors pir
                             WHERE     1 = 1
                                   AND pir.interface_header_id =
                                       rti.header_interface_id
                                   AND pir.error_message_name LIKE
                                           '%PO_PDOI_RECEIPT_NUM_UNIQUE%');

            out (
                   'Total number of lines updated on RTI for Receipt Already Exists                 :: '
                || SQL%ROWCOUNT);
            COMMIT;

            --
            UPDATE rcv_headers_interface rhi
               SET processing_status_code = 'PENDING', processing_request_id = NULL, validation_flag = 'Y',
                   receipt_header_id = NULL, receipt_num = NULL
             WHERE (GROUP_ID, header_interface_id) IN
                       (SELECT GROUP_ID, header_interface_id
                          FROM apps.rcv_transactions_interface rti
                         WHERE     1 = 1
                               AND (rti.transaction_status_code = 'ERROR' OR rti.processing_status_code = 'ERROR')
                               AND rti.to_organization_id IN (108, 109)
                               AND EXISTS
                                       (SELECT pir.error_message_name
                                          FROM po_interface_errors pir
                                         WHERE     1 = 1
                                               AND pir.interface_header_id =
                                                   rti.header_interface_id
                                               AND pir.error_message_name LIKE
                                                       '%RCV_INVALID_ROI_VALUE%'));

            out (
                   'Total number of lines updated on RHI for Invalid Receipt                        :: '
                || SQL%ROWCOUNT);

            --
            UPDATE rcv_transactions_interface rti
               SET processing_status_code = 'PENDING', transaction_status_code = 'PENDING', processing_request_id = NULL,
                   validation_flag = 'Y', request_id = NULL, processing_mode_code = 'BATCH'
             WHERE     1 = 1
                   AND (rti.transaction_status_code = 'ERROR' OR rti.processing_status_code = 'ERROR')
                   AND rti.to_organization_id IN (108, 109)
                   AND EXISTS
                           (SELECT pir.error_message_name
                              FROM po_interface_errors pir
                             WHERE     1 = 1
                                   AND pir.interface_header_id =
                                       rti.header_interface_id
                                   AND pir.error_message_name LIKE
                                           '%RCV_INVALID_ROI_VALUE%');

            out (
                   'Total number of lines updated on RTI for Invalid Receipt                        :: '
                || SQL%ROWCOUNT);
            COMMIT;

            --
            UPDATE rcv_headers_interface
               SET processing_request_id = NULL, validation_flag = 'Y', processing_status_code = 'PENDING'
             WHERE (GROUP_ID, header_interface_id) IN
                       (SELECT GROUP_ID, header_interface_id
                          FROM apps.rcv_transactions_interface rti
                         WHERE     1 = 1
                               AND (rti.transaction_status_code = 'ERROR' OR rti.processing_status_code = 'ERROR')
                               AND rti.to_organization_id IN (108, 109));

            out (
                   'Total number of lines updated on RHI for ALL ERROR Records                      :: '
                || SQL%ROWCOUNT);


            UPDATE rcv_transactions_interface rti
               SET processing_status_code = 'PENDING', transaction_status_code = 'PENDING', processing_request_id = NULL,
                   validation_flag = 'Y', request_id = NULL, processing_mode_code = 'BATCH'
             WHERE     1 = 1
                   AND (rti.transaction_status_code = 'ERROR' OR rti.processing_status_code = 'ERROR')
                   AND rti.to_organization_id IN (108, 109);

            out (
                   'Total number of lines updated on RTI for ALL ERROR Records                      :: '
                || SQL%ROWCOUNT);
            COMMIT;

            --
            DELETE FROM
                po_interface_errors pir
                  WHERE     1 = 1
                        AND batch_id IN
                                (SELECT GROUP_ID
                                   FROM apps.rcv_transactions_interface rti
                                  WHERE     1 = 1
                                        AND (rti.transaction_status_code = 'ERROR' OR rti.processing_status_code = 'ERROR')
                                        AND rti.to_organization_id IN (107)
                                        AND NOT EXISTS
                                                (SELECT 1
                                                   FROM oe_order_headers_all oeh
                                                  WHERE     oeh.header_id =
                                                            rti.oe_order_header_id
                                                        AND oeh.ORDER_SOURCE_ID =
                                                            1003));

            out (
                   'Total number of lines deleted from PO INTERFACE ERRORS for US1 ERROR Records    :: '
                || SQL%ROWCOUNT);

            --
            DELETE FROM
                rcv_headers_interface rhi
                  WHERE (GROUP_ID, header_interface_id) IN
                            (SELECT GROUP_ID, header_interface_id
                               FROM apps.rcv_transactions_interface rti
                              WHERE     1 = 1
                                    AND rti.TRANSACTION_TYPE <> 'SHIP'
                                    AND rti.SOURCE_DOCUMENT_CODE <> 'PO'
                                    AND (rti.transaction_status_code = 'ERROR' OR rti.processing_status_code = 'ERROR')
                                    AND rti.to_organization_id IN (107)
                                    AND NOT EXISTS
                                            (SELECT 1
                                               FROM oe_order_headers_all oeh
                                              WHERE     oeh.header_id =
                                                        rti.oe_order_header_id
                                                    AND oeh.ORDER_SOURCE_ID =
                                                        1003));

            out (
                   'Total number of lines deleted from RHI for US1 ERROR Records                    :: '
                || SQL%ROWCOUNT);

            --
            INSERT INTO xxdo_rti_rma_trx_backup
                (SELECT *
                   FROM rcv_transactions_interface rti
                  WHERE     1 = 1
                        AND (rti.transaction_status_code = 'ERROR' OR rti.processing_status_code = 'ERROR')
                        AND rti.to_organization_id IN (107)
                        AND NOT EXISTS
                                (SELECT 1
                                   FROM oe_order_headers_all oeh
                                  WHERE     oeh.header_id =
                                            rti.oe_order_header_id
                                        AND oeh.ORDER_SOURCE_ID = 1003));

            out (
                   'Total number of RTI lines inserted into the backup table for US1 ERROR Records  :: '
                || SQL%ROWCOUNT);

            DELETE FROM
                rcv_transactions_interface rti
                  WHERE     1 = 1
                        AND (rti.transaction_status_code = 'ERROR' OR rti.processing_status_code = 'ERROR')
                        AND rti.to_organization_id IN (107)
                        AND rti.TRANSACTION_TYPE <> 'SHIP'
                        AND rti.SOURCE_DOCUMENT_CODE <> 'PO'
                        AND NOT EXISTS
                                (SELECT 1
                                   FROM oe_order_headers_all oeh
                                  WHERE     oeh.header_id =
                                            rti.oe_order_header_id
                                        AND oeh.ORDER_SOURCE_ID = 1003);

            out (
                   'Total number of lines deleted from RTI for US1 ERROR Records                    :: '
                || SQL%ROWCOUNT);
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode    := 1;
            p_reterror   := SUBSTR (SQLERRM, 1, 200);
            COMMIT;
    END;

    /****************************************************************************
    * Procedure/Function Name  :  o2c_push_rma_order_line
    *
    * Description              :  The purpose of this procedure is to push
    *                             RMA Order Line workflow.
    *
    * INPUT Parameters  : p_rti_intfc_trx_id
    *                     p_rti_intfc_trx_grp_id
    *                     p_rti_intfc_trx_shpmnt_num
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/

    PROCEDURE o2c_push_rma_order_line (
        p_rti_intfc_trx_id           IN     NUMBER,
        p_rti_intfc_trx_grp_id       IN     NUMBER,
        p_rti_intfc_trx_shpmnt_num   IN     VARCHAR2,
        p_reterror                      OUT VARCHAR2,
        p_retcode                       OUT NUMBER)
    IS
        CURSOR line_info IS
            SELECT line_id, ordered_quantity, fulfilled_quantity
              FROM apps.oe_order_lines_all ool, apps.rcv_transactions_interface rti
             WHERE     rti.oe_order_line_id = ool.line_id
                   AND rti.processing_status_code IN ('COMPLETED', 'ERROR')
                   AND rti.interface_transaction_id =
                       NVL (p_rti_intfc_trx_id, rti.interface_transaction_id)
                   AND rti.GROUP_ID =
                       NVL (p_rti_intfc_trx_grp_id, rti.GROUP_ID)
                   AND rti.shipment_num =
                       NVL (p_rti_intfc_trx_shpmnt_num, rti.shipment_num)
                   AND ool.line_id IN
                           (SELECT DISTINCT oola.line_id
                              FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                             WHERE     oola.open_flag = 'Y'
                                   AND oola.fulfilled_quantity <
                                       oola.ordered_quantity
                                   AND oola.header_id = ooha.header_id
                                   AND NVL (oola.fulfilled_quantity, 0) > 0
                                   AND ooha.order_type_id IN (1226, 1225))
                   AND ool.flow_status_code = 'AWAITING_RETURN'
                   AND EXISTS
                           (SELECT 'x'
                              FROM apps.mtl_material_transactions mmt, apps.rcv_transactions rcv
                             WHERE     mmt.trx_source_line_id = ool.line_id
                                   AND mmt.transaction_type_id = 15
                                   AND rcv.oe_order_line_id = ool.line_id
                                   AND mmt.rcv_transaction_id =
                                       rcv.transaction_id);

        l_user_id         NUMBER := 0;
        l_resp_id         NUMBER := 0;
        l_appl_id         NUMBER := 0;
        l_org_id          NUMBER := 0;
        x_return_status   VARCHAR2 (10);
        x_msg_count       NUMBER;
        x_msg_data        VARCHAR2 (2000);
    BEGIN
        IF ((p_rti_intfc_trx_id IS NULL) AND (p_rti_intfc_trx_grp_id IS NULL) AND (p_rti_intfc_trx_shpmnt_num IS NULL))
        THEN
            out (
                'Please enter atleast one input for RTI and resubmit the program...');
        ELSE
            BEGIN
                FOR rec IN line_info
                LOOP
                    BEGIN
                        --Get Org_id from SO line for set policy context
                        SELECT org_id
                          INTO l_org_id
                          FROM oe_order_lines_all oola
                         WHERE line_id = rec.line_id;

                        SELECT number_value
                          INTO l_user_id
                          FROM apps.wf_item_attribute_values
                         WHERE     item_type = 'OEOL'
                               AND item_key = rec.line_id
                               AND name = 'USER_ID';

                        SELECT number_value
                          INTO l_resp_id
                          FROM apps.wf_item_attribute_values
                         WHERE     item_type = 'OEOL'
                               AND item_key = rec.line_id
                               AND name = 'RESPONSIBILITY_ID';

                        SELECT number_value
                          INTO l_appl_id
                          FROM apps.wf_item_attribute_values
                         WHERE     item_type = 'OEOL'
                               AND item_key = rec.line_id
                               AND name = 'APPLICATION_ID';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            out ('Error: Line flow does not exist.');
                            RETURN;
                    END;

                    out (
                           'USER ID :: '
                        || l_user_id
                        || ' RESP ID :: '
                        || l_resp_id
                        || ' APPL ID :: '
                        || l_appl_id);
                    apps.fnd_global.apps_initialize (l_user_id,
                                                     l_resp_id,
                                                     l_appl_id);

                    IF apps.mo_global.get_current_org_id IS NULL
                    THEN
                        apps.mo_global.set_policy_context ('S', l_org_id);
                    END IF;

                    UPDATE apps.oe_order_lines_all
                       SET fulfilled_quantity = NULL, shipped_quantity = NULL, last_updated_by = -99999999,
                           last_update_date = SYSDATE
                     WHERE line_id = rec.line_id;

                    COMMIT;

                    BEGIN
                        out ('Push receiving info RECEIVE');
                        apps.oe_rma_receiving.push_receiving_info (
                            rec.line_id,
                            rec.fulfilled_quantity,
                            'NO PARENT',
                            'RECEIVE',
                            'N',
                            x_return_status,
                            x_msg_count,
                            x_msg_data);

                        out ('Return Status :: ' || x_return_status);

                        IF x_return_status = 'S'
                        THEN
                            out ('Push receiving info DELIVER');
                            apps.oe_rma_receiving.push_receiving_info (
                                rec.line_id,
                                rec.fulfilled_quantity,
                                'RECEIVE',
                                'DELIVER',
                                'N',
                                x_return_status,
                                x_msg_count,
                                x_msg_data);
                        END IF;

                        out (' After Push receiving info');
                        out ('Count of OE messages :: ' || x_msg_count);

                        FOR k IN 1 .. x_msg_count
                        LOOP
                            x_msg_data   :=
                                apps.oe_msg_pub.get (p_msg_index   => k,
                                                     p_encoded     => 'F');

                            out (
                                'Error msg: ' || SUBSTR (x_msg_data, 1, 200));
                        END LOOP;

                        apps.fnd_msg_pub.count_and_get (
                            p_encoded   => 'F',
                            p_count     => x_msg_count,
                            p_data      => x_msg_data);

                        out ('Count of FND messages :: ' || x_msg_count);


                        IF x_return_status <> 'S'
                        THEN
                            out (
                                'Error occured, please fix the errors and retry.');
                            ROLLBACK;
                        ELSE
                            COMMIT;
                        END IF;
                    END;
                END LOOP;
            END;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode    := 1;
            p_reterror   := SUBSTR (SQLERRM, 1, 200);
            COMMIT;
    END;

    /****************************************************************************
    * Procedure/Function Name  :  o2c_repnt_rma_rcpt_ln_same_ln
    *
    * Description              :  The purpose of this procedure is to Repoint
    *                             RMA Receipt Line to the same line.
    *
    * INPUT Parameters  : p_rti_intfc_trx_id
    *                     p_rti_intfc_trx_grp_id
    *                     p_rti_intfc_trx_shpmnt_num
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/

    PROCEDURE o2c_repnt_rma_rcpt_ln_same_ln (
        p_rti_intfc_trx_id           IN     NUMBER,
        p_rti_intfc_trx_grp_id       IN     NUMBER,
        p_rti_intfc_trx_shpmnt_num   IN     VARCHAR2,
        p_reterror                      OUT VARCHAR2,
        p_retcode                       OUT NUMBER)
    IS
        CURSOR c_recs IS
            SELECT oola.line_id,
                   oola.line_number,
                   oola.inventory_item_id,
                   oola.shipment_number,
                   oola1.line_number new_line_number,
                   oola1.shipment_number new_shipment_number,
                   oola1.line_id new_line_id,
                   oola1.ordered_quantity,
                   oola1.flow_status_code,
                   (SELECT SUM (quantity)
                      FROM rcv_transactions_interface
                     WHERE oe_order_line_id = oola.line_id) pending_rcv
              FROM oe_order_lines_all oola, oe_order_lines_all oola1
             WHERE     oola.flow_status_code IN ('RETURNED', 'CLOSED', 'CANCELLED',
                                                 'INVOICE_HOLD')
                   AND oola1.flow_status_code = 'AWAITING_RETURN'
                   AND oola.header_id = oola1.header_id
                   AND oola.line_number = oola1.line_number
                   AND NVL (oola1.fulfilled_quantity, 0) = 0
                   AND oola.line_id IN
                           (SELECT oe_order_line_id
                              FROM apps.rcv_transactions_interface rti
                             WHERE     source_document_code = 'RMA'
                                   AND processing_status_code IN
                                           ('COMPLETED', 'ERROR')
                                   AND rti.interface_transaction_id =
                                       NVL (p_rti_intfc_trx_id,
                                            rti.interface_transaction_id)
                                   AND rti.GROUP_ID =
                                       NVL (p_rti_intfc_trx_grp_id,
                                            rti.GROUP_ID)
                                   AND rti.shipment_num =
                                       NVL (p_rti_intfc_trx_shpmnt_num,
                                            rti.shipment_num));
    BEGIN
        IF ((p_rti_intfc_trx_id IS NULL) AND (p_rti_intfc_trx_grp_id IS NULL) AND (p_rti_intfc_trx_shpmnt_num IS NULL))
        THEN
            out (
                'Please enter atleast one input for RTI and resubmit the program...');
        ELSE
            BEGIN
                FOR rec IN c_recs
                LOOP
                    --Repoint the RTI RMA line and reset for processing
                    UPDATE rcv_transactions_interface rti
                       SET oe_order_line_id = rec.new_line_id, processing_status_code = 'PENDING', transaction_status_code = 'PENDING',
                           processing_request_id = NULL, validation_flag = 'Y', request_id = NULL,
                           processing_mode_code = 'BATCH'
                     WHERE oe_order_line_id = rec.line_id;

                    --Update the RHI record status
                    UPDATE rcv_headers_interface rhi
                       SET processing_status_code = 'PENDING', processing_request_id = NULL, validation_flag = 'Y',
                           receipt_header_id = NULL, receipt_num = NULL
                     WHERE (GROUP_ID, header_interface_id) IN
                               (SELECT GROUP_ID, header_interface_id
                                  FROM rcv_transactions_interface
                                 WHERE oe_order_line_id = rec.new_line_id);
                END LOOP;
            END;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode    := 1;
            p_reterror   := SUBSTR (SQLERRM, 1, 200);
            COMMIT;
    END;


    /****************************************************************************
    * Procedure/Function Name  :  o2c_repnt_rma_rcpt_ln_new_ln
    *
    * Description              :  The purpose of this procedure is to Repoint
    *                             RMA Receipt Line to the new line.
    *
    * INPUT Parameters  : p_rti_intfc_trx_id
    *                     p_rti_intfc_trx_grp_id
    *                     p_rti_intfc_trx_shpmnt_num
    *
    * OUTPUT Parameters : p_retcode
    *                     p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ***************************************************************************/

    PROCEDURE o2c_repnt_rma_rcpt_ln_new_ln (
        p_rti_intfc_trx_id           IN     NUMBER,
        p_rti_intfc_trx_grp_id       IN     NUMBER,
        p_rti_intfc_trx_shpmnt_num   IN     VARCHAR2,
        p_reterror                      OUT VARCHAR2,
        p_retcode                       OUT NUMBER)
    IS
        CURSOR c_recs IS
            SELECT oola.line_id,
                   oola.line_number,
                   oola.shipment_number,
                   oola1.line_number new_line_number,
                   oola1.shipment_number new_shipment_number,
                   oola1.line_id new_line_id,
                   oola1.ship_from_org_id,
                   oola1.ordered_quantity,
                   oola1.flow_status_code,
                   (SELECT SUM (quantity)
                      FROM rcv_transactions_interface
                     WHERE oe_order_line_id = oola.line_id) pending_rcv
              FROM oe_order_lines_all oola, oe_order_lines_all oola1
             WHERE     oola.flow_status_code IN ('RETURNED', 'CLOSED', 'CANCELLED',
                                                 'INVOICE_HOLD')
                   AND oola1.flow_status_code = 'AWAITING_RETURN'
                   AND oola.header_id = oola1.header_id
                   AND oola.inventory_item_id = oola1.inventory_item_id
                   AND oola.line_id IN
                           (SELECT oe_order_line_id
                              FROM apps.rcv_transactions_interface rti
                             WHERE     source_document_code = 'RMA'
                                   AND rti.processing_status_code IN
                                           ('COMPLETED', 'ERROR')
                                   AND rti.interface_transaction_id =
                                       NVL (p_rti_intfc_trx_id,
                                            rti.interface_transaction_id)
                                   AND rti.GROUP_ID =
                                       NVL (p_rti_intfc_trx_grp_id,
                                            rti.GROUP_ID)
                                   AND rti.shipment_num =
                                       NVL (p_rti_intfc_trx_shpmnt_num,
                                            rti.shipment_num));
    BEGIN
        IF ((p_rti_intfc_trx_id IS NULL) AND (p_rti_intfc_trx_grp_id IS NULL) AND (p_rti_intfc_trx_shpmnt_num IS NULL))
        THEN
            out (
                'Please enter atleast one input for RTI and resubmit the program...');
        ELSE
            BEGIN
                FOR rec IN c_recs
                LOOP
                    --Repoint the RTI RMA line and reset for processing
                    UPDATE rcv_transactions_interface rti
                       SET oe_order_line_id = rec.new_line_id, processing_status_code = 'PENDING', transaction_status_code = 'PENDING',
                           to_organization_id = rec.ship_from_org_id, document_line_num = rec.new_line_number, oe_order_line_num = rec.new_line_number,
                           processing_request_id = NULL, validation_flag = 'Y', request_id = NULL,
                           processing_mode_code = 'BATCH'
                     WHERE oe_order_line_id = rec.line_id;

                    --Update the RHI record status
                    UPDATE rcv_headers_interface rhi
                       SET processing_status_code = 'PENDING', processing_request_id = NULL, validation_flag = 'Y',
                           receipt_header_id = NULL, receipt_num = NULL
                     WHERE (GROUP_ID, header_interface_id) IN
                               (SELECT GROUP_ID, header_interface_id
                                  FROM rcv_transactions_interface
                                 WHERE oe_order_line_id = rec.new_line_id);
                END LOOP;
            END;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_retcode    := 1;
            p_reterror   := SUBSTR (SQLERRM, 1, 200);
            COMMIT;
    END;

    /****************************************************************************
    * Procedure Name   : MAIN
    *
    * Description      : Main procedure to fetch output data
    *
    * INPUT Parameters : p_track
    *                    p_error
    *                    p_rhi_hdr_intfc_id
    *                    p_rhi_hdr_intfc_grp_id
    *                    p_rhi_hdr_intfc_shpmnt_num
    *                    p_rti_intfc_trx_id
    *                    p_rti_intfc_trx_grp_id
    *                    p_rti_intfc_trx_shpmnt_num
    *                    p_mtl_trx_hdr_id
    *                    p_mtl_trx_intfc_id
    *
    * OUTPUT Parameters: p_retcode
    *                    p_reterror
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ****************************************************************************/

    PROCEDURE main (p_reterror                      OUT VARCHAR2,
                    p_retcode                       OUT NUMBER,
                    p_track                      IN     VARCHAR2,
                    p_error                      IN     VARCHAR2,
                    p_wms                        IN     VARCHAR2,
                    p_o2c                        IN     VARCHAR2,
                    p_p2p                        IN     VARCHAR2,
                    p_p2p_reextracting           IN     VARCHAR2,
                    p_p2p_shipment               IN     VARCHAR2,
                    p_p2p_int_grp_id             IN     VARCHAR2,
                    p_p2p_int_hdr_id             IN     VARCHAR2,
                    p_p2p_container_id           IN     VARCHAR2,
                    p_o2c_int_trx_id             IN     VARCHAR2,
                    p_p2p_hdr_grp_id             IN     VARCHAR2,
                    p_rhi_hdr_intfc_id           IN     NUMBER,
                    p_rhi_hdr_intfc_grp_id       IN     NUMBER,
                    p_rhi_hdr_intfc_shpmnt_num   IN     VARCHAR2,
                    p_rti_intfc_trx_id           IN     NUMBER,
                    p_rti_intfc_trx_grp_id       IN     NUMBER,
                    p_rti_intfc_trx_shpmnt_num   IN     VARCHAR2,
                    p_container_id               IN     NUMBER,
                    p_mtl_trx_hdr_id             IN     NUMBER,
                    p_mtl_trx_intfc_id           IN     NUMBER)
    IS
        l_reterror                   VARCHAR2 (2000) := NULL;
        l_retcode                    NUMBER := 0;
        l_track                      VARCHAR2 (10) := NULL;
        l_error                      VARCHAR2 (80) := NULL;
        l_rhi_hdr_intfc_id           NUMBER (20) := NULL;
        l_rhi_hdr_intfc_grp_id       NUMBER (20) := NULL;
        l_rhi_hdr_intfc_shpmnt_num   VARCHAR2 (40) := NULL;
        l_rti_intfc_trx_id           NUMBER (20) := NULL;
        l_rti_intfc_trx_grp_id       NUMBER (20) := NULL;
        l_rti_intfc_trx_shpmnt_num   VARCHAR2 (40) := NULL;
        l_container_id               NUMBER := NULL;
        l_mtl_trx_hdr_id             NUMBER (20) := NULL;
        l_mtl_trx_intfc_id           NUMBER (20) := NULL;
    BEGIN
        out (
               '*** Main Program Start at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
        out ('');

        l_track                      := p_track;
        l_error                      := p_error;
        l_rhi_hdr_intfc_id           := p_rhi_hdr_intfc_id;
        l_rhi_hdr_intfc_grp_id       := p_rhi_hdr_intfc_grp_id;
        l_rhi_hdr_intfc_shpmnt_num   := p_rhi_hdr_intfc_shpmnt_num;
        l_rti_intfc_trx_id           := p_rti_intfc_trx_id;
        l_rti_intfc_trx_grp_id       := p_rti_intfc_trx_grp_id;
        l_rti_intfc_trx_shpmnt_num   := p_rti_intfc_trx_shpmnt_num;
        l_container_id               := p_container_id;
        l_mtl_trx_hdr_id             := p_mtl_trx_hdr_id;
        l_mtl_trx_intfc_id           := p_mtl_trx_intfc_id;

        out ('Requested by Track                       :: ' || l_track);
        out ('Process Type                             :: ' || l_error);

        IF l_rhi_hdr_intfc_id IS NOT NULL
        THEN
            out (
                   'RHI Header Interface ID                  :: '
                || l_rhi_hdr_intfc_id);
        END IF;

        IF l_rhi_hdr_intfc_grp_id IS NOT NULL
        THEN
            out (
                   'RHI Header Interface Group ID            :: '
                || l_rhi_hdr_intfc_grp_id);
        END IF;

        IF l_rhi_hdr_intfc_shpmnt_num IS NOT NULL
        THEN
            out (
                   'RHI Header Interface Shipment Number     :: '
                || l_rhi_hdr_intfc_shpmnt_num);
        END IF;

        IF l_rti_intfc_trx_id IS NOT NULL
        THEN
            out (
                   'RTI TRX Interface ID                     :: '
                || l_rti_intfc_trx_id);
        END IF;

        IF l_rti_intfc_trx_grp_id IS NOT NULL
        THEN
            out (
                   'RTI TRX Interface Group ID               :: '
                || l_rti_intfc_trx_grp_id);
        END IF;

        IF l_rti_intfc_trx_shpmnt_num IS NOT NULL
        THEN
            out (
                   'RTI TRX Interface Shipment Number        :: '
                || l_rti_intfc_trx_shpmnt_num);
        END IF;

        IF l_container_id IS NOT NULL
        THEN
            out (
                   'Container ID for ASN Re-Extract          :: '
                || l_container_id);
        END IF;

        IF l_mtl_trx_hdr_id IS NOT NULL
        THEN
            out (
                   'MTL TRX Header ID                        :: '
                || l_mtl_trx_hdr_id);
        END IF;

        IF l_mtl_trx_intfc_id IS NOT NULL
        THEN
            out (
                   'MTL TRX Interface ID                     :: '
                || l_mtl_trx_intfc_id);
        END IF;

        out ('');

        IF UPPER (l_track) = 'P2P'
        THEN
            IF UPPER (l_error) = 'ASNS RE-PROCESSING'
            THEN
                BEGIN
                    out (
                           'Calling P2P ASNS RE-PROCESSING Procedure at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    out ('');

                    p2p_asn_reprocess (l_rhi_hdr_intfc_id, l_rhi_hdr_intfc_grp_id, l_rhi_hdr_intfc_shpmnt_num
                                       , l_reterror, l_retcode);

                    out ('');

                    IF l_retcode > 0
                    THEN
                        out (
                               'P2P ASNS RE-PROCESSING Procedure failed with error message : '
                            || l_reterror);
                    ELSE
                        out (
                            'P2P ASNS RE-PROCESSING Procedure completed successfully');
                    END IF;
                END;
            ELSIF UPPER (l_error) = 'ASNS RE-EXTRACTING'
            THEN
                BEGIN
                    out (
                           'Calling P2P ASNS RE-EXTRACTING Procedure at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    out ('');

                    p2p_asn_reextract (l_rhi_hdr_intfc_shpmnt_num, l_rti_intfc_trx_shpmnt_num, l_container_id
                                       , l_reterror, l_retcode);

                    out ('');

                    IF l_retcode > 0
                    THEN
                        out (
                               'P2P ASNS RE-EXTRACTING Procedure failed with error message : '
                            || l_reterror);
                    ELSE
                        out (
                            'P2P ASNS RE-EXTRACTING Procedure completed successfully');
                    END IF;
                END;
            ELSIF UPPER (l_error) = 'ASNS NO OPEN SHIPMENTS'
            THEN
                BEGIN
                    out (
                           'Calling P2P ASNS NO OPEN SHIPMENTS Procedure at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    out ('');

                    p2p_asn_no_open_shipments (l_rhi_hdr_intfc_grp_id, l_rti_intfc_trx_grp_id, l_reterror
                                               , l_retcode);

                    out ('');

                    IF l_retcode > 0
                    THEN
                        out (
                               'P2P ASNS NO OPEN SHIPMENTS Procedure failed with error message : '
                            || l_reterror);
                    ELSE
                        out (
                            'P2P ASNS NO OPEN SHIPMENTS Procedure completed successfully');
                    END IF;
                END;
            ELSIF UPPER (l_error) = 'ASNS SHIPMENT HEADER EXISTS'
            THEN
                BEGIN
                    out (
                           'Calling P2P ASNS SHIPMENT HEADER EXISTS Procedure at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    out ('');

                    p2p_asn_shipment_exists (l_rhi_hdr_intfc_shpmnt_num, l_rti_intfc_trx_shpmnt_num, l_reterror
                                             , l_retcode);

                    out ('');

                    IF l_retcode > 0
                    THEN
                        out (
                               'P2P ASNS SHIPMENT HEADER EXISTS Procedure failed with error message : '
                            || l_reterror);
                    ELSE
                        out (
                            'P2P ASNS SHIPMENT HEADER EXISTS Procedure completed successfully');
                    END IF;
                END;
            END IF;
        ELSIF UPPER (l_track) = 'WMS'
        THEN
            IF UPPER (l_error) = 'MTL TRANSACTIONS INTERFACE CLEAN-UP'
            THEN
                BEGIN
                    out (
                           'Calling WMS MTL TRANSACTIONS INTERFACE CLEAN-UP Procedure at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    out ('');

                    wms_mtl_trx_intfc_clnup (l_mtl_trx_hdr_id, l_mtl_trx_intfc_id, l_reterror
                                             , l_retcode);

                    out ('');

                    IF l_retcode > 0
                    THEN
                        out (
                               'WMS MTL TRANSACTIONS INTERFACE CLEAN-UP Procedure failed with error message : '
                            || l_reterror);
                    ELSE
                        out (
                            'WMS MTL TRANSACTIONS INTERFACE CLEAN-UP Procedure completed successfully');
                    END IF;
                END;
            ELSIF UPPER (l_error) = 'RMA SUB ROUTINE ERROR'
            THEN
                BEGIN
                    out (
                           'Calling WMS RMA SUB ROUTINE Procedure at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    out ('');

                    wms_rma_sub_routine (l_reterror, l_retcode);

                    out ('');

                    IF l_retcode > 0
                    THEN
                        out (
                               'WMS RMA SUB ROUTINE Procedure failed with error message : '
                            || l_reterror);
                    ELSE
                        out (
                            'WMS RMA SUB ROUTINE Procedure completed successfully');
                    END IF;
                END;
            END IF;
        ELSIF UPPER (l_track) = 'O2C'
        THEN
            IF UPPER (l_error) = 'PUSH RMA ORDER LINE'
            THEN
                BEGIN
                    out (
                           'Calling O2C PUSH RMA ORDER LINE Procedure at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    out ('');

                    o2c_push_rma_order_line (l_rti_intfc_trx_id, l_rti_intfc_trx_grp_id, l_rti_intfc_trx_shpmnt_num
                                             , l_reterror, l_retcode);

                    out ('');

                    IF l_retcode > 0
                    THEN
                        out (
                               'O2C PUSH RMA ORDER LINE Procedure failed with error message : '
                            || l_reterror);
                    ELSE
                        out (
                            'O2C PUSH RMA ORDER LINE Procedure completed successfully');
                    END IF;
                END;
            ELSIF UPPER (l_error) = 'RE-POINT RMA RECEIPT LINES (SAME LINE)'
            THEN
                BEGIN
                    out (
                           'Calling O2C RE-POINT RMA RECEIPT LINES (SAME LINE) Procedure at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    out ('');

                    o2c_repnt_rma_rcpt_ln_same_ln (l_rti_intfc_trx_id, l_rti_intfc_trx_grp_id, l_rti_intfc_trx_shpmnt_num
                                                   , l_reterror, l_retcode);

                    out ('');

                    IF l_retcode > 0
                    THEN
                        out (
                               'O2C RE-POINT RMA RECEIPT LINES (SAME LINE) Procedure failed with error message : '
                            || l_reterror);
                    ELSE
                        out (
                            'O2C RE-POINT RMA RECEIPT LINES (SAME LINE) Procedure completed successfully');
                    END IF;
                END;
            ELSIF UPPER (l_error) = 'RE-POINT RMA RECEIPT LINES (NEW LINE)'
            THEN
                BEGIN
                    out (
                           'Calling O2C RE-POINT RMA RECEIPT LINES (NEW LINE) Procedure at :: '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    out ('');

                    o2c_repnt_rma_rcpt_ln_new_ln (l_rti_intfc_trx_id, l_rti_intfc_trx_grp_id, l_rti_intfc_trx_shpmnt_num
                                                  , l_reterror, l_retcode);

                    out ('');

                    IF l_retcode > 0
                    THEN
                        out (
                               'O2C RE-POINT RMA RECEIPT LINES (NEW LINE) Procedure failed with error message : '
                            || l_reterror);
                    ELSE
                        out (
                            'O2C RE-POINT RMA RECEIPT LINES (NEW LINE) Procedure completed successfully');
                    END IF;
                END;
            END IF;
        ELSE
            out (
                'Combination of Inputs passed to the program are Incorrect. Please check...');
        END IF;

        out ('');
        out (
               '*** Main Program End at :: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
            || ' ***');
    END;
END xxdo_intf_tbl_clnup_pkg;
/
