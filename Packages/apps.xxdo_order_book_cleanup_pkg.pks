--
-- XXDO_ORDER_BOOK_CLEANUP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ORDER_BOOK_CLEANUP_PKG"
--****************************************************************************************************
--*  NAME       : xxdo_ont_order_book_cleanup_pkg
--*  APPLICATION: Oracle Order Management
--*
--*  AUTHOR     : Sivakumar Boothathan
--*  DATE       : 08-Oct-2016
--*
--*  DESCRIPTION: This package will do the following
--*               A. It takes the input as Operating Unit
--*               B. Remove the orderride ATP for the lines for which the override ATP is set to Yes
--*               C. To copy the cancel date to LAD when LAD is null
--*               D. To sync the LAD with Cancel Date
--*  REVISION HISTORY:
--*  Change Date     Version             By                          Change Description
--****************************************************************************************************
--*  08-Oct-2016                    Siva Boothathan                  Initial Creation
--****************************************************************************************************
IS
    -------------------------------------------------------------
    -- Control procedure to navigate the control for the package
    -- Input Operating Unit
    -- Functionality :
    -- A. The input : Operating Unit is taken as the input Parameter
    -- B. Execute the delete scripts which will find the records
    -- in the interface table with the change sequence and delete
    -- C. Call the next procedures for ATP, LAD etc.
    -------------------------------------------------------------
    PROCEDURE main_control (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_operating_unit IN NUMBER
                            , p_change_sequence IN NUMBER);

    -------------------------------------------------------------
    -- Procedure to remove the override ATP
    -------------------------------------------------------------
    PROCEDURE remove_override_ATP (p_ou_id IN NUMBER, p_change_sequence IN NUMBER, p_user_id IN NUMBER);

    -------------------------------------------------------------
    -- Procedure to adjust and sync the LAD
    -------------------------------------------------------------
    PROCEDURE sync_LAD (p_ou_id             IN NUMBER,
                        p_change_sequence   IN NUMBER,
                        p_user_id           IN NUMBER);

    -----------------------
    -- End of the procedure
    -----------------------
    -------------------------------------------------------------
    -- Procedure to adjust and sync the LAD
    -------------------------------------------------------------
    PROCEDURE ssd_outside_LAD (p_ou_id IN NUMBER, p_change_sequence IN NUMBER, p_user_id IN NUMBER);
-----------------------
-- End of the procedure
-----------------------
END;
/
