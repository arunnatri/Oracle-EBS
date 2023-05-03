--
-- XXDOINV003_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINV003_REP_PKG"
AS
    /*****************************************************************
    * Package:           XXDOINV003_REP_PKG
    * Author:            BT Technology Team
    * Created:           22-JAN-2015
    *
    * Description:       Inventory Aging Details Report - Deckers
    *
    * Modifications:
    * Change date        Developer name          Version:
    * 22-JAN-2015        BT Technology Team      Initial
    *****************************************************************/



    --======================================================================+
    --                                                                      |
    -- Report Lexical Parameters                                            |
    --                                                                      |
    --======================================================================+
    p_sql_stmt     VARCHAR2 (32000);
    --======================================================================+
    --                                                                      |
    -- Report Input Parameters                                              |
    --                                                                      |
    --======================================================================+
    p_request_id   NUMBER;
    p_inv_org_id   NUMBER;
    p_sent_yn      VARCHAR2 (20);
    p_sales_reg    VARCHAR2 (20);
    p_as_of_date   VARCHAR2 (20);
    pv_email       VARCHAR2 (240);

    --------------------------------------------------------------------------------
    /*Start Changes by BT Technology Team on 12-JAN-2015*/
    --------------------------------------------------------------------------------

    FUNCTION get_server_timezone (pv_date VARCHAR2, pn_org_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_kco_open_qty_amt (p_inventory_item_id NUMBER, p_organization_id NUMBER, p_brand VARCHAR2 DEFAULT NULL
                                   , p_col VARCHAR2)
        RETURN NUMBER;

    --------------------------------------------------------------------------------
    /*END Changes by BT Technology Team on 16-DEC-2014*/
    --------------------------------------------------------------------------------


    FUNCTION get_item_detail (p_item_id NUMBER, p_invorg_id NUMBER, p_col VARCHAR2
                              , p_format VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE inv_aging_details (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_organization_id NUMBER, p_as_of_date VARCHAR2, p_region VARCHAR2, p_format VARCHAR2
                                 , p_time_zone VARCHAR2);
END xxdoinv003_rep_pkg;
/
