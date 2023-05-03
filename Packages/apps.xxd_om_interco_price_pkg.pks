--
-- XXD_OM_INTERCO_PRICE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_OM_INTERCO_PRICE_PKG"
AS
    /*****************************************************************
    * Package:           XXD_OM_INTERCO_PRICE
    *
    * Author:            GJensen
    *
    * Created:            30-MAR-2021
    *
    * Description:
    *
    * Modifications:
    * Date modified        Developer name          Version
    * 03/30/2021           GJensen                 Original(1.0)
    *****************************************************************/
    FUNCTION get_bonded_value (pn_line_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_free_circulation_value (pn_line_id IN NUMBER)
        RETURN NUMBER;
END XXD_OM_INTERCO_PRICE_PKG;
/
