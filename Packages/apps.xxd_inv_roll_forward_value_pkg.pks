--
-- XXD_INV_ROLL_FORWARD_VALUE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_ROLL_FORWARD_VALUE_PKG"
AS
    /************************************************************************************************
    * Package         : XXD_INV_ROLL_FORWARD_VALUE_PKG
    * Description     : This package is used in Deckers Inventory Roll Forward Value Report
    * Notes           :
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    * Date            Version#      Name                       Description
    *-----------------------------------------------------------------------------------------------
    * 27-Jun-2022     1.0           Viswanathan Pandian        Initial version
    ************************************************************************************************/
    -- Concurrent Program Parameters
    p_inv_org_id          NUMBER;
    p_from_date           VARCHAR2 (100);
    p_to_date             VARCHAR2 (100);
    -- Global Variables
    gn_category_set_id    NUMBER;
    gn_inv_structure_id   NUMBER;
    gn_inv_org_id         NUMBER;
    gd_from_date          DATE;
    gd_to_date            DATE;

    FUNCTION extract_data
        RETURN BOOLEAN;
END xxd_inv_roll_forward_value_pkg;
/
