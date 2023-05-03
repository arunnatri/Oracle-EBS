--
-- XXD_PO_REQ_IFACE_ERR_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_REQ_IFACE_ERR_PKG"
AS
    /*************************************************************************************
    * Package         : XXD_PO_REQ_IFACE_ERR_PKG
    * Description     : This package is used for PO Requistion Interface Error Report
    * Notes           :
    * Modification    :
    *-------------------------------------------------------------------------------------
    * Date         Version#      Name                       Description
    *-------------------------------------------------------------------------------------
    * 21-MAY-2020  1.0           Aravind Kannuri            Initial Version for CCR0007333
    *
    ***************************************************************************************/

    p_dest_org_id        NUMBER;
    p_brand              VARCHAR2 (30);
    p_import_source      VARCHAR2 (100);
    p_requisition_type   VARCHAR2 (100);
    p_preparer_id        NUMBER;
    p_buyer_id           NUMBER;
    p_need_by_dt_from    VARCHAR2 (50);
    p_need_by_dt_to      VARCHAR2 (50);
    p_creation_dt_from   VARCHAR2 (50);
    p_creation_dt_to     VARCHAR2 (50);
    p_vendor_id          NUMBER;
    p_vendor_site_id     NUMBER;
    p_iface_batch_id     NUMBER;
    p_send_email         VARCHAR2 (1);

    FUNCTION submit_bursting
        RETURN BOOLEAN;
END XXD_PO_REQ_IFACE_ERR_PKG;
/
