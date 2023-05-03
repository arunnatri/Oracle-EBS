--
-- XXD_RETURN_CHARGEBACK_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_RETURN_CHARGEBACK_PKG"
AS
    /***********************************************************************************
       * $Header$
       * Program Name : XXD_RETURN_CHARGEBACK_PKG.pks
       * Language     : PL/SQL
       * Description  : This package routine will be used to place multiple files to
       *                specific directory based upon the combination of brand and factory code
       *
       *
       * HISTORY
       *===================================================================================
       * Author                      Version                              Date
       *===================================================================================
       * BT Technology Team          1.0 - Initial Version                23-Feb-2015
       ***********************************************************************************/

    PROCEDURE main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN NUMBER, p_brand IN VARCHAR2, p_style IN VARCHAR2, p_color IN VARCHAR2, p_factory_code IN VARCHAR2, p_product_code IN VARCHAR2, p_return_date_from IN VARCHAR2, p_return_date_to IN VARCHAR2, p_reason_code IN VARCHAR2, p_product_group IN VARCHAR2
                    , p_sales_region IN VARCHAR2, p_threshold_value IN VARCHAR2, p_source_dir IN VARCHAR2);
END xxd_return_chargeback_pkg;
/
