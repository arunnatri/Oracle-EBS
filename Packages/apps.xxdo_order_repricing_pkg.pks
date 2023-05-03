--
-- XXDO_ORDER_REPRICING_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ORDER_REPRICING_PKG"
AS
    PROCEDURE POPULATE_REPRICE_STG (
        p_out_chr_ret_message      OUT NOCOPY VARCHAR2,
        p_out_num_ret_status       OUT NOCOPY NUMBER,
        pn_org_id                             NUMBER,
        pn_cust_acct_id                       NUMBER,
        pv_from_ord_no                        VARCHAR2,
        pv_to_ord_no                          VARCHAR2,
        pd_from_req_dt                        VARCHAR2,
        pd_to_req_dt                          VARCHAR2,
        -- pd_from_schdl_dt VARCHAR2,--Commented By Infosys for PRB0040923
        --  pd_to_schdl_dt   VARCHAR2,--Commented By Infosys for PRB0040923
        pn_order_src_id                       NUMBER,
        pn_brand                              VARCHAR2  -- modified by Infosys
                                                      ,
        pn_no_of_workers                      NUMBER --Added by Infosys on 14-Nov-2016
                                                    --,pn_process_status VARCHAR2
                                                    );

    PROCEDURE REPRICE_ORDER (P_ERR_BUFF OUT NOCOPY VARCHAR2, P_RET_CODE OUT NOCOPY NUMBER, p_parent_req_id NUMBER
                             , p_batch_id NUMBER, p_process_status VARCHAR2);
END XXDO_ORDER_REPRICING_PKG;
/
