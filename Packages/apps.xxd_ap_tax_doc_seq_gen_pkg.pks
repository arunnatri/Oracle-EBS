--
-- XXD_AP_TAX_DOC_SEQ_GEN_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_TAX_DOC_SEQ_GEN_PKG"
AS
    /****************************************************************************************
 * Package      : XXD_AP_TAX_DOC_SEQ_GEN_PKG
 * Design       : This package will be used to generate the AP Tax Authority Document Sequence
 * Notes        :
 * Modification :
 -- ======================================================================================
 -- Date         Version#   Name                    Comments
 -- ======================================================================================
 -- 03-Jan-2022 1.0        Showkath Ali            Initial Version
 ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    pn_operating_unit   NUMBER;
    pv_period_name      VARCHAR2 (50);
    pv_final_mode       VARCHAR2 (20);



    gn_error   CONSTANT NUMBER := 2;

    FUNCTION xml_main (pn_operating_unit IN NUMBER, pv_period_name IN VARCHAR2, pv_final_mode IN VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION send_email (PV_FINAL_MODE IN VARCHAR2)
        RETURN BOOLEAN;
END;
/
