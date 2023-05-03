--
-- XXD_SHOPIFY_UTILS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_SHOPIFY_UTILS_PKG"
/****************************************************************************************
* Package      :XXD_SHOPIFY_UTILS
* Design       : This package is used for the shopify process
* Notes        :
* Modification :
-- ===============================================================================
-- Date         Version#   Name                    Comments
-- ===============================================================================
-- 09-May-2022  1.0     Shivanshu          Initial Version
******************************************************************************************/
IS
    --Sets Invoice ref values for the Retrun orders to
    PROCEDURE update_shopify_ret_ord (pv_errbuf OUT NOCOPY VARCHAR2, pn_retcode OUT NOCOPY NUMBER, pn_number_of_days IN NUMBER);
END XXD_SHOPIFY_UTILS_PKG;
/
