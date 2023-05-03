--
-- XXD_INV_UPC_DECKERS_PK  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_UPC_DECKERS_PK"
    AUTHID CURRENT_USER
AS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Project         : Inventory Product Report
    --  Description     : Package for Inventory Product Report
    --  Module          : xxd_inv_upc_deckers_pk
    --  File            : xxd_inv_upc_deckers_pk.pks
    --  Schema          : APPS
    --  Date            : 01-FEB-2016
    --  Version         : 1.0
    --  Author(s)       : Rakesh Dudani [ Suneratech Consulting]
    --  Purpose         : Package used to generate the Inventory Product Report based on the
    --                    input parameters and return output in excel format.
    --  dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                  Description
    --  ----------      --------------      -----   --------------------    ------------------
    --  01-FEB-2016     Rakesh Dudani       1.0                             Initial Version
    --
    --
    --  ###################################################################################

    PROCEDURE run_upc_report (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_cur_season IN VARCHAR2, p_prod_class IN VARCHAR2, p_prod_group IN VARCHAR2, p_brand IN VARCHAR2, p_style IN VARCHAR2, p_color IN VARCHAR2, p_upc IN VARCHAR2
                              , p_ean IN VARCHAR2);
END xxd_inv_upc_deckers_pk;
/
