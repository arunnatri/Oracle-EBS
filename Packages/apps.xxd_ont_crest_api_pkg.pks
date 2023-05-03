--
-- XXD_ONT_CREST_API_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_CREST_API_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CREST_API_PKG
    * Design       : This package will be used in REST API calls for CREST
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 20-May-2022  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE get_order_dtls (p_email_address IN VARCHAR2);
END xxd_ont_crest_api_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_CREST_API_PKG TO XXORDS
/
