--
-- XXD_AR_INTERFACE_REF_UPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_INTERFACE_REF_UPD_PKG"
AS
    /***************************************************************************************************************************************
        file name    : XXD_AR_INTERFACE_REF_UPD_PKG.pkb
        created on   : 04-SEP-2018
        created by   : INFOSYS
        purpose      : package specification used for the following
                               1. To remove the reference line id for Credit Memos which are stuck in AR Interface with the error
                               "The valid values for credit method for accounting rule are: PRORATE, LIFO and UNIT"
      **************************************************************************************************************************************
       Modification history:
      **************************************************************************************************************************************
          Version        Date        Author           Description
          ---------  ----------  ---------------  ------------------------------------
          1.0         04-SEP-2018     INFOSYS       1.Created
     ***************************************************************************************************************************************
     ***************************************************************************************************************************************/
    PROCEDURE ref_line_upd (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER);
END;
/
