--
-- XXD_CONV_CALC_LEAD_TIME_PKG  (Package) 
--
--  Dependencies: 
--   MTL_SYSTEM_ITEMS_B (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_CONV_CALC_LEAD_TIME_PKG"
/*
================================================================
 Created By              : BT Technology Team
 Creation Date           : 6-May-2015
 File Name               : XXD_CONV_CALC_LEAD_TIME_PKG.pks
 Incident Num            :
 Description             :
 Latest Version          : 1.0

================================================================
 Date               Version#    Name                    Remarks
================================================================
6-May-2015        1.0       BT Technology Team

================================================================
*/
AS
    FUNCTION func_lead_time_cal (pn_organization_id NUMBER, pn_inventory_id NUMBER, p_attribute28 IN mtl_system_items_b.attribute28%TYPE)
        RETURN NUMBER;

    PROCEDURE prc_calc_cum_lead_time_child (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, pn_organization_id NUMBER);

    PROCEDURE PRC_CALC_LEAD_TIME_MAIN (x_errbuf    OUT VARCHAR2,
                                       x_retcode   OUT NUMBER);
END xxd_conv_calc_lead_time_pkg;
/
