--
-- XXD_AP_MTD_REPORT_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_MTD_REPORT_PKG"
AS
    /****************************************************************************************
     * Package      : XXD_MTD_REPORTD_PKG
     * Design       : This package will be used for MTD Reports
     * Notes        :
     * Modification :
     -- ======================================================================================
     -- Date         Version#   Name                    Comments
     -- ======================================================================================
     -- 14-Aug-2020  1.0        Tejaswi Gangumalla      Initial Version
     -- 06-Oct-2021  1.1        Aravind Kannuri         Modified for CCR0009638
    ******************************************************************************************/
    gn_request_id   NUMBER := fnd_global.conc_request_id;

    PROCEDURE mtd_ap_rep (pv_errbuf OUT NOCOPY VARCHAR2, pn_retcode OUT NOCOPY NUMBER, pv_operating_unit IN VARCHAR2, pv_company_code IN VARCHAR2, pv_invoice_date_from IN VARCHAR2, pv_invoice_date_to IN VARCHAR2, pv_gl_posted_from IN VARCHAR2, pv_gl_posted_to IN VARCHAR2, pv_tax_regime_code IN VARCHAR2, pv_tax_code IN VARCHAR2, pv_account IN VARCHAR2, pv_cost_center IN VARCHAR2
                          , --   pv_posting_status      IN              VARCHAR2,
                            pv_final_mode IN VARCHAR2);

    -- Start Added for 1.1
    FUNCTION remove_junk_char (p_input IN VARCHAR2)
        RETURN VARCHAR2;
-- End Added for 1.1

END xxd_ap_mtd_report_pkg;
/


GRANT EXECUTE ON APPS.XXD_AP_MTD_REPORT_PKG TO LKAKLOORI
/
