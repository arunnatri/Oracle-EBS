--
-- XXD_ONT_CAL_MARGIN_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_CAL_MARGIN_PKG"
AS
    PROCEDURE MAIN_LOAD (errbuf                OUT VARCHAR2,
                         retcode               OUT VARCHAR2,
                         pd_create_from_date       VARCHAR2,
                         pv_debug                  VARCHAR2,
                         pv_gather_stats           VARCHAR2,
                         pv_reprocess_flag         VARCHAR2,
                         pd_reprocess_date         VARCHAR2,
                         --Start Changes V1.1
                         pn_offset_hours           NUMBER   --End CHanges V1.1
                                                         );

    PROCEDURE MAIN_IR_LOAD (errbuf                OUT VARCHAR2,
                            retcode               OUT VARCHAR2,
                            pd_create_from_date       VARCHAR2,
                            pv_debug                  VARCHAR2,
                            pv_gather_stats           VARCHAR2,
                            pv_reprocess_flag         VARCHAR2,
                            pd_reprocess_date         VARCHAR2,
                            --Start Changes V1.1
                            pn_offset_hours           NUMBER --End CHanges V1.1
                                                            );

    PROCEDURE MAIN_UPDATE (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pd_create_from_date VARCHAR2, pv_debug VARCHAR2, pv_gather_stats VARCHAR2, pv_reprocess_flag VARCHAR2
                           , pd_reprocess_date VARCHAR2);

    PROCEDURE LOG (pv_debug VARCHAR2, pv_msgtxt_in IN VARCHAR2);

    FUNCTION get_inv_org_currency (pn_organization_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_costing_org (pn_src_organization_id    NUMBER,
                              pn_dstn_organization_id   NUMBER)
        RETURN NUMBER;

    FUNCTION get_operating_unit (pn_organization_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_corp_rate (pd_rcpt_shpmt_dt   DATE,
                            pv_from_currency   VARCHAR2,
                            pv_to_currency     VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_onhand_qty (pn_organization_id     NUMBER,
                             pn_inventory_item_id   NUMBER)
        RETURN NUMBER;

    FUNCTION get_macau_to_x_Trans_mrgn (pv_cost IN VARCHAR2, pn_organization_id NUMBER, pn_inventory_item_id NUMBER
                                        , pv_custom_cost IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_avg_prior_cst (pn_dstn_organization_id NUMBER, pn_inventory_item_id NUMBER, pn_sequence_number NUMBER
                                , pd_ship_confirm_dt DATE)
        RETURN NUMBER;

    --start changes v1.1
    FUNCTION get_so_max_seq_num (pn_req_line_id         NUMBER,
                                 pv_source              VARCHAR2,
                                 pn_inventory_item_id   NUMBER)
        RETURN NUMBER;

    FUNCTION get_unprocessed_lines_count (pn_inventory_item_id   NUMBER,
                                          pn_seq_num             NUMBER)
        RETURN NUMBER;

    PROCEDURE proc_update_ir_trx (errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

    --end changes v1.1

    FUNCTION get_max_seq_num (pn_oe_line_id          NUMBER,
                              pv_source              VARCHAR2,
                              pn_inventory_item_id   NUMBER)
        RETURN NUMBER;

    FUNCTION get_costed_onhand_qty (pv_source VARCHAR2, pv_custom_source VARCHAR2, pn_organization_id NUMBER
                                    , pn_inventory_item_id NUMBER, pn_source_line_id NUMBER, pn_mmt_trx_id NUMBER)
        RETURN NUMBER;



    PROCEDURE proc_load_ir_trx (pd_create_from_date VARCHAR2, x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2);

    FUNCTION get_onhand_eligible (pn_inventory_item_id   NUMBER,
                                  pn_sequence_number     NUMBER)
        RETURN VARCHAR2;
END;
/
