--
-- XXD_INV_ITEM_DTLS_UTILS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_ITEM_DTLS_UTILS_PKG"
AS
    -- ####################################################################################################################
    -- Package      : xxd_inv_item_dtls_utils_pkg
    -- Design       : This package will be used to fetch values required for LOV
    --                in the product move tool. This package will also  search
    --                for order details based on user entered data.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 23-Feb-2021    Infosys              1.0    Initial Version
    -- 24-Aug-2021    Infosys              1.1    Modified to add request to date condtion
    -- 28-Oct-2021    Infosys              2.0    Modified to include fetch_cancel_reasons procedure
    -- 06-May-2022    Infosys              3.0    Modified to include search page
    -- 20-Jun-2022    Infosys              3.1    Modified for Genesis CCR
    -- 07-Oct-2022 Infosys              4.0 Sales manager email id in loopkup
    -- #########################################################################################################################

    --start v3.0
    PROCEDURE get_pmt_warehouse (p_in_user_name IN VARCHAR2, p_in_instance_name IN VARCHAR2, p_out_warehouse OUT CLOB);

    --End v3.0

    PROCEDURE user_validation (p_in_user_email     IN     VARCHAR2,
                               p_out_user_name        OUT VARCHAR2,
                               p_out_brand            OUT VARCHAR2,
                               p_out_ou_id            OUT NUMBER,
                               p_out_salesrep_id      OUT NUMBER,
                               p_out_user_id          OUT NUMBER,
                               --Start changes v1.1
                               p_out_threshold        OUT NUMBER,
                               --End changes v1.1
                               --Start changes v2.0
                               p_out_super_user       OUT VARCHAR2,
                               p_out_ou_name          OUT VARCHAR2,
                               --End changes v2.0
                               --Start changes v4.0
                               p_out_sales_mgr        OUT VARCHAR2,
                               --End changes v4.0
                               p_out_err_msg          OUT VARCHAR2);

    --start v2.0
    PROCEDURE user_email_valid (p_in_user_email IN VARCHAR2, p_in_email_groups IN VARCHAR2, p_out_valid_email OUT VARCHAR2);

    --End v2.0
    PROCEDURE get_brand (p_out_brand OUT SYS_REFCURSOR);

    PROCEDURE get_warehouse (p_in_ou_id        IN     NUMBER,
                             p_out_warehouse      OUT SYS_REFCURSOR);

    --start ver3.1 perf fix
    PROCEDURE styl_col_with_brand (p_in_brand IN VARCHAR2, p_in_warehouse IN VARCHAR2, p_in_style IN VARCHAR2
                                   , p_out_style_clr OUT SYS_REFCURSOR);

    --End ver3.1

    PROCEDURE get_style_color (p_in_brand IN VARCHAR2, p_in_warehouse IN VARCHAR2, p_in_style IN VARCHAR2
                               , p_out_style_clr OUT SYS_REFCURSOR);

    PROCEDURE get_so_details (p_in_brand IN VARCHAR2, p_in_so_num IN VARCHAR2, p_in_so_cust_num IN VARCHAR2
                              , p_in_so_num_b2b IN VARCHAR2, p_in_ou_id IN NUMBER, p_out_so_dtls OUT SYS_REFCURSOR);

    PROCEDURE get_customer (p_in_cus_name_num IN VARCHAR2, p_in_brand IN VARCHAR2, p_out_customer OUT SYS_REFCURSOR);

    --Start changes v2.0
    PROCEDURE get_salesrep_name (p_in_salesrep_id      IN     NUMBER,
                                 p_out_salesrep_name      OUT VARCHAR2);
--End changes v2.0
END xxd_inv_item_dtls_utils_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_INV_ITEM_DTLS_UTILS_PKG TO XXORDS
/
