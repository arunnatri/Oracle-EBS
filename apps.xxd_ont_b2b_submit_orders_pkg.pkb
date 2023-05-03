--
-- XXD_ONT_B2B_SUBMIT_ORDERS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_B2B_SUBMIT_ORDERS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_B2B_SUBMIT_ORDERS_PKG
    * Design       : This package will be used for B2B Submit and Return Order Report
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 15-Jul-2021  1.0         Shivanshu Talwar       Initial Version
    -- 08-Sep-2021  1.1         Shivanshu Talwar       Modified for CCR CCR0009532
 -- 27-Aug-2022  1.2         Archana Kotha          Modified for CCR CCR0010122
    ******************************************************************************************/
    gv_package_name      VARCHAR2 (200) := 'XXD_ONT_B2B_SUBMIT_ORDERS_PKG';
    gn_created_by        NUMBER := apps.fnd_global.user_id;
    gn_last_updated_by   NUMBER := apps.fnd_global.user_id;
    gn_conc_request_id   NUMBER := apps.fnd_global.conc_request_id;
    gn_user_id           NUMBER := apps.fnd_global.user_id;
    gn_resp_appl_id      NUMBER := apps.fnd_global.resp_appl_id;
    gn_resp_id           NUMBER := apps.fnd_global.resp_id;
    gv_op_name           VARCHAR2 (1000);
    gv_op_key            VARCHAR2 (1000);

    PROCEDURE validate_submit_orders (p_batch_id IN NUMBER, p_region IN VARCHAR2, p_error_count OUT NUMBER
                                      , p_error_msg OUT VARCHAR2)
    AS
        lc_account_number           VARCHAR2 (30);
        lc_party_name               VARCHAR2 (360);
        lc_store_type               VARCHAR2 (150);
        lc_error_message            VARCHAR2 (4000);
        lc_store_status             VARCHAR2 (1);
        lc_sku_status               VARCHAR2 (1);
        ln_exists                   NUMBER;
        ln_sale_error_cnt           NUMBER;
        lv_error_flag               VARCHAR2 (100);
        ln_request_id               NUMBER;
        lv_inactive_items           VARCHAR2 (4000);
        lv_purchase_enable_items    VARCHAR2 (4000);
        lv_account_active_flag      VARCHAR2 (10);
        lv_account_name             VARCHAR2 (4000);
        lv_account_num              VARCHAR2 (4000);
        ln_site_id                  NUMBER;
        lv_iface_org                VARCHAR2 (100);
        ln_ship_to_org_id           NUMBER;
        lv_ship_to_org              VARCHAR2 (200);
        lv_action_items             VARCHAR2 (4000);
        lv_data_field               VARCHAR2 (4000);
        lv_error_msg                VARCHAR2 (4000);
        lv_order_account            VARCHAR2 (100);
        lv_related_account          VARCHAR2 (100);
        lv_ord2rel_status           VARCHAR2 (100);
        lv_rel2ord_status           VARCHAR2 (100);
        ln_ord2rel_orgm             NUMBER;
        ln_rel2ord_org              NUMBER;
        ln_order_org                NUMBER;
        lv_order_type               VARCHAR2 (100);
        lv_order_customer_class     VARCHAR2 (100);
        lv_correct_customer_class   VARCHAR2 (100);
        ln_cnt_inactive_site        NUMBER := 0;
        lv_site_ou_name             VARCHAR2 (100);
        lv_order_ou_name            VARCHAR2 (100);
        ln_cnt_relationship         NUMBER;
        ln_ord2rel_org              NUMBER;
        ln_site_org                 NUMBER;
        ln_rep_ou                   NUMBER;
        ln_ou_disc                  NUMBER;
        lv_ou_data                  VARCHAR2 (500);
        lv_error_msg_txt            VARCHAR2 (500);
        lv_acct_number              VARCHAR2 (500);
        lv_ship_to_site             VARCHAR2 (500); --added as part of CCR0010122

        CURSOR submit_orders_cur IS
            SELECT b2b_order, UPPER (error_message) error_msg, olia.error_flag,
                   olia.request_id
              FROM xxdo.xxd_ont_b2b_submit_orders_t xos, apps.oe_headers_iface_all olia
             WHERE     xos.batch_id = p_batch_id
                   AND olia.orig_sys_document_ref = xos.b2b_order
                   AND record_type = 'STUCK IN INTERFACE';
    BEGIN
        gv_op_name   := 'Update records for STUCK IN INTERFACE';

        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t xos
               SET record_type    = 'STUCK IN INTERFACE',
                   error_status   = 'E',
                   region        =
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND meaning = SUBSTR (b2b_order, 1, 2)),
                   portal_name   =                                 --w.r.t 1.1
                       (SELECT tag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND meaning = SUBSTR (b2b_order, 1, 2)),
                   error_message   =
                       (SELECT DISTINCT opmt.MESSAGE_TEXT
                          FROM apps.oe_processing_msgs_tl opmt, apps.oe_processing_msgs msgs
                         WHERE     opmt.transaction_id = msgs.transaction_id
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'You are entering%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'Scheduling failed%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'Order has been booked%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'Validation failed for the field - Shipping Method%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'A hold prevents booking of this order.%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'Hold applied against order based on Order Type%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'Item/Customer hold applied against line%'
                               AND msgs.original_sys_document_ref =
                                   xos.b2b_order
                               AND ROWNUM = 1)
             WHERE     1 = 1
                   AND batch_id = p_batch_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_headers_iface_all
                             WHERE     orig_sys_document_ref = b2b_order
                                   AND request_id NOT IN
                                           (SELECT meaning
                                              FROM fnd_lookup_values_vl
                                             WHERE lookup_type LIKE
                                                       'XXDO_CI_INT_ERRORS'));

            gv_op_name   :=
                'Update records for STUCK IN INTERFACE for CI INT Errors';

            UPDATE xxdo.xxd_ont_b2b_submit_orders_t xos
               SET record_type    = 'STUCK IN INTERFACE',
                   region        =
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND meaning = SUBSTR (b2b_order, 1, 2)),
                   portal_name   =                                 --w.r.t 1.1
                       (SELECT tag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND meaning = SUBSTR (b2b_order, 1, 2)),
                   error_message   =
                       (SELECT description
                          FROM fnd_lookup_values_vl flv, apps.oe_headers_iface_all ohi
                         WHERE     lookup_type = 'XXDO_CI_INT_ERRORS'
                               AND ohi.request_id = flv.meaning
                               AND flv.enabled_flag = 'Y'
                               AND orig_sys_document_ref = b2b_order
                               AND ROWNUM = 1),
                   error_status   = 'E'
             WHERE     1 = 1
                   AND batch_id = p_batch_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_headers_iface_all
                             WHERE     orig_sys_document_ref = b2b_order
                                   AND request_id IN
                                           (SELECT meaning
                                              FROM fnd_lookup_values_vl
                                             WHERE     lookup_type =
                                                       'XXDO_CI_INT_ERRORS'
                                                   AND enabled_flag = 'Y'));

            gv_op_name   := 'Update records for STUCK IN SOA';

            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET record_type    = 'STUCK IN SOA',
                   region        =
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND meaning = SUBSTR (b2b_order, 1, 2)),
                   portal_name   =                                 --w.r.t 1.1
                       (SELECT tag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND meaning = SUBSTR (b2b_order, 1, 2)),
                   error_status   = 'E',
                   error_message   =
                       (SELECT DISTINCT error_message soa_msg
                          FROM xxdo.xxd_ont_deckersb2b_error_t
                         WHERE     integration = 'SalesOrderDECKERSB2B-EBS'
                               AND b2b_order_num = b2b_order
                               AND ROWNUM = 1)
             WHERE     batch_id = p_batch_id
                   AND record_type IS NULL
                   AND NOT EXISTS
                           (SELECT 1                         --added w.r.t 1.1
                              FROM apps.oe_headers_iface_all
                             WHERE orig_sys_document_ref = b2b_order);


            ----added w.r.t 1.1
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET record_type    = 'IN ORDER INTERFACE',
                   region        =
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND meaning = SUBSTR (b2b_order, 1, 2)),
                   portal_name   =                                 --w.r.t 1.1
                       (SELECT tag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND meaning = SUBSTR (b2b_order, 1, 2)),
                   error_status   = 'E',
                   error_message   =
                       (SELECT DISTINCT error_message soa_msg
                          FROM xxdo.xxd_ont_deckersb2b_error_t
                         WHERE     integration = 'SalesOrderDECKERSB2B-EBS'
                               AND b2b_order_num = b2b_order
                               AND ROWNUM = 1)
             WHERE     batch_id = p_batch_id
                   AND record_type IS NULL
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_headers_iface_all
                             WHERE     orig_sys_document_ref = b2b_order
                                   AND request_id IS NULL);

            gv_op_name   := 'Update records for NOT YET SYNC';

            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET record_type    = 'NOT YET SYNC',
                   EBS_SALES_ORDER   =
                       (SELECT order_number
                          FROM apps.oe_order_headers_all
                         WHERE     orig_sys_document_ref = b2b_order
                               AND ROWNUM = 1),
                   error_status   = 'E',
                   error_message   =             --added as part of CCR0010122
                       (SELECT DISTINCT error_message soa_msg
                          FROM xxdo.xxd_ont_deckersb2b_error_t
                         WHERE     integration =
                                   'SalesOrderSyncEBS-DECKERSB2B'
                               AND b2b_order_num = b2b_order
                               AND ROWNUM = 1),
                   region        =
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND meaning = SUBSTR (b2b_order, 1, 2)),
                   portal_name   =                                 --w.r.t 1.1
                       (SELECT tag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND meaning = SUBSTR (b2b_order, 1, 2)),
                   action_items   =
                       'Order not synced back to DB2B. Support team to check further'
             WHERE     1 = 1
                   AND batch_id = p_batch_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_headers_all
                             WHERE orig_sys_document_ref = b2b_order);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   :=
                       ' Error at operation: '
                    || gv_op_name
                    || ' Error Message : '
                    || SQLERRM;
        END;

        FOR submit_orders_rec IN submit_orders_cur
        LOOP
            lv_action_items     := NULL;
            lv_data_field       := NULL;
            lv_inactive_items   := NULL;
            lv_error_msg        := submit_orders_rec.error_msg;

            BEGIN
                SELECT LISTAGG (segment1, '; ') WITHIN GROUP (ORDER BY oe.creation_date, segment1) "item_list"
                  INTO lv_inactive_items
                  FROM apps.oe_lines_iface_all oe, apps.mtl_system_items_b mtl
                 WHERE     oe.inventory_item_id = mtl.inventory_item_id
                       AND organization_id = NVL (ship_from_org_id, 130)
                       AND inventory_item_status_code = 'Inactive'
                       AND orig_sys_document_ref =
                           submit_orders_rec.b2b_order
                       AND error_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_inactive_items   := NULL;
            END;

            IF lv_inactive_items IS NOT NULL
            THEN
                lv_action_items   :=
                    'If needed, please remove the items in iface and reprocess. Let us know to cancel the items in DB2B';
                lv_data_field   := ' Inactive  Items ' || lv_inactive_items;
            END IF;

            BEGIN
                SELECT LISTAGG (segment1, '; ') WITHIN GROUP (ORDER BY oe.creation_date, segment1) "item_list"
                  INTO lv_purchase_enable_items
                  FROM apps.oe_lines_iface_all oe, apps.mtl_system_items_b mtl
                 WHERE     oe.inventory_item_id = mtl.inventory_item_id
                       AND organization_id = NVL (ship_from_org_id, 130)
                       AND mtl.purchasing_enabled_flag != 'Y'
                       AND orig_sys_document_ref =
                           submit_orders_rec.b2b_order
                       AND error_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_purchase_enable_items   := NULL;
            END;

            IF lv_purchase_enable_items IS NOT NULL
            THEN
                lv_action_items   :=
                       lv_action_items
                    || ' Please check with MDM team for the time that the items will be purchasing enabled if needed';
                lv_data_field   :=
                       lv_data_field
                    || ' Purchase Disabled Items : '
                    || lv_purchase_enable_items;
            END IF;

            BEGIN
                SELECT DISTINCT hzca.account_number,
                                hzcsua.site_use_id site_id,
                                CASE
                                    WHEN     hzcsua.status = 'A'
                                         AND hzcasa.status = 'A'
                                         AND hzca.status = 'A'
                                    THEN
                                        'Y'
                                    ELSE
                                        'N'
                                END AS active_flag
                  INTO lv_account_num, ln_site_id, lv_account_active_flag
                  FROM apps.oe_headers_iface_all ohia, hz_cust_accounts hzca, hz_cust_site_uses_all hzcsua,
                       hz_cust_acct_sites_all hzcasa
                 WHERE     ohia.sold_to_org_id = hzca.cust_account_id
                       AND ohia.ship_to_org_id = hzcsua.site_use_id
                       AND hzcsua.cust_acct_site_id =
                           hzcasa.cust_acct_site_id
                       AND hzcsua.org_id = hzcasa.org_id
                       AND hzcsua.site_use_code IN ('BILL_TO', 'SHIP_TO')
                       AND ohia.orig_sys_document_ref =
                           submit_orders_rec.b2b_order;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_account_active_flag   := NULL;
            END;

            IF lv_account_active_flag = 'N'
            THEN
                lv_error_msg   := ' Inactive Customer Account ';
                lv_action_items   :=
                       lv_action_items
                    || 'Please confirm if we can cancel it, and support team to sync the account manually';
                lv_data_field   :=
                       lv_data_field
                    || ' Account : '
                    || lv_account_num
                    || ' Site : '
                    || ln_site_id;
            END IF;

            /*

            BEGIN
                SELECT oh.ship_to_org_id,
                       hc.account_number      order_account,
                       rhc.account_number     related_account,
                       hr.status              ord2rel_status,
                       hr1.status             rel2ord_status
                  INTO ln_ship_to_org_id,
                       lv_order_account,
                       lv_related_account,
                       lv_ord2rel_status,
                       lv_rel2ord_status
                  FROM apps.hz_cust_acct_relate_all  hr,
                       apps.hz_cust_acct_relate_all  hr1,
                       apps.hz_cust_accounts         rhc,
                       apps.hz_cust_accounts         hc,
                       apps.oe_headers_iface_all     oh,
                       ar.hz_cust_site_uses_all      hzcsua,
                       ar.hz_cust_acct_sites_all     hcasa
                 WHERE     1 = 1
                       AND hr.cust_account_id = oh.sold_to_org_id
                       AND rhc.cust_account_id = hr.related_cust_account_id
                       AND hc.cust_account_id = hr.cust_account_id
                       AND hr.related_cust_account_id = hr1.cust_account_id
                       AND hr1.related_cust_account_id = hr.cust_account_id
                       AND oh.ship_to_org_id = hzcsua.site_use_id
                       AND hzcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                       AND hcasa.cust_account_id = hr.related_cust_account_id
                       AND oh.orig_sys_document_ref =submit_orders_rec.b2b_order;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_iface_org := NULL;
                    ln_ship_to_org_id := NULL;
            END;

            IF ln_ship_to_org_id IS NULL
            THEN
                lv_action_items :=
                    lv_action_items || ' MDM Team to check the relationship.';
                lv_data_field :=
                       lv_data_field
                    || ' Account : '
                    || lv_order_account
                    || ' Related Account : '
                    || lv_related_account;
            END IF;
   */

            IF submit_orders_rec.error_msg LIKE
                   '%VERTEXINVALIDTAXAREAIDEXCEPTION%'
            THEN
                lv_action_items   :=
                       lv_action_items
                    || 'Support team to work with finance team';
            -- lv_data_field :=  lv_data_field ||   ' Order Org ID ' || ln_order_org ;
            END IF;

            IF submit_orders_rec.error_msg LIKE '%HTTP REQUEST FAILED%'
            THEN
                lv_action_items   :=
                       lv_action_items
                    || 'Http request failed. Support team to reprocess the record';
            -- lv_data_field :=  lv_data_field ||   ' Order Org ID ' || ln_order_org ;
            END IF;

            IF submit_orders_rec.error_msg LIKE '%EXECUTEREQUEST EXCEPTION%'
            THEN
                lv_action_items   :=
                       lv_action_items
                    || 'Error: ExecuteRequest exception : User-Defined Exception. Support team to re-process';
            -- lv_data_field :=  lv_data_field ||   ' Order Org ID ' || ln_order_org ;
            END IF;

            lv_error_msg_txt    := NULL;

            BEGIN
                SELECT DISTINCT opmt.MESSAGE_TEXT
                  INTO lv_error_msg_txt
                  FROM apps.oe_processing_msgs_tl opmt, apps.oe_processing_msgs msgs
                 WHERE     opmt.transaction_id = msgs.transaction_id
                       AND opmt.MESSAGE_TEXT LIKE 'You are entering%'
                       AND msgs.original_sys_document_ref =
                           submit_orders_rec.b2b_order
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_msg_txt   := NULL;
            END;

            IF lv_error_msg_txt IS NOT NULL
            THEN
                lv_error_msg   := lv_error_msg || lv_error_msg_txt;
            END IF;

            IF submit_orders_rec.error_msg LIKE
                   '%VALIDATION FAILED FOR THE FIELD - SHIP TO%'
            THEN
                ln_cnt_inactive_site   := 0;


                --Inactive Ship to Site
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_cnt_inactive_site
                      FROM apps.oe_headers_iface_all oha, ar.hz_cust_accounts hca, xxdo.xxdoint_ar_cust_unified_v unif
                     WHERE     1 = 1
                           AND oha.sold_to_org_id = hca.cust_account_id
                           AND unif.site_id = oha.ship_to_org_id
                           AND unif.account_number = hca.ACCOUNT_NUMBER
                           AND unif.active_flag = 'N'
                           AND oha.orig_sys_document_ref =
                               submit_orders_rec.b2b_order;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cnt_inactive_site   := 0;
                END;

                IF ln_cnt_inactive_site > 0
                THEN
                    lv_error_msg   :=
                        lv_error_msg || '; Inactive Ship to Site';
                    lv_action_items   :=
                           lv_action_items
                        || 'Please confirm if we can cancel it, and support team to sync the account manually ';
                -- lv_data_field :=  lv_data_field ||   ' Order Org ID ' || ln_order_org ;
                END IF;

                --OU discrepancy between site and order
                BEGIN
                    SELECT DISTINCT hzca.account_name, hr_order.name iface_org, hr_ship_to.name ship_to_org_id
                      INTO lv_account_name, lv_iface_org, lv_ship_to_org
                      FROM apps.oe_headers_iface_all ohia, hz_cust_accounts hzca, hz_cust_site_uses_all hzcsua,
                           hz_cust_acct_sites_all hzcasa, hr_all_organization_units hr_order, hr_all_organization_units hr_ship_to
                     WHERE     ohia.sold_to_org_id = hzca.cust_account_id
                           AND ohia.ship_to_org_id = hzcsua.site_use_id
                           AND hzcsua.cust_acct_site_id =
                               hzcasa.cust_acct_site_id
                           AND hzcsua.site_use_code IN ('BILL_TO', 'SHIP_TO')
                           AND ohia.orig_sys_document_ref =
                               submit_orders_rec.b2b_order
                           AND ohia.org_id = hr_order.organization_id
                           AND hzcsua.org_id = hr_ship_to.organization_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_iface_org     := NULL;
                        lv_ship_to_org   := NULL;
                END;

                IF lv_iface_org <> lv_ship_to_org
                THEN
                    BEGIN
                        SELECT DISTINCT ou.NAME
                          INTO lv_site_ou_name
                          FROM apps.oe_headers_iface_all oh, ar.hz_cust_site_uses_all hzcsua, apps.hr_operating_units ou
                         WHERE     1 = 1
                               AND oh.ship_to_org_id = hzcsua.site_use_id
                               AND ou.organization_id = hzcsua.org_id
                               AND oh.orig_sys_document_ref =
                                   submit_orders_rec.b2b_order
                               AND ROWNUM = 1;


                        SELECT DISTINCT ou.NAME
                          INTO lv_order_ou_name
                          FROM apps.oe_headers_iface_all oh, apps.hr_operating_units ou
                         WHERE     ou.organization_id = oh.org_id
                               AND oh.orig_sys_document_ref =
                                   submit_orders_rec.b2b_order
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_site_ou_name    := ' Not Found';
                            lv_order_ou_name   := 'Not Found';
                    END;

                    lv_error_msg   :=
                           lv_error_msg
                        || '; OU discrepancy between site and order';
                    lv_action_items   :=
                           lv_action_items
                        || '; Please confirm if entering correctly, If yes, please help correct the pricing rule to match the correct OU';
                    lv_data_field   :=
                           lv_data_field
                        || '; Site OU : '
                        || lv_site_ou_name
                        || ' , Order OU : '
                        || lv_order_ou_name;
                END IF;

                --The relationship is one-way

                ln_cnt_relationship    := 0;

                BEGIN
                    SELECT COUNT (1)
                      INTO ln_cnt_relationship
                      FROM apps.hz_cust_acct_relate_all hr, apps.hz_cust_acct_relate_all hr1, apps.hz_cust_accounts rhc,
                           apps.hz_cust_accounts hc, apps.oe_headers_iface_all oh, ar.hz_cust_site_uses_all hzcsua,
                           ar.hz_cust_acct_sites_all hcasa
                     WHERE     1 = 1
                           AND hr.cust_account_id = oh.sold_to_org_id
                           AND rhc.cust_account_id =
                               hr.related_cust_account_id
                           AND hc.cust_account_id = hr.cust_account_id
                           AND hr.related_cust_account_id =
                               hr1.cust_account_id
                           AND hr1.related_cust_account_id =
                               hr.cust_account_id
                           AND oh.ship_to_org_id = hzcsua.site_use_id
                           AND hzcsua.cust_acct_site_id =
                               hcasa.cust_acct_site_id
                           AND hcasa.cust_account_id =
                               hr.related_cust_account_id
                           AND oh.orig_sys_document_ref =
                               submit_orders_rec.b2b_order;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cnt_relationship   := 0;
                END;

                IF ln_cnt_relationship = 0
                THEN
                    lv_error_msg   :=
                        lv_error_msg || '; The relationship is one-way';
                    lv_action_items   :=
                           lv_action_items
                        || '; MDM Team to check the relationship ';
                END IF;

                --Incorrect OU in relationship

                /*     BEGIN
                                    SELECT hr.org_id      ord2rel_org,
                                           hr1.org_id     rel2ord_org,
                                           oh.org_id      order_org
                                      INTO ln_ord2rel_orgm, ln_rel2ord_org, ln_order_org
                                      FROM apps.hz_cust_acct_relate_all  hr,
                                           apps.hz_cust_acct_relate_all  hr1,
                                           apps.hz_cust_accounts         rhc,
                                           apps.hz_cust_accounts         hc,
                                           apps.oe_headers_iface_all     oh,
                                           ar.hz_cust_site_uses_all      hzcsua,
                                           ar.hz_cust_acct_sites_all     hcasa
                                     WHERE     1 = 1
                                           AND hr.cust_account_id = oh.sold_to_org_id
                                           AND rhc.cust_account_id =
                                               hr.related_cust_account_id
                                           AND hc.cust_account_id = hr.cust_account_id
                                           AND hr.related_cust_account_id =hr1.cust_account_id
                                           AND hr1.related_cust_account_id =hr.cust_account_id
                                           AND oh.ship_to_org_id = hzcsua.site_use_id
                                           AND hzcsua.cust_acct_site_id =hcasa.cust_acct_site_id
                                           AND hcasa.cust_account_id =hr.related_cust_account_id
                                           AND oh.orig_sys_document_ref =submit_orders_rec.b2b_order;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_ord2rel_orgm := NULL;
                                        ln_rel2ord_org := NULL;
                                        ln_order_org := NULL;
                                END;

                                IF    ln_ord2rel_orgm <> ln_rel2ord_org
                                   OR ln_ord2rel_orgm <> ln_order_org
                                   OR ln_rel2ord_org <> ln_order_org
                                THEN
                                    lv_error_msg := lv_error_msg || '; Incorrect OU in relationship';
                                    lv_action_items := lv_action_items  || '; MDM Team to check the OU relationship';
                                    lv_data_field := lv_data_field || '; Order Org ID ' || ln_order_org;
                                END IF;
                    */

                --w.r.t 1.1
                SELECT COUNT (1)
                  INTO ln_ou_disc
                  FROM apps.hz_cust_acct_relate_all hr, apps.hz_cust_acct_relate_all hr1, apps.oe_headers_iface_all oh,
                       ar.hz_cust_site_uses_all hzcsua
                 WHERE     1 = 1
                       AND hr.cust_account_id = oh.sold_to_org_id
                       AND hr.related_cust_account_id = hr1.cust_account_id
                       AND hr1.related_cust_account_id = hr.cust_account_id
                       AND oh.SHIP_TO_ORG_ID = hzcsua.site_use_id
                       AND hr.status = 'A'
                       AND hr1.status = 'A'
                       AND hr.org_id = hr1.org_id
                       AND hr1.org_id = hzcsua.org_id
                       AND oh.orig_sys_document_ref =
                           submit_orders_rec.b2b_order;

                IF ln_ou_disc = 0
                THEN
                    BEGIN
                        SELECT '; acc2rel_ou:' --changes as part of  CCR0010122
                                               || ou1.name || '/  rel2acc_ou:' || ou2.name || '/  site_ou:' || ou3.name
                          INTO lv_ou_data
                          FROM apps.hz_cust_acct_relate_all hr, apps.hz_cust_acct_relate_all hr1, apps.oe_headers_iface_all oh,
                               ar.hz_cust_site_uses_all hzcsua, apps.hr_operating_units ou1, apps.hr_operating_units ou2,
                               apps.hr_operating_units ou3
                         WHERE     1 = 1
                               AND hr.cust_account_id = oh.sold_to_org_id
                               AND hr.related_cust_account_id =
                                   hr1.cust_account_id
                               AND hr1.related_cust_account_id =
                                   hr.cust_account_id
                               AND oh.SHIP_TO_ORG_ID = hzcsua.site_use_id
                               AND hr.status = 'A'
                               AND hr1.status = 'A'
                               AND hr.org_id = ou1.organization_id
                               AND hr1.org_id = ou2.organization_id
                               AND hzcsua.org_id = ou3.organization_id
                               AND oh.orig_sys_document_ref =
                                   submit_orders_rec.b2b_order;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_ou_data   := NULL;
                    END;

                    lv_error_msg    :=
                           lv_error_msg
                        || '; OU discrepancy between site and Relationship';
                    lv_action_items   :=
                           lv_action_items
                        || '; MDM Team to check the OU relationship';
                    lv_data_field   := lv_data_field || lv_ou_data;
                END IF;

                --Incorrect rep assignment in B2B

                BEGIN
                    SELECT rv.operating_unit_id
                      INTO ln_rep_ou
                      FROM xxdo.xxdoint_om_rep_assignment_v rv, apps.oe_headers_iface_all ohi
                     WHERE     rv.ship_to_site_id = ohi.ship_to_org_id
                           AND rv.customer_id = ohi.SOLD_TO_ORG_ID
                           AND rv.IS_ACTIVE = 'Y' --changes as part of  CCR0010122
                           AND ohi.orig_sys_document_ref =
                               submit_orders_rec.b2b_order;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_rep_ou   := NULL;
                END;

                IF ln_rep_ou IS NULL
                THEN
                    BEGIN
                        lv_acct_number    := NULL;
                        lv_ship_to_site   := NULL; --changes as part of  CCR0010122

                        SELECT DISTINCT hca.ACCOUNT_NUMBER
                          INTO lv_acct_number
                          FROM apps.hz_cust_accounts hca, apps.oe_headers_iface_all iface
                         WHERE     iface.orig_sys_document_ref =
                                   submit_orders_rec.b2b_order
                               AND iface.SOLD_TO_ORG_ID = hca.CUST_ACCOUNT_ID
                               AND ROWNUM = 1;

                        SELECT DISTINCT ' ERP:' || ship_to_org_id --changes as part of  CCR0010122
                          INTO lv_ship_to_site
                          FROM apps.oe_headers_iface_all iface
                         WHERE iface.orig_sys_document_ref =
                               submit_orders_rec.b2b_order;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_acct_number    := 'Not Found';
                            lv_ship_to_site   := 'Not Found';
                    END;

                    lv_data_field   :=
                           lv_data_field
                        || '; Account: '
                        || lv_acct_number
                        || ', Ship_to_site:'
                        || lv_ship_to_site;   --changes as part of  CCR0010122
                    lv_error_msg   :=
                        lv_error_msg || '; Incorrect rep assignment in B2B';
                    lv_action_items   :=
                           lv_action_items
                        || '; Rep assignment discrepancy between b2b and ebs. Please confirm if its expected that user placed order with the address under the rep; Support team may need to resync the rep assignment data'; --changes as part of  CCR0010122
                END IF;
            END IF;

            BEGIN
                SELECT lv.meaning order_type, customer_class_code order_customer_class, lv.attribute2 correct_customer_class
                  INTO lv_order_type, lv_order_customer_class, lv_correct_customer_class
                  FROM oe_headers_iface_all ohia, apps.fnd_lookup_values_vl lv, ar.hz_cust_accounts hca
                 WHERE     1 = 1
                       AND lv.lookup_type = 'XXD_ORDER_TYPE_CUST_CLASS'
                       AND lv.attribute1 = ohia.order_type_id
                       AND hca.cust_account_id = ohia.sold_to_org_id
                       AND ohia.orig_sys_document_ref =
                           submit_orders_rec.b2b_order;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_order_customer_class     := NULL;
                    lv_correct_customer_class   := NULL;
            END;

            IF lv_order_customer_class <> lv_correct_customer_class
            THEN
                lv_acct_number   := NULL;     --changes as part of  CCR0010122

                SELECT DISTINCT hca.ACCOUNT_NUMBER
                  INTO lv_acct_number
                  FROM apps.hz_cust_accounts hca, apps.oe_headers_iface_all iface
                 WHERE     iface.orig_sys_document_ref =
                           submit_orders_rec.b2b_order
                       AND iface.SOLD_TO_ORG_ID = hca.CUST_ACCOUNT_ID
                       AND ROWNUM = 1;

                lv_action_items   :=
                       lv_action_items
                    || '; Please confirm if a new pricing rule to apply a correct order type for the customer class need to be set up in DeckersB2B'; --changes as part of  CCR0010122
                lv_data_field    :=
                       lv_data_field
                    || ' Order Type : '
                    || lv_order_type
                    || ' Customer Class : '
                    || lv_correct_customer_class
                    || ' Account Number : '   --changes as part of  CCR0010122
                    || lv_acct_number;
            END IF;

            lv_error_msg        :=
                REPLACE (lv_error_msg,
                         'VALIDATION FAILED FOR THE FIELD - SHIP TO',
                         '');

            BEGIN
                UPDATE xxdo.xxd_ont_b2b_submit_orders_t
                   SET action_items = lv_action_items, error_message = lv_error_msg, data_field = lv_data_field
                 WHERE     b2b_order = submit_orders_rec.b2b_order
                       AND batch_id = p_batch_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_error_msg   :=
                           ' B2B Order : '
                        || submit_orders_rec.b2b_order
                        || ' Error Message '
                        || SQLERRM;
            END;
        END LOOP;

        COMMIT;


        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET Error_message   = 'Item not in EBS'
             WHERE     record_type = 'STUCK IN SOA'
                   AND UPPER (Error_message) LIKE '%SELECT%PRIMARY_UOM_CODE%'
                   AND batch_id = p_batch_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   := ' Error Message ' || SQLERRM;
        END;

        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET ACTION_ITEMS = 'Duplicate Location name: MDM team to make the duplicate location name different.'
             WHERE     record_type = 'STUCK IN SOA'
                   AND UPPER (Error_message) LIKE
                           '%SELECT XXDO_EDI_UTILS_PUB.LOCATION_TO_SITE_USE_ID%'
                   AND batch_id = p_batch_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   := ' Error Message ' || SQLERRM;
        END;


        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET error_message   = 'Item Validation Resulted in error(s)..'
             WHERE     record_type = 'STUCK IN INTERFACE'
                   AND UPPER (error_message) LIKE
                           '%THE ITEM SPECIFIED IS INVALID%'
                   AND batch_id = p_batch_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   := ' Error Message ' || SQLERRM;
        END;


        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET ERROR_MESSAGE   = 'Request date earlier than ats date',
                   ACTION_ITEMS   =
                       'Please confirm if we need to remove the items to process the orders, which should be requested after the ats date.',
                   data_field     =                        --w.r.t version 1.1
                       (SELECT SUBSTR (LISTAGG (objects, '; '), 1, 2200)
                          FROM (SELECT DISTINCT
                                       'Item : ' || msi.segment1 || ' Request Date ' || ohi.request_date || ' ATS Date ' || msi.attribute25 Objects
                                  FROM apps.mtl_system_items_b msi, apps.org_organization_definitions ood, apps.xxd_common_items_v ms,
                                       apps.oe_headers_iface_all ohi, apps.oe_lines_iface_all oli
                                 WHERE     1 = 1
                                       AND msi.inventory_item_id =
                                           oli.inventory_item_id
                                       AND ohi.orig_sys_document_ref =
                                           oli.orig_sys_document_ref
                                       AND ms.item_number = msi.segment1
                                       AND ood.organization_id =
                                           msi.organization_id
                                       AND ood.ORGANIZATION_CODE = 'MST'
                                       AND oli.error_flag = 'Y'
                                       AND oli.orig_sys_document_ref =
                                           B2B_ORDER))
             WHERE     record_type = 'STUCK IN INTERFACE'
                   AND UPPER (ERROR_MESSAGE) LIKE
                           '%DECKERS - ONE OF THE SALES ORDER LINES HAS THE REQUEST DATE EARLY THAN SKU INTRO DATE%'
                   AND batch_id = p_batch_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   := ' Error Message ' || SQLERRM;
        END;

        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET action_items   = ' Support team to Check Further '
             WHERE action_items IS NULL AND batch_id = p_batch_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   := ' Error Message ' || SQLERRM;
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_msg   := ' Procedure end with an error ' || SQLERRM;
    END validate_submit_orders;

    PROCEDURE validate_return_orders (p_batch_id IN NUMBER, --added as part of CCR0010122
                                                            p_region IN VARCHAR2, p_error_count OUT NUMBER
                                      , p_error_msg OUT VARCHAR2)
    AS
        lc_account_number           VARCHAR2 (30);
        lc_party_name               VARCHAR2 (360);
        lc_store_type               VARCHAR2 (150);
        lc_error_message            VARCHAR2 (4000);
        lc_store_status             VARCHAR2 (1);
        lc_sku_status               VARCHAR2 (1);
        ln_exists                   NUMBER;
        ln_sale_error_cnt           NUMBER;
        lv_error_flag               VARCHAR2 (100);
        ln_request_id               NUMBER;
        lv_inactive_items           VARCHAR2 (4000);
        lv_purchase_enable_items    VARCHAR2 (4000);
        lv_account_active_flag      VARCHAR2 (10);
        lv_account_name             VARCHAR2 (4000);
        lv_account_num              VARCHAR2 (4000);
        ln_site_id                  NUMBER;
        lv_iface_org                VARCHAR2 (100);
        ln_ship_to_org_id           NUMBER;
        lv_ship_to_org              VARCHAR2 (200);
        lv_action_items             VARCHAR2 (4000);
        lv_data_field               VARCHAR2 (4000);
        lv_error_msg                VARCHAR2 (4000);
        lv_order_account            VARCHAR2 (100);
        lv_related_account          VARCHAR2 (100);
        lv_ord2rel_status           VARCHAR2 (100);
        lv_rel2ord_status           VARCHAR2 (100);
        ln_ord2rel_orgm             NUMBER;
        ln_rel2ord_org              NUMBER;
        ln_order_org                NUMBER;
        lv_order_type               VARCHAR2 (100);
        lv_order_customer_class     VARCHAR2 (100);
        lv_correct_customer_class   VARCHAR2 (100);
        ln_cnt_inactive_site        NUMBER := 0;
        lv_site_ou_name             VARCHAR2 (100);
        lv_order_ou_name            VARCHAR2 (100);
        ln_cnt_relationship         NUMBER;
        ln_ord2rel_org              NUMBER;
        ln_site_org                 NUMBER;
        ln_rep_ou                   NUMBER;
        ln_ou_disc                  NUMBER;
        lv_ou_data                  VARCHAR2 (500);
        lv_error_msg_txt            VARCHAR2 (500);
        lv_acct_number              VARCHAR2 (500);
        lv_ship_to_site             VARCHAR2 (500); --added as part of CCR0010122

        CURSOR submit_orders_cur IS
            SELECT b2b_order, UPPER (error_message) error_msg, olia.error_flag,
                   olia.request_id
              FROM xxdo.xxd_ont_b2b_submit_orders_t xos, apps.oe_headers_iface_all olia
             WHERE     xos.batch_id = p_batch_id
                   AND olia.orig_sys_document_ref = xos.b2b_order
                   AND record_type = 'STUCK IN INTERFACE';
    BEGIN
        gv_op_name   := 'Update records for STUCK IN INTERFACE';

        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t xos
               SET record_type    = 'STUCK IN INTERFACE',
                   error_status   = 'E',
                   region        =
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND 'RA' || meaning = SUBSTR (b2b_order, 1, 4)),
                   portal_name   =                                 --w.r.t 1.1
                       (SELECT tag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND 'RA' || meaning = SUBSTR (b2b_order, 1, 4)),
                   error_message   =
                       (SELECT DISTINCT opmt.MESSAGE_TEXT
                          FROM apps.oe_processing_msgs_tl opmt, apps.oe_processing_msgs msgs
                         WHERE     opmt.transaction_id = msgs.transaction_id
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'You are entering%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'Scheduling failed%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'Order has been booked%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'Validation failed for the field - Shipping Method%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'A hold prevents booking of this order.%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'Hold applied against order based on Order Type%'
                               AND opmt.MESSAGE_TEXT NOT LIKE
                                       'Item/Customer hold applied against line%'
                               AND msgs.original_sys_document_ref =
                                   xos.b2b_order
                               AND ROWNUM = 1)
             WHERE     1 = 1
                   AND batch_id = p_batch_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_headers_iface_all
                             WHERE     orig_sys_document_ref = b2b_order
                                   AND request_id NOT IN
                                           (SELECT meaning
                                              FROM fnd_lookup_values_vl
                                             WHERE lookup_type LIKE
                                                       'XXDO_CI_INT_ERRORS'));

            gv_op_name   :=
                'Update records for STUCK IN INTERFACE for CI INT Errors';

            UPDATE xxdo.xxd_ont_b2b_submit_orders_t xos
               SET record_type    = 'STUCK IN INTERFACE',
                   region        =
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND 'RA' || meaning = SUBSTR (b2b_order, 1, 4)),
                   portal_name   =                                 --w.r.t 1.1
                       (SELECT tag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND 'RA' || meaning = SUBSTR (b2b_order, 1, 4)),
                   error_message   =
                       (SELECT description
                          FROM fnd_lookup_values_vl flv, apps.oe_headers_iface_all ohi
                         WHERE     lookup_type = 'XXDO_CI_INT_ERRORS'
                               AND ohi.request_id = flv.meaning
                               AND flv.enabled_flag = 'Y'
                               AND orig_sys_document_ref = b2b_order
                               AND ROWNUM = 1),
                   error_status   = 'E'
             WHERE     1 = 1
                   AND batch_id = p_batch_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_headers_iface_all
                             WHERE     orig_sys_document_ref = b2b_order
                                   AND request_id IN
                                           (SELECT meaning
                                              FROM fnd_lookup_values_vl
                                             WHERE     lookup_type =
                                                       'XXDO_CI_INT_ERRORS'
                                                   AND enabled_flag = 'Y'));

            gv_op_name   := 'Update records for STUCK IN SOA';

            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET record_type    = 'STUCK IN SOA',
                   region        =
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND 'RA' || meaning = SUBSTR (b2b_order, 1, 4)),
                   portal_name   =                                 --w.r.t 1.1
                       (SELECT tag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND 'RA' || meaning = SUBSTR (b2b_order, 1, 4)),
                   error_status   = 'E',
                   error_message   =
                       (SELECT DISTINCT error_message soa_msg
                          FROM xxdo.xxd_ont_deckersb2b_error_t
                         WHERE     integration = 'SalesOrderDECKERSB2B-EBS'
                               AND b2b_order_num = b2b_order
                               AND ROWNUM = 1)
             WHERE     batch_id = p_batch_id
                   AND record_type IS NULL
                   AND NOT EXISTS
                           (SELECT 1                         --added w.r.t 1.1
                              FROM apps.oe_headers_iface_all
                             WHERE orig_sys_document_ref = b2b_order);


            ----added w.r.t 1.1
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET record_type    = 'IN ORDER INTERFACE',
                   region        =
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND 'RA' || meaning = SUBSTR (b2b_order, 1, 4)),
                   portal_name   =                                 --w.r.t 1.1
                       (SELECT tag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND 'RA' || meaning = SUBSTR (b2b_order, 1, 4)),
                   error_status   = 'E',
                   error_message   =
                       (SELECT DISTINCT error_message soa_msg
                          FROM xxdo.xxd_ont_deckersb2b_error_t
                         WHERE     integration = 'SalesOrderDECKERSB2B-EBS'
                               AND b2b_order_num = b2b_order
                               AND ROWNUM = 1)
             WHERE     batch_id = p_batch_id
                   AND record_type IS NULL
                   AND EXISTS                    --added as part of CCR0010122
                           (SELECT 1
                              FROM apps.oe_headers_iface_all
                             WHERE     orig_sys_document_ref = b2b_order
                                   AND request_id IS NULL);

            gv_op_name   := 'Update records for NOT YET SYNC';

            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET record_type    = 'NOT YET SYNC',
                   EBS_SALES_ORDER   =
                       (SELECT order_number
                          FROM apps.oe_order_headers_all
                         WHERE     orig_sys_document_ref = b2b_order
                               AND ROWNUM = 1),
                   error_status   = 'E',
                   error_message   =             --added as part of CCR0010122
                       (SELECT DISTINCT error_message soa_msg
                          FROM xxdo.xxd_ont_deckersb2b_error_t
                         WHERE     integration =
                                   'SalesOrderSyncEBS-DECKERSB2B'
                               AND b2b_order_num = b2b_order
                               AND ROWNUM = 1),
                   region        =
                       (SELECT description
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND 'RA' || meaning = SUBSTR (b2b_order, 1, 4)),
                   portal_name   =                                 --w.r.t 1.1
                       (SELECT tag
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXD_ONT_B2B_PORTAL_REGIONS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               TRUNC (
                                                                   SYSDATE))
                               AND 'RA' || meaning = SUBSTR (b2b_order, 1, 4)),
                   action_items   =
                       'Order not synced back to DB2B. Support team to check further'
             WHERE     1 = 1
                   AND batch_id = p_batch_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_headers_all
                             WHERE orig_sys_document_ref = b2b_order);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   :=
                       ' Error at operation: '
                    || gv_op_name
                    || ' Error Message : '
                    || SQLERRM;
        END;

        FOR submit_orders_rec IN submit_orders_cur
        LOOP
            lv_action_items     := NULL;
            lv_data_field       := NULL;
            lv_inactive_items   := NULL;
            lv_error_msg        := submit_orders_rec.error_msg;

            BEGIN
                SELECT LISTAGG (segment1, '; ') WITHIN GROUP (ORDER BY oe.creation_date, segment1) "item_list"
                  INTO lv_inactive_items
                  FROM apps.oe_lines_iface_all oe, apps.mtl_system_items_b mtl
                 WHERE     oe.inventory_item_id = mtl.inventory_item_id
                       AND organization_id = NVL (ship_from_org_id, 130)
                       AND inventory_item_status_code = 'Inactive'
                       AND orig_sys_document_ref =
                           submit_orders_rec.b2b_order
                       AND error_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_inactive_items   := NULL;
            END;

            IF lv_inactive_items IS NOT NULL
            THEN
                lv_action_items   :=
                    'If needed, please remove the items in iface and reprocess. Let us know to cancel the items in DB2B';
                lv_data_field   := ' Inactive  Items ' || lv_inactive_items;
            END IF;

            BEGIN
                SELECT LISTAGG (segment1, '; ') WITHIN GROUP (ORDER BY oe.creation_date, segment1) "item_list"
                  INTO lv_purchase_enable_items
                  FROM apps.oe_lines_iface_all oe, apps.mtl_system_items_b mtl
                 WHERE     oe.inventory_item_id = mtl.inventory_item_id
                       AND organization_id = NVL (ship_from_org_id, 130)
                       AND mtl.purchasing_enabled_flag != 'Y'
                       AND orig_sys_document_ref =
                           submit_orders_rec.b2b_order
                       AND error_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_purchase_enable_items   := NULL;
            END;

            IF lv_purchase_enable_items IS NOT NULL
            THEN
                lv_action_items   :=
                       lv_action_items
                    || ' Please check with MDM team for the time that the items will be purchasing enabled if needed';
                lv_data_field   :=
                       lv_data_field
                    || ' Purchase Disabled Items : '
                    || lv_purchase_enable_items;
            END IF;

            BEGIN
                SELECT DISTINCT hzca.account_number,
                                hzcsua.site_use_id site_id,
                                CASE
                                    WHEN     hzcsua.status = 'A'
                                         AND hzcasa.status = 'A'
                                         AND hzca.status = 'A'
                                    THEN
                                        'Y'
                                    ELSE
                                        'N'
                                END AS active_flag
                  INTO lv_account_num, ln_site_id, lv_account_active_flag
                  FROM apps.oe_headers_iface_all ohia, hz_cust_accounts hzca, hz_cust_site_uses_all hzcsua,
                       hz_cust_acct_sites_all hzcasa
                 WHERE     ohia.sold_to_org_id = hzca.cust_account_id
                       AND ohia.ship_to_org_id = hzcsua.site_use_id
                       AND hzcsua.cust_acct_site_id =
                           hzcasa.cust_acct_site_id
                       AND hzcsua.org_id = hzcasa.org_id
                       AND hzcsua.site_use_code IN ('BILL_TO', 'SHIP_TO')
                       AND ohia.orig_sys_document_ref =
                           submit_orders_rec.b2b_order;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_account_active_flag   := NULL;
            END;

            IF lv_account_active_flag = 'N'
            THEN
                lv_error_msg   := ' Inactive Customer Account ';
                lv_action_items   :=
                       lv_action_items
                    || 'Please confirm if we can cancel it, and support team to sync the account manually';
                lv_data_field   :=
                       lv_data_field
                    || ' Account : '
                    || lv_account_num
                    || ' Site : '
                    || ln_site_id;
            END IF;

            /*

            BEGIN
                SELECT oh.ship_to_org_id,
                       hc.account_number      order_account,
                       rhc.account_number     related_account,
                       hr.status              ord2rel_status,
                       hr1.status             rel2ord_status
                  INTO ln_ship_to_org_id,
                       lv_order_account,
                       lv_related_account,
                       lv_ord2rel_status,
                       lv_rel2ord_status
                  FROM apps.hz_cust_acct_relate_all  hr,
                       apps.hz_cust_acct_relate_all  hr1,
                       apps.hz_cust_accounts         rhc,
                       apps.hz_cust_accounts         hc,
                       apps.oe_headers_iface_all     oh,
                       ar.hz_cust_site_uses_all      hzcsua,
                       ar.hz_cust_acct_sites_all     hcasa
                 WHERE     1 = 1
                       AND hr.cust_account_id = oh.sold_to_org_id
                       AND rhc.cust_account_id = hr.related_cust_account_id
                       AND hc.cust_account_id = hr.cust_account_id
                       AND hr.related_cust_account_id = hr1.cust_account_id
                       AND hr1.related_cust_account_id = hr.cust_account_id
                       AND oh.ship_to_org_id = hzcsua.site_use_id
                       AND hzcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                       AND hcasa.cust_account_id = hr.related_cust_account_id
                       AND oh.orig_sys_document_ref =submit_orders_rec.b2b_order;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_iface_org := NULL;
                    ln_ship_to_org_id := NULL;
            END;

            IF ln_ship_to_org_id IS NULL
            THEN
                lv_action_items :=
                    lv_action_items || ' MDM Team to check the relationship.';
                lv_data_field :=
                       lv_data_field
                    || ' Account : '
                    || lv_order_account
                    || ' Related Account : '
                    || lv_related_account;
            END IF;
   */

            IF submit_orders_rec.error_msg LIKE
                   '%VERTEXINVALIDTAXAREAIDEXCEPTION%'
            THEN
                lv_action_items   :=
                       lv_action_items
                    || 'Support team to work with finance team';
            -- lv_data_field :=  lv_data_field ||   ' Order Org ID ' || ln_order_org ;
            END IF;

            IF submit_orders_rec.error_msg LIKE '%HTTP REQUEST FAILED%'
            THEN
                lv_action_items   :=
                       lv_action_items
                    || 'Http request failed. Support team to reprocess the record';
            -- lv_data_field :=  lv_data_field ||   ' Order Org ID ' || ln_order_org ;
            END IF;

            IF submit_orders_rec.error_msg LIKE '%EXECUTEREQUEST EXCEPTION%'
            THEN
                lv_action_items   :=
                       lv_action_items
                    || 'Error: ExecuteRequest exception : User-Defined Exception. Support team to re-process';
            -- lv_data_field :=  lv_data_field ||   ' Order Org ID ' || ln_order_org ;
            END IF;

            lv_error_msg_txt    := NULL;

            BEGIN
                SELECT DISTINCT opmt.MESSAGE_TEXT
                  INTO lv_error_msg_txt
                  FROM apps.oe_processing_msgs_tl opmt, apps.oe_processing_msgs msgs
                 WHERE     opmt.transaction_id = msgs.transaction_id
                       AND opmt.MESSAGE_TEXT LIKE 'You are entering%'
                       AND msgs.original_sys_document_ref =
                           submit_orders_rec.b2b_order
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_msg_txt   := NULL;
            END;

            IF lv_error_msg_txt IS NOT NULL
            THEN
                lv_error_msg   := lv_error_msg || lv_error_msg_txt;
            END IF;

            IF submit_orders_rec.error_msg LIKE
                   '%VALIDATION FAILED FOR THE FIELD - SHIP TO%'
            THEN
                ln_cnt_inactive_site   := 0;


                --Inactive Ship to Site
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_cnt_inactive_site
                      FROM apps.oe_headers_iface_all oha, ar.hz_cust_accounts hca, xxdo.xxdoint_ar_cust_unified_v unif
                     WHERE     1 = 1
                           AND oha.sold_to_org_id = hca.cust_account_id
                           AND unif.site_id = oha.ship_to_org_id
                           AND unif.account_number = hca.ACCOUNT_NUMBER
                           AND unif.active_flag = 'N'
                           AND oha.orig_sys_document_ref =
                               submit_orders_rec.b2b_order;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cnt_inactive_site   := 0;
                END;

                IF ln_cnt_inactive_site > 0
                THEN
                    lv_error_msg   :=
                        lv_error_msg || '; Inactive Ship to Site';
                    lv_action_items   :=
                           lv_action_items
                        || 'Please confirm if we can cancel it, and support team to sync the account manually ';
                -- lv_data_field :=  lv_data_field ||   ' Order Org ID ' || ln_order_org ;
                END IF;

                --OU discrepancy between site and order
                BEGIN
                    SELECT DISTINCT hzca.account_name, hr_order.name iface_org, hr_ship_to.name ship_to_org_id
                      INTO lv_account_name, lv_iface_org, lv_ship_to_org
                      FROM apps.oe_headers_iface_all ohia, hz_cust_accounts hzca, hz_cust_site_uses_all hzcsua,
                           hz_cust_acct_sites_all hzcasa, hr_all_organization_units hr_order, hr_all_organization_units hr_ship_to
                     WHERE     ohia.sold_to_org_id = hzca.cust_account_id
                           AND ohia.ship_to_org_id = hzcsua.site_use_id
                           AND hzcsua.cust_acct_site_id =
                               hzcasa.cust_acct_site_id
                           AND hzcsua.site_use_code IN ('BILL_TO', 'SHIP_TO')
                           AND ohia.orig_sys_document_ref =
                               submit_orders_rec.b2b_order
                           AND ohia.org_id = hr_order.organization_id
                           AND hzcsua.org_id = hr_ship_to.organization_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_iface_org     := NULL;
                        lv_ship_to_org   := NULL;
                END;

                IF lv_iface_org <> lv_ship_to_org
                THEN
                    BEGIN
                        SELECT DISTINCT ou.NAME
                          INTO lv_site_ou_name
                          FROM apps.oe_headers_iface_all oh, ar.hz_cust_site_uses_all hzcsua, apps.hr_operating_units ou
                         WHERE     1 = 1
                               AND oh.ship_to_org_id = hzcsua.site_use_id
                               AND ou.organization_id = hzcsua.org_id
                               AND oh.orig_sys_document_ref =
                                   submit_orders_rec.b2b_order
                               AND ROWNUM = 1;


                        SELECT DISTINCT ou.NAME
                          INTO lv_order_ou_name
                          FROM apps.oe_headers_iface_all oh, apps.hr_operating_units ou
                         WHERE     ou.organization_id = oh.org_id
                               AND oh.orig_sys_document_ref =
                                   submit_orders_rec.b2b_order
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_site_ou_name    := ' Not Found';
                            lv_order_ou_name   := 'Not Found';
                    END;

                    lv_error_msg   :=
                           lv_error_msg
                        || '; OU discrepancy between site and order';
                    lv_action_items   :=
                           lv_action_items
                        || '; Please confirm if entering correctly, If yes, please help correct the pricing rule to match the correct OU';
                    lv_data_field   :=
                           lv_data_field
                        || '; Site OU : '
                        || lv_site_ou_name
                        || ' , Order OU : '
                        || lv_order_ou_name;
                END IF;

                --The relationship is one-way

                ln_cnt_relationship    := 0;

                BEGIN
                    SELECT COUNT (1)
                      INTO ln_cnt_relationship
                      FROM apps.hz_cust_acct_relate_all hr, apps.hz_cust_acct_relate_all hr1, apps.hz_cust_accounts rhc,
                           apps.hz_cust_accounts hc, apps.oe_headers_iface_all oh, ar.hz_cust_site_uses_all hzcsua,
                           ar.hz_cust_acct_sites_all hcasa
                     WHERE     1 = 1
                           AND hr.cust_account_id = oh.sold_to_org_id
                           AND rhc.cust_account_id =
                               hr.related_cust_account_id
                           AND hc.cust_account_id = hr.cust_account_id
                           AND hr.related_cust_account_id =
                               hr1.cust_account_id
                           AND hr1.related_cust_account_id =
                               hr.cust_account_id
                           AND oh.ship_to_org_id = hzcsua.site_use_id
                           AND hzcsua.cust_acct_site_id =
                               hcasa.cust_acct_site_id
                           AND hcasa.cust_account_id =
                               hr.related_cust_account_id
                           AND oh.orig_sys_document_ref =
                               submit_orders_rec.b2b_order;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cnt_relationship   := 0;
                END;

                IF ln_cnt_relationship = 0
                THEN
                    lv_error_msg   :=
                        lv_error_msg || '; The relationship is one-way';
                    lv_action_items   :=
                           lv_action_items
                        || '; MDM Team to check the relationship ';
                END IF;

                --Incorrect OU in relationship

                /*     BEGIN
                                    SELECT hr.org_id      ord2rel_org,
                                           hr1.org_id     rel2ord_org,
                                           oh.org_id      order_org
                                      INTO ln_ord2rel_orgm, ln_rel2ord_org, ln_order_org
                                      FROM apps.hz_cust_acct_relate_all  hr,
                                           apps.hz_cust_acct_relate_all  hr1,
                                           apps.hz_cust_accounts         rhc,
                                           apps.hz_cust_accounts         hc,
                                           apps.oe_headers_iface_all     oh,
                                           ar.hz_cust_site_uses_all      hzcsua,
                                           ar.hz_cust_acct_sites_all     hcasa
                                     WHERE     1 = 1
                                           AND hr.cust_account_id = oh.sold_to_org_id
                                           AND rhc.cust_account_id =
                                               hr.related_cust_account_id
                                           AND hc.cust_account_id = hr.cust_account_id
                                           AND hr.related_cust_account_id =hr1.cust_account_id
                                           AND hr1.related_cust_account_id =hr.cust_account_id
                                           AND oh.ship_to_org_id = hzcsua.site_use_id
                                           AND hzcsua.cust_acct_site_id =hcasa.cust_acct_site_id
                                           AND hcasa.cust_account_id =hr.related_cust_account_id
                                           AND oh.orig_sys_document_ref =submit_orders_rec.b2b_order;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_ord2rel_orgm := NULL;
                                        ln_rel2ord_org := NULL;
                                        ln_order_org := NULL;
                                END;

                                IF    ln_ord2rel_orgm <> ln_rel2ord_org
                                   OR ln_ord2rel_orgm <> ln_order_org
                                   OR ln_rel2ord_org <> ln_order_org
                                THEN
                                    lv_error_msg := lv_error_msg || '; Incorrect OU in relationship';
                                    lv_action_items := lv_action_items  || '; MDM Team to check the OU relationship';
                                    lv_data_field := lv_data_field || '; Order Org ID ' || ln_order_org;
                                END IF;
                    */

                --w.r.t 1.1
                SELECT COUNT (1)
                  INTO ln_ou_disc
                  FROM apps.hz_cust_acct_relate_all hr, apps.hz_cust_acct_relate_all hr1, apps.oe_headers_iface_all oh,
                       ar.hz_cust_site_uses_all hzcsua
                 WHERE     1 = 1
                       AND hr.cust_account_id = oh.sold_to_org_id
                       AND hr.related_cust_account_id = hr1.cust_account_id
                       AND hr1.related_cust_account_id = hr.cust_account_id
                       AND oh.SHIP_TO_ORG_ID = hzcsua.site_use_id
                       AND hr.status = 'A'
                       AND hr1.status = 'A'
                       AND hr.org_id = hr1.org_id
                       AND hr1.org_id = hzcsua.org_id
                       AND oh.orig_sys_document_ref =
                           submit_orders_rec.b2b_order;

                IF ln_ou_disc = 0
                THEN
                    BEGIN
                        SELECT '; acc2rel_ou:' --changes as part of  CCR0010122
                                               || ou1.name || '/  rel2acc_ou:' || ou2.name || '/  site_ou:' || ou3.name
                          INTO lv_ou_data
                          FROM apps.hz_cust_acct_relate_all hr, apps.hz_cust_acct_relate_all hr1, apps.oe_headers_iface_all oh,
                               ar.hz_cust_site_uses_all hzcsua, apps.hr_operating_units ou1, apps.hr_operating_units ou2,
                               apps.hr_operating_units ou3
                         WHERE     1 = 1
                               AND hr.cust_account_id = oh.sold_to_org_id
                               AND hr.related_cust_account_id =
                                   hr1.cust_account_id
                               AND hr1.related_cust_account_id =
                                   hr.cust_account_id
                               AND oh.SHIP_TO_ORG_ID = hzcsua.site_use_id
                               AND hr.status = 'A'
                               AND hr1.status = 'A'
                               AND hr.org_id = ou1.organization_id
                               AND hr1.org_id = ou2.organization_id
                               AND hzcsua.org_id = ou3.organization_id
                               AND oh.orig_sys_document_ref =
                                   submit_orders_rec.b2b_order;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_ou_data   := NULL;
                    END;

                    lv_error_msg    :=
                           lv_error_msg
                        || '; OU discrepancy between site and Relationship';
                    lv_action_items   :=
                           lv_action_items
                        || '; MDM Team to check the OU relationship';
                    lv_data_field   := lv_data_field || lv_ou_data;
                END IF;

                --Incorrect rep assignment in B2B

                BEGIN
                    SELECT rv.operating_unit_id
                      INTO ln_rep_ou
                      FROM xxdo.xxdoint_om_rep_assignment_v rv, apps.oe_headers_iface_all ohi
                     WHERE     rv.ship_to_site_id = ohi.ship_to_org_id
                           AND rv.customer_id = ohi.SOLD_TO_ORG_ID
                           AND rv.IS_ACTIVE = 'Y'
                           AND ohi.orig_sys_document_ref =
                               submit_orders_rec.b2b_order;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_rep_ou   := NULL;
                END;

                IF ln_rep_ou IS NULL
                THEN
                    BEGIN
                        lv_acct_number    := NULL;
                        lv_ship_to_site   := NULL; --changes as part of  CCR0010122

                        SELECT DISTINCT hca.ACCOUNT_NUMBER
                          INTO lv_acct_number
                          FROM apps.hz_cust_accounts hca, apps.oe_headers_iface_all iface
                         WHERE     iface.orig_sys_document_ref =
                                   submit_orders_rec.b2b_order
                               AND iface.SOLD_TO_ORG_ID = hca.CUST_ACCOUNT_ID
                               AND ROWNUM = 1;

                        SELECT DISTINCT ' ERP:' || ship_to_org_id --changes as part of  CCR0010122
                          INTO lv_ship_to_site
                          FROM apps.oe_headers_iface_all iface
                         WHERE iface.orig_sys_document_ref =
                               submit_orders_rec.b2b_order;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_acct_number    := 'Not Found';
                            lv_ship_to_site   := 'Not Found';
                    END;

                    lv_data_field   :=
                           lv_data_field
                        || '; Account: '
                        || lv_acct_number
                        || ', Ship_to_site:'
                        || lv_ship_to_site;   --changes as part of  CCR0010122
                    lv_error_msg   :=
                        lv_error_msg || '; Incorrect rep assignment in B2B';
                    lv_action_items   :=
                           lv_action_items
                        || '; Rep assignment discrepancy between b2b and ebs. Please confirm if its expected that user placed order with the address under the rep; Support team may need to resync the rep assignment data'; --changes as part of  CCR0010122
                END IF;
            END IF;

            BEGIN
                SELECT lv.meaning order_type, customer_class_code order_customer_class, lv.attribute2 correct_customer_class
                  INTO lv_order_type, lv_order_customer_class, lv_correct_customer_class
                  FROM oe_headers_iface_all ohia, apps.fnd_lookup_values_vl lv, ar.hz_cust_accounts hca
                 WHERE     1 = 1
                       AND lv.lookup_type = 'XXD_ORDER_TYPE_CUST_CLASS'
                       AND lv.attribute1 = ohia.order_type_id
                       AND hca.cust_account_id = ohia.sold_to_org_id
                       AND ohia.orig_sys_document_ref =
                           submit_orders_rec.b2b_order;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_order_customer_class     := NULL;
                    lv_correct_customer_class   := NULL;
            END;

            IF lv_order_customer_class <> lv_correct_customer_class
            THEN
                lv_acct_number   := NULL;     --changes as part of  CCR0010122

                SELECT DISTINCT hca.ACCOUNT_NUMBER
                  INTO lv_acct_number
                  FROM apps.hz_cust_accounts hca, apps.oe_headers_iface_all iface
                 WHERE     iface.orig_sys_document_ref =
                           submit_orders_rec.b2b_order
                       AND iface.SOLD_TO_ORG_ID = hca.CUST_ACCOUNT_ID
                       AND ROWNUM = 1;

                lv_action_items   :=
                       lv_action_items
                    || '; Please confirm if a new pricing rule to apply a correct order type for the customer class need to be set up in DeckersB2B'; --changes as part of  CCR0010122
                lv_data_field    :=
                       lv_data_field
                    || ' Order Type : '
                    || lv_order_type
                    || ' Customer Class : '
                    || lv_correct_customer_class
                    || ' Account Number : '   --changes as part of  CCR0010122
                    || lv_acct_number;
            END IF;

            lv_error_msg        :=
                REPLACE (lv_error_msg,
                         'VALIDATION FAILED FOR THE FIELD - SHIP TO',
                         '');

            BEGIN
                UPDATE xxdo.xxd_ont_b2b_submit_orders_t
                   SET action_items = lv_action_items, error_message = lv_error_msg, data_field = lv_data_field
                 WHERE     b2b_order = submit_orders_rec.b2b_order
                       AND batch_id = p_batch_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_error_msg   :=
                           ' B2B Order : '
                        || submit_orders_rec.b2b_order
                        || ' Error Message '
                        || SQLERRM;
            END;
        END LOOP;

        COMMIT;


        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET Error_message   = 'Item not in EBS'
             WHERE     record_type = 'STUCK IN SOA'
                   AND UPPER (Error_message) LIKE '%SELECT%PRIMARY_UOM_CODE%'
                   AND batch_id = p_batch_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   := ' Error Message ' || SQLERRM;
        END;

        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET ACTION_ITEMS = 'Duplicate Location name: MDM team to make the duplicate location name different.'
             WHERE     record_type = 'STUCK IN SOA'
                   AND UPPER (Error_message) LIKE
                           '%SELECT XXDO_EDI_UTILS_PUB.LOCATION_TO_SITE_USE_ID%'
                   AND batch_id = p_batch_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   := ' Error Message ' || SQLERRM;
        END;


        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET error_message   = 'Item Validation Resulted in error(s)..'
             WHERE     record_type = 'STUCK IN INTERFACE'
                   AND UPPER (error_message) LIKE
                           '%THE ITEM SPECIFIED IS INVALID%'
                   AND batch_id = p_batch_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   := ' Error Message ' || SQLERRM;
        END;


        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET ERROR_MESSAGE   = 'Request date earlier than ats date',
                   ACTION_ITEMS   =
                       'Please confirm if we need to remove the items to process the orders, which should be requested after the ats date.',
                   data_field     =                        --w.r.t version 1.1
                       (SELECT SUBSTR (LISTAGG (objects, '; '), 1, 2200)
                          FROM (SELECT DISTINCT
                                       'Item : ' || msi.segment1 || ' Request Date ' || ohi.request_date || ' ATS Date ' || msi.attribute25 Objects
                                  FROM apps.mtl_system_items_b msi, apps.org_organization_definitions ood, apps.xxd_common_items_v ms,
                                       apps.oe_headers_iface_all ohi, apps.oe_lines_iface_all oli
                                 WHERE     1 = 1
                                       AND msi.inventory_item_id =
                                           oli.inventory_item_id
                                       AND ohi.orig_sys_document_ref =
                                           oli.orig_sys_document_ref
                                       AND ms.item_number = msi.segment1
                                       AND ood.organization_id =
                                           msi.organization_id
                                       AND ood.ORGANIZATION_CODE = 'MST'
                                       AND oli.error_flag = 'Y'
                                       AND oli.orig_sys_document_ref =
                                           B2B_ORDER))
             WHERE     record_type = 'STUCK IN INTERFACE'
                   AND UPPER (ERROR_MESSAGE) LIKE
                           '%DECKERS - ONE OF THE SALES ORDER LINES HAS THE REQUEST DATE EARLY THAN SKU INTRO DATE%'
                   AND batch_id = p_batch_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   := ' Error Message ' || SQLERRM;
        END;

        BEGIN
            UPDATE xxdo.xxd_ont_b2b_submit_orders_t
               SET action_items   = ' Support team to Check Further '
             WHERE action_items IS NULL AND batch_id = p_batch_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_msg   := ' Error Message ' || SQLERRM;
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_msg   := ' Procedure end with an error ' || SQLERRM;
    END validate_return_orders;
END xxd_ont_b2b_submit_orders_pkg;
/


GRANT EXECUTE ON APPS.XXD_ONT_B2B_SUBMIT_ORDERS_PKG TO SOA_INT
/
