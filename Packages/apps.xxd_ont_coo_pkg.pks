--
-- XXD_ONT_COO_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_COO_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_COO_PKG
    * Design       : This package will be used to update Country of Origin for SO Shipped Lines
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 11-SEP-2020  1.0        Deckers                 Initial Version
    ******************************************************************************************/
    PROCEDURE COO_PRC (pv_errbuf              OUT VARCHAR2,
                       pv_retcode             OUT VARCHAR2,
                       pn_org_id           IN     NUMBER,
                       pn_order_num        IN     NUMBER,
                       pn_order_line_num   IN     NUMBER,
                       pn_inv_item_id      IN     NUMBER,
                       pv_ship_from_date   IN     VARCHAR2,
                       pv_ship_to_date     IN     VARCHAR2);

    FUNCTION get_trxn_id_fnc (pn_transaction_id IN NUMBER)
        RETURN BOOLEAN;
END XXD_ONT_COO_PKG;
/
