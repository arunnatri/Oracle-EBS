--
-- XXDO_WF_PROGRESS_LINES_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_WF_PROGRESS_LINES_PKG"
AS
    PROCEDURE XXDO_WORKFLOW_PROGRESS_MAIN (p_error_code IN OUT NUMBER, p_error_message IN OUT VARCHAR2, P_ORDER_NUMBER IN NUMBER
                                           , P_LINE_STATUS IN VARCHAR2)
    AS
        l_result     VARCHAR2 (240);
        l_file_val   VARCHAR2 (240);

        CURSOR c_lines IS
            SELECT oel.line_id
              FROM apps.oe_order_lines_all oel, apps.oe_order_headers_all oha
             WHERE     oel.header_id = oha.header_id
                   AND oel.flow_status_code = P_LINE_STATUS
                   AND oha.order_number = P_ORDER_NUMBER;
    BEGIN
        FND_GLOBAL.APPS_INITIALIZE (FND_PROFILE.VALUE ('USER_ID'),
                                    21623,
                                    660);

        FOR c IN c_lines
        LOOP
            DBMS_OUTPUT.put_line ('Loop Begins' || l_result);
            apps.OE_Standard_WF.OEOL_SELECTOR (
                p_itemtype   => 'OEOL',
                p_itemkey    => TO_CHAR (c.line_id),
                p_actid      => 12345,
                p_funcmode   => 'SET_CTX',
                p_result     => l_result);
            DBMS_OUTPUT.put_line ('result' || l_result);
            apps.wf_engine.HandleError ('OEOL', TO_CHAR (c.line_id), 'INVOICE_INTERFACE'
                                        , 'RETRY', '');
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                   'Error while moving workflow. Error Code : '
                || SQLCODE
                || '. Error Message : '
                || SQLERRM);
    END XXDO_WORKFLOW_PROGRESS_MAIN;
END XXDO_WF_PROGRESS_LINES_PKG;
/
