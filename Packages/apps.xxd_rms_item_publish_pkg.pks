--
-- XXD_RMS_ITEM_PUBLISH_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_RMS_ITEM_PUBLISH_PKG"
IS
    /**********************************************************************************************************
        file name    : XXD_RMS_ITEM_PUBLISH_PKG.pkb
        created on   : 10-NOV-2014
        created by   : INFOSYS
        purpose      : package specification used for the following
                               1. Insert the Style/SKU/UPC creation and update message to staging table.
                               1. Insert the TAX creation and update message to staging table.
    ****************************************************************************
       Modification history:
    *****************************************************************************
          NAME:         XXD_RMS_ITEM_PUBLISH_PKG
          PURPOSE:      MIAN PROCEDURE CONTROL_PROC

          REVISIONS:
          Version        Date        Author           Description
          ---------  ----------  ---------------  ------------------------------------
          1.0         9/11/2014     INFOSYS       1. Created this package body.
    *********************************************************************
    *********************************************************************/
    FUNCTION get_price_list_fun (p_region VARCHAR2)
        RETURN NUMBER;

    PROCEDURE main_proc (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_reprocess IN VARCHAR2, pv_dummy IN VARCHAR2, pv_request_id IN VARCHAR2, pv_rundate IN VARCHAR2
                         , pv_style IN VARCHAR2);
END XXD_RMS_ITEM_PUBLISH_PKG;
/
