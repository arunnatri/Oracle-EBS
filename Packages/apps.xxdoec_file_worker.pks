--
-- XXDOEC_FILE_WORKER  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDOEC_FILE_WORKER
AS
    /******************************************************************************
       NAME:       xxdoec_file_worker
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        11/26/2012      mbacigalupi       1. Created this package.
    *****************************************************************************/
    G_APPLICATION   VARCHAR2 (300) := 'xxdo.xxdoec_file_worker';

    TYPE t_order_array IS TABLE OF VARCHAR2 (30)
        INDEX BY BINARY_INTEGER;

    TYPE order_list IS RECORD
    (
        orderId           VARCHAR2 (50),
        shipToName        VARCHAR2 (30),
        billToEmail       VARCHAR2 (240),
        account_number    VARCHAR2 (240),
        website_id        VARCHAR2 (30),
        erp_language      VARCHAR2 (30),
        ordered_date      DATE
    );

    TYPE t_order_list IS REF CURSOR
        RETURN order_list;

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I');

    PROCEDURE GetOrderData (p_list       IN     t_order_array,
                            order_list      OUT t_order_list);
END xxdoec_file_worker;
/
