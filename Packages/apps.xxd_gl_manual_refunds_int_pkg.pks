--
-- XXD_GL_MANUAL_REFUNDS_INT_PKG  (Package) 
--
--  Dependencies: 
--   GL_INTERFACE (Synonym)
--   GL_LEDGERS (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_MANUAL_REFUNDS_INT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_GL_MANUAL_REFUNDS_INT_PKG
    * Design       : This package is used for creating GL Journals for the manual refunds
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 14-May-2018  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE main (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_ledger IN gl_ledgers.name%TYPE
                    , p_source IN gl_interface.user_je_source_name%TYPE, p_category IN gl_interface.user_je_category_name%TYPE, p_rate_type IN gl_interface.user_currency_conversion_type%TYPE);
END xxd_gl_manual_refunds_int_pkg;
/
