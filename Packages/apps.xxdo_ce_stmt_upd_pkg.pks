--
-- XXDO_CE_STMT_UPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_CE_STMT_UPD_PKG"
AS
    /*******************************************************************************
    * Program Name : XXDO_CE_STMT_UPD_PKG
    * Language     : PL/SQL
    * Description  : This package will update bank statement data in interface table
    *
    * History      :
    *
    * WHO                  DESCRIPTION                         WHEN
    * ------------------------------------------------------------------------------------
    * BT Technology Team   1.0                                 27-AUG-2015
    * --------------------------------------------------------------------------- */

    PROCEDURE main_prc (errbuf                       OUT VARCHAR2,
                        retcode                      OUT VARCHAR2,
                        p_branch_id               IN     NUMBER,
                        p_bank_account_id         IN     NUMBER,
                        p_statement_number_from   IN     VARCHAR2,
                        p_statement_number_to     IN     VARCHAR2,
                        p_statement_date_from     IN     VARCHAR2,
                        p_statement_date_to       IN     VARCHAR2);
END;
/
