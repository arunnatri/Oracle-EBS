--
-- XXD_IEX_ADL_AVG_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_IEX_ADL_AVG_PKG
IS
    PROCEDURE prc_get_AVG_ADL_cust (pn_cust_id NUMBER, Pv_column_name VARCHAR2, xn_qtr_avg OUT NUMBER);
END;
/
