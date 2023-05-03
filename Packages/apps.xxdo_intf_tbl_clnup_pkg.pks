--
-- XXDO_INTF_TBL_CLNUP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INTF_TBL_CLNUP_PKG"
AS
    /************************************************************
    * Package Name     : XXDO_INTF_TBL_CLNUP_PKG
    * File Type        : Package Specification
    *
    * DEVELOPMENT and MAINTENANCE HISTORY
    *
    * DATE          AUTHOR      Version     Description
    * ---------     -------     -------     ---------------
    * 9/09/2016     INFOSYS     1.0         Initial Version
    ************************************************************/

    PROCEDURE out (pv_msg VARCHAR2, pn_level NUMBER:= 1000);

    PROCEDURE intfc_rec_update (p_reterror OUT VARCHAR2, p_retcode OUT NUMBER, p_action IN VARCHAR2, p_table IN VARCHAR2, p_d_action IN VARCHAR2, p_set_col_name1 IN VARCHAR2, p_set_col_value1 IN VARCHAR2, p_set_col_name2 IN VARCHAR2, p_set_col_value2 IN VARCHAR2, p_set_col_name3 IN VARCHAR2, p_set_col_value3 IN VARCHAR2, p_set_col_name4 IN VARCHAR2, p_set_col_value4 IN VARCHAR2, p_set_col_name5 IN VARCHAR2, p_set_col_value5 IN NUMBER, p_where_col_name1 IN VARCHAR2, p_where_col_value1 IN VARCHAR2, p_where_col_name2 IN VARCHAR2
                                , p_where_col_value2 IN VARCHAR2, p_where_col_name3 IN VARCHAR2, p_where_col_value3 IN VARCHAR2);

    PROCEDURE p2p_asn_reprocess (
        p_rhi_hdr_intfc_id           IN     NUMBER,
        p_rhi_hdr_intfc_grp_id       IN     NUMBER,
        p_rhi_hdr_intfc_shpmnt_num   IN     VARCHAR2,
        p_reterror                      OUT VARCHAR2,
        p_retcode                       OUT NUMBER);

    PROCEDURE p2p_asn_reextract (
        p_rhi_hdr_intfc_shpmnt_num   IN     VARCHAR2,
        p_rti_intfc_trx_shpmnt_num   IN     VARCHAR2,
        p_container_id               IN     NUMBER,
        p_reterror                      OUT VARCHAR2,
        p_retcode                       OUT NUMBER);

    PROCEDURE p2p_asn_no_open_shipments (p_rhi_hdr_intfc_grp_id IN NUMBER, p_rti_intfc_trx_grp_id IN NUMBER, p_reterror OUT VARCHAR2
                                         , p_retcode OUT NUMBER);

    PROCEDURE p2p_asn_shipment_exists (p_rhi_hdr_intfc_shpmnt_num IN VARCHAR2, p_rti_intfc_trx_shpmnt_num IN VARCHAR2, p_reterror OUT VARCHAR2
                                       , p_retcode OUT NUMBER);

    PROCEDURE wms_mtl_trx_intfc_clnup (p_mtl_trx_hdr_id IN NUMBER, p_mtl_trx_intfc_id IN NUMBER, p_reterror OUT VARCHAR2
                                       , p_retcode OUT NUMBER);

    PROCEDURE wms_rma_sub_routine (p_reterror   OUT VARCHAR2,
                                   p_retcode    OUT NUMBER);

    PROCEDURE o2c_push_rma_order_line (
        p_rti_intfc_trx_id           IN     NUMBER,
        p_rti_intfc_trx_grp_id       IN     NUMBER,
        p_rti_intfc_trx_shpmnt_num   IN     VARCHAR2,
        p_reterror                      OUT VARCHAR2,
        p_retcode                       OUT NUMBER);

    PROCEDURE o2c_repnt_rma_rcpt_ln_same_ln (
        p_rti_intfc_trx_id           IN     NUMBER,
        p_rti_intfc_trx_grp_id       IN     NUMBER,
        p_rti_intfc_trx_shpmnt_num   IN     VARCHAR2,
        p_reterror                      OUT VARCHAR2,
        p_retcode                       OUT NUMBER);

    PROCEDURE o2c_repnt_rma_rcpt_ln_new_ln (
        p_rti_intfc_trx_id           IN     NUMBER,
        p_rti_intfc_trx_grp_id       IN     NUMBER,
        p_rti_intfc_trx_shpmnt_num   IN     VARCHAR2,
        p_reterror                      OUT VARCHAR2,
        p_retcode                       OUT NUMBER);

    PROCEDURE main (p_reterror                      OUT VARCHAR2,
                    p_retcode                       OUT NUMBER,
                    p_track                      IN     VARCHAR2,
                    p_error                      IN     VARCHAR2,
                    p_wms                        IN     VARCHAR2,
                    p_o2c                        IN     VARCHAR2,
                    p_p2p                        IN     VARCHAR2,
                    p_p2p_reextracting           IN     VARCHAR2,
                    p_p2p_shipment               IN     VARCHAR2,
                    p_p2p_int_grp_id             IN     VARCHAR2,
                    p_p2p_int_hdr_id             IN     VARCHAR2,
                    p_p2p_container_id           IN     VARCHAR2,
                    p_o2c_int_trx_id             IN     VARCHAR2,
                    p_p2p_hdr_grp_id             IN     VARCHAR2,
                    p_rhi_hdr_intfc_id           IN     NUMBER,
                    p_rhi_hdr_intfc_grp_id       IN     NUMBER,
                    p_rhi_hdr_intfc_shpmnt_num   IN     VARCHAR2,
                    p_rti_intfc_trx_id           IN     NUMBER,
                    p_rti_intfc_trx_grp_id       IN     NUMBER,
                    p_rti_intfc_trx_shpmnt_num   IN     VARCHAR2,
                    p_container_id               IN     NUMBER,
                    p_mtl_trx_hdr_id             IN     NUMBER,
                    p_mtl_trx_intfc_id           IN     NUMBER);
END xxdo_intf_tbl_clnup_pkg;
/
