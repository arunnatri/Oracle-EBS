--
-- XXD_WMS_RET_INV_VAL_BL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_RET_INV_VAL_BL_PKG"
IS
    /******************************************************************************************
     NAME           : XXD_WMS_RET_INV_VAL_BL_PKG
     REPORT NAME    : Deckers WMS Retail Inventory Valuation Report to Black Line

     REVISIONS:
     Date        Author             Version  Description
     ---------   ----------         -------  ---------------------------------------------------
     28-MAY-2021 Srinath Siricilla  1.0      Created this package using XXD_WMS_RET_INV_VAL_PKG
                                             for sending the report output to BlackLine
    *********************************************************************************************/

    pv_sql_stmt   VARCHAR2 (32000);

    --======================================================================+

    PROCEDURE MAIN_PRC (errbuf                    OUT NOCOPY VARCHAR2,
                        retcode                   OUT NOCOPY VARCHAR2,
                        pv_period_name         IN            VARCHAR2,
                        pn_org_unit_id_rms     IN            NUMBER,
                        pn_ou_id               IN            NUMBER,
                        pn_inv_org_id          IN            NUMBER,
                        pv_level               IN            VARCHAR2,
                        pn_store_number        IN            NUMBER,
                        pv_brand               IN            VARCHAR2,
                        pv_style               IN            VARCHAR2,
                        pv_style_color         IN            VARCHAR2,
                        pn_inventory_item_id   IN            NUMBER,
                        pv_file_path           IN            VARCHAR2,
                        pv_include_margin      IN            VARCHAR2);

    PROCEDURE write_ret_recon_file (pv_file_path IN VARCHAR2, pv_file_name IN VARCHAR2, x_ret_code OUT VARCHAR2
                                    , x_ret_message OUT VARCHAR2);

    PROCEDURE write_op_file (pv_file_path IN VARCHAR2, pv_file_name IN VARCHAR2, pv_period_name IN VARCHAR2
                             , p_operating_unit IN NUMBER, x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2);

    PROCEDURE update_valueset_prc (pv_file_path IN VARCHAR2);

    PROCEDURE update_attributes (x_ret_message       OUT VARCHAR2,
                                 pv_period_name   IN     VARCHAR2);

    FUNCTION get_conv_rate (pv_from_currency IN VARCHAR2, pv_to_currency IN VARCHAR2, pd_conversion_date IN DATE)
        RETURN NUMBER;

    PROCEDURE purge_prc (pn_purge_days IN NUMBER);

    PROCEDURE write_log (pv_msg IN VARCHAR2);

    FUNCTION get_store_currency (pn_store_number IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_fixed_margin_pct (pn_ou_id        IN NUMBER,
                                   pv_brand        IN VARCHAR2,
                                   pv_store_type   IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_org_unit_id_rms (pn_ou_id IN NUMBER)
        RETURN VARCHAR2;
END XXD_WMS_RET_INV_VAL_BL_PKG;
/
