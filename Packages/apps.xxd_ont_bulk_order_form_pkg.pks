--
-- XXD_ONT_BULK_ORDER_FORM_PKG  (Package) 
--
--  Dependencies: 
--   OE_ORDER_HEADERS_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_BULK_ORDER_FORM_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_ORDER_FORM_PKG
    * Design       : This package will be used in Bulk Order Transfer Form
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 21-Jan-2018  1.0        Arun Murthy             Initial Version
    -- 28-Nov-2018  1.1        Viswanathan Pandian     Updated for CCR0007531
    ******************************************************************************************/
    -- Start changes for CCR0007531
    -- FUNCTION lock_order_line(pn_line_id NUMBER) RETURN VARCHAR2;

    -- PROCEDURE proc_update_error (pv_error_msg VARCHAR2, pn_line_id NUMBER);
    FUNCTION lock_order (p_header_id IN oe_order_headers_all.header_id%TYPE)
        RETURN VARCHAR2;

    PROCEDURE proc_update_error (p_header_id IN oe_order_headers_all.header_id%TYPE DEFAULT NULL, p_error_msg VARCHAR2);

    -- End changes for CCR0007531

    PROCEDURE xxd_ont_bulk_order_proc (pn_org_id                NUMBER,
                                       pn_user_id               NUMBER,
                                       pn_resp_id               NUMBER,
                                       pn_resp_appl_id          NUMBER,
                                       pv_brand                 VARCHAR2,
                                       pn_cust_account_id       NUMBER,
                                       pn_cust_account_id2      NUMBER,
                                       pn_bulk_ord_hdr_id_frm   NUMBER,
                                       pn_bulk_ord_hdr_id_to    NUMBER,
                                       pd_req_ord_date_from     DATE,
                                       pd_req_ord_date_to       DATE,
                                       pd_ssd_from              DATE,
                                       pd_ssd_to                DATE,
                                       pd_lad_from              DATE,
                                       pd_lad_to                DATE,
                                       pv_demand_class_code     VARCHAR2,
                                       pn_ship_from_org_id      NUMBER,
                                       pv_style                 VARCHAR2,
                                       pv_color                 VARCHAR2,
                                       pn_inv_item_id           VARCHAR2,
                                       pn_frm_rem_qty           NUMBER,
                                       pn_to_rem_qty            NUMBER,
                                       pv_mode                  VARCHAR2);

    PROCEDURE xxd_initialize_proc (pn_org_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER
                                   , pn_resp_appl_id NUMBER);

    FUNCTION get_cum_transferred_qty (pn_header_id     NUMBER,
                                      pn_line_id       NUMBER,
                                      pv_reason_code   VARCHAR2)
        RETURN NUMBER;

    PROCEDURE proc_call_process_each_order (
        pn_org_id                         NUMBER,
        pn_user_id                        NUMBER,
        pn_resp_id                        NUMBER,
        pn_resp_appl_id                   NUMBER,
        pn_header_id                      NUMBER DEFAULT NULL,
        pn_sold_to_org_id                 NUMBER,
        pv_cust_po_number                 VARCHAR2,
        x_message              OUT NOCOPY VARCHAR2);
END xxd_ont_bulk_order_form_pkg;
/
