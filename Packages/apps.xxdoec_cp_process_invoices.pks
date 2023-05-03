--
-- XXDOEC_CP_PROCESS_INVOICES  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_CP_PROCESS_INVOICES"
AS
    PROCEDURE upload_invoices (x_errbuff         OUT VARCHAR2,
                               x_rtn_code        OUT NUMBER,
                               p_invoice_id   IN     NUMBER);
END xxdoec_cp_process_invoices;
/
