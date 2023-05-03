--
-- XXD_GL_OPEN_RETINV_JOURNAL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_OPEN_RETINV_JOURNAL_PKG"
AS
    /****************************************************************************************
       * Package      : XXD_GL_OPEN_RETINV_JOURNAL_PKG
       * Design       : This package will be used to CREATE journal entries for the open retail return inv
       * Notes        :
    * Modification :
       -- ======================================================================================
       -- Date         Version#   Name                    Comments
       -- ======================================================================================
       -- 08-Sep-2021  1.0        Showkath Ali            Initial Version
       *******************************************************************************************/



    -- ======================================================================================
    -- This procedure is used to generate the report
    -- ======================================================================================
    PROCEDURE MAIN (pv_errbuf OUT VARCHAR2, pn_retcode OUT NUMBER, pn_org_id IN VARCHAR2
                    , pv_period_end_date IN VARCHAR2, pv_order_created_from IN VARCHAR2, pv_order_created_to IN VARCHAR2);
END XXD_GL_OPEN_RETINV_JOURNAL_PKG;
/
