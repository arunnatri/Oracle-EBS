--
-- XXDO_ACC_EXT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ACC_EXT_PKG"
AS
    /****************************************************************************
    **
    NAME:       xxdo_acc_ext_pkg
    PURPOSE:    This package contains procedures for Accrual Extract
    REVISIONS:
    Ver        Date        Author           Description
    ---------  ----------  ---------------  ------------------------------------
    1.0        09/23/2016   Infosys           1. Created this package.
    *****************************************************************************
    */

    PROCEDURE main_acc_ext (p_out_var_errbuf         OUT VARCHAR2,
                            p_out_var_retcode        OUT NUMBER,
                            --      p_in_trxn_date      IN VARCHAR2,
                            p_org_id              IN     NUMBER,
                            p_in_acct_date_from   IN     VARCHAR2,
                            p_in_acct_date_to     IN     VARCHAR2);
END XXDO_ACC_EXT_PKG;
/
