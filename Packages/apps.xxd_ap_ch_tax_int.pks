--
-- XXD_AP_CH_TAX_INT  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_CH_TAX_INT"
IS
    gn_success   CONSTANT NUMBER := 0;
    gn_warning   CONSTANT NUMBER := 1;
    gn_error     CONSTANT NUMBER := 2;

    PROCEDURE MAIN_PROC (pv_errbuf OUT NOCOPY VARCHAR2, pn_retcode OUT NOCOPY NUMBER, pn_primary_ledger_id IN NUMBER, pn_secondary_ledger_id IN NUMBER, pn_entity_id IN NUMBER, pv_from_period IN VARCHAR2, pv_to_period IN VARCHAR2, pv_directory_name IN VARCHAR2, pv_temp IN VARCHAR2
                         , pv_over_write IN VARCHAR2);
END XXD_AP_CH_TAX_INT;
/
