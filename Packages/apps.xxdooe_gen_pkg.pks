--
-- XXDOOE_GEN_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOOE_GEN_PKG"
AS
    /******************************************************************************
       NAME: OM_GEN_PKG
       General Functios in Order Management

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       04/24/2012     Shibu        1. Created this package for XXDOOE_GEN_PKG
    ******************************************************************************/

    FUNCTION get_mmt_cost (pn_interface_line_attribute6 NUMBER, pn_interface_line_attribute7 NUMBER, pn_organization_id NUMBER
                           , pv_detail IN VARCHAR)
        RETURN NUMBER;

    FUNCTION get_cic_item_cost (pn_warehouse_id NUMBER, pn_inventory_item_id NUMBER, pv_custom_cost IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION GET_FACTORY_INVOICE (p_Cust_Trx_ID   IN VARCHAR2,
                                  p_Style         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION GET_PARENT_ORD_DET (PN_SO_LINE_ID   NUMBER,
                                 PN_ORG_ID       NUMBER,
                                 PV_COL          VARCHAR2)
        RETURN VARCHAR2;
END XXDOOE_GEN_PKG;
/


--
-- XXDOOE_GEN_PKG  (Synonym) 
--
--  Dependencies: 
--   XXDOOE_GEN_PKG (Package)
--
CREATE OR REPLACE SYNONYM XXDO.XXDOOE_GEN_PKG FOR APPS.XXDOOE_GEN_PKG
/


GRANT EXECUTE ON APPS.XXDOOE_GEN_PKG TO XXDO
/
