--
-- XXD_ONT_SHADOW_ORDER_PKG  (Package) 
--
--  Dependencies: 
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_ORDER_LINES_ALL (Synonym)
--   STANDARD (Package)
--   XXD_ONT_ORD_LINE_OBJ (Type)
--
/* Formatted on 4/26/2023 4:23:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_SHADOW_ORDER_PKG"
    AUTHID DEFINER
AS
    /****************************************************************************************
    * Package      : XXD_ONT_SHADOW_ORDER_PKG
    * Design       : This package will will manage the shadow order process
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 01-Jul-2021  1.0        Deckers                 Initial Version
    -- 16-Sep-2021  1.1        Laltu Kumar             Updated for CCR0009461
    -- 08-Oct-2021  1.2        Viswanathan Pandian     Updated for CCR0009695
    ******************************************************************************************/
    g_miss_num          CONSTANT NUMBER := 9.99e125;
    g_miss_char         CONSTANT VARCHAR2 (1) := CHR (0);
    g_miss_date         CONSTANT DATE := TO_DATE ('1', 'j');
    g_ret_sts_success   CONSTANT VARCHAR2 (1) := 'S';
    g_ret_sts_error     CONSTANT VARCHAR2 (1) := 'E';

    PROCEDURE check_bulk_header (pn_bulk_line_id IN oe_order_lines_all.line_id%TYPE, xn_bulk_header_id OUT oe_order_headers_all.header_id%TYPE, xc_ret_stat OUT VARCHAR2);

    FUNCTION rec_to_obj (pr_line IN oe_order_lines_all%ROWTYPE)
        RETURN xxd_ne.xxd_ont_ord_line_obj;

    PROCEDURE shadow_line (pn_calloff_line_id IN oe_order_lines_all.line_id%TYPE, xc_ret_stat OUT VARCHAR2);

    --Start changes for CCR0009461
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_cust_acct_id VARCHAR2, p_order_type_id VARCHAR2, p_req_date_from VARCHAR2, p_req_date_to VARCHAR2, -- Start changes for CCR0009695
                                                                                                                                                                                        p_order_number_from NUMBER, p_order_number_to NUMBER
                    , p_threads NUMBER, -- End changes for CCR0009695
                                        p_debug VARCHAR2);

    PROCEDURE shadow_line_child (errbuf            OUT VARCHAR2,
                                 retcode           OUT VARCHAR2,
                                 p_batch_id_from       NUMBER,
                                 p_batch_id_to         NUMBER,
                                 p_record_set          NUMBER,
                                 p_debug               VARCHAR2);
--End changes for CCR0009461
END xxd_ont_shadow_order_pkg;
/
