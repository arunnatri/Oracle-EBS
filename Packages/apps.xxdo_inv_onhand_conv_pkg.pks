--
-- XXDO_INV_ONHAND_CONV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INV_ONHAND_CONV_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_ship_confirm_pkg.sql   1.0    2014/07/15    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_ship_confirm_pkg
    --
    -- Description  :  This is package  for WMS to OMS Ship Confirm Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 15-Jul-14    Infosys            1.0       Created
    -- 09-Jun-15     Infosys            3.0        New Parameter is added for Requisition approval;
    --                                                          Identified by APPROVAL_PARAMETER
    -- ***************************************************************************


    g_num_api_version       NUMBER := 1.0;
    g_num_user_id           NUMBER := fnd_global.user_id;
    g_num_login_id          NUMBER := fnd_global.login_id;
    g_num_request_id        NUMBER := fnd_global.conc_request_id;
    g_num_program_id        NUMBER := fnd_global.conc_program_id;
    g_num_program_appl_id   NUMBER := fnd_global.prog_appl_id;
    g_num_org_id            NUMBER := fnd_profile.VALUE ('ORG_ID');

    TYPE g_req_ids_tab_type IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    TYPE g_ids_tab_type IS TABLE OF NUMBER
        INDEX BY VARCHAR2 (100);

    g_inv_ids_tab           g_ids_tab_type;
    g_carrier_ids_tab       g_ids_tab_type;

    PROCEDURE extract_oh (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_summary_level IN VARCHAR2, p_in_chr_brand IN VARCHAR2, p_in_chr_gender IN VARCHAR2, p_in_num_src_inv_org_id IN NUMBER, p_in_chr_src_subinv IN VARCHAR2, --                                    p_in_num_tar_inv_org_id IN NUMBER,
                                                                                                                                                                                                                                                          --                                    p_in_chr_tar_subinv IN VARCHAR2,
                                                                                                                                                                                                                                                          p_in_chr_product_group IN VARCHAR2, p_in_chr_prod_subgroup IN VARCHAR2
                          , p_in_chr_style IN VARCHAR2, p_in_chr_color IN VARCHAR2, p_in_chr_size IN VARCHAR2);

    --                                    p_in_num_inv_item_id IN NUMBER);

    PROCEDURE perform_direct_transfer (
        p_out_chr_errbuf             OUT VARCHAR2,
        p_out_chr_retcode            OUT VARCHAR2,
        p_in_chr_brand            IN     VARCHAR2,
        p_in_chr_gender           IN     VARCHAR2,
        p_in_num_src_inv_org_id   IN     NUMBER,
        p_in_chr_src_subinv       IN     VARCHAR2,
        p_in_num_tar_inv_org_id   IN     NUMBER,
        p_in_chr_tar_subinv       IN     VARCHAR2);

    PROCEDURE processing_oh (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT VARCHAR2, p_out_return_status OUT VARCHAR2);


    PROCEDURE onhand_cost_report (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_summary_level IN VARCHAR2, p_in_chr_brand IN VARCHAR2, p_in_chr_gender IN VARCHAR2, p_in_num_inv_org_id IN NUMBER, p_in_chr_subinv IN VARCHAR2, p_in_chr_product_group IN VARCHAR2, p_in_chr_prod_subgroup IN VARCHAR2
                                  , p_in_chr_style IN VARCHAR2, p_in_chr_color IN VARCHAR2, p_in_chr_size IN VARCHAR2);


    PROCEDURE onhand_cost_report_ext (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_summary_level IN VARCHAR2, p_in_chr_brand IN VARCHAR2, p_in_chr_gender IN VARCHAR2, p_in_num_inv_org_id IN NUMBER, p_in_chr_subinv IN VARCHAR2, p_in_chr_product_group IN VARCHAR2, p_in_chr_prod_subgroup IN VARCHAR2
                                      , p_in_chr_style IN VARCHAR2, p_in_chr_color IN VARCHAR2, p_in_chr_size IN VARCHAR2);


    PROCEDURE highjump_ext (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_summary_level IN VARCHAR2, p_in_chr_brand IN VARCHAR2, p_in_chr_gender IN VARCHAR2, p_in_num_inv_org_id IN NUMBER, p_in_chr_subinv IN VARCHAR2, p_in_chr_product_group IN VARCHAR2, p_in_chr_prod_subgroup IN VARCHAR2
                            , p_in_chr_style IN VARCHAR2, p_in_chr_color IN VARCHAR2, p_in_chr_size IN VARCHAR2);


    PROCEDURE extract_req_oh (p_out_chr_errbuf             OUT VARCHAR2,
                              p_out_chr_retcode            OUT VARCHAR2,
                              p_in_chr_brand            IN     VARCHAR2,
                              p_in_chr_gender           IN     VARCHAR2,
                              p_in_num_src_inv_org_id   IN     NUMBER,
                              p_in_chr_src_subinv       IN     VARCHAR2,
                              --                                    p_in_num_tar_inv_org_id IN NUMBER,
                              --                                    p_in_chr_tar_subinv IN VARCHAR2,
                              p_in_chr_product_group    IN     VARCHAR2,
                              p_in_chr_prod_subgroup    IN     VARCHAR2,
                              p_in_chr_style            IN     VARCHAR2,
                              p_in_chr_color            IN     VARCHAR2,
                              p_in_chr_size             IN     VARCHAR2);

    PROCEDURE create_requisitions (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_brand IN VARCHAR2, p_in_chr_gender IN VARCHAR2, p_in_num_src_inv_org_id IN NUMBER, p_in_chr_src_subinv IN VARCHAR2, p_in_num_tar_inv_org_id IN NUMBER, p_in_chr_tar_subinv IN VARCHAR2, p_in_chr_approval_flag IN VARCHAR2
                                   ,                  /* APPROVAL_PARAMETER */
                                     p_in_chr_user IN VARCHAR2); /* USER_PARAMETER */


    PROCEDURE wait_for_request (p_in_req_ids_tab IN g_req_ids_tab_type);
END xxdo_inv_onhand_conv_pkg;
/
