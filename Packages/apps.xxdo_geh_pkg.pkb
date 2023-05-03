--
-- XXDO_GEH_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_GEH_PKG"
AS
    /*******************************************************************************
     * NAME:  XXDO_GEH_PKG.pkb
     *
     * DESC:  PL/SQL PACKAGE
     *
     *
     * WHO             WHAT                                   WHEN
     * --------------  -------------------------------------  ---------------
     * BT Tech Team     Common Utilities                           06-Jun-2014
     *
   * Below list of common functions are available in this package
        record_error   -- To log error messages into common error table

    *
   ******************************************************************************/


    /*+==========================================================================+
    | Procedure name                                                             |
    |     RECORD_ERROR                                                   |
    |                                                                            |
    | DESCRIPTION                                                                |
    |     Deckers Standard Error Handling Procedure                        |
    +===========================================================================*/

    PROCEDURE record_error (p_module IN VARCHAR2,   --Oracle module short name
                                                  p_cust_account_id IN NUMBER, p_program IN VARCHAR2, --Concurrent program, PLSQL procedure, etc..
                                                                                                      p_error_msg IN VARCHAR2, --SQLERRM
                                                                                                                               p_error_line IN VARCHAR2, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                                                                                                                                         p_created_by IN NUMBER, --USER_ID
                                                                                                                                                                                 --p_request_id   IN   NUMBER DEFAULT NULL,        -- concurrent request ID
                                                                                                                                                                                 p_more_info1 IN VARCHAR2 DEFAULT NULL, --additional information for troubleshooting
                                                                                                                                                                                                                        p_more_info2 IN VARCHAR2 DEFAULT NULL, p_more_info3 IN VARCHAR2 DEFAULT NULL
                            , p_more_info4 IN VARCHAR2 DEFAULT NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_module            VARCHAR2 (100);
        v_cust_account_id   NUMBER;
        v_program           VARCHAR2 (1000);
        v_error_msg         VARCHAR2 (4000);
        v_error_line        VARCHAR2 (4000);
        v_error_date        DATE;
        v_created_by        NUMBER;
        --v_request_id   NUMBER;
        v_more_info1        VARCHAR2 (4000);
        v_more_info2        VARCHAR2 (4000);
        v_more_info3        VARCHAR2 (4000);
        v_more_info4        VARCHAR2 (4000);
    BEGIN
        v_module            := p_module;
        v_cust_account_id   := p_cust_account_id;
        v_program           := p_program;
        v_error_msg         := p_error_msg;
        v_error_line        := p_error_line;
        v_created_by        := p_created_by;
        --v_request_id := p_request_id;
        v_more_info1        := p_more_info1;
        v_more_info2        := p_more_info2;
        v_more_info3        := p_more_info3;
        v_more_info4        := p_more_info4;



        INSERT INTO XXDO.XXDO_GLOBAL_ERROR_LOG_T (seq,
                                                  module,
                                                  CUST_ACCOUNT_ID,
                                                  object_name,
                                                  error_message,
                                                  error_line,
                                                  creation_date,
                                                  created_by,
                                                  --request_id,
                                                  useful_info1,
                                                  useful_info2,
                                                  useful_info3,
                                                  useful_info4)
             VALUES (XXDO_ERROR_LOG_SEQ.NEXTVAL, v_module, v_cust_account_id,
                     v_program, v_error_msg, v_error_line,
                     SYSDATE, v_created_by, --v_request_id,
                                            v_more_info1,
                     v_more_info2, v_more_info3, v_more_info4);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_error_msg   := SQLERRM;

            INSERT INTO XXDO.XXDO_GLOBAL_ERROR_LOG_T (seq,
                                                      module,
                                                      cust_account_id,
                                                      object_name,
                                                      error_message,
                                                      error_line,
                                                      creation_date,
                                                      created_by,
                                                      --request_id,
                                                      useful_info1)
                 VALUES (XXDO_ERROR_LOG_SEQ.NEXTVAL, 'XXDO_GEH_PKG', p_cust_account_id, 'XXDO Error Handling Procedure', v_error_msg, DBMS_UTILITY.format_error_backtrace
                         , SYSDATE, 1143, --v_request_id,
                                          'Unhandled exception');

            COMMIT;
    END record_error;
END XXDO_GEH_PKG;
/
