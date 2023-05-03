--
-- XXD_ONT_OEOL_WF_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_OEOL_WF_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_OEOL_WF_PKG
    * Design       : This package will be called from OEOL Workflow
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 21-Feb-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE xxd_ont_validate_order_line (itemtype    IN     VARCHAR2,
                                           itemkey     IN     VARCHAR2,
                                           actid       IN     NUMBER,
                                           funcmode    IN     VARCHAR2,
                                           resultout   IN OUT VARCHAR2);
END xxd_ont_oeol_wf_pkg;
/
