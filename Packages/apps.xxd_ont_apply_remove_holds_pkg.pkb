--
-- XXD_ONT_APPLY_REMOVE_HOLDS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_APPLY_REMOVE_HOLDS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_APPLY_REMOVE_HOLDS_PKG
    * Design       : This package will be used TO APPLY /REMOVE holds on the SO.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
 -- 04-Apr-2022     1.0        Gaurav Joshi
    ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    -- Modifed to init G variable from input params

    gn_org_id              NUMBER;
    gn_user_id             NUMBER;
    gn_login_id            NUMBER;
    gn_application_id      NUMBER;
    gn_responsibility_id   NUMBER;
    gn_request_id          NUMBER := fnd_global.conc_request_id;
    gc_debug_enable        VARCHAR2 (1);


    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log Or File
    -- ======================================================================================

    PROCEDURE write_message (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END write_message;

    -- ======================================================================================
    -- This procedure will be used to initialize
    -- ======================================================================================

    PROCEDURE init
    AS
    BEGIN
        mo_global.init ('ONT');
        oe_msg_pub.delete_msg;
        oe_msg_pub.initialize;
        mo_global.set_policy_context ('S', gn_org_id);
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_responsibility_id,
                                    resp_appl_id   => gn_application_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in INIT = ' || SQLERRM);
    END init;

    PROCEDURE apply_hold
    AS
        CURSOR c_headers (p_hold_id NUMBER, l_date_offset NUMBER)
        IS
              SELECT head.order_number, head.header_id
                FROM hz_cust_accounts custs, oe_order_headers head, oe_order_lines line
               WHERE     line.header_id = head.header_id
                     AND custs.cust_account_id = head.sold_to_org_id
                     AND line.open_flag = 'Y'
                     AND line.line_category_code = 'ORDER'
                     AND TO_CHAR (
                             TO_DATE (line.attribute1, 'YYYY/MM/DD HH24:MI:SS'),
                             'YYYY/MM/DD') <=
                         TO_CHAR ((SYSDATE - l_date_offset), 'YYYY/MM/DD')
                     AND head.open_flag = 'Y'
                     AND NVL (custs.attribute5, 'Y') != 'N'
                     AND line.actual_shipment_date IS NULL
                     -- AND ROWNUM < 6
                     AND NOT EXISTS
                             (SELECT 1
                                FROM mtl_reservations mr
                               WHERE mr.demand_source_line_id = line.line_id)
                     AND NOT EXISTS
                             (SELECT '1'
                                FROM oe_hold_sources hold_source, oe_order_holds hold
                               WHERE     hold.header_id = line.header_id
                                     AND hold.hold_source_id =
                                         hold_source.hold_source_id
                                     AND hold_source.hold_id = p_hold_id
                                     AND NVL (hold.released_flag, 'N') = 'N')
                     AND NOT EXISTS
                             (SELECT NULL
                                FROM do_custom.do_customer_lookups
                               WHERE     brand IN ('ALL', head.attribute5)
                                     AND customer_id = head.sold_to_org_id
                                     AND lookup_type =
                                         'DISABLE_PAST_CANCEL_HOLD'
                                     AND lookup_value = '1'
                                     AND enabled_flag = 'Y')
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.fnd_lookup_values flv, apps.oe_transaction_types_tl ott
                               WHERE     flv.lookup_type =
                                         'XXD_ONT_PICK_REL_ORD_TYP_EXCL'
                                     AND flv.language = 'US'
                                     AND flv.enabled_flag = 'Y'
                                     AND TRUNC (
                                             NVL (flv.end_date_active,
                                                  SYSDATE + 1)) >=
                                         TRUNC (SYSDATE)
                                     AND flv.meaning = ott.name
                                     AND ott.language = 'US'
                                     AND ott.transaction_type_id =
                                         head.order_type_id)
            GROUP BY head.order_number, head.header_id;


        /*
          CURSOR c_headers(p_hold_id NUMBER, l_date_offset NUMBER)
          IS
          SELECT head.order_number, head.header_id
          FROM hz_cust_accounts_all custs, oe_order_headers head
         WHERE     1 = 1
               AND custs.cust_account_id = head.sold_to_org_id
               AND head.open_flag = 'Y'
           -- and rownum<6 -- this is for testing
               AND EXISTS
                       (SELECT 1
                          FROM oe_order_lines line
                         WHERE     1 = 1
                               AND line.open_flag = 'Y'
                               AND line.header_id = head.header_id
                               AND line.line_category_code = 'ORDER'
                               AND line.actual_shipment_date IS NULL
                               AND TO_CHAR (
                                       TO_DATE (line.attribute1,
                                                'YYYY/MM/DD HH24:MI:SS'),
                                       'YYYY/MM/DD') <=
                                   TO_CHAR ((SYSDATE - l_date_offset), 'YYYY/MM/DD')
                               AND NOT EXISTS
                                       (SELECT 1
                                          FROM mtl_reservations mr
                                         WHERE mr.demand_source_line_id =
                                               line.line_id)
                               AND NOT EXISTS
                                       (SELECT '1'
                                          FROM oe_hold_sources  hold_source,
                                               oe_order_holds   hold
                                         WHERE     hold.header_id = line.header_id
                                               AND hold.hold_source_id =
                                                   hold_source.hold_source_id
                                               AND hold_source.hold_id = p_hold_id
                                               AND NVL (hold.released_flag, 'N') =
                                                   'N'))
               AND NVL (custs.attribute5, 'Y') != 'N'
               AND NOT EXISTS
                       (SELECT NULL
                          FROM do_custom.do_customer_lookups
                         WHERE     brand IN ('ALL', head.attribute5)
                               AND customer_id = head.sold_to_org_id
                               AND lookup_type = 'DISABLE_PAST_CANCEL_HOLD'
                               AND lookup_value = '1'
                               AND enabled_flag = 'Y')
               AND NOT EXISTS
                       (SELECT 1
                          FROM apps.fnd_lookup_values        flv,
                               apps.oe_transaction_types_tl  ott
                         WHERE     flv.lookup_type = 'XXD_ONT_PICK_REL_ORD_TYP_EXCL'
                               AND flv.language = 'US'
                               AND flv.enabled_flag = 'Y'
                               AND TRUNC (NVL (flv.end_date_active, SYSDATE + 1)) >=
                                   TRUNC (SYSDATE)
                               AND flv.meaning = ott.name
                               AND ott.language = 'US'
                               AND ott.transaction_type_id = head.order_type_id);
                */

        min_hour_threshhold   NUMBER := 12;
        l_hold_id             NUMBER := 0;
        l_hold_source_rec     oe_holds_pvt.hold_source_rec_type;
        l_msg_count           NUMBER;
        l_msg_data            VARCHAR2 (300);
        l_return_status       CHAR (1);
        l_date_offset         NUMBER := 0;
        ex_not_logged_in      EXCEPTION;
        lc_msg_data           VARCHAR2 (2000);
        ln_msg_count          NUMBER := 0;
        ln_msg_index_out      NUMBER;
        lc_error_message      VARCHAR2 (4000);
    BEGIN
        l_hold_id   := fnd_profile.VALUE ('DO_CANCEL_DATE_HOLD_NAME');
        min_hour_threshhold   :=
            NVL (fnd_profile.VALUE ('DO_OM_PAST_CANCEL_TH'), 12);

        IF (ROUND ((SYSDATE - TRUNC (SYSDATE)) * 24, 2) < min_hour_threshhold)
        THEN
            l_date_offset   := 1;
        END IF;

        write_message (
               '~~~Applying holds for cancel dates on or before '
            || TO_CHAR (TRUNC (SYSDATE - l_date_offset), 'MM/DD/YYYY'));
        write_message ('Mode~Order Number~Status~Error Messsage');

        FOR c_header IN c_headers (l_hold_id, l_date_offset)
        LOOP
            BEGIN
                SAVEPOINT before_hold;
                l_hold_source_rec.hold_id            := l_hold_id;  -- Hold Id
                l_hold_source_rec.hold_entity_code   := 'O';      -- hold type
                l_hold_source_rec.hold_entity_id     := c_header.header_id;
                -- Order Header id
                l_hold_source_rec.line_id            := NULL; -- Null for order-level holds
                oe_holds_pub.apply_holds (
                    p_api_version        => 1.0,
                    p_validation_level   => fnd_api.g_valid_level_none,
                    p_hold_source_rec    => l_hold_source_rec,
                    x_msg_count          => l_msg_count,
                    x_msg_data           => l_msg_data,
                    x_return_status      => l_return_status);

                IF l_return_status != 'S'
                THEN
                    FOR i IN 1 .. l_msg_count
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                        , p_msg_index_out => ln_msg_index_out);
                        lc_error_message   := lc_error_message || lc_msg_data;
                    END LOOP;

                    write_message (
                           'Apply'
                        || '~'
                        || c_header.order_number
                        || '~'
                        || l_return_status
                        || '~'
                        || lc_error_message);


                    ROLLBACK TO before_hold;
                ELSE
                    write_message (
                           'Apply'
                        || '~'
                        || c_header.order_number
                        || '~'
                        || l_return_status
                        || '~'
                        || 'Hold applied');

                    COMMIT;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_message (
                           'Apply'
                        || '~'
                        || c_header.order_number
                        || '~'
                        || l_return_status
                        || '~'
                        || SQLERRM);

                    ROLLBACK TO before_hold;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END apply_hold;

    PROCEDURE release_hold
    AS
        l_order_tbl_type    oe_holds_pvt.order_tbl_type;

        CURSOR c_headers IS
            SELECT ooh.header_id, ohs.hold_id, ooh.order_number
              FROM apps.oe_order_headers ooh, apps.oe_order_holds hld, apps.oe_hold_sources ohs,
                   apps.oe_hold_definitions ohd
             WHERE     1 = 1
                   AND ooh.order_category_code = 'ORDER'
                   AND ooh.header_id = hld.header_id
                   AND ohs.released_flag = 'N'              -- HOLD IS PRESENT
                   AND ohd.name = 'Past Cancel Hold'
                   AND ooh.open_flag = 'Y'
                   /* AND TO_CHAR (
                           TO_DATE (ooh.attribute1, 'YYYY/MM/DD HH24:MI:SS'),
                           'YYYY/MM/DD') >=
                       TO_CHAR ((SYSDATE), 'YYYY/MM/DD') -- hdr cancel date   g8t then sys date
                       */
                   AND hld.hold_source_id = ohs.hold_source_id
                   AND ohs.hold_id = ohd.hold_id
                   -- AND ROWNUM < 6
                   -- not even a single line shuld have cancel date as past i.e. all lines shuld have cancel date as future to release the hold
                   AND NOT EXISTS
                           (SELECT 1
                              FROM oe_order_lines a
                             WHERE     a.header_id = ooh.header_id
                                   AND TO_CHAR (
                                           TO_DATE (a.attribute1,
                                                    'YYYY/MM/DD HH24:MI:SS'),
                                           'YYYY/MM/DD') <
                                       TO_CHAR ((SYSDATE), 'YYYY/MM/DD')
                                   AND EXISTS
                                           (SELECT 1
                                              FROM oe_order_lines b
                                             WHERE     b.header_id =
                                                       ooh.header_id
                                                   AND a.line_id = b.LINE_ID
                                                   AND b.open_flag = 'Y'));

        lc_return_status    VARCHAR2 (20);
        lc_msg_data         VARCHAR2 (2000);
        ln_msg_count        NUMBER := 0;
        ln_msg_index_out    NUMBER;
        lc_error_message    VARCHAR2 (4000);
        l_hold_source_rec   oe_holds_pvt.hold_source_rec_type;
    BEGIN
        write_message ('Mode~Order Number~Status~Error Messsage');

        FOR c_header IN c_headers
        LOOP
            BEGIN
                SAVEPOINT before_hold;
                l_hold_source_rec.hold_id            := c_header.hold_id; -- Hold Id
                l_hold_source_rec.hold_entity_code   := 'O';      -- hold type
                l_hold_source_rec.hold_entity_id     := c_header.header_id;
                -- Order Header id

                l_order_tbl_type (1).header_id       := c_header.header_id;

                -- Call Process Order to release hold
                oe_holds_pub.release_holds (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_false, p_order_tbl => l_order_tbl_type, p_hold_id => c_header.hold_id, p_release_reason_code => 'OM_MODIFY', p_release_comment => 'Released from SOMT', x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                            , x_msg_data => lc_msg_data);

                IF lc_return_status = 'S'
                THEN
                    write_message (
                           'Release'
                        || '~'
                        || c_header.order_number
                        || '~'
                        || lc_return_status
                        || '~'
                        || 'Hold Released');
                    COMMIT;
                ELSE
                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                        , p_msg_index_out => ln_msg_index_out);
                        lc_error_message   := lc_error_message || lc_msg_data;
                    END LOOP;

                    write_message (
                           'Release'
                        || '~'
                        || c_header.order_number
                        || '~'
                        || lc_return_status
                        || '~'
                        || lc_error_message);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_message (
                           'Release'
                        || '~'
                        || c_header.order_number
                        || '~'
                        || lc_return_status
                        || '~'
                        || SQLERRM);

                    ROLLBACK TO before_hold;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_message ('unexpeted error in hold release:-' || SQLERRM);
    END release_hold;

    PROCEDURE main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_mode IN VARCHAR2)
    AS
    BEGIN
        IF p_mode = 'Apply'
        THEN
            apply_hold;
        ELSIF p_mode = 'Release'
        THEN
            release_hold;
        ELSIF p_mode = 'Both'
        THEN
            apply_hold;
            release_hold;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END main;
END XXD_ONT_APPLY_REMOVE_HOLDS_PKG;
/
