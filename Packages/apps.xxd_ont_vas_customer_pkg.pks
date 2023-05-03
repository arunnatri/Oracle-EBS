--
-- XXD_ONT_VAS_CUSTOMER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XXD_ONT_CUST_HEAD_INFO_TBL_TYP (Type)
--   XXD_ONT_CUST_SHIP_INFO_TBL_TYP (Type)
--   XXD_ONT_VAS_AGNMT_DTLS_TBL_TYP (Type)
--   XXD_ONT_VAS_SITE_USE_TBL_TYP (Type)
--
/* Formatted on 4/26/2023 4:24:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_VAS_CUSTOMER_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_VAS_CUSTOMER_PKG
    * Design       : This package will be used for VAS Automation.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-JUL-2020  1.0        Gaurav Joshi           Initial Version
    -- 15-jul-2022  1.1        Gaurav Joshi           CCR0010026
    ******************************************************************************************/
    --  This procedure is used to save label and routing requirment
    -- for the given cutsomer  from customer info page
    PROCEDURE save_customer_info (p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_cust_hdr_info_record IN xxdo.xxd_ont_cust_head_info_tbl_typ, x_ret_status OUT NOCOPY VARCHAR2
                                  , x_err_msg OUT NOCOPY VARCHAR2);

    --  This procedure is used to save label and routing requirment
    -- for the given cutsomer and site from customer site page
    PROCEDURE save_customersite_info (p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_custsite_hdr_info_record IN xxdo.xxd_ont_cust_ship_info_tbl_typ, x_ret_status OUT NOCOPY VARCHAR2
                                      , x_err_msg OUT NOCOPY VARCHAR2);

    --  This procedure is used to assign/modify/delete vas code for customer info page
    PROCEDURE assign_vas_to_customer (
        p_org_id                   IN            NUMBER,
        p_resp_id                  IN            NUMBER,
        p_resp_app_id              IN            NUMBER,
        p_user_id                  IN            NUMBER,
        p_mode                     IN            VARCHAR2,
        p_cust_vas_assign_record   IN            xxdo.xxd_ont_vas_agnmt_dtls_tbl_typ,
        x_ret_status                  OUT NOCOPY VARCHAR2,
        x_err_msg                     OUT NOCOPY VARCHAR2);

    --  This procedure is used to update customer info like freight term/ship via from customer info page
    PROCEDURE update_customer_account (p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_cust_account_id IN NUMBER, p_ship_via IN VARCHAR2, p_freight_term IN VARCHAR2, p_gs1_128format IN VARCHAR2, p_freight_account IN VARCHAR2
                                       , p_print_cc IN VARCHAR2, x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2);

    --  This procedure is used to update lable format/ print cc and freight account on
    -- hz_cust_acct_sites_all
    PROCEDURE update_cust_acct_site (p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_cust_acct_site_Id IN NUMBER, p_gs1_128format IN VARCHAR2, p_freight_account IN VARCHAR2, p_print_cc IN VARCHAR2, x_ret_status OUT NOCOPY VARCHAR2
                                     , x_err_msg OUT NOCOPY VARCHAR2);

    --  This procedure is used to update  site freight terms and ship method
    -- hz_cust_site_uses_all
    PROCEDURE update_cust_site_uses (p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_site_use_id IN NUMBER, p_cust_acct_site_Id IN NUMBER, p_ship_via IN VARCHAR2, p_freight_term IN VARCHAR2, x_ret_status OUT NOCOPY VARCHAR2
                                     , x_err_msg OUT NOCOPY VARCHAR2);

    PROCEDURE pre_pack_order (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_order_number IN NUMBER, p_override_assortment IN VARCHAR2, p_assortment1 IN NUMBER, p_assortment1_line_id IN VARCHAR2, p_assortment2 IN NUMBER, p_assortment2_line_id IN VARCHAR2, p_assortment3 IN NUMBER, p_assortment3_line_id IN VARCHAR2, p_assortment4 IN NUMBER, p_assortment4_line_id IN VARCHAR2, p_assortment5 IN NUMBER, p_assortment5_line_id IN VARCHAR2, p_assortment6 IN NUMBER
                              , p_assortment6_line_id IN VARCHAR2);

    -- ver 1.1
    PROCEDURE assign_vas_at_site_style_mc_sc_lvl (
        p_org_id                   IN            NUMBER,
        p_resp_id                  IN            NUMBER,
        p_resp_app_id              IN            NUMBER,
        p_user_id                  IN            NUMBER,
        p_cust_account_id          IN            NUMBER,
        p_site_use_ids_record      IN            xxdo.xxd_ont_vas_site_use_tbl_typ,
        p_cust_vas_assign_record   IN            xxdo.xxd_ont_vas_agnmt_dtls_tbl_typ,
        p_mode                     IN            VARCHAR2,
        x_ret_status                  OUT NOCOPY VARCHAR2,
        x_err_msg                     OUT NOCOPY VARCHAR2);
END xxd_ont_vas_customer_pkg;
/
