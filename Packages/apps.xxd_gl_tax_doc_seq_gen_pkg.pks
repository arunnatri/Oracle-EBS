--
-- XXD_GL_TAX_DOC_SEQ_GEN_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_TAX_DOC_SEQ_GEN_PKG"
AS
    /****************************************************************************************
 * Package      : XXD_GL_TAX_DOC_SEQ_GEN_PKG
 * Design       : This package will be used to generate the GL Tax Authority Document Sequence
 * Notes        :
 * Modification :
 -- ======================================================================================
 -- Date         Version#   Name                    Comments
 -- ======================================================================================
 -- 11-Jan-2022 1.0        Showkath Ali            Initial Version
 ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    pv_ledger_name       NUMBER;
    pv_period_name       VARCHAR2 (50);
    pv_company_segment   VARCHAR2 (20);
    pv_final_mode        VARCHAR2 (20);



    gn_error    CONSTANT NUMBER := 2;

    FUNCTION xml_main (pv_ledger_name IN NUMBER, pv_period_name IN VARCHAR2, pv_company_segment IN VARCHAR2
                       , pv_final_mode IN VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION send_email (PV_FINAL_MODE IN VARCHAR2)
        RETURN BOOLEAN;
END;
/
