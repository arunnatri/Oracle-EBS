--
-- XXD_AP_RECON_VAL_BL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_RECON_VAL_BL_PKG"
AS
    /****************************************************************************************
       * Package      : XXD_AP_PAY_RECON_BL_PKG
       * Design       : This package is used for update value set XXD_AP_PAY_RECON_HIST_ID_VS after concurrent program
                        'Deckers AP Payments To Blackline' is completed sucessfully
       * Notes        :
       * Modification :
       -- ===============================================================================
       -- Date         Version#   Name                    Comments
       -- ===============================================================================
       -- 12-OCT-2020  1.0      Tejaswi Gangumala      Initial Version
       ******************************************************************************************/
    PROCEDURE update_value_set (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER, pv_module IN VARCHAR2
                                , pn_request_id IN NUMBER, pn_organization_id IN NUMBER, pn_max_id IN NUMBER);
END xxd_ap_recon_val_bl_pkg;
/
