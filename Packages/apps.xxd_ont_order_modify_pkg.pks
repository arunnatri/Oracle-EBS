--
-- XXD_ONT_ORDER_MODIFY_PKG  (Package) 
--
--  Dependencies: 
--   XXD_ONT_ORDER_DTLS_TBL_TYP (Synonym)
--   STANDARD (Package)
--   XXD_ONT_ORDER_COPY_TBL_TYPE (Type)
--   XXD_ONT_ORDER_LINES_TBL_TYPE (Type)
--
/* Formatted on 4/26/2023 4:23:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_ORDER_MODIFY_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_ORDER_MODIFY_PKG
    * Design       : This package will be used for modifying the Sales Orders.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-Mar-2020  1.0        Viswanathan Pandian     Initial Version
    -- 09-Apr-2020  2.0        Balavenu                CCR0008870 GSA Project
    -- 01-Sep-2021  2.1        Laltu                   CCR0009521 VAS Code Update
    -- 21-sep-2021  2.2        Gaurav Joshi            CCR0009617 -Auto Split line/copy attachment and copy att16
    -- 04-Jan-2021  2.3        Gaurav Joshi            CCR0009738 - Mutiple changes
   --  10-Jan-2022  2.4        Gaurav Joshi            CCR0009772 - Mass Hold apply
   --  24-Apr-2022  2.5        Gaurav Joshi            CCR0009334- Amazon 855
    -- 01-Oct-2022  1.17      Pardeep Rohilla         CCR0010163 - Update Sales Order Cust_PO_Number
 -- 12-Dec-2022  2.6      Gaurav Joshi            CCR0010360  - PDCTOM-291 - SOMT for Mass Units release to ATP
    ******************************************************************************************/
    PROCEDURE master_prc (x_errbuf              OUT NOCOPY VARCHAR2,
                          x_retcode             OUT NOCOPY VARCHAR2,
                          p_operation_mode   IN            VARCHAR2,
                          p_group_id         IN            NUMBER,
                          p_om_debug         IN            VARCHAR2,
                          p_custom_debug     IN            VARCHAR2);

    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_operation_mode IN VARCHAR2, p_group_id IN NUMBER, p_batch_id IN NUMBER, p_om_debug IN VARCHAR2
                         , p_custom_debug IN VARCHAR2);

    PROCEDURE process_order_prc (
        p_operation_mode       IN            VARCHAR2,
        p_group_id             IN            NUMBER,
        p_org_id               IN            NUMBER,
        p_resp_id              IN            NUMBER,
        p_resp_app_id          IN            NUMBER,
        p_user_id              IN            NUMBER,
        p_order_dtls_tbl_typ   IN            xxd_ont_order_dtls_tbl_typ,
        p_om_debug             IN            VARCHAR2,
        p_custom_debug         IN            VARCHAR2,
        x_ret_status              OUT NOCOPY VARCHAR2,
        x_err_msg                 OUT NOCOPY VARCHAR2);

    /*---------------------------2.0 Start GSA Project-----------------------------------*/

    PROCEDURE xxd_ont_order_mgt_copy_prc (p_ont_ord_copy_tbl xxdo.xxd_ont_order_copy_tbl_type, p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_om_debug IN VARCHAR2, p_custom_debug IN VARCHAR2, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2
                                          , pv_group_id OUT NUMBER);

    PROCEDURE process_book_order_file (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                       , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2);

    PROCEDURE process_cancel_order_file (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                         , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2);

    PROCEDURE process_update_order_file (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                         , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2);

    PROCEDURE book_cancel_order_mast_prc (
        x_errbuf              OUT NOCOPY VARCHAR2,
        x_retcode             OUT NOCOPY VARCHAR2,
        p_operation_mode   IN            VARCHAR2,
        p_group_id         IN            NUMBER,
        p_om_debug         IN            VARCHAR2,
        p_custom_debug     IN            VARCHAR2,
        p_freeAtp_flag     IN            VARCHAR2 DEFAULT 'N'       -- ver 2.3
                                                             );

    PROCEDURE book_cancel_order_child_prc (
        x_errbuf              OUT NOCOPY VARCHAR2,
        x_retcode             OUT NOCOPY VARCHAR2,
        p_operation_mode   IN            VARCHAR2,
        p_group_id         IN            NUMBER,
        p_batch_id         IN            NUMBER,
        p_om_debug         IN            VARCHAR2,
        p_custom_debug     IN            VARCHAR2,
        p_freeAtp_flag     IN            VARCHAR2 DEFAULT 'N'       -- ver 2.3
                                                             );

    PROCEDURE cancel_order_prc (p_group_id       IN NUMBER,
                                p_batch_id       IN NUMBER,
                                p_freeAtp_flag   IN VARCHAR2        -- ver 2.3
                                                            );

    PROCEDURE book_order_prc (p_group_id IN NUMBER, p_batch_id IN NUMBER);



    PROCEDURE submit_book_cancel_updat_order (p_operation_mode IN VARCHAR2, p_group_id IN NUMBER, p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_om_debug IN VARCHAR2, p_custom_debug IN VARCHAR2, p_freeAtp_flag IN VARCHAR2 DEFAULT 'N'
                                              ,                     -- ver 2.3
                                                x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2);

    PROCEDURE copy_sales_order_prc (p_group_id   IN NUMBER,
                                    p_batch_id   IN NUMBER);

    PROCEDURE xxd_ont_order_lines_update (
        p_ont_order_lines_tbl          xxdo.xxd_ont_order_lines_tbl_type,
        p_org_id                IN     NUMBER,
        p_resp_id               IN     NUMBER,
        p_resp_app_id           IN     NUMBER,
        p_user_id               IN     NUMBER,
        p_action                IN     VARCHAR2,
        pv_error_stat              OUT VARCHAR2,
        pv_error_msg               OUT VARCHAR2);

    PROCEDURE xxd_ont_order_delete (
        p_ont_order_lines_tbl          xxdo.xxd_ont_order_lines_tbl_type,
        p_org_id                IN     NUMBER,
        p_resp_id               IN     NUMBER,
        p_resp_app_id           IN     NUMBER,
        p_user_id               IN     NUMBER,
        p_operation_mode        IN     VARCHAR2,
        pv_error_stat              OUT VARCHAR2,
        pv_error_msg               OUT VARCHAR2);

    PROCEDURE update_order_lines_prc (p_group_id IN NUMBER, p_batch_id IN NUMBER, p_freeAtp_flag IN VARCHAR2 DEFAULT 'N' -- ver 2.6
                                                                                                                        );

    /*---------------------------2.0 End GSA Project-----------------------------------*/
    --Start changes for v2.1

    FUNCTION get_vas_code (p_level IN VARCHAR2, p_cust_account_id IN NUMBER, p_site_use_id IN NUMBER
                           , p_style IN VARCHAR2, p_color IN VARCHAR2)
        RETURN VARCHAR2;

    --End changes for v2.1
    -- begin ver 2.2
    PROCEDURE copy_attachment (p_source_pk_value IN VARCHAR2, p_target_pk_value IN VARCHAR2, p_in_entity IN VARCHAR2);

    -- end ver 2.2
    --
    PROCEDURE process_hold_file (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                 , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2);

    PROCEDURE xxd_ont_apply_hold_delete (
        p_ont_order_lines_tbl          xxdo.xxd_ont_order_lines_tbl_type,
        p_org_id                IN     NUMBER,
        p_resp_id               IN     NUMBER,
        p_resp_app_id           IN     NUMBER,
        p_user_id               IN     NUMBER,
        p_operation_mode        IN     VARCHAR2,
        pv_error_stat              OUT VARCHAR2,
        pv_error_msg               OUT VARCHAR2);

    PROCEDURE apply_remove_hold (p_group_id IN NUMBER, p_batch_id IN NUMBER);

    -- begin 2.5

    PROCEDURE process_cancel_order_file855 (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                            , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2);

    PROCEDURE xxd_ont_order_cancel_855 (p_ont_order_lines_tbl xxdo.xxd_ont_order_lines_tbl_type, p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_action IN VARCHAR2, p_group_id IN NUMBER, p_freeAtp_flag IN VARCHAR2, pv_error_stat OUT VARCHAR2
                                        , pv_error_msg OUT VARCHAR2);



    PROCEDURE cancel_order_prc855 (p_group_id IN NUMBER, p_batch_id IN NUMBER, p_freeAtp_flag IN VARCHAR2 -- ver 2.3
                                                                                                         );

    PROCEDURE send855_prc (p_order_header_id   NUMBER,
                           p_group_id          NUMBER,
                           p_batch_id          NUMBER);

    PROCEDURE write_to_855_table (p_order_number NUMBER, p_customer_po_number VARCHAR2, p_acct_num VARCHAR2
                                  , p_party_name VARCHAR2);

    --End ver 2.5

    -- Begin 1.17  CCR0010163 (Update PO Number)

    PROCEDURE process_update_headers_file (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                           , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2);


    PROCEDURE xxd_ont_update_headers_cust_po_num (p_ont_update_order_tbl xxdo.xxd_ont_order_lines_tbl_type, p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_action IN VARCHAR2
                                                  , p_group_id IN NUMBER, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2);

    PROCEDURE validate_update_headers_prc (p_group_id   IN NUMBER,
                                           p_batch_id   IN NUMBER);

    PROCEDURE update_headers_cust_po_prc (p_group_id   IN NUMBER,
                                          p_batch_id   IN NUMBER);

    PROCEDURE xxd_ont_update_header_delete (
        p_ont_order_lines_tbl          xxdo.xxd_ont_order_lines_tbl_type,
        p_org_id                IN     NUMBER,
        p_resp_id               IN     NUMBER,
        p_resp_app_id           IN     NUMBER,
        p_user_id               IN     NUMBER,
        p_operation_mode        IN     VARCHAR2,
        pv_error_stat              OUT VARCHAR2,
        pv_error_msg               OUT VARCHAR2);
-- End 1.17  CCR0010163 (Update PO Number)

END xxd_ont_order_modify_pkg;
/
