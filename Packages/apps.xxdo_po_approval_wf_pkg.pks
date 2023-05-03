--
-- XXDO_PO_APPROVAL_WF_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_PO_APPROVAL_WF_PKG
/**********************************************************************************************************

    File Name    : XXDO_PO_APPROVAL_WF_PKG

    Created On   : 15-DEC-2014

    Created By   : BT Technology Team

    Purpose      : This  package is to provide individual functions and procedures for PO Print.
   ***********************************************************************************************************
   Modification History:
   Version   SCN#        By                        Date                     Comments
  1.0              BT Technology Team          15-Dec-2014               Base Version
    **********************************************************************************************************/

AS
    PROCEDURE IS_TRADE_PO (itemtype    IN            VARCHAR2,
                           itemkey     IN            VARCHAR2,
                           actid       IN            NUMBER,
                           funcmode    IN            VARCHAR2,
                           resultout      OUT NOCOPY VARCHAR2);



    FUNCTION HEADER_ATTACHMENT (p_po_header_id NUMBER)
        RETURN CLOB;

    FUNCTION LINE_ATTACHMENT (p_po_line_id NUMBER, p_note_to_vendor VARCHAR2)
        RETURN CLOB;

    FUNCTION GET_PO_CATEGORY (p_po_header_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION GET_TERMS_N_CONDITIONS (p_po_ship_to_id   NUMBER,
                                     p_po_org_id       NUMBER)
        RETURN CLOB;
END XXDO_PO_APPROVAL_WF_PKG;
/
