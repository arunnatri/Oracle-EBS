--
-- XXD_AP_DEF_ACCT_UPDATE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_DEF_ACCT_UPDATE_PKG"
AS
    PROCEDURE update_deferred_values (pn_invoice_id   IN     NUMBER,
                                      pv_error_msg       OUT VARCHAR2);

    FUNCTION validate_deferred_dates (pn_org_id            IN NUMBER,
                                      pv_deff_start_date   IN VARCHAR2)
        RETURN VARCHAR2;
END xxd_ap_def_acct_update_pkg;
/
