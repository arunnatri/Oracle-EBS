--
-- XXD_PO_COPY_PKG  (Package) 
--
--  Dependencies: 
--   XXD_PO_COPY_COLOR (Type)
--   XXD_PO_COPY_STYLE (Type)
--   XXD_PO_LINE_TYPE (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_COPY_PKG"
AS
    /*******************************************************************************
       * Program Name : xxd_po_copy_pkg
       * Language     : PL/SQL
       * Description  : This package is used by PO copy form
       *
       * History      :
       *
       * WHO            WHAT              Desc                             WHEN
       * -------------- ---------------------------------------------- ---------------
       * BT Technology          1.0 - Initial Version                        Feb/15/2015
       * Bala Murugesan         1.1 - Modified to add logic to copy/move
       *                              PO to a new warehouse;                  Mar/03/2017
       *                              Changes identified by
       *                              PO_COPY_TO_NEW_ORG
    * Infosys                1.6 - Modifed for CCR0007264; IDENTIFIED by CCR0007264
    *                              Changed the logic to create new Requisition 28/05/2018
    *                              before adding or creating new PO lines
       * --------------------------------------------------------------------------- */
    gv_source_code                          VARCHAR2 (20) := 'PO_Copy_Form'; -- CCR0007264
    gbatcho2f_user                          VARCHAR2 (50) := 'BATCH.O2F'; -- CCR0007264
    gbatchp2p_user                          VARCHAR2 (50) := 'BATCH.P2P'; -- CCR0007264
    gv_order_entry                          VARCHAR2 (50) := 'ORDER ENTRY'; -- CCR0007264
    gv_responsibility_name_so      CONSTANT VARCHAR2 (240)
        := 'Deckers Order Management User' ;                     -- CCR0007264
    gv_mo_profile_option_name      CONSTANT VARCHAR2 (240)
                                                := 'MO: Security Profile' ; -- CCR0007264
    gv_mo_profile_option_name_so   CONSTANT VARCHAR2 (240)
                                                := 'MO: Operating Unit' ; -- CCR0007264

    PROCEDURE XXD_CANCEL_PO_LINES (P_HEADER_ID    IN     NUMBER,
                                   p_style        IN     xxd_po_copy_style,
                                   p_color        IN     xxd_po_copy_color,
                                   P_ERROR_CODE      OUT VARCHAR2,
                                   P_PO_LINE_ID      OUT xxd_po_line_TYPE);

    PROCEDURE XXD_CREATE_PO (
        P_HEADER_ID          IN            NUMBER,
        P_VENDOR_ID          IN            NUMBER,
        P_VENDOR_SITE_ID     IN            NUMBER,
        P_PO_LINE_ID         IN            xxd_po_line_TYPE,
        P_BATCH_ID           IN            VARCHAR2,
        P_NEW_DOCUMENT_NUM      OUT        VARCHAR2,
        P_ERROR_CODE            OUT NOCOPY VARCHAR2,
        P_NEW_INV_ORG_ID     IN            NUMBER DEFAULT NULL); -- PO_COPY_TO_NEW_ORG- Start-End

    PROCEDURE XXD_ADD_PO_LINES (P_HEADER_ID IN NUMBER, V_MOVE_PO_HEADER_ID IN NUMBER, P_PO_LINE_ID IN xxd_po_line_TYPE
                                , P_BATCH_ID IN VARCHAR2, P_ERROR_CODE OUT NOCOPY VARCHAR2, P_NEW_INV_ORG_ID IN NUMBER DEFAULT NULL);
END xxd_po_copy_pkg;
/
