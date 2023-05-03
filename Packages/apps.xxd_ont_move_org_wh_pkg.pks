--
-- XXD_ONT_MOVE_ORG_WH_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_MOVE_ORG_WH_PKG"
AS
    /*******************************************************************************************
       File Name : APPS.XXD_ONT_MOVE_ORG_WH_PKG

       Created On   : 09-Mar-2017

       Created By   : Arun N Murthy

       Purpose      : This program will be used to update warehouse on the orders
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 09-Mar-2018  1.0        Arun Murthy            Initial Version
    -- 14-Feb-2022  1.1        Jayarajan A K          Updated for US Inv Org Move CCR0009841
    ******************************************************************************************/

    PROCEDURE proc_extract_data (pv_as_of_date IN VARCHAR2, pn_from_shp_frm_org_id IN NUMBER, pv_schdl_status IN VARCHAR2
                                 , pn_from_ord_no IN NUMBER, pv_brand IN VARCHAR2, pn_org_id IN NUMBER);

    PROCEDURE proc_process_order (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pv_debug VARCHAR2
                                  , pn_hdr_batch_id NUMBER, --                                 pn_parent_request_id   IN NUMBER,
                                                            pn_to_shp_frm_org_id IN NUMBER, pv_schdl_status IN VARCHAR2);

    PROCEDURE load_main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pv_brand IN VARCHAR2, pn_org_id IN NUMBER, pv_as_of_date IN VARCHAR2, pn_from_shp_frm_org_id IN NUMBER, pn_to_shp_frm_org_id IN NUMBER, pv_schdl_status IN VARCHAR2, pn_from_ord_no IN NUMBER, p_no_of_process IN NUMBER, pv_reprocess IN VARCHAR2, p_debug_flag IN VARCHAR2, p_division_flag IN VARCHAR2, --Start changes v1.1
                                                                                                                                                                                                                                                                                                                                                                                               p_deptmnt_flag IN VARCHAR2, p_class_flag IN VARCHAR2
                         , p_subclass_flag IN VARCHAR2);    --End changes v1.1
END;
/
