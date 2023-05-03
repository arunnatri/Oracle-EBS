--
-- XXDO_AP_REQ_ACCRUAL_UPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AP_REQ_ACCRUAL_UPD_PKG"
AS
    /******************************************************************************
       NAME: SAP_AP_REQ_ACCRUAL_UPD_PKG
      This package is called from porgcon.sql
      Program NAme = Create Releases
       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       06/08/2011     Shibu        1. Created this package for AP accrual acount update at the time of Requisition Import.
       v1.1      12/DEC/2014   BT Technology Team  Retrofit for BT project
    ******************************************************************************/
    FUNCTION get_accrual_seg (p_req_dist_id   NUMBER,
                              p_org_id        NUMBER,
                              p_col           VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_do_accrual_account (p_inv_org_id IN NUMBER, p_item_id IN NUMBER, p_cc_id IN NUMBER
                                     , p_segment2 IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION xxdo_get_item_details (pv_style IN VARCHAR2, pn_inventory_item_id NUMBER, pv_detail IN VARCHAR2)
        RETURN VARCHAR2;

    /* Added by Srinath*/
    FUNCTION xxdo_get_po_num (pn_fty_invc_num IN VARCHAR2)
        RETURN VARCHAR2;

    /* End of Change */
    PROCEDURE main (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER
                    , p_start_date IN VARCHAR2, p_end_date IN VARCHAR2);
END XXDO_AP_REQ_ACCRUAL_UPD_PKG;
/
