--
-- XXD_CE_CASHFLOW_UPD_VS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_CE_CASHFLOW_UPD_VS_PKG"
AS
    /****************************************************************************************
      * Package         : XXD_CE_CASHFLOW_UPD_VS_PKG
      * Description     : This package is to update value set XXD_CE_LATEST_CASHFLOW_ID_VS
      *       post successful completion of 'Deckers CE Cashflow Statement Report'
      * Notes           :
      * Modification    :
      *-------------------------------------------------------------------------------------
      * Date         Version#      Name                       Description
      *-------------------------------------------------------------------------------------
      * 10-NOV-2020  1.0           Aravind Kannuri            Initial Version for CCR0008759
      *
      ***************************************************************************************/

    PROCEDURE update_value_set (pv_errbuf           OUT VARCHAR2,
                                pv_retcode          OUT NUMBER,
                                pv_module        IN     VARCHAR2,
                                pn_request_id    IN     NUMBER,
                                pn_criteria_id   IN     NUMBER);
END XXD_CE_CASHFLOW_UPD_VS_PKG;
/
