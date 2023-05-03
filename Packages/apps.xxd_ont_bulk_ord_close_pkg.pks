--
-- XXD_ONT_BULK_ORD_CLOSE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_BULK_ORD_CLOSE_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_ORD_CLOSE_PKG
    * Design       : This package will be used to force close Bulk Order headers and
    *                update the delivery detail records
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 24-May-2022  1.0        Viswanathan Pandian/    Initial Version
    --                         Jayarajan AK
    ******************************************************************************************/
    PROCEDURE main (retcode OUT VARCHAR2, errbuff OUT VARCHAR2, p_org_id IN NUMBER, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_action IN VARCHAR2
                    , p_debug IN VARCHAR2);
END xxd_ont_bulk_ord_close_pkg;
/
