--
-- XXD_WMS_PICK_RELEASE_FIXES  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_PICK_RELEASE_FIXES"
AS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Project         :
    --  Description     :
    --  Module          : xxd_wms_pick_release_fixes
    --  File            : xxd_wms_pick_release_fixes.pks
    --  Schema          : APPS
    --  Date            : 01-SEPT-2015
    --  Version         : 1.0
    --  Author(s)       : Rakesh Dudani [ Suneratech Consulting]
    --  Purpose         : Package used to update the shipment priority code.
    --  dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                  Description
    --  ----------      --------------      -----   --------------------    ------------------
    --  01-SEPT-2015     Rakesh Dudani       1.0                             Initial Version
    --
    --
    --  ###################################################################################


    PROCEDURE update_ship_priority (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER)
    IS
        CURSOR order_cur IS
            SELECT mr.creation_date, ooh.order_number, ool.line_number,
                   ool.ordered_item, ooh.header_id, ool.line_id,
                   ool.flow_status_code, wdd.released_status, ool.org_id
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool, apps.mtl_reservations mr,
                   apps.wsh_delivery_details wdd
             WHERE     ooh.header_id = ool.header_id
                   AND ool.ship_from_org_id = p_org_id
                   AND ool.line_id = mr.demand_source_line_id
                   AND ool.shipment_number = 1
                   AND mr.organization_id = p_org_id
                   AND ool.ordered_quantity = mr.reservation_quantity
                   AND mr.subinventory_code IS NULL
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_order_holds_all oh
                             WHERE     oh.header_id = ooh.header_id
                                   AND NVL (released_flag, 'Y') = 'N')
                   AND ool.line_id = wdd.source_line_id
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status IN ('R', 'B');

        order_rec          order_cur%ROWTYPE;

        ln_request_id      NUMBER;
        ln_user_id         NUMBER;
        ln_resp_id         NUMBER;
        ln_app_id          NUMBER;

        lv_ship_code       VARCHAR2 (100) := 'US1-MLINES';

        p_header_rec       apps.oe_order_pub.header_rec_type;
        p_line_tbl         apps.oe_order_pub.line_tbl_type;
        p_price_adj_tbl    apps.oe_order_pub.line_adj_tbl_type;
        x_header_rec       apps.oe_order_pub.header_rec_type;
        x_header_adj_tbl   apps.oe_order_pub.header_adj_tbl_type;
        x_line_tbl         apps.oe_order_pub.line_tbl_type;
        x_line_adj_tbl     apps.oe_order_pub.line_adj_tbl_type;
        x_ret_status       VARCHAR2 (1);
        x_error_text       VARCHAR2 (4000);
    BEGIN
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.LOG,
            'Update Shipment Priority Start. Org_id = ' || p_org_id);

        --  SELECT fnd.user_id ,
        --         fresp.responsibility_id,
        --         fresp.application_id
        --   INTO  ln_user_id, ln_resp_id, ln_app_id
        --   FROM  fnd_user fnd
        --        ,fnd_responsibility_tl fresp
        --   WHERE fnd.user_name LIKE '%SIVA%B%'
        --     AND fresp.responsibility_name = 'Order Management Super User'
        --     AND ROWNUM=1;


        --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'Intializing.....');
        --apps.Fnd_Global.apps_initialize(ln_user_id, ln_resp_id, ln_app_id);

        FOR order_rec IN order_cur
        LOOP
            --mo_global.init('APPS');
            --mo_global.set_policy_context('S',order_rec.org_id);

            --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'Calling the API to update shipment priority.');

            IF order_rec.org_id = 2
            THEN
                ln_user_id   := 1037;
                ln_resp_id   := 50225;
                ln_app_id    := 20003;
            ELSIF order_rec.org_id = 472
            THEN
                ln_user_id   := 1037;
                ln_resp_id   := 56246;
                ln_app_id    := 222;
            END IF;

            apps.Fnd_Global.apps_initialize (ln_user_id,
                                             ln_resp_id,
                                             ln_app_id);


            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.LOG,
                   ' Updating line# '
                || order_rec.line_number
                || ' of Order # '
                || order_rec.order_number);

            p_header_rec                            := apps.OE_ORDER_PUB.G_MISS_HEADER_REC;
            p_header_rec.operation                  := apps.OE_GLOBALS.G_OPR_UPDATE;
            p_header_rec.header_id                  := order_rec.header_id;

            --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.Log,'Working on LINE Number: ' || order_rec.line_number);
            p_line_tbl (1)                          := apps.OE_ORDER_PUB.G_MISS_LINE_REC;
            p_line_tbl (1).operation                := apps.OE_GLOBALS.G_OPR_UPDATE;
            p_line_tbl (1).header_id                := order_rec.header_id;
            p_line_tbl (1).line_id                  := order_rec.line_id;
            p_line_tbl (1).SHIPMENT_PRIORITY_CODE   := lv_ship_code;

            --
            apps.do_debug_utils.set_level (10000);
            apps.DO_OE_UTILS.CALL_PROCESS_ORDER (p_header_rec => p_header_rec, p_line_tbl => p_line_tbl, x_header_rec => x_header_rec, x_header_adj_tbl => x_header_adj_tbl, x_line_tbl => x_line_tbl, x_line_adj_tbl => x_line_adj_tbl, x_return_status => x_ret_status, x_error_text => x_error_text, p_debug_location => apps.DO_DEBUG_UTILS.DEBUG_TABLE
                                                 , p_do_commit => 0);

            -- APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'After the API call. :: '|| x_ret_status);
            --APPS.FND_FILE.PUT_LINE(APPS.FND_FILE.LOG, 'x_error_text :: '|| x_error_text);

            IF x_ret_status = apps.fnd_api.g_ret_sts_success
            THEN
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                       ' Updated the shipment priority for line# '
                    || order_rec.line_number
                    || ' of Order # '
                    || order_rec.order_number
                    || ' as '
                    || lv_ship_code);
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.OUTPUT,
                       ' Updated the shipment priority for line# '
                    || order_rec.line_number
                    || ' of Order # '
                    || order_rec.order_number
                    || ' as '
                    || lv_ship_code);
                COMMIT;
            ELSE
                --ROLLBACK;
                apps.fnd_file.put_line (
                    apps.fnd_file.OUTPUT,
                       'Error occurred while updating record, header_id = '
                    || order_rec.header_id
                    || ' , line_id = '
                    || order_rec.line_id);
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error Occured while updating the shipment priority'
                || 'Erro message is:-'
                || SQLERRM);
    END;                                                --update_ship_priority
END xxd_wms_pick_release_fixes;
/
