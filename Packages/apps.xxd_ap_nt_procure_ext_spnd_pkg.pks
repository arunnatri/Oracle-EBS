--
-- XXD_AP_NT_PROCURE_EXT_SPND_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_NT_PROCURE_EXT_SPND_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_AP_NT_PROCURE_EXT_SPND_PKG
    -- Design       : This package will be used by the Deckers Non-Trade Procurement External Spend Report
    --
    -- Modification :
    -- ----------
    -- Date            Name               Ver    Description
    -- ----------      --------------    -----  ------------------
    -- 20-Jan-2023     Jayarajan A K      1.0    Initial Version (CCR0010397)
    -- #########################################################################################################################

    PROCEDURE generate_report (x_msg                 OUT VARCHAR2,
                               x_ret_stat            OUT VARCHAR2,
                               p_inv_start_date   IN     VARCHAR2,
                               p_inv_end_date     IN     VARCHAR2,
                               p_debug            IN     VARCHAR2);
END xxd_ap_nt_procure_ext_spnd_pkg;
/
