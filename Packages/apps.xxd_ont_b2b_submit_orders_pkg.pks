--
-- XXD_ONT_B2B_SUBMIT_ORDERS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_B2B_SUBMIT_ORDERS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_B2B_SUBMIT_ORDERS_PKG
    * Design       : This package will be used for B2B Submit and Return Order Report
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
  -- 15-Jul-2020  1.0         Shivanshu Talwar       Initial Version
     -- 20-Oct-2022  1.1         Archana Kotha          Added Procedure validate_return_orders
    ******************************************************************************************/
    PROCEDURE validate_submit_orders (p_batch_id IN NUMBER, p_region IN VARCHAR2, p_error_count OUT NUMBER
                                      , p_error_msg OUT VARCHAR2);

    PROCEDURE validate_return_orders (p_batch_id IN NUMBER, p_region IN VARCHAR2, p_error_count OUT NUMBER
                                      , p_error_msg OUT VARCHAR2);
END XXD_ONT_B2B_SUBMIT_ORDERS_PKG;
/


GRANT EXECUTE ON APPS.XXD_ONT_B2B_SUBMIT_ORDERS_PKG TO SOA_INT
/
