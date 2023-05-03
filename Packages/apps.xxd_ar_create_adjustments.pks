--
-- XXD_AR_CREATE_ADJUSTMENTS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_CREATE_ADJUSTMENTS"
AS
    /****************************************************************************************
     * Package      : XXD_AR_CREATE_ADJUSTMENTS
     * Design       : This package will be used for tax rounding error in EBS over/under charging customers / AR - Program to Create Adjustment entries related to eComm Rounding Issues
     * Notes        :
     * Modification :
     -- ======================================================================================
     -- Date         Version#   Name                    Comments
     -- ======================================================================================
     -- 08-Aug-2020  1.0        Tejaswi Gangumalla      Initial Version
     ******************************************************************************************/
    p_org_id          NUMBER;
    pv_date_from      VARCHAR2 (200);
    pv_date_to        VARCHAR2 (200);
    pv_gl_date_from   VARCHAR2 (200);
    pv_gl_date_to     VARCHAR2 (200);
    pn_trx_number     VARCHAR2 (200);
    pv_report_mode    VARCHAR2 (50);

    FUNCTION before_report
        RETURN BOOLEAN;
END;
/
