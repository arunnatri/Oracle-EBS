--
-- XXD_ONT_GENESIS_PROC_ORD_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   GEN_TBL_TYPE (Type)
--   OE_ORDER_PUB (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_GENESIS_PROC_ORD_PKG"
AS
    -- ####################################################################################################################
    -- Package      : xxd_ont_genesis_proc_ord_pkg
    -- Design       : This package will be used to fetch values required for LOV
    --                in the genesis tool. This package will also  search
    --                for order details based on user entered data.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 28-Jun-2021    Infosys              1.0    Initial Version
    -- 12-Sep-2022    Infosys              2.0    New API for transaction history
    --13-Jan-2023  Infosys              3.0 Code change to fix issue with same error repeating in other lines and
    --           seperating header api call
    -- #########################################################################################################################

    TYPE hdrRecTyp IS RECORD
    (
        hdr_action           VARCHAR2 (1),
        hdr_cancel_reason    VARCHAR2 (100)
    );

    hdr_rec    hdrRecTyp;

    TYPE lineRecTyp IS RECORD
    (
        lne_action     VARCHAR2 (1),
        orig_qty       NUMBER,
        new_qty        NUMBER,
        line_reason    VARCHAR2 (100)
    );

    line_rec   lineRecTyp;

    PROCEDURE write_to_table (msg VARCHAR2, app VARCHAR2);

    PROCEDURE fetch_ad_user_email (p_in_user_id IN VARCHAR2, p_out_user_name OUT VARCHAR2, p_out_display_name OUT VARCHAR2
                                   , p_out_email_id OUT VARCHAR2);

    PROCEDURE get_size_atp (p_in_style_color IN VARCHAR2, p_in_warehouse IN VARCHAR2, p_out_product OUT VARCHAR2, p_out_color_desc OUT VARCHAR2, p_out_product_no OUT VARCHAR2, p_out_unlim_sup_dt OUT DATE
                            , p_out_size_atp OUT SYS_REFCURSOR, p_out_size OUT SYS_REFCURSOR, p_out_err_msg OUT VARCHAR2);

    PROCEDURE insert_stg_data (p_in_user_id IN NUMBER, p_in_batch_id IN NUMBER, p_input_data IN gen_tbl_type
                               , p_out_err_msg OUT VARCHAR2);

    PROCEDURE process_order_api_p (p_in_batch_id IN NUMBER);


    PROCEDURE schedule_order (p_in_batch_id   IN     NUMBER,
                              p_out_err_msg      OUT VARCHAR2);

    PROCEDURE fetch_trx_history_data (p_in_user_id IN NUMBER, p_out_hdr OUT SYS_REFCURSOR, p_out_err_msg OUT VARCHAR2);

    PROCEDURE fetch_trx_details (p_in_user_id IN NUMBER, p_in_batch_id IN NUMBER, p_out_results OUT CLOB
                                 , p_out_err_msg OUT VARCHAR2);

    --start v2.0
    PROCEDURE fetch_trx_his_filter (p_in_filter IN CLOB, p_out_hdr OUT CLOB, p_out_results OUT CLOB
                                    , p_out_err_msg OUT VARCHAR2);

    PROCEDURE fetch_trx_history_data_new (p_in_user_id IN NUMBER, p_out_hdr OUT SYS_REFCURSOR, p_out_results OUT CLOB
                                          , p_out_err_msg OUT VARCHAR2);

    --End v2.0
    --start ver 3.0
    PROCEDURE process_order_header_line (p_in_hdr_called IN OUT VARCHAR2, p_header_rec IN oe_order_pub.header_rec_type, p_action_request_tbl IN oe_order_pub.request_tbl_type
                                         , p_line_tbl IN oe_order_pub.line_tbl_type, p_out_err_msg OUT VARCHAR2, p_out_ret_code OUT VARCHAR2);

    PROCEDURE process_order (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_out_hdr_rec_x OUT oe_order_pub.header_rec_type
                             , p_in_header_rec IN oe_order_pub.header_rec_type, p_in_action_request_tbl IN oe_order_pub.request_tbl_type, p_in_line_tbl IN oe_order_pub.line_tbl_type);

    PROCEDURE validate_header (retcode         OUT VARCHAR2,
                               errbuff         OUT VARCHAR2,
                               p_hdr_attr   IN     hdrRecTyp);

    PROCEDURE validate_line (retcode          OUT VARCHAR2,
                             errbuff          OUT VARCHAR2,
                             p_line_attr   IN     lineRecTyp);
--end ver 3.0

END xxd_ont_genesis_proc_ord_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_GENESIS_PROC_ORD_PKG TO XXORDS
/
