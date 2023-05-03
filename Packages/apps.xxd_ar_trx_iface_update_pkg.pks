--
-- XXD_AR_TRX_IFACE_UPDATE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_TRX_IFACE_UPDATE_PKG"
AS
    --  ####################################################################################################
    --  Package      : xxd_ar_trx_iface_update_pkg
    --  Design       : This package is used to update the records in RA Interface Tables.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  22-Mar-2020     1.0        Showkath Al             Initial Version
    --  ####################################################################################################
    PROCEDURE trx_iface_update_main_prc (p_errbuf              OUT VARCHAR2,
                                         p_retcode             OUT NUMBER,
                                         p_operating_unit   IN     NUMBER,
                                         p_pay_date_from    IN     VARCHAR2,
                                         p_pay_date_to      IN     VARCHAR2);
END;
/
