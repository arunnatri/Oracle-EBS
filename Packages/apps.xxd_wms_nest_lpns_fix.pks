--
-- XXD_WMS_NEST_LPNS_FIX  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_NEST_LPNS_FIX"
AS
    PROCEDURE nest_lpn (errbuf OUT VARCHAR2, retcode OUT NUMBER);
END XXD_WMS_NEST_LPNS_FIX;
/
