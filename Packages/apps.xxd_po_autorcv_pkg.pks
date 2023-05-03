--
-- XXD_PO_AUTORCV_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_AUTORCV_PKG"
AS
    PROCEDURE do_auto_receive_process (p_error_stat OUT VARCHAR2, p_error_msg OUT VARCHAR2, p_org_id IN NUMBER, p_asn_id IN NUMBER:= NULL, p_rma_id IN NUMBER:= NULL, p_dummy IN VARCHAR:= NULL
                                       , p_to_date IN DATE:= NULL);
END XXD_PO_AUTORCV_PKG;
/
