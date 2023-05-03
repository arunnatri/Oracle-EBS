--
-- XXD_DO_OM_DEFAULT_RULES  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_DO_OM_DEFAULT_RULES"
AS
    /*******************************************************************************
    * Program Name : XXD_DO_OM_DEFAULT_RULES
    * Language     : PL/SQL
    * Description  : This package will be Used for OM Defaulting Rules
    *
    * History      :
    *
    * WHO                 WHAT              Desc                                               WHEN
    * -------------- ------------------------------------------------------------------- ---------------
    *  BT Tech Team        1.0                                                               12-JAN-2015
    *  Jerry Ni            1.1           Add new procedure ret_warehouse                     30-APR-2015
    *  Infosys             1.2           Added new function get_def_latest_accep_date        06-DEC-2017
    *  Arun N Murthy       1.3           Updated for CCR0007043                              07-MAR-2018
    *  Tejaswi Gangumalla  1.4           Updated for CCR0007850                              18-APR-2019
    *  Viswanathan Pandian 1.5           Updated for CCR0008531                              24-MAR-2020
    *  Greg Jensen         1.6           Updated for CCR0008530                              26-MAR-2020
    *  Gaurav joshi        1.7           Updated for CCR0008657                              21-AUG-2020
    *  Jayarajan A K       1.8           Updated for DXLabs Changes CCR0009018               26-NOV-2020
    *  Gaurav joshi        1.9           Updated for CCR0008870                              29-JUN-2021
 *  Aravind Kannuri    1.10          Updated for CCR0009197                              05-JUL-2021
 * Gaurav Joshi         1.11          Updated for US6   CCR0009841                        28-feb-2022
    * ----------------------------------------------------------------------------------------------------- */

    FUNCTION ret_hpricelist (p_database_object_name   IN VARCHAR2,
                             p_attribute_code         IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION ret_lpricelist (p_database_object_name   IN VARCHAR2,
                             p_attribute_code         IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION ret_demclass (p_database_object_name   IN VARCHAR2,
                           p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_request_date (p_database_object_name   IN VARCHAR2,
                               p_attribute_code         IN VARCHAR2)
        RETURN DATE;

    FUNCTION ret_pricing_date (p_database_object_name   IN VARCHAR2,
                               p_attribute_code         IN VARCHAR2)
        RETURN DATE;

    /*FUNCTION ret_hsalesrep (
          p_database_object_name   IN   VARCHAR2,
          p_attribute_code         IN   VARCHAR2
       )
          RETURN NUMBER;

    FUNCTION ret_lsalesrep (
          p_database_object_name   IN   VARCHAR2,
          p_attribute_code         IN   VARCHAR2
       )
          RETURN NUMBER;*/

    FUNCTION ret_shipinstr (p_database_object_name   IN VARCHAR2,
                            p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_packinstr (p_database_object_name   IN VARCHAR2,
                            p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_ship_to_loc (p_database_object_name   IN VARCHAR2,
                              p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_bill_to_loc (p_database_object_name   IN VARCHAR2,
                              p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_default_line_type (p_database_object_name   IN VARCHAR2,
                                    p_attribute_code         IN VARCHAR2)
        RETURN NUMBER;

    --Start:1.2 Added by Infosys on 06-DEC-2017 for CCR0006679
    FUNCTION get_def_latest_accep_date (p_database_object_name   IN VARCHAR2,
                                        p_attribute_code         IN VARCHAR2)
        RETURN DATE;

    --End:1.2 Added by Infosys on 06-DEC-2017 for CCR0006679
    --Start:1.9 Added for CCR0008870
    FUNCTION get_def_calculated_lad (p_database_object_name   IN VARCHAR2,
                                     p_attribute_code         IN VARCHAR2)
        RETURN DATE;

    --End:1.9 Added for CCR0008870

    FUNCTION get_default_subinventory (p_database_object_name   IN VARCHAR2,
                                       p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_warehouse (p_database_object_name   IN VARCHAR2,
                            p_attribute_code         IN VARCHAR2)
        RETURN NUMBER;

    --start changes v1.3
    FUNCTION ret_org_move_warehouse (pn_org_id IN NUMBER, pv_brand IN VARCHAR2, pn_order_type_id IN NUMBER
                                     , pd_request_date DATE)
        RETURN NUMBER;

    --end changes v1.3

    --start changes v1.11
    FUNCTION ret_inv_warehouse (pn_org_id IN NUMBER, pn_order_type_id IN NUMBER, pn_line_type_id IN NUMBER, pn_request_date IN DATE, pn_brand IN VARCHAR2, pn_division IN VARCHAR2
                                , pn_department IN VARCHAR2, pn_class IN VARCHAR2, pn_subclass IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION ret_inv_warehouse (p_org_id              IN NUMBER,
                                p_order_type_id       IN NUMBER,
                                p_line_type_id        IN NUMBER,
                                p_request_date        IN DATE,
                                p_inventory_item_id   IN NUMBER)
        RETURN NUMBER;

    --end changes v1.11

    PROCEDURE get_warehouse (p_org_id IN NUMBER, p_line_type_id IN NUMBER, p_inventory_item_id IN NUMBER
                             , p_order_type_id IN NUMBER DEFAULT NULL, --ver 1.11
                                                                       p_request_date IN DATE DEFAULT NULL, --ver 1.11
                                                                                                            x_warehouse_id OUT NUMBER);

    /* Start Of Changes For CCR CCR0007850*/
    FUNCTION internal_order_demclass (p_database_object_name   IN VARCHAR2,
                                      p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    /* End Of Changes For CCR CCR0007850*/
    -- Start changes for CCR0008531
    FUNCTION ret_ecomm_demand_class (p_database_object_name   IN VARCHAR2,
                                     p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    -- End changes for CCR0008531
    --ver 1.6 Start Changes for CCR0008530
    FUNCTION ret_globale_tax_code (p_database_object_name   IN VARCHAR2,
                                   p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    --End Changes for CCR0008530

    -- ver 1.7 Start changes for CCR0008657
    FUNCTION ret_hdrshipinstr (p_database_object_name   IN VARCHAR2,
                               p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_hdrpackinstr (p_database_object_name   IN VARCHAR2,
                               p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_lineshipinstr (p_database_object_name   IN VARCHAR2,
                                p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_linepackinstr (p_database_object_name   IN VARCHAR2,
                                p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    -- ver 1.7 End changes for CCR0008657

    --Start v1.8 DXLabs Changes
    FUNCTION ret_hdr_ship_method (p_database_object_name   IN VARCHAR2,
                                  p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_hdr_freight_term (p_database_object_name   IN VARCHAR2,
                                   p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_line_ship_method (p_database_object_name   IN VARCHAR2,
                                   p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION ret_line_freight_term (p_database_object_name   IN VARCHAR2,
                                    p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;

    --End v1.8 DXLabs Changes

    --Start changes for v1.10
    FUNCTION ret_jp_bill_to_loc (p_database_object_name   IN VARCHAR2,
                                 p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2;
--End changes for v1.10

END xxd_do_om_default_rules;
/


GRANT EXECUTE ON APPS.XXD_DO_OM_DEFAULT_RULES TO SOA_INT
/
