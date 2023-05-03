--
-- XXDOINT_AP_INVOICE_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINT_AP_INVOICE_UTILS"
AS
    G_PKG_NAME   CONSTANT VARCHAR2 (40) := 'xxdoint_ap_invoice_utils';
    g_n_temp              NUMBER;
    l_buffer_number       NUMBER;


    PROCEDURE msg (p_message IN VARCHAR2, p_debug_level IN NUMBER:= 10000)
    IS
    BEGIN
        apps.do_debug_tools.msg (p_msg           => p_message,
                                 p_debug_level   => p_debug_level);
    END;


    FUNCTION get_invoice_header_id
        RETURN NUMBER
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_proc_name   VARCHAR2 (240) := 'get_invoice_header_id';
        l_header_id   NUMBER;
    BEGIN
        DO_EDI."GET_NEXT_VALUES" ('DO_EDI810IN_HEADERS_S', 1, l_header_id);
        RETURN l_header_id;
    END;
END;
/


GRANT EXECUTE ON APPS.XXDOINT_AP_INVOICE_UTILS TO SOA_INT
/
