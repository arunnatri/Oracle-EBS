--
-- XXD_ONT_SO_LINE_REPROCESS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_SO_LINE_REPROCESS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_SO_LINE_REPROCESS_PKG
    * Design       : This package will be used to retry order lines workflow and/or to
    *                update order lines flow status code
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 10-Mar-2022  1.0        Somasekhar C            Initial Version for CCR0009891
    ******************************************************************************************/
    PROCEDURE reprocess_so_lines (x_errbuf             OUT VARCHAR2,
                                  x_retcode            OUT NUMBER,
                                  p_org_id          IN     NUMBER,
                                  p_req_date_from   IN     VARCHAR2,
                                  p_req_date_to     IN     VARCHAR2);
END xxd_ont_so_line_reprocess_pkg;
/
