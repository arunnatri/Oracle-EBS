--
-- XXD_AR_CREATE_AUTO_RECEIPT_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_CREATE_AUTO_RECEIPT_PKG"
AS
    --  ####################################################################################################
    --  Author(s)       : Showkath Ali (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Subsystem       : EBS(Accounts Receivables)
    --  Change          : CCR0008295
    --  Schema          : APPS
    --  Purpose         : This package is used to create receipts and apply to invoices of DXLAB
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  12-Dec-2019     Showkath Ali      1.0     NA              Initial Version
    --  ####################################################################################################

    gn_created_by      NUMBER := fnd_global.user_id;
    gn_session_id      NUMBER := USERENV ('SESSIONID');
    gn_request_id      NUMBER := fnd_global.conc_request_id;
    gv_debug_message   VARCHAR2 (100);

    PROCEDURE main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_order_number IN VARCHAR2
                    , p_invoice_number IN VARCHAR2, p_invoice_date_from IN DATE, p_invoice_date_to IN DATE);
END;
/
