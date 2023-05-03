--
-- XXD_PO_RCO_APPROVAL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_RCO_APPROVAL_PKG"
AS
    /******************************************************************************
       NAME: xxd_po_rco_approval_pkg

       Ver          Date            Author                       Description
       ---------  ----------    ---------------           ------------------------------------
      1.0         14/10/2014    BT Technology Team        Function to return approval list ( AME  )
      1.1         01/03.2018    Tejswi Gangumalla         Added function get_post_apprvrlist to get buyer approval list based on changed quantity
      1.1         01/03.2018    Tejswi Gangumalla         Added function get_req_eligible to check buyer approval eligibility based on changed quantity
      1.1         01/03.2018    Tejswi Gangumalla         Added function get_apac_finance_apprlist to get APAC finance approval listbased on changed quantity
      1.1         01/03.2018    Tejswi Gangumalla         Added function get_apac_finance_apprlimit to check APAC finance approval eligibility based on changed quantity
      1.1         01/03.2018    Tejswi Gangumalla         Added function change_po_buyer to modify buyer name on PO when buyer approver is changed
      1.2         21/05/2018    Infosys                   Modified for CCR0007258 ; IDENTIFIED BY CCR0007258
                                                          Approval List is not Getting Generated when there were multiple lines in Requisition.
      1.3         13/11/2019    Srinath Siricilla         CCR0008214
    **************************************************************************************************************************************************/
    FUNCTION get_supervisor (p_per_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_apprlist (p_trx_id IN NUMBER)
        RETURN xxd_po_rco_approval_pkg.out_rec
        PIPELINED;

    TYPE out_record IS RECORD
    (
        approver    NUMBER
    );

    TYPE out_rec IS TABLE OF out_record;

    out_approver_rec               out_record;
    out_approver_rec_final         out_rec := out_rec (NULL);

    FUNCTION get_post_apprvrlist (p_trx_id IN NUMBER)
        RETURN xxd_po_rco_approval_pkg.out_rec_list
        PIPELINED;

    TYPE out_record_list IS RECORD
    (
        approver_id    NUMBER
    );

    TYPE out_rec_list IS TABLE OF out_record_list;

    out_approver_rec_list          out_record_list;
    out_approver_rec_final_list    out_rec_list := out_rec_list (NULL);

    FUNCTION get_apac_finance_apprlist (p_trx_id IN NUMBER)
        RETURN xxd_po_rco_approval_pkg.out_apac_rec_list
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

    FUNCTION change_po_buyer (p_trx_id IN NUMBER)
        RETURN xxd_po_rco_approval_pkg.out_rec_list
        PIPELINED;

    TYPE out_newbuyer_record_list IS RECORD
    (
        approver_id    NUMBER
    );

    TYPE out_newbuyer_rec_list IS TABLE OF out_record_list;

    out_newbuyer_rec_list          out_record_list;
    out_newbuyer_rec_final_list    out_rec_list := out_rec_list (NULL);

    PROCEDURE change_buyer (pn_po_header_id    NUMBER,
                            pn_new_buyer_id    NUMBER,
                            pn_req_header_id   NUMBER);

    PROCEDURE po_approval (pn_po_header_id    NUMBER,
                           pn_new_buyer_id    NUMBER,
                           pn_req_header_id   NUMBER);

    FUNCTION get_req_eligible (p_transaction_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_req_buyer_change_eligible (p_transaction_id NUMBER) --Added Function CCR0007258
        RETURN NUMBER;

    -- Added function as per change 1.3

    FUNCTION is_req_auto_approved (p_trx_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_unit_price (p_trx_id IN NUMBER)
        RETURN NUMBER;
END xxd_po_rco_approval_pkg;
/
