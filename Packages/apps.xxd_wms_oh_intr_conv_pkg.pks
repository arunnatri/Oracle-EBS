--
-- XXD_WMS_OH_INTR_CONV_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_OH_INTR_CONV_PKG"
AS
    /******************************************************************************************
     * Package      : XXD_WMS_OH_INTR_CONV_PKG
     * Design       : This package is used for creating IR/ISO to move OH inventory from one org to anorther
     * Notes        :
     * Modification :
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 03-SEP-2019  1.0        Greg Jensen           Initial Version
    ******************************************************************************************/

    PROCEDURE insert_into_oh_table (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_inv_org_id IN NUMBER, pv_brand IN VARCHAR2:= NULL, pv_style IN VARCHAR2:= NULL, pn_dest_inv_org_id IN NUMBER
                                    , pn_max_req_qty IN NUMBER:= 1000);

    PROCEDURE create_oh_xfer_ir (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_src_organization_id IN NUMBER
                                 , pn_dest_organization_id IN NUMBER, pv_brand IN VARCHAR2, pv_style IN VARCHAR2:= NULL);

    PROCEDURE run_create_internal_orders (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_org_id IN NUMBER);

    --Function to check item attributes for OH cursor
    FUNCTION check_item_attributes (pn_inventory_item_id IN NUMBER, pn_src_org_id IN NUMBER, pn_dest_org_id IN NUMBER)
        RETURN NUMBER;

    PROCEDURE do_validation (pv_err_stat                  OUT VARCHAR2,
                             pv_err_msg                   OUT VARCHAR2,
                             pn_src_organization_id    IN     NUMBER,
                             pn_dest_organization_id   IN     VARCHAR2,
                             pv_brand                  IN     VARCHAR2);


    PROCEDURE run_oh_conversion (
        pv_err_stat                  OUT VARCHAR2,
        pv_err_msg                   OUT VARCHAR2,
        pn_src_organization_id    IN     NUMBER,
        pn_dest_organization_id   IN     VARCHAR2,
        pv_brand                  IN     VARCHAR2,
        pv_style                  IN     VARCHAR2 := NULL,
        pn_max_req_qty            IN     NUMBER := 1000,
        pn_number_oimp_threads    IN     NUMBER := 4);

    PROCEDURE stage_conv_internal_so (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_iso_number IN NUMBER);
END XXD_WMS_OH_INTR_CONV_PKG;
/
