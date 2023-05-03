--
-- XXD_AR_TAX_DOC_SEQ_GEN_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_TAX_DOC_SEQ_GEN_PKG"
AS
    /****************************************************************************************
 * Package      : XXD_AR_TAX_DOC_SEQ_GEN_PKG
 * Design       : This package will be used to generate the AR Tax Authority Document Sequence
 * Notes        :
 * Modification :
 -- ======================================================================================
 -- Date         Version#   Name                    Comments
 -- ======================================================================================
 -- 15-Jun-2022  1.0        Showkath Ali            Initial Version
 ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    pn_operating_unit     NUMBER;
    pv_period_name        VARCHAR2 (50);
    pv_final_mode         VARCHAR2 (20);
    pv_transaction_type   NUMBER;

    gn_error     CONSTANT NUMBER := 2;

    FUNCTION xml_main (pn_operating_unit IN NUMBER, pv_period_name IN VARCHAR2, pv_final_mode IN VARCHAR2
                       , pv_transaction_type IN NUMBER)
        RETURN BOOLEAN;

    FUNCTION send_email (PV_FINAL_MODE IN VARCHAR2)
        RETURN BOOLEAN;
END;
/
