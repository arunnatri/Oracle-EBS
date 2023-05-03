--
-- XXD_AR_CONS_INV_GE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_CONS_INV_GE_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_AR_CONS_GE_PKG
    * Design       : This package is used for GlobalE Consolidated Invoice Printing
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 03-APR-2020  1.0       Srinath Siricilla       Initial Version
    ******************************************************************************************/
    p_operating_unit    VARCHAR2 (200);
    p_Reprint           VARCHAR2 (200);
    p_warehouse         VARCHAR2 (200);
    p_trx_date_from     VARCHAR2 (200);
    p_trx_date_to       VARCHAR2 (200);
    p_send_email        VARCHAR2 (1);
    p_cons_inv_number   VARCHAR2 (200);
    p_cr_date_from      VARCHAR2 (200);
    p_cr_date_to        VARCHAR2 (200);
    p_brand             VARCHAR2 (200);
    p_cc_email          VARCHAR2 (200);
    p_regenerate        VARCHAR2 (200);
    p_line_details      VARCHAR2 (200);

    FUNCTION get_cons_seq (ln_inv_seq IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION directory_path
        RETURN VARCHAR2;

    FUNCTION get_ar_ge_cons_bill_to (p_warehouse IN VARCHAR2, x_name OUT VARCHAR2, x_add_line1 OUT VARCHAR2, x_add_line2 OUT VARCHAR2, x_add_line3 OUT VARCHAR2, x_add_line4 OUT VARCHAR2, x_company_number OUT VARCHAR2, x_vat_number OUT VARCHAR2, x_email_address OUT VARCHAR2
                                     , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_ar_ge_cons_bill_from (p_warehouse IN VARCHAR2, x_name OUT VARCHAR2, x_add_line1 OUT VARCHAR2, x_add_line2 OUT VARCHAR2, x_add_line3 OUT VARCHAR2, x_add_line4 OUT VARCHAR2, x_company_number OUT VARCHAR2, x_vat_number OUT VARCHAR2, x_email_address OUT VARCHAR2
                                       , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_ar_ge_cons_ship_from (p_warehouse   IN     VARCHAR2,
                                       x_name           OUT VARCHAR2,
                                       x_add_line1      OUT VARCHAR2,
                                       x_add_line2      OUT VARCHAR2,
                                       x_add_line3      OUT VARCHAR2,
                                       x_add_line4      OUT VARCHAR2,
                                       x_add_line5      OUT VARCHAR2,
                                       x_ret_msg        OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_ar_ge_cons_ship_to (p_warehouse   IN     VARCHAR2,
                                     x_name           OUT VARCHAR2,
                                     x_add_line1      OUT VARCHAR2,
                                     x_add_line2      OUT VARCHAR2,
                                     x_add_line3      OUT VARCHAR2,
                                     x_add_line4      OUT VARCHAR2,
                                     x_add_line5      OUT VARCHAR2,
                                     x_ret_msg        OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_ar_ge_cons_taxstmt (p_warehouse IN VARCHAR2, x_ship_to_country OUT VARCHAR2, x_tax_stmt OUT VARCHAR2
                                     , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_ar_ge_cons_taxrate (p_warehouse IN VARCHAR2, x_ship_to_country OUT VARCHAR2, x_tax_rate OUT VARCHAR2
                                     , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION get_amount (p_customer_trx_id IN NUMBER, p_line_number IN NUMBER, p_line_type IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION insert_data
        RETURN BOOLEAN;

    FUNCTION submit_bursting
        RETURN BOOLEAN;
END XXD_AR_CONS_INV_GE_PKG;
/
