--
-- XXDOEC_DCDLOGGER  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDOEC_DCDLOGGER
AS
    /******************************************************************************
       NAME:       xxdoec_DCDLogger
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        11/2/2011      mbacigalupi       1. Created this package.
    ******************************************************************************/
    FUNCTION MyFunction (Param1 IN NUMBER)
        RETURN NUMBER
    IS
    BEGIN
        RETURN -1;
    END;

    PROCEDURE UpdateRepl_Flag (p_id_list IN t_id_array)
    IS
        l_err_num   NUMBER := -1;
        l_err_msg   VARCHAR2 (100) := '';
        l_message   VARCHAR2 (1000) := '';
        l_rc        NUMBER := 0;
        DCDLog      DCDLog_type
                        := DCDLog_type (P_CODE => -10051, P_APPLICATION => G_APPLICATION, P_LOGEVENTTYPE => 1
                                        , P_TRACELEVEL => 1, P_DEBUG => 0);
    BEGIN
        FORALL i IN p_id_list.FIRST .. p_id_list.LAST
            UPDATE xxdo.xxdoec_DCDLog
               SET repl_flag   = 1
             WHERE id = p_id_list (i);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_num   := SQLCODE;
            l_err_msg   := SUBSTR (SQLERRM, 1, 100);
            l_message   := 'ERROR updating repl_flag in xxdo.xxdoec_DCDLog.';
            l_message   :=
                   l_message
                || ' err_num='
                || TO_CHAR (l_err_num)
                || ' err_msg='
                || l_err_msg
                || '.';
            ROLLBACK;

            -- PUT IN DCDLogging code here!
            --         DCDLog.ChangeCode(
            --                    P_CODE=>-10051,
            --                    P_APPLICATION=>G_APPLICATION,
            --                    P_LOGEVENTTYPE=>1,
            --                    P_TRACELEVEL=>1,
            --                    P_DEBUG=>0);
            FOR i IN p_id_list.FIRST .. p_id_list.LAST
            LOOP
                DCDLog.AddParameter ('ID', TO_CHAR (p_id_list (i)), 'NUMBER');
            END LOOP;

            IF (l_rc <> 1)
            THEN
                INSERT INTO xxdo.XXDOEC_PROCESS_ORDER_LOG
                         VALUES (xxdo.XXDOEC_SEQ_PROCESS_ORDER.NEXTVAL,
                                 l_message,
                                 CURRENT_TIMESTAMP);

                COMMIT;
            END IF;
    END;

    PROCEDURE get_oracle_records (p_number               NUMBER := 500,
                                  p_oracle_rec_cur   OUT oracle_rec_cur)
    IS
    BEGIN
        OPEN p_oracle_rec_cur FOR
              SELECT NVL (b.parametername, 'none') parameterName, NVL (b.parametervalue, 'none') parameterValue, NVL (b.parametertype, 'none') parameterType,
                     a.ID, a.CODE, a.MESSAGE,
                     a.SERVER, a.APPLICATION, a.FUNCTIONNAME,
                     a.LOGEVENTTYPE, a.DTLOGGED, a.RESOLUTIONSTATUS,
                     a.SEVERITY, a.PARENTID, a.SITEID,
                     a.REPL_FLAG
                FROM xxdo.xxdoec_DCDLog a
                     LEFT JOIN xxdo.xxdoec_DCDLogParameters b ON a.id = b.Logid
               WHERE a.repl_flag = 0 AND ROWNUM <= p_number
            ORDER BY a.id;
    END;

    PROCEDURE Delete_replicated_records (p_number IN NUMBER:= 1000)
    IS
        l_id_list   t_id_array;
        l_total     NUMBER := 0;
        l_err_num   NUMBER := -1;
        l_err_msg   VARCHAR2 (100) := '';
        l_message   VARCHAR2 (1000) := '';
        l_rc        NUMBER := 1;
        DCDLog      DCDLog_type
                        := DCDLog_type (P_CODE => -10052, P_APPLICATION => G_APPLICATION, P_LOGEVENTTYPE => 1
                                        , P_TRACELEVEL => 1, P_DEBUG => 0);
    BEGIN
        WHILE (l_rc <> 0)
        LOOP
            SELECT ID
              BULK COLLECT INTO l_id_list
              FROM xxdo.xxdoec_DCDLog
             WHERE     dtLogged < SYSDATE - 7
                   AND repl_flag = 1
                   AND ROWNUM < p_number;

            l_rc   := l_id_list.COUNT;

            IF l_rc > 0
            THEN
                FORALL i IN l_id_list.FIRST .. l_id_list.LAST
                    DELETE FROM xxdo.xxdoec_DCDLogParameters
                          WHERE LogId = l_id_list (i);

                FORALL i IN l_id_list.FIRST .. l_id_list.LAST
                    DELETE FROM xxdo.xxdoec_DCDLog
                          WHERE Id = l_id_list (i);

                l_total   := l_total + l_id_list.COUNT;
                l_id_list.DELETE;
                DBMS_LOCK.SLEEP (1);                         -- Sleep 1 second
                COMMIT;
            END IF;
        --        IF l_total > 2000 THEN
        --            l_rc := 0;
        --        END IF;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE (
            '**Deleted ' || TO_CHAR (l_total) || ' records.');
        DCDLog.AddParameter ('Records deleted', TO_CHAR (l_total), 'NUMBER');
        l_rc   := DCDLog.LogInsert ();
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            -- We're done, exit.
            DBMS_OUTPUT.PUT_LINE (
                'Deleted ' || TO_CHAR (l_total) || ' records.');
        WHEN OTHERS
        THEN
            l_err_num   := SQLCODE;
            l_err_msg   := SUBSTR (SQLERRM, 1, 100);
            l_message   :=
                'ERROR deleting replicated records in xxdo.xxdoec_DCDLog.';
            l_message   :=
                   l_message
                || ' err_num='
                || TO_CHAR (l_err_num)
                || ' err_msg='
                || l_err_msg
                || '.';
            ROLLBACK;
    END;
END xxdoec_DCDLogger;
/
