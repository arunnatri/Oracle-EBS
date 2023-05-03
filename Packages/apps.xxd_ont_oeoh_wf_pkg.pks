--
-- XXD_ONT_OEOH_WF_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_OEOH_WF_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_OEOH_WF_PKG
    * Design       : This package will be called from OEOH Workflow
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 10-Apr-2018  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE apply_hold (itemtype IN VARCHAR2, itemkey IN VARCHAR2, actid IN NUMBER
                          , funcmode IN VARCHAR2, resultout IN OUT VARCHAR2);
END xxd_ont_oeoh_wf_pkg;
/
