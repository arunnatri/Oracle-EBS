--
-- XXD_AP_INV_APPROVAL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_ap_inv_approval_pkg
AS
    /******************************************************************************
       NAME: XXD_AP_INV_APPROVAL_PKG

       Ver        Date        Author                       Description
       ---------  ----------  ---------------           ------------------------------------
       1.0        14/10/2014  BT Technology Team        Function to return approval list ( AME  )
    ******************************************************************************/
    FUNCTION get_supervisor (p_per_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_apprlist (p_trx_id IN NUMBER)
        RETURN xxd_ap_inv_approval_pkg.out_rec
        PIPELINED;

    TYPE out_record IS RECORD
    (
        approver    NUMBER
    );

    TYPE out_rec IS TABLE OF out_record;

    out_approver_rec         out_record;
    out_approver_rec_final   out_rec := out_rec (NULL);
END xxd_ap_inv_approval_pkg;
/
