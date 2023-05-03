--
-- XXD_WMS_RET_INV_VAL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_RET_INV_VAL_PKG"
IS
    /******************************************************************************
     NAME           : XXDO.XXD_WMS_RET_INV_VAL_PKG
     REPORT NAME    : Deckers WMS Retail Inventory Valuation Report

     REVISIONS:
     Date       Author          Version Description
     ---------  ----------      ------- --------------------------------------------
     06/12/2019 Kranthi Bollam  1.0     Created this package for Retail Inventory
                                        valuation report(CCR0007979 - Deckers Macau
                                        Project)
    ******************************************************************************/

    --======================================================================+
    -- |
    -- Report Lexical Parameters |
    -- |
    --======================================================================+
    pv_sql_stmt            VARCHAR2 (32000);

    --======================================================================+
    -- |
    -- Report Input Parameters |
    -- |
    --======================================================================+
    pv_period_name         VARCHAR2 (10);                      -- := 'FEB-18';
    pn_org_unit_id_rms     NUMBER;
    pn_ou_id               NUMBER;                                   -- := 95;
    pn_inv_org_id          NUMBER;
    pv_level               VARCHAR2 (30);                       -- := 'STORE';
    pn_store_number        NUMBER;                              -- := '10001';
    pv_brand               VARCHAR2 (30);
    pv_style               VARCHAR2 (30);
    pv_style_color         VARCHAR2 (30);
    pn_inventory_item_id   NUMBER;

    --======================================================================+

    FUNCTION before_report
        RETURN BOOLEAN;

    FUNCTION after_report
        RETURN BOOLEAN;

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
END xxd_wms_ret_inv_val_pkg;
/
