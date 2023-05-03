--
-- XXD_PLM_ITEM_STG_UPD  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PLM_ITEM_STG_UPD"
IS
    /**********************************************************************************************************
       file name    : XXD_PLM_ITEM_STG_UPD.pkb
       created on   : 01-JAN-2017
       created by   : INFOSYS
       purpose      : package specification used for the following
                              1. to
      ***********************************************************************************************************
      Modification history:
     *****************************************************************************
         NAME:        XXD_PLM_ITEM_STG_UPD
         PURPOSE:

         REVISIONS:
         Version        Date        Author           Description
         ---------  ----------  ---------------  ------------------------------------
         1.0         08-JAN-2017     INFOSYS       1. Created this package Specification.
    *********************************************************************
    *********************************************************************/
    PROCEDURE update_stg_tab_active_items (pv_reterror OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_operation IN VARCHAR2, pv_style IN VARCHAR2, pv_color IN VARCHAR2, pn_cleanup_days IN NUMBER
                                           , pv_commit IN VARCHAR2);
END XXD_PLM_ITEM_STG_UPD;
/
