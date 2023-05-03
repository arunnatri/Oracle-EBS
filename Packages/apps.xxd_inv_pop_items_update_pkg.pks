--
-- XXD_INV_POP_ITEMS_UPDATE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_POP_ITEMS_UPDATE_PKG"
AS
    --  ####################################################################################################
    --  Package      : xxd_inv_pop_items_update_pkg
    --  Design       : This package is used to update the flags for POP items.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  02-Sep-2020     1.0        Showkath Ali             Initial Version - CCR0008684
    --  ####################################################################################################
    PROCEDURE main (p_errbuf                 OUT VARCHAR2,
                    p_retcode                OUT NUMBER,
                    p_organization_id     IN     NUMBER,
                    p_inventory_item_id   IN     NUMBER,
                    p_transaction_type    IN     VARCHAR2);
END xxd_inv_pop_items_update_pkg;
/
