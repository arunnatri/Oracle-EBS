--
-- XXD_FND_CONC_REQUESTS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FND_CONC_REQUESTS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_FND_CONC_REQUESTS_PKG
    * Design       : This package will be used for backing up Concurrent Requests table data
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 06-Feb-2019  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/

    PROCEDURE main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_backup_days IN NUMBER
                    , p_purge_days IN NUMBER);
END xxd_fnd_conc_requests_pkg;
/
