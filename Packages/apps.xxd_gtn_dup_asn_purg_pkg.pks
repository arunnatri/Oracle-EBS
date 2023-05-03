--
-- XXD_GTN_DUP_ASN_PURG_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GTN_DUP_ASN_PURG_PKG"
IS
    /**********************************************************************************************************
        file name    : XXD_GTN_DUP_ASN_PURG_PKG.pkb
        created on   : 10-NOV-2014
        created by   : INFOSYS
        purpose      : package specification used for the following
                               1. Insert the Style/SKU/UPC creation and update message to staging table.
                               1. Insert the TAX creation and update message to staging table.
    ****************************************************************************
       Modification history:
    *****************************************************************************
          NAME:         XXD_GTN_DUP_ASN_PURG_PKG
          PURPOSE:      MIAN PROCEDURE CONTROL_PROC

          REVISIONS:
          Version        Date        Author           Description
          ---------  ----------  ---------------  ------------------------------------
          1.0         9/11/2014     INFOSYS       1. Created this package body.
    *********************************************************************
    *********************************************************************/

    PROCEDURE main_proc (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_action IN VARCHAR2
                         , pv_asn_ref IN VARCHAR2);
END XXD_GTN_DUP_ASN_PURG_PKG;
/
