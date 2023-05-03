--
-- XXD_PO_REQ_APPROVAL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_REQ_APPROVAL_PKG"
AS
    /******************************************************************************
       NAME: XXD_REQ_APPROVAL_PKG

       Ver        Date        Author                       Description
       ---------  ----------  ---------------           ------------------------------------
       1.0        14/10/2014  BT Technology Team        Function to return approval list ( AME)
       1.1        20/07/2015  BT Technology Team        Modified for CR 57
       1.2       11/07/2019  Srinath Siricilla          CCR0008214
    ******************************************************************************/
    FUNCTION get_supervisor (p_per_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_apprlist (p_trx_id IN NUMBER)
        RETURN xxd_po_req_approval_pkg.out_rec
        PIPELINED;

    TYPE out_record IS RECORD
    (
        approver    NUMBER
    );

    TYPE out_rec IS TABLE OF out_record;

    out_approver_rec               out_record;
    out_approver_rec_final         out_rec := out_rec (NULL);

    --Start Added for CR 57 by BT Technology Team on 20-Jul-15
    FUNCTION get_req_eligible (p_transaction_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_post_apprvrlist (p_trx_id IN NUMBER)
        RETURN xxd_po_req_approval_pkg.out_rec_list
        PIPELINED;

    TYPE out_record_list IS RECORD
    (
        approver_id    NUMBER
    );

    TYPE out_rec_list IS TABLE OF out_record_list;

    out_approver_rec_list          out_record_list;
    out_approver_rec_final_list    out_rec_list := out_rec_list (NULL);

    --End Added for CR 57 by BT Technology Team on 20-Jul-15
    FUNCTION can_requestor_approve (p_transaction_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_apac_finance_apprlist (p_trx_id IN NUMBER)
        RETURN xxd_po_req_approval_pkg.out_apac_rec_list
        PIPELINED;

    TYPE out_apac_record_list IS RECORD
    (
        approver_id    NUMBER
    );

    TYPE out_apac_rec_list IS TABLE OF out_apac_record_list;

    out_apac_approver_rec_list     out_apac_record_list;
    out_apac_appr_rec_final_list   out_apac_rec_list
                                       := out_apac_rec_list (NULL);

    FUNCTION get_apac_finance_apprlimit (p_trx_id IN NUMBER)
        RETURN VARCHAR2;

    -- Added function as per change 1.2

    FUNCTION is_req_auto_approved (p_trx_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_unit_price (p_trx_id IN NUMBER, p_req_line_id IN NUMBER)
        RETURN NUMBER;
END xxd_po_req_approval_pkg;
/
