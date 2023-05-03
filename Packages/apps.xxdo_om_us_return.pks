--
-- XXDO_OM_US_RETURN  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_OM_US_RETURN
/*
================================================================
 Created By              : BT Technology Team
 Creation Date           : 26-April-2015
 File Name               : XXDO_OM_US_RETURN.pks
 Incident Num            :
 Description             :
 Latest Version          : 1.0

================================================================
 Date               Version#    Name                    Remarks
================================================================
28-April-2015        1.0       BT Technology Team

This is an Detailed US Returns Report to compare Returned quantity vs Over Shipped Vs Under Shipped returns  with return reason code
====================================================================================================================================
*/
AS
    PROCEDURE us_ret_rep (psqlstat                  OUT VARCHAR2,
                          perrproc                  OUT VARCHAR2,
                          p_brand                IN     VARCHAR2,
                          p_customer             IN     VARCHAR2,
                          p_customer_number      IN     VARCHAR2,
                          p_cust_po_num          IN     VARCHAR2,
                          p_order_num            IN     NUMBER,
                          p_creation_date_from   IN     VARCHAR2,
                          p_creation_date_to     IN     VARCHAR2,
                          p_cancel_date_from     IN     VARCHAR2,
                          p_cancel_date_to       IN     VARCHAR2);
END XXDO_OM_US_RETURN;
/
