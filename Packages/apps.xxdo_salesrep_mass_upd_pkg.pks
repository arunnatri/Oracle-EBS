--
-- XXDO_SALESREP_MASS_UPD_PKG  (Package) 
--
--  Dependencies: 
--   HZ_CUST_ACCOUNTS_ALL (Synonym)
--   HZ_PARTIES (Synonym)
--   JTF_RS_RESOURCE_EXTNS_VL (View)
--   JTF_RS_SALESREPS (Synonym)
--   MTL_PARAMETERS (Synonym)
--   OE_HOLD_DEFINITIONS (Synonym)
--   OE_HOLD_SOURCES_ALL (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_ORDER_HOLDS_ALL (Synonym)
--   OE_ORDER_LINES_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_SALESREP_MASS_UPD_PKG"
AS
    --------------------------------------------------------------------------------
    -- Created By              : Infosys
    -- Creation Date           : 10-May-2016
    -- Description             : Batch program to update salesreps for order lines on hold
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 10-May-2016        1.0         Infosys        Initial Version
    -- =============================================================================

    CURSOR order_line_cur (p_ou             IN NUMBER,
                           p_order_source   IN NUMBER,
                           p_organization   IN NUMBER,
                           p_so_number      IN NUMBER,
                           p_cust_name      IN VARCHAR2,
                           p_cust_number    IN VARCHAR2)
    IS
          SELECT ooh.order_number, ooh.header_id, ohs.hold_id,
                 ool.line_number, ool.line_id, ool.ordered_item,
                 ool.schedule_ship_date, s2.salesrep_id line_salesrep_id, s2.name line_salesrep,
                 ool.org_id, ooh.sold_to_org_id, ooh.order_type_id,
                 ool.inventory_item_id, ooh.invoice_to_org_id, ool.ship_to_org_id
            FROM apps.oe_order_holds_all oh, apps.OE_HOLD_SOURCES_ALL ohs, apps.oe_hold_definitions ohd,
                 apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool, apps.mtl_parameters mp,
                 JTF_RS_SALESREPS s2, apps.hz_cust_accounts_all hca, apps.hz_parties hp,
                 apps.JTF_RS_RESOURCE_EXTNS_VL RES
           WHERE     oh.released_flag = 'N'
                 AND oh.hold_source_id = ohs.hold_source_id
                 AND ohs.hold_id = ohd.hold_id
                 AND ohd.name = 'Salesrep Assignment Hold'
                 AND oh.header_id = ooh.header_id
                 AND NVL (oh.line_id, ool.line_id) = ool.line_id
                 AND ooh.header_id = ool.header_id
                 AND ool.salesrep_id = s2.salesrep_id
                 AND ool.org_id = s2.org_id
                 AND RES.resource_id = s2.resource_id
                 AND RES.resource_name = 'No Sales Credit'
                 AND ooh.order_number = NVL (p_so_number, ooh.order_number)
                 AND ool.org_id = NVL (P_OU, ool.org_id)
                 AND ool.order_source_id =
                     NVL (P_ORDER_SOURCE, ool.order_source_id)
                 AND ool.ship_from_org_id = mp.organization_id
                 AND mp.organization_id =
                     NVL (p_organization, mp.organization_id)
                 AND ooh.sold_to_org_id = hca.cust_account_id
                 AND hca.account_number =
                     NVL (p_cust_number, hca.account_number)
                 AND hca.party_id = hp.party_id
                 AND hp.party_name = NVL (p_cust_name, hp.party_name)
        ORDER BY ooh.header_id, ool.line_id;


    PROCEDURE msg (in_chr_message VARCHAR2);

    PROCEDURE ASSIGN_DEFAULTS;

    FUNCTION RET_LSALESREP (order_line_rec IN order_line_cur%ROWTYPE)
        RETURN NUMBER;

    PROCEDURE release_hold (in_num_header_id NUMBER, in_num_line_id NUMBER, in_num_hold_id NUMBER
                            , in_chr_Reason VARCHAR2);

    FUNCTION RET_HSALESREP (in_num_sold_to_org_id IN NUMBER, in_num_invoice_to_org_id IN NUMBER, in_num_ship_to_org_id NUMBER
                            , in_num_org_id IN NUMBER)
        RETURN NUMBER;

    PROCEDURE Main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_ou IN NUMBER,
                    p_order_source IN NUMBER, p_organization IN NUMBER, p_so_number IN NUMBER, p_cust_number IN VARCHAR2, p_cust_name IN VARCHAR2, p_chr_reason IN VARCHAR2
                    , p_debug_level IN VARCHAR2);
END XXDO_SALESREP_MASS_UPD_PKG;
/
