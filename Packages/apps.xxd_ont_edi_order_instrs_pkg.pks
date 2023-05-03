--
-- XXD_ONT_EDI_ORDER_INSTRS_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_EDI_ORDER_INSTRS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_EDI_ORDER_INSTRS_PKG
    * Design       : This package is used for creating/attaching shipping/packing/pick ticket
    *                Instructions for EDI Orders
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 14-Feb-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    gn_user_id    NUMBER := fnd_global.user_id;
    gn_login_id   NUMBER := fnd_global.login_id;

    PROCEDURE create_attach_documents (
        x_errbuf                     OUT NOCOPY VARCHAR2,
        x_retcode                    OUT NOCOPY VARCHAR2,
        p_org_id                  IN            oe_order_headers_all.org_id%TYPE,
        p_orig_sys_document_ref   IN            oe_order_headers_all.orig_sys_document_ref%TYPE);
END xxd_ont_edi_order_instrs_pkg;
/
