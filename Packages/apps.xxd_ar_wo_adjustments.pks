--
-- XXD_AR_WO_ADJUSTMENTS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_WO_ADJUSTMENTS"
AS
    --  #########################################################################################
    --  Author(s)       : Tejaswi Gangumala
    --  System          : Oracle Applications
    --  Subsystem       :
    --  Change          : ecom records with "WO", needs adjustments in EBS
    --  Schema          : APPS
    --  Purpose         : This package is used to make adjutments to transactions
    --  Dependency      : N
    --  Change History
    --  --------------
    --  Date            Name                    Ver     Change                  Description
    --  ----------      --------------          -----   --------------------    ---------------------
    --  25-May-2019     Tejaswi Gangumalla       1.0     NA                      Initial Version
    --
    --  #########################################################################################
    PROCEDURE main (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER, pn_org_id IN NUMBER, pv_trx_class IN VARCHAR2, pv_trx_type IN VARCHAR2, pv_cust_trx_id IN NUMBER
                    , pv_reprocess IN VARCHAR2);
END;
/
