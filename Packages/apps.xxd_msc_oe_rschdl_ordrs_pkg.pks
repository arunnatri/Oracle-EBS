--
-- XXD_MSC_OE_RSCHDL_ORDRS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_msc_oe_rschdl_ordrs_pkg
AS
    PROCEDURE prc_xxd_msc_oe_rschdlordrs (errbuff OUT VARCHAR2, retcode OUT NUMBER, pn_ou_id NUMBER
                                          , pn_warehouse_id NUMBER);
END xxd_msc_oe_rschdl_ordrs_pkg;
/
