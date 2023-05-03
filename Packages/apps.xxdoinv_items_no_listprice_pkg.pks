--
-- XXDOINV_ITEMS_NO_LISTPRICE_PKG  (Package) 
--
--  Dependencies: 
--   DO_MAIL_UTILS (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoinv_items_no_listprice_pkg
AS
    -- ###################################################################################
    --
    -- System : Oracle Applications
    -- Subsystem : SCP
    -- Project : ENHC0011892
    -- Description : Package to send the emails to recipients if the Items do not have list price
    -- Module : Inventory
    -- File : XXDOINV_ITEMS_NO_LISTPRICE_PKG.pks
    -- Schema : APPS
    -- Date : 18-Mar-2014
    -- Version : 1.0
    -- Author(s) : Rakkesh Kurupathi[Suneratech Consulting]
    -- Purpose : Package used to send the email with EXCEL attachment for the items do not have list price.
    -- dependency :
    -- Change History
    -- --------------
    -- Date Name Ver Change Description
    -- ---------- -------------- ----- -------------------- ------------------
    -- 18-Mar-2014 Rakkesh Kurupaathi 1.0 Initial Version
    --
    -- ###################################################################################


    PROCEDURE items_main (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2);

    FUNCTION get_email_recips (pv_lookup_type VARCHAR2)
        RETURN apps.do_mail_utils.tbl_recips;
END xxdoinv_items_no_listprice_pkg;
/
